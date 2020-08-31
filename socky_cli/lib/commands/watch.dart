import 'dart:async';
import 'dart:convert';
import "dart:io";

import "package:args/command_runner.dart";
import 'package:io/ansi.dart';
import 'package:socky_cli/commands/socky_yaml.dart';

import 'pub.dart';

class WatchCommand extends Command {
  // final KeyCommand _key = new KeyCommand();

  @override
  String get name => "watch";

  @override
  String get description => "Starts all build_runner's in watch mode";

  WatchCommand() {
    argParser..addFlag('delete-conflicting-outputs', defaultsTo: false);
  }

  @override
  run() async {
    Directory projectDir = new Directory('.');

    final sockyYaml = File('${projectDir.path}/socky.yaml');

    if (!sockyYaml.existsSync()) {
      throw UsageException('socky.yaml file not found', '');
    }

    final meta = loadMetadata(sockyYaml);
    print('project "${meta.name}"');

    print(
        "Running build_runner in watch mode in ${projectDir.absolute.path}...");

    preBuild(projectDir, 'shared').catchError((_) => null);
    preBuild(projectDir, 'server').catchError((_) => null);
  }

  Future preBuild(Directory projectDir, String subDir) async {
    // Run build
    // print('Running `pub run build_runner build`...');
    print(white.wrap('> $subDir'));

    var args = ['run', 'build_runner', 'watch'];

    if (argResults['delete-conflicting-outputs'])
      args.add('--delete-conflicting-outputs');

    print(darkGray.wrap(
        '\$ pub${args.fold('', (previousValue, element) => '$previousValue $element')}'));

    var build = await Process.start(resolvePub(), args,
        workingDirectory: projectDir.absolute.path + '/' + subDir,
        mode: ProcessStartMode.normal);

    AnsiCode code = {
          'shared': magenta,
          'server': yellow,
        }[subDir] ??
        green;

    var msgCode = white;

    build.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        if (event.startsWith('[INFO] ----------')) {
          msgCode = darkGray;

          event = '';
          for (int i = 0; i < (stdout.terminalColumns - subDir.length - 3); i++)
            event += '-';
        } else if (event.startsWith('[INFO] Succeeded')) {
          msgCode = green;
        } else if (event.startsWith('[INFO]')) {
          msgCode = darkGray;
        } else if (event.startsWith('[WARNING]')) {
          msgCode = white;
        } else if (event.startsWith('[SEVERE]')) {
          msgCode = red;
        }

        print(code.wrap('[$subDir] ') + msgCode.wrap('$event'));
      }
    });

    build.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        stderr.writeln(code.wrap('[$subDir] ') + red.wrap('$event'));
      }
    });

    var buildCode = await build.exitCode;

    if (buildCode != 0) throw new Exception('Failed to pre-build resources.');
  }
}
