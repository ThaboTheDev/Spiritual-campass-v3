import 'package:flutter_test/flutter_test.dart';
import 'package:tshk_compass_app/src/data/app_models.dart';
import 'package:tshk_core/tshk_core.dart';

void main() {
  test('member response dates are parsed as UTC and status is typed', () {
    final MemberSnapshot member = MemberSnapshot.fromJson(<String, Object?>{
      'hasAccess': true,
      'status': 'active',
      'trialEndsAt': '2026-10-10T12:00:00Z',
      'paidThrough': '2026-11-10T12:00:00Z',
      'graceEndsAt': '2026-11-13T12:00:00Z',
      'isAdmin': false,
      'reason': 'paid',
    });
    expect(member.status, MemberStatus.active);
    expect(member.hasAccess, isTrue);
    expect(member.trialEndsAt.isUtc, isTrue);
    expect(member.paidThrough, DateTime.utc(2026, 11, 10, 12));
  });

  test('empty centre catalog remains empty rather than inventing rows', () {
    final CentreCatalog catalog = CentreCatalog.fromJson(<String, Object?>{
      'regions': <Object?>[],
      'count': 0,
    });
    expect(catalog.count, 0);
    expect(catalog.regions, isEmpty);
  });

  test('centre response preserves region grouping and coordinates', () {
    final CentreCatalog catalog = CentreCatalog.fromJson(<String, Object?>{
      'regions': <Object?>[
        <String, Object?>{
          'region': 'Maseru',
          'centres': <Object?>[
            <String, Object?>{
              'id': '1',
              'name': 'Example',
              'region': 'Maseru',
              'address': null,
              'phone': null,
              'latitude': -29.3,
              'longitude': 27.5,
            },
          ],
        },
      ],
      'count': 1,
    });
    expect(catalog.regions.single.name, 'Maseru');
    expect(catalog.regions.single.centres.single.latitude, -29.3);
  });
}
