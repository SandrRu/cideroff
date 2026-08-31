import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:path_provider/path_provider.dart';

import 'export_import_service.dart';

class GoogleDriveSyncService {
  static final GoogleDriveSyncService _instance = GoogleDriveSyncService._internal();
  factory GoogleDriveSyncService() => _instance;
  GoogleDriveSyncService._internal();

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  GoogleSignInAccount? _currentUser;

  GoogleSignInAccount? get currentUser => _currentUser;

  Future<bool> signIn() async {
    try {
      _currentUser = await _googleSignIn.signIn();
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
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return null;
    return drive.DriveApi(httpClient);
  }

  /// Выгрузка бэкапа CiderOff в Google Drive (в папку appDataFolder)
  Future<bool> uploadBackup() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return false;

      final jsonString = await ExportImportService().generateBackupJsonString();
      final bytes = utf8.encode(jsonString);

      const fileName = 'cideroff_backup.ciderbak';

      // Поиск существующего файла в appDataFolder
      final fileList = await driveApi.files.list(
        q: "name = '$fileName' and 'appDataFolder' in parents and trashed = false",
        spaces: 'appDataFolder',
      );

      final mediaStream = Stream.value(bytes);
      final media = drive.Media(mediaStream, bytes.length);

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Перезапись существующего бэкапа
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(drive.File(), fileId, uploadMedia: media);
      } else {
        // Создание нового файла
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
      final localFile = File('${tempDir.path}/$fileName');
      
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