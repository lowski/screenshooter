enum FrameDeviceType {
  computer,
  phone,
  tablet,
}

class FrameDeviceInfo {
  final FrameDeviceType type;
  final String device;

  const FrameDeviceInfo({
    required this.type,
    required this.device,
  });

  const FrameDeviceInfo.iPhone(
    String model,
  )   : type = FrameDeviceType.phone,
        device = 'Apple iPhone $model';

  const FrameDeviceInfo.iPad(
    String model,
  )   : type = FrameDeviceType.tablet,
        device = 'Apple iPad $model';

  @override
  String toString() {
    return 'FrameDeviceInfo{$device}';
  }
}
