library boot.os.tools.sources;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

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

class ChecksumWithHash {
  final String checksum;
  final crypto.Hash hash;

  ChecksumWithHash(this.checksum, this.hash);
}

class SourceFileChecksums {
  final String? sha256;
  final String? sha512;

  SourceFileChecksums(this.sha256, this.sha512);

  factory SourceFileChecksums.decode(Map<String, dynamic> content) {
    return SourceFileChecksums(content["sha256"], content["sha512"]);
  }

  ChecksumWithHash createPreferredHash() {
    if (sha512 != null) {
      return ChecksumWithHash(sha512!, crypto.sha512);
    }

    if (sha256 != null) {
      return ChecksumWithHash(sha256!, crypto.sha256);
    }

    throw Exception("Recognized hash not found.");
  }
}

extension JsonFileSources on Sources {
  static Future<Sources> loadFromFile(String path) async {
    final file = File(path);
    final content = json.decode(await file.readAsString());
    return Sources.decode(content);
  }
}

extension FileChecksumValidate on SourceFileChecksums {
  Future<void> validatePreferredHash(File file) async {
    final checksumAndHash = createPreferredHash();
    final stream = file.openRead();
    final digest = await checksumAndHash.hash.bind(stream).single;
    if (digest.toString() != checksumAndHash.checksum) {
      throw Exception(
          "${file.path} has checksum ${digest.toString()} but ${checksumAndHash.checksum} was expected");
    }
  }
}
