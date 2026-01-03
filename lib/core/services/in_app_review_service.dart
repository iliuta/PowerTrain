import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class InAppReviewService {
  static final InAppReviewService _instance = InAppReviewService._internal();
  
  factory InAppReviewService() {
    return _instance;
  }
  
  InAppReviewService._internal();

  static const String _usageCountKey = 'usage_count';
  static const String _reviewTargetKey = 'review_target_count';
  static const String _reviewCompletedKey = 'review_completed';

  /// Increments and returns the current usage count
  Future<int> incrementUsageCount() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCount = prefs.getInt(_usageCountKey) ?? 0;
    currentCount++;
    await prefs.setInt(_usageCountKey, currentCount);
    return currentCount;
  }

  /// Gets the current usage count without incrementing
  Future<int> getUsageCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_usageCountKey) ?? 0;
  }

  /// Resets the usage count to 0
  Future<void> resetUsageCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_usageCountKey, 0);
    //await prefs.remove(_reviewTargetKey);
  }

  /// Gets or generates a random review target count (5-10)
  Future<int> getOrGenerateReviewTarget() async {
    final prefs = await SharedPreferences.getInstance();
    int targetCount = prefs.getInt(_reviewTargetKey) ?? 0;
    
    if (targetCount == 0) {
      targetCount = _generateRandomTarget();
      await prefs.setInt(_reviewTargetKey, targetCount);
    }
    
    return targetCount;
  }

  /// Generates a new random target count and saves it
  Future<int> generateNewReviewTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final newTarget = _generateRandomTarget();
    await prefs.setInt(_reviewTargetKey, newTarget);
    return newTarget;
  }

  /// Removes the review target (user has rated, no more prompts)
  Future<void> clearReviewTarget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reviewTargetKey);
  }

  /// Checks if review should be shown based on current usage
  /// Returns false immediately if user has already completed a review
  Future<bool> shouldShowReview() async {
    final prefs = await SharedPreferences.getInstance();

    // CRITICAL: If user has already completed the review, never show again
    // This check happens before any other logic to ensure maximum efficiency
    final reviewCompleted = prefs.getBool(_reviewCompletedKey) ?? false;
    if (reviewCompleted) {
      return false;
    }

    final usageCount = await getUsageCount();
    final targetCount = await getOrGenerateReviewTarget();
    return usageCount >= targetCount;
  }

  /// Handles dismissal: resets usage count and generates new target
  Future<void> handleReviewDismissal() async {
    await resetUsageCount();
    await generateNewReviewTarget();
  }

  /// Handles successful review: marks as completed and resets all counters
  Future<void> handleReviewCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewCompletedKey, true);
    // Reset all counters when review is completed
    await resetUsageCount();
    await clearReviewTarget();
  }

  /// Generates a random number between 5 and 10 inclusive
  int _generateRandomTarget() {
    return 5 + Random().nextInt(6); // 5 + (0-5) = 5-10
  }

  /// Resets all review-related data (useful for testing)
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usageCountKey);
    await prefs.remove(_reviewTargetKey);
    await prefs.remove(_reviewCompletedKey);
  }
}