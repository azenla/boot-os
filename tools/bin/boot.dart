import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/constants.dart';
import 'package:boot_os_tools/os.dart';
import 'package:boot_os_tools/qemu.dart';
import 'package:boot_os_tools/sources.dart';

Future<void> main(List<String> argv) async {
  final argp = ArgParser(allowTrailingOptions: true);
  argp.addFlag("help", abbr: "h", help: "Show Command Usage", negatable: false);
  argp.addOption("architecture",
      abbr: "a", help: "Boot Architecture", mandatory: true);
  argp.addOption("qemu-firmware-path", abbr: "q", help: "QEMU Firmware Path");
  argp.addOption("media", abbr: "m", help: "Boot Media", mandatory: true);

  Never printUsageAndExit() {
    print("Usage: tools/bin/boot.dart [options] <os>");
    print(argp.usage);
    exit(1);
  }

  ArgResults args;
  try {
    args = argp.parse(argv);
  } catch (e) {
    print(e);
    printUsageAndExit();
  }

  if (args["help"]) {
    printUsageAndExit();
  }
  final architecture = args["architecture"].toString();
  final media = args["media"].toString();
  final id = args.rest[0];
  final os = await OperatingSystem.load(id);
  if (!os.metadata.architectures.contains(architecture)) {
    throw Exception(
        "Operating System at ${args.rest[0]} does not support architecture $architecture");
  }

  final source = os.metadata.sources.files.entries
      .cast<MapEntry<String, SourceFile>?>()
      .firstWhere((entry) {
    final source = entry!.value;
    if (source.architecture != architecture) {
      return false;
    }
    if (source.media != media) {
      return false;
    }
    return true;
  }, orElse: () => null);

  if (source == null) {
    throw Exception(
        "Failed to find source media $media on $id for architecture $architecture");
  }

  final sourceFileName = source.key;
  final sourceMetadata = source.value;

  if (!qemuArchitectureTable.containsKey(architecture)) {
    throw Exception("Unknown QEMU architecture $architecture");
  }

  final qemuSystemExecutable = qemuArchitectureTable[architecture]!;
  final qemuSystemArgs = <String>[];

  await os.ensureInstancesDirectory();
  final instanceDirectory = os.instancesDirectory;

  Future<String> ensureQemuImage(
      String file, String format, String size) async {
    final qemuImageFile = File("${instanceDirectory.absolute.path}/${file}");
    if (!(await qemuImageFile.exists())) {
      await qemuCreateImage(qemuImageFile.path, format, size);
    }
    return qemuImageFile.path;
  }

  final qemuFirmwarePath = args["qemu-firmware-path"];
  Future<String> ensureQemuFirmware(String file) async {
    if (qemuFirmwarePath == null) {
      throw Exception("qemu-firmware-path is required to find file ${file}");
    }

    final qemuFirmwareFile = File("$qemuFirmwarePath/$file");
    if (await qemuFirmwareFile.exists()) {
      return qemuFirmwareFile.absolute.path;
    } else {
      throw Exception(
          "Failed to find firmware file $file in $qemuFirmwarePath");
    }
  }

  switch (qemuSystemExecutable) {
    case "qemu-system-aarch64":
      final flashZeroImagePath =
          await ensureQemuImage("aarch64-flash0.img", "raw", "64M");
      final flashOneImagePath =
          await ensureQemuImage("aarch64-flash1.img", "raw", "64M");
      final edk2Aarch64Path = await ensureQemuFirmware("edk2-aarch64-code.fd");
      await writeToImage(edk2Aarch64Path, flashZeroImagePath);
      qemuSystemArgs.addAll(<String>[
        "-machine",
        "virt",
        "-cpu",
        "cortex-a53",
        "-device",
        "virtio-gpu-pci",
        "-drive",
        "if=pflash,format=raw,file=$flashZeroImagePath",
        "-drive",
        "if=pflash,format=raw,file=$flashOneImagePath"
      ]);
      break;
  }

  switch (sourceMetadata.format) {
    case "iso":
      qemuSystemArgs.addAll(["-cdrom", "sources/$sourceFileName"]);
      break;
    case "qcow2":
    case "img":
      qemuSystemArgs.addAll(["-hda", "sources/$sourceFileName"]);
      break;
    default:
      throw Exception("Source with supported format not found.");
  }

  final process = await Process.start(qemuSystemExecutable, qemuSystemArgs,
      mode: ProcessStartMode.inheritStdio, workingDirectory: os.path);
  exit(await process.exitCode);
}
