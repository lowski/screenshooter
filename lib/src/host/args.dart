// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';

import '../common.dart';

class ScreenshotArgs {
  late final ArgResults _args;

  ScreenshotArgs.parse(List<String> argv) {
    _args = parseCommandArguments(argv);
  }

  String? get username => _args['username'];
  String? get password => _args['password'];
  String get target => _args['target'];
  String? get device => _args['device'];
  bool get verbose => _args['verbose'];
  String get path => _args['path'];

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

  parser.addOption(
    'target',
    abbr: 't',
    defaultsTo: 'lib/screenshots.dart',
    help: 'The target file to run (the entrypoint with the [ScrenshotSuite])',
  );
  parser.addOption(
    'path',
    abbr: 'p',
    defaultsTo: '{name}.png',
    valueHelp: './{locale}/{name}.png',
    help:
        'Sets the path pattern of the screenshots (with placeholders like `{placeholder}`). Available placeholders: locale, name. (Default: {name}.png)',
  );
  parser.addFlag(
    'verbose',
    abbr: 'v',
    defaultsTo: false,
    help: 'Prints more information',
  );
  parser.addMultiOption(
    'locales',
    abbr: 'l',
    splitCommas: true,
    help: 'A list of locales to run the screenshots for.',
  );
  parser.addOption(
    'device',
    defaultsTo: null,
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
