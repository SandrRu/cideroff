import 'package:cider_off/data/models/batch_history_model.dart';
import 'package:cider_off/presentation/screens/history/widgets/fermentation_chart.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BatchHistory _measurement({
  required DateTime timestamp,
  double? sugar,
  double? alcohol,
}) {
  return BatchHistory(
    batchId: 'b1',
    timestamp: timestamp,
    stepTitle: 'Постановка на первичное брожение',
    actionName: 'Шаг выполнен',
    sugarMeasured: sugar,
    alcoholMeasured: alcohol,
  );
}

void main() {
  testWidgets('график без замеров ничего не рисует', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: FermentationChart(historyList: [])),
      ),
    );

    expect(find.byType(FermentationChart), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('график строит диаграмму по замерам', (tester) async {
    final history = [
      _measurement(timestamp: DateTime(2023, 5, 1), sugar: 12),
      _measurement(timestamp: DateTime(2023, 5, 8), sugar: 6, alcohol: 3.2),
      _measurement(timestamp: DateTime(2023, 5, 15), sugar: 1, alcohol: 6.4),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 400,
            child: FermentationChart(historyList: history),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(LineChart), findsOneWidget);
  });
}
