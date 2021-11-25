import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/download.dart';
import 'package:boot_os_tools/jigdo.dart';
import 'package:boot_os_tools/sources.dart';
import 'package:crypto/crypto.dart';

Future<void> main(List<String> argv) async {
  final argp = ArgParser();
  argp.addOption("max-parallel-downloads",
      abbr: "p", help: "Maximum Parallel Downloads", defaultsTo: "3");
  argp.addOption("jigdo-cache-path",
      abbr: "c", help: "Jigdo Cache Directory Path", mandatory: true);
  argp.addOption("image-file",
      abbr: "i", help: "Image File Path", mandatory: true);
  argp.addOption("jigdo-file",
      abbr: "j", help: "Jigdo File Path", mandatory: true);
  argp.addOption("template-file",
      abbr: "t", help: "Template File Path", mandatory: true);
  argp.addFlag("help", abbr: "h", help: "Show Command Usage", negatable: false);

  Never printUsageAndExit() {
    print("Usage: tools/bin/jigdo.dart [options]");
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

  final cacheDirectoryPath = args["jigdo-cache-path"];
  final imageFilePath = args["image-file"];
  final jigdoFilePath = args["jigdo-file"];
  final templateFilePath = args["template-file"];
  final maxParallelDownloads = int.parse(args["max-parallel-downloads"]);
  final http = HttpClient();
  http.maxConnectionsPerHost = maxParallelDownloads;
  GlobalDownloadPool.setup(maxParallelDownloads);

  final jigdoFile = File(jigdoFilePath);
  final cacheDirectory = Directory(cacheDirectoryPath);
  final cache = JigdoCache(http, cacheDirectory);
  JigdoCache.globalJigdoCache = cache;

  final jigdoFileBytes = await jigdoFile.readAsBytes();
  String jigdoFileContent;
  try {
    jigdoFileContent = utf8.decode(gzip.decode(jigdoFileBytes));
  } catch (e) {
    jigdoFileContent = utf8.decode(jigdoFileBytes);
  }
  final metadata = JigdoMetadataFile.parse(jigdoFileContent);
  final partsToUrls = metadata.generatePossibleUrls();
  final files = await Future.wait(partsToUrls.entries.map((e) async =>
      await GlobalDownloadPool.use(
          () => cache.download(e.value, ChecksumWithHash(e.key, md5)))));
  http.close();
  final imageFile = File(imageFilePath);
  if (await imageFile.exists()) {
    await imageFile.delete();
  }
  final allFilePaths = files.map((file) => file.path).toList();
  print("[jigdo] ${imageFilePath}");
  await runJigdoMakeImage(Directory.current.path, imageFilePath, jigdoFilePath,
      templateFilePath, allFilePaths);
}
