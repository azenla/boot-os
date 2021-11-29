library boot.os.tools.download;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boot_os_tools/sources.dart';
import 'package:boot_os_tools/fasthash.dart';
import 'package:pool/pool.dart';

import 'jigdo.dart';

class GlobalDownloadPool {
  static Pool? _pool = null;

  static Future<T> use<T>(FutureOr<T> Function() task) {
    if (_pool != null) {
      return _pool!.withResource(() => task());
    } else {
      return Future(() async => await task());
    }
  }

  static void setup(int maxParallelDownloads) {
    _pool = Pool(maxParallelDownloads);
  }
}

extension DownloadHttpClient on HttpClient {
  Future<File> downloadToFile(Uri url, String path,
      {bool failOnNotFound = true}) async {
    final file = File(path);
    final request = await getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain();
      if (response.statusCode == 404 && !failOnNotFound) {
        return file;
      }
      throw Exception(
          "Download of ${url} failed. Status Code: ${response.statusCode}");
    }

    if (!(await file.parent.exists())) {
      await file.parent.create();
    }

    final output = await file.openWrite();
    await response.listen((bytes) {
      output.add(bytes);
    }).asFuture();
    await output.close();
    return file;
  }

  Future<String> getUrlString(Uri url) async {
    final stream = await getUrlStream(url);
    return await stream.transform(utf8.decoder).join();
  }

  Future<String?> getUrlStringMaybe(Uri url) async {
    final stream = await getUrlStreamMaybe(url);
    return await stream?.transform(utf8.decoder).join();
  }

  Future<Stream<List<int>>> getUrlStream(Uri url) async {
    final request = await getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      response.listen((bytes) {});
      throw Exception(
          "Fetch of ${url} failed. Status Code: ${response.statusCode}");
    }
    return response;
  }

  Future<Stream<List<int>>?> getUrlStreamMaybe(Uri url) async {
    final request = await getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      response.listen((bytes) {});
      return null;
    }
    return response;
  }
}

class SourceDownload {
  final HttpClient http;
  final String outputDirectoryPath;
  final String outputFileName;
  final SourceFile metadata;

  SourceDownload(
      this.http, this.outputDirectoryPath, this.outputFileName, this.metadata);

  Future<void> download() async {
    if (metadata.assemble == null) {
      await GlobalDownloadPool.use(() async => await downloadDirectFile());
    } else {
      final assemble = metadata.assemble!;
      for (final entry in assemble.sources.files.entries) {
        final fileName = entry.key;
        final file = entry.value;
        final download =
            SourceDownload(http, outputDirectoryPath, fileName, file);
        await download.download();
      }

      final outputFilePath = "$outputDirectoryPath/$outputFileName";
      final file = File(outputFilePath);

      if (await file.exists()) {
        if (await metadata.checksums
            .validatePreferredHash(file, shouldThrowError: false)) {
          print("[cached] ${outputFilePath}");
          return;
        }
      }

      if (assemble.type == "jigdo") {
        final jigdoFileName =
            assemble.sources.files.keys.firstWhere((e) => e.endsWith(".jigdo"));
        final templateFileName = assemble.sources.files.keys
            .firstWhere((e) => e.endsWith(".template"));
        final jigdoFile = File("$outputDirectoryPath/$jigdoFileName");
        final jigdoFileBytes = await jigdoFile.readAsBytes();
        String jigdoFileContent;
        try {
          jigdoFileContent = utf8.decode(gzip.decode(jigdoFileBytes));
        } catch (e) {
          jigdoFileContent = utf8.decode(jigdoFileBytes);
        }
        final jigdoMetadata = JigdoMetadataFile.parse(jigdoFileContent);
        final partsToUrls = jigdoMetadata.generatePossibleUrls();
        final cache = JigdoCache.globalJigdoCache != null
            ? JigdoCache.globalJigdoCache!
            : JigdoCache(http, Directory("${outputDirectoryPath}/jigdo"));
        final allFilePaths = <String>[];

        final tasks = partsToUrls.entries.map((entry) {
          return GlobalDownloadPool.use(() {
            return cache.download(
                entry.value, ChecksumWithHash(entry.key, md5));
          });
        });
        final results = await Future.wait(tasks);
        for (final cachedFile in results) {
          allFilePaths.add(cachedFile.absolute.path);
        }

        if (await file.exists()) {
          await file.delete();
        }
        print("[jigdo] $outputFilePath");
        await runJigdoMakeImage(outputDirectoryPath, outputFileName,
            jigdoFileName, templateFileName, allFilePaths);
      } else {
        throw Exception("Unknown assemble type '${assemble.type}'");
      }

      print("[validate] ${outputFilePath}");
      await metadata.checksums.validatePreferredHash(file);
    }
  }

  Future<void> downloadDirectFile() async {
    final urlStrings = metadata.urls!.toList();
    while (urlStrings.isNotEmpty) {
      final urlString = urlStrings.removeAt(0);
      final url = Uri.parse(urlString);
      final didSucceed = await downloadNeededFile(
          outputFileName, url, metadata.checksums,
          failOnNotFound: urlStrings.isEmpty);
      if (!didSucceed) {
        print("[next] ${outputFileName}");
      }
    }
  }

  Future<bool> downloadNeededFile(
      String fileName, Uri url, SourceFileChecksums checksums,
      {bool failOnNotFound = true}) async {
    final outputFilePath = "$outputDirectoryPath/$fileName";
    final file = File(outputFilePath);
    if (await file.exists()) {
      print("[validate] ${outputFilePath}");
      if (await checksums.validatePreferredHash(file,
          shouldThrowError: false)) {
        print("[cached] ${outputFilePath}");
        return true;
      } else {
        print("[invalid] ${outputFilePath}");
      }
    }
    print("[download] ${outputFilePath}");
    final downloadedFile = await http.downloadToFile(
        url, "$outputDirectoryPath/$fileName",
        failOnNotFound: failOnNotFound);
    if (!failOnNotFound) {
      if (!(await downloadedFile.exists())) {
        return false;
      }
    }
    print("[validate] ${outputFilePath}");
    await checksums.validatePreferredHash(downloadedFile);
    return true;
  }
}
