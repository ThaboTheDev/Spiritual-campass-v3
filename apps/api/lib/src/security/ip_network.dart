import 'dart:io';

class IpCidr {
  IpCidr._(this.address, this.prefixLength);

  final InternetAddress address;
  final int prefixLength;

  factory IpCidr.parse(String value) {
    final List<String> parts = value.split('/');
    final InternetAddress? address = InternetAddress.tryParse(parts.first);
    if (address == null || parts.length > 2) {
      throw FormatException('Invalid CIDR: $value');
    }
    final int maxPrefix = address.type == InternetAddressType.IPv4 ? 32 : 128;
    final int prefix = parts.length == 2 ? int.parse(parts[1]) : maxPrefix;
    if (prefix < 0 || prefix > maxPrefix) throw FormatException('Invalid CIDR: $value');
    return IpCidr._(address, prefix);
  }

  bool contains(InternetAddress candidate) {
    if (candidate.type != address.type) return false;
    final List<int> network = address.rawAddress;
    final List<int> value = candidate.rawAddress;
    final int wholeBytes = prefixLength ~/ 8;
    final int remainingBits = prefixLength % 8;
    for (int index = 0; index < wholeBytes; index++) {
      if (network[index] != value[index]) return false;
    }
    if (remainingBits == 0) return true;
    final int mask = (0xFF << (8 - remainingBits)) & 0xFF;
    return (network[wholeBytes] & mask) == (value[wholeBytes] & mask);
  }
}

class IpAllowList {
  IpAllowList(Iterable<String> cidrs)
      : networks = List<IpCidr>.unmodifiable(cidrs.map(IpCidr.parse)) {
    if (networks.isEmpty) throw ArgumentError('At least one CIDR is required');
  }

  final List<IpCidr> networks;

  bool contains(String value) {
    final InternetAddress? address = InternetAddress.tryParse(value.trim());
    if (address == null) return false;
    return networks.any((IpCidr network) => network.contains(address));
  }
}
