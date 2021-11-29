library boot.os.tools.sources;

import 'dart:io';

import 'package:boot_os_tools/globals.dart';
import 'package:boot_os_tools/hashlist.dart';
import 'package:boot_os_tools/util.dart';
import 'package:crypto/crypto.dart' as crypto;

class Sources {
  final Map<String, SourceFile> files;

  Sources(this.files);

  factory Sources.decode(Map<dynamic, dynamic> content,
      {bool useAssembleMode = false}) {
    var files = Map<String, SourceFile>();
    for (var key in content.keys) {
      SourceFile file;
      if (useAssembleMode) {
        file = SourceFile.decodeAssemble(content[key] as Map<dynamic, dynamic>);
      } else {
        file = SourceFile.decode(content[key] as Map<dynamic, dynamic>);
      }
      files[key] = file;
    }
    return Sources(files);
  }

  Map<String, dynamic> encode() =>
      files.map((key, value) => MapEntry(key, value.encode()));
}

class SourceFile {
  final String media;
  final String architecture;
  final String format;
  final String version;
  final List<String>? urls;
  final SourceFileAssemble? assemble;
  final SourceFileChecksums checksums;

  SourceFile(this.media, this.architecture, this.format, this.version,
      this.urls, this.assemble, this.checksums);

  SourceFile.assemble(this.urls, this.assemble, this.checksums)
      : media = "",
        architecture = "",
        format = "",
        version = "";

  factory SourceFile.decode(Map<dynamic, dynamic> content) {
    return SourceFile(
        content["media"],
        content["architecture"],
        content["format"],
        content["version"],
        (content["urls"] as List<dynamic>?)?.cast<String>(),
        content.containsKey("assemble")
            ? SourceFileAssemble.decode(
                content["assemble"] as Map<dynamic, dynamic>)
            : null,
        SourceFileChecksums.decode(
            content["checksums"] as Map<dynamic, dynamic>));
  }

  factory SourceFile.decodeAssemble(Map<dynamic, dynamic> content) {
    return SourceFile.assemble(
        (content["urls"] as List<dynamic>?)?.cast<String>(),
        content.containsKey("assemble")
            ? SourceFileAssemble.decode(
                content["assemble"] as Map<dynamic, dynamic>)
            : null,
        SourceFileChecksums.decode(
            content["checksums"] as Map<dynamic, dynamic>));
  }

  Map<String, dynamic> encode() => <String, dynamic>{
        "media": nullIfEmpty(media),
        "architecture": nullIfEmpty(architecture),
        "format": nullIfEmpty(format),
        "version": nullIfEmpty(version),
        "urls": urls,
        "assemble": assemble?.encode(),
        "checksums": checksums.encode()
      };
}

class ChecksumWithHash {
  final String checksum;
  final crypto.Hash hash;

  ChecksumWithHash(this.checksum, this.hash);

  Future<bool> validate(File file, {bool shouldThrowError = true}) async {
    if (GlobalSettings.shortCircuitFileValidation) {
      print("[validation-skip] ${file.path}");
      return true;
    }

    final stream = file.openRead();
    final digest = await hash.bind(stream).single;
    if (digest.toString() != checksum) {
      if (shouldThrowError) {
        throw Exception(
            "${file.path} has checksum ${digest.toString()} but ${checksum} was expected");
      }
      return false;
    }
    return true;
  }
}

class SourceFileChecksums {
  final String? md5;
  final String? sha256;
  final String? sha512;

  SourceFileChecksums({this.md5, this.sha256, this.sha512});

  factory SourceFileChecksums.decode(Map<dynamic, dynamic> content) {
    return SourceFileChecksums(
        md5: content["md5"],
        sha256: content["sha256"],
        sha512: content["sha512"]);
  }

  ChecksumWithHash createPreferredHash() {
    if (sha512 != null) {
      return ChecksumWithHash(sha512!, crypto.sha512);
    }

    if (sha256 != null) {
      return ChecksumWithHash(sha256!, crypto.sha256);
    }

    if (md5 != null) {
      return ChecksumWithHash(md5!, crypto.md5);
    }

    throw Exception("Recognized hash not found.");
  }

  Map<String, String?> encode() =>
      <String, String?>{"md5": md5, "sha256": sha256, "sha512": sha512};
}

class SourceFileAssemble {
  final String type;
  final Sources sources;

  SourceFileAssemble(this.type, this.sources);

  factory SourceFileAssemble.decode(Map<dynamic, dynamic> content) {
    return SourceFileAssemble(
        content["type"],
        Sources.decode(content["sources"] as Map<dynamic, dynamic>,
            useAssembleMode: true));
  }

  Map<String, dynamic> encode() =>
      <String, dynamic>{"type": type, "sources": sources.encode()};
}

extension ChecksumWithHashSourceFileChecksums on HashList {
  SourceFileChecksums? createSourceFileChecksums(String file) {
    final checksum = files[file];
    if (checksum == null) {
      return null;
    }

    if (hash == crypto.md5) {
      return SourceFileChecksums(md5: checksum);
    } else if (hash == crypto.sha256) {
      return SourceFileChecksums(sha256: checksum);
    } else if (hash == crypto.sha512) {
      return SourceFileChecksums(sha512: checksum);
    } else {
      throw Exception("Unknown Hash");
    }
  }
}

extension FileChecksumValidate on SourceFileChecksums {
  Future<bool> validatePreferredHash(File file,
      {bool shouldThrowError = true}) async {
    final checksumAndHash = createPreferredHash();
    return await checksumAndHash.validate(file,
        shouldThrowError: shouldThrowError);
  }
}
