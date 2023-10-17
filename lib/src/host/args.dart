// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';

import '../common.dart';

class ScreenshotArgs {
  late final ArgResults _args;

  ScreenshotArgs.parse(List<String> argv) {
    _args = parseCommandArguments(argv);
  }

  bool? get build => _args['build'];
  String? get deviceIdentifier => _args['deviceIdentifier'];
  String get dir => _args['dir'];
  String get suffix => _args['suffix'];
  List<String>? get overlay => _args['overlay'];
  String? get username => _args['username'];
  String? get password => _args['password'];
  String get suite => _args['suite'];
  String get target => _args['target'];
  String? get device => _args['device'];
  bool get verbose => _args['verbose'];

  ScreenshotConfiguration get configuration => ScreenshotConfiguration(
        username: username ?? Platform.environment['SCREENSHOTS_USERNAME'],
        password: password ?? Platform.environment['SCREENSHOTS_PASSWORD'],
        // we make this roundtrip to make sure the locales are valid
        locales: _args['locales'] == null
            ? null
            : ScreenshotLocale.fromStrings(_args['locales']!)
                .map((e) => e.toLanguageTag())
                .join(','),
      );
}

/// Parses CLI arguments.
ArgResults parseCommandArguments(List<String> argv) {
  var parser = ArgParser();

  parser.addFlag(
    'build',
    defaultsTo: null,
    help: 'Build the screenshot app before running',
  );
  parser.addOption(
    'target',
    abbr: 't',
    defaultsTo: 'lib/screenshots.dart',
    help: 'The target file to run (the entrypoint with the [ScrenshotSuite])',
  );
  parser.addOption(
    'deviceIdentifier',
    abbr: 'i',
    help:
        'Sets the device identifier, which will be used in a platform specific context:\n'
        '- platform "ios": appended to the filename (i.e. "IPHONE_62", "IPAD_9")\n'
        '- platform "android": a subdirectory inside the locale dir (i.e. "phoneScreenshots", "tabletScreenshots")\n',
  );
  parser.addFlag(
    'verbose',
    abbr: 'v',
    defaultsTo: false,
    help: 'Prints more information',
  );
  parser.addOption(
    'dir',
    defaultsTo: './screenshots',
    help: 'Path to the directory where the screenshots will be stored (in '
        'locale specific subdirectories)',
  );
  parser.addMultiOption(
    'locales',
    abbr: 'l',
    splitCommas: true,
    help: 'A list of locales to run the screenshots for.',
  );
  parser.addOption(
    'suffix',
    defaultsTo: '',
    help:
        'A suffix to append to the filename. (Filename: <filename><suffix>.png)',
    valueHelp: 'suffix',
  );
  parser.addOption(
    'device',
    defaultsTo: null,
    help:
        'The device to run the screenshots on. (Default: the first available device)',
  );
  parser.addMultiOption(
    'overlay',
    abbr: 'o',
    help: 'Applies an overlay to the screenshots containing <pattern>.\n'
        'Only the first matching overlay is used.\nThe dimensions are not '
        'adjusted.',
    valueHelp: 'pattern>:<path to overlay>',
  );
  parser.addOption(
    'username',
    help: 'Set the username to use for login. (Default \$SCREENSHOTS_USERNAME)',
  );
  parser.addOption(
    'password',
    help: 'Set the password to use for login. (Default \$SCREENSHOTS_PASSWORD)',
  );
  parser.addOption(
    'suite',
    defaultsTo: 'default',
    help: 'The suite to run. Can contain multiple comma-separated values.',
    abbr: 's',
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
