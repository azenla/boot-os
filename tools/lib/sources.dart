library boot.os.tools.sources;

import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

class Sources {
  final Map<String, SourceFile> files;

  Sources(this.files);

  factory Sources.decode(Map<dynamic, dynamic> content) {
    var files = Map<String, SourceFile>();
    for (var key in content.keys) {
      var file = SourceFile.decode(content[key] as Map<dynamic, dynamic>);
      files[key] = file;
    }
    return Sources(files);
  }
}

class SourceFile {
  final String media;
  final String architecture;
  final String format;
  final String version;
  final List<String> urls;
  final SourceFileChecksums checksums;

  SourceFile(this.media, this.architecture, this.format, this.version, this.urls, this.checksums);

  factory SourceFile.decode(Map<dynamic, dynamic> content) {
    return SourceFile(
        content["media"],
        content["architecture"],
        content["format"],
        content["version"],
        (content["urls"] as List<dynamic>).cast<String>(),
        SourceFileChecksums.decode(
            content["checksums"] as Map<dynamic, dynamic>));
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

  factory SourceFileChecksums.decode(Map<dynamic, dynamic> content) {
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
