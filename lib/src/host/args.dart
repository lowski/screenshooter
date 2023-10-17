// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';
import 'package:checked_yaml/checked_yaml.dart';

import '../common.dart';

class _ScreenshotFileConfig {
  final String? path;
  final List<String>? locales;
  final String? target;

  _ScreenshotFileConfig._({
    this.path,
    this.locales,
    this.target,
  });

  factory _ScreenshotFileConfig.fromJson(Map json) => _ScreenshotFileConfig._(
        path: json['path'],
        locales: json['locales']?.cast<String>(),
        target: json['target'],
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

  List<String>? get _locales => (_args['locales'] as List?)?.isNotEmpty ?? false
      ? _args['locales']
      : _fileConfig.locales;

  ScreenshotConfiguration get configuration => ScreenshotConfiguration(
        username:
            _args['username'] ?? Platform.environment['SCREENSHOTS_USERNAME'],
        password:
            _args['password'] ?? Platform.environment['SCREENSHOTS_PASSWORD'],
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
  parser.addFlag(
    'verbose',
    abbr: 'v',
    help: 'Prints more information',
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
    help: 'Set the username to use for login. (Default \$SCREENSHOTS_USERNAME)',
  );
  parser.addOption(
    'password',
    help: 'Set the password to use for login. (Default \$SCREENSHOTS_PASSWORD)',
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
