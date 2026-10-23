// KitEngine runtime v0.1 — reusable 2D engine core.
// OpenGL renderer lives behind NativeGraphics; game logic stays in Dart.
import 'dart:ffi';
import 'dart:math' as math;

import 'src/native_graphics.dart';

export 'src/native_graphics.dart' show NativeGraphics;

/// Key codes follow GLFW's keyboard constants.
abstract final class Keys {
  static const int space = 32;
  static const int a = 65;
  static const int d = 68;
  static const int e = 69;
  static const int q = 81;
  static const int s = 83;
  static const int w = 87;
  static const int escape = 256;
  static const int left = 263;
  static const int right = 262;
  static const int down = 264;
  static const int up = 265;
}

class Input {
  Input(this._graphics);
  final NativeGraphics _graphics;
  final Set<int> _tracked = {
    Keys.a, Keys.d, Keys.e, Keys.q, Keys.s, Keys.w,
    Keys.space, Keys.escape, Keys.left, Keys.right, Keys.up, Keys.down,
  };
  Set<int> _current = {};
  Set<int> _previous = {};

  void track(int glfwKey) => _tracked.add(glfwKey);

  void capture() {
    _previous = _current;
    _current = {
      for (final key in _tracked)
        if (_graphics.keyDown(key)) key,
    };
  }

  bool down(int key) => _current.contains(key);
  bool pressed(int key) => down(key) && !_previous.contains(key);
  bool released(int key) => !down(key) && _previous.contains(key);
}

class Vec2 {
  const Vec2(this.x, this.y);
  final double x;
  final double y;
  static const zero = Vec2(0, 0);
  static const one = Vec2(1, 1);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double factor) => Vec2(x * factor, y * factor);
}

class Rgba {
  const Rgba(this.r, this.g, this.b, [this.a = 1]);
  final double r;
  final double g;
  final double b;
  final double a;

  static const foxfire = Rgba(.09, .07, .09);
  static const orange = Rgba(1, .70, .50);
  static const mint = Rgba(.65, .85, .77);
  static const rose = Rgba(.95, .55, .70);
}

/// 3×3 homogeneous transform, column-major (OpenGL layout).
class Mat3 {
  const Mat3(this.values);
  final List<double> values;

  static const identity = Mat3([
    1, 0, 0,
    0, 1, 0,
    0, 0, 1,
  ]);

  factory Mat3.translation(Vec2 p) => Mat3([
        1, 0, 0,
        0, 1, 0,
        p.x, p.y, 1,
      ]);

  factory Mat3.rotation(double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return Mat3([
      c, s, 0,
      -s, c, 0,
      0, 0, 1,
    ]);
  }

  factory Mat3.scaling(Vec2 s) => Mat3([
        s.x, 0, 0,
        0, s.y, 0,
        0, 0, 1,
      ]);

  Mat3 operator *(Mat3 b) {
    final a = values;
    final bb = b.values;
    final output = List<double>.filled(9, 0);
    for (var col = 0; col < 3; col++) {
      for (var row = 0; row < 3; row++) {
        for (var k = 0; k < 3; k++) {
          output[col * 3 + row] +=
              a[k * 3 + row] * bb[col * 3 + k];
        }
      }
    }
    return Mat3(output);
  }
}

class Node2D {
  Node2D({this.name = 'Node2D'});

  String name;
  Vec2 position = Vec2.zero;
  double rotation = 0; // radians
  Vec2 scale = Vec2.one;
  bool visible = true;
  Node2D? parent;
  final List<Node2D> _children = [];
  List<Node2D> get children => List.unmodifiable(_children);

  Mat3 get localTransform =>
      Mat3.translation(position) *
      Mat3.rotation(rotation) *
      Mat3.scaling(scale);

  Mat3 get worldTransform =>
      parent == null ? localTransform : parent!.worldTransform * localTransform;

  void add(Node2D child) {
    if (identical(child, this)) {
      throw ArgumentError('A node cannot parent itself');
    }
    for (Node2D? ancestor = this; ancestor != null; ancestor = ancestor.parent) {
      if (identical(ancestor, child)) {
        throw ArgumentError('Cyclic parent/child relationship');
      }
    }
    if (child.parent != null) {
      throw StateError('Child is already attached to another node');
    }
    child.parent = this;
    _children.add(child);
  }

