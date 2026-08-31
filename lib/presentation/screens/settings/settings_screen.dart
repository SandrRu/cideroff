import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/export_import_service.dart';
import '../../../services/cloud_sync_service.dart';
import '../../../services/google_drive_sync_service.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/batch_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/yeast_provider.dart';
import '../recipe/recipe_list_screen.dart';
import '../label/label_template_list_screen.dart';
import '../yeast/yeast_list_screen.dart';
import 'batch_card_settings_screen.dart';
import 'dashboard_settings_screen.dart';
import '../../../data/datasources/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _calendarSyncEnabled = true;

  final _webdavUrlController = TextEditingController();
  final _webdavUsernameController = TextEditingController();
  final _webdavPasswordController = TextEditingController();

  bool _isUploading = false;
  bool _isDownloading = false;

  // Состояние синхронизации Google Drive
  bool _isGoogleDriveUploading = false;
  bool _isGoogleDriveDownloading = false;

  @override
  void dispose() {
    _webdavUrlController.dispose();
    _webdavUsernameController.dispose();
    _webdavPasswordController.dispose();
    super.dispose();
  }

  Future<void> _uploadToGoogleDrive() async {
    setState(() => _isGoogleDriveUploading = true);
    try {
      final success = await GoogleDriveSyncService().uploadBackup();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Резервная копия выгружена в Google Drive'
                : 'Ошибка выгрузки в Google Drive',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGoogleDriveUploading = false);
    }
  }

  Future<void> _downloadFromGoogleDrive() async {
    setState(() => _isGoogleDriveDownloading = true);
    try {
      final success = await GoogleDriveSyncService().downloadAndApplyBackup();
      if (!mounted) return;

      if (success) {
        await context.read<BatchProvider>().loadBatches();
        await context.read<RecipeProvider>().loadRecipes();
        await context.read<YeastProvider>().loadYeasts();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные успешно восстановлены из Google Drive')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить резервную копию из Google Drive')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleDriveDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<AppSettingsProvider>();
    final currentLocaleCode = settingsProvider.currentLocale.languageCode;
    final currentLanguageName = currentLocaleCode == 'en' ? 'English' : 'Русский';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Раздел: Основные настройки
          _buildSectionHeader('Основные'),
          ListTile(
            leading: const Icon(Icons.language_outlined, color: Colors.amber),
            title: const Text('Язык интерфейса'),
            subtitle: Text(currentLanguageName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_outlined, color: Colors.amber),
            title: const Text('Настройки Дашборда'),
            subtitle: const Text('Выбор колонок и активных карточек статистики'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DashboardSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.style_outlined, color: Colors.amber),
            title: const Text('Вид карточек партий'),
            subtitle: const Text('Выбор отображаемых полей на главном экране'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BatchCardSettingsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.grain_outlined, color: Colors.amber),
            title: const Text('Справочник дрожжей'),
            subtitle: const Text('Управление штаммами дрожжей для брожения'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const YeastListScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined, color: Colors.amber),
            title: const Text('Рецепты'),
            subtitle: const Text('Просмотр и редактирование базовых рецептов'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecipeListScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_2_outlined, color: Colors.amber),
            title: const Text('Макеты наклеек'),
            subtitle: const Text('Управление шаблонами и дизайном этикеток'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LabelTemplateListScreen(),
                ),
              );
            },
          ),

          const Divider(),

          // Раздел: Облачная синхронизация Google Drive
          _buildSectionHeader('Синхронизация Google Drive'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isGoogleDriveUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.add_to_drive_outlined),
                    label: Text(_isGoogleDriveUploading ? 'Сохранение...' : 'Выгрузить в Drive'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: (_isGoogleDriveUploading || _isGoogleDriveDownloading)
                        ? null
                        : _uploadToGoogleDrive,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _isGoogleDriveDownloading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    label: Text(_isGoogleDriveDownloading ? 'Загрузка...' : 'Скачать из Drive'),
                    onPressed: (_isGoogleDriveUploading || _isGoogleDriveDownloading)
                        ? null
                        : _downloadFromGoogleDrive,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Раздел: Облачная синхронизация WebDAV
          _buildSectionHeader('Синхронизация WebDAV'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: _webdavUrlController,
                  decoration: const InputDecoration(
                    labelText: 'URL сервера WebDAV',
                    hintText: 'https://example.com/remote.php/webdav/',
                    prefixIcon: Icon(Icons.cloud_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _webdavUsernameController,
                  decoration: const InputDecoration(
                    labelText: 'Логин',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _webdavPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(_isUploading ? 'Выгрузка...' : 'Выгрузить в облако'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: (_isUploading || _isDownloading) ? null : _uploadToWebDav,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _isDownloading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                        label: Text(_isDownloading ? 'Загрузка...' : 'Скачать из облака'),
                        onPressed: (_isUploading || _isDownloading) ? null : _downloadFromWebDav,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(),

          // Раздел: Напоминания
          _buildSectionHeader('Напоминания и Календарь'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined, color: Colors.amber),
            title: const Text('Push-уведомления'),
            subtitle: const Text('Напоминать о наступлении следующих этапов'),
            value: _notificationsEnabled,
            activeThumbColor: Colors.amber,
            onChanged: (val) {
              setState(() {
                _notificationsEnabled = val;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.calendar_today_outlined, color: Colors.amber),
            title: const Text('Синхронизация с Календарем'),
            subtitle: const Text('Добавлять события в системный календарь'),
            value: _calendarSyncEnabled,
            activeThumbColor: Colors.amber,
            onChanged: (val) {
              setState(() {
                _calendarSyncEnabled = val;
              });
            },
          ),

          const Divider(),

          // Раздел: Данные и База данных
          _buildSectionHeader('Управление данными'),
          ListTile(
            leading: const Icon(Icons.refresh, color: Colors.blue),
            title: const Text('Перезагрузить все данные'),
            subtitle: const Text('Обновить список партий, рецептов и дрожжей из базы'),
            onTap: () async {
              final batchProvider = context.read<BatchProvider>();
              final recipeProvider = context.read<RecipeProvider>();
              final yeastProvider = context.read<YeastProvider>();

              await batchProvider.loadBatches();
              await recipeProvider.loadRecipes();
              await yeastProvider.loadYeasts();

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Данные успешно обновлены')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined, color: Colors.green),
            title: const Text('Экспорт данных (Бэкап)'),
            subtitle: const Text('Сохранить все партии, историю и рецепты в файл'),
            onTap: () async {
              try {
                await ExportImportService().exportFullBackup();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Экспорт бэкапа завершён')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка экспорта: $e')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined, color: Colors.orange),
            title: const Text('Импорт данных (Восстановление)'),
            subtitle: const Text('Восстановить резервную копию из файла .ciderbak'),
            onTap: () async {
              try {
                final success = await ExportImportService().importFullBackup();
                if (success && mounted) {
                  await context.read<BatchProvider>().loadBatches();
                  await context.read<RecipeProvider>().loadRecipes();
                  await context.read<YeastProvider>().loadYeasts();

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Данные успешно восстановлены')),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка импорта: $e')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('Очистить базу данных'),
            subtitle: const Text('Удалить все созданные партии и историю'),
            onTap: () => _showClearDataDialog(context),
          ),

          const Divider(),

          // Раздел: О приложении
          _buildSectionHeader('О приложении'),
          const ListTile(
            leading: Icon(Icons.local_drink_outlined, color: Colors.amber),
            title: Text('CiderOff'),
            subtitle: Text('Версия 1.1.0'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.grey),
            title: const Text('Помощь и поддержка'),
            subtitle: const Text('Руководство по изготовлению сидра'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'CiderOff',
                applicationVersion: '1.1.0',
                applicationIcon: const Icon(Icons.local_drink, size: 40, color: Colors.amber),
                children: [
                  const SizedBox(height: 12),
                  const Text('Приложение для контроля процесса брожения, замеров сахара, алкоголя и печати этикеток.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  bool _initWebDavClient() {
    final url = _webdavUrlController.text.trim();
    final username = _webdavUsernameController.text.trim();
    final password = _webdavPasswordController.text;

    if (url.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните URL, логин и пароль WebDAV')),
      );
      return false;
    }

    CloudSyncService().init(
      uri: url,
      user: username,
      password: password,
    );
    return true;
  }

  Future<void> _uploadToWebDav() async {
    if (!_initWebDavClient()) return;

    setState(() => _isUploading = true);
    try {
      final success = await CloudSyncService().uploadBackupToCloud();
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бэкап успешно выгружен в WebDAV')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка подключения или выгрузки в WebDAV')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _downloadFromWebDav() async {
    if (!_initWebDavClient()) return;

    setState(() => _isDownloading = true);
    try {
      final success = await CloudSyncService().downloadAndApplyBackup();
      if (!mounted) return;

      if (success) {
        await context.read<BatchProvider>().loadBatches();
        await context.read<RecipeProvider>().loadRecipes();
        await context.read<YeastProvider>().loadYeasts();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Данные успешно загружены из WebDAV')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка скачивания бэкапа из WebDAV')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.amber.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          title: const Text('Выберите язык'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                context.read<AppSettingsProvider>().setLocale(const Locale('ru'));
                Navigator.pop(dialogContext);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Русский', style: TextStyle(fontSize: 16)),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                context.read<AppSettingsProvider>().setLocale(const Locale('en'));
                Navigator.pop(dialogContext);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('English', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Очистить все данные?'),
          content: const Text(
            'Вы уверены, что хотите удалить все сохраненные партии и историю замеров? Это действие нельзя отменить.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final batchProvider = context.read<BatchProvider>();
                final recipeProvider = context.read<RecipeProvider>();
                final yeastProvider = context.read<YeastProvider>();

                Navigator.pop(dialogContext);

                await DatabaseService.instance.clearAllData();
                await batchProvider.loadBatches();
                await recipeProvider.loadRecipes();
                await yeastProvider.loadYeasts();

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('База данных успешно очищена')),
                );
              },
              child: const Text('Удалить всё'),
            ),
          ],
        );
      },
    );
  }
}