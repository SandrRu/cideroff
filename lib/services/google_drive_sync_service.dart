import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Используется для Platform.isWindows / Platform.isAndroid
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

  // OAuth Client ID из Google Cloud Console для Windows (Тип: Desktop App)
  //static const String _windowsClientId = 'XXXXXX';
  //static const String _windowsClientSecret = 'XXXXXXX';
  // Получение значений из флагов сборки --dart-define
  static const String _windowsClientId = String.fromEnvironment('WINDOWS_CLIENT_ID');
  static const String _windowsClientSecret = String.fromEnvironment('WINDOWS_CLIENT_SECRET');

  GoogleSignInAccount? _currentUser;
  bool _isInitialized = false;

  // Авторизованный клиент для Windows Desktop
  http.Client? _windowsAuthClient;

  /// Проверка на Desktop платформу через dart:io
  bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// Инициализация GoogleSignIn для мобильных/Web платформ
  Future<void> _ensureInitialized() async {
    if (_isDesktop) return;

    if (!_isInitialized) {
      final signIn = GoogleSignIn.instance;
      
      signIn.authenticationEvents.listen((GoogleSignInAuthenticationEvent event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _currentUser = event.user;
            break;
          case GoogleSignInAuthenticationEventSignOut():
            _currentUser = null;
            _windowsAuthClient?.close();
            _windowsAuthClient = null;
            break;
        }
      });

      await signIn.initialize();
      unawaited(signIn.attemptLightweightAuthentication());
      _isInitialized = true;
    }
  }

  /// Вход через Google Sign-In или OAuth Loopback Flow (Windows)
  Future<bool> signIn() async {
    try {
      if (_isDesktop) {
        if (_windowsAuthClient != null) return true;

        final clientId = ClientId(
          _windowsClientId,
          _windowsClientSecret.isNotEmpty ? _windowsClientSecret : null,
        );

        _windowsAuthClient = await clientViaUserConsent(
          clientId,
          _scopes,
          (String url) async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        );

        return _windowsAuthClient != null;
      } else {
        await _ensureInitialized();
        if (_currentUser != null) return true;

        final account = await GoogleSignIn.instance.authenticate();
        _currentUser = account;
        return _currentUser != null;
      }
    } catch (e) {
      debugPrint('Ошибка авторизации в Google: $e');
      return false;
    }
  }

  /// Выход из аккаунта Google
  Future<void> signOut() async {
    try {
      if (_isDesktop) {
        _windowsAuthClient?.close();
        _windowsAuthClient = null;
      } else {
        await _ensureInitialized();
        await GoogleSignIn.instance.disconnect();
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('Ошибка выхода из Google Sign-In: $e');
    }
  }

  /// Получение авторизованного клиента Drive API
  Future<drive.DriveApi?> _getDriveApi() async {
    final signedIn = await signIn();
    if (!signedIn) {
      debugPrint('Пользователь не авторизован в Google');
      return null;
    }

    try {
      if (_isDesktop) {
        if (_windowsAuthClient == null) return null;
        return drive.DriveApi(_windowsAuthClient!);
      } else {
        final account = _currentUser;
        if (account == null) return null;

        GoogleSignInClientAuthorization? authorization =
            await account.authorizationClient.authorizationForScopes(_scopes);
        
        authorization ??= await account.authorizationClient.authorizeScopes(_scopes);

        if (authorization == null) {
          debugPrint('Не удалось получить авторизацию для требуемых scopes Drive API');
          return null;
        }

        final httpClient = authorization.authClient(scopes: _scopes);
        return drive.DriveApi(httpClient);
      }
    } catch (e) {
      debugPrint('Ошибка при получении клиента Drive API: $e');
      return null;
    }
  }

  /// Загрузка резервной копии базы данных в Google Drive
  Future<bool> uploadBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final jsonString = await ExportImportService().generateBackupJsonString();
      final bytes = utf8.encode(jsonString);

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
      );

      final mediaStream = Stream<List<int>>.value(bytes);
      final media = drive.Media(mediaStream, bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final existingFileId = fileList.files!.first.id!;
        final driveFile = drive.File();
        await driveApi.files.update(
          driveFile,
          existingFileId,
          uploadMedia: media,
        );
        debugPrint('Резервная копия успешно обновлена в Google Drive (ID: $existingFileId)');
      } else {
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

      final fileList = await driveApi.files.list(
        q: "name = '$_backupFileName' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('Файл резервной копии не найден в Google Drive');
        return false;
      }

      final fileId = fileList.files!.first.id!;

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