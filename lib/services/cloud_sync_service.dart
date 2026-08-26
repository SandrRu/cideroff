import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:webdav_client/webdav_client.dart' as wd;
import 'export_import_service.dart';

class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  wd.Client? _client;

  /// Инициализация клиента WebDAV
  void init({
    required String uri,
    required String user,
    required String password,
  }) {
    _client = wd.newClient(
      uri,
      user: user,
      password: password,
    );
    _client?.setConnectTimeout(5000);
    _client?.setSendTimeout(5000);
    _client?.setReceiveTimeout(5000);
  }

  /// Проверка соединения с облаком
  Future<bool> testConnection() async {
    if (_client == null) return false;
    try {
      await _client!.ping();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Выгрузка бэкапа в облако
  Future<bool> uploadBackupToCloud() async {
    if (_client == null) return false;
    try {
      final jsonString = await ExportImportService().generateBackupJsonString();
      
      const remoteFileName = 'cideroff_sync_backup.ciderbak';
      
      final bytes = utf8.encode(jsonString);
      await _client!.write('/$remoteFileName', bytes);
      return true;
    } catch (e) {
      developer.log('Ошибка загрузки в облако: $e', name: 'CloudSyncService');
      return false;
    }
  }

  /// Скачивание и применение бэкапа из облака
  Future<bool> downloadAndApplyBackup() async {
    if (_client == null) return false;
    try {
      const remoteFileName = 'cideroff_sync_backup.ciderbak';
      
      // Скачиваем файл во временную директорию
      final tempDir = await getTemporaryDirectory();
      final localFile = File('${tempDir.path}/$remoteFileName');
      
      // Исправлено: используем read2File вместо read2
      await _client!.read2File('/$remoteFileName', localFile.path);
      
      // Импортируем скачанный файл с помощью существующего сервиса
      final success = await ExportImportService().importBackupFromFile(localFile.path);
      return success;
    } catch (e) {
      developer.log('Ошибка скачивания из облака: $e', name: 'CloudSyncService');
      return false;
    }
  }
}