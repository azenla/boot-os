import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/download.dart';
import 'package:boot_os_tools/hashlist.dart';
import 'package:boot_os_tools/os.dart';
import 'package:boot_os_tools/sources.dart';
import 'package:boot_os_tools/util.dart';
import 'package:boot_os_tools/yaml.dart';
import 'package:crypto/crypto.dart';
import 'package:yaml/yaml.dart' as yaml;

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
  singleReleaseCommand.addFlag("write", abbr: "w", help: "Write Metadata");
  argp.addCommand("single-release", singleReleaseCommand);

  final allReleasesCommand = ArgParser();
  allReleasesCommand.addOption("architecture",
      abbr: "a", help: "Architecture", defaultsTo: "amd64");
  allReleasesCommand.addOption("mirror-url",
      abbr: "m", help: "Mirror URL", defaultsTo: "https://releases.ubuntu.com");
  allReleasesCommand.addFlag("write", abbr: "w", help: "Write Metadata");
  allReleasesCommand.addOption("releases-to-versions-path",
      abbr: "r", help: "Releases to Versions Path");
  argp.addCommand("all-releases", allReleasesCommand);

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
    case "all-releases":
      await runAllReleasesTool(command);
      break;
    default:
      printUsageAndExit(argp);
  }
}

Future<void> runAllReleasesTool(ArgResults args) async {
  final http = HttpClient();
  final architecture = args["architecture"].toString();
  final releasesToVersionsPath = args["releases-to-versions-path"].toString();
  final releasesToVersionsFile = File(releasesToVersionsPath);
  final mirrorsToReleasesToVersions =
      (yaml.loadYaml(await releasesToVersionsFile.readAsString())
              as Map<dynamic, dynamic>)
          .cast<String, dynamic>()
          .map((key, value) => MapEntry(
              key, (value as Map<dynamic, dynamic>).cast<String, String>()));
  for (final mirrorUrlString in mirrorsToReleasesToVersions.keys) {
    final releasesToVersions = mirrorsToReleasesToVersions[mirrorUrlString];
    if (releasesToVersions == null) {
      continue;
    }
    final mirrorUrl = Uri.parse(mirrorUrlString);
    for (final releaseToVersion in releasesToVersions.entries) {
      if (!args["write"]) {
        print("---");
      }
      await produceSingleRelease(http, releaseToVersion.key,
          releaseToVersion.value, architecture, mirrorUrl, args["write"]);
    }
  }
  http.close();
}

Future<void> runSingleReleaseTool(ArgResults args) async {
  final http = HttpClient();
  final version = args["ubuntu-version"].toString();
  final release = args["ubuntu-release"].toString();
  final architecture = args["architecture"].toString();
  final mirrorUrlString = args["mirror-url"].toString();
  final mirrorUrl = Uri.parse(mirrorUrlString);
  await produceSingleRelease(
      http, release, version, architecture, mirrorUrl, args["write"]);
  http.close();
}

Future<void> produceSingleRelease(HttpClient http, String release,
    String version, String architecture, Uri mirrorUrl, bool write) async {
  final releaseDirectoryUrl = mirrorUrl.resolve("./$version/");
  final sha256HashesUrl = releaseDirectoryUrl.resolve("SHA256SUMS");
  var hashListString = await http.getUrlStringMaybe(sha256HashesUrl);
  var hashListHash = sha256;

  if (hashListString == null) {
    final md5HashesUrl = releaseDirectoryUrl.resolve("MD5SUMS");
    hashListHash = md5;
    hashListString = await http.getUrlString(md5HashesUrl);
  }

  final hashList = HashList.parse(hashListHash, hashListString.split("\n"));
  final fileNames = hashList.files.keys.toList();
  final desktopIsoFileName = fileNames.firstWhere(
      (fileName) =>
          fileName.endsWith("desktop-${architecture}.iso") &&
          !fileName.contains("-beta-"),
      orElse: () => fileNames.firstWhere(
          (fileName) => fileName.endsWith("-live-${architecture}.iso")));

  final releaseDesktopIsoUrl =
      releaseDirectoryUrl.resolve("./${desktopIsoFileName}");
  final desktopIsoUrlStrings = <String>[releaseDesktopIsoUrl.toString()];

  if (releaseDesktopIsoUrl.host == "releases.ubuntu.com") {
    final oldReleasesDesktopIsoUrl =
        releaseDesktopIsoUrl.replace(host: "old-releases.ubuntu.com");
    desktopIsoUrlStrings.add(oldReleasesDesktopIsoUrl.toString());
  }

  final sources = Sources({
    desktopIsoFileName: SourceFile(
        "live",
        architecture,
        "iso",
        version,
        desktopIsoUrlStrings,
        null,
        hashList.createSourceFileChecksums(desktopIsoFileName)!)
  });
  final osMetadata = OperatingSystemMetadata(
      "ubuntu", release, <String>[architecture], sources);
  final encoded = osMetadata.encode();
  removeAllNullValues(encoded);
  if (write) {
    final osDirectoryPath = "ubuntu/$release";
    final osMetadataPath = "$osDirectoryPath/os.yaml";
    final osMetadataFile = File(osMetadataPath);
    if (!(await osMetadataFile.parent.exists())) {
      await osMetadataFile.parent.create(recursive: true);
    }
    await osMetadataFile.writeAsString(YamlWriter.write(encoded) + "\n");
  } else {
    print(YamlWriter.write(encoded));
  }
}
