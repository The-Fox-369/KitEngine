import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ============================================================
// KitDen + KitTheme .kitth v1
// Complete, self-contained launcher source.
// Uses only file_selector and flutter_svg, which KitDen already has.
// ============================================================

late final KitThemeLibrary kitThemes;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kitThemes = KitThemeLibrary(KitDenStore.dataDirectory);
  await kitThemes.initialize();
  runApp(const KitDenApp());
}

// ============================================================
// KitTheme file format
// A .kitth file contains JSON, not executable Dart code.
// ============================================================

class KitTheme {
  KitTheme({
    required this.id,
    required this.name,
    required this.author,
    required this.brightness,
    required Map<String, Color> colors,
  }) : colors = Map.unmodifiable(colors);

  final String id;
  final String name;
  final String author;
  final Brightness brightness;
  final Map<String, Color> colors;

  static const keys = <String>[
    'background', 'sidebar', 'panel', 'field', 'border',
    'accent', 'accentDim', 'danger',
    'textPrimary', 'textSecondary', 'textMuted',
  ];

  Color get(String key) => colors[key]!;

  static KitTheme parse(String source) {
    if (source.length > 131072) {
      throw const FormatException('Theme exceeds the 128 KiB limit.');
    }
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> ||
        json['format'] != 'kitth' || json['formatVersion'] != 1) {
      throw const FormatException('Unsupported .kitth format or version.');
    }
    final id = json['id'];
    final name = json['name'];
    final author = json['author'];
    final appearance = json['appearance'];
    final rawColors = json['colors'];
    if (id is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$').hasMatch(id) ||
        name is! String || name.trim().isEmpty || name.length > 100 ||
        author is! String || author.trim().isEmpty || author.length > 100 ||
        (appearance != 'dark' && appearance != 'light') ||
        rawColors is! Map<String, dynamic>) {
      throw const FormatException('Invalid KitTheme metadata.');
    }
    final parsed = <String, Color>{};
    for (final key in keys) {
      final text = rawColors[key];
      if (text is! String ||
          !RegExp(r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(text)) {
        throw FormatException('Missing or invalid color: $key');
      }
      final hex = text.substring(1);
      final number = int.parse(hex, radix: 16);
      parsed[key] = Color(hex.length == 6 ? 0xFF000000 | number : number);
    }
    return KitTheme(
      id: id,
      name: name.trim(),
      author: author.trim(),
      brightness: appearance == 'light' ? Brightness.light : Brightness.dark,
      colors: parsed,
    );
  }

