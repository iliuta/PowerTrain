import 'expanded_training_session_definition.dart';
import 'expanded_unit_training_interval.dart';

/// Interface that effect handlers must implement.
/// When a new effect type is needed, add a method here,
/// forcing all implementers to handle it.
abstract interface class SessionEffectHandler {
  void onStartTimer();
  void onStopTimer();
  void onPlayWarningSound();
  void onIntervalChanged(ExpandedUnitTrainingInterval newInterval);
  void onSessionCompleted();
  void onSendFtmsPause();
  void onSendFtmsResume();
  void onSendFtmsStopAndReset();
  void onNotifyListeners();
}

/// Represents the possible states of a training session
enum SessionStatus {
  /// Session has been created but not yet started
  created,

  /// Session is actively running (timer is counting)
  running,

  /// Session has been paused manually by the user
  pausedByUser,

  /// Session has been paused automatically due to device disconnection
  pausedByDisconnection,

  /// Session has been completed successfully
  completed,

  /// Session has been stopped/discarded by the user before completion
  stopped,
}

/// Immutable class that holds all timing information for a training session
class SessionTiming {
  /// Total elapsed time in seconds since session started
  final int elapsedSeconds;

  /// Index of the current interval (0-based)
  final int currentIntervalIndex;

  /// List of cumulative start times for each interval
  final List<int> intervalStartTimes;

  /// Total session duration in seconds
  final int totalDuration;

  /// List of intervals with their durations
  final List<ExpandedUnitTrainingInterval> intervals;

  const SessionTiming({
    required this.elapsedSeconds,
    required this.currentIntervalIndex,
    required this.intervalStartTimes,
    required this.totalDuration,
    required this.intervals,
  });

  /// Creates initial timing from a session definition
  factory SessionTiming.fromSession(ExpandedTrainingSessionDefinition session) {
    final intervals = session.intervals;
    final intervalStartTimes = <int>[];
    int acc = 0;
    for (final interval in intervals) {
      intervalStartTimes.add(acc);
      acc += interval.duration;
    }
    return SessionTiming(
      elapsedSeconds: 0,
      currentIntervalIndex: 0,
      intervalStartTimes: intervalStartTimes,
      totalDuration: acc,
      intervals: intervals,
    );
  }

  /// Time remaining in the entire session (in seconds)
  int get sessionTimeLeft => totalDuration - elapsedSeconds;

  /// Time elapsed in the current interval (in seconds)
  int get intervalElapsedSeconds =>
      elapsedSeconds - intervalStartTimes[currentIntervalIndex];

  /// Time remaining in the current interval (in seconds)
  int get intervalTimeLeft =>
      currentInterval.duration - intervalElapsedSeconds;

  /// The current interval
  ExpandedUnitTrainingInterval get currentInterval =>
      intervals[currentIntervalIndex];

  /// Remaining intervals (including current)
  List<ExpandedUnitTrainingInterval> get remainingIntervals =>
      intervals.sublist(currentIntervalIndex);

  /// Whether the session duration has been reached
  bool get isDurationReached => elapsedSeconds >= totalDuration;

  /// Whether we're in the last few seconds of an interval (for warning sounds)
  bool get shouldPlayWarningSound =>
      intervalTimeLeft <= 4 || intervalElapsedSeconds == 0;

  /// Creates a new SessionTiming with one second added
  SessionTiming tick() {
    if (isDurationReached) return this;

    final newElapsed = elapsedSeconds + 1;

    // Calculate new interval index
    int newIntervalIndex = currentIntervalIndex;
    while (newIntervalIndex < intervals.length - 1 &&
        newElapsed >= intervalStartTimes[newIntervalIndex + 1]) {
      newIntervalIndex++;
    }

    return SessionTiming(
      elapsedSeconds: newElapsed,
      currentIntervalIndex: newIntervalIndex,
      intervalStartTimes: intervalStartTimes,
      totalDuration: totalDuration,
      intervals: intervals,
    );
  }

  /// Whether the interval changed after a tick
  bool didIntervalChange(SessionTiming previous) =>
      currentIntervalIndex != previous.currentIntervalIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionTiming &&
          runtimeType == other.runtimeType &&
          elapsedSeconds == other.elapsedSeconds &&
          currentIntervalIndex == other.currentIntervalIndex &&
          totalDuration == other.totalDuration;

  @override
  int get hashCode =>
      elapsedSeconds.hashCode ^
      currentIntervalIndex.hashCode ^
      totalDuration.hashCode;

  @override
  String toString() =>
      'SessionTiming(elapsed: $elapsedSeconds, interval: $currentIntervalIndex, '
      'intervalElapsed: $intervalElapsedSeconds, sessionTimeLeft: $sessionTimeLeft)';
}

/// Mutable class that holds the state of a training session.
/// State transitions call the handler directly to execute side effects.
class TrainingSessionState {
  /// Current status of the session
  SessionStatus status;

  /// Timing information for the session
  SessionTiming timing;

  /// Whether the device is currently connected
  bool isDeviceConnected;

  /// The session definition
  final ExpandedTrainingSessionDefinition session;

