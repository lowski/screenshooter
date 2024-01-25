import 'dart:async';
import 'dart:io';

import '../ipc_message.dart';
import 'args.dart';
import 'flutter_process.dart';
import 'ios_simulator.dart';
import 'ipc_server.dart';
import 'utils.dart';

class ScreenshotHost {
  final ScreenshotArgs args;

  /// The device ID of the next device to be assigned.
  String? _nextDeviceId;

  /// Completes once [_nextDeviceId] has been assigned to a device.
  Completer<void>? _deviceIdAssigned;

  final Map<String, IosSimulator> _simulators = {};

  List<IosSimulator>? _simulatorList;

  ScreenshotHost({
    List<String>? argv,
  }) : args = ScreenshotArgs(argv ?? []);

  /// Run the screenshot host.
  Future<void> run() async {
    _simulatorList ??= await IosSimulator.listAll();
    _bootSimulators(args.devices.keys);

    if (!args.skipBuild) {
      await _build();
    }

    final futures = <Future<void>>[];

    final ipcServer = await IpcServer.start();
    ipcServer.onMessage = _onMessage;
    ipcServer.onRequestClientId = _onRequestClientId;

    for (final device in args.devices.entries) {
      _nextDeviceId = device.value;
      _deviceIdAssigned = Completer();

      final f = _runDevice(
        deviceName: device.key,
        deviceId: device.value,
        ipcServer: ipcServer,
      );
      futures.add(f);

      await _deviceIdAssigned!.future;
    }

    await Future.wait(futures);

    await ipcServer.close();
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
  Future<void> _runDevice({
    required String deviceName,
    String? deviceId,
    required IpcServer ipcServer,
  }) async {
    final simulator = await _findSimulator(deviceName);
    _simulators[deviceId!] = simulator;
    await simulator.boot();

    if (simulator.platform == IosSimulatorPlatform.iPad) {
      await simulator.setOrientation(args.tabletOrientation);
    }

    await simulator.installApp('build/ios/iphonesimulator/Runner.app');
    await simulator.launchApp(args.bundleId!);

    // Now the app is running and we wait for it to finish.

    await ipcServer.clientDone(deviceId);

    _simulators.remove(deviceId);
    await simulator.shutdown();
  }

  Future<IosSimulator> _findSimulator(String name) async {
    _simulatorList ??= await IosSimulator.listAll();
    return _simulatorList!.firstWhere(
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
      print('[${infoMessage.clientId}] ${infoMessage.message}');
    }
  }

  Future<String> _onRequestClientId() async {
    final result = _nextDeviceId ?? 'unknownDevice';
    _deviceIdAssigned?.complete();
    return result;
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
        msg.clientId ?? 'unknownDevice',
      );
    }
    await File(filename).create(recursive: true);

    await _simulators[msg.clientId]?.screenshot(filename);
  }
}
