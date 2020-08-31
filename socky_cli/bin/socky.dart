#!/usr/bin/env dart

library socky_cli.tool;

import "dart:io";

import "package:args/command_runner.dart";
import 'package:io/ansi.dart';
import 'package:socky_cli/commands/dev.dart';
import 'package:socky_cli/commands/watch.dart';
import 'package:socky_cli/commands/doctor.dart';
import 'package:socky_cli/commands/init.dart';

main(List<String> args) async {
  var runner = new CommandRunner(
      "socky",
      asciiArt +
          '\n\n' +
          "Command-line tools for the Socky framework." +
          '\n\n' +
          'https://socky.dev');

  runner.argParser
      .addFlag('verbose', help: 'Print verbose output.', negatable: false);

  runner
    ..addCommand(new InitCommand())
    ..addCommand(new DoctorCommand())
    ..addCommand(new DevCommand())
    ..addCommand(new WatchCommand());

  return await runner.run(args).catchError((exc, st) {
    if (exc is String) {
      stdout.writeln(exc);
    } else {
      stderr.writeln("Oops, something went wrong: $exc");
      if (args.contains('--verbose')) {
        stderr.writeln(st);
      }
    }

    exitCode = 1;
  }).whenComplete(() {
    stdout.write(resetAll.wrap(''));
  });
}

const String asciiArt = '''   
   _____            __        
  / ___/____  _____/ /____  __
  \\__ \\/ __ \\/ ___/ //_/ / / /
 ___/ / /_/ / /__/ ,< / /_/ / 
/____/\\____/\\___/_/|_|\\__, /  
                     /____/    ''';
