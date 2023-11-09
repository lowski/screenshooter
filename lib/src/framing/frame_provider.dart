import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';

abstract class FrameProvider {
  final String basePath;

  FrameProvider(this.basePath);

  /// Download the frames.
  Future<void> forceDownload();

  /// Download the frames if they are not already downloaded.
  Future<void> download();

  /// Returns the path to the "best" matching frame.
  ///
  /// The [criteria] are a list of strings that are used to find the best match.
  ///
  /// Note that this is implemented as a greedy algorithm going directory by
  /// directory. In every step it will use the shortest child that contains one
  /// of the criteria (every criterion can only be used once).
  Future<String> findBestMatch(List<String> criteria);
}

class MetaFrameProvider extends FrameProvider {
  static const _archiveUrl =
      'https://scontent-dus1-1.xx.fbcdn.net/v/t39.8562-6/10000000_929936395109225_7548977251578542904_n.zip?_nc_cat=106&ccb=1-7&_nc_sid=b8d81d&_nc_ohc=fEHvFVVoGn8AX8eXQbu&_nc_ht=scontent-dus1-1.xx&oh=00_AfD1mo2bbo9dPLyy2nfm_zK0Q_tr8myoPDlxPEWF7wjUfQ&oe=6551F95C';

  MetaFrameProvider(String basePath) : super('$basePath/Meta Devices');

  @override
  Future<void> forceDownload() async {
    await _downloadArchive();
    await _unpackArchive();
  }

  @override
  Future<void> download() async {
    if (FileSystemEntity.isDirectorySync(basePath)) {
      return;
    }

    await _downloadArchive();
    await _unpackArchive();
  }

  Future<void> _downloadArchive() async {
    final uri = Uri.parse(_archiveUrl);
    final file = File('$basePath/${uri.pathSegments.last}');

    if (file.existsSync()) {
      return;
    }

    // ignore: avoid_print
    print('Downloading frames...');

    file.createSync(recursive: true);
    final request = await HttpClient().getUrl(uri);
    final response = await request.close();
    await response.pipe(file.openWrite());
  }

  Future<void> _unpackArchive() async {
    final file = File('$basePath/${Uri.parse(_archiveUrl).pathSegments.last}');
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());

    for (final child in archive) {
      if (![
        'Meta Devices/Computers.zip',
        'Meta Devices/Phones.zip',
        'Meta Devices/Tablets.zip',
      ].contains(child.name)) {
        continue;
      }

      final childArchive = ZipDecoder().decodeBytes(child.content);

      for (final child in childArchive) {
        if (!child.isFile ||
            !child.name.endsWith('.png') ||
            child.name.contains('__MACOSX') ||
            child.name.contains('.DS_Store')) {
          continue;
        }
        final out = OutputFileStream('$basePath/${child.name}');
        child.writeContent(out);
        await out.close();
      }
    }
  }

  @override
  Future<String> findBestMatch(List<String> criteria) async {
    final variantSpecifiers = criteria.map((e) => e.toLowerCase()).toList();

    String currentPath = basePath;
    while (FileSystemEntity.isDirectorySync(currentPath)) {
      String currentDefaultPath = currentPath + currentPath;
      String? foundVariantMatch;
      String shortestVariantMatchPath = currentDefaultPath;

      for (final entity in Directory(currentPath).listSync()) {
        if (entity.path.length < currentDefaultPath.length) {
          currentDefaultPath = entity.path;
        }

        for (final variantSpecifier in variantSpecifiers) {
          final name = entity.path.split('/').last.toLowerCase();

          if (name.contains(variantSpecifier)) {
            if (entity.path.length < shortestVariantMatchPath.length) {
              shortestVariantMatchPath = entity.path;
              foundVariantMatch = variantSpecifier;
              break;
            }
          }
        }
      }

      if (foundVariantMatch == null) {
        currentPath = currentDefaultPath;
      } else {
        currentPath = shortestVariantMatchPath;
        variantSpecifiers.remove(foundVariantMatch);
      }
    }

    return currentPath;
  }
}
