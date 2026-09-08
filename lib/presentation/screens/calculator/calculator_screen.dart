import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cider_off/core/utils/hydrometry_calculator.dart';
import 'package:cider_off/data/models/drink_type_model.dart';
import 'package:cider_off/data/models/sweetener_type_model.dart';
import 'package:cider_off/data/datasources/database_service.dart';
import 'package:cider_off/presentation/providers/sweetener_provider.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Поля ABV
  double _ogBrix = 12.0;
  double _fgBrix = 2.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор сидродела'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Крепость (ABV)'),
            Tab(text: 'Сладость / Розлив'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbvCalculator(),
          const BottlingCalculatorTab(),
        ],
      ),
    );
  }

  // --- 1. Калькулятор Алкоголя ---
  Widget _buildAbvCalculator() {
    final ogSg = HydrometryCalculator.brixToSg(_ogBrix);
    final fgSg = HydrometryCalculator.brixToSg(_fgBrix);
    final abv = HydrometryCalculator.calculateAbvFromSg(ogSg, fgSg);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildResultCard(
          title: 'Оцениваемая крепость (ABV)',
          value: '$abv % об.',
          subtitle: 'Начальный SG: ${ogSg.toStringAsFixed(3)} | Конечный SG: ${fgSg.toStringAsFixed(3)}',
        ),
        const SizedBox(height: 20),
        Text('Начальный сахар: ${_ogBrix.toStringAsFixed(1)} °Brix'),
        Slider(
          value: _ogBrix,
          min: 5.0,
          max: 25.0,
          divisions: 200,
          label: '$_ogBrix °Brix',
          onChanged: (v) => setState(() => _ogBrix = v),
        ),
        const SizedBox(height: 12),
        Text('Конечный сахар: ${_fgBrix.toStringAsFixed(1)} °Brix'),
        Slider(
          value: _fgBrix,
          min: 0.0,
          max: 10.0,
          divisions: 100,
          label: '$_fgBrix °Brix',
          onChanged: (v) => setState(() => _fgBrix = v),
        ),
      ],
    );
  }

  Widget _buildResultCard({required String title, required String value, required String subtitle}) {
    return Card(
      color: Colors.amber.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: Colors.amber.shade900, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. Калькулятор Розлива и Подсластителя ---
class BottlingCalculatorTab extends StatefulWidget {
  const BottlingCalculatorTab({super.key});

  @override
  State<BottlingCalculatorTab> createState() => _BottlingCalculatorTabState();
}

class _BottlingCalculatorTabState extends State<BottlingCalculatorTab> {
  final _tareWeightController = TextEditingController();
  final _tareWithMustWeightController = TextEditingController();
  final _carbonationDextroseController = TextEditingController(text: '7.0'); // По умолчанию 7 г/л
  final _desiredSweetnessController = TextEditingController();

  List<DrinkType> _drinkTypes = [];
  SweetenerType? _selectedSweetener;

  // Результаты расчетов
  double? _netMustWeight;
  double? _weightWithDextrose;
  double? _weightWithDextroseAndSweetener;
  String _calculatedSweetnessType = '—';
  double? _maxAllowedSweetness;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _tareWeightController.dispose();
    _tareWithMustWeightController.dispose();
    _carbonationDextroseController.dispose();
    _desiredSweetnessController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final sweetenerProvider = context.read<SweetenerProvider>();
      await sweetenerProvider.loadSweetenerTypes();

      final drinkTypes = await DatabaseService.instance.getAllDrinkTypes();

      if (mounted) {
        setState(() {
          _drinkTypes = drinkTypes;
          if (sweetenerProvider.sweetenerTypes.isNotEmpty) {
            _selectedSweetener = sweetenerProvider.sweetenerTypes.first;
          }

          if (_drinkTypes.isNotEmpty) {
            _maxAllowedSweetness = _drinkTypes
                .map((d) => d.maxSugarGramsPerLiter)
                .reduce((a, b) => a > b ? a : b);
          }
        });
        _calculate();
      }
    });
  }

  double? _parseDouble(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  void _calculate() {
    final tareWeight = _parseDouble(_tareWeightController.text);
    final tareWithMustWeight = _parseDouble(_tareWithMustWeightController.text);
    final carbonationRate = _parseDouble(_carbonationDextroseController.text) ?? 0.0;
    final desiredSweetness = _parseDouble(_desiredSweetnessController.text) ?? 0.0;

    if (tareWeight == null || tareWithMustWeight == null || tareWithMustWeight <= tareWeight) {
      setState(() {
        _netMustWeight = null;
        _weightWithDextrose = null;
        _weightWithDextroseAndSweetener = null;
        _calculatedSweetnessType = '—';
      });
      return;
    }

    final netMust = tareWithMustWeight - tareWeight;

    String sweetnessTypeResult = 'Вне диапазонов';
    for (final drinkType in _drinkTypes) {
      if (desiredSweetness >= drinkType.minSugarGramsPerLiter &&
          desiredSweetness <= drinkType.maxSugarGramsPerLiter) {
        sweetnessTypeResult = drinkType.name;
        break;
      }
    }

    // Расчет нормы декстрозы на основе введенного пользователем значения (г/л)
    final dextroseAmount = (netMust / 1000.0) * carbonationRate;
    final weightAfterDextrose = tareWithMustWeight + dextroseAmount;

    final factor = _selectedSweetener?.sweetnessFactor ?? 1.0;
    final sweetenerGramPerLiter = factor > 0 ? (desiredSweetness / factor) : 0.0;
    final totalSweetenerAmount = (netMust / 1000.0) * sweetenerGramPerLiter;

    final weightAfterSweetener = weightAfterDextrose + totalSweetenerAmount;

    setState(() {
      _netMustWeight = netMust;
      _weightWithDextrose = weightAfterDextrose;
      _weightWithDextroseAndSweetener = weightAfterSweetener;
      _calculatedSweetnessType = sweetnessTypeResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sweeteners = context.watch<SweetenerProvider>().sweetenerTypes;

    final currentSweetener = sweeteners.contains(_selectedSweetener)
        ? _selectedSweetener
        : (sweeteners.isNotEmpty ? sweeteners.first : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Калькулятор розлива',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _tareWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '1) Вес тары (г)',
              hintText: 'Например: 450',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _tareWithMustWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '2) Вес тары с суслом (г)',
              hintText: 'Например: 1200',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 12),

          // Поле: Карбонизация (г/л)
          TextField(
            controller: _carbonationDextroseController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '3) Карбонизация / Декстроза (г/л)',
              hintText: 'Например: 7.0',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<SweetenerType>(
            value: currentSweetener,
            decoration: const InputDecoration(
              labelText: '4) Тип подсластителя',
              border: OutlineInputBorder(),
            ),
            items: sweeteners.map((sw) {
              return DropdownMenuItem<SweetenerType>(
                value: sw,
                child: Text('${sw.name} (Коэфф: ${sw.sweetnessFactor})'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                _selectedSweetener = val;
              });
              _calculate();
            },
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _desiredSweetnessController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '5) Сладость (г/л)',
              hintText: _maxAllowedSweetness != null
                  ? 'Макс. лимит: ${_maxAllowedSweetness!.toStringAsFixed(1)} г/л'
                  : 'Введите желаемую сладость',
              border: const OutlineInputBorder(),
            ),
            onChanged: (val) {
              final doubleVal = _parseDouble(val);
              if (doubleVal != null &&
                  _maxAllowedSweetness != null &&
                  doubleVal > _maxAllowedSweetness!) {
                _desiredSweetnessController.text = _maxAllowedSweetness!.toStringAsFixed(1);
                _desiredSweetnessController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _desiredSweetnessController.text.length),
                );
              }
              _calculate();
            },
          ),
          const SizedBox(height: 8),

          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Тип сладости',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.black12,
            ),
            child: Text(
              _calculatedSweetnessType,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),

          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Результаты расчета:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Divider(),
                  _resultRow(
                    'Чистый вес сусла:',
                    _netMustWeight != null
                        ? '${_netMustWeight!.toStringAsFixed(1)} г'
                        : '—',
                  ),
                  const SizedBox(height: 8),
                  _resultRow(
                    'Вес после карбонизации (декстроза):',
                    _weightWithDextrose != null
                        ? '${_weightWithDextrose!.toStringAsFixed(1)} г'
                        : '—',
                  ),
                  const SizedBox(height: 8),
                  _resultRow(
                    'Вес с декстрозой и подсластителем:',
                    _weightWithDextroseAndSweetener != null
                        ? '${_weightWithDextroseAndSweetener!.toStringAsFixed(1)} г'
                        : '—',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black87, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}