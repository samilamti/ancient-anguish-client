import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'package:ancient_anguish_server/src/config.dart';
import 'package:ancient_anguish_server/src/server.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: '8080', help: 'Port to listen on')
    ..addOption('data-dir', abbr: 'd', defaultsTo: './data', help: 'Data directory for user profiles')
    ..addOption('jwt-secret', help: 'JWT signing secret (or set JWT_SECRET env var)')
    ..addOption('mud-host', defaultsTo: 'ancient.anguish.org', help: 'MUD server host')
    ..addOption('mud-port', defaultsTo: '2222', help: 'MUD server port')
    ..addOption('cors-origins', defaultsTo: '*', help: 'Comma-separated CORS origins')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final results = parser.parse(args);

  if (results.flag('help')) {
    print('Ancient Anguish Web Server\n');
    print(parser.usage);
    exit(0);
  }

  final jwtSecret = results.option('jwt-secret') ??
      Platform.environment['JWT_SECRET'];

  if (jwtSecret == null || jwtSecret.length < 32) {
    stderr.writeln('Error: JWT secret must be at least 32 characters.');
    stderr.writeln('Provide via --jwt-secret or JWT_SECRET environment variable.');
    exit(1);
  }

  final config = ServerConfig(
    port: int.parse(results.option('port')!),
    dataDir: results.option('data-dir')!,
    jwtSecret: jwtSecret,
    mudHost: results.option('mud-host')!,
    mudPort: int.parse(results.option('mud-port')!),
    corsOrigins: results.option('cors-origins')!.split(',').map((s) => s.trim()).toList(),
  );

  // Ensure data directory exists.
  await Directory(config.dataDir).create(recursive: true);

  final handler = await buildServer(config);
  final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, config.port);

  print('Ancient Anguish server listening on port ${server.port}');
  print('Data directory: ${Directory(config.dataDir).absolute.path}');
  print('MUD target: ${config.mudHost}:${config.mudPort}');

  // Graceful shutdown on SIGINT.
  ProcessSignal.sigint.watch().listen((_) async {
    print('\nShutting down...');
    await server.close();
    exit(0);
  });
}
