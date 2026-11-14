import 'dart:io';

void main() async {
  final dir = Directory('lib/screens');
  final files = await dir
      .list(recursive: true)
      .where((e) => e is File && e.path.endsWith('.dart'))
      .toList();

  for (var entity in files) {
    if (entity is! File) continue;
    final file = entity as File;
    var content = await file.readAsString();
    if (content.contains('appBar: AppBar(') ||
        content.contains('SliverAppBar(')) {
      // Just print out for now to see
      print(file.path);
    }
  }
}
