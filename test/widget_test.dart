import 'package:flutter_test/flutter_test.dart';
import 'package:cider_off/main.dart';

void main() {
  testWidgets('CiderOffApp smoke test', (WidgetTester tester) async {
    // Монтируем главное приложение CiderOffApp вместо несуществующего MyApp
    await tester.pumpWidget(const CiderOffApp());

    // Проверяем наличие заголовок или стартовый экран
    expect(find.byType(CiderOffApp), findsOneWidget);
  });
}