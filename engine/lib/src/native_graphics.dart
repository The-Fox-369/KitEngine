// KitEngine's private Linux OpenGL FFI bridge.
// The native context and every call to it must stay on one OS thread.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _InitC = Int32 Function(Int32, Int32);
typedef _InitDart = int Function(int, int);
typedef _IntC = Int32 Function();
typedef _IntDart = int Function();
typedef _KeyC = Int32 Function(Int32);
typedef _KeyDart = int Function(int);
typedef _VoidC = Void Function();
typedef _VoidDart = void Function();
typedef _FrameC = Void Function(Float, Float, Float, Float);
typedef _FrameDart = void Function(double, double, double, double);
typedef _MeshC = Pointer<Void> Function(Pointer<Float>, Int32);
typedef _MeshDart = Pointer<Void> Function(Pointer<Float>, int);
typedef _FreeC = Void Function(Pointer<Void>);
typedef _FreeDart = void Function(Pointer<Void>);
typedef _DrawC = Void Function(Pointer<Void>, Pointer<Float>);
typedef _DrawDart = void Function(Pointer<Void>, Pointer<Float>);
typedef _TitleC = Void Function(Pointer<Utf8>);
typedef _TitleDart = void Function(Pointer<Utf8>);

class NativeGraphics {
  NativeGraphics() : _library = DynamicLibrary.open(_path());

  final DynamicLibrary _library;

  static String _path() {
    if (!Platform.isLinux) {
      throw UnsupportedError('KitEngine OpenGL backend currently targets Linux.');
    }
    final override = Platform.environment['KITENGINE_NATIVE_LIB'];
    if (override != null && override.isNotEmpty) return override;
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) throw StateError('HOME is missing');
    return '$home/.cache/kitengine/libkitengine_graphics.so';
  }

  late final _InitDart _initialize =
      _library.lookupFunction<_InitC, _InitDart>('ke_initialize');
  late final _IntDart _shouldClose =
      _library.lookupFunction<_IntC, _IntDart>('ke_should_close');
  late final _VoidDart _pollEvents =
      _library.lookupFunction<_VoidC, _VoidDart>('ke_poll_events');
  late final _KeyDart _keyDown =
      _library.lookupFunction<_KeyC, _KeyDart>('ke_key_down');
  late final _FrameDart _beginFrame =
      _library.lookupFunction<_FrameC, _FrameDart>('ke_begin_frame');
  late final _VoidDart _endFrame =
      _library.lookupFunction<_VoidC, _VoidDart>('ke_end_frame');
  late final _MeshDart _createMesh =
      _library.lookupFunction<_MeshC, _MeshDart>('ke_create_mesh');
  late final _FreeDart _destroyMesh =
      _library.lookupFunction<_FreeC, _FreeDart>('ke_destroy_mesh');
  late final _DrawDart _drawMesh =
      _library.lookupFunction<_DrawC, _DrawDart>('ke_draw_mesh');
  late final _VoidDart _shutdown =
      _library.lookupFunction<_VoidC, _VoidDart>('ke_shutdown');
  late final _TitleDart _setTitle =
      _library.lookupFunction<_TitleC, _TitleDart>('ke_set_window_title');
  late final _VoidDart _requestClose =
      _library.lookupFunction<_VoidC, _VoidDart>('ke_request_close');

  bool initialize(int width, int height) => _initialize(width, height) == 1;
  bool get shouldClose => _shouldClose() != 0;
  void pollEvents() => _pollEvents();
  bool keyDown(int glfwCode) => _keyDown(glfwCode) != 0;
  void beginFrame(double r, double g, double b, double a) =>
      _beginFrame(r, g, b, a);
  void endFrame() => _endFrame();
  void shutdown() => _shutdown();
  void requestClose() => _requestClose();

  void setTitle(String text) {
    final native = text.toNativeUtf8();
    try {
      _setTitle(native);
    } finally {
      calloc.free(native);
    }
  }

  Pointer<Void> createMesh(List<double> vertices) {
    if (vertices.length < 6 || vertices.length % 6 != 0) {
      throw ArgumentError('Use x/y pairs, with three vertices per triangle.');
    }
    final floats = calloc<Float>(vertices.length);
    try {
      for (var i = 0; i < vertices.length; i++) {
        floats[i] = vertices[i];
      }
      final mesh = _createMesh(floats, vertices.length ~/ 2);
      if (mesh == nullptr) {
        throw StateError('OpenGL could not create the requested mesh');
      }
      return mesh;
    } finally {
      calloc.free(floats);
    }
  }

  void destroyMesh(Pointer<Void> mesh) => _destroyMesh(mesh);

  void drawMesh(Pointer<Void> mesh, List<double> parameters) {
    if (parameters.length != 16) {
      throw ArgumentError('Renderer expects sixteen draw parameters');
    }
    final floats = calloc<Float>(16);
    try {
      for (var i = 0; i < 16; i++) {
        floats[i] = parameters[i];
      }
      _drawMesh(mesh, floats);
    } finally {
      calloc.free(floats);
    }
  }
}
