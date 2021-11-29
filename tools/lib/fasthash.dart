library boot.os.tools.fasthash;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;

final md5 =
    Hash("md5", "md5sum", crypto.md5, "d41d8cd98f00b204e9800998ecf8427e");
final sha256 = Hash("sha256", "sha256sum", crypto.sha256,
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
final sha512 = Hash("sha512", "sha512sum", crypto.sha512,
    "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e");

class Hash {
  final String name;
  final String executable;
  final crypto.Hash dartSlowHash;
  final String emptyDataHash;

  Hash(this.name, this.executable, this.dartSlowHash, this.emptyDataHash);

  Future<String> hashStream(Stream<List<int>> stream) async {
    if (await _isFastSupported()) {
      return await fastHashStream(stream);
    } else {
      return await slowHashStream(stream);
    }
  }

  Future<String> hashFile(File file) async {
    if (await _isFastSupported()) {
      return await fastHashFile(file);
    } else {
      return await slowHashFile(file);
    }
  }

  Future<String> slowHashStream(Stream<List<int>> stream) async {
    return (await dartSlowHash.bind(stream).single).toString();
  }

  Future<String> slowHashFile(File file) async {
    return await slowHashStream(file.openRead());
  }

  Future<String> _fastHashInternal(
      String filePath, Future<void> Function(Process process) apply) async {
    final process = await Process.start(executable, <String>[filePath]);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    await apply(process);
    process.stderr.drain();
    final stdout = await stdoutFuture;
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception(
          "Failed to run ${executable} to calculate hash: exit code = ${exitCode}");
    }
    final line = stdout.trim().split("\n").first;
    final parts = line.split(" ");
    final checksum = parts[0];
    if (checksum.length != emptyDataHash.length) {
      throw Exception("Resulting fast checksum had the wrong length:"
          " expected ${emptyDataHash.length} but got ${checksum.length}");
    }
    return checksum;
  }

  Future<String> fastHashFile(File file) async {
    return await _fastHashInternal(file.absolute.path, (process) async {
      await process.stdin.close();
    });
  }

  Future<String> fastHashStream(Stream<List<int>> stream) async {
    return await _fastHashInternal("-", (process) async {
      await stream.pipe(process.stdin);
      await process.stdin.close();
    });
  }

  Future<bool> _isFastSupported() async {
    try {
      if ((await fastHashStream(Stream.empty())) == emptyDataHash) {
        return true;
      }
    } catch (e) {
      print("[fast-hash] ${name} unsupported: ${e}");
      return false;
    }
    print("[fast-hash] ${name} unsupported");
    return false;
  }
}
