import 'package:flutter_test/flutter_test.dart';
import 'package:ftms/core/services/in_app_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('InAppReviewService', () {
    late InAppReviewService service;

    setUp(() async {
      // Clear all SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      // Reset the singleton instance for testing
      // Since it's a singleton, we need to ensure clean state
      service = InAppReviewService();
    });

    group('Singleton Pattern', () {
      test('should return the same instance', () {
        final instance1 = InAppReviewService();
        final instance2 = InAppReviewService();

        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Usage Count Management', () {
      test('should return 0 for initial usage count', () async {
        final count = await service.getUsageCount();
        expect(count, equals(0));
      });

      test('should increment usage count from 0 to 1', () async {
        final newCount = await service.incrementUsageCount();
        expect(newCount, equals(1));

        final currentCount = await service.getUsageCount();
        expect(currentCount, equals(1));
      });

      test('should increment usage count multiple times', () async {
        await service.incrementUsageCount(); // 1
        await service.incrementUsageCount(); // 2
        final newCount = await service.incrementUsageCount(); // 3

        expect(newCount, equals(3));

        final currentCount = await service.getUsageCount();
        expect(currentCount, equals(3));
      });

      test('should reset usage count to 0', () async {
        await service.incrementUsageCount();
        await service.incrementUsageCount();
        expect(await service.getUsageCount(), equals(2));

        await service.resetUsageCount();
        expect(await service.getUsageCount(), equals(0));
      });
    });

    group('Review Target Management', () {
      test('should generate and return review target when none exists', () async {
        final target = await service.getOrGenerateReviewTarget();

        // Target should be between 5 and 10 inclusive
        expect(target, greaterThanOrEqualTo(5));
        expect(target, lessThanOrEqualTo(10));
      });

      test('should return existing review target on subsequent calls', () async {
        final firstTarget = await service.getOrGenerateReviewTarget();
        final secondTarget = await service.getOrGenerateReviewTarget();

        expect(secondTarget, equals(firstTarget));
      });

      test('should generate new review target when requested', () async {
        final newTarget = await service.generateNewReviewTarget();

        // New target should be in valid range
        expect(newTarget, greaterThanOrEqualTo(5));
        expect(newTarget, lessThanOrEqualTo(10));

        // getOrGenerateReviewTarget should now return the new target
        final currentTarget = await service.getOrGenerateReviewTarget();
        expect(currentTarget, equals(newTarget));
      });

      test('should clear review target', () async {
        await service.getOrGenerateReviewTarget(); // Creates a target
        expect(await service.getOrGenerateReviewTarget(), isNotNull);

        await service.clearReviewTarget();

        // After clearing, getOrGenerateReviewTarget should create a new one
        final newTarget = await service.getOrGenerateReviewTarget();
        expect(newTarget, greaterThanOrEqualTo(5));
        expect(newTarget, lessThanOrEqualTo(10));
      });
    });

    group('Review Logic', () {
      test('should not show review when usage count is below target', () async {
        // Set up a target of 7
        SharedPreferences.setMockInitialValues({'review_target_count': 7});

        // Set usage count to 3
        await service.incrementUsageCount();
        await service.incrementUsageCount();
        await service.incrementUsageCount();

        final shouldShow = await service.shouldShowReview();
        expect(shouldShow, isFalse);
      });

      test('should show review when usage count equals target', () async {
        // Set up a target of 3
        SharedPreferences.setMockInitialValues({'review_target_count': 3});

        // Set usage count to 3
        await service.incrementUsageCount();
        await service.incrementUsageCount();
        await service.incrementUsageCount();

        final shouldShow = await service.shouldShowReview();
        expect(shouldShow, isTrue);
      });

      test('should show review when usage count exceeds target', () async {
        // Set up a target of 3
        SharedPreferences.setMockInitialValues({'review_target_count': 3});

        // Set usage count to 5
        await service.incrementUsageCount();
        await service.incrementUsageCount();
        await service.incrementUsageCount();
        await service.incrementUsageCount();
        await service.incrementUsageCount();

        final shouldShow = await service.shouldShowReview();
        expect(shouldShow, isTrue);
      });

      test('should not show review when review is completed', () async {
        // Set up usage count of 10 and target of 5
        SharedPreferences.setMockInitialValues({
          'usage_count': 10,
          'review_target_count': 5
        });

        // Initially should show review
        expect(await service.shouldShowReview(), isTrue);

        // After completing review, should not show review again
        await service.handleReviewCompleted();
        expect(await service.shouldShowReview(), isFalse);
      });
    });

    group('Review Event Handling', () {
      test('should handle review dismissal by resetting count and generating new target', () async {
        // Set up initial state
        await service.incrementUsageCount();
        await service.incrementUsageCount();

        expect(await service.getUsageCount(), equals(2));

        // Handle dismissal
        await service.handleReviewDismissal();

        // Usage count should be reset to 0
        expect(await service.getUsageCount(), equals(0));

        // New target should be generated
        final newTarget = await service.getOrGenerateReviewTarget();
        expect(newTarget, greaterThanOrEqualTo(5));
        expect(newTarget, lessThanOrEqualTo(10));
      });

      test('should handle review completion by clearing target', () async {
        // Set up a target
        final originalTarget = await service.getOrGenerateReviewTarget();
        expect(originalTarget, greaterThanOrEqualTo(5));

        // Handle completion
        await service.handleReviewCompleted();

        // Target should be cleared, so getOrGenerateReviewTarget creates new one
        final newTarget = await service.getOrGenerateReviewTarget();
        expect(newTarget, greaterThanOrEqualTo(5));
        expect(newTarget, lessThanOrEqualTo(10));
      });
    });

    group('Reset Functionality', () {
      test('should reset all data', () async {
        // Set up some data
        await service.incrementUsageCount();
        await service.incrementUsageCount();
        final target = await service.getOrGenerateReviewTarget();

        expect(await service.getUsageCount(), equals(2));
        expect(target, greaterThanOrEqualTo(5));

        // Reset all
        await service.resetAll();

        // All data should be cleared
        expect(await service.getUsageCount(), equals(0));

        // getOrGenerateReviewTarget should create new target
        final newTarget = await service.getOrGenerateReviewTarget();
        expect(newTarget, greaterThanOrEqualTo(5));
        expect(newTarget, lessThanOrEqualTo(10));
      });
    });

    group('Random Target Generation', () {
      test('should generate different targets over multiple calls', () async {
        final targets = <int>[];

        for (int i = 0; i < 20; i++) {
          await service.resetAll();
          final target = await service.getOrGenerateReviewTarget();
          targets.add(target);
        }

        // With random generation, we should get some variety
        // (though statistically, duplicates are possible but unlikely)
        final uniqueTargets = targets.toSet();
        expect(uniqueTargets.length, greaterThan(1)); // Should have some variety
      });
    });

    group('Integration Scenarios', () {
      test('should handle complete review flow', () async {
        // Set a known target for predictable testing
        SharedPreferences.setMockInitialValues({'review_target_count': 5});

        // 1. Initial state
        expect(await service.getUsageCount(), equals(0));
        expect(await service.shouldShowReview(), isFalse);

        // 2. Increment usage to reach target
        for (int i = 0; i < 5; i++) {
          await service.incrementUsageCount();
        }
        expect(await service.getUsageCount(), equals(5));

        // 3. Should show review now
        expect(await service.shouldShowReview(), isTrue);

        // 4. User dismisses review
        await service.handleReviewDismissal();
        expect(await service.getUsageCount(), equals(0));
        expect(await service.shouldShowReview(), isFalse);

        // 5. Increment usage enough times to reach any possible target (5-10)
        for (int i = 0; i < 10; i++) {
          await service.incrementUsageCount();
        }
        expect(await service.shouldShowReview(), isTrue);

        // 6. User completes review
        await service.handleReviewCompleted();
        expect(await service.getUsageCount(), equals(0)); // Usage count should be reset
        expect(await service.shouldShowReview(), isFalse);
      });

      test('should handle edge case of target being 5', () async {
        SharedPreferences.setMockInitialValues({'review_target_count': 5});

        // Increment to exactly 5
        for (int i = 0; i < 5; i++) {
          await service.incrementUsageCount();
        }

        expect(await service.shouldShowReview(), isTrue);
      });

      test('should never show review after completion', () async {
        // Set review as completed
        SharedPreferences.setMockInitialValues({'review_completed': true});

        // Even with high usage count, should not show review
        for (int i = 0; i < 20; i++) {
          await service.incrementUsageCount();
        }

        expect(await service.shouldShowReview(), isFalse);
      });
    });
  });
}