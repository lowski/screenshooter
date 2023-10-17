import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../host/ipc_server.dart';
import '../ipc_message.dart';

class IpcClient {
  /// Sends a message to the server.
  static Future<void> send(IpcMessage message) async {
    final client = HttpClient();
    final request = await client.post(IpcServer.host, IpcServer.port, '/');
    request.write(jsonEncode(message.toJson()));
    await request.close();
  }

  /// Send an [InfoIpcMessage] to the server.
  static Future<void> sendInfo(String message) => send(InfoIpcMessage(message));

  /// Send a [ClientDoneIpcMessage] to the server.
  static Future<void> sendDone() => send(ClientDoneIpcMessage());
}
