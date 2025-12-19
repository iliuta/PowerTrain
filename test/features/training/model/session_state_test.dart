import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/session_state.dart';
import 'package:ftms/features/training/model/unit_training_interval.dart';

/// Mock handler that records which methods were called
class MockSessionEffectHandler implements SessionEffectHandler {
  final List<String> calls = [];
  final List<ExpandedUnitTrainingInterval> intervalChanges = [];

  void reset() {
    calls.clear();
    intervalChanges.clear();
  }

  @override
  void onStartTimer() => calls.add('startTimer');

  @override
  void onStopTimer() => calls.add('stopTimer');

  @override
  void onPlayWarningSound() => calls.add('playWarningSound');

  @override
  void onIntervalChanged(ExpandedUnitTrainingInterval newInterval) {
    calls.add('intervalChanged');
    intervalChanges.add(newInterval);
  }

  @override
  void onSessionCompleted() => calls.add('sessionCompleted');

  @override
  void onSessionCompletedAwaitingConfirmation() => calls.add('sessionCompletedAwaitingConfirmation');

  @override
  void onSendFtmsPause() => calls.add('sendFtmsPause');

  @override
  void onSendFtmsResume() => calls.add('sendFtmsResume');

  @override
  void onSendFtmsStopAndReset() => calls.add('sendFtmsStopAndReset');

  @override
  void onNotifyListeners() => calls.add('notifyListeners');

  bool get startTimerCalled => calls.contains('startTimer');
  bool get stopTimerCalled => calls.contains('stopTimer');
  bool get playWarningSoundCalled => calls.contains('playWarningSound');
  bool get intervalChangedCalled => calls.contains('intervalChanged');
  bool get sessionCompletedCalled => calls.contains('sessionCompleted');
  bool get sessionCompletedAwaitingConfirmationCalled => calls.contains('sessionCompletedAwaitingConfirmation');
  bool get sendFtmsPauseCalled => calls.contains('sendFtmsPause');
  bool get sendFtmsResumeCalled => calls.contains('sendFtmsResume');
  bool get sendFtmsStopAndResetCalled => calls.contains('sendFtmsStopAndReset');
  bool get notifyListenersCalled => calls.contains('notifyListeners');
}

