library boot.os.tools.jigdo;

import 'dart:io';

Future<void> runJigdoLiteIn(String path, List<String> args) async {
  final process = await Process.start("jigdo-lite", args,
      workingDirectory: path, mode: ProcessStartMode.inheritStdio);
  if ((await process.exitCode) != 0) {
    throw Exception("jigdo-lite ${args} failed in ${path}");
  }
}
