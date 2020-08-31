import 'dart:async';
import 'dart:convert';
import "dart:io";

import "package:args/command_runner.dart";
import 'package:io/ansi.dart';
import 'package:socky_cli/commands/socky_yaml.dart';

import 'pub.dart';

class DevCommand extends Command {
  // final KeyCommand _key = new KeyCommand();

  @override
  String get name => "dev";

  @override
  String get description => "Starts the Socky Server in dev mode";

  DevCommand() {}

  @override
  run() async {
    Directory projectDir = new Directory('.');

    final sockyYaml = File('${projectDir.path}/socky.yaml');

    if (!sockyYaml.existsSync()) {
      throw UsageException('socky.yaml file not found', '');
    }

    final meta = loadMetadata(sockyYaml);

    print('project "${meta.name}"');

    print("Running Socky Server in dev mode in ${projectDir.absolute.path}...");

    preBuild(projectDir, 'server').catchError((_) => null);
  }

  Future preBuild(Directory projectDir, String subDir) async {
    // Run build
    // print('Running `pub run build_runner build`...');
    print(white.wrap('> $subDir'));

    var args = ['--observe', 'bin/dev.dart'];
    //var args = ['--enable-vm-service', 'bin/dev.dart'];

    print(darkGray.wrap(
        '\$ dart${args.fold('', (previousValue, element) => '$previousValue $element')}'));

    var build = await Process.start(resolveDart(), args,
        workingDirectory: projectDir.absolute.path + '/' + subDir,
        mode: ProcessStartMode.normal);

    build.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        print(event);
      }
    });

    build.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        stderr.writeln(event);
      }
    });

    var buildCode = await build.exitCode;

    if (buildCode != 0) throw new Exception('Failed to pre-build resources.');
  }
}
