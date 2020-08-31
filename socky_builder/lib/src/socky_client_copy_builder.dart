import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';

class ClientCopyBuilder implements PostProcessBuilder {
  final String outputExtension;

  @override
  final inputExtensions = ['.client.dart'];

  ClientCopyBuilder({this.outputExtension = '.client.dart'});

  @override
  FutureOr<Null> build(PostProcessBuildStep buildStep) async {
    var file = File('../client/' + buildStep.inputId.path);

    file.createSync(recursive: true);
    file.writeAsStringSync(await buildStep.readInputAsString());
  }
}
