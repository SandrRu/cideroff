import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/batch_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/yeast_provider.dart';
import '../dashboard/dashboard_screen.dart';
import 'main_screen.dart';
import '../recipe/recipe_list_screen.dart';
import '../calculator/calculator_screen.dart';
import '../settings/settings_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BatchProvider>().loadBatches();
        context.read<RecipeProvider>().loadRecipes();
        context.read<YeastProvider>().loadYeasts();
      }
    });
  }

  final List<Widget> _screens = const [
    DashboardScreen(),   // Вкладка 0: Дашборд
    MainScreen(),        // Вкладка 1: Партии
    RecipeListScreen(),  // Вкладка 2: Рецепты
    CalculatorScreen(),  // Вкладка 3: Калькулятор
    SettingsScreen(),    // Вкладка 4: Настройки
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        indicatorColor: Colors.amber.shade200,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Colors.black87),
            label: 'Дашборд',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science, color: Colors.black87),
            label: 'Партии',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book, color: Colors.black87),
            label: 'Рецепты',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate, color: Colors.black87),
            label: 'Калькулятор',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Colors.black87),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}