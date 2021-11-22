import 'dart:async';
import 'dart:io';

import 'package:boot_os_tools/sources.dart';
import 'package:boot_os_tools/download.dart';

Future<void> main(List<String> args) async {
  final http = HttpClient();
  for (final os in args) {
    final osSourcesFilePath = "${os}/sources.json";
    final osSourcesDirPath = "${os}/sources";
    final Directory osSourcesDir = Directory(osSourcesDirPath);
    if (!(await osSourcesDir.exists())) {
      await osSourcesDir.create();
    }
    final sources = await JsonFileSources.loadFromFile(osSourcesFilePath);
    for (final name in sources.files.keys) {
      final file = sources.files[name];
      final sourceFilePath = "${osSourcesDirPath}/${name}";
      if (file == null) {
        continue;
      }
      final url = Uri.parse(file.urls.first);
      print("${url} -> ${sourceFilePath}");
      await http.downloadToFile(url, sourceFilePath);
    }
  }
  http.close();
}
