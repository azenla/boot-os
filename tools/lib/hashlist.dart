library boot.os.tools.hashlist;

import 'package:crypto/crypto.dart';

class HashList {
  final Hash hash;
  final Map<String, String> files;

  HashList(this.hash, this.files);

  @override
  String toString() => "HashList(${files})";

  factory HashList.parse(Hash hash, List<String> lines) {
    final files = <String, String>{};
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith("#")) {
        continue;
      }

      final parts = trimmed.split(" ");
      final checksum = parts.removeAt(0);
      while (parts[0].isEmpty) {
        parts.removeAt(0);
      }
      final file = parts.join(" ");
      files[file] = checksum;
    }
    return HashList(hash, files);
  }
}
