import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:socky_server/annotations.dart';
import 'package:dart_style/dart_style.dart';

import 'package:source_gen/source_gen.dart';
import 'package:path/path.dart' as p;

class SockyBuilder implements Builder {
  static final _allFilesInLib = Glob('lib/**');

  final usedReturnTypes = Set<DartType>();

  @override
  Map<String, List<String>> get buildExtensions {
    return const {
      r'$lib$': ['socky.g.dart']
    };
  }

  static AssetId _allFileOutput(BuildStep buildStep) {
    return AssetId(
      buildStep.inputId.package,
      p.join('lib', 'socky.g.dart'),
    );
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final lines = <String>[];
    final classesInLibrary = <ClassElement>[];
    await for (final input in buildStep.findAssets(_allFilesInLib)) {
      // print(input.path);

      final library = await buildStep.resolver.libraryFor(input);
      classesInLibrary.addAll(LibraryReader(library)
          .annotatedWith(TypeChecker.fromRuntime(Socky))
          .where((match) => match.element is ClassElement)
          .map((match) => match.element as ClassElement)
          .toList());
    }
    // print('classesInLibrary $classesInLibrary');

    final sockets = classesInLibrary.map((c) => _generateSocket(c)).toList();
    /*    final unmappedTypes = processedTypes
        .where((t) => t.element is ClassElement)
        .toSet()
        .difference(classesInLibrary
            .map((optedClasses) => optedClasses.thisType)
            .toSet()); */
/*     print(
        'WARNING: Generated mappings for the following unannotated types: ${unmappedTypes.map((t) => t.toString()).join(', ')}'); */

/*     final unmappedElements =
        unmappedTypes.map((t) => t.element as ClassElement).toList();
    mappers.addAll(unmappedElements.map((c) => _generateMapper(c))); */

    final imports = _generateHeader(
      usedReturnTypes.map<ClassElement>((type) => type.element).toList()
        ..addAll(
          classesInLibrary,
        ),
    );
    final registrations = _generateInit(classesInLibrary);

    lines.add(imports);
    lines.addAll(sockets);
    lines.add(registrations);

    var formatter = DartFormatter();

    await buildStep.writeAsString(
        _allFileOutput(buildStep), formatter.format(lines.join('\n')));
  }

  bool hasElementFromJson(ClassElement element) {
    //  if (element == null) return false;

    //  print('hasElementFromJson $element');
    // bool hasFromJson = false;
    for (var c in element.constructors) {
      //  print(c.name);
      if (c.name == 'fromJson') {
        return true;
      }
    }
    return false;
  }

