import 'package:test/test.dart';
import 'package:tshk_core/tshk_core.dart';

void main() {
  final EntitlementPolicy policy = EntitlementPolicy();
  final DateTime now = DateTime.utc(2026, 4, 1, 12);

  MemberRecord member({
    MemberStatus status = MemberStatus.trialing,
    DateTime? trialEndsAt,
    DateTime? paidThrough,
  }) =>
      MemberRecord(
        id: 'member-1',
        email: 'member@example.test',
        status: status,
        trialEndsAt: trialEndsAt ?? now.add(const Duration(days: 7)),
        paidThrough: paidThrough,
        isAdmin: false,
      );

  test('trial expires exactly at trial_ends_at', () {
    final EntitlementResult active = policy.evaluate(
      member(trialEndsAt: now.add(const Duration(microseconds: 1))),
      now: now,
    );
    final EntitlementResult expired = policy.evaluate(
      member(trialEndsAt: now),
      now: now,
    );
    expect(active.hasAccess, isTrue);
    expect(active.status, MemberStatus.trialing);
    expect(expired.hasAccess, isFalse);
    expect(expired.reason, 'expired');
  });

  test('paid-through access and inclusive three-day grace boundary', () {
    final DateTime paidThrough = now.subtract(const Duration(days: 2));
    final EntitlementResult inGrace = policy.evaluate(
      member(status: MemberStatus.active, trialEndsAt: now, paidThrough: paidThrough),
      now: now,
    );
    expect(inGrace.hasAccess, isTrue);
    expect(inGrace.reason, 'payment_grace');
    expect(inGrace.graceEndsAt, paidThrough.add(const Duration(days: 3)));

    final EntitlementResult atGraceBoundary = policy.evaluate(
      member(
        status: MemberStatus.active,
        trialEndsAt: now,
        paidThrough: now.subtract(const Duration(days: 3)),
      ),
      now: now,
    );
    expect(atGraceBoundary.hasAccess, isTrue);

    final EntitlementResult afterBoundary = policy.evaluate(
      member(
        status: MemberStatus.active,
        trialEndsAt: now,
        paidThrough: now.subtract(const Duration(days: 3, microseconds: 1)),
      ),
      now: now,
    );
    expect(afterBoundary.hasAccess, isFalse);
  });

  test('cancellation preserves already-paid access until it lapses', () {
    final EntitlementResult access = policy.evaluate(
      member(
        status: MemberStatus.cancelled,
        trialEndsAt: now.subtract(const Duration(days: 10)),
        paidThrough: now.add(const Duration(days: 5)),
      ),
      now: now,
    );
    expect(access.hasAccess, isTrue);
    expect(access.status, MemberStatus.cancelled);
    expect(access.reason, 'cancelled_paid_access');
  });

  test('calendar month renewal clamps month ends and remains UTC', () {
    expect(
      addCalendarMonthUtc(DateTime.utc(2024, 1, 31, 23, 30)),
      DateTime.utc(2024, 2, 29, 23, 30),
    );
    expect(
      addCalendarMonthUtc(DateTime.utc(2026, 12, 31)),
      DateTime.utc(2027, 1, 31),
    );
  });

  test('offset timestamps are evaluated in UTC, independent of DST', () {
    final DateTime trialEndsAt = DateTime.parse('2026-04-01T14:00:00+02:00');
    final DateTime instant = DateTime.parse('2026-04-01T12:00:00Z');
    final EntitlementResult result = policy.evaluate(
      member(trialEndsAt: trialEndsAt),
      now: instant,
    );
    expect(result.hasAccess, isFalse);
    expect(result.trialEndsAt.isUtc, isTrue);
  });

  test('fixed clock can be advanced deterministically', () {
    final FixedClock clock = FixedClock(now);
    expect(clock.now(), now);
    clock.set(now.add(const Duration(days: 1)));
    expect(clock.now(), now.add(const Duration(days: 1)));
  });
}
