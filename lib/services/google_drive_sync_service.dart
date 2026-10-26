// Синхронизация резервной копии CiderOff с Google Drive.
//
// Поддерживаемые платформы:
//  * Windows / Linux / macOS — OAuth 2.0 loopback-поток (googleapis_auth);
//  * Android / iOS — google_sign_in 7.x;
//  * web — вход через authenticate() не поддерживается плагином,
//    нужен renderButton(), поэтому операции возвращают понятную ошибку.
//
// Требуемые --dart-define:
//  * WINDOWS_CLIENT_ID / WINDOWS_CLIENT_SECRET — OAuth-клиент типа "Desktop app";
//  * WEB_CLIENT_ID — Web-клиент, он же serverClientId для мобильных платформ;
//  * IOS_CLIENT_ID — опционально, iOS/macOS OAuth-клиент для плагина.

import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'export_import_service.dart';
import 'google_drive_desktop_auth_stub.dart'
    if (dart.library.io) 'google_drive_desktop_auth.dart';

/// Причина неудачной операции синхронизации.
enum DriveSyncFailure {
  none,
  notConfigured,
  notSignedIn,
  cancelled,
  network,
  backupNotFound,
  invalidBackup,
  permissionDenied,
  unknown,
}

/// Результат операции синхронизации: успех/причина + человекочитаемое описание.
@immutable
class DriveSyncResult {
  const DriveSyncResult.success([this.message])
      : failure = DriveSyncFailure.none;

  const DriveSyncResult.failure(this.failure, [this.message]);

  final DriveSyncFailure failure;
  final String? message;

  bool get isSuccess => failure == DriveSyncFailure.none;
  bool get isCancelled => failure == DriveSyncFailure.cancelled;

  @override
  String toString() => isSuccess
      ? 'DriveSyncResult.success'
      : 'DriveSyncResult($failure: $message)';
}

class GoogleDriveSyncService {
  static final GoogleDriveSyncService _instance =
      GoogleDriveSyncService._internal();

  factory GoogleDriveSyncService() => _instance;

  GoogleDriveSyncService._internal();

  static const String _backupFileName = 'CiderOff_Backup_Auto.ciderbak';
  static const String _backupMimeType = 'application/json';
  static const String _appDataFolder = 'appDataFolder';

  static const Duration _requestTimeout = Duration(seconds: 45);
  static const Duration _downloadTimeout = Duration(minutes: 3);

  /// Достаточно appdata: все файлы лежат в appDataFolder приложения.
  /// Если понадобится доступ к обычному Drive — добавьте drive.DriveApi.driveFileScope.
  static const List<String> _scopes = <String>[
    drive.DriveApi.driveAppdataScope,
  ];

  static const String _windowsClientId =
      String.fromEnvironment('WINDOWS_CLIENT_ID');
  static const String _windowsClientSecret =
      String.fromEnvironment('WINDOWS_CLIENT_SECRET');
  static const String _webClientId = String.fromEnvironment('WEB_CLIENT_ID');
  static const String _iosClientId = String.fromEnvironment('IOS_CLIENT_ID');

  GoogleSignInAccount? _currentUser;
  Future<void>? _initFuture;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;
  DesktopDriveAuth? _desktopAuth;

  DriveSyncResult? _lastResult;

  /// Результат последней операции — можно показать в UI.
  DriveSyncResult? get lastResult => _lastResult;

  /// Сообщение последней ошибки (null, если последняя операция успешна).
  String? get lastError => _lastResult?.message;

