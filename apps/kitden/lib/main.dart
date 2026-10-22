import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KitDenApp());
}

// ============================================================
// KITDEN — DESIGN SYSTEM
// ============================================================

const bg = Color(0xFF101418);
const sidebarBg = Color(0xFF171D23);
const panelBg = Color(0xFF1C242B);
const fieldBg = Color(0xFF252F37);
const borderColor = Color(0xFF35414A);

const accent = Color(0xFFA5D6C5);
const accentDim = Color(0xFF283E3B);
const danger = Color(0xFFFF8088);

const textPrimary = Color(0xFFF2F3F0);
const textSecondary = Color(0xFFABB7BC);
const textMuted = Color(0xFF76858C);

// ============================================================
// APPLICATION
// ============================================================

class KitDenApp extends StatelessWidget {
  const KitDenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KitDen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          error: danger,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: fieldBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const KitDenHome(),
    );
  }
}

// ============================================================
// PROJECT DATA
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

  factory LocalProject.fromJson(Map<String, dynamic> json) {
    return LocalProject(
      name: json['name'] as String,
      path: json['path'] as String,
      addedAt:
          DateTime.tryParse(json['addedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ============================================================
// LOCAL STORAGE
// ============================================================

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

    if (data is! List) {
      throw const FormatException('Invalid project registry');
    }

    return data
        .map(
          (item) =>
              LocalProject.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static Future<void> saveProjects(List<LocalProject> projects) async {
    final file = File(projectRegistry);

    await file.parent.create(recursive: true);

    await file.writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert(projects.map((p) => p.toJson()).toList()),
      flush: true,
    );
  }

  static Future<Map<String, dynamic>> loadPreferences() async {
    final file = File(preferencesFile);

    if (!await file.exists()) return {};

    final data = jsonDecode(await file.readAsString());

    if (data is! Map) {
      throw const FormatException('Invalid preferences');
    }

    return Map<String, dynamic>.from(data);
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
// THEME-AWARE TWO-TONE NUKE SVG
//
// For a white outer shape and #808080 interior:
//   White  -> destructive primary color
//   Gray   -> darker destructive color
//
// Also handles a black outer shape.
//
// NO colorFilter here. A single colorFilter would flatten
// the shading.
// ============================================================

class NukeColorMapper extends ColorMapper {
  const NukeColorMapper({required this.primary, required this.shadow});

  final Color primary;
  final Color shadow;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    // White or black outer shape.
    if (color == const Color(0xFFFFFFFF) || color == const Color(0xFF000000)) {
      return primary;
    }

    // Interior shading from the exported SVG.
    if (color == const Color(0xFF808080) ||
        color == const Color(0xFF7F7F7F) ||
        color == const Color(0xFF888888)) {
      return shadow;
    }

    // Preserve any other colors.
    return color;
  }

  @override
  bool operator ==(Object other) {
    return other is NukeColorMapper &&
        other.primary == primary &&
        other.shadow == shadow;
  }

  @override
  int get hashCode => Object.hash(primary, shadow);
}

// ============================================================
// NAVIGATION
// ============================================================

enum DenPage { projects, engines, preferences }

// ============================================================
// MAIN WINDOW
// ============================================================

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

  // ----------------------------------------------------------
  // DEFAULT DATA-DRIVE LOCATION
  // ----------------------------------------------------------

  String get suggestedProjectDirectory {
    if (Platform.isLinux) {
      final user = Platform.environment['USER'] ?? '';

      final drive = '/run/media/$user/SSD Old';
      final preferred = '$drive/Nubaid/Projects/KitEngine';
      final fallback = '$drive/Nubaid';

      if (Directory(preferred).existsSync()) {
        return preferred;
      }

      if (Directory(fallback).existsSync()) {
        return fallback;
      }

      if (Directory(drive).existsSync()) {
        return drive;
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

  // ----------------------------------------------------------
  // INITIALIZATION
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    loadEverything();
  }

  Future<void> loadEverything() async {
    try {
      final savedProjects = await KitDenStore.loadProjects();
      final prefs = await KitDenStore.loadPreferences();

      if (!mounted) return;

      final savedName = prefs['displayName'];
      final savedPath = prefs['projectDirectory'];

      setState(() {
        projects = savedProjects;

        displayName = savedName is String && savedName.trim().isNotEmpty
            ? savedName
            : 'User';

        projectDirectory = savedPath is String && savedPath.isNotEmpty
            ? savedPath
            : suggestedProjectDirectory;

        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        projectDirectory = suggestedProjectDirectory;
        loading = false;
      });

      notify('Could not load local data: $error', error: true);
    }
  }

  void notify(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFF883F48) : panelBg,
      ),
    );
  }

  Future<void> savePreferences() {
    return KitDenStore.savePreferences(
      displayName: displayName,
      projectDirectory: projectDirectory,
    );
  }

  // ==========================================================
  // NATIVE FOLDER PICKER
  // ==========================================================

  Future<String?> pickFolder({
    String? initialDirectory,
    String buttonLabel = 'Choose folder',
  }) async {
    String? initial = initialDirectory;

    if (initial == null || !Directory(initial).existsSync()) {
      final fallback = suggestedProjectDirectory;

      if (fallback.isNotEmpty && Directory(fallback).existsSync()) {
        initial = fallback;
      } else {
        initial = Platform.environment['HOME'];
      }
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

  // ==========================================================
  // CREATE PROJECT
  // ==========================================================

  Future<void> showCreateProject() async {
    final controller = TextEditingController();

    String selectedParent = projectDirectory;

    final result = await showDialog<({String name, String parent})>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, updateDialog) {
            return AlertDialog(
              title: const Text('Create a project'),
              content: SizedBox(
                width: 490,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Every great game starts somewhere.',
                      style: TextStyle(color: textSecondary),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Project name',
                        hintText: 'My Awesome Game',
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'PROJECT LOCATION',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    folderPreview(
                      selectedParent.isEmpty
                          ? 'Choose a folder'
                          : selectedParent,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final chosen = await pickFolder(
                          initialDirectory: selectedParent,
                          buttonLabel: 'Use this folder',
                        );

                        if (chosen == null || !dialogContext.mounted) {
                          return;
                        }

                        updateDialog(() {
                          selectedParent = chosen;
                        });
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
                  onPressed: selectedParent.isEmpty
                      ? null
                      : () {
                          Navigator.pop(dialogContext, (
                            name: controller.text.trim(),
                            parent: selectedParent,
                          ));
                        },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (result == null) return;

    await createProject(result.name, result.parent);
  }

  Widget folderPreview(String path) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              path,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> createProject(String name, String parentPath) async {
    if (busy) return;

    if (name.trim().isEmpty ||
        name.length > 80 ||
        name == '.' ||
        name == '..' ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        RegExp(r'[<>:"/\\|?*]').hasMatch(name)) {
      notify('Invalid project name.', error: true);
      return;
    }

    final parent = Directory(parentPath);

    if (!parent.isAbsolute || !await parent.exists()) {
      notify('Select an existing parent directory.', error: true);
      return;
    }

    final separator = Platform.pathSeparator;
    final directory = Directory('$parentPath$separator$name');

    if (await directory.exists()) {
      notify('That folder already exists. Import it instead.', error: true);
      return;
    }

    setState(() => busy = true);

    try {
      await directory.create();

      final created = DateTime.now().toUtc();

      final manifest = File(
        '${directory.path}${separator}kitengine.project.json',
      );

      await manifest.writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'formatVersion': 1,
          'id': 'kit-${created.microsecondsSinceEpoch}',
          'name': name,
          'engineVersion': null,
          'createdAt': created.toIso8601String(),
        }),
      );

      for (final folder in ['assets', 'scenes', 'scripts']) {
        await Directory('${directory.path}$separator$folder').create();
      }

      final updated = [
        LocalProject(
          name: name,
          path: directory.absolute.path,
          addedAt: created,
        ),
        ...projects,
      ];

      await KitDenStore.saveProjects(updated);

      if (!mounted) return;

      setState(() {
        projects = updated;
      });

      notify('Project "$name" created successfully.');
    } catch (error) {
      notify('Could not create project: $error', error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // ==========================================================
  // IMPORT PROJECT
  // ==========================================================

  Future<void> importProject() async {
    final chosen = await pickFolder(
      initialDirectory: projectDirectory,
      buttonLabel: 'Import project',
    );

    if (chosen == null) return;

    try {
      final manifest = File(
        '$chosen${Platform.pathSeparator}kitengine.project.json',
      );

      if (!await manifest.exists()) {
        notify('This folder is not a KitEngine project.', error: true);
        return;
      }

      final data = jsonDecode(await manifest.readAsString());

      if (data is! Map ||
          data['name'] is! String ||
          (data['name'] as String).trim().isEmpty) {
        throw const FormatException('Invalid KitEngine project manifest');
      }

      final project = LocalProject(
        name: data['name'] as String,
        path: Directory(chosen).absolute.path,
        addedAt: DateTime.now(),
      );

      final updated = [
        project,
        ...projects.where((p) => p.path != project.path),
      ];

      await KitDenStore.saveProjects(updated);

      if (!mounted) return;

      setState(() {
        projects = updated;
      });

      notify('Project imported.');
    } catch (error) {
      notify('Import failed: $error', error: true);
    }
  }

  // ==========================================================
  // OPEN PROJECT FOLDER
  // ==========================================================

  Future<void> openFolder(LocalProject project) async {
    try {
      if (!await Directory(project.path).exists()) {
        notify('Project folder is missing.', error: true);
        return;
      }

      final executable = Platform.isWindows
          ? 'explorer.exe'
          : Platform.isMacOS
          ? 'open'
          : 'xdg-open';

      await Process.start(executable, [
        project.path,
      ], mode: ProcessStartMode.detached);
    } catch (error) {
      notify('Could not open folder: $error', error: true);
    }
  }

  // ==========================================================
  // REMOVE PROJECT FROM LIST
  // FILES ARE NOT DELETED.
  // ==========================================================

  Future<void> removeProject(LocalProject project) async {
    if (busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove project from KitDen?'),
        content: Text(
          '"${project.name}" will be removed from your '
          'project list.\n\n'
          'Its files will remain untouched.',
        ),
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

      setState(() {
        projects = updated;
      });
    } catch (error) {
      notify('Could not remove project: $error', error: true);
    }
  }

  // ==========================================================
  // PROJECT NUKE
  //
  // Normal click:
  //   Show confirmation.
  //
  // Ctrl + click:
  //   Skip confirmation.
  //
  // Safety validation ALWAYS runs, even with Ctrl.
  // Only the selected project folder may be deleted.
  // ==========================================================

  Future<void> nukeProject(
    LocalProject project, {
    required bool skipConfirmation,
  }) async {
    if (busy) return;

    if (!skipConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: danger),
                SizedBox(width: 12),
                Text('Nuke this project?'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will PERMANENTLY delete '
                    '"${project.name}".',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Everything inside this project folder '
                    'will be deleted:',
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    project.path,
                    style: const TextStyle(color: danger, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'This does not move files to Trash. '
                    'There is no undo.',
                    style: TextStyle(color: textSecondary),
                  ),
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
                  backgroundColor: danger,
                  foregroundColor: bg,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Nuke Project'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    }

    if (!mounted) return;

    setState(() => busy = true);

    try {
      // Must be present in the current registry.
      if (!projects.any((p) => p.path == project.path)) {
        throw const FileSystemException('Project is no longer registered');
      }

      final directory = Directory(project.path);

      // Never delete a symlink masquerading as a project.
      final type = await FileSystemEntity.type(
        directory.path,
        followLinks: false,
      );

      if (type != FileSystemEntityType.directory) {
        throw const FileSystemException(
          'Project directory is missing or is a link',
        );
      }

      final resolved = await directory.resolveSymbolicLinks();

      final separator = Platform.pathSeparator;

      // Refuse roots and very shallow paths.
      final segments = resolved
          .split(separator)
          .where((part) => part.isNotEmpty)
          .toList();

      if (segments.length < 3) {
        throw const FileSystemException(
          'Refusing to delete a top-level directory',
        );
      }

      final home = Platform.environment['HOME'];
      final username = Platform.environment['USER'];

      final protectedPaths = <String>{
        separator,
        '/home',
        '/root',
        '/usr',
        '/opt',
        '/mnt',
        '/media',
        '/run',
        '/run/media',
        if (home != null) home,
        if (username != null) '/run/media/$username',
        if (username != null) '/run/media/$username/SSD Old',
        if (username != null) '/run/media/$username/SSD Old/Nubaid',
      };

      if (protectedPaths.contains(resolved)) {
        throw const FileSystemException('This directory is protected');
      }

      // Never nuke the current source/build workspace
      // or a parent directory containing it.
      final workingDirectory = await Directory.current.resolveSymbolicLinks();

      if (workingDirectory == resolved ||
          workingDirectory.startsWith('$resolved$separator')) {
        throw const FileSystemException(
          'Cannot nuke the running KitDen workspace',
        );
      }

      // Must contain an actual KitEngine project manifest.
      final manifest = File('$resolved${separator}kitengine.project.json');

      if (!await manifest.exists()) {
        throw const FileSystemException('Project manifest not found');
      }

      final data = jsonDecode(await manifest.readAsString());

      if (data is! Map ||
          data['formatVersion'] != 1 ||
          data['id'] is! String ||
          data['name'] is! String ||
          data['name'] != project.name) {
        throw const FormatException(
          'Project manifest does not match '
          'the selected project',
        );
      }

      // Refuse a project folder containing another
      // separately registered project.
      for (final other in projects) {
        if (other.path == project.path) continue;

        final otherDirectory = Directory(other.path);

        if (!await otherDirectory.exists()) continue;

        final otherResolved = await otherDirectory.resolveSymbolicLinks();

        if (otherResolved == resolved ||
            otherResolved.startsWith('$resolved$separator')) {
          throw const FileSystemException(
            'Selected folder contains another project',
          );
        }
      }

      // ======================================================
      // THE ACTUAL NUKE
      // ======================================================

      await directory.delete(recursive: true);

      // The folder is gone. Now update the project registry.
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
        notify(
          'Project files were deleted, but the '
          'registry could not be updated: $error',
          error: true,
        );
      }
    } catch (error) {
      notify('Nuke failed: $error', error: true);
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  // ==========================================================
  // USER PREFERENCES
  // ==========================================================

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
            controller: controller,
            autofocus: true,
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'The Fox 369',
              labelText: 'Display name',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null) return;

    final previous = displayName;

    setState(() {
      displayName = result.isEmpty ? 'User' : result;
    });

    try {
      await savePreferences();
    } catch (error) {
      if (mounted) {
        setState(() => displayName = previous);
      }

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

    setState(() {
      projectDirectory = chosen;
    });

    try {
      await savePreferences();
      notify('Default project location saved.');
    } catch (error) {
      if (mounted) {
        setState(() => projectDirectory = previous);
      }

      notify('Could not save location: $error', error: true);
    }
  }

  // ==========================================================
  // MAIN LAYOUT
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;

        return Scaffold(
          body: Row(
            children: [
              if (wide) buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    buildTopbar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(wide ? 36 : 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: switch (page) {
                              DenPage.projects => projectsPage(),
                              DenPage.engines => enginesPage(),
                              DenPage.preferences => preferencesPage(),
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page.index,
                  onDestinationSelected: (index) {
                    setState(() {
                      page = DenPage.values[index];
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.folder_outlined),
                      label: 'Projects',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.layers_outlined),
                      label: 'Engines',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tune_rounded),
                      label: 'Preferences',
                    ),
                  ],
                ),
        );
      },
    );
  }

  // ==========================================================
  // SIDEBAR
  // ==========================================================

  Widget buildSidebar() {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
      decoration: const BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.hexagon_outlined, color: accent, size: 32),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KitDen',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 25,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      'DEVELOPMENT HUB',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 45),
          const Padding(
            padding: EdgeInsets.only(left: 13, bottom: 14),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          navItem(DenPage.projects, Icons.folder_outlined, 'My Projects'),
          const SizedBox(height: 7),
          navItem(DenPage.engines, Icons.layers_outlined, 'Engine Versions'),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.only(left: 13, bottom: 14),
            child: Text(
              'APPLICATION',
              style: TextStyle(
                color: textMuted,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          navItem(DenPage.preferences, Icons.tune_outlined, 'Preferences'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 21,
                  backgroundColor: fieldBg,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Local profile',
                        style: TextStyle(color: textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'KitDen • Early Development',
              style: TextStyle(color: textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget navItem(DenPage destination, IconData icon, String title) {
    final selected = page == destination;

    return Material(
      color: selected ? accentDim : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            page = destination;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: selected ? accent : textMuted, size: 21),
              const SizedBox(width: 13),
              Text(
                title,
                style: TextStyle(
                  color: selected ? textPrimary : textSecondary,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTopbar() {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 30),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: const Row(
        children: [
          Icon(Icons.circle, size: 8, color: accent),
          SizedBox(width: 9),
          Text(
            'LOCAL WORKSPACE',
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
          Spacer(),
          Text(
            'KitDen Preview',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // REUSABLE UI
  // ==========================================================

  Widget pageHeading(String label, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 13),
        Text(
          title,
          style: const TextStyle(
            fontSize: 32,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: const TextStyle(color: textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(24),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget settingCard({
    required IconData icon,
    required String heading,
    required String description,
    required Widget content,
  }) {
    return panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: accentDim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            description,
            style: const TextStyle(color: textSecondary, height: 1.5),
          ),
          const SizedBox(height: 22),
          content,
        ],
      ),
    );
  }

  // ==========================================================
  // PROJECT PAGE
  // ==========================================================

  Widget projectsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageHeading(
          'Welcome to the den',
          '$greeting, $displayName.',
          'Ready to make something?',
        ),
        const SizedBox(height: 35),
        panel(
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : showCreateProject,
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: bg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 23,
                    vertical: 18,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : importProject,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Import Project'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 23,
                    vertical: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Row(
          children: [
            const Text(
              'Recent Projects',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text(
              '${projects.length}',
              style: const TextStyle(color: accent, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (projects.isEmpty)
          panel(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 65),
            child: const Column(
              children: [
                Icon(Icons.folder_copy_outlined, size: 56, color: textMuted),
                SizedBox(height: 20),
                Text(
                  'Your workspace is empty.',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Start a project or import an existing one.',
                  style: TextStyle(color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...projects.map(projectTile),
        const SizedBox(height: 26),
        const Text(
          'KitEngine itself is still under development. '
          'Projects can be organized here, but the '
          'engine editor is not available yet.',
          style: TextStyle(color: textMuted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  // ==========================================================
  // PROJECT ROW
  // OPEN FOLDER | NUKE (ON HOVER) | X
  // ==========================================================

  Widget projectTile(LocalProject project) {
    final hovered = hoveredProjectPath == project.path;

    return MouseRegion(
      onEnter: (_) {
        if (!mounted) return;

        setState(() {
          hoveredProjectPath = project.path;
        });
      },
      onExit: (_) {
        if (!mounted) return;

        if (hoveredProjectPath == project.path) {
          setState(() {
            hoveredProjectPath = null;
          });
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: panel(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = Row(
                children: [
                  const Icon(Icons.folder_outlined, color: accent, size: 31),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          project.path,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final nukeColor = Theme.of(context).colorScheme.error;

              final nukeShadow = Color.lerp(nukeColor, Colors.black, 0.35)!;

              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => openFolder(project),
                    icon: const Icon(Icons.folder_open_outlined, size: 17),
                    label: const Text('Open Folder'),
                  ),
                  const SizedBox(width: 6),

                  // --------------------------------------
                  // NUKE — BESIDE THE X.
                  // --------------------------------------
                  if (hovered)
                    IconButton(
                      tooltip: 'Nuke project (Ctrl+click: instant)',
                      onPressed: busy
                          ? null
                          : () {
                              final ctrlPressed =
                                  HardwareKeyboard.instance.isControlPressed;

                              nukeProject(
                                project,
                                skipConfirmation: ctrlPressed,
                              );
                            },
                      icon: SvgPicture.asset(
                        'assets/icons/nuke.svg',
                        width: 23,
                        height: 23,
                        colorMapper: NukeColorMapper(
                          primary: nukeColor,
                          shadow: nukeShadow,
                        ),
                        // No colorFilter here!
                      ),
                    ),

                  // --------------------------------------
                  // X — REMOVE FROM LIST ONLY.
                  // --------------------------------------
                  IconButton(
                    tooltip: 'Remove from list only',
                    onPressed: busy ? null : () => removeProject(project),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              );

              if (constraints.maxWidth < 650) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [info, const SizedBox(height: 18), actions],
                );
              }

              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 20),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // ENGINE VERSIONS
  // ==========================================================

  Widget enginesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageHeading(
          'Engine Management',
          'Your engine versions.',
          'Manage KitEngine installations in one place.',
        ),
        const SizedBox(height: 34),
        panel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.layers_clear_outlined, size: 42, color: textMuted),
              SizedBox(height: 20),
              Text(
                'No engine builds installed.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'KitEngine has not reached its first '
                'usable engine build yet. Engine version '
                'management is planned for a later milestone.',
                style: TextStyle(color: textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // PREFERENCES
  // ==========================================================

  Widget preferencesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pageHeading(
          'Application',
          'Preferences',
          'Make KitDen work the way you like.',
        ),
        const SizedBox(height: 32),

        // PROFILE
        settingCard(
          icon: Icons.person_outline_rounded,
          heading: 'Your Profile',
          description:
              'Personalize your local KitDen experience. '
              'This does not create an online account.',
          content: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: fieldBg,
                child: Icon(
                  Icons.person_outline_rounded,
                  color: accent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Profile picture coming later',
                      style: TextStyle(color: textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: editDisplayName,
                child: const Text('Edit Name'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // PROJECT LOCATION
        settingCard(
          icon: Icons.folder_outlined,
          heading: 'Project Storage',
          description:
              'Choose where new KitEngine projects should '
              'be created. Existing projects are not moved.',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              folderPreview(
                projectDirectory.isEmpty
                    ? 'No location selected'
                    : projectDirectory,
              ),
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

        // APPLICATION DATA
        settingCard(
          icon: Icons.storage_outlined,
          heading: 'Application Data',
          description:
              'KitDen keeps a small local project registry '
              'so your projects appear after restarting.',
          content: SelectableText(
            KitDenStore.projectRegistry,
            style: const TextStyle(color: textSecondary, fontSize: 13),
          ),
        ),

        const SizedBox(height: 20),

        // CLOUD
        settingCard(
          icon: Icons.cloud_off_outlined,
          heading: 'Cloud & Accounts',
          description:
              'KitDen works entirely offline. Optional '
              'cloud accounts and backups may be added '
              'later, but local development will never '
              'require signing in.',
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: accent, size: 19),
              SizedBox(width: 10),
              Text(
                'Local mode enabled',
                style: TextStyle(color: accent, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
