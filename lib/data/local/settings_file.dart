import '../../state/settings_store.dart';
import 'json_file.dart';

/// Loads [SettingsStore] values from a file and saves them on every change.
class SettingsFile {
  SettingsFile(this._file);

  final JsonFile _file;

  Future<void> bind(SettingsStore settings) async {
    try {
      final json = await _file.read();
      if (json is Map<String, Object?>) settings.applyJson(json);
    } catch (_) {
      // Corrupt or unreadable settings fall back to the defaults.
    }
    settings.addListener(() => _file.write(settings.toJson()).ignore());
  }
}
