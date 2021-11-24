library boot.os.tools.download;

import 'dart:async';
import 'dart:io';

import 'package:boot_os_tools/sources.dart';

import 'jigdo.dart';

extension DownloadHttpClient on HttpClient {
  Future<File> downloadToFile(Uri url, String path) async {
    final file = File(path);

    if (!(await file.parent.exists())) {
      await file.parent.create();
    }

    final request = await getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception(
          "Download of ${url} failed. Status Code: ${response.statusCode}");
    }

    final output = await file.openWrite();
    await response.pipe(output);
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

      if (assemble.type == "jigdo") {
        final jigdoFile =
            assemble.sources.files.keys.firstWhere((e) => e.endsWith(".jigdo"));
        print("[jigdo] ${outputDirectoryPath}/$jigdoFile");
        await runJigdoLiteIn(
            outputDirectoryPath, ["--noask", "--scan", ".", jigdoFile]);
      } else {
        throw Exception("Unknown assemble type '${assemble.type}'");
      }

      final outputFilePath = "$outputDirectoryPath/$outputFileName";
      final file = File(outputFilePath);
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
