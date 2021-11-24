import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/lslr.dart';

Future<void> main(List<String> argv) async {
  final ArgParser argp = ArgParser();
  argp.addOption("mirror",
      abbr: "m",
      help: "Mirror URL",
      defaultsTo: "https://cdimage.debian.org/debian-cd/");
  argp.addFlag("help", abbr: "h", help: "Show Command Usage", negatable: false);

  Never printUsageAndExit() {
    print("Usage: tools/bin/generate_debian_metadata.dart [options]");
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
  final mirrorUrl = Uri.parse(args["mirror"]);
  final mirrorIndexUrl = mirrorUrl.resolve("./ls-lR.gz");
  final http = HttpClient();
  final request = await http.getUrl(mirrorIndexUrl);
  final response = await request.close();
  final decompressedIndexStream = gzip.decoder.bind(response);
  final utf8IndexStream = utf8.decoder.bind(decompressedIndexStream);
  final linesIndexStream = LineSplitter().bind(utf8IndexStream);
  final index = await LslrIndexUnstructured.parse(linesIndexStream);
  final structure = index.createFullStructure();
  final jigdoFiles = structure.find(
      RegExp(r"^.*\/jigdo-cd\/debian\-[0-9].*\-netinst\.jigdo$"),
      matchOnFullPath: true);
  for (final jigdoFile in jigdoFiles) {
    final jigdoFileName = jigdoFile.name;
    print(jigdoFileName);
  }
  http.close();
}
