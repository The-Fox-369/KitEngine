
#!/usr/bin/env bash
# KitEngine Runtime v0.1 — Linux launcher.
# Called by KitDen's Run button.

set -euo pipefail

ENGINE_DIR="$(
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P
)"
cd -- "$ENGINE_DIR"

if [[ $# -ne 0 && ( $# -ne 2 || $1 != '--project' ) ]]; then
    echo 'Usage: bash run_linux.sh [--project "/path/to/project"]' >&2
    exit 2
fi

if [[ $# -eq 2 ]]; then
    [[ -d "$2" && -f "$2/kitengine.project.json" ]] || {
        echo "KitEngine: invalid project directory: $2" >&2
        exit 2
    }
fi

# Detect Dart, including when launched from a desktop GUI.

if [[ -n "${KITENGINE_DART_BIN:-}" &&
      -x "$KITENGINE_DART_BIN" ]]; then
    DART="$KITENGINE_DART_BIN"
elif command -v dart >/dev/null 2>&1; then
    DART="$(command -v dart)"
elif [[ -x "$HOME/develop/flutter/bin/dart" ]]; then
    DART="$HOME/develop/flutter/bin/dart"
elif [[ -x "$HOME/flutter/bin/dart" ]]; then
    DART="$HOME/flutter/bin/dart"
else
    echo 'KitEngine: Dart SDK not found.' >&2
    exit 127
fi

for tool in gcc pkg-config; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "KitEngine: missing tool $tool" >&2
        exit 127
    }
done

# Compile the native library on the Linux filesystem.
# KitEngine source can remain on your NTFS SSD.

LIBRARY="$HOME/.cache/kitengine/libkitengine_graphics.so"

mkdir -p -- "$(dirname -- "$LIBRARY")"

if [[ ! -f "$LIBRARY" || native/graphics.c -nt "$LIBRARY" ]]; then
    echo '[KitEngine] Building OpenGL backend...'

    read -r -a PKG_FLAGS <<< \
        "$(pkg-config --cflags --libs glfw3 glew)"

    gcc -std=c11 -O2 -Wall -Wextra -fPIC -shared \
        native/graphics.c \
        -o "$LIBRARY" \
        "${PKG_FLAGS[@]}" \
        -lGL
fi

# Resolve dependencies only when needed.

if [[ ! -f .dart_tool/package_config.json ]]; then
    echo '[KitEngine] Resolving Dart dependencies...'
    "$DART" pub get
fi

# Your confirmed GLFW/GLEW XWayland workaround.

echo '[KitEngine] Starting runtime...'

exec env -u WAYLAND_DISPLAY XDG_SESSION_TYPE=x11 \
    "$DART" run bin/main.dart "$@"
