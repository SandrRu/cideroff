import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_settings_provider.dart';

class BatchCardSettingsScreen extends StatelessWidget {
  const BatchCardSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<AppSettingsProvider>();
    final cardSettings = settingsProvider.cardSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вид карточек партий'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Выберите данные, которые будут отображаться на карточках партий:',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Сорт яблок'),
            value: cardSettings.showVariety,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showVariety: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Объём сока'),
            value: cardSettings.showVolume,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showVolume: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Статус-бейдж (Бродильня / Выдержан)'),
            value: cardSettings.showTypeBadge,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showTypeBadge: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Дата следующего шага'),
            subtitle: const Text('Для партий в процессе'),
            value: cardSettings.showNextStepDate,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showNextStepDate: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Осталось дней до шага'),
            subtitle: const Text('Для партий в процессе'),
            value: cardSettings.showDaysLeft,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showDaysLeft: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Дней выдержки в бочке'),
            subtitle: const Text('Для Кальвадоса'),
            value: cardSettings.showAgingDays,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showAgingDays: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Показатели сахара'),
            value: cardSettings.showSugar,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showSugar: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Показатели алкоголя'),
            value: cardSettings.showAlcohol,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showAlcohol: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Информация о таре'),
            subtitle: const Text('Тип и количество бутылок'),
            value: cardSettings.showContainers,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showContainers: val),
                );
              }
            },
          ),
          CheckboxListTile(
            activeColor: Colors.amber,
            title: const Text('Название следующего шага'),
            subtitle: const Text('Показывать этап (например: "Снятие с осадка")'),
            value: cardSettings.showNextStepTitle,
            onChanged: (val) {
              if (val != null) {
                settingsProvider.updateCardSettings(
                  cardSettings.copyWith(showNextStepTitle: val),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}