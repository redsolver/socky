import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:socky_server/src/recharge.dart';
import 'package:socky_server/src/user.dart';
import 'package:uuid/uuid.dart';

import 'src/call_context.dart';

class SockyServer {
  HttpServer httpServer;
  Function rootSockyBuilder;
  final bool dev;

  SockyServer({
    this.httpServer,
    this.rootSockyBuilder,
    this.dev = false,
  });

  Map<String, dynamic> instances = {};

  Future start() async {
    if (dev) {
      var recharge = Recharge(path: 'lib/');
      await recharge.init();
    }

    // TODO One instance per client

    //var server = Server();

    // TODO Set json headers
    httpServer.listen((req) async {
      try {
        var function = req.uri.path;
        if (function == '/ws') {
          final token = req.uri.queryParameters['token'];

          CallContext context = CallContext();
          if (token != null) {
            if (userTokens.containsKey(token)) {
              context.user = users[userTokens[token]];
            } else {
              req.response.statusCode = HttpStatus.forbidden;
              await req.response.close();
              return;
            }
          }

          WebSocketTransformer.upgrade(req).then((WebSocket ws) {
            List<StreamSubscription> streamSubs = [];
            ws.listen(
              (wsReq) async {
                var decoded = json.decode(wsReq);

                String function = decoded['/'];
                var data = decoded['data'];

                /*  print(
                  '\t\t${req?.connectionInfo?.remoteAddress} -- ${json.decode(data)}'); */

                print('${function}');

                String clientId = null;

                if (clientId != null) print('Client $clientId');

                if (!instances.containsKey(clientId)) {
                  // TODO Add async init

                  instances[clientId] = rootSockyBuilder();
                }

                final server = instances[clientId];
                dynamic socket = server;

                List<String> fParts =
                    function.split('/').where((s) => s.isNotEmpty).toList();

                for (String part in fParts.sublist(0, fParts.length - 1)) {
                  if (socket is Map) {
                    socket = socket[part];
                  } else {
                    socket = socket.sub['/' + part];
                  }
                }

                if (socket is Map) return; // TODO Exception

                // TODO Use extension methods

                Function func = socket.map[fParts.last];

                if (func == null) {
                  // TODO Better error handling
                  ws.close(404);
                  /*       req.response.statusCode = 404;
                await req.response.close(); */
                  return;
                }

                print('> $data');
                try {
                  Stream result = func(
                    data,
                    context,
                    /*   CallContext(
                        User(id: req.connectionInfo.remoteAddress.host)) */
                  );
                  ws.add(json.encode({
                    '/': function,
                    'data': '___ready___',
                  }));

                  var sub = result.listen((data) {
                    print('< $data');
                    ws.add(json.encode({
                      '/': function,
                      'data': data,
                    }));
                  });

                  streamSubs.add(sub);
                } catch (e) {
                  // TODO Error
                  /*  ws.add(json.encode({
                  '/': function,
                  'data': '___ready___',
                })); */
                  /*  // TODO Custom Exception
                req.response.statusCode = 500; // TODO Use other status code
                req.response.write((e.toString())); */
                }

                /*  Stream.periodic(Duration(seconds: 1)).listen((_) {
                ws.add(json.encode({
                  '/': 'everySecond',
                  'data': 123,
                }));
              }); */
              },
              onDone: () {
                print('Closed');
                streamSubs.forEach((sub) => sub.cancel());
              },
              onError: (err) => print('[!]Error -- ${err.toString()}'),
              cancelOnError: true,
            );
          }, onError: (err) => print('[!]Error -- ${err.toString()}'));
        } else {
          await handleRequest(req);
        }
      } catch (e, st) {
        print(e);
        print(st);

        req.response.statusCode = 500;

        await req.response.close();
      }
    }, onError: (err) => print('[!]Error -- ${err.toString()}'));
  }
// TODO Check http method etc.

// TODO Maybe use one RootSocket instance per user and expose a global service.

  handleRequest(HttpRequest request) async {
    //await Future.delayed(Duration(milliseconds: 25));
    String authorization =
        request.headers.value('authorization') /* .toLowerCase() */;

    print('');

    String clientId = null;
    //if (clientId != null) print('Client $clientId');

    if (!instances.containsKey(clientId)) {
      // TODO Add async init

      instances[clientId] = rootSockyBuilder();
    }

    final server = instances[clientId];

    var function = request.uri.toString();

    print('${function}');

    if (function.startsWith('/_')) {
      var content = await utf8.decoder.bind(request).join();

      var data = json.decode(content);

      print('> $data');
      if (function == '/_login') {
        var user = SockyUser(id: Uuid().v4(), name: data['username']);
        users[user.id] = user;

        var token = Uuid().v4();
        userTokens[token] = user.id;

        print('< $token');
        request.response.write(json.encode({'token': token, 'user': user}));
      }
    } else {
      CallContext context = CallContext();

      if (authorization != null) {
        String bearerToken = authorization.split(' ').last;

        if (userTokens.containsKey(bearerToken)) {
          context.user = users[userTokens[bearerToken]];
        } else {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
          return;
        }
      }
      // TODO Check if Endpoint requires authorization

      List<String> fParts =
          function.split('/').where((s) => s.isNotEmpty).toList();

      dynamic socket = server;

      for (String part in fParts.sublist(0, fParts.length - 1)) {
        if (socket is Map) {
          socket = socket[part];
        } else {
          socket = socket.sub['/' + part];
        }
      }

      if (socket is Map) return; // TODO Exception

      Function func = socket.map[fParts.last];

      if (func == null) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }

      var content = await utf8.decoder.bind(request).join();

      // TODO Check if this always works, and how!
      // var content = await request.single;

// TODO Add JSON Option
      //var data = msgpack.deserialize(content);

      var data = json.decode(content);

      print('> $data');

      var result;
      try {
        result = await func(data, context);

        print('< $result');
        request.response.write(json.encode(result));
      } catch (e, st) {
        print(e);
        print(st);
        // TODO Custom Exception
        request.response.statusCode = 500; // TODO Use other status code
        request.response.write((e.toString()));
      }
    }

    await request.response.close();
  }

/* executeFunction() {}
 */

  Map<String, SockyUser> users = {
    /*  'abc123': User(
      id: 'abc123',
      name: 'redsolver',
    ) */
  };

// TODO Add Ablaufzeit
  Map<String, String> userTokens = {
    'xyz': 'abc123',
  };
}
