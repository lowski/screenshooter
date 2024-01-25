// ignore_for_file: deprecated_member_use_from_same_package

import 'package:screenshooter/screenshooter.dart';

enum IpcMessageType {
  screenshot,
  info,
  @Deprecated('Only for internal use. See [IpcServer.onMessage].')
  clientDone,
  @Deprecated('Only for internal use. See [IpcServer.onMessage].')
  clientIdRequest,
}

sealed class IpcMessage {
  final IpcMessageType type;
  final Map<String, dynamic>? payload;
  String? clientId;

  IpcMessage(this.type, this.payload, {this.clientId});

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'payload': payload,
      'clientId': clientId,
    };
  }

  factory IpcMessage.fromJson(Map<String, dynamic> json) {
    final type = IpcMessageType.values[json['type']];
    switch (type) {
      case IpcMessageType.screenshot:
        return ScreenshotIpcMessage.fromJson(json['payload'] ?? {})
          ..clientId = json['clientId'];
      case IpcMessageType.info:
        return InfoIpcMessage.fromJson(json['payload'] ?? {})
          ..clientId = json['clientId'];
      case IpcMessageType.clientDone:
        return ClientDoneIpcMessage()..clientId = json['clientId'];
      case IpcMessageType.clientIdRequest:
        return ClientIdRequestIpcMessage()..clientId = json['clientId'];
    }
  }

  @override
  String toString() {
    return '$runtimeType{type: $type, payload: $payload}';
  }
}

class ScreenshotIpcMessage extends IpcMessage {
  final String name;
  final ScreenshotLocale? locale;

  ScreenshotIpcMessage({
    required this.name,
    this.locale,
  }) : super(
          IpcMessageType.screenshot,
          {
            'name': name,
            'locale': locale?.toLanguageTag(),
          },
        );

  factory ScreenshotIpcMessage.fromJson(Map<String, dynamic> json) {
    return ScreenshotIpcMessage(
      name: json['name'],
      locale: json['locale'] == null
          ? null
          : ScreenshotLocale.fromString(json['locale']!),
    );
  }
}

class InfoIpcMessage extends IpcMessage {
  final String message;

  InfoIpcMessage(
    this.message,
  ) : super(IpcMessageType.info, {'message': message});

  factory InfoIpcMessage.fromJson(Map<String, dynamic> json) {
    return InfoIpcMessage(
      json['message'],
    );
  }
}

class ClientDoneIpcMessage extends IpcMessage {
  ClientDoneIpcMessage() : super(IpcMessageType.clientDone, null);

  factory ClientDoneIpcMessage.fromJson(Map<String, dynamic> json) {
    return ClientDoneIpcMessage();
  }
}

class ClientIdRequestIpcMessage extends IpcMessage {
  ClientIdRequestIpcMessage() : super(IpcMessageType.clientIdRequest, null);

  factory ClientIdRequestIpcMessage.fromJson(Map<String, dynamic> json) {
    return ClientIdRequestIpcMessage();
  }
}
