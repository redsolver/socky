import "dart:convert";
import "dart:io";
import "package:args/command_runner.dart";
import 'package:io/ansi.dart';
import '../util.dart';

class DoctorCommand extends Command {
  @override
  String get name => "doctor";

  @override
  String get description =>
      "Ensures that the current system is capable of running Socky.";

  @override
  run() async {
    print("Checking your system for dependencies...");
    await _checkForGit();
    await _checkForFlutter();
  }

  _checkForFlutter() async {
    try {
      var flutter = await Process.start("flutter", ["--version"]);
      if (await flutter.exitCode == 0) {
        var version = await flutter.stdout.transform(utf8.decoder).join();
        print(green.wrap("$checkmark Flutter executable found:\n${version}"));
      } else
        throw new Exception("Flutter executable exit code not 0");
    } catch (exc) {
      print(red.wrap("$ballot Flutter executable not found"));
    }
  }

  _checkForGit() async {
    try {
      var git = await Process.start("git", ["--version"]);
      if (await git.exitCode == 0) {
        var version = await git.stdout.transform(utf8.decoder).join();
        print(green.wrap(
            "$checkmark Git executable found: v${version.replaceAll('git version', '').trim()}"));
      } else
        throw new Exception("Git executable exit code not 0");
    } catch (exc) {
      print(red.wrap("$ballot Git executable not found"));
    }
  }
}
