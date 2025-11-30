import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/models/device_types.dart';
import 'package:ftms/features/training/model/expanded_training_session_definition.dart';
import 'package:ftms/features/training/model/expanded_unit_training_interval.dart';
import 'package:ftms/features/training/model/session_state.dart';

void main() {
  group('SessionTiming', () {
    late ExpandedTrainingSessionDefinition testSession;

    setUp(() {
      testSession = ExpandedTrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            duration: 60,
            resistanceLevel: 5,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            duration: 120,
            resistanceLevel: 10,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Cooldown',
            duration: 60,
            resistanceLevel: 3,
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

    group('tick', () {
      test('increments elapsed by 1', () {
        final timing = SessionTiming.fromSession(testSession);
        final newTiming = timing.tick();

        expect(newTiming.elapsedSeconds, 1);
      });

      test('keeps same interval within first interval', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Tick 30 times (still in first interval)
        for (int i = 0; i < 30; i++) {
          current = current.tick();
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
          current = current.tick();
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
          current = current.tick();
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
          current = current.tick();
        }

        expect(current.elapsedSeconds, 240);
        expect(current.isDurationReached, true);
      });

      test('isDurationReached returns true at end', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        for (int i = 0; i < 240; i++) {
          current = current.tick();
        }

        expect(current.isDurationReached, true);
        expect(current.sessionTimeLeft, 0);
      });
    });

    group('didIntervalChange', () {
      test('returns false when interval has not changed', () {
        final timing = SessionTiming.fromSession(testSession);
        final after = timing.tick();

        expect(after.didIntervalChange(timing), false);
      });

      test('returns true when interval has changed', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Get to second 59 (last second of first interval)
        for (int i = 0; i < 59; i++) {
          current = current.tick();
        }

        final before = current;
        final after = current.tick(); // This should transition to interval 1

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
          current = current.tick();
        }

        expect(current.shouldPlayWarningSound, false);
      });

      test('returns true in last 4 seconds of interval', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Get to second 56 (4 seconds remaining in first interval)
        for (int i = 0; i < 56; i++) {
          current = current.tick();
        }

        expect(current.intervalTimeLeft, 4);
        expect(current.shouldPlayWarningSound, true);
      });

      test('returns true in last second of interval', () {
        final timing = SessionTiming.fromSession(testSession);
        var current = timing;

        // Get to second 59 (1 second remaining in first interval)
        for (int i = 0; i < 59; i++) {
          current = current.tick();
        }

        expect(current.intervalTimeLeft, 1);
        expect(current.shouldPlayWarningSound, true);
      });
    });

    test('equality works correctly', () {
      final timing1 = SessionTiming.fromSession(testSession);
      final timing2 = SessionTiming.fromSession(testSession);

      expect(timing1, equals(timing2));

      final timing3 = timing1.tick();
      expect(timing1, isNot(equals(timing3)));
    });
  });

  group('TrainingSessionState', () {
    late ExpandedTrainingSessionDefinition testSession;

    setUp(() {
      testSession = ExpandedTrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            duration: 60,
            resistanceLevel: 5,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            duration: 120,
            resistanceLevel: 10,
          ),
        ],
      );
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
        final newState = state.processEvent(SessionEvent.dataChanged);

        expect(newState.status, SessionStatus.running);
        expect(newState.isRunning, true);
        expect(newState.hasStarted, true);
      });

      test('does not transition if already running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        final newState = state.processEvent(SessionEvent.dataChanged);

        expect(newState, same(state));
      });

      test('canProcessEvent returns true from created state', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.canProcessEvent(SessionEvent.dataChanged), true);
      });

      test('canProcessEvent returns false from running state', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        expect(state.canProcessEvent(SessionEvent.dataChanged), false);
      });
    });

    group('state transitions: userPaused', () {
      test('transitions from running to pausedByUser', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        final newState = state.processEvent(SessionEvent.userPaused);

        expect(newState.status, SessionStatus.pausedByUser);
        expect(newState.isPaused, true);
        expect(newState.wasAutoPaused, false);
      });

      test('does not transition if not running', () {
        final state = TrainingSessionState.initial(testSession);

        final newState = state.processEvent(SessionEvent.userPaused);

        expect(newState, same(state));
      });

      test('canProcessEvent returns true from running state', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        expect(state.canProcessEvent(SessionEvent.userPaused), true);
      });

      test('canProcessEvent returns false from created state', () {
        final state = TrainingSessionState.initial(testSession);

        expect(state.canProcessEvent(SessionEvent.userPaused), false);
      });
    });

    group('state transitions: userResumed', () {
      test('transitions from pausedByUser to running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);

        final newState = state.processEvent(SessionEvent.userResumed);

        expect(newState.status, SessionStatus.running);
        expect(newState.isRunning, true);
        expect(newState.isPaused, false);
      });

      test('transitions from pausedByDisconnection to running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);

        final newState = state.processEvent(SessionEvent.userResumed);

        expect(newState.status, SessionStatus.running);
      });

      test('does not transition if not paused', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        final newState = state.processEvent(SessionEvent.userResumed);

        expect(newState, same(state));
      });

      test('canProcessEvent returns true from paused state', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);

        expect(state.canProcessEvent(SessionEvent.userResumed), true);
      });
    });

    group('state transitions: deviceDisconnected', () {
      test('transitions from running to pausedByDisconnection', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        final newState = state.processEvent(SessionEvent.deviceDisconnected);

        expect(newState.status, SessionStatus.pausedByDisconnection);
        expect(newState.isPaused, true);
        expect(newState.wasAutoPaused, true);
        expect(newState.isDeviceConnected, false);
      });

      test('updates connection state from created without changing status', () {
        final state = TrainingSessionState.initial(testSession);

        final newState = state.processEvent(SessionEvent.deviceDisconnected);

        expect(newState.status, SessionStatus.created);
        expect(newState.isDeviceConnected, false);
      });

      test('does not change status if already ended', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userStopped);

        final newState = state.processEvent(SessionEvent.deviceDisconnected);

        expect(newState.status, SessionStatus.stopped);
      });
    });

    group('state transitions: deviceReconnected', () {
      test('transitions from pausedByDisconnection to running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);

        final newState = state.processEvent(SessionEvent.deviceReconnected);

        expect(newState.status, SessionStatus.running);
        expect(newState.isDeviceConnected, true);
        expect(newState.wasAutoPaused, false);
      });

      test('updates connection state from other states without resuming', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);

        // Simulate disconnection that doesn't change status (already paused by user)
        final disconnectedState = TrainingSessionState(
          status: SessionStatus.pausedByUser,
          timing: state.timing,
          isDeviceConnected: false,
          session: testSession,
        );

        final newState =
            disconnectedState.processEvent(SessionEvent.deviceReconnected);

        // Should only update connection state, not status
        expect(newState.status, SessionStatus.pausedByUser);
        expect(newState.isDeviceConnected, true);
      });

      test('canProcessEvent returns true from pausedByDisconnection', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);

        expect(state.canProcessEvent(SessionEvent.deviceReconnected), true);
      });
    });

    group('state transitions: timerTick', () {
      test('increments elapsed time when running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        final newState = state.processEvent(SessionEvent.timerTick);

        expect(newState.elapsedSeconds, 1);
      });

      test('does not tick when paused', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);

        final newState = state.processEvent(SessionEvent.timerTick);

        expect(newState, same(state));
      });

      test('completes session when duration reached', () {
        // Create a very short session
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(
              duration: 3,
            ),
          ],
        );

        var state = TrainingSessionState.initial(shortSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick 3 times to complete
        for (int i = 0; i < 3; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }

        expect(state.status, SessionStatus.completed);
        expect(state.isCompleted, true);
        expect(state.hasEnded, true);
      });

      test('canProcessEvent returns true when running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        expect(state.canProcessEvent(SessionEvent.timerTick), true);
      });

      test('canProcessEvent returns false when paused', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);

        expect(state.canProcessEvent(SessionEvent.timerTick), false);
      });
    });

    group('state transitions: userStopped', () {
      test('transitions from running to stopped', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        final newState = state.processEvent(SessionEvent.userStopped);

        expect(newState.status, SessionStatus.stopped);
        expect(newState.isStopped, true);
        expect(newState.hasEnded, true);
      });

      test('transitions from created to stopped', () {
        final state = TrainingSessionState.initial(testSession);

        final newState = state.processEvent(SessionEvent.userStopped);

        expect(newState.status, SessionStatus.stopped);
      });

      test('transitions from paused to stopped', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);

        final newState = state.processEvent(SessionEvent.userStopped);

        expect(newState.status, SessionStatus.stopped);
      });

      test('does not transition if already stopped', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.userStopped);

        final newState = state.processEvent(SessionEvent.userStopped);

        expect(newState, same(state));
      });

      test('does not transition if already completed', () {
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 1),
          ],
        );

        var state = TrainingSessionState.initial(shortSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.timerTick);

        expect(state.status, SessionStatus.completed);

        final newState = state.processEvent(SessionEvent.userStopped);
        expect(newState, same(state));
      });

      test('canProcessEvent returns false when already ended', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.userStopped);

        expect(state.canProcessEvent(SessionEvent.userStopped), false);
      });
    });

    group('convenience getters', () {
      test('shouldTimerBeActive returns true only when running', () {
        final created = TrainingSessionState.initial(testSession);
        expect(created.shouldTimerBeActive, false);

        final running = created.processEvent(SessionEvent.dataChanged);
        expect(running.shouldTimerBeActive, true);

        final paused = running.processEvent(SessionEvent.userPaused);
        expect(paused.shouldTimerBeActive, false);

        final stopped = created.processEvent(SessionEvent.userStopped);
        expect(stopped.shouldTimerBeActive, false);
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
        var state = TrainingSessionState.initial(testSession);

        // Session created
        expect(state.status, SessionStatus.created);

        // Data changes, session starts
        state = state.processEvent(SessionEvent.dataChanged);
        expect(state.status, SessionStatus.running);

        // Timer ticks a few times
        for (int i = 0; i < 30; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }
        expect(state.elapsedSeconds, 30);

        // User pauses
        state = state.processEvent(SessionEvent.userPaused);
        expect(state.status, SessionStatus.pausedByUser);

        // Timer ticks should not advance while paused
        state = state.processEvent(SessionEvent.timerTick);
        expect(state.elapsedSeconds, 30);

        // User resumes
        state = state.processEvent(SessionEvent.userResumed);
        expect(state.status, SessionStatus.running);

        // Timer continues
        state = state.processEvent(SessionEvent.timerTick);
        expect(state.elapsedSeconds, 31);
      });

      test('disconnection during session', () {
        var state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // Session is running
        for (int i = 0; i < 20; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }

        // Device disconnects
        state = state.processEvent(SessionEvent.deviceDisconnected);
        expect(state.status, SessionStatus.pausedByDisconnection);
        expect(state.wasAutoPaused, true);
        expect(state.isDeviceConnected, false);

        // Timer should not advance
        final beforeTick = state.elapsedSeconds;
        state = state.processEvent(SessionEvent.timerTick);
        expect(state.elapsedSeconds, beforeTick);

        // Device reconnects
        state = state.processEvent(SessionEvent.deviceReconnected);
        expect(state.status, SessionStatus.running);
        expect(state.wasAutoPaused, false);
        expect(state.isDeviceConnected, true);

        // Timer should advance again
        state = state.processEvent(SessionEvent.timerTick);
        expect(state.elapsedSeconds, beforeTick + 1);
      });

      test('interval transitions during full session', () {
        // Session with 3 short intervals
        final multiIntervalSession = ExpandedTrainingSessionDefinition(
          title: 'Multi',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(title: 'A', duration: 5),
            ExpandedUnitTrainingInterval(title: 'B', duration: 5),
            ExpandedUnitTrainingInterval(title: 'C', duration: 5),
          ],
        );

        var state = TrainingSessionState.initial(multiIntervalSession)
            .processEvent(SessionEvent.dataChanged);

        // In first interval
        expect(state.currentIntervalIndex, 0);
        expect(state.currentInterval.title, 'A');

        // Tick through first interval
        for (int i = 0; i < 5; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }

        // Now in second interval
        expect(state.currentIntervalIndex, 1);
        expect(state.currentInterval.title, 'B');
        expect(state.intervalElapsedSeconds, 0);

        // Tick through second interval
        for (int i = 0; i < 5; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }

        // Now in third interval
        expect(state.currentIntervalIndex, 2);
        expect(state.currentInterval.title, 'C');

        // Tick through third interval
        for (int i = 0; i < 5; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }

        // Session completed
        expect(state.status, SessionStatus.completed);
      });
    });

    test('equality works correctly', () {
      final state1 = TrainingSessionState.initial(testSession);
      final state2 = TrainingSessionState.initial(testSession);

      expect(state1, equals(state2));

      final state3 = state1.processEvent(SessionEvent.dataChanged);
      expect(state1, isNot(equals(state3)));
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

  group('SessionEvent', () {
    test('has all expected values', () {
      expect(SessionEvent.values, contains(SessionEvent.dataChanged));
      expect(SessionEvent.values, contains(SessionEvent.userPaused));
      expect(SessionEvent.values, contains(SessionEvent.userResumed));
      expect(SessionEvent.values, contains(SessionEvent.deviceDisconnected));
      expect(SessionEvent.values, contains(SessionEvent.deviceReconnected));
      expect(SessionEvent.values, contains(SessionEvent.timerTick));
      expect(SessionEvent.values, contains(SessionEvent.durationReached));
      expect(SessionEvent.values, contains(SessionEvent.userStopped));
    });
  });

  group('SessionEffect system', () {
    late ExpandedTrainingSessionDefinition testSession;

    setUp(() {
      testSession = ExpandedTrainingSessionDefinition(
        title: 'Test Session',
        ftmsMachineType: DeviceType.rower,
        intervals: [
          ExpandedUnitTrainingInterval(
            title: 'Warmup',
            duration: 60,
            resistanceLevel: 5,
          ),
          ExpandedUnitTrainingInterval(
            title: 'Work',
            duration: 120,
            resistanceLevel: 10,
          ),
        ],
      );
    });

    group('dataChanged effects', () {
      test('emits StartTimer, IntervalChanged, and NotifyListeners', () {
        final state = TrainingSessionState.initial(testSession);
        final result = state.processEventWithEffects(SessionEvent.dataChanged);

        expect(result.effects, contains(isA<StartTimer>()));
        expect(result.effects, contains(isA<IntervalChanged>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('IntervalChanged contains the first interval', () {
        final state = TrainingSessionState.initial(testSession);
        final result = state.processEventWithEffects(SessionEvent.dataChanged);

        final intervalEffect =
            result.effects.whereType<IntervalChanged>().first;
        expect(intervalEffect.newInterval.title, 'Warmup');
      });

      test('emits no effects when already running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result = state.processEventWithEffects(SessionEvent.dataChanged);

        expect(result.effects, isEmpty);
      });
    });

    group('userPaused effects', () {
      test('emits StopTimer, SendFtmsPause, and NotifyListeners', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result = state.processEventWithEffects(SessionEvent.userPaused);

        expect(result.effects, contains(isA<StopTimer>()));
        expect(result.effects, contains(isA<SendFtmsPause>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('emits no effects when not running', () {
        final state = TrainingSessionState.initial(testSession);
        final result = state.processEventWithEffects(SessionEvent.userPaused);

        expect(result.effects, isEmpty);
      });
    });

    group('userResumed effects', () {
      test('emits StartTimer, SendFtmsResume, and NotifyListeners', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);
        final result = state.processEventWithEffects(SessionEvent.userResumed);

        expect(result.effects, contains(isA<StartTimer>()));
        expect(result.effects, contains(isA<SendFtmsResume>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('emits no effects when not paused', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result = state.processEventWithEffects(SessionEvent.userResumed);

        expect(result.effects, isEmpty);
      });
    });

    group('deviceDisconnected effects', () {
      test('emits StopTimer and NotifyListeners when running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.effects, contains(isA<StopTimer>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('emits only NotifyListeners when in created state', () {
        final state = TrainingSessionState.initial(testSession);
        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.effects.whereType<StopTimer>(), isEmpty);
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('transitions to pausedByDisconnection when running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.state.status, SessionStatus.pausedByDisconnection);
        expect(result.state.isDeviceConnected, false);
      });

      test('keeps created status when disconnected before start', () {
        final state = TrainingSessionState.initial(testSession);
        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.state.status, SessionStatus.created);
        expect(result.state.isDeviceConnected, false);
      });

      test('keeps pausedByUser status when disconnected during user pause', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);
        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.state.status, SessionStatus.pausedByUser);
        expect(result.state.isDeviceConnected, false);
        expect(result.effects, contains(isA<NotifyListeners>()));
        expect(result.effects.whereType<StopTimer>(), isEmpty);
      });

      test('emits no effects when session has ended', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userStopped);
        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.effects, isEmpty);
        expect(result.state.status, SessionStatus.stopped);
      });

      test('emits no effects when session is completed', () {
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 1),
          ],
        );

        var state = TrainingSessionState.initial(shortSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.timerTick);

        expect(state.status, SessionStatus.completed);

        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.effects, isEmpty);
      });

      test('does not emit SendFtmsPause (disconnect is not user pause)', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result =
            state.processEventWithEffects(SessionEvent.deviceDisconnected);

        expect(result.effects.whereType<SendFtmsPause>(), isEmpty);
      });
    });

    group('deviceReconnected effects', () {
      test(
          'emits StartTimer, IntervalChanged, and NotifyListeners when auto-paused',
          () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);
        final result =
            state.processEventWithEffects(SessionEvent.deviceReconnected);

        expect(result.effects, contains(isA<StartTimer>()));
        expect(result.effects, contains(isA<IntervalChanged>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('emits only NotifyListeners when not auto-paused', () {
        final state = TrainingSessionState.initial(testSession);
        final result =
            state.processEventWithEffects(SessionEvent.deviceReconnected);

        expect(result.effects.whereType<StartTimer>(), isEmpty);
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('transitions from pausedByDisconnection to running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);
        final result =
            state.processEventWithEffects(SessionEvent.deviceReconnected);

        expect(result.state.status, SessionStatus.running);
        expect(result.state.isDeviceConnected, true);
      });

      test('IntervalChanged contains current interval after reconnection', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);
        final result =
            state.processEventWithEffects(SessionEvent.deviceReconnected);

        final intervalEffect =
            result.effects.whereType<IntervalChanged>().first;
        expect(intervalEffect.newInterval.title, 'Warmup');
      });

      test('does not emit SendFtmsResume (reconnect uses IntervalChanged)', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);
        final result =
            state.processEventWithEffects(SessionEvent.deviceReconnected);

        expect(result.effects.whereType<SendFtmsResume>(), isEmpty);
      });

      test('updates isDeviceConnected when reconnecting from created state', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.deviceDisconnected);

        expect(state.isDeviceConnected, false);

        final result =
            state.processEventWithEffects(SessionEvent.deviceReconnected);

        expect(result.state.status, SessionStatus.created);
        expect(result.state.isDeviceConnected, true);
        expect(result.effects.whereType<StartTimer>(), isEmpty);
      });

      test('updates isDeviceConnected when reconnecting from pausedByUser', () {
        // Manually construct state with pausedByUser and disconnected
        final pausedState = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused)
            .processEvent(SessionEvent.deviceDisconnected);

        expect(pausedState.status, SessionStatus.pausedByUser);
        expect(pausedState.isDeviceConnected, false);

        final result =
            pausedState.processEventWithEffects(SessionEvent.deviceReconnected);

        expect(result.state.status, SessionStatus.pausedByUser);
        expect(result.state.isDeviceConnected, true);
        expect(result.effects.whereType<StartTimer>(), isEmpty);
      });

      test('reconnects mid-session and resumes with correct interval', () {
        var state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick into the second interval
        for (int i = 0; i < 65; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }
        expect(state.currentIntervalIndex, 1);
        expect(state.currentInterval.title, 'Work');

        // Disconnect
        state = state.processEvent(SessionEvent.deviceDisconnected);
        expect(state.status, SessionStatus.pausedByDisconnection);

        // Reconnect
        final result =
            state.processEventWithEffects(SessionEvent.deviceReconnected);

        expect(result.state.status, SessionStatus.running);
        final intervalEffect =
            result.effects.whereType<IntervalChanged>().first;
        expect(intervalEffect.newInterval.title, 'Work');
      });
    });

    group('timerTick effects', () {
      test('emits NotifyListeners on normal tick', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result = state.processEventWithEffects(SessionEvent.timerTick);

        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('emits IntervalChanged when interval changes', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick to last second of first interval
        var current = state;
        for (int i = 0; i < 59; i++) {
          current = current.processEvent(SessionEvent.timerTick);
        }

        // This tick should transition to next interval
        final result = current.processEventWithEffects(SessionEvent.timerTick);

        expect(result.effects, contains(isA<IntervalChanged>()));
        final intervalEffect =
            result.effects.whereType<IntervalChanged>().first;
        expect(intervalEffect.newInterval.title, 'Work');
      });

      test('emits PlayWarningSound in last 4 seconds of interval', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick to second 55 (5 seconds remaining)
        var current = state;
        for (int i = 0; i < 55; i++) {
          current = current.processEvent(SessionEvent.timerTick);
        }

        // This tick should emit warning sound (4 seconds remaining after tick)
        final result = current.processEventWithEffects(SessionEvent.timerTick);

        expect(result.effects, contains(isA<PlayWarningSound>()));
      });

      test('emits SessionCompleted and StopTimer when duration reached', () {
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 3),
          ],
        );

        var state = TrainingSessionState.initial(shortSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick to last second
        state = state.processEvent(SessionEvent.timerTick);
        state = state.processEvent(SessionEvent.timerTick);

        // This tick should complete
        final result = state.processEventWithEffects(SessionEvent.timerTick);

        expect(result.effects, contains(isA<StopTimer>()));
        expect(result.effects, contains(isA<SessionCompleted>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('emits no effects when not running', () {
        final state = TrainingSessionState.initial(testSession);
        final result = state.processEventWithEffects(SessionEvent.timerTick);

        expect(result.effects, isEmpty);
      });

      test('increments elapsed time correctly', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result = state.processEventWithEffects(SessionEvent.timerTick);

        expect(result.state.elapsedSeconds, 1);
      });

      test('emits PlayWarningSound at start of interval (first tick)', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // First tick is at elapsed=1, which is intervalElapsed=1
        // shouldPlayWarningSound is true when intervalElapsed==0 or intervalTimeLeft<=4
        // After first tick, intervalElapsed=1, so warning depends on intervalTimeLeft
        final result = state.processEventWithEffects(SessionEvent.timerTick);

        // After tick, intervalElapsed = 1, intervalTimeLeft = 59
        // shouldPlayWarningSound checks intervalTimeLeft <= 4 OR intervalElapsed == 0
        // So no warning sound here (intervalElapsed=1, intervalTimeLeft=59)
        expect(result.effects.whereType<PlayWarningSound>(), isEmpty);
      });

      test('emits PlayWarningSound at exactly 4 seconds remaining', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick to second 55 (after this tick, intervalTimeLeft will be 4)
        var current = state;
        for (int i = 0; i < 55; i++) {
          current = current.processEvent(SessionEvent.timerTick);
        }

        // At 55 ticks, intervalElapsed=55, intervalTimeLeft=5
        final result = current.processEventWithEffects(SessionEvent.timerTick);
        // After tick: intervalElapsed=56, intervalTimeLeft=4
        expect(result.effects, contains(isA<PlayWarningSound>()));
      });

      test('emits PlayWarningSound at 3, 2, 1 seconds remaining', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        var current = state;
        for (int i = 0; i < 56; i++) {
          current = current.processEvent(SessionEvent.timerTick);
        }

        // At 56 ticks: intervalElapsed=56, intervalTimeLeft=4
        // Tick to 57: intervalTimeLeft=3
        var result = current.processEventWithEffects(SessionEvent.timerTick);
        expect(result.effects, contains(isA<PlayWarningSound>()));
        current = result.state;

        // Tick to 58: intervalTimeLeft=2
        result = current.processEventWithEffects(SessionEvent.timerTick);
        expect(result.effects, contains(isA<PlayWarningSound>()));
        current = result.state;

        // Tick to 59: intervalTimeLeft=1
        result = current.processEventWithEffects(SessionEvent.timerTick);
        expect(result.effects, contains(isA<PlayWarningSound>()));
      });

      test('does not emit IntervalChanged when staying in same interval', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick a few times within first interval
        var current = state;
        for (int i = 0; i < 30; i++) {
          final result = current.processEventWithEffects(SessionEvent.timerTick);
          expect(result.effects.whereType<IntervalChanged>(), isEmpty);
          current = result.state;
        }
      });

      test('transitions state to completed when duration reached', () {
        final shortSession = ExpandedTrainingSessionDefinition(
          title: 'Short',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(duration: 2),
          ],
        );

        var state = TrainingSessionState.initial(shortSession)
            .processEvent(SessionEvent.dataChanged);

        state = state.processEvent(SessionEvent.timerTick);
        final result = state.processEventWithEffects(SessionEvent.timerTick);

        expect(result.state.status, SessionStatus.completed);
        expect(result.state.isCompleted, true);
        expect(result.state.hasEnded, true);
      });

      test('emits no effects when paused by user', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);

        final result = state.processEventWithEffects(SessionEvent.timerTick);

        expect(result.effects, isEmpty);
        expect(result.state.elapsedSeconds, 0);
      });

      test('emits no effects when paused by disconnection', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);

        final result = state.processEventWithEffects(SessionEvent.timerTick);

        expect(result.effects, isEmpty);
      });

      test('handles multiple interval transitions in sequence', () {
        final multiIntervalSession = ExpandedTrainingSessionDefinition(
          title: 'Multi',
          ftmsMachineType: DeviceType.rower,
          intervals: [
            ExpandedUnitTrainingInterval(title: 'A', duration: 5),
            ExpandedUnitTrainingInterval(title: 'B', duration: 5),
            ExpandedUnitTrainingInterval(title: 'C', duration: 5),
          ],
        );

        var state = TrainingSessionState.initial(multiIntervalSession)
            .processEvent(SessionEvent.dataChanged);

        // Tick to transition from A to B
        for (int i = 0; i < 4; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }
        var result = state.processEventWithEffects(SessionEvent.timerTick);
        expect(result.effects.whereType<IntervalChanged>().first.newInterval.title, 'B');
        state = result.state;

        // Tick to transition from B to C
        for (int i = 0; i < 4; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }
        result = state.processEventWithEffects(SessionEvent.timerTick);
        expect(result.effects.whereType<IntervalChanged>().first.newInterval.title, 'C');
      });
    });

    group('userStopped effects', () {
      test('emits StopTimer, SendFtmsStopAndReset, and NotifyListeners', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result = state.processEventWithEffects(SessionEvent.userStopped);

        expect(result.effects, contains(isA<StopTimer>()));
        expect(result.effects, contains(isA<SendFtmsStopAndReset>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('emits no effects when already ended', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.userStopped);
        final result = state.processEventWithEffects(SessionEvent.userStopped);

        expect(result.effects, isEmpty);
      });
    });

    group('durationReached effects', () {
      test('emits StopTimer, SessionCompleted, and NotifyListeners when running', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.effects, contains(isA<StopTimer>()));
        expect(result.effects, contains(isA<SessionCompleted>()));
        expect(result.effects, contains(isA<NotifyListeners>()));
      });

      test('transitions state to completed', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.state.status, SessionStatus.completed);
        expect(result.state.isCompleted, true);
        expect(result.state.hasEnded, true);
      });

      test('emits no effects when not running', () {
        final state = TrainingSessionState.initial(testSession);
        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.effects, isEmpty);
      });

      test('emits no effects when paused by user', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userPaused);
        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.effects, isEmpty);
        expect(result.state.status, SessionStatus.pausedByUser);
      });

      test('emits no effects when paused by disconnection', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.deviceDisconnected);
        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.effects, isEmpty);
        expect(result.state.status, SessionStatus.pausedByDisconnection);
      });

      test('emits no effects when already completed', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.durationReached);

        expect(state.status, SessionStatus.completed);

        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.effects, isEmpty);
      });

      test('emits no effects when already stopped', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged)
            .processEvent(SessionEvent.userStopped);
        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.effects, isEmpty);
      });

      test('does not emit SendFtmsStopAndReset (completion is not stop)', () {
        final state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);
        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.effects.whereType<SendFtmsStopAndReset>(), isEmpty);
      });

      test('preserves timing state when completing', () {
        var state = TrainingSessionState.initial(testSession)
            .processEvent(SessionEvent.dataChanged);

        // Advance time
        for (int i = 0; i < 30; i++) {
          state = state.processEvent(SessionEvent.timerTick);
        }

        final result =
            state.processEventWithEffects(SessionEvent.durationReached);

        expect(result.state.elapsedSeconds, 30);
        expect(result.state.timing, state.timing);
      });
    });

    group('StateTransitionResult', () {
      test('unchanged factory creates result with empty effects', () {
        final state = TrainingSessionState.initial(testSession);
        final result = StateTransitionResult.unchanged(state);

        expect(result.state, same(state));
        expect(result.effects, isEmpty);
      });

      test('processEvent returns same state as processEventWithEffects', () {
        final state = TrainingSessionState.initial(testSession);

        final stateOnly = state.processEvent(SessionEvent.dataChanged);
        final resultWithEffects =
            state.processEventWithEffects(SessionEvent.dataChanged);

        expect(stateOnly, equals(resultWithEffects.state));
      });
    });
  });
}
