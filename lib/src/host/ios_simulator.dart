import 'dart:convert';

import 'utils.dart';

class IosSimulatorSize {
  final double width;
  final double height;

  IosSimulatorSize(this.width, this.height);

  @override
  String toString() {
    return 'IosSimulatorSize($width, $height)';
  }
}

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
      // ignore: deprecated_member_use_from_same_package
      await rotate(IosSimulatorRotation.left);
    }

    assert(this.orientation == orientation);
  }

  /// Install the .app bundle located at [path] on the simulator.
  Future<void> installApp(String path) async {
    if (!isBooted) {
      throw StateError('Simulator is not booted.');
    }
    await exec(['xcrun', 'simctl', 'install', deviceId, path]);
  }

  /// Launch the app with the bundle identifier [bundleId] on the simulator.
  Future<void> launchApp(String bundleId) async {
    if (!isBooted) {
      throw StateError('Simulator is not booted.');
    }
    await exec(['xcrun', 'simctl', 'launch', deviceId, bundleId]);
  }

  Future<IosSimulatorSize> get size async {
    final result = await exec([
      'xcrun',
      'simctl',
      'io',
      deviceId,
      'enumerate',
    ]);
    final ports = (result.stdout as String).split('Port:').map((e) => e.trim());
    // Example port we are looking for:
    // Port:
    //     UUID: 09022C69-26FE-4A81-BFB7-F4B9F8B8C842
    //     Class: Display
    //     Port Identifier: com.apple.framebuffer.display
    //     Power state: On
    //     Display class: 0
    //     Default width: 1284
    //     Default height: 2778
    //     Default pixel format: 'BGRA'
    //     IOSurface port:
    //         width              = 1284
    //         height             = 2778
    //         bytes per row      = 5184
    //         size               = 14401536
    //         pixel format       = 'BGRA'
    //         bytes per element  = 4
    //         CPU cache mode     = Default cache
    //         Pixel size casting = Yes

    final port = ports.firstWhere((element) => element.contains('IOSurface'));
    final lines = port.split('\n');
    final width = lines
        .firstWhere((element) => element.trim().startsWith('Default width'))
        .split(':')
        .last
        .trim();
    final height = lines
        .firstWhere((element) => element.trim().startsWith('Default height'))
        .split(':')
        .last
        .trim();
    return IosSimulatorSize(double.parse(width), double.parse(height));
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

  /// Create a new simulator with the given [modelName] that has the same name as
  /// the model.
  static Future<IosSimulator?> create(String modelName) async {
    final result =
        await exec(['xcrun', 'simctl', 'create', modelName, modelName]);
    final simulators = await listAll();
    return simulators.firstWhere(
      (element) => element.name == modelName,
      orElse: () =>
          throw Exception('Simulator creation failed: ${result.stderr}'),
    );
  }

  @override
  String toString() {
    return 'IosSimulator($name, $deviceId, $platform)';
  }
}
