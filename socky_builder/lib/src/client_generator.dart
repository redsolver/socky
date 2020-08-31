import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:socky_server/annotations.dart';
import 'package:source_gen/source_gen.dart';

class ClientGenerator extends GeneratorForAnnotation<Socky> {
  bool hasElementFromJson(ClassElement element) {
    // bool hasFromJson = false;
    for (var c in (/* e.returnType. */ element as ClassElement).constructors) {
      //  print(c.name);
      if (c.name == 'fromJson') {
        return true;
      }
    }
    return false;
  }

  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    //final numValue = annotation.read('value').literalValue as num;
/*     var el=element.enclosingElement as CompilationUnitElement;
    print(el.); */

    List<String> usedReturnTypes = []; // TODO List of types etc.
    List<String> usedSubSocketTypes = []; // TODO List of types etc.

    if (element is! ClassElement) {
      final name = element.name;
      throw InvalidGenerationSourceError('Generator cannot target `$name`.',
          todo: 'Remove the Socky annotation from `$name`.', element: element);
    }

    final classElement = element as ClassElement;

    String s = '''

class ${element.name}Client {\n''';

    s += "final basePath;\n";
    s += "final baseUrl;\n";

    for (MethodElement e in classElement.methods) {
      if (e.name.startsWith('_')) continue;

      if (e.name == 'redLogin') {
        // TODO better maybe use $login DONT USE DOLLAR
        s += '''  Future<User> redLogin(String username) async {
    var data = await _send('redLogin', {'username': username});
    \$token =  data['token'] as String;
    return User.fromJson(data['user']);

  }''';
        continue;
      }

      String paramS = '';
      String jsonS = '';

      bool hasPositional = false;
      bool hasNamed = false;

      for (var p in e.parameters) {
        if (p.name.startsWith('\$')) continue;
        jsonS += "'${p.name}':${p.name},";
        if (p.isNotOptional) {
          paramS += "${p.type.displayName} ${p.name},";
        } else if (p.isOptionalPositional) {
          if (hasPositional) {
            paramS += ",${p.type.displayName} ${p.name}";
          } else {
            paramS += "[${p.type.displayName} ${p.name}";
            hasPositional = true;
          }
        } else if (p.isOptionalNamed) {
          if (hasNamed) {
            paramS += ",${p.type.displayName} ${p.name}";
          } else {
            paramS += "{${p.type.displayName} ${p.name}";
            hasNamed = true;
          }
          // paramS += "{${p.type.name} ${p.name}},";
        }
      }
      if (hasPositional) paramS += ']';
      if (hasNamed) paramS += '}';

/*       final method = Method((b) => b
        ..body = const Code('')
        ..name = 'doThing'
        ..returns = refer('Thing', 'package:a/a.dart')
        ..optionalParameters=[Paramter]);

      final emitter = DartEmitter();
      print('${animal.accept(emitter)}'); */

      //  s += "'/${e.name}': (data) => ${e.name}($paramS),";

      if (e.returnType.isDynamic) {
        throw Exception(
            'class ${element.displayName} -> ${e.displayName}: Please specify a return type (void, if you don\'t need one)');
      } else if (e.returnType.name == 'void') {
        s += "Future ${e.name}($paramS) => _send('${e.name}', {$jsonS});\n";
      } else if (e.returnType.displayName == 'Future') {
        s += "Future ${e.name}($paramS) => _send('${e.name}', {$jsonS});\n";
      } else {
        //number, boolean, string, null, list or a map
        /// with string keys
        ///
        ///
        ///
        var returnType = e.returnType;
        if (returnType.name == 'Future') {
          if (returnType.displayName != 'Future') {
            returnType = (returnType as InterfaceType).typeArguments.first;
          }
        } else if (returnType.name == 'Stream') {
          if (returnType.displayName != 'Stream') {
            returnType = (returnType as InterfaceType).typeArguments.first;
          }
        } else {}
        var hasFromJson = hasElementFromJson(returnType.element);

        String cast;
        if (hasFromJson) {
          usedReturnTypes.add(returnType.name);
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
          usedReturnTypes.add(returnType.name);

          cast = ' as ${returnType.displayName}';
        }

        if (e.returnType.name == 'Stream') {
          s +=
              """Future<Stream<${returnType.displayName}>> ${e.name}($paramS) async {
    await _streamSend('${e.name}', {$jsonS});

    if (_subs.containsKey('${e.name}'))
      throw Exception('Already listening to this stream');
    _subs['${e.name}'] = StreamController.broadcast();

    var firstData = await _subs['${e.name}'].stream.first;
    if (firstData != '___ready___') throw Exception(); // TODO

    return _subs['${e.name}'].stream.map((data) => ${hasFromJson ? '${returnType.displayName}.fromJson' : ''}( data) $cast);
  }""";
          /*        s += """Stream<${returnType.displayName}> ${e.name}($paramS) async*{
               await _streamSend('${e.name}', {$jsonS});

                   if (subs.containsKey('${e.name}'))
      throw Exception('Already listening to this stream');
    subs['${e.name}'] = StreamController();

    await for (var data in subs['${e.name}'].stream) {
      yield ${hasFromJson ? '${returnType.displayName}.fromJson' : ''}( data) $cast;
    }

               
                }
              """; */
        } else {
          s +=
              "Future<${returnType.displayName}> ${e.name}($paramS) async{return ${hasFromJson ? '${returnType.displayName}.fromJson' : ''}(await _send('${e.name}', {$jsonS}))$cast;}\n";
        }
      }

      // s += "Future<int> add(int a, int b) => _('add', {'a': a, 'b': b});";
    }