void main() {
  group('SessionTiming', () {
    late ExpandedTrainingSessionDefinition testSession;
    late ExpandedTrainingSessionDefinition distanceTestSession;

    setUp(() {
      final warmupOriginal = UnitTrainingInterval(title: 'Warmup', duration: 60, resistanceLevel: 5);
      final workOriginal = UnitTrainingInterval(title: 'Work', duration: 120, resistanceLevel: 10);
      final cooldownOriginal = UnitTrainingInterval(title: 'Cooldown', duration: 60, resistanceLevel: 3);
      testSession = ExpandedTrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            duration: 60,
            resistanceLevel: 5,
            originalInterval: warmupOriginal,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            duration: 120,
            resistanceLevel: 10,
            originalInterval: workOriginal,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Cooldown',
            duration: 60,
            resistanceLevel: 3,
            originalInterval: cooldownOriginal,
          ),
        ],
      );

      // Distance-based session setup
      final warmupDistanceOriginal = UnitTrainingInterval(title: 'Warmup', distance: 500, resistanceLevel: 5);
      final workDistanceOriginal = UnitTrainingInterval(title: 'Work', distance: 2000, resistanceLevel: 10);
      final cooldownDistanceOriginal = UnitTrainingInterval(title: 'Cooldown', distance: 500, resistanceLevel: 3);
      distanceTestSession = ExpandedTrainingSessionDefinition(
        title: 'Distance Test Session',
        ftmsMachineType: DeviceType.rower,
        isDistanceBased: true,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            distance: 500,
            resistanceLevel: 5,
            originalInterval: warmupDistanceOriginal,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            distance: 2000,
            resistanceLevel: 10,
            originalInterval: workDistanceOriginal,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Cooldown',
            distance: 500,
            resistanceLevel: 3,
            originalInterval: cooldownDistanceOriginal,
          ),
        ],
      );
    });

    test('fromSession calculates correct total duration', () {
      final timing = SessionTiming.fromSession(testSession);

      expect(timing.totalDuration, 240); // 60 + 120 + 60
    });

    test('fromSession calculates correct interval start times', () {
      final timing = SessionTiming.fromSession(testSession);

      expect(timing.intervalStartTimes, [0, 60, 180]);
    });

    test('initial state has zero elapsed and first interval', () {
      final timing = SessionTiming.fromSession(testSession);

      expect(timing.elapsedSeconds, 0);
      expect(timing.currentIntervalIndex, 0);
      expect(timing.intervalElapsedSeconds, 0);
    });

    test('sessionTimeLeft returns correct value at start', () {
      final timing = SessionTiming.fromSession(testSession);

      expect(timing.sessionTimeLeft, 240);
    });

    test('intervalTimeLeft returns correct value at start', () {
      final timing = SessionTiming.fromSession(testSession);

      expect(timing.intervalTimeLeft, 60);
    });

    test('currentInterval returns first interval at start', () {
      final timing = SessionTiming.fromSession(testSession);

      expect(timing.currentInterval.title, 'Warmup');
      expect(timing.currentInterval.duration, 60);
    });

    test('remainingIntervals returns all intervals at start', () {
      final timing = SessionTiming.fromSession(testSession);

      expect(timing.remainingIntervals.length, 3);
    });

    group('distance-based sessions', () {
      test('fromSession calculates correct total distance', () {
        final timing = SessionTiming.fromSession(distanceTestSession);

        expect(timing.totalDistance, 3000); // 500 + 2000 + 500
      });

      test('fromSession calculates correct interval start distances', () {
        final timing = SessionTiming.fromSession(distanceTestSession);

        expect(timing.intervalStartDistances, [0, 500, 2500]);
      });

      test('currentInterval returns first interval at start', () {
        final timing = SessionTiming.fromSession(distanceTestSession);

        expect(timing.currentInterval.distance, 500);
        expect(timing.currentInterval.title, 'Warmup');
      });

      test('remainingIntervals returns all intervals at start', () {
        final timing = SessionTiming.fromSession(distanceTestSession);

        expect(timing.remainingIntervals.length, 3);
      });

      test('updateDistance advances to next interval', () {
        final timing = SessionTiming.fromSession(distanceTestSession);
        final newTiming = timing.updateDistance(500, distanceTestSession);

        expect(newTiming.currentIntervalIndex, 1);
        expect(newTiming.currentInterval.distance, 2000);
        expect(newTiming.currentInterval.title, 'Work');
      });

      test('updateDistance completes session when total distance reached', () {
        final timing = SessionTiming.fromSession(distanceTestSession);
        final newTiming = timing.updateDistance(3000, distanceTestSession);

        expect(newTiming.currentIntervalIndex, 2);
        expect(newTiming.isDistanceReached, true);
      });

      test('updateDistance handles partial distance within interval', () {
        final timing = SessionTiming.fromSession(distanceTestSession);
        final newTiming = timing.updateDistance(250, distanceTestSession);

        expect(newTiming.currentIntervalIndex, 0);
        expect(newTiming.currentInterval.distance, 500);
        expect(newTiming.currentInterval.title, 'Warmup');
        expect(newTiming.elapsedDistance, 250);
      });
    });

    group('tick', () {
      test('increments elapsed by 1', () {
        final timing = SessionTiming.fromSession(testSession);
        final newTiming = timing.tick(testSession);

        expect(newTiming.elapsedSeconds, 1);
      });

      test('keeps same interval within first interval', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Tick 30 times (still in first interval)
        for (int i = 0; i < 30; i++) {
          current = current.tick(testSession);
        }

        expect(current.currentIntervalIndex, 0);
        expect(current.intervalElapsedSeconds, 30);
        expect(current.intervalTimeLeft, 30);
      });

      test('transitions to second interval at correct time', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Tick 60 times (exactly at transition)
        for (int i = 0; i < 60; i++) {
          current = current.tick(testSession);
        }

        expect(current.currentIntervalIndex, 1);
        expect(current.intervalElapsedSeconds, 0);
        expect(current.currentInterval.title, 'Work');
      });

      test('transitions to third interval at correct time', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Tick 180 times (60 + 120 = start of third interval)
        for (int i = 0; i < 180; i++) {
          current = current.tick(testSession);
        }

        expect(current.currentIntervalIndex, 2);
        expect(current.intervalElapsedSeconds, 0);
        expect(current.currentInterval.title, 'Cooldown');
      });

      test('does not exceed total duration', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Tick 300 times (more than total duration of 240)
        for (int i = 0; i < 300; i++) {
          current = current.tick(testSession);
        }

        expect(current.elapsedSeconds, 240);
        expect(current.isDurationReached, true);
      });

      test('isDurationReached returns true at end', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        for (int i = 0; i < 240; i++) {
          current = current.tick(testSession);
        }

        expect(current.isDurationReached, true);
        expect(current.sessionTimeLeft, 0);
      });
    });

    group('didIntervalChange', () {
      test('returns false when interval has not changed', () {
        final timing = SessionTiming.fromSession(testSession);
        final after = timing.tick(testSession);

        expect(after.didIntervalChange(timing), false);
      });

      test('returns true when interval has changed', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Get to second 59 (last second of first interval)
        for (int i = 0; i < 59; i++) {
          current = current.tick(testSession);
        }

        final before = current;
        final after = current.tick(testSession); // This should transition to interval 1

        expect(after.didIntervalChange(before), true);
      });
    });

    group('shouldPlayWarningSound', () {
      test('returns true at start of interval', () {
        final timing = SessionTiming.fromSession(testSession);

        expect(timing.shouldPlayWarningSound, true);
      });

      test('returns false in middle of interval', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        for (int i = 0; i < 30; i++) {
          current = current.tick(testSession);
        }

        expect(current.shouldPlayWarningSound, false);
      });

      test('returns true in last 4 seconds of interval', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Get to second 56 (4 seconds remaining in first interval)
        for (int i = 0; i < 56; i++) {
          current = current.tick(testSession);
        }

        expect(current.intervalTimeLeft, 4);
        expect(current.shouldPlayWarningSound, true);
      });

      test('returns true in last second of interval', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Get to second 59 (1 second remaining in first interval)
        for (int i = 0; i < 59; i++) {
          current = current.tick(testSession);
        }

        expect(current.intervalTimeLeft, 1);
        expect(current.shouldPlayWarningSound, true);
      });
    });

    test('equality works correctly', () {
      final timing1 = SessionTiming.fromSession(testSession);
      final timing2 = SessionTiming.fromSession(testSession);

      expect(timing1, equals(timing2));

      final timing3 = timing1.tick(testSession);
      expect(timing1, isNot(equals(timing3)));
    });
  });

  group('TrainingSessionState', () {
    late ExpandedTrainingSessionDefinition testSession;
    late ExpandedTrainingSessionDefinition distanceTestSession;
    late MockSessionEffectHandler mockHandler;

    setUp(() {
      final warmupOriginal = UnitTrainingInterval(title: 'Warmup', duration: 60, resistanceLevel: 5);
      final workOriginal = UnitTrainingInterval(title: 'Work', duration: 120, resistanceLevel: 10);
      testSession = ExpandedTrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            duration: 60,
            resistanceLevel: 5,
            originalInterval: warmupOriginal,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            duration: 120,
            resistanceLevel: 10,
            originalInterval: workOriginal,
          ),
        ],
      );

      // Distance-based session setup
      final warmupDistanceOriginal = UnitTrainingInterval(title: 'Warmup', distance: 500, resistanceLevel: 5);
      final workDistanceOriginal = UnitTrainingInterval(title: 'Work', distance: 2000, resistanceLevel: 10);
      distanceTestSession = ExpandedTrainingSessionDefinition(
        title: 'Distance Test Session',
        ftmsMachineType: DeviceType.rower,
        isDistanceBased: true,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            distance: 500,
            resistanceLevel: 5,
            originalInterval: warmupDistanceOriginal,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            distance: 2000,
            resistanceLevel: 10,
            originalInterval: workDistanceOriginal,
          ),
        ],
      );

      mockHandler = MockSessionEffectHandler();
    });

    group('initial state', () {
      test('creates state with created status', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.status, SessionStatus.created);
      });

      test('creates state with device connected', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.isDeviceConnected, true);
      });

      test('hasStarted returns false', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.hasStarted, false);
      });

      test('isRunning returns false', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.isRunning, false);
      });

      test('isPaused returns false', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.isPaused, false);
      });

      test('hasEnded returns false', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.hasEnded, false);
      });
    });

    group('state transitions: dataChanged', () {
      test('transitions from created to running', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();

        expect(state.status, SessionStatus.running);
        expect(state.isRunning, true);
        expect(state.hasStarted, true);
      });

      test('does not transition if already running', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        final statusBefore = state.status;

        state.onDataChanged();

        expect(state.status, statusBefore);
      });
    });

    group('state transitions: userPaused', () {
      test('transitions from running to pausedByUser', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();

        state.onUserPaused();

        expect(state.status, SessionStatus.pausedByUser);
        expect(state.isPaused, true);
        expect(state.wasAutoPaused, false);
      });

      test('does not transition if not running', () {
        final state = TrainingSessionState.initial(testSession);
        final statusBefore = state.status;

        state.onUserPaused();

        expect(state.status, statusBefore);
      });
    });

    group('state transitions: userResumed', () {
      test('transitions from pausedByUser to running', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        state.onUserPaused();

        state.onUserResumed();

        expect(state.status, SessionStatus.running);
        expect(state.isRunning, true);
        expect(state.isPaused, false);
      });

      test('transitions from pausedByDisconnection to running', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        state.onDeviceDisconnected();

        state.onUserResumed();

        expect(state.status, SessionStatus.running);
      });

      test('does not transition if not paused', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        final statusBefore = state.status;

        state.onUserResumed();

        expect(state.status, statusBefore);
      });
    });

    group('state transitions: deviceDisconnected', () {
      test('transitions from running to pausedByDisconnection', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();

        state.onDeviceDisconnected();

        expect(state.status, SessionStatus.pausedByDisconnection);
        expect(state.isPaused, true);
        expect(state.wasAutoPaused, true);
        expect(state.isDeviceConnected, false);
      });

      test('updates connection state from created without changing status', () {
        final state = TrainingSessionState.initial(testSession);

        state.onDeviceDisconnected();

        expect(state.status, SessionStatus.created);
        expect(state.isDeviceConnected, false);
      });

      test('does not change status if already ended', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        state.onUserStopped();

        state.onDeviceDisconnected();

        expect(state.status, SessionStatus.stopped);
      });
    });

    group('state transitions: deviceReconnected', () {
      test('transitions from pausedByDisconnection to running', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        state.onDeviceDisconnected();

        state.onDeviceReconnected();

        expect(state.status, SessionStatus.running);
        expect(state.isDeviceConnected, true);
        expect(state.wasAutoPaused, false);
      });

      test('updates connection state from other states without resuming', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        state.onUserPaused();

        // Manually set disconnected
        state.isDeviceConnected = false;

        state.onDeviceReconnected();

        // Should only update connection state, not status
        expect(state.status, SessionStatus.pausedByUser);
        expect(state.isDeviceConnected, true);
      });
    });

    group('state transitions: timerTick', () {
      test('increments elapsed time when running', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();

        state.onTimerTick();

        expect(state.elapsedSeconds, 1);
      });

      test('does not tick when paused', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        state.onUserPaused();
        final elapsedBefore = state.elapsedSeconds;

        state.onTimerTick();

        expect(state.elapsedSeconds, elapsedBefore);
      });

      test('completes session when duration reached', () {
        // Create a very short session
        final original = UnitTrainingInterval(duration: 3);
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(
              duration: 3,
              originalInterval: original,
            ),
          ],
        );

        final state = TrainingSessionState.initial(shortSession);
        state.onDataChanged();

        // Tick 3 times to complete
        for (int i = 0; i < 3; i++) {
          state.onTimerTick();
        }

        expect(state.status, SessionStatus.completed);
        expect(state.isCompleted, true);
        expect(state.hasEnded, true);
      });
    });

    group('state transitions: userStopped', () {
      test('transitions from running to stopped', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();

        state.onUserStopped();

        expect(state.status, SessionStatus.stopped);
        expect(state.isStopped, true);
        expect(state.hasEnded, true);
      });

      test('transitions from created to stopped', () {
        final state = TrainingSessionState.initial(testSession);

        state.onUserStopped();

        expect(state.status, SessionStatus.stopped);
      });

      test('transitions from paused to stopped', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();
        state.onUserPaused();

        state.onUserStopped();

        expect(state.status, SessionStatus.stopped);
      });

      test('does not transition if already stopped', () {
        final state = TrainingSessionState.initial(testSession);
        state.onUserStopped();
        final statusBefore = state.status;

        state.onUserStopped();

        expect(state.status, statusBefore);
      });

      test('does not transition if already completed', () {
        final shortInterval = UnitTrainingInterval(duration: 1, title: 'Short');
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 1, originalInterval: shortInterval),
          ],
        );

        final state = TrainingSessionState.initial(shortSession);
        state.onDataChanged();
        state.onTimerTick();

        expect(state.status, SessionStatus.completed);

        state.onUserStopped();
        expect(state.status, SessionStatus.completed);
      });
    });

    group('convenience getters', () {
      test('shouldTimerBeActive returns true only when running', () {
        final state = TrainingSessionState.initial(testSession);
        expect(state.shouldTimerBeActive, false);

        state.onDataChanged();
        expect(state.shouldTimerBeActive, true);

        state.onUserPaused();
        expect(state.shouldTimerBeActive, false);

        final stoppedState = TrainingSessionState.initial(testSession);
        stoppedState.onUserStopped();
        expect(stoppedState.shouldTimerBeActive, false);
      });

      test('timing convenience getters delegate correctly', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.totalDuration, state.timing.totalDuration);
        expect(state.elapsedSeconds, state.timing.elapsedSeconds);
        expect(state.sessionTimeLeft, state.timing.sessionTimeLeft);
        expect(state.intervalElapsedSeconds, state.timing.intervalElapsedSeconds);
        expect(state.intervalTimeLeft, state.timing.intervalTimeLeft);
        expect(state.currentIntervalIndex, state.timing.currentIntervalIndex);
        expect(state.currentInterval, state.timing.currentInterval);
        expect(state.remainingIntervals, state.timing.remainingIntervals);
      });
    });

    group('complex scenarios', () {
      test('full session lifecycle with pause and resume', () {
        final state = TrainingSessionState.initial(testSession);

        // Session created
        expect(state.status, SessionStatus.created);

        // Data changes, session starts
        state.onDataChanged();
        expect(state.status, SessionStatus.running);

        // Timer ticks a few times
        for (int i = 0; i < 30; i++) {
          state.onTimerTick();
        }
        expect(state.elapsedSeconds, 30);

        // User pauses
        state.onUserPaused();
        expect(state.status, SessionStatus.pausedByUser);

        // Timer ticks should not advance while paused
        state.onTimerTick();
        expect(state.elapsedSeconds, 30);

        // User resumes
        state.onUserResumed();
        expect(state.status, SessionStatus.running);

        // Timer continues
        state.onTimerTick();
        expect(state.elapsedSeconds, 31);
      });

      test('disconnection during session', () {
        final state = TrainingSessionState.initial(testSession);
        state.onDataChanged();

        // Session is running
        for (int i = 0; i < 20; i++) {
          state.onTimerTick();
        }

        // Device disconnects
        state.onDeviceDisconnected();
        expect(state.status, SessionStatus.pausedByDisconnection);
        expect(state.wasAutoPaused, true);
        expect(state.isDeviceConnected, false);

        // Timer should not advance
        final beforeTick = state.elapsedSeconds;
        state.onTimerTick();
        expect(state.elapsedSeconds, beforeTick);

        // Device reconnects
        state.onDeviceReconnected();
        expect(state.status, SessionStatus.running);
        expect(state.wasAutoPaused, false);
        expect(state.isDeviceConnected, true);

        // Timer should advance again
        state.onTimerTick();
        expect(state.elapsedSeconds, beforeTick + 1);
      });

      test('interval transitions during full session', () {
        // Session with 3 short intervals
        final intervalA = UnitTrainingInterval(duration: 5, title: 'A');
        final intervalB = UnitTrainingInterval(duration: 5, title: 'B');
        final intervalC = UnitTrainingInterval(duration: 5, title: 'C');
        final multiIntervalSession = ExpandedTrainingSessionDefinition(
          title: 'Multi',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(title: 'A', duration: 5, originalInterval: intervalA),
            ExpandedUnitTrainingInterval(title: 'B', duration: 5, originalInterval: intervalB),
            ExpandedUnitTrainingInterval(title: 'C', duration: 5, originalInterval: intervalC),
          ],
        );

        final state = TrainingSessionState.initial(multiIntervalSession);
        state.onDataChanged();

        // In first interval
        expect(state.currentIntervalIndex, 0);
        expect(state.currentInterval.title, 'A');

        // Tick through first interval
        for (int i = 0; i < 5; i++) {
          state.onTimerTick();
        }

        // Now in second interval
        expect(state.currentIntervalIndex, 1);
        expect(state.currentInterval.title, 'B');
        expect(state.intervalElapsedSeconds, 0);

        // Tick through second interval
        for (int i = 0; i < 5; i++) {
          state.onTimerTick();
        }

        // Now in third interval
        expect(state.currentIntervalIndex, 2);
        expect(state.currentInterval.title, 'C');

        // Tick through third interval
        for (int i = 0; i < 5; i++) {
          state.onTimerTick();
        }

        // Session completed
        expect(state.status, SessionStatus.completed);
      });
    });

    group('onDistanceUpdate', () {
      test('ignores updates when session is not distance-based', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        mockHandler.reset();

        state.onDistanceUpdate(100.0);

        expect(state.elapsedDistance, 0);
        expect(mockHandler.calls, isEmpty);
      });

      test('ignores updates when session is not running', () {
        final state = TrainingSessionState.initial(distanceTestSession, handler: mockHandler);

        state.onDistanceUpdate(100.0);

        expect(state.elapsedDistance, 0);
        expect(mockHandler.calls, isEmpty);
      });

      test('updates distance and advances interval', () {
        final state = TrainingSessionState.initial(distanceTestSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onDistanceUpdate(500.0);

        expect(state.elapsedDistance, 500.0);
        expect(state.currentIntervalIndex, 1);
        expect(state.currentInterval.title, 'Work');
        expect(mockHandler.intervalChangedCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('plays warning sound when approaching interval end', () {
        final state = TrainingSessionState.initial(distanceTestSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onDistanceUpdate(490.0); // 10 meters from end of 500m interval

        expect(mockHandler.playWarningSoundCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('completes session when total distance reached', () {
        final state = TrainingSessionState.initial(distanceTestSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onDistanceUpdate(2500.0); // Total distance of session

        expect(state.status, SessionStatus.completed);
        expect(mockHandler.sessionCompletedAwaitingConfirmationCalled, true);
        expect(mockHandler.stopTimerCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('handles partial distance updates within interval', () {
        final state = TrainingSessionState.initial(distanceTestSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onDistanceUpdate(250.0);

        expect(state.elapsedDistance, 250.0);
        expect(state.currentIntervalIndex, 0);
        expect(state.currentInterval.title, 'Warmup');
        expect(mockHandler.intervalChangedCalled, false);
        expect(mockHandler.notifyListenersCalled, true);
      });
    });
  });

  group('SessionStatus', () {
    test('has all expected values', () {
      expect(SessionStatus.values, contains(SessionStatus.created));
      expect(SessionStatus.values, contains(SessionStatus.running));
      expect(SessionStatus.values, contains(SessionStatus.pausedByUser));
      expect(SessionStatus.values, contains(SessionStatus.pausedByDisconnection));
      expect(SessionStatus.values, contains(SessionStatus.completed));
      expect(SessionStatus.values, contains(SessionStatus.stopped));
    });
  });

  group('SessionEffectHandler calls', () {
    late ExpandedTrainingSessionDefinition testSession;
    late MockSessionEffectHandler mockHandler;

    setUp(() {
      final warmupOriginal = UnitTrainingInterval(title: 'Warmup', duration: 60, resistanceLevel: 5);
      final workOriginal = UnitTrainingInterval(title: 'Work', duration: 120, resistanceLevel: 10);
      testSession = ExpandedTrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            duration: 60,
            resistanceLevel: 5,
            originalInterval: warmupOriginal,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            duration: 120,
            resistanceLevel: 10,
            originalInterval: workOriginal,
          ),
        ],
      );
      mockHandler = MockSessionEffectHandler();
    });

    group('dataChanged handler calls', () {
      test('calls startTimer, intervalChanged, and notifyListeners', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        expect(mockHandler.startTimerCalled, true);
        expect(mockHandler.intervalChangedCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('intervalChanged receives the first interval', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        expect(mockHandler.intervalChanges.first.title, 'Warmup');
      });

      test('calls no handler methods when already running', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onDataChanged();

        expect(mockHandler.calls, isEmpty);
      });
    });

    group('userPaused handler calls', () {
      test('calls stopTimer, sendFtmsPause, and notifyListeners', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onUserPaused();

        expect(mockHandler.stopTimerCalled, true);
        expect(mockHandler.sendFtmsPauseCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('calls no handler methods when not running', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onUserPaused();

        expect(mockHandler.calls, isEmpty);
      });
    });

    group('userResumed handler calls', () {
      test('calls startTimer, sendFtmsResume, and notifyListeners', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onUserPaused();

        mockHandler.reset();
        state.onUserResumed();

        expect(mockHandler.startTimerCalled, true);
        expect(mockHandler.sendFtmsResumeCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('calls no handler methods when not paused', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onUserResumed();

        expect(mockHandler.calls, isEmpty);
      });
    });

    group('deviceDisconnected handler calls', () {
      test('calls stopTimer and notifyListeners when running', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onDeviceDisconnected();

        expect(mockHandler.stopTimerCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('calls only notifyListeners when in created state', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDeviceDisconnected();

        expect(mockHandler.stopTimerCalled, false);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('transitions to pausedByDisconnection when running', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onDeviceDisconnected();

        expect(state.status, SessionStatus.pausedByDisconnection);
        expect(state.isDeviceConnected, false);
      });

      test('keeps created status when disconnected before start', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDeviceDisconnected();

        expect(state.status, SessionStatus.created);
        expect(state.isDeviceConnected, false);
      });

      test('keeps pausedByUser status when disconnected during user pause', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onUserPaused();

        mockHandler.reset();
        state.onDeviceDisconnected();

        expect(state.status, SessionStatus.pausedByUser);
        expect(state.isDeviceConnected, false);
        expect(mockHandler.notifyListenersCalled, true);
        expect(mockHandler.stopTimerCalled, false);
      });

      test('calls no handler methods when session has ended', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onUserStopped();

        mockHandler.reset();
        state.onDeviceDisconnected();

        expect(mockHandler.calls, isEmpty);
        expect(state.status, SessionStatus.stopped);
      });

      test('calls no handler methods when session is completed', () {
        final shortInterval = UnitTrainingInterval(duration: 1, title: 'Short');
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 1, originalInterval: shortInterval),
          ],
        );

        final state = TrainingSessionState.initial(shortSession, handler: mockHandler);
        state.onDataChanged();
        state.onTimerTick();

        expect(state.status, SessionStatus.completed);

        mockHandler.reset();
        state.onDeviceDisconnected();

        expect(mockHandler.calls, isEmpty);
      });

      test('does not call sendFtmsPause (disconnect is not user pause)', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onDeviceDisconnected();

        expect(mockHandler.sendFtmsPauseCalled, false);
      });
    });

    group('deviceReconnected handler calls', () {
      test('calls startTimer, intervalChanged, and notifyListeners when auto-paused', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onDeviceDisconnected();

        mockHandler.reset();
        state.onDeviceReconnected();

        expect(mockHandler.startTimerCalled, true);
        expect(mockHandler.intervalChangedCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('calls only notifyListeners when not auto-paused', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDeviceReconnected();

        expect(mockHandler.startTimerCalled, false);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('transitions from pausedByDisconnection to running', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onDeviceDisconnected();
        state.onDeviceReconnected();

        expect(state.status, SessionStatus.running);
        expect(state.isDeviceConnected, true);
      });

      test('intervalChanged receives current interval after reconnection', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onDeviceDisconnected();

        mockHandler.reset();
        state.onDeviceReconnected();

        expect(mockHandler.intervalChanges.first.title, 'Warmup');
      });

      test('does not call sendFtmsResume (reconnect uses intervalChanged)', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onDeviceDisconnected();

        mockHandler.reset();
        state.onDeviceReconnected();

        expect(mockHandler.sendFtmsResumeCalled, true);
      });

      test('updates isDeviceConnected when reconnecting from created state', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDeviceDisconnected();

        expect(state.isDeviceConnected, false);

        mockHandler.reset();
        state.onDeviceReconnected();

        expect(state.status, SessionStatus.created);
        expect(state.isDeviceConnected, true);
        expect(mockHandler.startTimerCalled, false);
      });

      test('updates isDeviceConnected when reconnecting from pausedByUser', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onUserPaused();
        state.onDeviceDisconnected();

        expect(state.status, SessionStatus.pausedByUser);
        expect(state.isDeviceConnected, false);

        mockHandler.reset();
        state.onDeviceReconnected();

        expect(state.status, SessionStatus.pausedByUser);
        expect(state.isDeviceConnected, true);
        expect(mockHandler.startTimerCalled, false);
      });

      test('reconnects mid-session and resumes with correct interval', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        // Tick into the second interval
        for (int i = 0; i < 65; i++) {
          state.onTimerTick();
        }
        expect(state.currentIntervalIndex, 1);
        expect(state.currentInterval.title, 'Work');

        // Disconnect
        state.onDeviceDisconnected();
        expect(state.status, SessionStatus.pausedByDisconnection);

        // Reconnect
        mockHandler.reset();
        state.onDeviceReconnected();

        expect(state.status, SessionStatus.running);
        expect(mockHandler.intervalChanges.first.title, 'Work');
      });
    });

    group('timerTick handler calls', () {
      test('calls notifyListeners on normal tick', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onTimerTick();

        expect(mockHandler.notifyListenersCalled, true);
      });

      test('calls intervalChanged when interval changes', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        // Tick to last second of first interval
        for (int i = 0; i < 59; i++) {
          state.onTimerTick();
        }

        // This tick should transition to next interval
        mockHandler.reset();
        state.onTimerTick();

        expect(mockHandler.intervalChangedCalled, true);
        expect(mockHandler.intervalChanges.first.title, 'Work');
      });

      test('calls playWarningSound in last 4 seconds of interval', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        // Tick to second 55 (5 seconds remaining)
        for (int i = 0; i < 55; i++) {
          state.onTimerTick();
        }

        // This tick should call warning sound (4 seconds remaining after tick)
        mockHandler.reset();
        state.onTimerTick();

        expect(mockHandler.playWarningSoundCalled, true);
      });

      test('calls sessionCompletedAwaitingConfirmation and stopTimer when duration reached', () {
        final original = UnitTrainingInterval(duration: 3);
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 3, originalInterval: original),
          ],
        );

        final state = TrainingSessionState.initial(shortSession, handler: mockHandler);
        state.onDataChanged();

        // Tick to last second
        state.onTimerTick();
        state.onTimerTick();

        // This tick should complete
        mockHandler.reset();
        state.onTimerTick();

        expect(mockHandler.stopTimerCalled, true);
        expect(mockHandler.sessionCompletedAwaitingConfirmationCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('calls no handler methods when not running', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onTimerTick();

        expect(mockHandler.calls, isEmpty);
      });

      test('increments elapsed time correctly', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onTimerTick();

        expect(state.elapsedSeconds, 1);
      });

      test('does not call playWarningSound at intervalElapsed=1', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onTimerTick();

        // After tick, intervalElapsed = 1, intervalTimeLeft = 59
        // shouldPlayWarningSound checks intervalTimeLeft <= 4 OR intervalElapsed == 0
        // So no warning sound here (intervalElapsed=1, intervalTimeLeft=59)
        expect(mockHandler.playWarningSoundCalled, false);
      });

      test('calls playWarningSound at exactly 4 seconds remaining', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        // Tick to second 55 (after this tick, intervalTimeLeft will be 4)
        for (int i = 0; i < 55; i++) {
          state.onTimerTick();
        }

        // At 55 ticks, intervalElapsed=55, intervalTimeLeft=5
        mockHandler.reset();
        state.onTimerTick();
        // After tick: intervalElapsed=56, intervalTimeLeft=4
        expect(mockHandler.playWarningSoundCalled, true);
      });

      test('calls playWarningSound at 3, 2, 1 seconds remaining', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        for (int i = 0; i < 56; i++) {
          state.onTimerTick();
        }

        // At 56 ticks: intervalElapsed=56, intervalTimeLeft=4
        // Tick to 57: intervalTimeLeft=3
        mockHandler.reset();
        state.onTimerTick();
        expect(mockHandler.playWarningSoundCalled, true);

        // Tick to 58: intervalTimeLeft=2
        mockHandler.reset();
        state.onTimerTick();
        expect(mockHandler.playWarningSoundCalled, true);

        // Tick to 59: intervalTimeLeft=1
        mockHandler.reset();
        state.onTimerTick();
        expect(mockHandler.playWarningSoundCalled, true);
      });

      test('does not call intervalChanged when staying in same interval', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        // Tick a few times within first interval
        for (int i = 0; i < 30; i++) {
          mockHandler.reset();
          state.onTimerTick();
          expect(mockHandler.intervalChangedCalled, false);
        }
      });

      test('transitions state to completed when duration reached', () {
        final original = UnitTrainingInterval(duration: 2);
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 2, originalInterval: original),
          ],
        );

        final state = TrainingSessionState.initial(shortSession, handler: mockHandler);
        state.onDataChanged();

        state.onTimerTick();
        state.onTimerTick();

        expect(state.status, SessionStatus.completed);
        expect(state.isCompleted, true);
        expect(state.hasEnded, true);
      });

      test('calls no handler methods when paused by user', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onUserPaused();

        mockHandler.reset();
        state.onTimerTick();

        expect(mockHandler.calls, isEmpty);
        expect(state.elapsedSeconds, 0);
      });

      test('calls no handler methods when paused by disconnection', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();
        state.onDeviceDisconnected();

        mockHandler.reset();
        state.onTimerTick();

        expect(mockHandler.calls, isEmpty);
      });

      test('handles multiple interval transitions in sequence', () {
        final originalA = UnitTrainingInterval(title: 'A', duration: 5);
        final originalB = UnitTrainingInterval(title: 'B', duration: 5);
        final originalC = UnitTrainingInterval(title: 'C', duration: 5);
        final multiIntervalSession = ExpandedTrainingSessionDefinition(
          title: 'Multi',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(title: 'A', duration: 5, originalInterval: originalA),
            ExpandedUnitTrainingInterval(title: 'B', duration: 5, originalInterval: originalB),
            ExpandedUnitTrainingInterval(title: 'C', duration: 5, originalInterval: originalC),
          ],
        );

        final state = TrainingSessionState.initial(multiIntervalSession, handler: mockHandler);
        state.onDataChanged();

        // Tick to transition from A to B
        for (int i = 0; i < 4; i++) {
          state.onTimerTick();
        }
        mockHandler.reset();
        state.onTimerTick();
        expect(mockHandler.intervalChanges.first.title, 'B');

        // Tick to transition from B to C
        for (int i = 0; i < 4; i++) {
          state.onTimerTick();
        }
        mockHandler.reset();
        state.onTimerTick();
        expect(mockHandler.intervalChanges.first.title, 'C');
      });
    });

    group('userStopped handler calls', () {
      test('calls stopTimer, sendFtmsStopAndReset, and notifyListeners', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onDataChanged();

        mockHandler.reset();
        state.onUserStopped();

        expect(mockHandler.stopTimerCalled, true);
        expect(mockHandler.sendFtmsStopAndResetCalled, true);
        expect(mockHandler.notifyListenersCalled, true);
      });

      test('calls no handler methods when already ended', () {
        final state = TrainingSessionState.initial(testSession, handler: mockHandler);
        state.onUserStopped();

        mockHandler.reset();
        state.onUserStopped();

        expect(mockHandler.calls, isEmpty);
      });
    });
  });
}
