import 'dart:io';

import '../ipc_message.dart';
import 'args.dart';
import 'flutter_process.dart';
import 'ios_simulator.dart';
import 'ipc_server.dart';
import 'utils.dart';

class ScreenshotHost {
  final FlutterProcess _process;
  IpcServer? ipcServer;
  IosSimulator? simulator = IosSimulator(
    deviceId: 'booted',
    name: 'iPhone 14 Plus',
    platform: IosSimulatorPlatform.iPhone,
  )..isBooted = true;

  final ScreenshotArgs args;

  ScreenshotHost({
    List<String>? argv,
  })  : args = ScreenshotArgs.parse(argv ?? []),
        _process = FlutterProcess.run();

  /// Run the screenshot host.
  Future<void> run() async {
    if (simulator != null) {
      await simulator!.boot();
      _process.device = simulator!.name;
    } else if (args.device != null) {
      _process.device = args.device;
    }
    _process.target = args.target;
    args.configuration.addToProcess(_process);

    ipcServer = await IpcServer.start();
    ipcServer!.onMessage = _onMessage;

    await _process.start(
      pipeOutput: args.verbose,
    );

    await ipcServer!.clientDone;
    await ipcServer!.close();
    await _process.kill();
  }

  Future<void> _onMessage(IpcMessage message) async {
    if (message.type == IpcMessageType.screenshot) {
      final screenshotMessage = message as ScreenshotIpcMessage;
      await _saveScreenshot(screenshotMessage);
    } else if (message.type == IpcMessageType.info) {
      final infoMessage = message as InfoIpcMessage;
      print(infoMessage.message);
    }
  }

  Future<void> _saveScreenshot(ScreenshotIpcMessage msg) async {
    final locale = msg.locale?.toLanguageTag() ?? 'none';

    String filename = args.path;
    if (filename.contains('{locale}')) {
      filename = filename.replaceAll('{locale}', locale);
    }
    if (filename.contains('{name}')) {
      filename = filename.replaceAll('{name}', msg.name);
    }
    await File(filename).create(recursive: true);

    await simulator?.screenshot(filename);
  }
}
