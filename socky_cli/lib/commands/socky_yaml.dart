import 'dart:io';

import 'package:yaml/yaml.dart';

SockyProjectMetadata loadMetadata(File file) {
  var doc = loadYaml(file.readAsStringSync());
  var meta = SockyProjectMetadata();
  meta.name = doc['name'];
  return meta;
}

class SockyProjectMetadata {
  String name;
}
