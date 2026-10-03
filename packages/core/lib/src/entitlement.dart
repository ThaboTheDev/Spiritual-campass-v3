enum MemberStatus { trialing, active, cancelled, expired }

MemberStatus memberStatusFromString(String value) => switch (value) {
      'trialing' => MemberStatus.trialing,
      'active' => MemberStatus.active,
      'cancelled' => MemberStatus.cancelled,
      'expired' => MemberStatus.expired,
      _ => throw FormatException('Unknown member status: $value'),
    };

String memberStatusToString(MemberStatus status) => switch (status) {
      MemberStatus.trialing => 'trialing',
      MemberStatus.active => 'active',
      MemberStatus.cancelled => 'cancelled',
      MemberStatus.expired => 'expired',
    };

class MemberRecord {
  const MemberRecord({
    required this.id,
    required this.email,
    required this.status,
    required this.trialEndsAt,
    required this.paidThrough,
    required this.isAdmin,
  });

  final String id;
  final String? email;
  final MemberStatus status;
  final DateTime trialEndsAt;
  final DateTime? paidThrough;
  final bool isAdmin;
}

class EntitlementResult {
  const EntitlementResult({
    required this.hasAccess,
    required this.status,
    required this.trialEndsAt,
    required this.paidThrough,
    required this.graceEndsAt,
    required this.isAdmin,
    required this.reason,
  });

  final bool hasAccess;
  final MemberStatus status;
  final DateTime trialEndsAt;
  final DateTime? paidThrough;
  final DateTime? graceEndsAt;
  final bool isAdmin;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
        'hasAccess': hasAccess,
        'status': memberStatusToString(status),
        'trialEndsAt': trialEndsAt.toUtc().toIso8601String(),
        'paidThrough': paidThrough?.toUtc().toIso8601String(),
        'graceEndsAt': graceEndsAt?.toUtc().toIso8601String(),
        'isAdmin': isAdmin,
        'reason': reason,
      };
}

abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class FixedClock implements Clock {
  FixedClock(DateTime value) : _value = value.toUtc();

  DateTime _value;

  @override
  DateTime now() => _value;

  void set(DateTime value) => _value = value.toUtc();
}

class EntitlementPolicy {
  const EntitlementPolicy({this.gracePeriod = const Duration(days: 3)});

  final Duration gracePeriod;

  EntitlementResult evaluate(MemberRecord member, {required DateTime now}) {
    final DateTime utcNow = now.toUtc();
    final DateTime trialEndsAt = member.trialEndsAt.toUtc();
    final DateTime? paidThrough = member.paidThrough?.toUtc();
    final DateTime? graceEndsAt =
        paidThrough?.add(gracePeriod).toUtc();
    final bool trialActive = utcNow.isBefore(trialEndsAt);
    final bool withinPaidPeriod =
        paidThrough != null && !utcNow.isAfter(paidThrough);
    final bool withinGrace =
        graceEndsAt != null &&
        utcNow.isAfter(paidThrough!) &&
        !utcNow.isAfter(graceEndsAt);
    final bool hasAccess = trialActive || withinPaidPeriod || withinGrace;

    final String reason;
    if (trialActive) {
      reason = 'trial_active';
    } else if (withinPaidPeriod) {
      reason = member.status == MemberStatus.cancelled
          ? 'cancelled_paid_access'
          : 'paid';
    } else if (withinGrace) {
      reason = 'payment_grace';
    } else if (member.status == MemberStatus.cancelled) {
      reason = 'cancelled';
    } else {
      reason = 'expired';
    }

    final MemberStatus computedStatus;
    if (member.status == MemberStatus.cancelled && !trialActive) {
      computedStatus = MemberStatus.cancelled;
    } else if (trialActive && paidThrough == null) {
      computedStatus = MemberStatus.trialing;
    } else if (hasAccess) {
      computedStatus = MemberStatus.active;
    } else {
      computedStatus = MemberStatus.expired;
    }

    return EntitlementResult(
      hasAccess: hasAccess,
      status: computedStatus,
      trialEndsAt: trialEndsAt,
      paidThrough: paidThrough,
      graceEndsAt: graceEndsAt,
      isAdmin: member.isAdmin,
      reason: reason,
    );
  }
}

/// Add one UTC calendar month while clamping month-end dates (Jan 31 -> Feb
/// 28/29). This avoids DST and duration-based month arithmetic.
DateTime addCalendarMonthUtc(DateTime value) {
  final DateTime utc = value.toUtc();
  final int targetYear = utc.month == 12 ? utc.year + 1 : utc.year;
  final int targetMonth = utc.month == 12 ? 1 : utc.month + 1;
  final int lastDay = DateTime.utc(targetYear, targetMonth + 1, 0).day;
  return DateTime.utc(
    targetYear,
    targetMonth,
    utc.day > lastDay ? lastDay : utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    utc.millisecond,
    utc.microsecond,
  );
}

DateTime trialEndUtc(DateTime startedAt, {Duration trial = const Duration(days: 7)}) =>
    startedAt.toUtc().add(trial);
