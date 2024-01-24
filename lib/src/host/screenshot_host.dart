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

  List<IosSimulator>? _simulators;

  ScreenshotHost({
    List<String>? argv,
  }) : args = ScreenshotArgs(argv ?? []);

  /// Run the screenshot host.
  Future<void> run() async {
    if (!args.skipBuild) {
      await _build();
    }

    _simulators ??= await IosSimulator.listAll();
    _bootSimulators(args.devices.keys);

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

  Future<void> _bootSimulators(Iterable<String> devices) {
    return Future.wait(devices.map(
      (device) => _findSimulator(device).then((value) => value.boot()),
    ));
  }

  /// Upload an existing app bundle to the simulator and run it.
  Future<void> _runDevice(
    String deviceName,
    String? deviceId,
  ) async {
    currentDeviceId = deviceId;
    simulator = await _findSimulator(deviceName);
    await simulator!.boot();

    if (simulator!.platform == IosSimulatorPlatform.iPad) {
      await simulator!.setOrientation(args.tabletOrientation);
    }

    final ipcServer = await IpcServer.start();
    ipcServer.onMessage = _onMessage;

    await simulator!.installApp('build/ios/iphonesimulator/Runner.app');
    await simulator!.launchApp(args.bundleId!);

    await ipcServer.clientDone;
    await ipcServer.close();
    await simulator!.shutdown();
  }

  Future<IosSimulator> _findSimulator(String name) async {
    _simulators ??= await IosSimulator.listAll();
    return _simulators!.firstWhere(
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
      // ignore: avoid_print
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
