library socky_builder.builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/socky_builder.dart';
import 'src/client_generator.dart';
import 'src/socky_client_copy_builder.dart';

SockyBuilder sockyBuilder(_) => SockyBuilder();

Builder clientBuilder(BuilderOptions options) =>
    LibraryBuilder(ClientGenerator(), generatedExtension: '.client.dart');

PostProcessBuilder clientCopy(BuilderOptions options) =>
    ClientCopyBuilder();
