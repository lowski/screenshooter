// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';
import 'package:checked_yaml/checked_yaml.dart';
import 'package:screenshooter/src/host/ios_simulator.dart';

import '../common.dart';

T? _loadFromYaml<T>(
  String path, {
  String? key,
  required T Function(Map) fromJson,
}) {
  final file = File(path);
  if (!file.existsSync()) {
    return null;
  }
  final content = file.readAsStringSync();
  return checkedYamlDecode(
    content,
    (yaml) => yaml == null
        ? null
        : fromJson(
            Map.from(key == null ? yaml : yaml[key]),
          ),
  );
}

class ScreenshotFrameConfig {
  final String? path;
  final String? background;
  final num? paddingPercent;
  final Map<String, Map<String, String>>? titles;
  final String? font;
  final num? fontSize;
  final String? fontColor;
  final List<String>? frameSelectors;
  final String suffixFrame;
  final String suffixText;
  final Map<String, String> deviceFrameNames;
  final bool scaleDownFrameToFit;

  ScreenshotFrameConfig._({
    this.path,
    this.background,
    this.paddingPercent,
    this.titles,
    this.font,
    this.fontSize,
    this.fontColor,
    this.frameSelectors,
    this.suffixFrame = '_framed',
    this.suffixText = '',
    this.deviceFrameNames = const {},
    this.scaleDownFrameToFit = false,
  });

  factory ScreenshotFrameConfig.fromJson(Map json) => ScreenshotFrameConfig._(
        path: json['path'],
        background: json['background'],
        paddingPercent: json['paddingPercent'],
        titles:
            (json['titles'] as Map?)?.map((k, v) => MapEntry(k, Map.from(v))),
        font: json['font'],
        fontSize: json['fontSize'],
        fontColor: json['fontColor'],
        frameSelectors: (json['frameSelectors'] as List?)?.cast<String>(),
        suffixFrame: json['suffixFrame'] ?? '_framed',
        suffixText: json['suffixText'] ?? '',
        deviceFrameNames:
            json['deviceFrameNames']?.cast<String, String>() ?? {},
        scaleDownFrameToFit: json['scaleDownFrameToFit'] ?? false,
      );

  /// Loads the configuration from a file. First, it tries to load the
  /// configuration from a `screenshooter.frames.yaml` file. If that does not
  /// exist, it tries to load it from a `screenshooter.yaml` file. If that does
  /// not exist, it tries to load it from a 'pubspec.yaml' file.
  /// If that does not exist, it returns an empty configuration.
  factory ScreenshotFrameConfig.fromConfigFiles() =>
      ScreenshotFrameConfig.fromFile('screenshooter.frames.yaml', key: null) ??
      ScreenshotFrameConfig.fromFile('screenshooter.yaml', key: 'frames') ??
      ScreenshotFrameConfig.fromFile('pubspec.yaml', key: 'frames') ??
      ScreenshotFrameConfig._();

  /// Loads the configuration from a YAML file.
  ///
  /// The [key] is the key in the YAML file to look for. If it is `null`, the
  /// whole YAML file is parsed.
  static ScreenshotFrameConfig? fromFile(
    String path, {
    String? key = 'frames',
  }) =>
      _loadFromYaml(
        path,
        key: key,
        fromJson: ScreenshotFrameConfig.fromJson,
      );
}

class _ScreenshotFileConfig {
  final String? path;
  final List<String>? locales;
  final String? target;
  final Map<String, String>? devices;
  final String? bundleId;
  final IosSimulatorOrientation? tabletOrientation;

  _ScreenshotFileConfig._({
    this.path,
    this.locales,
    this.target,
    this.devices,
    this.bundleId,
    this.tabletOrientation = IosSimulatorOrientation.portrait,
  });

  factory _ScreenshotFileConfig.fromJson(Map json) => _ScreenshotFileConfig._(
        path: json['path'],
        locales: json['locales']?.cast<String>(),
        target: json['target'],
        devices: json['devices']?.cast<String, String>(),
        bundleId: json['bundleId'],
        tabletOrientation: switch (json['tabletOrientation']) {
          'portrait' => IosSimulatorOrientation.portrait,
          'landscape' || null => IosSimulatorOrientation.landscapeLeft,
          _ => throw ArgumentError.value(
              json['tabletOrientation'],
              'tabletOrientation',
              'Invalid value',
            ),
        },
      );

  /// Loads the configuration from a file. First, it tries to load the
  /// configuration from a `screenshooter.yaml` file. If that does not exist,
  /// it tries to load it from a `pubspec.yaml` file.
  /// If that does not exist, it returns an empty configuration.
  ///
  /// In the `pubspec.yaml` file, the configuration is expected to be in the
  /// `screenshooter` key. Otherwise, the whole file is parsed.
  factory _ScreenshotFileConfig.fromConfigFiles() =>
      _ScreenshotFileConfig.fromFile('screenshooter.yaml', key: null) ??
      _ScreenshotFileConfig.fromFile('pubspec.yaml') ??
      _ScreenshotFileConfig._();

