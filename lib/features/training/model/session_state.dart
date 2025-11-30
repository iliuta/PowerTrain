import 'expanded_training_session_definition.dart';
import 'expanded_unit_training_interval.dart';

/// Side effects that should be executed by the controller after a state transition
sealed class SessionEffect {
  const SessionEffect();
}

/// Start the timer
class StartTimer extends SessionEffect {
  const StartTimer();
}

/// Stop the timer
class StopTimer extends SessionEffect {
  const StopTimer();
}

/// Play warning sound (countdown beep)
class PlayWarningSound extends SessionEffect {
  const PlayWarningSound();
}

/// Interval changed - update FTMS targets
class IntervalChanged extends SessionEffect {
  final ExpandedUnitTrainingInterval newInterval;
  const IntervalChanged(this.newInterval);
}

/// Session completed - finalize recording and upload
class SessionCompleted extends SessionEffect {
  const SessionCompleted();
}

/// Send FTMS pause command
class SendFtmsPause extends SessionEffect {
  const SendFtmsPause();
}

/// Send FTMS resume command
class SendFtmsResume extends SessionEffect {
  const SendFtmsResume();
}

/// Send FTMS stop and reset commands
class SendFtmsStopAndReset extends SessionEffect {
  const SendFtmsStopAndReset();
}

/// Notify listeners of state change
class NotifyListeners extends SessionEffect {
  const NotifyListeners();
}

/// Result of processing an event - contains new state and any side effects
class StateTransitionResult {
  final TrainingSessionState state;
  final List<SessionEffect> effects;

  const StateTransitionResult(this.state, [this.effects = const []]);

  /// No transition occurred
  factory StateTransitionResult.unchanged(TrainingSessionState state) =>
      StateTransitionResult(state, const []);
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

/// Represents the possible inputs/events that can trigger state transitions
enum SessionEvent {
  /// FTMS data changed (triggers start from created state)
  dataChanged,

  /// User manually paused the session
  userPaused,

  /// User manually resumed the session
  userResumed,

  /// FTMS device disconnected
  deviceDisconnected,

  /// FTMS device reconnected
  deviceReconnected,

  /// Timer tick (1 second elapsed)
  timerTick,

  /// Total duration reached
  durationReached,

  /// User stopped/discarded the session
  userStopped,
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

/// Represents the complete state of a training session with state machine logic
class TrainingSessionState {
  /// Current status of the session
  final SessionStatus status;

  /// Timing information for the session
  final SessionTiming timing;

  /// Whether the device is currently connected
  final bool isDeviceConnected;

  /// The session definition
  final ExpandedTrainingSessionDefinition session;

  const TrainingSessionState({
    required this.status,
    required this.timing,
    required this.isDeviceConnected,
    required this.session,
  });

