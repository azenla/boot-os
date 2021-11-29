import 'dart:io';

import 'boot.dart' as cmd_boot;
import 'download.dart' as cmd_download;
import 'generate_debian_metadata.dart' as cmd_generate_debian_metadata;
import 'generate_ubuntu_metadata.dart' as cmd_generate_ubuntu_metadata;
import 'jigdo.dart' as cmd_jigdo;

Never printUsageAndExit() {
  print("Usage: boot-os <command> [options]");
  print("Commands:");
  print("  boot: Boot an Operating System");
  print("  download: Download Sources");
  print("  generate-debian-metadata: Generate Debian Metadata");
  print("  generate-ubuntu-metadata: Generate Ubuntu Metadata");
  print("  jigdo: Jigsaw Downloader");
  exit(1);
}

Future<void> main(List<String> args) async {
  final argv = args.toList();
  if (argv.isEmpty) {
    printUsageAndExit();
  }

  final command = argv.removeAt(0);
  switch (command) {
    case "boot":
      await cmd_boot.main(argv);
      break;
    case "download":
      await cmd_download.main(argv);
      break;
    case "generate-debian-metadata":
      await cmd_generate_debian_metadata.main(argv);
      break;
    case "generate-ubuntu-metadata":
      await cmd_generate_ubuntu_metadata.main(argv);
      break;
    case "jigdo":
      await cmd_jigdo.main(argv);
      break;
  }
  exit(0);
}