  /// The handler that executes side effects
  final SessionEffectHandler? _handler;

  TrainingSessionState({
    required this.status,
    required this.timing,
    required this.isDeviceConnected,
    required this.session,
    SessionEffectHandler? handler,
  }) : _handler = handler;

  /// Creates initial state for a new session
  factory TrainingSessionState.initial(
    ExpandedTrainingSessionDefinition session, {
    SessionEffectHandler? handler,
  }) {
    return TrainingSessionState(
      status: SessionStatus.created,
      timing: SessionTiming.fromSession(session),
      isDeviceConnected: true,
      session: session,
      handler: handler,
    );
  }

  // ============ Convenience getters ============

  /// Whether the session has been started (not in created state)
  bool get hasStarted => status != SessionStatus.created;

  /// Whether the session is currently running
  bool get isRunning => status == SessionStatus.running;

  /// Whether the session is paused (by user or disconnection)
  bool get isPaused =>
      status == SessionStatus.pausedByUser ||
      status == SessionStatus.pausedByDisconnection;

  /// Whether the session was auto-paused due to disconnection
  bool get wasAutoPaused => status == SessionStatus.pausedByDisconnection;

  /// Whether the session has ended (completed or stopped)
  bool get hasEnded =>
      status == SessionStatus.completed || status == SessionStatus.stopped;

  /// Whether the session completed successfully
  bool get isCompleted => status == SessionStatus.completed;

  /// Whether the session was stopped/discarded
  bool get isStopped => status == SessionStatus.stopped;

  /// Whether the timer should be active
  bool get shouldTimerBeActive => status == SessionStatus.running;

  // ============ Timing convenience getters ============

  int get totalDuration => timing.totalDuration;
  int get elapsedSeconds => timing.elapsedSeconds;
  int get sessionTimeLeft => timing.sessionTimeLeft;
  int get intervalElapsedSeconds => timing.intervalElapsedSeconds;
  int get intervalTimeLeft => timing.intervalTimeLeft;
  int get currentIntervalIndex => timing.currentIntervalIndex;
  ExpandedUnitTrainingInterval get currentInterval => timing.currentInterval;
  List<ExpandedUnitTrainingInterval> get remainingIntervals =>
      timing.remainingIntervals;
  List<ExpandedUnitTrainingInterval> get intervals => timing.intervals;
  List<int> get intervalStartTimes => timing.intervalStartTimes;

  // ============ State transition methods ============

  /// Handles FTMS data changed event (triggers start from created state)
  void onDataChanged() {
    if (status != SessionStatus.created) return;

    status = SessionStatus.running;
    _handler?.onStartTimer();
    _handler?.onIntervalChanged(timing.currentInterval);
    _handler?.onNotifyListeners();
  }

  /// Handles user pause event
  void onUserPaused() {
    if (status != SessionStatus.running) return;

    status = SessionStatus.pausedByUser;
    _handler?.onStopTimer();
    _handler?.onSendFtmsPause();
    _handler?.onNotifyListeners();
  }

  /// Handles user resume event
  void onUserResumed() {
    if (!isPaused) return;

    status = SessionStatus.running;
    _handler?.onStartTimer();
    _handler?.onSendFtmsResume();
    _handler?.onNotifyListeners();
  }

  /// Handles device disconnection event
  void onDeviceDisconnected() {
    if (hasEnded) return;

    if (status == SessionStatus.running) {
      status = SessionStatus.pausedByDisconnection;
      _handler?.onStopTimer();
    }
    isDeviceConnected = false;
    _handler?.onNotifyListeners();
  }

  /// Handles device reconnection event
  void onDeviceReconnected() {
    if (status == SessionStatus.pausedByDisconnection) {
      status = SessionStatus.running;
      isDeviceConnected = true;
      _handler?.onStartTimer();
      _handler?.onIntervalChanged(timing.currentInterval);
      _handler?.onNotifyListeners();
      return;
    }

    isDeviceConnected = true;
    _handler?.onNotifyListeners();
  }

  /// Handles timer tick event (1 second elapsed)
  void onTimerTick() {
    if (status != SessionStatus.running) return;

    final previousTiming = timing;
    timing = timing.tick();

    // Check for interval change
    if (timing.didIntervalChange(previousTiming)) {
      _handler?.onIntervalChanged(timing.currentInterval);
    }

    // Check for warning sound
    if (timing.shouldPlayWarningSound) {
      _handler?.onPlayWarningSound();
    }

    // Check for completion
    if (timing.isDurationReached) {
      status = SessionStatus.completed;
      _handler?.onStopTimer();
      _handler?.onSessionCompleted();
      _handler?.onNotifyListeners();
      return;
    }

    _handler?.onNotifyListeners();
  }

  /// Handles user stop event
  void onUserStopped() {
    if (hasEnded) return;

    status = SessionStatus.stopped;
    _handler?.onStopTimer();
    _handler?.onSendFtmsStopAndReset();
    _handler?.onNotifyListeners();
  }

  @override
  String toString() =>
      'TrainingSessionState(status: $status, timing: $timing, connected: $isDeviceConnected)';
}
