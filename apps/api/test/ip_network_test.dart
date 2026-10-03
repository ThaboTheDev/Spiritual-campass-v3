import 'package:test/test.dart';
import 'package:tshk_api/tshk_api.dart';

void main() {
  test('PayFast published IPv4 CIDR ranges include endpoints, exclude adjacent hosts', () {
    final IpAllowList allowList = IpAllowList(const <String>[
      '197.97.145.144/28',
      '41.74.179.192/27',
      '102.216.36.0/28',
      '102.216.36.128/28',
      '144.126.193.139/32',
    ]);
    expect(allowList.contains('197.97.145.144'), isTrue);
    expect(allowList.contains('197.97.145.159'), isTrue);
    expect(allowList.contains('197.97.145.160'), isFalse);
    expect(allowList.contains('144.126.193.139'), isTrue);
    expect(allowList.contains('144.126.193.140'), isFalse);
    expect(allowList.contains('not-an-ip'), isFalse);
  });
}
