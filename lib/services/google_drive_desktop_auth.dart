// OAuth 2.0 (loopback) авторизация Google для Windows / Linux / macOS.
// На этих платформах плагин google_sign_in не работает, поэтому используется
// поток "Desktop app" OAuth-клиента из пакета googleapis_auth.
//
// ВАЖНО: OAuth-клиент в Google Cloud Console должен быть типа "Desktop app",
// иначе loopback-редирект на http://localhost:<port> будет отклонён.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ошибка desktop-авторизации.
class DesktopAuthException implements Exception {
  const DesktopAuthException(this.message, {this.cancelled = false});

  final String message;

  /// true, если пользователь сам отказался от входа.
  final bool cancelled;

  @override
  String toString() => message;
}

/// Держит один авторизованный клиент Google на всё приложение
/// и сохраняет credentials между запусками.
class DesktopDriveAuth {
  DesktopDriveAuth({
    required String clientId,
    required String clientSecret,
    required List<String> scopes,
  })  : _clientId =
            ClientId(clientId, clientSecret.isEmpty ? null : clientSecret),
        _scopes = List<String>.unmodifiable(scopes);

  static const String _credentialsFileName = 'google_drive_credentials.json';
  static const Duration _consentTimeout = Duration(minutes: 5);

  final ClientId _clientId;
  final List<String> _scopes;

  http.Client? _client;
  DesktopAuthException? _browserError;

  bool get hasSession => _client != null;

  /// Возвращает авторизованный клиент.
  ///
  /// Если [interactive] == false, UI не показывается: метод вернёт null,
  /// когда сохранённых credentials нет (нужно для фоновой синхронизации).
  Future<http.Client?> ensureSignedIn({bool interactive = false}) async {
    final existing = _client;
    if (existing != null) return existing;

    final saved = await _loadCredentials();
    if (saved != null) {
      final tokenIsFresh = saved.accessToken.expiry.isAfter(
        DateTime.now().toUtc().add(const Duration(minutes: 1)),
      );
      if (saved.refreshToken != null || tokenIsFresh) {
        final client = autoRefreshingClient(_clientId, saved, http.Client());
        _client = client;
        return client;
      }
      await _deleteCredentials();
    }

    if (!interactive) return null;
    return _signInInteractively();
  }

  /// Полный вход с открытием браузера и экраном согласия Google.
  Future<http.Client?> _signInInteractively() async {
    await _ensureBrowserAvailable();

    _browserError = null;
    final baseClient = http.Client();

    try {
      final credentials = await obtainAccessCredentialsViaUserConsent(
        _clientId,
        _scopes,
        baseClient,
        _promptUser,
      ).timeout(_consentTimeout);

      await _saveCredentials(credentials);
      final client = autoRefreshingClient(_clientId, credentials, baseClient);
      _client = client;
      return client;
    } on TimeoutException {
      baseClient.close();
      throw const DesktopAuthException(
        'Истекло время ожидания подтверждения в браузере. Попробуйте войти снова.',
      );
    } on UserConsentException {
      baseClient.close();
      throw const DesktopAuthException(
        'Доступ к Google Drive не предоставлен.',
        cancelled: true,
      );
    } on DesktopAuthException {
      baseClient.close();
      rethrow;
    } catch (error) {
      baseClient.close();
      final browserError = _browserError;
      if (browserError != null) throw browserError;
      debugPrint('Ошибка OAuth-потока Google: $error');
      throw DesktopAuthException('Не удалось войти в Google: $error');
    }
  }

  /// Проверяет заранее, что система вообще умеет открыть браузер.
  /// Без этого проверка потолка: без браузера поток ждал бы редирект вечно.
  Future<void> _ensureBrowserAvailable() async {
    bool available;
    try {
      available = await canLaunchUrl(Uri.parse('https://accounts.google.com/'));
    } catch (error) {
      debugPrint('canLaunchUrl завершился ошибкой: $error');
      available = true;
    }
    if (!available) {
      throw const DesktopAuthException(
        'В системе не найден браузер по умолчанию, вход в Google невозможен.',
      );
    }
  }

  /// Открывает URL согласия. Колбэк синхронный, поэтому запуск делаем
  /// в фоне, а ошибку запоминаем и поднимаем после таймаута/сбоя потока.
  void _promptUser(String authorizationUrl) {
    final uri = Uri.tryParse(authorizationUrl);
    if (uri == null) {
      _browserError =
          const DesktopAuthException('Некорректная ссылка авторизации Google.');
      return;
    }

    unawaited(() async {
      try {
        final opened =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!opened) {
          _browserError = const DesktopAuthException(
            'Не удалось открыть браузер для входа в Google.',
          );
        }
      } catch (error) {
        _browserError =
            DesktopAuthException('Не удалось открыть браузер: $error');
      }
    }());
  }

  /// Сбрасывает сессию: закрывает клиент и удаляет сохранённые credentials.
  Future<void> signOut() async {
    _client?.close();
    _client = null;
    await _deleteCredentials();
  }

  Future<File> _credentialsFile() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File(
        '${directory.path}${Platform.pathSeparator}$_credentialsFileName');
  }

  Future<void> _saveCredentials(AccessCredentials credentials) async {
    try {
      final file = await _credentialsFile();
      final payload = <String, dynamic>{
        'accessToken': credentials.accessToken.data,
        'refreshToken': credentials.refreshToken,
        'scopes': credentials.scopes,
        'expiry': credentials.accessToken.expiry.toUtc().toIso8601String(),
      };
      await file.writeAsString(jsonEncode(payload));
    } catch (error) {
      // Не критично: пользователь просто введёт согласие при следующем запуске.
      debugPrint('Не удалось сохранить Google credentials: $error');
    }
  }

  Future<AccessCredentials?> _loadCredentials() async {
    try {
      final file = await _credentialsFile();
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final accessToken = data['accessToken'] as String?;
      final expiry = DateTime.tryParse((data['expiry'] as String?) ?? '');
      if (accessToken == null || accessToken.isEmpty || expiry == null)
        return null;

      final refreshToken = data['refreshToken'] as String?;
      final scopes =
          (data['scopes'] as List<dynamic>?)?.cast<String>() ?? _scopes;

      return AccessCredentials(
        AccessToken(accessToken, 'Bearer', expiry.toUtc()),
        refreshToken,
        scopes,
      );
    } catch (error) {
      debugPrint('Не удалось прочитать сохранённые Google credentials: $error');
      return null;
    }
  }

  Future<void> _deleteCredentials() async {
    try {
      final file = await _credentialsFile();
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Не удалось удалить сохранённые Google credentials: $error');
    }
  }
}