  /// Loads the configuration from a YAML file.
  ///
  /// The [key] is the key in the YAML file to look for. If it is `null`, the
  /// whole YAML file is parsed.
  static _ScreenshotFileConfig? fromFile(
    String path, {
    String? key = 'screenshooter',
  }) {
    final pubspecFile = File(path);
    if (!pubspecFile.existsSync()) {
      return null;
    }
    final content = pubspecFile.readAsStringSync();
    return checkedYamlDecode(
      content,
      (yaml) => yaml == null
          ? null
          : _ScreenshotFileConfig.fromJson(
              key == null ? yaml : yaml[key],
            ),
    );
  }
}

class ScreenshotArgs {
  late final ArgResults _args;
  late final _ScreenshotFileConfig _fileConfig;

  ScreenshotArgs(List<String> argv) {
    _args = parseCommandArguments(argv);
    if (_args['file'] != null) {
      final cfg = _ScreenshotFileConfig.fromFile(_args['file']!);
      if (cfg == null) {
        throw ArgumentError.value(
          _args['file'],
          'file',
          'Configuration file does not exist',
        );
      }
      _fileConfig = cfg;
    } else {
      _fileConfig = _ScreenshotFileConfig.fromConfigFiles();
    }
  }

  String get target =>
      _args['target'] ?? _fileConfig.target ?? 'lib/screenshots.dart';
  String? get device => _args['device'];
  bool get verbose => _args['verbose'] ?? false;
  String get path => _args['path'] ?? _fileConfig.path ?? '{name}.png';
  Map<String, String> get devices => _fileConfig.devices ?? {};
  String? get bundleId => _args['bundleId'] ?? _fileConfig.bundleId;
  IosSimulatorOrientation get tabletOrientation =>
      _fileConfig.tabletOrientation ?? IosSimulatorOrientation.portrait;
  bool get skipBuild => _args['skip-build'] ?? false;

  List<String>? get _locales => (_args['locales'] as List?)?.isNotEmpty ?? false
      ? _args['locales']
      : _fileConfig.locales;

  ScreenshotConfiguration get configuration => ScreenshotConfiguration(
        username:
            _args['username'] ?? Platform.environment['SCREENSHOOTER_USERNAME'],
        password:
            _args['password'] ?? Platform.environment['SCREENSHOOTER_PASSWORD'],
        // we make this roundtrip to make sure the locales are valid
        locales: _locales == null
            ? null
            : ScreenshotLocale.fromStrings(_locales!)
                .map((e) => e.toLanguageTag())
                .join(','),
      );
}

/// Parses CLI arguments.
ArgResults parseCommandArguments(List<String> argv) {
  var parser = ArgParser();

  parser.addOption(
    'file',
    abbr: 'f',
    help: 'A YAML file with the configuration. If this is omitted, '
        '`screenshooter.yaml` and `pubspec.yaml` (key: `screenshooter`) are '
        'tried.',
  );
  parser.addOption(
    'target',
    abbr: 't',
    help: 'The target file to run (the entrypoint with the [ScrenshotSuite])',
  );
  parser.addOption(
    'path',
    abbr: 'p',
    valueHelp: './{locale}/{name}.png',
    help:
        'Sets the path pattern of the screenshots (with placeholders like `{placeholder}`). Available placeholders: locale, name. (Default: {name}.png)',
  );
  parser.addOption(
    'bundleId',
    help: 'The bundle ID of the app to run the screenshots for.',
  );
  parser.addFlag(
    'verbose',
    abbr: 'v',
    help: 'Prints more information',
  );
  parser.addFlag(
    'skip-build',
    defaultsTo: false,
    help: 'Skips the build step',
  );
  parser.addMultiOption(
    'locales',
    abbr: 'l',
    splitCommas: true,
    defaultsTo: null,
    help: 'A list of locales to run the screenshots for.',
  );
  parser.addOption(
    'device',
    help:
        'The device to run the screenshots on. (Default: the first available device)',
  );
  parser.addOption(
    'username',
    help:
        'Set the username to use for login. (Default \$SCREENSHOOTER_USERNAME)',
  );
  parser.addOption(
    'password',
    help:
        'Set the password to use for login. (Default \$SCREENSHOOTER_PASSWORD)',
  );

  parser.addFlag(
    'help',
    help: 'Show this Dialog',
    defaultsTo: false,
    negatable: false,
  );
  ArgResults args;
  try {
    args = parser.parse(argv);
  } catch (e) {
    print('Invalid command: $e\n\nUsage:');
    print(parser.usage);
    exit(1);
  }
  if (args.rest.isNotEmpty) {
    print('Invalid arguments: ${args.rest.join(', ')}\n\nUsage:');
    print(parser.usage);
    exit(1);
  }
  if (args['help']) {
    print(parser.usage);
    exit(0);
  }
  return args;
}
