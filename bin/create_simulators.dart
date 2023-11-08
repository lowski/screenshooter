import 'package:screenshooter/src/host/args.dart';
import 'package:screenshooter/src/host/ios_simulator.dart';

void main(List<String> argv) async {
  final args = ScreenshotArgs(argv);
  final simulators = await IosSimulator.listAll();
  for (final deviceName in args.devices.keys) {
    if (simulators.any((e) => e.name == deviceName)) {
      print('Device $deviceName already exists.');
      continue;
    }
    print('Creating device $deviceName...');
    await IosSimulator.create(deviceName);
  }
}
