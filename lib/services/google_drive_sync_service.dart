import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
// Импорт пакета расширения для получения авторизованного клиента (^3.0.0)
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

import 'export_import_service.dart';

class GoogleDriveSyncService {
  static final GoogleDriveSyncService _instance = GoogleDriveSyncService._internal();
  factory GoogleDriveSyncService() => _instance;
  GoogleDriveSyncService._internal();

  static const String _backupFileName = 'CiderOff_Backup_Auto.ciderbak';

  static const List<String> _scopes = [
    drive.DriveApi.driveAppdataScope,
    drive.DriveApi.driveFileScope,
  ];

  GoogleSignInAccount? _currentUser;
  bool _isInitialized = false;

  /// Инициализация синглтона GoogleSignIn
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      final signIn = GoogleSignIn.instance;
      
      // В версии 7.x отслеживаем состояние текущего пользователя через события
      signIn.authenticationEvents.listen((GoogleSignInAuthenticationEvent event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _currentUser = event.user;
            break;
          case GoogleSignInAuthenticationEventSignOut():
            _currentUser = null;
            break;
        }
      });

      // Обязательная инициализация перед любыми вызовами API
      await signIn.initialize();
      
      // Пробуем тихо авторизоваться при старте приложения (заменяет старый signInSilently)
      unawaited(signIn.attemptLightweightAuthentication());
      
      _isInitialized = true;
    }
  }

  /// Вход через Google Sign-In
  Future<GoogleSignInAccount?> signIn() async {
    try {
      await _ensureInitialized();
      
      if (_currentUser != null) {
        return _currentUser;
      }
      
      // В версии 7.x используется authenticate() вместо signIn()
      final account = await GoogleSignIn.instance.authenticate();
      return account;
    } catch (e) {
      debugPrint('Ошибка авторизации в Google: $e');
      return null;
    }
  }

  /// Выход из аккаунта Google
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      // В версии 7.x используется disconnect() для полного выхода и отзыва токена
      await GoogleSignIn.instance.disconnect();
    } catch (e) {
      debugPrint('Ошибка выхода из Google Sign-In: $e');
    }
  }

  /// Получение авторизованного клиента Drive API
  Future<drive.DriveApi?> _getDriveApi() async {
    final account = await signIn();
    if (account == null) {
      debugPrint('Пользователь не авторизован в Google');
      return null;
    }

    try {
      // 1. Проверяем наличие разрешений на нужные scopes (теперь это отдельный шаг авторизации)
      GoogleSignInClientAuthorization? authorization = await account.authorizationClient.authorizationForScopes(_scopes);
      
      // 2. Если разрешений нет, запрашиваем их у пользователя напрямую
      authorization ??= await account.authorizationClient.authorizeScopes(_scopes);

      if (authorization == null) {
        debugPrint('Не удалось получить авторизацию для требуемых scopes Drive API');
        return null;
      }

      // 3. Получаем HTTP-клиент с помощью extension_google_sign_in_as_googleapis_auth ^3.0.0
      // Метод теперь называется authClient(scopes: ...), и применяется к authorization
      final httpClient = authorization.authClient(scopes: _scopes);

      return drive.DriveApi(httpClient);
    } catch (e) {
      debugPrint('Ошибка при получении клиента Drive API: $e');
      return null;
    }
  }

  /// Загрузка резервной копии базы данных в Google Drive (в папку appDataFolder)
  Future<bool> uploadBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // 1. Сериализуем данные
      final jsonString = await ExportImportService().generateBackupJsonString();
      final bytes = utf8.encode(jsonString);

      // 2. Ищем существующий файл резервной копии в appDataFolder
      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
      );

      final mediaStream = Stream<List<int>>.value(bytes);
      final media = drive.Media(mediaStream, bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Обновляем существующий файл
        final existingFileId = fileList.files!.first.id!;
        final driveFile = drive.File();
        await driveApi.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
        debugPrint('Резервная копия успешно обновлена в Google Drive (ID: $existingFileId)');
      } else {
        // Создаем новый файл
        final driveFile = drive.File()
          ..name = _backupFileName
          ..parents = ['appDataFolder'];

        final result = await driveApi.files.create(
          driveFile,
          uploadMedia: media,
        );
        debugPrint('Новая резервная копия создана в Google Drive (ID: ${result.id})');
      }

      return true;
    } catch (e, stack) {
      debugPrint('Ошибка при выгрузке резервной копии в Google Drive: $e');
      debugPrint(stack.toString());
      return false;
    }
  }

  /// Скачивание и автоматическое применение бэкапа из Google Drive
  Future<bool> downloadAndApplyBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      // 1. Находим файл бэкапа
      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('Файл резервной копии не найден в Google Drive');
        return false;
      }

      final fileId = fileList.files!.first.id!;

      // 2. Скачиваем медиа-содержимое
      final dynamic response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      );

      if (response is drive.Media) {
        final List<int> dataBytes = [];
        await for (final chunk in response.stream) {
          dataBytes.addAll(chunk);
        }

        final jsonString = utf8.decode(dataBytes);

        // 3. Восстанавливаем базу через ExportImportService
        return await ExportImportService().importBackupFromJsonString(jsonString);
      } else {
        debugPrint('Некорректный формат ответа от Google Drive API');
        return false;
      }
    } catch (e, stack) {
      debugPrint('Ошибка при скачивании резервной копии из Google Drive: $e');
      debugPrint(stack.toString());
      return false;
    }
  }
}