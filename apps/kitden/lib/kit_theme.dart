import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// KITTHEME FORMAT v1
// ============================================================

class KitTheme {
  KitTheme({
    required this.id,
    required this.name,
    required this.author,
    required this.appearance,
    required Map<String, Color> colors,
  }) : colors = Map.unmodifiable(colors);

  final String id;
  final String name;
  final String author;
  final Brightness appearance;
  final Map<String, Color> colors;

  static const requiredColors = <String>[
    'background',
    'sidebar',
    'panel',
    'field',
    'border',
    'accent',
    'accentDim',
    'danger',
    'textPrimary',
    'textSecondary',
    'textMuted',
  ];

  // ----------------------------------------------------------
  // READ A .KITTH FILE
  // ----------------------------------------------------------

  factory KitTheme.parse(String source) {
    if (source.length > 131072) {
      throw const FormatException('Theme file exceeds 128 KiB');
    }

    final decoded = jsonDecode(source);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('A .kitth file must contain a JSON object');
    }

    if (decoded['format'] != 'kitth') {
      throw const FormatException('Not a KitTheme file');
    }

    if (decoded['formatVersion'] != 1) {
      throw const FormatException('Unsupported KitTheme format version');
    }

    final id = decoded['id'];
    final name = decoded['name'];
    final author = decoded['author'];
    final appearance = decoded['appearance'];
    final palette = decoded['colors'];

    if (id is! String || !RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$').hasMatch(id)) {
      throw const FormatException(
        'Theme ID must contain lowercase letters, '
        'numbers, or hyphens',
      );
    }

    if (name is! String || name.trim().isEmpty || name.length > 100) {
      throw const FormatException('Invalid theme name');
    }

    if (author is! String || author.trim().isEmpty || author.length > 100) {
      throw const FormatException('Invalid theme author');
    }

    if (appearance != 'dark' && appearance != 'light') {
      throw const FormatException('Appearance must be dark or light');
    }

    if (palette is! Map<String, dynamic>) {
      throw const FormatException('Theme colors must be an object');
    }

    final parsedColors = <String, Color>{};

    for (final key in requiredColors) {
      final value = palette[key];

      if (value is! String) {
        throw FormatException('Missing color: $key');
      }

      parsedColors[key] = parseHexColor(value);
    }

