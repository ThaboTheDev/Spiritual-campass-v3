import 'dart:io';

import 'package:shelf/shelf.dart';

import 'ip_network.dart';

class ClientIpResolver {
  ClientIpResolver({required Iterable<String> trustedProxyCidrs})
      : _trustedProxies = IpAllowList(trustedProxyCidrs);

  final IpAllowList _trustedProxies;

  String resolve(Request request) {
    final Object? connectionInfo = request.context['shelf.io.connection_info'];
    final InternetAddress? peer = connectionInfo is HttpConnectionInfo
        ? connectionInfo.remoteAddress
        : null;
    final String? forwarded = request.headers['x-forwarded-for'];
    if (peer == null || !_trustedProxies.contains(peer.address) || forwarded == null) {
      return peer?.address ?? 'unknown';
    }

    final List<InternetAddress> chain = <InternetAddress>[];
    for (final String entry in forwarded.split(',')) {
      final InternetAddress? address = InternetAddress.tryParse(entry.trim());
      if (address == null) return peer.address;
      chain.add(address);
    }
    chain.add(peer);
    for (int index = chain.length - 1; index >= 0; index--) {
      if (!_trustedProxies.networks.any((IpCidr cidr) => cidr.contains(chain[index]))) {
        return chain[index].address;
      }
    }
    return chain.first.address;
  }
}
