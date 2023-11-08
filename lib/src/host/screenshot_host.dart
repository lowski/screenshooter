import 'dart:io';

import '../ipc_message.dart';
import 'args.dart';
import 'flutter_process.dart';
import 'ios_simulator.dart';
import 'ipc_server.dart';
import 'utils.dart';

class ScreenshotHost {
  IosSimulator? simulator;

  final ScreenshotArgs args;

  String? currentDeviceId;

  ScreenshotHost({
    List<String>? argv,
  }) : args = ScreenshotArgs(argv ?? []);

  /// Run the screenshot host.
  Future<void> run() async {
    await _build();
    for (final device in args.devices.entries) {
      await _runDevice(device.key, device.value);
    }
  }

  Future<void> _build() async {
    final process = FlutterProcess.buildIosDebug();
    process.addFlag('--simulator');
    process.addFlag('--no-codesign');
    process.target = args.target;
    args.configuration.addToProcess(process);

    await process.start(
      pipeOutput: args.verbose,
    );
    await process.done;
  }

  /// Upload an existing app bundle to the simulator and run it.
  Future<void> _runDevice(
    String deviceName,
    String? deviceId,
  ) async {
    currentDeviceId = deviceId;
    simulator = await _findSimulator(deviceName);
    await simulator!.boot();

    final ipcServer = await IpcServer.start();
    ipcServer.onMessage = _onMessage;

    await simulator!.installApp('build/ios/iphonesimulator/Runner.app');
    await simulator!.launchApp(args.bundleId!);

    await ipcServer.clientDone;
    await ipcServer.close();
  }

  Future<IosSimulator> _findSimulator(String name) async {
    final simulators = await IosSimulator.listAll();
    return simulators.firstWhere(
      (element) => element.name == name,
      orElse: () => throw Exception(
        'No simulator with the name "$name" found',
      ),
    );
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
    String filename = args.path;
    if (filename.contains('{locale}')) {
      filename = filename.replaceAll(
        '{locale}',
        msg.locale?.toLanguageTag() ?? 'none',
      );
    }
    if (filename.contains('{name}')) {
      filename = filename.replaceAll('{name}', msg.name);
    }
    if (filename.contains('{device}')) {
      filename = filename.replaceAll(
        '{device}',
        currentDeviceId ?? 'unknownDevice',
      );
    }
    await File(filename).create(recursive: true);

    await simulator?.screenshot(filename);
  }
}
