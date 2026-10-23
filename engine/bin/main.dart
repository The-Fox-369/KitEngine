// KitEngine Runtime v0.1 — standalone playground or project scene.
// Usage: dart run bin/main.dart [--project '/path/to/project']
import 'dart:convert';
import 'dart:io';

import 'package:kitengine/kitengine.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    KitEngine(title: 'KitEngine v0.1 — Foxfire Playground')
        .run(FoxfirePlayground());
    return;
  }

  if (arguments.length != 2 || arguments[0] != '--project') {
    stderr.writeln(
      'Usage: dart run bin/main.dart [--project "/path/to/project"]',
    );
    exitCode = 2;
    return;
  }

  final path = arguments[1];
  final directory = Directory(path);
  final manifest = File('${directory.path}/kitengine.project.json');
  if (!directory.existsSync() || !manifest.existsSync()) {
    stderr.writeln('KitEngine: project manifest not found in $path');
    exitCode = 2;
    return;
  }

  try {
    final metadata = jsonDecode(manifest.readAsStringSync());
    if (metadata is! Map ||
        metadata['formatVersion'] != 1 ||
        metadata['name'] is! String) {
      throw const FormatException('Invalid project manifest');
    }
    final name = metadata['name'] as String;
    KitEngine(title: 'KitEngine — $name')
        .run(ProjectSceneGame(directory.path));
  } catch (error, trace) {
    stderr.writeln('KitEngine: could not run project: $error');
    stderr.writeln(trace);
    exitCode = 1;
  }
}

// ============================================================
// PROJECT SCENE v1
//
// Loads a scene from <project>/scenes/main.scene.json.
// It is actual, editable project data—not the unrelated demo.
// Older projects without a scene get a temporary starter scene
// without writing anything to their existing files.
// ============================================================

class ProjectSceneGame extends Game {
  ProjectSceneGame(this.projectPath);
  final String projectPath;
  Node2D? _controlled;
  int _loadedNodes = 0;

  @override
  void onStart(KitEngine engine) {
    final path = '$projectPath/scenes/main.scene.json';
    final file = File(path);
    final Map<String, dynamic> data;

    if (file.existsSync()) {
      if (file.lengthSync() > 256 * 1024) {
        throw const FormatException('Scene exceeds the 256 KiB limit');
      }
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Scene must be a JSON object');
      }
      data = decoded;
      stdout.writeln('[KitEngine] Loading scene: $path');
    } else {
      data = _starterScene;
      stdout.writeln('[KitEngine] No scene found: showing temporary starter');
    }

    if (data['format'] != 'kitengine.scene' ||
        data['formatVersion'] != 1) {
      throw const FormatException('Unsupported KitEngine scene version');
    }

    scene.background = _color(data['background'], Rgba.foxfire);
    final camera = data['camera'];
    if (camera is Map) {
      scene.camera.position = _vector(camera['position'], Vec2.zero);
      final zoom = camera['zoom'];
      if (zoom is num && zoom.toDouble() > 0) {
        scene.camera.zoom = zoom.toDouble();
      }
    }

