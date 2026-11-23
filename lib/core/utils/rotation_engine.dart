import 'dart:math';
import 'package:lafz/core/enums/enums.dart';

/// Pure, deterministic rotation engine implementing the shuffle-bag algorithm
/// per PRD Section 5.1 and SRS Section 5.1.
class RotationEngine {
  /// Build eligible set: published & displayable quote IDs from enabled collections,
  /// plus favorites if enabled.
  static List<int> buildEligibleSet({
    required List<int> collectionQuoteIds,
    required List<int> favoriteQuoteIds,
    required bool includeFavorites,
  }) {
    final set = <int>{...collectionQuoteIds};
    if (includeFavorites) {
      set.addAll(favoriteQuoteIds);
    }
    final result = set.toList();
    result.sort(); // Deterministic sorting before shuffle
    return result;
  }

  /// Clean bag: drop quote IDs that are no longer eligible.
  static List<int> cleanBag(List<int> bag, List<int> eligibleSet) {
    final eligibleLookup = eligibleSet.toSet();
    return bag.where((id) => eligibleLookup.contains(id)).toList();
  }

  /// Refill bag with eligible set in shuffled order.
  /// If [seed] is provided, shuffle is completely deterministic.
  static List<int> refillBag(List<int> eligibleSet, [int? seed]) {
    final list = List<int>.from(eligibleSet);
    final random = seed != null ? Random(seed) : Random();
    list.shuffle(random);
    return list;
  }

  /// Select next quote using shuffle bag.
  /// Returns a record with `(int nextQuoteId, List<int> updatedShuffleBag)`.
  /// If eligibleSet is empty, returns (-1, []).
  static (int nextQuoteId, List<int> updatedBag) selectNext({
    required int? currentQuoteId,
    required List<int> shuffleBag,
    required List<int> eligibleSet,
    int? seed,
  }) {
    if (eligibleSet.isEmpty) {
      return (-1, []);
    }

    // 1. Clean the bag of any quotes no longer eligible
    var bag = cleanBag(shuffleBag, eligibleSet);

    // 2. If bag is empty, refill it with shuffled eligible quotes
    if (bag.isEmpty) {
      bag = refillBag(eligibleSet, seed);
    }

    // 3. Take the next ID
    var nextId = bag.removeAt(0);

    // 4. If next equals current quote and alternatives exist, pick another
    if (nextId == currentQuoteId && (bag.isNotEmpty || eligibleSet.length > 1)) {
      if (bag.isNotEmpty) {
        // Swap nextId with first element in bag
        final alternative = bag.removeAt(0);
        bag.insert(0, nextId);
        nextId = alternative;
      } else {
        // Bag just emptied, refill and pick another
        bag = refillBag(eligibleSet, seed);
        if (bag.first == currentQuoteId && bag.length > 1) {
          nextId = bag.removeAt(1);
        } else {
          nextId = bag.removeAt(0);
        }
      }
    }

    return (nextId, bag);
  }

  /// Check if rotation is due based on schedule and current time.
  static bool shouldRotate({
    required DateTime? lastRotation,
    required DateTime? nextRotation,
    required DateTime now,
    required bool enabled,
  }) {
    if (!enabled) return false;
    if (nextRotation == null) return true;
    return now.isAfter(nextRotation) || now.isAtSameMomentAs(nextRotation);
  }

  /// Compute next rotation time based on schedule type.
  static DateTime computeNextRotation({
    required DateTime now,
    required ScheduleType scheduleType,
    required int intervalHours,
    List<int>? specificTimes,
    RoutineType? routine,
  }) {
    switch (scheduleType) {
      case ScheduleType.interval:
        final hours = intervalHours > 0 ? intervalHours : 12;
        return now.add(Duration(hours: hours));

      case ScheduleType.specificTimes:
        if (specificTimes == null || specificTimes.isEmpty) {
          return now.add(Duration(hours: intervalHours));
        }
        final sortedHours = List<int>.from(specificTimes)..sort();
        for (final h in sortedHours) {
          final target = DateTime(now.year, now.month, now.day, h);
          if (target.isAfter(now)) {
            return target;
          }
        }
        // Rollover to first time tomorrow
        return DateTime(
          now.year,
          now.month,
          now.day + 1,
          sortedHours.first,
        );

      case ScheduleType.routine:
        final defaultHour = routine?.defaultHour ?? 6;
        final target = DateTime(now.year, now.month, now.day, defaultHour);
        if (target.isAfter(now)) {
          return target;
        }
        return DateTime(now.year, now.month, now.day + 1, defaultHour);

      case ScheduleType.manual:
        // Far future date for manual
        return now.add(const Duration(days: 365));
    }
  }

  /// Check if an overdue warning should be triggered (> 2x interval).
  static bool isOverdue({
    required DateTime? nextRotation,
    required DateTime now,
    required int intervalHours,
  }) {
    if (nextRotation == null) return false;
    final overdueThreshold = Duration(hours: intervalHours * 2);
    return now.isAfter(nextRotation.add(overdueThreshold));
  }
}
