library boot.os.tools.jigdo;

import 'dart:io';

import 'package:path/path.dart' as paths;

import 'download.dart';
import 'ini.dart';
import 'sources.dart';

SourceFile createJigdoSourceFile(
    String media,
    String architecture,
    String format,
    String version,
    String jigdoFileName,
    List<String> jigdoFileUrls,
    SourceFileChecksums jigdoFileChecksums,
    String templateFileName,
    List<String> templateFileUrls,
    SourceFileChecksums templateFileChecksums,
    SourceFileChecksums resultFileChecksums) {
  return SourceFile(
      media,
      architecture,
      format,
      version,
      null,
      SourceFileAssemble(
          "jigdo",
          Sources({
            jigdoFileName:
                SourceFile.assemble(jigdoFileUrls, null, jigdoFileChecksums),
            templateFileName: SourceFile.assemble(
                templateFileUrls, null, templateFileChecksums)
          })),
      resultFileChecksums);
}

Future<void> runJigdoMakeImage(
    String workingDirectoryPath,
    String imageFileName,
    String jigdoFilePath,
    String templateFilePath,
    List<String> allInputFiles) async {
  final process = await Process.start(
      "jigdo-file",
      [
        "make-image",
        "-i",
        imageFileName,
        "-j",
        jigdoFilePath,
        "-t",
        templateFilePath,
        "-T",
        "-"
      ],
      workingDirectory: workingDirectoryPath);
  process.stdin.writeAll(allInputFiles, "\n");
  process.stdin.close();
  process.stdout.listen((event) {});
  process.stderr.listen((event) {});
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw Exception(
        "jigdo-file failed in $workingDirectoryPath: exit code = $exitCode");
  }
}

class JigdoCache {
  static JigdoCache? globalJigdoCache;

  final HttpClient http;
  final Directory directory;

  JigdoCache(this.http, this.directory);

  Future<File> download(List<Uri> urls, ChecksumWithHash hash) async {
    final pathsToCheck = urls.map(
        (url) => paths.join(directory.path, url.host, url.path.substring(1)));
    for (final cachedFilePath in pathsToCheck) {
      final cachedFile = File(cachedFilePath);
      if (await cachedFile.exists()) {
        print("[jigdo] [cached] ${cachedFilePath}");
        return cachedFile;
      }
    }

    for (final url in urls) {
      final cachedFilePath =
          paths.join(directory.path, url.host, url.path.substring(1));
      final cachedFile = File(cachedFilePath);
      if (await cachedFile.exists()) {
        print("[jigdo] [cached] ${cachedFilePath}");
        return cachedFile;
      }

      if (!(await cachedFile.parent.exists())) {
        await cachedFile.parent.create(recursive: true);
      }

      print("[jigdo] [download] ${cachedFilePath}");
      final downloadedFile =
          await http.downloadToFile(url, cachedFilePath, failOnNotFound: false);
      if (!(await downloadedFile.exists())) {
        print("[jigdo] [next] ${cachedFilePath}");
        continue;
      } else {
        return cachedFile;
      }
    }

    throw Exception("Failed to get file for jigdo download.");
  }
}

class JigdoMetadataFile {
  final RelaxedIniFile ini;

  JigdoMetadataFile(this.ini);

  List<String> get parts => ini.sections["Parts"]!.keys.toList();

  String partPathForKey(String key) => ini.sections["Parts"]![key]!.first;

  Map<String, List<String>> get servers {
    final serverNames = ini.sections["Servers"]!.keys.toList();
    final servers = <String, List<String>>{};
    for (final name in serverNames) {
      final urls = ini.sections["Servers"]![name]!;
      servers[name] = urls.map((e) => e.split(" ").first).toList();
    }
    return servers;
  }

  Map<String, List<Uri>> generatePossibleUrls() {
    final results = <String, List<Uri>>{};

    final servers = this.servers;
    for (final part in parts) {
      final unprocessedFilePath = partPathForKey(part);
      final serverName =
          unprocessedFilePath.substring(0, unprocessedFilePath.indexOf(":"));
      final pathOnServer =
          unprocessedFilePath.substring(unprocessedFilePath.indexOf(":") + 1);
      var serverUrls = servers[serverName]!;
      for (var serverUrl in serverUrls) {
        if (serverUrl.endsWith("/")) {
          serverUrl = serverUrl.substring(0, serverUrl.length - 1);
        }
        final fullUrl = Uri.parse("$serverUrl/$pathOnServer");
        results.update(part, (value) => value..add(fullUrl),
            ifAbsent: () => <Uri>[fullUrl]);
      }
    }

    return results;
  }

  factory JigdoMetadataFile.parse(String content) {
    return JigdoMetadataFile(RelaxedIniFile.parse(content.split("\n")));
  }
}
