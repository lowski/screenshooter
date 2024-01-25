import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../host/ipc_server.dart';
import '../ipc_message.dart';

class IpcClient {
  static String? _clientId;

  /// Sends a message to the server.
  static Future<String> send(IpcMessage message) async {
    message.clientId = _clientId;

    final client = HttpClient();
    final request = await client.post(IpcServer.host, IpcServer.port, '/');
    request.write(jsonEncode(message.toJson()));
    final response = await request.close();

    return await utf8.decodeStream(response);
  }

  /// Send an [InfoIpcMessage] to the server.
  static Future<void> sendInfo(String message) => send(InfoIpcMessage(message));

  /// Send a [ClientDoneIpcMessage] to the server.
  static Future<void> sendDone() => send(ClientDoneIpcMessage());

  /// Request a client id from the server.
  static Future<void> requestClientId() async {
    if (_clientId != null) {
      return;
    }
    _clientId = await send(ClientIdRequestIpcMessage());
  }
}
