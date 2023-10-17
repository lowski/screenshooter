import 'dart:async';
import 'dart:convert';
import 'dart:io';

class FlutterProcess {
  final String _executable = 'flutter';
  final String _command;
  Process? _process;

  final List<String> _arguments;

  /// A complete list of all the command arguments for the process.
  List<String> get arguments {
    final args = <String>[_command, ..._arguments];

    for (final entry in _dartDefines.entries) {
      args.addAll(['--dart-define', '${entry.key}=${entry.value}']);
    }

    if (device != null) {
      args.addAll(['-d', device!]);
    }
    if (target != null) {
      args.addAll(['-t', target!]);
    }

    return args;
  }

  final _dartDefines = <String, String>{};

  /// The device to run the process on.
  String? device;

  /// Which file to run.
  String? target;

  FlutterProcess._(this._command, [this._arguments = const []]);

  FlutterProcess.run() : this._('run');

  FlutterProcess.buildIosDebug() : this._('build', ['ios', '--debug']);

  /// Add a dart define to the process.
  void define(String key, String value) => _dartDefines[key] = value;

  /// Start the process.
  Future<void> start({
    bool pipeOutput = false,
  }) async {
    print('Starting process: `$_executable ${arguments.join(' ')}`');
    _process = await Process.start(_executable, arguments);
    if (pipeOutput) {
      _process!.stdout.transform(utf8.decoder).listen(
            (chunk) => stdout.add(
              utf8.encode('\x1B[38;5;8m$chunk\x1B[0m'),
            ),
          );
      _process!.stderr.transform(utf8.decoder).listen(
            (chunk) => stderr.add(
              utf8.encode('\x1B[38;5;9m$chunk\x1B[0m'),
            ),
          );
    }
  }

  Future<void> get done => _process!.exitCode;

  /// Kill the process.
  Future<void> kill() async {
    _process?.kill();
  }
}
