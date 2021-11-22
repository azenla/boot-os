import 'dart:async';
import 'dart:io';

import 'package:boot_os_tools/sources.dart';
import 'package:boot_os_tools/download.dart';

import 'package:pool/pool.dart';

class DownloadTask {
  final HttpClient http;
  final SourceFile sourceFile;
  final String targetFilePath;

  DownloadTask(this.http, this.sourceFile, this.targetFilePath);

  Future<void> downloadAndVerify() async {
    final url = Uri.parse(sourceFile.urls.first);
    print("[download] ${targetFilePath}");
    final targetFile = await http.downloadToFile(url, targetFilePath);
    print("[verify] ${targetFilePath}");
    await sourceFile.checksums.validatePreferredHash(targetFile);
  }
}

Future<void> main(List<String> args) async {
  final http = HttpClient();
  final tasks = <DownloadTask>[];
  for (final os in args) {
    final osSourcesFilePath = "${os}/sources.json";
    final osSourcesDirPath = "${os}/sources";
    final Directory osSourcesDir = Directory(osSourcesDirPath);
    if (!(await osSourcesDir.exists())) {
      await osSourcesDir.create();
    }
    final sources = await JsonFileSources.loadFromFile(osSourcesFilePath);
    for (final name in sources.files.keys) {
      final sourceFile = sources.files[name];
      final targetFilePath = "${osSourcesDirPath}/${name}";
      if (sourceFile == null) {
        continue;
      }
      tasks.add(DownloadTask(http, sourceFile, targetFilePath));
    }
  }

  final pool = Pool(4);
  await Future.wait(
      tasks.map((task) => pool.withResource(() => task.downloadAndVerify())));
  http.close();
}
