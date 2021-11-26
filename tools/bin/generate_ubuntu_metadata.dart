import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/download.dart';
import 'package:boot_os_tools/hashlist.dart';
import 'package:boot_os_tools/os.dart';
import 'package:boot_os_tools/sources.dart';
import 'package:boot_os_tools/util.dart';
import 'package:crypto/crypto.dart';

Never printUsageAndExit(ArgParser argp) {
  print("Usage: tools/bin/generate_ubuntu_metadata.dart [options]");
  print("");
  print(argp.usage);
  if (argp.commands.isNotEmpty) {
    print("");
  }
  for (final commandName in argp.commands.keys) {
    print("Command: ${commandName}");
    print("");
    print(argp.commands[commandName]!.usage);
  }
  exit(1);
}

Future<void> main(List<String> argv) async {
  final argp = ArgParser();
  argp.addFlag("help", abbr: "h", help: "Show Command Usage", negatable: false);

  final singleReleaseCommand = ArgParser();
  singleReleaseCommand.addOption("ubuntu-version",
      abbr: "V", help: "Ubuntu Version", mandatory: true);
  singleReleaseCommand.addOption("ubuntu-release",
      abbr: "r", help: "Ubuntu Release", mandatory: true);
  singleReleaseCommand.addOption("architecture",
      abbr: "a", help: "Architecture", defaultsTo: "amd64");
  singleReleaseCommand.addOption("mirror-url",
      abbr: "m", help: "Mirror URL", defaultsTo: "https://releases.ubuntu.com");
  argp.addCommand("single-release", singleReleaseCommand);

  ArgResults args;
  try {
    args = argp.parse(argv);
  } catch (e) {
    print(e);
    printUsageAndExit(argp);
  }

  if (args["help"]) {
    printUsageAndExit(argp);
  }

  final command = args.command;
  if (command == null) {
    printUsageAndExit(argp);
  }

  final commandName = command.name!;
  switch (commandName) {
    case "single-release":
      await runSingleReleaseTool(command);
      break;
    default:
      printUsageAndExit(argp);
  }
}

Future<void> runSingleReleaseTool(ArgResults args) async {
  final http = HttpClient();
  final version = args["ubuntu-version"].toString();
  final release = args["ubuntu-release"].toString();
  final architecture = args["architecture"].toString();
  final mirrorUrlString = args["mirror-url"].toString();
  final mirrorUrl = Uri.parse(mirrorUrlString);
  final releaseDirectoryUrl = mirrorUrl.resolve("./$version/");
  final sha256HashesUrl = releaseDirectoryUrl.resolve("SHA256SUMS");
  final hashListString = await http.getUrlString(sha256HashesUrl);
  final hashList = HashList.parse(sha256, hashListString.split("\n"));
  final fileNames = hashList.files.keys.toList();
  final desktopIsoFileName = fileNames.firstWhere(
      (fileName) => fileName.endsWith("desktop-${architecture}.iso"));
  final desktopIsoChecksum = hashList.files[desktopIsoFileName];
  final sources = Sources({
    desktopIsoFileName: SourceFile(
        "live",
        architecture,
        "iso",
        version,
        <String>[
          releaseDirectoryUrl.resolve("./${desktopIsoFileName}").toString()
        ],
        null,
        SourceFileChecksums(desktopIsoChecksum, null))
  });
  final osMetadata = OperatingSystemMetadata(
      "ubuntu", release, <String>[architecture], sources);
  final encoded = osMetadata.encode();
  removeAllNullValues(encoded);
  print(const JsonEncoder.withIndent("  ").convert(encoded));
  http.close();
}
