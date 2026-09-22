import 'dart:convert';
import 'dart:io';

/// A JSON document stored in a single file.
///
/// Writes go to a temporary file that is then renamed over the original, so
/// an interrupted write never leaves a half-written file behind. Writes are
/// queued so two quick saves can't interleave.
class JsonFile {
  JsonFile(this.file);

  final File file;
  Future<void> _queue = Future.value();

  Future<Object?> read() async {
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  }

  Future<void> write(Object? json) {
    final encoded = jsonEncode(json);
    final done = _queue.then((_) async {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(file.path);
    });
    _queue = done.catchError((_) {});
    return done;
  }
}
