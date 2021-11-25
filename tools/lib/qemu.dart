library boot.os.tools.qemu;

import 'dart:io';

Future<void> qemuCreateImage(
    String imageFilePath, String format, String size) async {
  final result = await Process.run(
      "qemu-img", <String>["create", "-f", format, imageFilePath, size]);

  if (result.exitCode != 0) {
    throw Exception("Failed to run qemu-img to create"
        " $imageFilePath:\n${result.stdout}\n${result.stderr}");
  }
}

Future<void> writeToImage(String inputFilePath, String targetFilePath) async {
  final result = await Process.run("dd",
      <String>["if=${inputFilePath}", "of=${targetFilePath}", "conv=notrunc"]);

  if (result.exitCode != 0) {
    throw Exception("Failed to write ${inputFilePath} to ${targetFilePath}");
  }
}