  bool get _isDesktop =>
      !kIsWeb &&
      const <TargetPlatform>{
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  bool get isSignedIn =>
      _isDesktop ? (_desktopAuth?.hasSession ?? false) : _currentUser != null;

  /// Email пользователя известен только на мобильных платформах.
  String? get accountEmail => _isDesktop ? null : _currentUser?.email;

  /// null — конфигурация в порядке, иначе текст проблемы.
  String? get configurationError {
    if (_isDesktop) {
      if (_windowsClientId.isEmpty) {
        return 'Не задан WINDOWS_CLIENT_ID (--dart-define). '
            'OAuth-клиент должен быть типа "Desktop app".';
      }
      return null;
    }
    if (_webClientId.isEmpty) {
      return 'Не задан WEB_CLIENT_ID (--dart-define). '
          'Он обязателен как serverClientId для Google Sign-In.';
    }
    return null;
  }

  /// clientId передаём только для iOS/macOS: на Android он не используется,
  /// а на web плагин вообще работает через renderButton().
  static String? get _pluginClientId {
    if (kIsWeb || _iosClientId.isEmpty) return null;
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS
        ? _iosClientId
        : null;
  }

  // ---------------------------------------------------------------------------
  // Авторизация
  // ---------------------------------------------------------------------------

  /// Инициализация google_sign_in — строго один раз, даже при параллельных вызовах.
  Future<void> _ensureInitialized() => _initFuture ??= _initialize();

  Future<void> _initialize() async {
    if (_isDesktop) return;

    final signIn = GoogleSignIn.instance;

    _authEventsSub ??= signIn.authenticationEvents.listen(
      _handleAuthEvent,
      onError: (Object error) =>
          debugPrint('Ошибка потока Google Sign-In: $error'),
    );

    try {
      await signIn.initialize(
        clientId: _pluginClientId,
        serverClientId: _webClientId.isEmpty ? null : _webClientId,
      );
    } catch (error) {
      // Позволяем повторить инициализацию при следующем вызове.
      _initFuture = null;
      await _authEventsSub?.cancel();
      _authEventsSub = null;
      debugPrint('Не удалось инициализировать Google Sign-In: $error');
      rethrow;
    }
  }

  void _handleAuthEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn(:final user):
        _currentUser = user;
      case GoogleSignInAuthenticationEventSignOut():
        _currentUser = null;
    }
  }

  /// Интерактивный вход. Возвращает true, если пользователь авторизован
  /// и разрешения на Google Drive выданы.
  Future<bool> signIn() async {
    final result = await _run(() async {
      final outcome = await _authorize(allowInteractive: true);
      return outcome.error ?? const DriveSyncResult.success();
    });
    _lastResult = result;
    return result.isSuccess;
  }

  /// Выход из аккаунта Google.
  Future<void> signOut() async {
    if (_isDesktop) {
      await _desktopAuth?.signOut();
      _desktopAuth = null;
      return;
    }

    try {
      await _ensureInitialized();
      await GoogleSignIn.instance.disconnect();
    } catch (error) {
      debugPrint('Ошибка выхода из Google Sign-In: $error');
    } finally {
      _currentUser = null;
    }
  }

  /// Освобождает подписку на события Google Sign-In.
  /// Сохранённые credentials намеренно не удаляются — для этого есть signOut().
  Future<void> dispose() async {
    await _authEventsSub?.cancel();
    _authEventsSub = null;
  }

  /// Возвращает авторизованный http-клиент либо причину, по которой его нет.
  Future<_AuthOutcome> _authorize({required bool allowInteractive}) async {
    final configError = configurationError;
    if (configError != null) {
      return _AuthOutcome.failed(
          DriveSyncResult.failure(DriveSyncFailure.notConfigured, configError));
    }

    if (_isDesktop) {
      final auth = _desktopAuth ??= DesktopDriveAuth(
        clientId: _windowsClientId,
        clientSecret: _windowsClientSecret,
        scopes: _scopes,
      );

      final client = await auth.ensureSignedIn(interactive: allowInteractive);
      if (client == null) {
        return _AuthOutcome.failed(
          DriveSyncResult.failure(
            DriveSyncFailure.notSignedIn,
            'Нет сохранённой сессии Google. Войдите через настройки синхронизации.',
          ),
        );
      }
      return _AuthOutcome.ok(client);
    }

    // Android / iOS / web
    await _ensureInitialized();

    var account = _currentUser ?? await _signInSilently();

    if (account == null) {
      if (!allowInteractive) {
        return _AuthOutcome.failed(
          const DriveSyncResult.failure(
              DriveSyncFailure.notSignedIn, 'Нет активной сессии Google.'),
        );
      }
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return _AuthOutcome.failed(
          const DriveSyncResult.failure(
            DriveSyncFailure.notSignedIn,
            'На этой платформе вход выполняется только через кнопку Google (renderButton).',
          ),
        );
      }
      account = await GoogleSignIn.instance.authenticate();
      _currentUser = account;
    }

    var authorization =
        await account.authorizationClient.authorizationForScopes(_scopes);
    if (authorization == null) {
      if (!allowInteractive) {
        return _AuthOutcome.failed(
          const DriveSyncResult.failure(
            DriveSyncFailure.permissionDenied,
            'Нет сохранённого разрешения на доступ к Google Drive.',
          ),
        );
      }
      // authorizeScopes должен вызываться из действия пользователя.
      authorization =
          await account.authorizationClient.authorizeScopes(_scopes);
    }

    return _AuthOutcome.ok(authorization.authClient(scopes: _scopes));
  }

  /// Тихий вход без UI: восстановление ранее выданной сессии.
  Future<GoogleSignInAccount?> _signInSilently() async {
    try {
      final account =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      if (account != null) _currentUser = account;
      return account;
    } on GoogleSignInException catch (error) {
      debugPrint('Тихий вход не удался: ${error.code} ${error.description}');
      return null;
    } catch (error) {
      debugPrint('Тихий вход не удался: $error');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Google Drive
  // ---------------------------------------------------------------------------

  /// Загрузка резервной копии в appDataFolder Google Drive.
  ///
  /// [allowInteractiveSignIn] = false — без UI (для фоновой синхронизации).
  Future<bool> uploadBackup({bool allowInteractiveSignIn = true}) async {
    final result = await uploadBackupResult(
        allowInteractiveSignIn: allowInteractiveSignIn);
    return result.isSuccess;
  }

  Future<DriveSyncResult> uploadBackupResult(
      {bool allowInteractiveSignIn = true}) async {
    final result = await _run(() async {
      final auth = await _authorize(allowInteractive: allowInteractiveSignIn);
      final client = auth.client;
      if (client == null) return auth.error!;

      final jsonString = await ExportImportService().generateBackupJsonString();
      final bytes = utf8.encode(jsonString);
      final driveApi = drive.DriveApi(client);

      final existingFileId = await _findBackupFileId(driveApi);

      if (existingFileId != null) {
        final metadata = drive.File()..mimeType = _backupMimeType;
        await driveApi.files
            .update(
              metadata,
              existingFileId,
              uploadMedia:
                  drive.Media(Stream<List<int>>.value(bytes), bytes.length),
            )
            .timeout(_requestTimeout);
        debugPrint(
            'Резервная копия обновлена в Google Drive (ID: $existingFileId)');
      } else {
        final metadata = drive.File()
          ..name = _backupFileName
          ..parents = <String>[_appDataFolder]
          ..mimeType = _backupMimeType;
        final created = await driveApi.files
            .create(
              metadata,
              uploadMedia:
                  drive.Media(Stream<List<int>>.value(bytes), bytes.length),
            )
            .timeout(_requestTimeout);
        debugPrint(
            'Резервная копия создана в Google Drive (ID: ${created.id})');
      }

      return const DriveSyncResult.success();
    });

    _lastResult = result;
    return result;
  }

  /// Скачивание и применение резервной копии из appDataFolder.
  Future<bool> downloadAndApplyBackup(
      {bool allowInteractiveSignIn = true}) async {
    final result = await downloadAndApplyBackupResult(
      allowInteractiveSignIn: allowInteractiveSignIn,
    );
    return result.isSuccess;
  }

  Future<DriveSyncResult> downloadAndApplyBackupResult(
      {bool allowInteractiveSignIn = true}) async {
    final result = await _run(() async {
      final auth = await _authorize(allowInteractive: allowInteractiveSignIn);
      final client = auth.client;
      if (client == null) return auth.error!;

      final driveApi = drive.DriveApi(client);
      final fileId = await _findBackupFileId(driveApi);

      if (fileId == null) {
        return const DriveSyncResult.failure(
          DriveSyncFailure.backupNotFound,
          'Резервная копия не найдена в Google Drive.',
        );
      }

      final dynamic response = await driveApi.files
          .get(fileId, downloadOptions: drive.DownloadOptions.fullMedia)
          .timeout(_requestTimeout);

      if (response is! drive.Media) {
        return const DriveSyncResult.failure(
          DriveSyncFailure.unknown,
          'Google Drive вернул неожиданный формат ответа.',
        );
      }

      final bytes = <int>[];
      await for (final chunk in response.stream.timeout(_downloadTimeout)) {
        bytes.addAll(chunk);
      }

      if (bytes.isEmpty) {
        return const DriveSyncResult.failure(
          DriveSyncFailure.invalidBackup,
          'Файл резервной копии пуст.',
        );
      }

      // FormatException перехватывается в _run и превращается в invalidBackup.
      final jsonString = utf8.decode(bytes);
      final applied = await ExportImportService().importBackupFromJsonString(
        jsonString,
        replaceExisting: true,
      );

      if (!applied) {
        return const DriveSyncResult.failure(
          DriveSyncFailure.invalidBackup,
          'Резервная копия повреждена или несовместима с текущей версией приложения.',
        );
      }

      return const DriveSyncResult.success();
    });

    _lastResult = result;
    return result;
  }

  /// Ищет файл бэкапа в appDataFolder. Возвращает null, если файла нет.
  Future<String?> _findBackupFileId(drive.DriveApi driveApi) async {
    final fileList = await driveApi.files
        .list(
          q: "name = '$_backupFileName' and '$_appDataFolder' in parents and trashed = false",
          spaces: _appDataFolder,
          pageSize: 10,
          $fields: 'files(id,name)',
        )
        .timeout(_requestTimeout);

    final files = fileList.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }

  // ---------------------------------------------------------------------------
  // Обработка ошибок
  // ---------------------------------------------------------------------------

  Future<DriveSyncResult> _run(
      Future<DriveSyncResult> Function() action) async {
    try {
      return await action();
    } on TimeoutException {
      return const DriveSyncResult.failure(
        DriveSyncFailure.network,
        'Превышено время ожидания ответа Google Drive.',
      );
    } on DesktopAuthException catch (error) {
      return DriveSyncResult.failure(
        error.cancelled
            ? DriveSyncFailure.cancelled
            : DriveSyncFailure.notSignedIn,
        error.message,
      );
    } on GoogleSignInException catch (error) {
      return _mapSignInError(error);
    } on drive.DetailedApiRequestError catch (error) {
      return _mapApiError(error);
    } on FormatException catch (error) {
      return DriveSyncResult.failure(
        DriveSyncFailure.invalidBackup,
        'Повреждённые данные резервной копии: ${error.message}',
      );
    } catch (error, stack) {
      debugPrint('Ошибка синхронизации с Google Drive: $error');
      debugPrint(stack.toString());
      return DriveSyncResult.failure(
        DriveSyncFailure.unknown,
        'Непредвиденная ошибка синхронизации: $error',
      );
    }
  }

  DriveSyncResult _mapSignInError(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return const DriveSyncResult.failure(
          DriveSyncFailure.cancelled,
          'Вход в Google отменён пользователем.',
        );
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return DriveSyncResult.failure(
          DriveSyncFailure.notConfigured,
          'Google Sign-In настроен неверно: ${error.description ?? error.code.name}',
        );
      default:
        return DriveSyncResult.failure(
          DriveSyncFailure.unknown,
          'Ошибка Google Sign-In: ${error.description ?? error.code.name}',
        );
    }
  }

  DriveSyncResult _mapApiError(drive.DetailedApiRequestError error) {
    switch (error.status) {
      case 401:
        return const DriveSyncResult.failure(
          DriveSyncFailure.notSignedIn,
          'Сессия Google истекла. Войдите в аккаунт заново.',
        );
      case 403:
        return const DriveSyncResult.failure(
          DriveSyncFailure.permissionDenied,
          'Google Drive отклонил доступ. Проверьте, что Drive API включён '
          'в проекте Cloud Console и выдано разрешение на appDataFolder.',
        );
      case 404:
        return const DriveSyncResult.failure(
          DriveSyncFailure.backupNotFound,
          'Файл резервной копии не найден в Google Drive.',
        );
      default:
        return DriveSyncResult.failure(
          DriveSyncFailure.network,
          'Google Drive вернул ошибку ${error.status}: ${error.message ?? 'без описания'}',
        );
    }
  }
}

class _AuthOutcome {
  _AuthOutcome.ok(http.Client this.client) : error = null;

  _AuthOutcome.failed(DriveSyncResult this.error) : client = null;

  final http.Client? client;
  final DriveSyncResult? error;
}
