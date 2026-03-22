import 'dart:io';

void downloadCsvFile(String csv, String filename) {
  final downloadsDir = Directory('${Platform.environment['USERPROFILE'] ?? Platform.environment['HOME']}/Downloads');
  if (!downloadsDir.existsSync()) {
    downloadsDir.createSync(recursive: true);
  }
  final file = File('${downloadsDir.path}/$filename');
  file.writeAsStringSync(csv);
}
