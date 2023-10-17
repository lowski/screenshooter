import 'dart:convert';

import 'utils.dart';

enum IosSimulatorPlatform {
  iPhone,
  iPad,
  unknown,
}

/// The orientation of the simulator.
enum IosSimulatorOrientation {
  // DO NOT CHANGE THE ORDER OF THESE VALUES.
  portrait,
  landscapeLeft,
  portraitUpsideDown,
  landscapeRight,
}

enum IosSimulatorRotation {
  left,
  right,
}

class IosSimulator {
  final String deviceId;
  final String name;
  final IosSimulatorPlatform platform;

  /// Whether the simulator is booted.
  bool isBooted = false;

  /// The current orientation of the simulator. This is only valid if the
  /// orientation when the simulator was booted was portrait and the simulator
  /// has not been rotated manually.
  IosSimulatorOrientation orientation = IosSimulatorOrientation.portrait;

  IosSimulator({
    required this.deviceId,
    required this.name,
    required this.platform,
  });

  /// Boot the simulator.
  Future<void> boot() async {
    if (isBooted) {
      return;
    }
    await exec(['xcrun', 'simctl', 'boot', deviceId]);
    isBooted = true;
  }

  /// Shutdown the simulator.
  Future<void> shutdown() async {
    await exec(['xcrun', 'simctl', 'shutdown', deviceId]);
    isBooted = false;
  }

  /// Reset the simulator for a clean state.
  Future<void> dispose() async {
    await setOrientation(IosSimulatorOrientation.portrait);
  }

  /// Take a screenshot of the simulator and save it to [path].
  Future<void> screenshot(String path) async {
    if (!isBooted) {
      throw StateError('Simulator is not booted.');
    }
    await exec(['xcrun', 'simctl', 'io', deviceId, 'screenshot', path]);
  }

  /// Rotate the simulator.
  @Deprecated('Use setOrientation instead.')
  Future<void> rotate(IosSimulatorRotation rotation) async {
    if (!isBooted) {
      throw StateError('Simulator is not booted.');
    }

    await exec([
      'osascript',
      '-e',
      'tell application "Simulator" to activate',
      '-e',
      'tell application "System Events" to click menu item "Rotate ${rotation == IosSimulatorRotation.left ? 'Left' : 'Right'}" of menu 1 of menu bar item "Device" of menu bar 1 of application process "Simulator"',
    ]);

    orientation = IosSimulatorOrientation.values[
        (orientation.index + (rotation == IosSimulatorRotation.left ? 1 : 3)) %
            4];
  }

  /// Set the orientation of the simulator.
  ///
  /// This will only work if the simulator was booted in portrait mode and has
  /// not been rotated manually.
  Future<void> setOrientation(IosSimulatorOrientation orientation) async {
    if (!isBooted) {
      throw StateError('Simulator is not booted.');
    }

    for (var i = 0; i < (this.orientation.index - orientation.index) % 4; i++) {
      await rotate(IosSimulatorRotation.left);
    }

    assert(this.orientation == orientation);
  }

  /// List all available simulators.
  static Future<List<IosSimulator>> listAll() async {
    final result = await exec(['xcrun', 'simctl', 'list', '-j']);
    final json = result.stdout;
    final devices =
        ((jsonDecode(json) as Map)['devices'] as Map).cast<String, dynamic>();
    final simulators = <IosSimulator>[];
    for (final runtime in devices.values) {
      if (runtime is! List) {
        continue;
      }
      for (final simulator in runtime) {
        if (simulator is! Map || simulator['isAvailable'] != true) {
          continue;
        }
        final deviceId = simulator['udid'] as String;
        final name = simulator['name'] as String;
        final deviceTypeIdentifier =
            simulator['deviceTypeIdentifier'] as String;

        simulators.add(
          IosSimulator(
            deviceId: deviceId,
            name: name,
            platform: deviceTypeIdentifier.contains('iPad')
                ? IosSimulatorPlatform.iPad
                : deviceTypeIdentifier.contains('iPhone')
                    ? IosSimulatorPlatform.iPhone
                    : IosSimulatorPlatform.unknown,
          )..isBooted = simulator['state'] == 'Booted',
        );
      }
    }
    return simulators;
  }

  @override
  String toString() {
    return 'IosSimulator($name, $deviceId, $platform)';
  }
}
