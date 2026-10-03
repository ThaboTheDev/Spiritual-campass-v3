import 'package:tshk_core/tshk_core.dart';

class Centre {
  const Centre({
    required this.id,
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
  });

  final String id;
  final String name;
  final String region;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;

  factory Centre.fromJson(Map<String, Object?> json, {required String region}) =>
      Centre(
        id: json['id']! as String,
        name: json['name']! as String,
        region: region,
        latitude: (json['latitude']! as num).toDouble(),
        longitude: (json['longitude']! as num).toDouble(),
        address: json['address'] as String?,
        phone: json['phone'] as String?,
      );
}

class CentreCatalog {
  const CentreCatalog({required this.regions, required this.count});

  final List<({String name, List<Centre> centres})> regions;
  final int count;

  factory CentreCatalog.fromJson(Map<String, Object?> json) {
    final List<Object?> rawRegions = json['regions']! as List<Object?>;
    final List<({String name, List<Centre> centres})> regions =
        <({String name, List<Centre> centres})>[];
    for (final Object? value in rawRegions) {
      final Map<String, Object?> region = value! as Map<String, Object?>;
      final String name = region['region']! as String;
      final List<Object?> rawCentres = region['centres']! as List<Object?>;
      regions.add((
        name: name,
        centres: rawCentres
            .map((Object? centre) => Centre.fromJson(
                  centre! as Map<String, Object?>,
                  region: name,
                ))
            .toList(growable: false),
      ));
    }
    return CentreCatalog(
      regions: List<({String name, List<Centre> centres})>.unmodifiable(regions),
      count: (json['count']! as num).toInt(),
    );
  }
}

class CheckoutSession {
  const CheckoutSession({required this.actionUrl, required this.fields});

  final Uri actionUrl;
  final Map<String, String> fields;

  factory CheckoutSession.fromJson(Map<String, Object?> json) {
    final Uri action = Uri.parse(json['actionUrl']! as String);
    if (!action.isScheme('https') ||
        !<String>{'www.payfast.co.za', 'sandbox.payfast.co.za'}
            .contains(action.host) ||
        action.path != '/eng/process') {
      throw const FormatException('Unexpected PayFast checkout URL.');
    }
    final Map<String, Object?> rawFields =
        json['fields']! as Map<String, Object?>;
    return CheckoutSession(
      actionUrl: action,
      fields: Map<String, String>.unmodifiable(<String, String>{
        for (final MapEntry<String, Object?> entry in rawFields.entries)
          entry.key: entry.value! as String,
      }),
    );
  }
}

class MemberSnapshot {
  const MemberSnapshot({
    required this.hasAccess,
    required this.status,
    required this.trialEndsAt,
    required this.reason,
    required this.isAdmin,
    this.paidThrough,
    this.graceEndsAt,
  });

  final bool hasAccess;
  final MemberStatus status;
  final DateTime trialEndsAt;
  final DateTime? paidThrough;
  final DateTime? graceEndsAt;
  final bool isAdmin;
  final String reason;

  factory MemberSnapshot.fromJson(Map<String, Object?> json) => MemberSnapshot(
        hasAccess: json['hasAccess']! as bool,
        status: memberStatusFromString(json['status']! as String),
        trialEndsAt: DateTime.parse(json['trialEndsAt']! as String).toUtc(),
        paidThrough: json['paidThrough'] == null
            ? null
            : DateTime.parse(json['paidThrough']! as String).toUtc(),
        graceEndsAt: json['graceEndsAt'] == null
            ? null
            : DateTime.parse(json['graceEndsAt']! as String).toUtc(),
        isAdmin: json['isAdmin']! as bool,
        reason: json['reason']! as String,
      );
}

class AppApiException implements Exception {
  const AppApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'AppApiException($statusCode): $message';
}
