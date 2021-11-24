import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/os.dart';
import 'package:boot_os_tools/pool.dart';
import 'package:boot_os_tools/sources.dart';
import 'package:boot_os_tools/download.dart';

class DownloadTask {
  final HttpClient http;
  final SourceFile sourceFile;
  final String targetFilePath;

  DownloadTask(this.http, this.sourceFile, this.targetFilePath);

  Future<void> downloadAndVerify() async {
    final url = Uri.parse(sourceFile.urls.first);
    print("[download] $targetFilePath");
    final targetFile = await http.downloadToFile(url, targetFilePath);
    print("[checksum] $targetFilePath");
    await sourceFile.checksums.validatePreferredHash(targetFile);
  }
}

Future<void> downloadAllSources(
    HttpClient http, int downloadPoolSize, List<OperatingSystem> osList) async {
  final tasks = <DownloadTask>[];
  for (final os in osList) {
    for (final name in os.metadata.sources.files.keys) {
      final sourceFile = os.metadata.sources.files[name];
      final targetFilePath = "${os.sourcesDirectory.path}/${name}";
      if (sourceFile == null) {
        continue;
      }
      tasks.add(DownloadTask(http, sourceFile, targetFilePath));
    }
  }
  await runTasksWithMaxConcurrency(
      downloadPoolSize, tasks.map((e) => e.downloadAndVerify).toList());
}

Future<void> main(List<String> argv) async {
  final ArgParser argp = ArgParser();
  argp.addOption("max-parallel-downloads",
      abbr: "p", help: "Maximum Parallel Downloads", defaultsTo: "3");
  argp.addFlag("help", abbr: "h", help: "Show Command Usage", negatable: false);
  ArgResults args;
  try {
    args = argp.parse(argv);
  } catch (e) {
    print(e);
    print("Usage: tools/bin/download.dart [options] [os...]");
    print(argp.usage);
    exit(1);
  }

  if (args["help"]) {
    print("Usage: tools/bin/download.dart [options] [os...]");
    print(argp.usage);
    exit(1);
  }
  final maxParallelDownloads = int.parse(args["max-parallel-downloads"]);

  final http = HttpClient();
  final osList =
      await Future.wait(args.rest.map((path) => OperatingSystem.load(path)));
  await downloadAllSources(http, maxParallelDownloads, osList);
  http.close();
}
