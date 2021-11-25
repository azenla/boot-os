import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:boot_os_tools/preseed.dart';

Future<void> main(List<String> argv) async {
  final argp = ArgParser();
  argp.addFlag("help", abbr: "h", help: "Show Command Usage", negatable: false);

  Never printUsageAndExit() {
    print("Usage: tools/bin/preseed.dart <file>");
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
  final file = File(args.rest[0]);
  final preseed = DebianPreseedFile.parse(await file.readAsLines());

  preseed.forEach((directive, what, option, selection) {
    print(
        "${directive} ${what}/${option} ${selection.type} ${selection.value}");
  });
}