  bool remove(Node2D child) {
    final removed = _children.remove(child);
    if (removed) child.parent = null;
    return removed;
  }

  void onUpdate(double dt) {}

  void updateTree(double dt) {
    onUpdate(dt);
    for (final child in List<Node2D>.of(_children)) {
      if (identical(child.parent, this)) child.updateTree(dt);
    }
  }

  void renderTree(NativeGraphics renderer, Camera2D camera) {
    if (!visible) return;
    renderSelf(renderer, camera);
    for (final child in List<Node2D>.of(_children)) {
      if (identical(child.parent, this)) child.renderTree(renderer, camera);
    }
  }

  void renderSelf(NativeGraphics renderer, Camera2D camera) {}
}

class Mesh2D {
  Mesh2D._(this._renderer, this._handle);
  final NativeGraphics _renderer;
  Pointer<Void> _handle;
  bool _disposed = false;

  void render(Camera2D camera, Mat3 matrix, Rgba color) {
    if (_disposed) throw StateError('Cannot render a disposed mesh');
    _renderer.drawMesh(_handle, [
      ...matrix.values,
      camera.position.x,
      camera.position.y,
      camera.zoom,
      color.r,
      color.g,
      color.b,
      color.a,
    ]);
  }

  void dispose() {
    if (_disposed) return;
    _renderer.destroyMesh(_handle);
    _handle = nullptr;
    _disposed = true;
  }
}

class MeshNode extends Node2D {
  MeshNode({required this.mesh, this.color = Rgba.orange, super.name = 'MeshNode'});
  final Mesh2D mesh;
  Rgba color;

  @override
  void renderSelf(NativeGraphics renderer, Camera2D camera) {
    mesh.render(camera, worldTransform, color);
  }
}

class Camera2D {
  Vec2 position = Vec2.zero;
  double zoom = 1;
}

class Scene {
  Scene({this.background = Rgba.foxfire});
  final Node2D root = Node2D(name: 'Root');
  final Camera2D camera = Camera2D();
  Rgba background;

  void update(double dt) => root.updateTree(dt);
  void draw(NativeGraphics graphics) => root.renderTree(graphics, camera);
}

/// Override onStart/onUpdate/onStop for your game.
abstract class Game {
  final Scene scene = Scene();
  void onStart(KitEngine engine);
  void onUpdate(double dt, KitEngine engine) {}
  void onStop(KitEngine engine) {}
}

class KitEngine {
  KitEngine({this.width = 960, this.height = 540, this.title = 'KitEngine v0.1'});

  final int width;
  final int height;
  final String title;
  final NativeGraphics _graphics = NativeGraphics();
  final List<Mesh2D> _meshes = [];
  late final Input input = Input(_graphics);
  bool _running = false;

  Mesh2D createMesh(List<double> xyVertices) {
    if (!_running) throw StateError('Create meshes after engine initialization');
    final mesh = Mesh2D._(_graphics, _graphics.createMesh(xyVertices));
    _meshes.add(mesh);
    return mesh;
  }

  void close() => _graphics.requestClose();

  /// Synchronous main loop: GLFW and the OpenGL context remain on one thread.
  void run(Game game) {
    if (_running) throw StateError('Engine is already running');
    if (!_graphics.initialize(width, height)) {
      throw StateError('Could not initialize OpenGL; use XWayland workaround');
    }
    _running = true;
    _graphics.setTitle(title);
    final timer = Stopwatch()..start();
    var previous = timer.elapsedMicroseconds;
    try {
      game.onStart(this);
      while (!_graphics.shouldClose) {
        _graphics.pollEvents();
        if (_graphics.shouldClose) break;
        input.capture();
        final now = timer.elapsedMicroseconds;
        final dt = ((now - previous) / 1000000).clamp(0.0, 0.05).toDouble();
        previous = now;
        game.onUpdate(dt, this);
        game.scene.update(dt);
        final c = game.scene.background;
        _graphics.beginFrame(c.r, c.g, c.b, c.a);
        game.scene.draw(_graphics);
        _graphics.endFrame();
      }
    } finally {
      try {
        game.onStop(this);
      } finally {
        // Native GL resource destruction must happen before context teardown.
        for (final mesh in _meshes.reversed) {
          mesh.dispose();
        }
        _meshes.clear();
        _graphics.shutdown();
        _running = false;
        timer.stop();
      }
    }
  }
}