    return KitTheme(
      id: id,
      name: name.trim(),
      author: author.trim(),
      appearance: appearance == 'dark' ? Brightness.dark : Brightness.light,
      colors: parsedColors,
    );
  }

  // ----------------------------------------------------------
  // HEX COLOR SUPPORT
  //
  // #RRGGBB
  // #AARRGGBB
  // ----------------------------------------------------------

  static Color parseHexColor(String source) {
    final valid = RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

    if (!valid.hasMatch(source)) {
      throw FormatException('Invalid color: $source');
    }

    final hex = source.substring(1);
    final number = int.parse(hex, radix: 16);

    if (hex.length == 6) {
      return Color(0xFF000000 | number);
    }

    return Color(number);
  }

  // ----------------------------------------------------------
  // ACCESS A THEME COLOR
  // ----------------------------------------------------------

  Color color(String key) {
    final result = colors[key];

    if (result == null) {
      throw ArgumentError.value(key, 'key', 'Unknown theme color');
    }

    return result;
  }

  // ----------------------------------------------------------
  // CONVERT TO FLUTTER THEME
  // ----------------------------------------------------------

  ThemeData toFlutterTheme() {
    final accent = color('accent');
    final background = color('background');
    final panel = color('panel');
    final primaryText = color('textPrimary');

    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: appearance,
    );

    final scheme = base.copyWith(
      primary: accent,
      onPrimary: background,
      surface: panel,
      onSurface: primaryText,
      error: color('danger'),
      outline: color('border'),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: appearance,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: panel,
      dividerColor: color('border'),
      colorScheme: scheme,
      dialogTheme: DialogThemeData(backgroundColor: panel),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: color('field'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ============================================================
// KITTHEME LIBRARY
//
// Includes:
// - Bundled theme loading
// - User theme loading
// - Selecting a theme
// - Remembering the selection
// - Importing custom .kitth files
// ============================================================

class KitThemeLibrary extends ChangeNotifier {
  KitThemeLibrary({required this.dataDirectory});

  final String dataDirectory;

  static const bundledAssets = <String>[
    'assets/themes/den-mint.kitth',
    'assets/themes/foxfire.kitth',
  ];

  final Map<String, KitTheme> _themes = {};

  KitTheme? _selected;

  KitTheme get current {
    final theme = _selected;

    if (theme == null) {
      throw StateError('Call initialize() before using KitTheme');
    }

    return theme;
  }

  List<KitTheme> get available {
    final list = _themes.values.toList();

    list.sort((a, b) => a.name.compareTo(b.name));

    return List.unmodifiable(list);
  }

  Directory get customThemeDirectory {
    return Directory('$dataDirectory${Platform.pathSeparator}themes');
  }

  File get selectionFile {
    return File(
      '$dataDirectory${Platform.pathSeparator}'
      'selected-theme.json',
    );
  }

  // ----------------------------------------------------------
  // INITIALIZE
  // ----------------------------------------------------------

  Future<void> initialize() async {
    _themes.clear();

    // Load built-in themes from Flutter assets.
    for (final asset in bundledAssets) {
      final source = await rootBundle.loadString(asset);
      final theme = KitTheme.parse(source);

      _themes[theme.id] = theme;
    }

    // Load previously imported user themes.
    await customThemeDirectory.create(recursive: true);

    await for (final entity in customThemeDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.kitth')) {
        continue;
      }

      try {
        if (await entity.length() > 131072) {
          continue;
        }

        final theme = KitTheme.parse(await entity.readAsString());

        // Bundled themes take priority.
        if (_themes.containsKey(theme.id)) {
          continue;
        }

        _themes[theme.id] = theme;
      } catch (_) {
        // One invalid community theme must not
        // prevent KitDen from starting.
        continue;
      }
    }

    final fallback = _themes['den-mint'];

    if (fallback == null) {
      throw StateError('Missing default KitDen theme');
    }

    _selected = fallback;

    // Restore the last selected theme.
    if (await selectionFile.exists()) {
      try {
        final decoded = jsonDecode(await selectionFile.readAsString());

        if (decoded is Map && decoded['themeId'] is String) {
          final previous = decoded['themeId'];

          _selected = _themes[previous] ?? fallback;
        }
      } catch (_) {
        // Corrupted selection file:
        // return to the default theme.
        _selected = fallback;
      }
    }

    notifyListeners();
  }

  // ----------------------------------------------------------
  // SELECT AND SAVE THEME
  // ----------------------------------------------------------

  Future<void> select(String id) async {
    final theme = _themes[id];

    if (theme == null) {
      throw ArgumentError.value(id, 'id', 'Theme not found');
    }

    await selectionFile.parent.create(recursive: true);

    await selectionFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'themeId': id}),
      flush: true,
    );

    _selected = theme;

    notifyListeners();
  }

  // ----------------------------------------------------------
  // IMPORT COMMUNITY THEME
  // ----------------------------------------------------------

  Future<KitTheme> importFile(String sourcePath) async {
    final source = File(sourcePath);

    if (!sourcePath.toLowerCase().endsWith('.kitth')) {
      throw const FormatException('Expected a .kitth file');
    }

    if (!await source.exists()) {
      throw const FileSystemException('Theme file does not exist');
    }

    if (await source.length() > 131072) {
      throw const FormatException('Theme file exceeds 128 KiB');
    }

    final contents = await source.readAsString();

    final theme = KitTheme.parse(contents);

    if (bundledAssets.any((asset) => asset.endsWith('/${theme.id}.kitth'))) {
      throw const FormatException('Cannot replace a built-in theme');
    }

    await customThemeDirectory.create(recursive: true);

    final destination = File(
      '${customThemeDirectory.path}'
      '${Platform.pathSeparator}'
      '${theme.id}.kitth',
    );

    // Save the validated theme into KitDen's local
    // theme directory.
    await destination.writeAsString(contents, flush: true);

    _themes[theme.id] = theme;

    // Activate it immediately.
    await select(theme.id);

    return theme;
  }
}
