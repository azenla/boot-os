import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/jigdo.dart';
import 'package:boot_os_tools/os.dart';
import 'package:boot_os_tools/download.dart';

import 'package:path/path.dart' as pathlib;

Future<void> downloadAllSources(HttpClient http, List<OperatingSystem> osList,
    {String? architecture}) async {
  final tasks = <SourceDownload>[];
  for (final os in osList) {
    for (final name in os.metadata.sources.files.keys) {
      final sourceFile = os.metadata.sources.files[name];
      if (sourceFile == null) {
        continue;
      }

      if (architecture != null) {
        if (sourceFile.architecture != architecture) {
          continue;
        }
      }

      tasks.add(
          SourceDownload(http, os.sourcesDirectory.path, name, sourceFile));
    }
  }
  await Future.wait(tasks.map((e) => e.download()));
}

Future<void> main(List<String> argv) async {
  final argp = ArgParser();
  argp.addOption("max-parallel-downloads",
      abbr: "p", help: "Maximum Parallel Downloads", defaultsTo: "3");
  argp.addOption("jigdo-cache-path",
      abbr: "j",
      help: "Jigdo Cache Path",
      defaultsTo: "${Directory.current.absolute.path}/jigdo");
  argp.addOption("architecture", abbr: "a", help: "Limit to Architecture");
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
  var jigdoCachePath = args["jigdo-cache-path"];
  GlobalDownloadPool.setup(maxParallelDownloads);

  final http = HttpClient();
  http.maxConnectionsPerHost = maxParallelDownloads;
  jigdoCachePath =
      pathlib.relative(jigdoCachePath, from: Directory.current.path);
  JigdoCache.globalJigdoCache = JigdoCache(http, Directory(jigdoCachePath));

  final osList =
      await Future.wait(args.rest.map((path) => OperatingSystem.load(path)));
  await downloadAllSources(http, osList,
      architecture: args["architecture"]?.toString());
  http.close();
}
