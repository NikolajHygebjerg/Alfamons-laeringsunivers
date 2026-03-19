import 'dart:io';

Future<List<int>> readFileBytes(String path) async {
  return File(path).readAsBytes();
}