  String _generateSocket(ClassElement element) {
    //final numValue = annotation.read('value').literalValue as num;

    if (element is! ClassElement) {
      final name = element.name;
      throw InvalidGenerationSourceError('Generator cannot target `$name`.',
          todo: 'Remove the Socky annotation from `$name`.', element: element);
    }

    final classElement = element as ClassElement;

    String s = 'class ${element.name}Socky extends ${element.name} {\n';

    s += 'Map<String, Function> map;\n';

    s += 'Map<String, dynamic> sub;\n';

    s += '${element.name}Socky(){map = {';

    for (MethodElement e in classElement.methods) {
      if (e.name.startsWith('_')) continue;
      String paramS = '';
      for (var p in e.parameters) {
        if (p.name.startsWith(
            '\$') /* p.name == '\$' || ['user'].contains(p.name) */) {
          if (p.name == '\$') {
            paramS += "\$: ctx, ";
          } else {
            paramS += "${p.name}: ctx.${p.name.substring(1)}, ";
          }

          continue;
        }
        /*     // TODO Add optional and named types + list
        bool hasFromJson = false;
        for (var c in (p.type.element as ClassElement).constructors) {
          if (c.name == 'fromJson') {
            hasFromJson = true;
            break;
          }
        } */

        var returnType = p.type;
        var hasFromJson = hasElementFromJson(p.type.element);

        String cast;
        if (hasFromJson) {
          usedReturnTypes.add(returnType);
          cast = '';
        } else if (returnType.name == 'List' &&
            returnType.displayName != 'List') {
          var typeArgument =
              (returnType as InterfaceType).typeArguments.first.element;

          var hasFromJson = hasElementFromJson(typeArgument);

          if (hasFromJson) {
            cast =
                '.map<${typeArgument.displayName}>((m)=>${typeArgument.displayName}.fromJson(m)).toList()';
          } else {
            cast = '.cast<${typeArgument.displayName}>()';
            //  / cast = '.cast${returnType.displayName.substring(4)}()';
          }
        } else if (returnType.name == 'Map' &&
            returnType.displayName != 'Map') {
          var secTypeArgument =
              (returnType as InterfaceType).typeArguments[1].element;

          var hasFromJson = hasElementFromJson(secTypeArgument);

          //Map().map<int, String>((a, b) => MapEntry(key, value));

          if (hasFromJson) {
            cast =
                '.map${returnType.displayName.substring(3)}((k,v)=>MapEntry${returnType.displayName.substring(3)}(k,${secTypeArgument.displayName}.fromJson(v)))';
          } else {
            cast = '.cast${returnType.displayName.substring(3)}()';
            //  / cast = '.cast${e.returnType.displayName.substring(4)}()';
          }
        } else {
          usedReturnTypes.add(returnType);

          cast = ' as ${returnType.displayName}';
        }

        if (p.isNotOptional) {
          if (hasFromJson) {
            paramS += "${p.type.displayName}.fromJson(data['${p.name}']), ";
          } else {
            paramS += "data['${p.name}']$cast, ";
          }
        } else if (p.isOptionalPositional) {
          paramS += " data['${p.name}']$cast, ";
        } else if (p.isOptionalNamed) {
          paramS += "${p.name}: data['${p.name}']$cast, ";
        }
      }

      s += "'${e.name}': (data, ctx) => ${e.name}($paramS),";
    }

    /*    for (PropertyAccessorElement e in classElement.accessors) {
      print(e.name);
      print(e.isGetter);
      print(e.returnType);
      print(e.displayName);
      print(e.kind);
      print(e.parameters);
      print(e.variable);
    } */
    s += '};';

    s += 'sub = {';

    for (FieldElement e in classElement.fields) {
      s += '\n// ${e}\n';

      if (e.type != null) {
        /*     try { */

        if (e.type.name == 'Map' && e.type.displayName != 'Map') {
          var typeArgs = (e.type as InterfaceType).typeArguments;

          var typeElement = typeArgs[1].element as ClassElement;
          /*        print(e);
          print(e.type);
          print(typeElement); */

          var annotations = typeElement.metadata ?? [];

          /*          print('---');
          print(annotations);
 */
          if (annotations.isEmpty) continue;

          if (annotations.first.computeConstantValue().type?.displayName ==
              'Socky') {
            // print('This is a sub socket map!');
            s +=
                '"/${e.name}":${e.name}.cast<${typeArgs[0].name}, ${typeElement.name}Socky>(),';
          }
        } else {
          /*      print('!!!'); */
          var typeElement = e.type.element as ClassElement;
          /*      print(e);
          print(e.type);
          print(typeElement); */

          var annotations = typeElement.metadata ?? [];

          if (annotations.isEmpty) continue;

          /*   print('annotations check...');
          print(annotations.first);
          print(annotations.first.computeConstantValue()); */
          if (annotations.first.computeConstantValue().type?.displayName ==
              'Socky') {
         //   print('This is a sub socket!');
            s += '"/${e.name}":${e.name} as ${typeElement.name}Socky,';
          }
          /*  } catch (e, st) {
           print(e);
          print(st);
        } */
        }
      }
    }

    /*    for (FieldElement e in classElement.fields) {
      try {
        var typeElement = e.initializer.returnType.element;
        print(e.constantValue);

        print(typeElement);
        if (typeElement is! ClassElement) continue;

        var annotations = typeElement.metadata ?? [];

        print(annotations.first);
        print(annotations.first.constantValue);
        print(annotations.first.constantValue?.type?.displayName);
        if (annotations.first.constantValue?.type?.displayName == 'Socky') {
          print('This is a sub socket!');
          s += '"/${e.name}":${e.name},';
        }
      } catch (e, st) {
        print(e);
        print(st);
      }
      /*  if (e.type != null) {
        try {
          /*      s +=
              "${typeElement.name}Client get ${e.name} => ${typeElement.name}Client(baseUrl: baseUrl, \$token: \$token);"; */

        } catch (e, st) {
          print(e);
          print(st);
        }
      } */
    } */

    s += '};';

    s += '}';

    s += '}';

/*     for (var i in element.library.imports) {
      // print('++');

      for (var t in i.importedLibrary.definingCompilationUnit.types) {
        // print(t.displayName);
        // print(i.importedLibrary.definingCompilationUnit.t);

        if (usedReturnTypes.contains(t.name)) {
          s = "import '${i.uri}';\n$s";
        }

        /* for (var st in t.allSupertypes) {
          print("super: ${st.element.displayName}");
        } */
      }
    } */

    //Multiplied() => ${element.name} * 100;

    return s;
  }

  bool isParamFieldFormal(ParameterElement param) {
    return param.isInitializingFormal;
  }

  bool isParamEnum(FieldFormalParameterElement param) {
    return (param.field.type.element as ClassElement).isEnum;
  }

  String _generateInit(List<ClassElement> elements) {
    return '''
void initTODO() {
  ${elements.map(_generateRegistration).join('\n  ')} 
}
    ''';
  }

  String _generateRegistration(ClassElement element) {
    return '''// JsonMapper.register(_${element.displayName.toLowerCase()}Mapper);''';
  }

  String _generateHeader(List<ClassElement> elements) {
    return [
      '''// GENERATED CODE - DO NOT MODIFY BY HAND''',
      '''// Generated and consumed by 'socky_builder' ''',
      '',
      '''import 'dart:core';''',
      Utils.dedupe(elements.map(_generateImport).toList()).join('\n')
    ].join('\n');
  }

  String _generateImport(ClassElement element) {
    return '''import '${element.library.identifier}';''';
  }
}

class Utils {
  static List<T> dedupe<T>(List<T> items) {
    return [...Set()..addAll(items)];
  }

  static String enumToString<T>(T enumVal) {
    return enumVal.toString().split('.')[1];
  }
}
