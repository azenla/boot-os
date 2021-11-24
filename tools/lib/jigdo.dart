library boot.os.tools.jigdo;

import 'dart:io';

Future<void> runJigdoLiteIn(String path, List<String> args) async {
  final process =
      await Process.start("jigdo-lite", args, workingDirectory: path);
  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw Exception("jigdo-lite $args failed in $path: exit code = $exitCode");
  }
}
