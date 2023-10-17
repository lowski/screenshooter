// ignore_for_file: deprecated_member_use_from_same_package

enum IpcMessageType {
  screenshot,
  info,
  @Deprecated('Only for internal use. See [IpcClient.onMessage].')
  clientDone,
}

sealed class IpcMessage {
  final IpcMessageType type;
  final Map<String, dynamic>? payload;

  IpcMessage(this.type, this.payload);

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'payload': payload,
    };
  }

  factory IpcMessage.fromJson(Map<String, dynamic> json) {
    final type = IpcMessageType.values[json['type']];
    switch (type) {
      case IpcMessageType.screenshot:
        return ScreenshotIpcMessage.fromJson(json['payload'] ?? {});
      case IpcMessageType.info:
        return InfoIpcMessage.fromJson(json['payload'] ?? {});
      case IpcMessageType.clientDone:
        return ClientDoneIpcMessage();
    }
  }

  @override
  String toString() {
    return '$runtimeType{type: $type, payload: $payload}';
  }
}

class ScreenshotIpcMessage extends IpcMessage {
  final String name;
  final String? locale;

  ScreenshotIpcMessage({
    required this.name,
    this.locale,
  }) : super(
          IpcMessageType.screenshot,
          {
            'name': name,
            'locale': locale,
          },
        );

  factory ScreenshotIpcMessage.fromJson(Map<String, dynamic> json) {
    return ScreenshotIpcMessage(
      name: json['name'],
      locale: json['locale'],
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
