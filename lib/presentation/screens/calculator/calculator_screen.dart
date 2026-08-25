import 'package:flutter/material.dart';
import '../../../core/utils/hydrometry_calculator.dart';

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

  // Поля Шаптализации
  double _currentSugar = 10.0;
  double _targetSugar = 14.0;
  double _volumeLiters = 20.0;

  // Поля Прайминга
  double _targetCo2 = 2.4;
  double _ciderTemp = 18.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор сидодела'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Крепость (ABV)'),
            Tab(text: 'Подсахаривание'),
            Tab(text: 'Карбонизация'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAbvCalculator(),
          _buildChaptalizationCalculator(),
          _buildPrimingCalculator(),
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

  // --- 2. Калькулятор Шаптализации ---
  Widget _buildChaptalizationCalculator() {
    final neededSugarGrams = HydrometryCalculator.calculateSugarAddition(
      currentSugarGrams100ml: _currentSugar,
      targetSugarGrams100ml: _targetSugar,
      volumeLiters: _volumeLiters,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildResultCard(
          title: 'Необходимо добавить сахара',
          value: '${neededSugarGrams.toStringAsFixed(0)} г',
          subtitle: 'Для объема $_volumeLiters л сока',
        ),
        const SizedBox(height: 20),
        Text('Текущий сахар: ${_currentSugar.toStringAsFixed(1)} г/100мл'),
        Slider(
          value: _currentSugar,
          min: 5.0,
          max: 20.0,
          divisions: 150,
          onChanged: (v) => setState(() => _currentSugar = v),
        ),
        Text('Желаемый сахар: ${_targetSugar.toStringAsFixed(1)} г/100мл'),
        Slider(
          value: _targetSugar,
          min: _currentSugar,
          max: 25.0,
          divisions: 150,
          onChanged: (v) => setState(() => _targetSugar = v),
        ),
        Text('Объём партии: ${_volumeLiters.toStringAsFixed(0)} л'),
        Slider(
          value: _volumeLiters,
          min: 1.0,
          max: 200.0,
          divisions: 199,
          onChanged: (v) => setState(() => _volumeLiters = v),
        ),
      ],
    );
  }

  // --- 3. Калькулятор Карбонизации ---
  Widget _buildPrimingCalculator() {
    final sugarPerLiter = HydrometryCalculator.calculatePrimingSugarPerLiter(
      targetCo2Volumes: _targetCo2,
      ciderTempC: _ciderTemp,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildResultCard(
          title: 'Сахар / Декстроза на розлив',
          value: '$sugarPerLiter г/л',
          subtitle: 'Уровень газации: $_targetCo2 Vol CO2 при $_ciderTemp°C',
        ),
        const SizedBox(height: 20),
        Text('Целевой уровень CO2: ${_targetCo2.toStringAsFixed(1)} Vol'),
        Slider(
          value: _targetCo2,
          min: 1.5,
          max: 3.5,
          divisions: 20,
          onChanged: (v) => setState(() => _targetCo2 = v),
        ),
        Text('Температура сидра при розливе: ${_ciderTemp.toStringAsFixed(0)} °C'),
        Slider(
          value: _ciderTemp,
          min: 0.0,
          max: 30.0,
          divisions: 30,
          onChanged: (v) => setState(() => _ciderTemp = v),
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
              style: TextStyle(
                color: Colors.amber.shade900,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}