import 'dart:io';

import 'package:boot_os_tools/fasthash.dart';

Future<void> main() async {
  final file = File("ubuntu/impish/sources/ubuntu-21.10-desktop-amd64.iso");
  await speed(sha512, file, true, true);
  await speed(sha512, file, true, false);
  await speed(sha512, file, false, true);
  await speed(sha512, file, false, false);
}

Future<void> speed(Hash hash, File file, bool useFile, bool useFast) async {
  final stream = file.openRead();
  final watch = Stopwatch()..start();
  String checksum;
  if (useFast) {
    if (useFile) {
      checksum = await hash.fastHashFile(file);
    } else {
      checksum = await hash.fastHashStream(stream);
    }
  } else {
    if (useFile) {
      checksum = await hash.slowHashFile(file);
    } else {
      checksum = await hash.slowHashStream(stream);
    }
  }
  watch.stop();
  final milliseconds = watch.elapsedMilliseconds;
  print(
      "${useFast ? "fast" : "slow"} ${useFile ? "file" : "stream"} ${hash.name} ${milliseconds}ms ${file.path}");
}
