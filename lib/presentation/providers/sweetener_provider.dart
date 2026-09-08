import 'package:flutter/foundation.dart';
import 'package:cider_off/data/models/sweetener_type_model.dart';
import 'package:cider_off/data/datasources/database_service.dart';

class SweetenerProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<SweetenerType> _sweetenerTypes = [];
  bool _isLoading = false;

  List<SweetenerType> get sweetenerTypes => _sweetenerTypes;
  bool get isLoading => _isLoading;

  /// Загрузка списка подсластителей из базы данных
  Future<void> loadSweetenerTypes() async {
    _isLoading = true;
    notifyListeners();

    try {
      _sweetenerTypes = await _db.getAllSweetenerTypes();
    } catch (e) {
      debugPrint('Error loading sweetener types: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Добавление нового пользовательского подсластителя
  Future<void> addSweetenerType(SweetenerType sweetener) async {
    try {
      await _db.insertSweetenerType(sweetener);
      await loadSweetenerTypes(); // Обновляем список
    } catch (e) {
      debugPrint('Error adding sweetener type: $e');
      rethrow;
    }
  }

  /// Удаление подсластителя (только пользовательского)
  Future<void> deleteSweetenerType(String id) async {
    try {
      await _db.deleteSweetenerType(id);
      await loadSweetenerTypes();
    } catch (e) {
      debugPrint('Error deleting sweetener type: $e');
      rethrow;
    }
  }
}