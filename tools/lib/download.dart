library boot.os.tools.download;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:boot_os_tools/sources.dart';
import 'package:crypto/crypto.dart';

import 'jigdo.dart';

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
      await downloadDirectFile();
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
        final cache =
            JigdoCache(http, Directory("${outputDirectoryPath}/jigdo"));
        final allFilePaths = <String>[];
        for (final e in partsToUrls.entries) {
          final file =
              await cache.download(e.value, ChecksumWithHash(e.key, md5));
          allFilePaths.add(file.absolute.path);
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
    final url = Uri.parse(metadata.urls!.first);
    await downloadNeededFile(outputFileName, url, metadata.checksums);
  }

  Future<void> downloadNeededFile(
      String fileName, Uri url, SourceFileChecksums checksums) async {
    final outputFilePath = "$outputDirectoryPath/$fileName";
    final file = File(outputFilePath);
    if (await file.exists()) {
      print("[validate] ${outputFilePath}");
      if (await checksums.validatePreferredHash(file,
          shouldThrowError: false)) {
        print("[cached] ${outputFilePath}");
        return;
      } else {
        print("[invalid] ${outputFilePath}");
      }
    }
    print("[download] ${outputFilePath}");
    final downloadedFile =
        await http.downloadToFile(url, "$outputDirectoryPath/$fileName");
    print("[validate] ${outputFilePath}");
    await checksums.validatePreferredHash(downloadedFile);
  }
}
