import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:tshk_api/tshk_api.dart';

Future<void> main() async {
  final ApiConfig config = ApiConfig.fromEnvironment();
  final handler = createProductionHandler(config: config);
  final HttpServer server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    config.port,
    poweredByHeader: null,
  );
  server.autoCompress = true;
  stdout.writeln('TSHK Compass API listening on 0.0.0.0:${server.port}');
}
