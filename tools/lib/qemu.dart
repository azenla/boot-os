library boot.os.tools.qemu;

import 'dart:io';

final _commonQemuFirmwarePaths = <String>[
  "/usr/local/opt/qemu/share/qemu",
  "/opt/homebrew/opt/qemu/share/qemu",
  "/usr/share/edk2/aarch64"
];

final _architectureFirmwarePaths = <String, List<String>>{
  "arm64": ["/usr/share/edk2/aarch64"]
};

Future<String?> findQemuFirmwareFile(
    String architecture, List<String> possibleFileNames,
    {List<String>? additionalFirmwarePaths}) async {
  final List<String> firmwarePaths = <String>[];

  if (additionalFirmwarePaths != null) {
    firmwarePaths.addAll(additionalFirmwarePaths);
  }

  final architectureSpecificPaths = _architectureFirmwarePaths[architecture];
  if (architectureSpecificPaths != null) {
    firmwarePaths.addAll(architectureSpecificPaths);
  }

  firmwarePaths.addAll(_commonQemuFirmwarePaths);

  for (final path in firmwarePaths) {
    final directory = Directory(path);
    if (!(await directory.exists())) {
      continue;
    }

    for (final fileName in possibleFileNames) {
      final file = File("${directory.path}/${fileName}");
      if (await file.exists()) {
        return file.path;
      }
    }
  }
  return null;
}

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
