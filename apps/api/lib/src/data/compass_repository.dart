import 'package:supabase/supabase.dart';
import 'package:tshk_core/tshk_core.dart';

import '../auth/jwt_verifier.dart';

class CentreRow {
  const CentreRow({
    required this.id,
    required this.name,
    required this.region,
    required this.address,
    required this.phone,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String region;
  final String? address;
  final String? phone;
  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'region': region,
        'address': address,
        'phone': phone,
        'latitude': latitude,
        'longitude': longitude,
      };
}

abstract interface class CompassRepository {
  Future<MemberRecord> ensureMember(AuthPrincipal principal);
  Future<List<CentreRow>> listCentres();
  Future<bool> applyPayFastItn({
    required String paymentId,
    required String memberId,
    required int amountCents,
    required String status,
    required Map<String, Object?> raw,
    required String? token,
    required bool trialSetup,
    required DateTime now,
  });
  Future<void> deleteAuthUser(String memberId);
}

class SupabaseCompassRepository implements CompassRepository {
  SupabaseCompassRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<MemberRecord> ensureMember(AuthPrincipal principal) async {
    await _client.from('members').upsert(
      <String, Object?>{'id': principal.id, 'email': principal.email},
      onConflict: 'id',
      ignoreDuplicates: true,
    );
    final Map<String, dynamic>? row = await _client
        .from('members')
        .select('id,email,status,trial_ends_at,paid_through,is_admin')
        .eq('id', principal.id)
        .maybeSingle();
    if (row == null) throw StateError('Member row was not created');
    return _memberFromRow(row);
  }

  @override
  Future<List<CentreRow>> listCentres() async {
    final List<Map<String, dynamic>> rows = await _client
        .from('centres')
        .select('id,name,region,address,phone,latitude,longitude')
        .order('region')
        .order('name');
    return rows.map(_centreFromRow).toList(growable: false);
  }

  @override
  Future<bool> applyPayFastItn({
    required String paymentId,
    required String memberId,
    required int amountCents,
    required String status,
    required Map<String, Object?> raw,
    required String? token,
    required bool trialSetup,
    required DateTime now,
  }) async {
    final Object? result = await _client.rpc(
      'apply_payfast_itn',
      params: <String, Object?>{
        'p_pf_payment_id': paymentId,
        'p_member_id': memberId,
        'p_amount': (amountCents / 100).toStringAsFixed(2),
        'p_status': status,
        'p_raw': raw,
        'p_token': token,
        'p_trial_setup': trialSetup,
        'p_now': now.toUtc().toIso8601String(),
      },
    );
    return result == true;
  }

  @override
  Future<void> deleteAuthUser(String memberId) async {
    await _client.auth.admin.deleteUser(memberId);
  }

  static MemberRecord _memberFromRow(Map<String, dynamic> row) => MemberRecord(
        id: row['id'] as String,
        email: row['email'] as String?,
        status: memberStatusFromString(row['status'] as String),
        trialEndsAt: DateTime.parse(row['trial_ends_at'] as String).toUtc(),
        paidThrough: row['paid_through'] == null
            ? null
            : DateTime.parse(row['paid_through'] as String).toUtc(),
        isAdmin: row['is_admin'] as bool? ?? false,
      );

  static CentreRow _centreFromRow(Map<String, dynamic> row) => CentreRow(
        id: row['id'] as String,
        name: row['name'] as String,
        region: row['region'] as String,
        address: row['address'] as String?,
        phone: row['phone'] as String?,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
      );
}
