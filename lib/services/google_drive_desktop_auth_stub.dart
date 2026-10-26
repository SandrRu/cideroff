// Заглушка для платформ без dart:io (web).
// Реальная реализация: google_drive_desktop_auth.dart
// Оба файла обязаны предоставлять одинаковый публичный API.

import 'package:http/http.dart' as http;

/// Ошибка desktop-авторизации. Дублируется в реальной реализации,
/// чтобы основной сервис мог ловить её через условный импорт.
class DesktopAuthException implements Exception {
  const DesktopAuthException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

/// На web desktop-авторизация не используется.
class DesktopDriveAuth {
  DesktopDriveAuth({
    required String clientId,
    required String clientSecret,
    required List<String> scopes,
  });

  bool get hasSession => false;

  Future<http.Client?> ensureSignedIn({bool interactive = false}) async => null;

  Future<void> signOut() async {}
}