    // TODO Check if getter or field is better? hmm

    for (FieldElement e in classElement.fields) {
      if (e.type != null) {
        if (e.type.name == 'Map' && e.type.displayName != 'Map') {
          var typeArgs = (e.type as InterfaceType).typeArguments;

          //  print('MAP $typeArgs client');

          var typeElement = typeArgs[1].element as ClassElement;
          /*         print(e);
          print(e.type);
          print(typeElement); */

          var annotations = typeElement.metadata ?? [];

          //print(annotations);

          if (annotations.isEmpty) continue;

          if (annotations.first.computeConstantValue().type?.displayName ==
              'Socky') {
            // print('This is a sub Socky map!');

            usedSubSocketTypes.add(typeElement.name);

            s +=
                "${typeElement.name}Client ${e.name}(${typeArgs[0].name} id) => ${typeElement.name}Client(basePath: basePath+'/${e.name}/\$id', baseUrl: baseUrl, \$token: \$token);";
          }
        } else {
          //print('!!!');
          var typeElement = e.type.element as ClassElement;
          //print(e);
          // print(e.type);
          //   print(typeElement);

          var annotations = typeElement.metadata ?? [];

          if (annotations.isEmpty) continue;

          /*   print('annotations check...');
          print(annotations.first);
          print(annotations.first.computeConstantValue());
          print(annotations.first.constantValue);
          print(annotations.first.constantValue?.type?.displayName); */
          if (annotations.first.computeConstantValue().type?.displayName ==
              'Socky') {
/*             print('This is a sub socket!'); */
            usedSubSocketTypes.add(typeElement.name);

            s +=
                "${typeElement.name}Client get ${e.name} => ${typeElement.name}Client(basePath: basePath+'/${e.name}', baseUrl: baseUrl, \$token: \$token);";
          }
          /*  } catch (e, st) {
           print(e);
          print(st);
        } */
        }
      }
    }

    // TODO -1 Add option between JSON and msgpack

    // TODO Create and maintain one WebSocket if `Stream`+ is used, normal methods go to the usual HTTP call. If there is not a single Stream, do not generate the WebSocket stuff

    s += '''
    String \$token;

    //final bool useWebSocket;

    ${element.name}Client({this.baseUrl = 'http://localhost:8080',this.basePath = '',this.\$token,/*this.useWebSocket=false*/});
    
  WebSocketChannel _channel;

  Map<String,StreamController> _subs={};

void _initStream(
  )  {

  if (_channel == null) {
      _channel = IOWebSocketChannel.connect('\${baseUrl.replaceFirst('http','ws')}/ws' + (\$token ==null?'':'?token=\${\$token}'));
      _channel.stream.listen((rawData) {
        var payload = json.decode(rawData);

        String method =  payload['/'].split('/').last;
        var data = payload['data'];

        if (_subs.containsKey(method)){
        _subs[method].add(data);
        }
      });
    }

  }
Future _streamSend(
    String function,
    var data,
  ) async {

    _initStream();
    _channel.sink.add(json.encode({'/':basePath+'/'+function,'data':data,}));
      
  }




Future _send(
    String function,
    var data,
  ) async {

    Map<String,String> headers={
        'content-type': 'application/json',
      };

      if(\$token!=null)headers.addAll({
        'authorization': 'Bearer \${\$token}',
      });
      
    var res = await http.post(
      '\$baseUrl\$basePath/\$function',
      body: json.encode(data),
      headers: headers,
    );

    if(res.statusCode==200){
    return json.decode(res.body);

    }else if(res.statusCode==500){

      throw ServerException(res.body);

    }

  }
  }
class ServerException implements Exception {
  String cause;
  ServerException(this.cause);
}
    
    ''';

    //Multiplied() => ${element.name} * 100;

    usedReturnTypes.add('User');

    for (var i in element.library.imports) {
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
    }
// TODO Compact two loopsthe
    for (var i in element.library.imports) {
      for (var t in i.importedLibrary.definingCompilationUnit.types) {
        if (usedSubSocketTypes.contains(t.name)) {
          String uri = i.uri;
          uri = uri.replaceFirst(
              RegExp(r'package:[a-zA-Z0-9_]+\/'), 'package:client/');
          uri = uri.replaceFirst(RegExp(r'\.dart$'), '.client.dart');
          s = "import '${uri}';\n$s";
        }
      }
    }
    //s = "import 'dart:convert';import 'package:http/http.dart' as http;import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;$s";
    s = """import 'dart:convert';
    import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
$s""";

    return s;
  }
}
