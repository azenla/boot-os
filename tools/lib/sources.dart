library boot.os.tools.sources;

import 'dart:convert';
import 'dart:io';

class Sources {
  final Map<String, SourceFile> files;

  Sources(this.files);

  factory Sources.decode(Map<String, dynamic> content) {
    var files = Map<String, SourceFile>();
    for (var key in content["files"].keys) {
      var file =
          SourceFile.decode(content["files"][key] as Map<String, dynamic>);
      files[key] = file;
    }
    return Sources(files);
  }
}

class SourceFile {
  final List<String> urls;
  final SourceFileChecksums checksums;

  SourceFile(this.urls, this.checksums);

  factory SourceFile.decode(Map<String, dynamic> content) {
    return SourceFile(
        (content["urls"] as List<dynamic>).cast<String>(),
        SourceFileChecksums.decode(
            content["checksums"] as Map<String, dynamic>));
  }
}

class SourceFileChecksums {
  final String? md5;
  final String? sha1;
  final String? sha256;
  final String? sha512;

  SourceFileChecksums(this.md5, this.sha1, this.sha256, this.sha512);

  factory SourceFileChecksums.decode(Map<String, dynamic> content) {
    return SourceFileChecksums(
        content["md5"], content["sha1"], content["sha256"], content["sha512"]);
  }
}

extension JsonFileSources on Sources {
  static Future<Sources> loadFromFile(String path) async {
    final file = File(path);
    final content = json.decode(await file.readAsString());
    return Sources.decode(content);
  }
}
