library boot.os.tools.os;

import 'dart:io';
import 'package:boot_os_tools/sources.dart';
import 'package:path/path.dart' as pathlib;
import 'package:yaml/yaml.dart' as yaml;

class OperatingSystem {
  final String path;
  final OperatingSystemMetadata metadata;

  OperatingSystem(this.path, this.metadata);

  File get sourcesYamlFile => File("$path/sources.yaml");

  Directory get sourcesDirectory => Directory("$path/sources");

  Directory get instancesDirectory => Directory("$path/instances");

  Future<void> ensureSourcesDirectory() async {
    if (!(await sourcesDirectory.exists())) {
      await sourcesDirectory.create(recursive: true);
    }
  }

  Future<void> ensureInstancesDirectory() async {
    if (!(await instancesDirectory.exists())) {
      await instancesDirectory.create(recursive: true);
    }
  }

  static Future<OperatingSystem> load(String path) async {
    final osMetadataPath = "${path}/os.yaml";
    final metadata = await OperatingSystemMetadata.loadFromFile(osMetadataPath);
    return OperatingSystem(path, metadata);
  }

  static Stream<OperatingSystem> loadAllIn(String path) async* {
    final directory = Directory(path);
    await for (final entity in directory.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }

      if (pathlib.basename(entity.path) != "os.yaml") {
        continue;
      }

      var pathOfDirectory = entity.parent.path;
      if (pathOfDirectory.startsWith("./")) {
        pathOfDirectory = pathOfDirectory.substring(2);
      }
      yield await load(pathOfDirectory);
    }
  }
}

class OperatingSystemMetadata {
  final String os;
  final String version;
  final List<String> architectures;

  final Sources sources;

  OperatingSystemMetadata(
      this.os, this.version, this.architectures, this.sources);

  factory OperatingSystemMetadata.decode(Map<dynamic, dynamic> content) {
    return OperatingSystemMetadata(
        content["os"],
        content["version"],
        (content["architectures"] as List<dynamic>).cast<String>(),
        Sources.decode(content["sources"]));
  }

  static Future<OperatingSystemMetadata> loadFromFile(String path) async {
    final file = File(path);
    final content = yaml.loadYaml(await file.readAsString());
    return OperatingSystemMetadata.decode(content);
  }

  Map<String, dynamic> encode() => <String, dynamic>{
        "os": os,
        "version": version,
        "architectures": architectures,
        "sources": sources.encode()
      };
}
