import 'package:cider_off/data/models/batch_container_model.dart';
import 'package:cider_off/data/models/batch_model.dart';
import 'package:cider_off/data/models/drink_type_model.dart';
import 'package:cider_off/services/svg_label_processor.dart';
import 'package:flutter_test/flutter_test.dart';

Batch _batch({String name = 'Антоновка', String appleVariety = 'Антоновка'}) {
  return Batch(
    name: name,
    appleVariety: appleVariety,
    initialSugar: 12,
    juiceVolume: 20,
    pressDate: DateTime(2023, 5, 1),
    finalSugar: 0,
    finalAlcohol: 6.5,
    notes: 'Заметка',
  );
}

BatchContainer _container({String title = 'Сухой бугель'}) {
  return BatchContainer(
    batchId: 'b1',
    title: title,
    containerType: 'Бутылка (бугель)',
    containerVolumeLiters: 0.75,
    count: 20,
  );
}

void main() {
  group('getSweetnessCategory', () {
    test('использует встроенные границы, если справочник пуст', () {
      expect(SvgLabelProcessor.getSweetnessCategory(1.0, null), 'Сухой');
      expect(SvgLabelProcessor.getSweetnessCategory(2.0, null), 'Полусухой');
      expect(SvgLabelProcessor.getSweetnessCategory(4.0, null), 'Полусладкий');
      expect(SvgLabelProcessor.getSweetnessCategory(6.0, null), 'Сладкий');
    });

    test('использует пользовательские типы напитков', () {
      final types = [
        DrinkType(
          id: 't1',
          name: 'Брют',
          minSugarGramsPerLiter: 0,
          maxSugarGramsPerLiter: 10,
        ),
        DrinkType(
          id: 't2',
          name: 'Сладкий сидр',
          minSugarGramsPerLiter: 10.1,
          maxSugarGramsPerLiter: 100,
        ),
      ];

      expect(SvgLabelProcessor.getSweetnessCategory(0.5, types), 'Брют');
      expect(
          SvgLabelProcessor.getSweetnessCategory(5.0, types), 'Сладкий сидр');
    });
  });

  group('injectData', () {
    test('подставляет дату розлива, а не текущую дату', () {
      final svg = SvgLabelProcessor.injectData(
        rawSvg: '<text>{{BOTTLING_DATE}}</text>',
        batch: _batch(),
        container: _container(),
        bottlingDate: DateTime(2023, 5, 17),
      );

      expect(svg, contains('17.05.2023'));
      expect(svg, isNot(contains('{{BOTTLING_DATE}}')));
    });

    test('дата отжима подставляется отдельно', () {
      final svg = SvgLabelProcessor.injectData(
        rawSvg: '<text>{{PRESS_DATE}}</text>',
        batch: _batch(),
        container: _container(),
        bottlingDate: DateTime(2023, 5, 17),
      );

      expect(svg, contains('01.05.2023'));
    });

    test('экранирует XML в пользовательских данных', () {
      final svg = SvgLabelProcessor.injectData(
        rawSvg: '<text>{{BATCH_NAME}}|{{NOTES}}</text>',
        batch: _batch(name: 'Сидр & Ко <премиум>'),
        container: _container(),
        bottlingDate: DateTime(2023, 5, 17),
      );

      expect(svg, contains('Сидр &amp; Ко &lt;премиум&gt;'));
      expect(svg, isNot(contains('<премиум>')));
    });

    test('восстанавливает плейсхолдер, разорванный тегами tspan', () {
      final svg = SvgLabelProcessor.injectData(
        rawSvg: '<text><tspan>{{BATCH</tspan><tspan>_NAME}}</tspan></text>',
        batch: _batch(name: 'Штрифлинг'),
        container: _container(),
        bottlingDate: DateTime(2023, 5, 17),
      );

      expect(svg, contains('Штрифлинг'));
    });

    test('подставляет данные тары и подсластителя', () {
      final svg = SvgLabelProcessor.injectData(
        rawSvg:
            '<text>{{CONTAINER_TITLE}}/{{CONTAINER_TYPE}}/{{SWEETENER}}</text>',
        batch: _batch(),
        container: _container(title: 'Сладкий кег'),
        bottlingDate: DateTime(2023, 5, 17),
      );

      expect(svg, contains('Сладкий кег'));
      expect(svg, contains('Бутылка (бугель)'));
      expect(svg, contains('Без подсластителя'));
    });
  });
}
