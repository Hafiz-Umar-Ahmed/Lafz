import 'package:flutter_test/flutter_test.dart';
import 'package:lafz/core/enums/enums.dart';
import 'package:lafz/core/utils/rotation_engine.dart';

void main() {
  group('RotationEngine Tests (PRD 5.1 & SRS 5.1)', () {
    test('buildEligibleSet combines collections and favorites deterministically', () {
      final collectionQuotes = [5, 12, 3, 19];
      final favoriteQuotes = [3, 42, 1];

      // With favorites included
      final eligibleWithFav = RotationEngine.buildEligibleSet(
        collectionQuoteIds: collectionQuotes,
        favoriteQuoteIds: favoriteQuotes,
        includeFavorites: true,
      );

      expect(eligibleWithFav, [1, 3, 5, 12, 19, 42]);

      // Without favorites
      final eligibleWithoutFav = RotationEngine.buildEligibleSet(
        collectionQuoteIds: collectionQuotes,
        favoriteQuoteIds: favoriteQuotes,
        includeFavorites: false,
      );

      expect(eligibleWithoutFav, [3, 5, 12, 19]);
    });

    test('cleanBag drops IDs that are no longer eligible', () {
      final bag = [1, 5, 9, 12, 15];
      final eligible = [1, 12, 20];

      final cleaned = RotationEngine.cleanBag(bag, eligible);
      expect(cleaned, [1, 12]);
    });

    test('refillBag is deterministic when seed is provided', () {
      final eligible = [1, 2, 3, 4, 5, 6, 7, 8];

      final bag1 = RotationEngine.refillBag(eligible, 42);
      final bag2 = RotationEngine.refillBag(eligible, 42);

      expect(bag1, bag2);
      expect(bag1.length, eligible.length);
      expect(bag1.toSet(), eligible.toSet());
    });

    test('selectNext picks items sequentially from bag and refills on exhaustion', () {
      final eligible = [10, 20, 30];
      var bag = <int>[];

      final (q1, bag1) = RotationEngine.selectNext(
        currentQuoteId: null,
        shuffleBag: bag,
        eligibleSet: eligible,
        seed: 123,
      );

      expect(eligible.contains(q1), isTrue);
      expect(bag1.length, 2);

      final (q2, bag2) = RotationEngine.selectNext(
        currentQuoteId: q1,
        shuffleBag: bag1,
        eligibleSet: eligible,
        seed: 123,
      );

      expect(q2, isNot(equals(q1)));
      expect(bag2.length, 1);

      final (q3, bag3) = RotationEngine.selectNext(
        currentQuoteId: q2,
        shuffleBag: bag2,
        eligibleSet: eligible,
        seed: 123,
      );

      expect(bag3.isEmpty, isTrue);

      // Next pick refills the bag
      final (q4, bag4) = RotationEngine.selectNext(
        currentQuoteId: q3,
        shuffleBag: bag3,
        eligibleSet: eligible,
        seed: 123,
      );

      expect(eligible.contains(q4), isTrue);
      expect(bag4.length, 2);
    });

    test('selectNext avoids repeating current quote when alternatives exist', () {
      final eligible = [1, 2];
      // Bag has [1], current is 1 -> algorithm avoids 1
      final (nextQuote, updatedBag) = RotationEngine.selectNext(
        currentQuoteId: 1,
        shuffleBag: [1, 2],
        eligibleSet: eligible,
        seed: 42,
      );

      expect(nextQuote, 2);
      expect(updatedBag, [1]);
    });

    test('shouldRotate checks time thresholds correctly', () {
      final now = DateTime(2026, 11, 19, 14, 0);

      // When disabled
      expect(
        RotationEngine.shouldRotate(
          lastRotation: now.subtract(const Duration(hours: 24)),
          nextRotation: now.subtract(const Duration(hours: 1)),
          now: now,
          enabled: false,
        ),
        isFalse,
      );

      // When nextRotation is null -> should rotate
      expect(
        RotationEngine.shouldRotate(
          lastRotation: null,
          nextRotation: null,
          now: now,
          enabled: true,
        ),
        isTrue,
      );

      // When nextRotation is past
      expect(
        RotationEngine.shouldRotate(
          lastRotation: now.subtract(const Duration(hours: 13)),
          nextRotation: now.subtract(const Duration(hours: 1)),
          now: now,
          enabled: true,
        ),
        isTrue,
      );

      // When nextRotation is in future
      expect(
        RotationEngine.shouldRotate(
          lastRotation: now.subtract(const Duration(hours: 2)),
          nextRotation: now.add(const Duration(hours: 10)),
          now: now,
          enabled: true,
        ),
        isFalse,
      );
    });

    test('computeNextRotation handles interval, specific times and routine', () {
      final now = DateTime(2026, 11, 19, 10, 0);

      // Interval 12h
      final nextInterval = RotationEngine.computeNextRotation(
        now: now,
        scheduleType: ScheduleType.interval,
        intervalHours: 12,
      );
      expect(nextInterval, DateTime(2026, 11, 19, 22, 0));

      // Specific times: 8:00, 14:00, 20:00 -> at 10:00 should pick 14:00
      final nextSpecific = RotationEngine.computeNextRotation(
        now: now,
        scheduleType: ScheduleType.specificTimes,
        intervalHours: 12,
        specificTimes: [8, 14, 20],
      );
      expect(nextSpecific, DateTime(2026, 11, 19, 14, 0));

      // Specific times rollover to tomorrow
      final lateNow = DateTime(2026, 11, 19, 22, 0);
      final nextRollover = RotationEngine.computeNextRotation(
        now: lateNow,
        scheduleType: ScheduleType.specificTimes,
        intervalHours: 12,
        specificTimes: [8, 14, 20],
      );
      expect(nextRollover, DateTime(2026, 11, 20, 8, 0));

      // Routine: Evening (18:00)
      final nextRoutine = RotationEngine.computeNextRotation(
        now: now,
        scheduleType: ScheduleType.routine,
        intervalHours: 12,
        routine: RoutineType.evening,
      );
      expect(nextRoutine, DateTime(2026, 11, 19, 18, 0));
    });

    test('isOverdue flags when overdue by more than 2x interval', () {
      final nextTime = DateTime(2026, 11, 19, 10, 0);
      final interval = 12; // 2x is 24 hours -> overdue at 2026-11-20 10:00:01

      // 10 hours late: not overdue yet
      expect(
        RotationEngine.isOverdue(
          nextRotation: nextTime,
          now: DateTime(2026, 11, 19, 20, 0),
          intervalHours: interval,
        ),
        isFalse,
      );

      // 25 hours late: overdue!
      expect(
        RotationEngine.isOverdue(
          nextRotation: nextTime,
          now: DateTime(2026, 11, 20, 11, 0),
          intervalHours: interval,
        ),
        isTrue,
      );
    });
  });
}
