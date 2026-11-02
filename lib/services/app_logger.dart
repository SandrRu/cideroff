import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

/// Простое файловое логирование с ротацией.
///
/// Пишет и ошибки приложения, и обычные сообщения. Файл лежит рядом с
/// данными приложения (Application Support), поэтому доступен и в релизе.
class AppLogger {
  AppLogger._();

  static final AppLogger instance = AppLogger._();

  static const String _fileName = 'cider_off.log';
  static const int _maxFileBytes = 2 * 1024 * 1024; // 2 МБ

  File? _logFile;
  IOSink? _sink;
  bool _initialized = false;
  bool _closed = false;

  /// Очередь сообщений, чтобы не терять их до открытия файла
  /// и не блокировать UI.
  final List<String> _pending = <String>[];
  bool _flushing = false;

  String? get logFilePath => _logFile?.path;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await _resolveLogDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File(p.join(dir.path, _fileName));
      await _rotateIfNeeded(file);
      _logFile = file;
      _sink = file.openWrite(mode: FileMode.append);
      _initialized = true;
      log(LogLevel.info,
          '=== Запуск логирования ${DateTime.now().toIso8601String()} ===');
    } catch (e, s) {
      // Если файл недоступен — не ломаем приложение, пишем в консоль.
      debugPrint('AppLogger: не удалось открыть файл лога: $e\n$s');
    }
  }

  Future<Directory> _resolveLogDirectory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return getApplicationSupportDirectory();
    }
    return getApplicationDocumentsDirectory();
  }

  Future<void> _rotateIfNeeded(File file) async {
    try {
      if (await file.exists() && await file.length() > _maxFileBytes) {
        final backup = File('${file.path}.1');
        if (await backup.exists()) {
          await backup.delete();
        }
        await file.rename(backup.path);
      }
    } catch (_) {
      // Ротация — не критична.
    }
  }

  void log(LogLevel level, Object? message, [Object? error, StackTrace? stack]) {
    if (_closed) return;
    final ts = DateTime.now().toIso8601String();
    final buffer = StringBuffer()
      ..write('[$ts] [${level.name.toUpperCase()}] $message');
    if (error != null) {
      buffer.write('\n  error: $error');
    }
    if (stack != null) {
      buffer.write('\n  stack: $stack');
    }
    buffer.write('\n');

    final line = buffer.toString();

    // Дублируем в консоль, чтобы поведение dev-сборки не изменилось.
    if (kDebugMode) {
      debugPrint(line);
    }

    _pending.add(line);
    unawaited(_flush());
  }

  void debug(Object? message) => log(LogLevel.debug, message);
  void info(Object? message) => log(LogLevel.info, message);

  void warning(Object? message, [Object? error, StackTrace? stack]) =>
      log(LogLevel.warning, message, error, stack);

  void error(Object? message, [Object? error, StackTrace? stack]) =>
      log(LogLevel.error, message, error, stack);

  Future<void> _flush() async {
    final sink = _sink;
    if (sink == null || _flushing) return;
    _flushing = true;
    try {
      while (_pending.isNotEmpty) {
        final line = _pending.removeAt(0);
        sink.write(line);
      }
      await sink.flush();
    } catch (e) {
      debugPrint('AppLogger: ошибка записи в лог: $e');
    } finally {
      _flushing = false;
    }
  }

  Future<void> close() async {
    _closed = true;
    try {
      await _flush();
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {}
    _sink = null;
  }
}