  ThemeData toFlutterTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: get('accent'), brightness: brightness,
    );
    final surface = get('panel');
    final background = get('background');
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: get('border'),
      colorScheme: base.copyWith(
        primary: get('accent'),
        onPrimary: background,
        surface: surface,
        onSurface: get('textPrimary'),
        error: get('danger'),
        outline: get('border'),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      snackBarTheme: SnackBarThemeData(backgroundColor: surface),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: get('field'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 16,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ============================================================
// Bundled .kitth presets. Installed as real editable .kitth
// files in the user's local KitDen themes directory on launch.
// ============================================================

const _mintKitth = r'''
{
  "format": "kitth", "formatVersion": 1,
  "id": "den-mint", "name": "Den Mint", "author": "KitEngine",
  "appearance": "dark",
  "colors": {
    "background": "#101418", "sidebar": "#171D23",
    "panel": "#1C242B", "field": "#252F37",
    "border": "#35414A", "accent": "#A5D6C5",
    "accentDim": "#283E3B", "danger": "#FF8088",
    "textPrimary": "#F2F3F0", "textSecondary": "#ABB7BC",
    "textMuted": "#76858C"
  }
}
''';

const _foxfireKitth = r'''
{
  "format": "kitth", "formatVersion": 1,
  "id": "foxfire", "name": "Foxfire", "author": "KitEngine",
  "appearance": "dark",
  "colors": {
    "background": "#171116", "sidebar": "#241A22",
    "panel": "#2D2129", "field": "#3A2B34",
    "border": "#54404A", "accent": "#FFB480",
    "accentDim": "#493025", "danger": "#FF788F",
    "textPrimary": "#FFF3EA", "textSecondary": "#D0B4BF",
    "textMuted": "#997F8E"
  }
}
''';

// ============================================================
// KitTheme library: load, import, reload, select, persist.
// ============================================================

class KitThemeLibrary extends ChangeNotifier {
  KitThemeLibrary(this.dataDirectory);

  final String dataDirectory;
  final Map<String, KitTheme> _themes = {};
  KitTheme? _current;

  Directory get directory => Directory(
    '$dataDirectory${Platform.pathSeparator}themes',
  );
  File get selectedFile => File(
    '$dataDirectory${Platform.pathSeparator}selected-theme.json',
  );

  KitTheme get current => _current!;
  List<KitTheme> get available {
    final list = _themes.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(list);
  }

  Future<void> initialize() async {
    await directory.create(recursive: true);
    for (final entry in {
      'den-mint.kitth': _mintKitth,
      'foxfire.kitth': _foxfireKitth,
    }.entries) {
      final file = File('${directory.path}${Platform.pathSeparator}${entry.key}');
      if (!await file.exists()) {
        await file.writeAsString(entry.value, flush: true);
      }
    }
    await reload();
    if (await selectedFile.exists()) {
      try {
        final saved = jsonDecode(await selectedFile.readAsString());
        if (saved is Map && saved['themeId'] is String) {
          _current = _themes[saved['themeId']] ?? _current;
        }
      } catch (_) {
        // Invalid selection should never prevent startup.
      }
    }
    notifyListeners();
  }

  Future<void> reload() async {
    final chosen = _current?.id;
    _themes.clear();
    // Fallback themes are always available, even if local files break.
    _themes['den-mint'] = KitTheme.parse(_mintKitth);
    _themes['foxfire'] = KitTheme.parse(_foxfireKitth);
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.kitth')) {
        continue;
      }
      try {
        if (await entity.length() > 131072) continue;
        final theme = KitTheme.parse(await entity.readAsString());
        // Only designated preset files may override built-in palettes.
        final filename = entity.uri.pathSegments.last;
        if ((theme.id == 'den-mint' && filename != 'den-mint.kitth') ||
            (theme.id == 'foxfire' && filename != 'foxfire.kitth')) {
          continue;
        }
        _themes[theme.id] = theme;
      } catch (_) {
        // Skip a broken theme rather than crash the launcher.
      }
    }
    _current = _themes[chosen] ?? _themes['foxfire']!;
    notifyListeners();
  }

  Future<void> select(String id) async {
    final selected = _themes[id];
    if (selected == null) throw StateError('Unknown theme: $id');
    await selectedFile.parent.create(recursive: true);
    await selectedFile.writeAsString(jsonEncode({'themeId': id}), flush: true);
    _current = selected;
    notifyListeners();
  }

  Future<KitTheme> importFile(String path) async {
    if (!path.toLowerCase().endsWith('.kitth')) {
      throw const FormatException('Please select a .kitth file.');
    }
    final source = File(path);
    if (await source.length() > 131072) {
      throw const FormatException('Theme exceeds the 128 KiB limit.');
    }
    final content = await source.readAsString();
    final parsed = KitTheme.parse(content);
    if (parsed.id == 'den-mint' || parsed.id == 'foxfire') {
      throw const FormatException('Cannot import over a built-in theme.');
    }
    await directory.create(recursive: true);
    final dest = File('${directory.path}${Platform.pathSeparator}${parsed.id}.kitth');
    await dest.writeAsString(content, flush: true);
    await reload();
    await select(parsed.id);
    return parsed;
  }
}

// ============================================================
// Dynamic UI palette. Unlike const Color values, these switch
// instantly when a different .kitth is selected.
// ============================================================

Color get bg => kitThemes.current.get('background');
Color get sidebarBg => kitThemes.current.get('sidebar');
Color get panelBg => kitThemes.current.get('panel');
Color get fieldBg => kitThemes.current.get('field');
Color get borderColor => kitThemes.current.get('border');
Color get accent => kitThemes.current.get('accent');
Color get accentDim => kitThemes.current.get('accentDim');
Color get danger => kitThemes.current.get('danger');
Color get textPrimary => kitThemes.current.get('textPrimary');
Color get textSecondary => kitThemes.current.get('textSecondary');
Color get textMuted => kitThemes.current.get('textMuted');

class KitDenApp extends StatelessWidget {
  const KitDenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: kitThemes,
      builder: (context, _) => MaterialApp(
        title: 'KitDen',
        debugShowCheckedModeBanner: false,
        theme: kitThemes.current.toFlutterTheme(),
        home: const KitDenHome(),
      ),
    );
  }
}

// ============================================================
// Local project registry and preferences.
// ============================================================

class LocalProject {
  const LocalProject({
    required this.name,
    required this.path,
    required this.addedAt,
  });
  final String name;
  final String path;
  final DateTime addedAt;

  Map<String, dynamic> toJson() => {
    'name': name,
    'path': path,
    'addedAt': addedAt.toIso8601String(),
  };

