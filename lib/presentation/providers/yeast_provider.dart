import 'package:flutter/material.dart';
import '../../data/datasources/database_service.dart';
import '../../data/models/yeast_model.dart';

class YeastProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<Yeast> _yeasts = [];
  bool _isLoading = false;

  List<Yeast> get yeasts => _yeasts;
  bool get isLoading => _isLoading;

  Future<void> loadYeasts({bool force = false}) async {
    if (_isLoading) return;
    if (!force && _yeasts.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    _yeasts = await _db.getAllYeasts();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveYeast(Yeast yeast) async {
    await _db.insertYeast(yeast);
    await loadYeasts(force: true);
  }

  Future<void> deleteYeast(String id) async {
    await _db.deleteYeast(id);
    await loadYeasts(force: true);
  }
}