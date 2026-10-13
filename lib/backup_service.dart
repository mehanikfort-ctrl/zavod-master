import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupService {
  // Ключи, которые сохраняем
  static const List<String> _dataKeys = [
    'tasks',
    'equipment',
    'meters',
    'regulations',
    'themeMode',
  ];

  /// Экспортирует всё в ZIP. Возвращает путь к сохранённому файлу или null.
  static Future<String?> exportAll() async {
    final prefs = await SharedPreferences.getInstance();

    // Собираем JSON со всеми данными
    final data = <String, dynamic>{};
    for (final key in _dataKeys) {
      final val = prefs.getString(key);
      if (val != null && val.isNotEmpty) {
        try {
          data[key] = jsonDecode(val);
        } catch (_) {
          data[key] = val;
        }
      }
    }
    final meta = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'Завод-Механик',
    };

    // Папка приложения (там лежат photos/ и files/)
    final supportDir = await getApplicationSupportDirectory();
    final photosDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}photos',
    );
    final filesDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}files',
    );

    // Формируем архив
    final archive = Archive();

    // data.json и meta.json
    final dataBytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile('data.json', dataBytes.length, dataBytes));

    final metaBytes = utf8.encode(jsonEncode(meta));
    archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));

    // Фото
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          final name = entity.path.split(Platform.pathSeparator).last;
          archive.addFile(ArchiveFile('photos/$name', bytes.length, bytes));
        }
      }
    }

    // Файлы
    if (await filesDir.exists()) {
      await for (final entity in filesDir.list()) {
        if (entity is File) {
          final bytes = await entity.readAsBytes();
          final name = entity.path.split(Platform.pathSeparator).last;
          archive.addFile(ArchiveFile('files/$name', bytes.length, bytes));
        }
      }
    }

    // Кодируем в ZIP
    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) return null;

    // Диалог сохранения
    final now = DateTime.now();
    final fileName =
        'zavod_master_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.zip';

    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'ZIP-архив', extensions: ['zip']),
      ],
    );
    if (location == null) return null;

    final outFile = File(location.path);
    await outFile.writeAsBytes(zipBytes);
    return outFile.path;
  }

  /// Импортирует ZIP и перезаписывает все данные.
  /// Возвращает true, если успешно.
  static Future<bool> importAll() async {
    final picked = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'ZIP-архив', extensions: ['zip']),
      ],
    );
    if (picked == null) return false;

    final bytes = await File(picked.path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final supportDir = await getApplicationSupportDirectory();
    final photosDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}photos',
    );
    final filesDir = Directory(
      '${supportDir.path}${Platform.pathSeparator}files',
    );

    // Очищаем старые папки
    if (await photosDir.exists()) {
      await photosDir.delete(recursive: true);
    }
    if (await filesDir.exists()) {
      await filesDir.delete(recursive: true);
    }
    await photosDir.create(recursive: true);
    await filesDir.create(recursive: true);

    Map<String, dynamic>? data;
    final prefs = await SharedPreferences.getInstance();

    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name;

      if (name == 'data.json') {
        final content = utf8.decode(file.content as List<int>);
        data = jsonDecode(content) as Map<String, dynamic>;
      } else if (name.startsWith('photos/')) {
        final outPath =
            '${photosDir.path}${Platform.pathSeparator}${name.substring(7)}';
        final outFile = File(outPath);
        await outFile.writeAsBytes(file.content as List<int>);
      } else if (name.startsWith('files/')) {
        final outPath =
            '${filesDir.path}${Platform.pathSeparator}${name.substring(6)}';
        final outFile = File(outPath);
        await outFile.writeAsBytes(file.content as List<int>);
      }
    }

    if (data == null) return false;

    // Восстанавливаем shared_preferences
    for (final key in _dataKeys) {
      if (!data.containsKey(key)) {
        await prefs.remove(key);
        continue;
      }
      final value = data[key];
      if (value is String) {
        await prefs.setString(key, value);
      } else {
        await prefs.setString(key, jsonEncode(value));
      }
    }

    return true;
  }
}