  factory LocalProject.fromJson(Map<String, dynamic> json) => LocalProject(
    name: json['name'] as String,
    path: json['path'] as String,
    addedAt: DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class KitDenStore {
  static String get dataDirectory {
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData == null || appData.isEmpty) {
        throw const FileSystemException('APPDATA unavailable');
      }
      return '$appData\\KitDen';
    }
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw const FileSystemException('HOME unavailable');
    }
    final xdg = Platform.environment['XDG_DATA_HOME'];
    final root = xdg != null && xdg.isNotEmpty ? xdg : '$home/.local/share';
    return '$root/kitden';
  }

  static String get projectRegistry =>
      '$dataDirectory${Platform.pathSeparator}projects.json';
  static String get preferencesFile =>
      '$dataDirectory${Platform.pathSeparator}preferences.json';

  static Future<List<LocalProject>> loadProjects() async {
    final file = File(projectRegistry);
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString());
    if (data is! List) throw const FormatException('Invalid project registry');
    return data.map((x) => LocalProject.fromJson(Map<String, dynamic>.from(x as Map))).toList();
  }

  static Future<void> saveProjects(List<LocalProject> projects) async {
    final file = File(projectRegistry);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(projects.map((p) => p.toJson()).toList()),
      flush: true,
    );
  }

  static Future<Map<String, dynamic>> loadPreferences() async {
    final file = File(preferencesFile);
    if (!await file.exists()) return {};
    final json = jsonDecode(await file.readAsString());
    if (json is! Map) throw const FormatException('Invalid preferences');
    return Map<String, dynamic>.from(json);
  }

  static Future<void> savePreferences({
    required String displayName,
    required String projectDirectory,
  }) async {
    final file = File(preferencesFile);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'displayName': displayName,
        'projectDirectory': projectDirectory,
      }),
      flush: true,
    );
  }
}

// ============================================================
// SVG nuke: white => danger color, gray => darker danger color.
// ============================================================

class NukeColorMapper extends ColorMapper {
  const NukeColorMapper({required this.primary, required this.shadow});
  final Color primary;
  final Color shadow;

  @override
  Color substitute(String? id, String elementName, String attributeName, Color color) {
    if (color == const Color(0xFFFFFFFF) || color == const Color(0xFF000000)) {
      return primary;
    }
    if (color == const Color(0xFF808080) ||
        color == const Color(0xFF7F7F7F) ||
        color == const Color(0xFF888888)) {
      return shadow;
    }
    return color;
  }

  @override
  bool operator ==(Object other) =>
      other is NukeColorMapper && other.primary == primary && other.shadow == shadow;

  @override
  int get hashCode => Object.hash(primary, shadow);
}

enum DenPage { projects, engines, preferences }

class KitDenHome extends StatefulWidget {
  const KitDenHome({super.key});

  @override
  State<KitDenHome> createState() => _KitDenHomeState();
}

class _KitDenHomeState extends State<KitDenHome> {
  DenPage page = DenPage.projects;
  List<LocalProject> projects = [];
  String displayName = 'User';
  String projectDirectory = '';
  String? hoveredProjectPath;
  bool loading = true;
  bool busy = false;

  String get suggestedProjectDirectory {
    if (Platform.isLinux) {
      final user = Platform.environment['USER'] ?? '';
      final drive = '/run/media/$user/SSD Old';
      for (final candidate in [
        '$drive/Nubaid/Projects/KitEngine', '$drive/Nubaid', drive,
      ]) {
        if (Directory(candidate).existsSync()) return candidate;
      }
    }
    return '';
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    kitThemes.addListener(_themeChanged);
    loadEverything();
  }

  @override
  void dispose() {
    kitThemes.removeListener(_themeChanged);
    super.dispose();
  }

  void _themeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> loadEverything() async {
    try {
      final savedProjects = await KitDenStore.loadProjects();
      final preferences = await KitDenStore.loadPreferences();
      if (!mounted) return;
      setState(() {
        projects = savedProjects;
        final name = preferences['displayName'];
        final path = preferences['projectDirectory'];
        displayName = name is String && name.trim().isNotEmpty ? name : 'User';
        projectDirectory = path is String && path.isNotEmpty
            ? path : suggestedProjectDirectory;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        projectDirectory = suggestedProjectDirectory;
      });
      notify('Could not load local data: $error', error: true);
    }
  }

