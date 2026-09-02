# Сохраняем MainActivity от удаления и переименования
-keep class ru.sandr.cideroff_app.MainActivity { *; }

# Сохраняем ключевые классы Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }