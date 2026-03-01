/// Stub implementation of [File] for web platforms where dart:io is unavailable.
class File {
  File(this.path);

  final String path;

  bool existsSync() => false;

  Future<String> readAsString() =>
      Future.error(UnsupportedError('File.readAsString() is not supported on web.'));

  Future<File> writeAsBytes(List<int> bytes, {bool flush = false}) =>
      Future.error(UnsupportedError('File.writeAsBytes() is not supported on web.'));

  Future<File> delete({bool recursive = false}) => Future.value(this);
}
