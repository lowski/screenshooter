import 'dart:async';
import 'dart:convert';
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
  static const _webpageUrl =
      'https://design.facebook.com/toolsandresources/devices/';

  MetaFrameProvider(String basePath) : super('$basePath/Meta Devices');

  @override
  Future<void> forceDownload() async {
    final archive = await _downloadArchive();
    await _unpackArchive(archive);
  }

  @override
  Future<void> download() async {
    if (FileSystemEntity.isDirectorySync(basePath)) {
      return;
    }

    await forceDownload();
  }

  Future<File> _downloadArchive() async {
    final guiUri = Uri.parse(_webpageUrl);
    final guiRequest = await HttpClient().getUrl(guiUri);
    final guiResponse = await guiRequest.close();
    final guiHtml = await guiResponse.transform(utf8.decoder).join();

    // There is an <a> tag with the download link in the HTML. We can find it
    // because there is only one link that ends with .zip. We need to keep any
    // query parameters, because they are used to authenticate the download.
    final downloadLink = RegExp(r'href="([^"]+\.zip[^"]+)"')
        .firstMatch(guiHtml)
        ?.group(1)
        ?.replaceAll('&amp;', '&');

    if (downloadLink == null) {
      // ignore: avoid_print
      print('\n+--------------------------------------------+\n'
          '| MANUAL ACTION REQUIRED                     |\n'
          '+--------------------------------------------+\n'
          'Could not find download link in HTML. Please download '
          'the archive manually from $guiUri and extract it to '
          '"$basePath".\n'
          'Refer to README.md for more information.\n'
          '----------------------------------------------\n');
      throw Exception('Archive url not found.');
    }

    final uri = Uri.parse(downloadLink);
    final file = File('$basePath/${uri.pathSegments.last}');

    if (file.existsSync()) {
      return file;
    }

    // ignore: avoid_print
    print('Downloading frames...');

    file.createSync(recursive: true);
    final request = await HttpClient().getUrl(uri);
    final response = await request.close();
    await response.pipe(file.openWrite());
    return file;
  }

  Future<void> _unpackArchive(File file) async {
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
