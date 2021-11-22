library boot.os.tools.download;

import 'dart:async';
import 'dart:io';

extension DownloadHttpClient on HttpClient {
  Future<File> downloadToFile(Uri url, String path) async {
    final file = File(path);

    if (!(await file.parent.exists())) {
      await file.parent.create();
    }

    final request = await getUrl(url);
    final response = await request.close();
    if (response.statusCode != 200) {
      throw Exception(
          "Download of ${url} failed. Status Code: ${response.statusCode}");
    }

    final output = await file.openWrite();
    await response.pipe(output);
    await output.close();
    return file;
  }
}
