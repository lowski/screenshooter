// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ipc_message.dart';

class IpcServer {
  /// The port that the IPC server listens on.
  static const port = 8123;

  /// The host that the IPC server listens on.
  static const host = 'localhost';

  late final HttpServer _server;

  /// Called when a message is received from the client. The client will not
  /// receive a response until this function completes.
  ///
  /// This function will not be called if the message is a
  /// [ClientDoneIpcMessage], instead the [clientDone] future will complete.
  Future<void> Function(IpcMessage message)? onMessage;

  final Completer<void> _doneCompleter = Completer();

  /// A future that completes when the client sends a [ClientDoneIpcMessage].
  Future<void> get clientDone => _doneCompleter.future;

  IpcServer._();

  /// Opens a new IPC server.
  static Future<IpcServer> start() async {
    final ipcServer = IpcServer._();
    final server = await HttpServer.bind(host, port);
    server.listen(ipcServer._handler);
    ipcServer._server = server;
    return ipcServer;
  }

  /// Handles an incoming HTTP request. For sending a response to the client,
  /// use [request.response].
  Future<void> _handler(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    try {
      final message = IpcMessage.fromJson(jsonDecode(body));
      if (message is ClientDoneIpcMessage) {
        _doneCompleter.complete();
      } else {
        await onMessage?.call(message);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Cannot decode IpcMessage: $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Cannot decode IpcMessage');
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.ok;
    await request.response.close();
  }

  /// Closes this IPC server.
  Future<void> close() async {
    await _server.close();
  }
}