  /// Creates initial state for a new session
  factory TrainingSessionState.initial(
      ExpandedTrainingSessionDefinition session) {
    return TrainingSessionState(
      status: SessionStatus.created,
      timing: SessionTiming.fromSession(session),
      isDeviceConnected: true,
      session: session,
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

  /// Processes an event and returns the new state (or same state if transition not allowed)
  /// Use [processEventWithEffects] to also get the side effects to execute.
  TrainingSessionState processEvent(SessionEvent event) {
    return processEventWithEffects(event).state;
  }

  /// Processes an event and returns both the new state and any side effects to execute.
  /// This is the preferred method for the controller to use.
  StateTransitionResult processEventWithEffects(SessionEvent event) {
    switch (event) {
      case SessionEvent.dataChanged:
        return _onDataChanged();
      case SessionEvent.userPaused:
        return _onUserPaused();
      case SessionEvent.userResumed:
        return _onUserResumed();
      case SessionEvent.deviceDisconnected:
        return _onDeviceDisconnected();
      case SessionEvent.deviceReconnected:
        return _onDeviceReconnected();
      case SessionEvent.timerTick:
        return _onTimerTick();
      case SessionEvent.durationReached:
        return _onDurationReached();
      case SessionEvent.userStopped:
        return _onUserStopped();
    }
  }

  /// Checks if a transition is valid for the given event
  bool canProcessEvent(SessionEvent event) {
    switch (event) {
      case SessionEvent.dataChanged:
        return status == SessionStatus.created;
      case SessionEvent.userPaused:
        return status == SessionStatus.running;
      case SessionEvent.userResumed:
        return isPaused;
      case SessionEvent.deviceDisconnected:
        return status == SessionStatus.running ||
            status == SessionStatus.created;
      case SessionEvent.deviceReconnected:
        return status == SessionStatus.pausedByDisconnection;
      case SessionEvent.timerTick:
        return status == SessionStatus.running;
      case SessionEvent.durationReached:
        return status == SessionStatus.running;
      case SessionEvent.userStopped:
        return !hasEnded;
    }
  }

  // ============ Private transition implementations ============

  StateTransitionResult _onDataChanged() {
    if (status != SessionStatus.created) {
      return StateTransitionResult.unchanged(this);
    }
    final newState = _copyWith(status: SessionStatus.running);
    return StateTransitionResult(newState, [
      const StartTimer(),
      IntervalChanged(timing.currentInterval),
      const NotifyListeners(),
    ]);
  }

  StateTransitionResult _onUserPaused() {
    if (status != SessionStatus.running) {
      return StateTransitionResult.unchanged(this);
    }
    final newState = _copyWith(status: SessionStatus.pausedByUser);
    return StateTransitionResult(newState, [
      const StopTimer(),
      const SendFtmsPause(),
      const NotifyListeners(),
    ]);
  }

  StateTransitionResult _onUserResumed() {
    if (!isPaused) {
      return StateTransitionResult.unchanged(this);
    }
    final newState = _copyWith(status: SessionStatus.running);
    return StateTransitionResult(newState, [
      const StartTimer(),
      const SendFtmsResume(),
      const NotifyListeners(),
    ]);
  }

  StateTransitionResult _onDeviceDisconnected() {
    if (hasEnded) {
      return StateTransitionResult.unchanged(this);
    }

    final effects = <SessionEffect>[];
    SessionStatus newStatus = status;

    if (status == SessionStatus.running) {
      newStatus = SessionStatus.pausedByDisconnection;
      effects.add(const StopTimer());
    }
    effects.add(const NotifyListeners());

    return StateTransitionResult(
      _copyWith(status: newStatus, isDeviceConnected: false),
      effects,
    );
  }

  StateTransitionResult _onDeviceReconnected() {
    if (status == SessionStatus.pausedByDisconnection) {
      final newState = _copyWith(
        status: SessionStatus.running,
        isDeviceConnected: true,
      );
      return StateTransitionResult(newState, [
        const StartTimer(),
        IntervalChanged(timing.currentInterval),
        const NotifyListeners(),
      ]);
    }

    return StateTransitionResult(
      _copyWith(isDeviceConnected: true),
      [const NotifyListeners()],
    );
  }

  StateTransitionResult _onTimerTick() {
    if (status != SessionStatus.running) {
      return StateTransitionResult.unchanged(this);
    }

    final previousTiming = timing;
    final newTiming = timing.tick();
    final effects = <SessionEffect>[];

    // Check for interval change
    if (newTiming.didIntervalChange(previousTiming)) {
      effects.add(IntervalChanged(newTiming.currentInterval));
    }

    // Check for warning sound
    if (newTiming.shouldPlayWarningSound) {
      effects.add(const PlayWarningSound());
    }

    // Check for completion
    if (newTiming.isDurationReached) {
      effects.add(const StopTimer());
      effects.add(const SessionCompleted());
      effects.add(const NotifyListeners());
      return StateTransitionResult(
        _copyWith(status: SessionStatus.completed, timing: newTiming),
        effects,
      );
    }

    effects.add(const NotifyListeners());
    return StateTransitionResult(_copyWith(timing: newTiming), effects);
  }

  StateTransitionResult _onDurationReached() {
    if (status != SessionStatus.running) {
      return StateTransitionResult.unchanged(this);
    }
    final newState = _copyWith(status: SessionStatus.completed);
    return StateTransitionResult(newState, [
      const StopTimer(),
      const SessionCompleted(),
      const NotifyListeners(),
    ]);
  }

  StateTransitionResult _onUserStopped() {
    if (hasEnded) {
      return StateTransitionResult.unchanged(this);
    }
    final newState = _copyWith(status: SessionStatus.stopped);
    return StateTransitionResult(newState, [
      const StopTimer(),
      const SendFtmsStopAndReset(),
      const NotifyListeners(),
    ]);
  }

  // ============ Helper methods ============

  TrainingSessionState _copyWith({
    SessionStatus? status,
    SessionTiming? timing,
    bool? isDeviceConnected,
  }) {
    return TrainingSessionState(
      status: status ?? this.status,
      timing: timing ?? this.timing,
      isDeviceConnected: isDeviceConnected ?? this.isDeviceConnected,
      session: session,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrainingSessionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          timing == other.timing &&
          isDeviceConnected == other.isDeviceConnected;

  @override
  int get hashCode =>
      status.hashCode ^ timing.hashCode ^ isDeviceConnected.hashCode;

  @override
  String toString() =>
      'TrainingSessionState(status: $status, timing: $timing, connected: $isDeviceConnected)';
}