    final nodes = data['nodes'];
    if (nodes is! List) {
      throw const FormatException('Scene must contain a nodes array');
    }
    for (final value in nodes) {
      scene.root.add(_loadNode(value, engine, depth: 0));
    }
    stdout.writeln('[KitEngine] Loaded $_loadedNodes nodes. '
        'WASD=move, Q/E=rotate, arrows=camera, Space=zoom, Esc=exit');
  }

  Node2D _loadNode(dynamic raw, KitEngine engine, {required int depth}) {
    if (depth > 16 || ++_loadedNodes > 200) {
      throw const FormatException('Scene hierarchy exceeds safety limits');
    }
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Each node must be an object');
    }

    final name = raw['name'] is String ? raw['name'] as String : 'Node';
    final verticesRaw = raw['vertices'];
    late final Node2D node;

    if (verticesRaw is List) {
      if (verticesRaw.length < 6 ||
          verticesRaw.length > 6000 ||
          verticesRaw.length % 6 != 0 ||
          verticesRaw.any((v) => v is! num || !v.isFinite)) {
        throw FormatException('Invalid triangle vertices for node $name');
      }
      final coordinates = verticesRaw.cast<num>()
          .map((v) => v.toDouble()).toList();
      node = MeshNode(
        name: name,
        mesh: engine.createMesh(coordinates),
        color: _color(raw['color'], Rgba.orange),
      );
    } else {
      node = Node2D(name: name);
    }

    node.position = _vector(raw['position'], Vec2.zero);
    node.scale = _vector(raw['scale'], Vec2.one);
    final angle = raw['rotation'];
    if (angle is num && angle.isFinite) node.rotation = angle.toDouble();
    if (raw['visible'] == false) node.visible = false;

    if (raw['controllable'] == true) {
      if (_controlled != null) {
        throw const FormatException('Only one controllable node is supported');
      }
      _controlled = node;
    }

    final children = raw['children'];
    if (children != null) {
      if (children is! List) {
        throw FormatException('children must be an array on $name');
      }
      for (final child in children) {
        node.add(_loadNode(child, engine, depth: depth + 1));
      }
    }
    return node;
  }

  static Vec2 _vector(dynamic raw, Vec2 fallback) {
    if (raw == null) return fallback;
    if (raw is! List || raw.length != 2 ||
        raw[0] is! num || raw[1] is! num ||
        !(raw[0] as num).isFinite || !(raw[1] as num).isFinite) {
      throw const FormatException('Vector must be [x, y] with finite numbers');
    }
    return Vec2((raw[0] as num).toDouble(), (raw[1] as num).toDouble());
  }

  static Rgba _color(dynamic raw, Rgba fallback) {
    if (raw == null) return fallback;
    if (raw is! String || !RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(raw)) {
      throw const FormatException('Color must use #RRGGBB');
    }
    final value = int.parse(raw.substring(1), radix: 16);
    return Rgba(
      ((value >> 16) & 255) / 255,
      ((value >> 8) & 255) / 255,
      (value & 255) / 255,
    );
  }

  @override
  void onUpdate(double dt, KitEngine engine) {
    final input = engine.input;
    final speed = 230 * dt;
    final actor = _controlled;
    if (actor != null) {
      var dx = 0.0;
      var dy = 0.0;
      if (input.down(Keys.w)) dy += speed;
      if (input.down(Keys.s)) dy -= speed;
      if (input.down(Keys.a)) dx -= speed;
      if (input.down(Keys.d)) dx += speed;
      actor.position += Vec2(dx, dy);
      if (input.down(Keys.q)) actor.rotation += 2.4 * dt;
      if (input.down(Keys.e)) actor.rotation -= 2.4 * dt;
    }
    var cx = 0.0;
    var cy = 0.0;
    if (input.down(Keys.left)) cx -= speed;
    if (input.down(Keys.right)) cx += speed;
    if (input.down(Keys.up)) cy += speed;
    if (input.down(Keys.down)) cy -= speed;
    scene.camera.position += Vec2(cx, cy);
    if (input.pressed(Keys.space)) {
      scene.camera.zoom = scene.camera.zoom == 1 ? 1.5 : 1;
    }
  }
}

const Map<String, dynamic> _starterScene = {
  'format': 'kitengine.scene',
  'formatVersion': 1,
  'background': '#171116',
  'nodes': [
    {
      'name': 'Player', 'controllable': true,
      'color': '#FFB480',
      'vertices': [0, 66, -59, -45, 59, -45],
      'children': [
        {
          'name': 'Gem', 'position': [96, 0],
          'color': '#A5D9C5',
          'vertices': [
            0, 25, -19, 0, 0, -25,
            0, 25, 0, -25, 19, 0,
          ],
        },
      ],
    },
  ],
};

// ============================================================
// BUILT-IN PLAYGROUND (launched from Engine Versions)
// ============================================================

class FoxfirePlayground extends Game {
  late final Node2D player;
  late final MeshNode child;

  @override
  void onStart(KitEngine engine) {
    final triangle = engine.createMesh([
      0, 66,
      -59, -45,
      59, -45,
    ]);
    final diamond = engine.createMesh([
      0, 25, -19, 0, 0, -25,
      0, 25, 0, -25, 19, 0,
    ]);
    final floor = engine.createMesh([
      -320, -170, 320, -170, 320, -175,
      -320, -170, 320, -175, -320, -175,
    ]);

    scene.root.add(MeshNode(
      name: 'Horizon', mesh: floor, color: const Rgba(.42, .28, .34),
    ));
    player = Node2D(name: 'Player');
    player.add(MeshNode(
      name: 'MainBody', mesh: triangle, color: Rgba.orange,
    ));
    child = MeshNode(name: 'OrbitingGem', mesh: diamond, color: Rgba.mint)
      ..position = const Vec2(96, 0);
    child.scale = const Vec2(.65, .65);
    player.add(child);
    scene.root.add(player);
    stdout.writeln('[KitEngine] Playground loaded: WASD Q/E arrows Space Esc');
  }

  @override
  void onUpdate(double dt, KitEngine engine) {
    final input = engine.input;
    final speed = 230 * dt;
    var dx = 0.0;
    var dy = 0.0;
    if (input.down(Keys.w)) dy += speed;
    if (input.down(Keys.s)) dy -= speed;
    if (input.down(Keys.a)) dx -= speed;
    if (input.down(Keys.d)) dx += speed;
    player.position += Vec2(dx, dy);
    if (input.down(Keys.q)) player.rotation += 2.4 * dt;
    if (input.down(Keys.e)) player.rotation -= 2.4 * dt;
    var cx = 0.0;
    var cy = 0.0;
    if (input.down(Keys.left)) cx -= speed;
    if (input.down(Keys.right)) cx += speed;
    if (input.down(Keys.up)) cy += speed;
    if (input.down(Keys.down)) cy -= speed;
    scene.camera.position += Vec2(cx, cy);
    child.rotation += dt * 2;
    if (input.pressed(Keys.space)) {
      scene.camera.zoom = scene.camera.zoom == 1 ? 1.5 : 1;
    }
  }
}
