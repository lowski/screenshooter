// ignore_for_file: avoid_print

import 'package:screenshooter/src/host/ios_simulator.dart';

void main() async {
  final simulators = await IosSimulator.listAll();
  print('Got ${simulators.length} simulators');
  final iphones = simulators
      .where((element) => element.platform == IosSimulatorPlatform.iPhone);

  for (final iphone in iphones) {
    print('Got ${iphone.name}');
  }

  final booted = simulators.firstWhere((e) => e.isBooted);
  print('Booted simulators: $booted');
}
