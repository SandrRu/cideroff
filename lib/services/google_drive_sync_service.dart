import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'export_import_service.dart';

class GoogleDriveSyncService {
  static final GoogleDriveSyncService _instance = GoogleDriveSyncService._internal();
  factory GoogleDriveSyncService() => _instance;
  GoogleDriveSyncService._internal();

  final _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  Future<bool> signIn() async {
    try {
      await _ensureInitialized();
      _currentUser = await _googleSignIn.authenticate(
        scopeHint: [drive.DriveApi.driveAppdataScope],
      );
      return _currentUser != null;
    } catch (e) {
      debugPrint('Ошибка авторизации Google: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    if (_currentUser == null) {
      final success = await signIn();
      if (!success) return null;
    }

    try {
      final auth = await _currentUser?.authorizationClient.authorizeScopes([drive.DriveApi.driveAppdataScope]);
      if (auth == null) return null;

      final httpClient = _AuthenticatedClient(auth.accessToken);
      return drive.DriveApi(httpClient);
    } catch (e) {
      debugPrint('Ошибка создания Drive API клиента: $e');
      return null;
    }
  }

  /// Выгрузка бэкапа CiderOff в Google Drive (в папку appDataFolder)
  Future<bool> uploadBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final jsonString = await ExportImportService().generateBackupJsonString();
      final bytes = utf8.encode(jsonString);

      const fileName = 'cideroff_backup.ciderbak';

      final fileList = await driveApi.files.list(
        q: "name = '$fileName' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
      );

      final mediaStream = Stream.value(bytes);
      final media = drive.Media(mediaStream, bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        final driveFile = drive.File()
          ..name = fileName
          ..parents = ['appDataFolder'];
        await driveApi.files.create(driveFile, uploadMedia: media);
      }
      return true;
    } catch (e) {
      debugPrint('Ошибка выгрузки в Google Drive: $e');
      return false;
    }
  }

  /// Загрузка и восстановление бэкапа из Google Drive
  Future<bool> downloadAndApplyBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      const fileName = 'cideroff_backup.ciderbak';

      final fileList = await driveApi.files.list(
        q: "name = '$fileName' and 'appDataFolder' in parents and trashed = false",
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

      if (response is! drive.Media) {
        debugPrint('Не удалось получить поток файла Media из Google Drive');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final localFile = io.File('${tempDir.path}/$fileName');
      
      final List<int> dataBytes = [];
      await for (final data in response.stream) {
        dataBytes.addAll(data);
      }
      await localFile.writeAsBytes(dataBytes);

      return await ExportImportService().importBackupFromFile(localFile.path);
    } catch (e) {
      debugPrint('Ошибка скачивания из Google Drive: $e');
      return false;
    }
  }
}

/// Простой HTTP клиент для подстановки Bearer-токена в вызовы Google API
class _AuthenticatedClient extends http.BaseClient {
  final String _token;
  final http.Client _client = http.Client();

  _AuthenticatedClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _client.send(request);
  }
}