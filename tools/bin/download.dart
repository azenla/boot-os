import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/os.dart';
import 'package:boot_os_tools/pool.dart';
import 'package:boot_os_tools/download.dart';

Future<void> downloadAllSources(
    HttpClient http, int downloadPoolSize, List<OperatingSystem> osList) async {
  final tasks = <SourceDownload>[];
  for (final os in osList) {
    for (final name in os.metadata.sources.files.keys) {
      final sourceFile = os.metadata.sources.files[name];
      if (sourceFile == null) {
        continue;
      }
      tasks.add(
          SourceDownload(http, os.sourcesDirectory.path, name, sourceFile));
    }
  }
  await runTasksWithMaxConcurrency(
      downloadPoolSize, tasks.map((e) => e.download).toList());
}

Future<void> main(List<String> argv) async {
  final ArgParser argp = ArgParser();
  argp.addOption("max-parallel-downloads",
      abbr: "p", help: "Maximum Parallel Downloads", defaultsTo: "3");
  argp.addFlag("help", abbr: "h", help: "Show Command Usage", negatable: false);

  Never printUsageAndExit() {
    print("Usage: tools/bin/download.dart [options] [os...]");
    print(argp.usage);
    exit(1);
  }

  ArgResults args;
  try {
    args = argp.parse(argv);
  } catch (e) {
    print(e);
    printUsageAndExit();
  }

  if (args["help"]) {
    printUsageAndExit();
  }
  final maxParallelDownloads = int.parse(args["max-parallel-downloads"]);

  final http = HttpClient();
  http.maxConnectionsPerHost = maxParallelDownloads;
  final osList =
      await Future.wait(args.rest.map((path) => OperatingSystem.load(path)));
  await downloadAllSources(http, maxParallelDownloads, osList);
  http.close();
}