  void notify(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? danger.withValues(alpha: 0.75) : panelBg,
      ),
    );
  }

  Future<void> savePreferences() => KitDenStore.savePreferences(
    displayName: displayName,
    projectDirectory: projectDirectory,
  );

  // ----------------------------------------------------------
  // Native folder and .kitth file pickers.
  // ----------------------------------------------------------

  Future<String?> pickFolder({
    String? initialDirectory,
    String buttonLabel = 'Choose folder',
  }) async {
    var initial = initialDirectory;
    if (initial == null || !Directory(initial).existsSync()) {
      final preferred = suggestedProjectDirectory;
      initial = preferred.isNotEmpty
          ? preferred : Platform.environment['HOME'];
    }
    try {
      return await getDirectoryPath(
        initialDirectory: initial,
        confirmButtonText: buttonLabel,
      );
    } catch (error) {
      notify('Folder picker failed: $error', error: true);
      return null;
    }
  }

  Future<void> importTheme() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'KitTheme theme files',
        extensions: ['kitth'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;
      final imported = await kitThemes.importFile(file.path);
      notify('Imported and activated "${imported.name}".');
    } catch (error) {
      notify('Theme import failed: $error', error: true);
    }
  }

  Future<void> openPath(String path) async {
    try {
      if (!await Directory(path).exists()) {
        notify('Folder is missing.', error: true);
        return;
      }
      final executable = Platform.isWindows
          ? 'explorer.exe' : Platform.isMacOS ? 'open' : 'xdg-open';
      await Process.start(executable, [path], mode: ProcessStartMode.detached);
    } catch (error) {
      notify('Could not open folder: $error', error: true);
    }
  }

  // ----------------------------------------------------------
  // Create a KitEngine project.
  // ----------------------------------------------------------

  Future<void> showCreateProject() async {
    final controller = TextEditingController();
    var selectedParent = projectDirectory;
    final result = await showDialog<({String name, String parent})>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Create a project'),
          content: SizedBox(
            width: 490,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Every great game starts somewhere.',
                    style: TextStyle(color: textSecondary)),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Project name', hintText: 'My Awesome Game',
                  ),
                ),
                const SizedBox(height: 22),
                Text('PROJECT LOCATION', style: TextStyle(
                  color: textSecondary, fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 1.3,
                )),
                const SizedBox(height: 10),
                folderPreview(selectedParent.isEmpty
                    ? 'Choose a folder' : selectedParent),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final chosen = await pickFolder(
                      initialDirectory: selectedParent,
                      buttonLabel: 'Use this folder',
                    );
                    if (chosen != null && dialogContext.mounted) {
                      updateDialog(() => selectedParent = chosen);
                    }
                  },
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Browse...'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedParent.isEmpty ? null : () {
                Navigator.pop(dialogContext, (
                  name: controller.text.trim(), parent: selectedParent,
                ));
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (result != null) await createProject(result.name, result.parent);
  }

  Future<void> createProject(String name, String parentPath) async {
    if (busy) return;
    if (name.isEmpty || name.length > 80 || name == '.' || name == '..' ||
        name.endsWith('.') || name.endsWith(' ') ||
        RegExp(r'[<>:"/\\|?*]').hasMatch(name)) {
      notify('Invalid project name.', error: true);
      return;
    }
    final parent = Directory(parentPath);
    if (!parent.isAbsolute || !await parent.exists()) {
      notify('Choose an existing parent directory.', error: true);
      return;
    }
    final directory = Directory('$parentPath${Platform.pathSeparator}$name');
    if (await FileSystemEntity.type(directory.path, followLinks: false) !=
        FileSystemEntityType.notFound) {
      notify('That project path already exists.', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      await directory.create();
      final created = DateTime.now().toUtc();
      final manifest = File(
        '${directory.path}${Platform.pathSeparator}kitengine.project.json',
      );
      await manifest.writeAsString(const JsonEncoder.withIndent('  ').convert({
        'formatVersion': 1,
        'id': 'kit-${created.microsecondsSinceEpoch}',
        'name': name,
        'engineVersion': null,
        'createdAt': created.toIso8601String(),
      }));
      for (final folder in ['assets', 'scenes', 'scripts']) {
        await Directory('${directory.path}${Platform.pathSeparator}$folder')
            .create();
      }
      final updated = [
        LocalProject(
          name: name, path: directory.absolute.path, addedAt: created,
        ),
        ...projects,
      ];
      await KitDenStore.saveProjects(updated);
      if (!mounted) return;
      setState(() => projects = updated);
      notify('Project "$name" created.');
    } catch (error) {
      notify('Could not create project: $error', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ----------------------------------------------------------
  // Import an existing KitEngine project.
  // ----------------------------------------------------------

  Future<void> importProject() async {
    final chosen = await pickFolder(
      initialDirectory: projectDirectory,
      buttonLabel: 'Import project',
    );
    if (chosen == null) return;
    try {
      final directory = Directory(chosen);
      final manifest = File(
        '$chosen${Platform.pathSeparator}kitengine.project.json',
      );
      if (!await manifest.exists()) {
        notify('Not a KitEngine project.', error: true);
        return;
      }
      final data = jsonDecode(await manifest.readAsString());
      if (data is! Map || data['name'] is! String ||
          (data['name'] as String).trim().isEmpty) {
        throw const FormatException('Invalid project manifest.');
      }
      final project = LocalProject(
        name: data['name'] as String,
        path: directory.absolute.path,
        addedAt: DateTime.now(),
      );
      final updated = [
        project,
        ...projects.where((p) => p.path != project.path),
      ];
      await KitDenStore.saveProjects(updated);
      if (!mounted) return;
      setState(() => projects = updated);
      notify('Project imported.');
    } catch (error) {
      notify('Import failed: $error', error: true);
    }
  }

  // ----------------------------------------------------------
  // Forget a project. Does NOT delete its files.
  // ----------------------------------------------------------

  Future<void> removeProject(LocalProject project) async {
    if (busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove project from KitDen?'),
        content: Text('"${project.name}" will disappear from your list.\n\n'
            'Its files will remain untouched.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final updated = projects.where((p) => p.path != project.path).toList();
    try {
      await KitDenStore.saveProjects(updated);
      if (!mounted) return;
      setState(() => projects = updated);
    } catch (error) {
      notify('Could not remove project: $error', error: true);
    }
  }

  // ----------------------------------------------------------
  // Nuke: normal click asks; Ctrl+click skips confirmation.
  // Permanent deletion ONLY after safety checks.
  // ----------------------------------------------------------

  Future<void> nukeProject(LocalProject project, {
    required bool skipConfirmation,
  }) async {
    if (busy) return;
    if (!skipConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: danger),
            const SizedBox(width: 12),
            const Text('Nuke this project?'),
          ]),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PERMANENTLY delete "${project.name}"?',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Everything inside this folder will be deleted:'),
                const SizedBox(height: 12),
                SelectableText(project.path,
                    style: TextStyle(color: danger, fontSize: 12)),
                const SizedBox(height: 18),
                Text('This does not move files to Trash. There is no undo.',
                    style: TextStyle(color: textSecondary)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: danger, foregroundColor: bg,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Nuke Project'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      if (!projects.any((p) => p.path == project.path)) {
        throw const FileSystemException('Project is no longer registered.');
      }
      final directory = Directory(project.path);
      final type = await FileSystemEntity.type(
        directory.path, followLinks: false,
      );
      if (type != FileSystemEntityType.directory) {
        throw const FileSystemException('Project is missing or a symlink.');
      }
      final resolved = await directory.resolveSymbolicLinks();
      final separator = Platform.pathSeparator;
      final parts = resolved.split(separator)
          .where((x) => x.isNotEmpty).toList();
      if (parts.length < 3) {
        throw const FileSystemException('Refusing to delete a root folder.');
      }
      final home = Platform.environment['HOME'];
      final username = Platform.environment['USER'];
      final protected = <String>{
        '/', '/home', '/root', '/usr', '/opt', '/mnt', '/media',
        '/run', '/run/media',
        if (home != null) home,
        if (username != null) '/run/media/$username',
        if (username != null) '/run/media/$username/SSD Old',
        if (username != null) '/run/media/$username/SSD Old/Nubaid',
      };
      if (protected.contains(resolved)) {
        throw const FileSystemException('That folder is protected.');
      }
      final cwd = await Directory.current.resolveSymbolicLinks();
      if (cwd == resolved || cwd.startsWith('$resolved$separator')) {
        throw const FileSystemException('Cannot delete a running workspace.');
      }
      final manifest = File('$resolved${separator}kitengine.project.json');
      if (!await manifest.exists()) {
        throw const FileSystemException('KitEngine manifest not found.');
      }
      final data = jsonDecode(await manifest.readAsString());
      if (data is! Map || data['formatVersion'] != 1 ||
          data['id'] is! String || data['name'] != project.name) {
        throw const FormatException('Selected project does not match its manifest.');
      }
      for (final other in projects) {
        if (other.path == project.path) continue;
        final otherDirectory = Directory(other.path);
        if (!await otherDirectory.exists()) continue;
        final otherPath = await otherDirectory.resolveSymbolicLinks();
        if (otherPath == resolved || otherPath.startsWith('$resolved$separator')) {
          throw const FileSystemException(
            'Cannot nuke a folder containing another registered project.',
          );
        }
      }
      // This is the irreversible operation. Ctrl only skips the dialog.
      await directory.delete(recursive: true);
      final updated = projects.where((p) => p.path != project.path).toList();
      try {
        await KitDenStore.saveProjects(updated);
        if (!mounted) return;
        setState(() {
          projects = updated;
          hoveredProjectPath = null;
        });
        notify('Project "${project.name}" nuked.');
      } catch (error) {
        notify('Files deleted, but registry update failed: $error', error: true);
      }
    } catch (error) {
      notify('Nuke failed: $error', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ----------------------------------------------------------
  // Profile and default projects directory.
  // ----------------------------------------------------------

  Future<void> editDisplayName() async {
    final controller = TextEditingController(
      text: displayName == 'User' ? '' : displayName,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your display name'),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller, autofocus: true, maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Display name', hintText: 'The Fox 369',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    final previous = displayName;
    setState(() => displayName = result.isEmpty ? 'User' : result);
    try {
      await savePreferences();
    } catch (error) {
      if (mounted) setState(() => displayName = previous);
      notify('Could not save display name: $error', error: true);
    }
  }

  Future<void> changeProjectDirectory() async {
    final chosen = await pickFolder(
      initialDirectory: projectDirectory,
      buttonLabel: 'Set project location',
    );
    if (chosen == null) return;
    final previous = projectDirectory;
    setState(() => projectDirectory = chosen);
    try {
      await savePreferences();
      notify('Default project location saved.');
    } catch (error) {
      if (mounted) setState(() => projectDirectory = previous);
      notify('Could not save location: $error', error: true);
    }
  }

  // ============================================================
  // Layout
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        return Scaffold(
          body: Row(children: [
            if (wide) buildSidebar(),
            Expanded(child: Column(children: [
              buildTopbar(),
              Expanded(child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 36 : 20),
                child: Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: switch (page) {
                    DenPage.projects => projectsPage(),
                    DenPage.engines => enginesPage(),
                    DenPage.preferences => preferencesPage(),
                  },
                )),
              )),
            ])),
          ]),
          bottomNavigationBar: wide ? null : NavigationBar(
            selectedIndex: page.index,
            onDestinationSelected: (index) => setState(() {
              page = DenPage.values[index];
            }),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Projects'),
              NavigationDestination(icon: Icon(Icons.layers_outlined), label: 'Engines'),
              NavigationDestination(icon: Icon(Icons.tune_rounded), label: 'Preferences'),
            ],
          ),
        );
      },
    );
  }

  Widget buildSidebar() {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
      decoration: BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Icon(Icons.hexagon_outlined, color: accent, size: 32),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('KitDen', style: TextStyle(
                  color: textPrimary, fontWeight: FontWeight.w800,
                  fontSize: 25, letterSpacing: -0.8,
                )),
                Text('DEVELOPMENT HUB', style: TextStyle(
                  color: textMuted, fontSize: 10, letterSpacing: 1.4,
                )),
              ]),
            ]),
          ),
          const SizedBox(height: 45),
          _sidebarCaption('WORKSPACE'),
          navItem(DenPage.projects, Icons.folder_outlined, 'My Projects'),
          const SizedBox(height: 7),
          navItem(DenPage.engines, Icons.layers_outlined, 'Engine Versions'),
          const SizedBox(height: 32),
          _sidebarCaption('APPLICATION'),
          navItem(DenPage.preferences, Icons.tune_outlined, 'Preferences'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panelBg, borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderColor),
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 21, backgroundColor: fieldBg,
                child: Icon(Icons.person_outline_rounded, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Local profile', style: TextStyle(
                    color: textMuted, fontSize: 11,
                  )),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 14),
          Center(child: Text('KitDen • Early Development',
            style: TextStyle(color: textMuted, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _sidebarCaption(String text) => Padding(
    padding: const EdgeInsets.only(left: 13, bottom: 14),
    child: Text(text, style: TextStyle(
      color: textMuted, fontSize: 11, letterSpacing: 1.6,
      fontWeight: FontWeight.bold,
    )),
  );

  Widget navItem(DenPage target, IconData icon, String title) {
    final selected = page == target;
    return Material(
      color: selected ? accentDim : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => page = target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          child: Row(children: [
            Icon(icon, color: selected ? accent : textMuted, size: 21),
            const SizedBox(width: 13),
            Text(title, style: TextStyle(
              color: selected ? textPrimary : textSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }

  Widget buildTopbar() => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 30),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: borderColor)),
    ),
    child: Row(children: [
      Icon(Icons.circle, size: 8, color: accent),
      const SizedBox(width: 9),
      Text('LOCAL WORKSPACE', style: TextStyle(
        color: textSecondary, fontSize: 11, letterSpacing: 1.5,
      )),
      const Spacer(),
      Text('KitDen Preview', style: TextStyle(
        color: textMuted, fontSize: 12,
      )),
    ]),
  );

  Widget pageHeading(String label, String title, String description) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: TextStyle(
        color: accent, fontSize: 12,
        fontWeight: FontWeight.bold, letterSpacing: 1.6,
      )),
      const SizedBox(height: 13),
      Text(title, style: TextStyle(
        fontSize: 32, height: 1.2, fontWeight: FontWeight.w800,
        color: textPrimary, letterSpacing: -0.8,
      )),
      const SizedBox(height: 12),
      Text(description, style: TextStyle(color: textSecondary, fontSize: 15)),
    ]);
  }

  Widget panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: panelBg,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );

  Widget folderPreview(String path) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: fieldBg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: borderColor),
    ),
    child: Row(children: [
      Icon(Icons.folder_outlined, color: accent, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(path, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12))),
    ]),
  );

  Widget settingCard({
    required IconData icon,
    required String heading,
    required String description,
    required Widget content,
  }) => panel(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Container(
          width: 43, height: 43,
          decoration: BoxDecoration(
            color: accentDim, borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent),
        ),
        const SizedBox(width: 15),
        Expanded(child: Text(heading, style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold,
        ))),
      ]),
      const SizedBox(height: 17),
      Text(description, style: TextStyle(color: textSecondary, height: 1.5)),
      const SizedBox(height: 22),
      content,
    ],
  ));

  // ============================================================
  // My Projects screen
  // ============================================================

  Widget projectsPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      pageHeading('Welcome to the den',
        '$greeting, $displayName.', 'Ready to make something?'),
      const SizedBox(height: 35),
      panel(child: Wrap(
        spacing: 14, runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: busy ? null : showCreateProject,
            icon: const Icon(Icons.add), label: const Text('New Project'),
            style: FilledButton.styleFrom(
              backgroundColor: accent, foregroundColor: bg,
              padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 18),
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : importProject,
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Import Project'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 18),
            ),
          ),
        ],
      )),
      const SizedBox(height: 36),
      Row(children: [
        const Text('Recent Projects', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold,
        )),
        const SizedBox(width: 12),
        Text('${projects.length}', style: TextStyle(color: accent, fontSize: 18)),
      ]),
      const SizedBox(height: 18),
      if (loading)
        const Center(child: CircularProgressIndicator())
      else if (projects.isEmpty)
        panel(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 65),
          child: Column(children: [
            Icon(Icons.folder_copy_outlined, size: 56, color: textMuted),
            const SizedBox(height: 20),
            const Text('Your workspace is empty.', style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.bold,
            )),
            const SizedBox(height: 10),
            Text('Start a project or import an existing one.',
              style: TextStyle(color: textSecondary), textAlign: TextAlign.center),
          ]),
        )
      else
        ...projects.map(projectTile),
      const SizedBox(height: 26),
      Text('KitEngine itself is still under development. '
        'Projects can be organized here, but the engine editor is not available yet.',
        style: TextStyle(color: textMuted, fontSize: 12, height: 1.5)),
    ],
  );

  // Nuke only appears when the pointer hovers this project row.
  Widget projectTile(LocalProject project) {
    final hovered = hoveredProjectPath == project.path;
    return MouseRegion(
      onEnter: (_) => setState(() => hoveredProjectPath = project.path),
      onExit: (_) {
        if (hoveredProjectPath == project.path) {
          setState(() => hoveredProjectPath = null);
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: panel(child: LayoutBuilder(
          builder: (context, constraints) {
            final info = Row(children: [
              Icon(Icons.folder_outlined, color: accent, size: 31),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.name, style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 6),
                  Text(project.path, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 12)),
                ],
              )),
            ]);
            final actions = Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton.icon(
                onPressed: () => openPath(project.path),
                icon: const Icon(Icons.folder_open_outlined, size: 17),
                label: const Text('Open Folder'),
              ),
              const SizedBox(width: 6),
              if (hovered)
                IconButton(
                  tooltip: 'Nuke project (Ctrl+click: instant)',
                  onPressed: busy ? null : () => nukeProject(
                    project,
                    skipConfirmation: HardwareKeyboard.instance.isControlPressed,
                  ),
                  icon: SvgPicture.asset(
                    'assets/icons/nuke.svg',
                    width: 23, height: 23,
                    colorMapper: NukeColorMapper(
                      primary: danger,
                      shadow: Color.lerp(danger, Colors.black, 0.35)!,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Remove from list only',
                onPressed: busy ? null : () => removeProject(project),
                icon: const Icon(Icons.close_rounded),
              ),
            ]);
            if (constraints.maxWidth < 650) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 18), actions],
              );
            }
            return Row(children: [
              Expanded(child: info),
              const SizedBox(width: 20),
              actions,
            ]);
          },
        )),
      ),
    );
  }

  // ============================================================
  // Engine Versions placeholder
  // ============================================================

  Widget enginesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      pageHeading('Engine Management', 'Your engine versions.',
          'Manage KitEngine installations in one place.'),
      const SizedBox(height: 34),
      panel(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.layers_clear_outlined, size: 42, color: textMuted),
          const SizedBox(height: 20),
          const Text('No engine builds installed.', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold,
          )),
          const SizedBox(height: 12),
          Text('KitEngine has not reached its first usable engine build yet. '
              'Engine version management is planned for a later milestone.',
              style: TextStyle(color: textSecondary, height: 1.5)),
        ],
      )),
    ],
  );

  // ============================================================
  // Preferences, including the REAL KitTheme selector
  // ============================================================

  Widget preferencesPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      pageHeading('Application', 'Preferences',
          'Make KitDen work the way you like.'),
      const SizedBox(height: 32),
      settingCard(
        icon: Icons.person_outline_rounded,
        heading: 'Your Profile',
        description: 'Personalize your local KitDen experience. '
            'This does not create an online account.',
        content: Row(children: [
          CircleAvatar(
            radius: 28, backgroundColor: fieldBg,
            child: Icon(Icons.person_outline_rounded, color: accent, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold,
              )),
              const SizedBox(height: 5),
              Text('Profile picture coming later', style: TextStyle(
                color: textMuted, fontSize: 12,
              )),
            ],
          )),
          OutlinedButton(
            onPressed: editDisplayName, child: const Text('Edit Name'),
          ),
        ]),
      ),
      const SizedBox(height: 20),
      settingCard(
        icon: Icons.folder_outlined,
        heading: 'Project Storage',
        description: 'Choose where new KitEngine projects are created. '
            'Existing projects are not moved.',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            folderPreview(projectDirectory.isEmpty
                ? 'No location selected' : projectDirectory),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: changeProjectDirectory,
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Change Location'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      settingCard(
        icon: Icons.palette_outlined,
        heading: 'KitTheme (.kitth)',
        description: 'Switch themes instantly, import themes from other '
            'creators, or edit .kitth files in your local themes folder.',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: kitThemes.current.id,
              decoration: const InputDecoration(labelText: 'Active theme'),
              items: kitThemes.available.map((theme) => DropdownMenuItem(
                value: theme.id,
                child: Text('${theme.name} — ${theme.author}'),
              )).toList(),
              onChanged: (id) async {
                if (id == null) return;
                try {
                  await kitThemes.select(id);
                } catch (error) {
                  notify('Theme change failed: $error', error: true);
                }
              },
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: importTheme,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import .kitth'),
              ),
              OutlinedButton.icon(
                onPressed: () => openPath(kitThemes.directory.path),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open Themes Folder'),
              ),
              TextButton.icon(
                onPressed: () async {
                  try {
                    await kitThemes.reload();
                    notify('Themes reloaded.');
                  } catch (error) {
                    notify('Could not reload themes: $error', error: true);
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reload'),
              ),
            ]),
            const SizedBox(height: 16),
            Text('Current palette', style: TextStyle(color: textSecondary)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final name in KitTheme.keys)
                Tooltip(
                  message: '$name: ${kitThemes.current.get(name)}',
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: kitThemes.current.get(name),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: borderColor),
                    ),
                  ),
                ),
            ]),
          ],
        ),
      ),
      const SizedBox(height: 20),
      settingCard(
        icon: Icons.storage_outlined,
        heading: 'Application Data',
        description: 'KitDen keeps a small local project registry so your '
            'projects appear after restarting.',
        content: SelectableText(KitDenStore.projectRegistry,
          style: TextStyle(color: textSecondary, fontSize: 13)),
      ),
      const SizedBox(height: 20),
      settingCard(
        icon: Icons.cloud_off_outlined,
        heading: 'Cloud & Accounts',
        description: 'KitDen works entirely offline. Optional cloud accounts '
            'and backups may be added later, but local development will '
            'never require signing in.',
        content: Row(children: [
          Icon(Icons.check_circle_outline, color: accent, size: 19),
          const SizedBox(width: 10),
          Text('Local mode enabled', style: TextStyle(
            color: accent, fontWeight: FontWeight.bold,
          )),
        ]),
      ),
    ],
  );
}
