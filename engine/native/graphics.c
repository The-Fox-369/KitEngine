/*
 * KitEngine OpenGL backend v0.1 (Linux, GLFW, GLEW, OpenGL 3.3).
 * All exported ke_* functions must be called on the graphics/context thread.
 * Vertex format: interleaved 2D coordinates [x,y] per vertex.
 * Draw params: 16 floats: column-major 3x3 model matrix (0..8),
 * camera x/y (9..10), zoom (11), RGBA (12..15).
 */

 #include <stdio.h>
 #include <stdlib.h>
 #include <stdint.h>
 
 #include <GL/glew.h>
 #include <GLFW/glfw3.h>
 
 typedef struct KEMesh {
     GLuint vao;
     GLuint vbo;
     GLsizei vertex_count;
 } KEMesh;
 
 static GLFWwindow *window = NULL;
 static GLuint program = 0;
 
 static GLint loc_model = -1;
 static GLint loc_camera = -1;
 static GLint loc_zoom = -1;
 static GLint loc_viewport = -1;
 static GLint loc_color = -1;
 
 static int glfw_ready = 0;
 static int renderer_ready = 0;
 
 /* ============================================================
  * SHADERS
  * ============================================================ */
 
 static const char *vertex_shader =
     "#version 330 core\n"
     "layout(location=0) in vec2 aPosition;\n"
     "uniform mat3 uModel;\n"
     "uniform vec2 uCamera;\n"
     "uniform float uZoom;\n"
     "uniform vec2 uViewport;\n"
     "void main() {\n"
     "  vec2 world = (uModel * vec3(aPosition, 1.0)).xy;\n"
     "  vec2 screen = (world - uCamera) * uZoom;\n"
     "  gl_Position = vec4(screen * 2.0 / uViewport, 0.0, 1.0);\n"
     "}\n";
 
 static const char *fragment_shader =
     "#version 330 core\n"
     "uniform vec4 uColor;\n"
     "out vec4 FragColor;\n"
     "void main() { FragColor = uColor; }\n";
 
 /* ============================================================
  * ERROR HANDLING
  * ============================================================ */
 
 static void error_callback(int code, const char *message) {
     fprintf(
         stderr,
         "[KitEngine/GLFW %d] %s\n",
         code,
         message ? message : "Unknown error"
     );
 }
 
 /* ============================================================
  * SHADER COMPILATION
  * ============================================================ */
 
 static GLuint compile_shader(
     GLenum type,
     const char *source
 ) {
     GLuint shader = glCreateShader(type);
 
     if (!shader) {
         return 0;
     }
 
     glShaderSource(shader, 1, &source, NULL);
     glCompileShader(shader);
 
     GLint ok = GL_FALSE;
 
     glGetShaderiv(
         shader,
         GL_COMPILE_STATUS,
         &ok
     );
 
     if (!ok) {
         char log[4096] = {0};
 
         glGetShaderInfoLog(
             shader,
             (GLsizei)sizeof(log),
             NULL,
             log
         );
 
         fprintf(
             stderr,
             "[KitEngine] Shader error: %s\n",
             log
         );
 
         glDeleteShader(shader);
         return 0;
     }
 
     return shader;
 }
 
 /* ============================================================
  * SHADER PROGRAM
  * ============================================================ */
 
 static int create_program(void) {
     GLuint vs = compile_shader(
         GL_VERTEX_SHADER,
         vertex_shader
     );
 
     if (!vs) {
         return 0;
     }
 
     GLuint fs = compile_shader(
         GL_FRAGMENT_SHADER,
         fragment_shader
     );
 
     if (!fs) {
         glDeleteShader(vs);
         return 0;
     }
 
     program = glCreateProgram();
 
     if (!program) {
         glDeleteShader(vs);
         glDeleteShader(fs);
         return 0;
     }
 
     glAttachShader(program, vs);
     glAttachShader(program, fs);
 
     glLinkProgram(program);
 
     glDeleteShader(vs);
     glDeleteShader(fs);
 
     GLint ok = GL_FALSE;
 
     glGetProgramiv(
         program,
         GL_LINK_STATUS,
         &ok
     );
 
     if (!ok) {
         char log[4096] = {0};
 
         glGetProgramInfoLog(
             program,
             (GLsizei)sizeof(log),
             NULL,
             log
         );
 
         fprintf(
             stderr,
             "[KitEngine] Program link error: %s\n",
             log
         );
 
         glDeleteProgram(program);
         program = 0;
 
         return 0;
     }
 
     loc_model = glGetUniformLocation(
         program,
         "uModel"
     );
 
     loc_camera = glGetUniformLocation(
         program,
         "uCamera"
     );
 
     loc_zoom = glGetUniformLocation(
         program,
         "uZoom"
     );
 
     loc_viewport = glGetUniformLocation(
         program,
         "uViewport"
     );
 
     loc_color = glGetUniformLocation(
         program,
         "uColor"
     );
 
     return 1;
 }
 
 /* ============================================================
  * SHUTDOWN
  * ============================================================ */
 
 void ke_shutdown(void) {
     if (window) {
         glfwMakeContextCurrent(window);
 
         if (program) {
             glDeleteProgram(program);
             program = 0;
         }
 
         glfwDestroyWindow(window);
         window = NULL;
     }
 
     renderer_ready = 0;
 
     if (glfw_ready) {
         glfwTerminate();
         glfw_ready = 0;
     }
 }
 
 /* ============================================================
  * INITIALIZATION
  * ============================================================ */
 
 int ke_initialize(int width, int height) {
     if (renderer_ready) {
         return 1;
     }
 
     if (width <= 0 || height <= 0) {
         return 0;
     }
 
     glfwSetErrorCallback(error_callback);
 
     if (!glfwInit()) {
         fprintf(
             stderr,
             "[KitEngine] glfwInit failed.\n"
         );
 
         return 0;
     }
 
     glfw_ready = 1;
 
     glfwWindowHint(
         GLFW_CONTEXT_VERSION_MAJOR,
         3
     );
 
     glfwWindowHint(
         GLFW_CONTEXT_VERSION_MINOR,
         3
     );
 
     glfwWindowHint(
         GLFW_OPENGL_PROFILE,
         GLFW_OPENGL_CORE_PROFILE
     );
 
     glfwWindowHint(
         GLFW_RESIZABLE,
         GLFW_TRUE
     );
 
     window = glfwCreateWindow(
         width,
         height,
         "KitEngine v0.1",
         NULL,
         NULL
     );
 
     if (!window) {
         ke_shutdown();
         return 0;
     }
 
     glfwMakeContextCurrent(window);
 
     glfwSwapInterval(1);
 
     glewExperimental = GL_TRUE;
 
     GLenum glew_status = glewInit();
 
     if (glew_status != GLEW_OK) {
         fprintf(
             stderr,
             "[KitEngine] GLEW failure (%u): %s\n",
             (unsigned int)glew_status,
             glewGetErrorString(glew_status)
         );
 
         fprintf(
             stderr,
             "[KitEngine] On Ubuntu Wayland try: "
             "env -u WAYLAND_DISPLAY XDG_SESSION_TYPE=x11 "
             "dart run bin/main.dart\n"
         );
 
         ke_shutdown();
         return 0;
     }
 
     /*
      * GLEW may leave a harmless OpenGL error after
      * initialization with a core-profile context.
      */
 
     glGetError();
 
     if (!GLEW_VERSION_3_3 || !create_program()) {
         fprintf(
             stderr,
             "[KitEngine] OpenGL 3.3 or shader "
             "pipeline unavailable.\n"
         );
 
         ke_shutdown();
         return 0;
     }
 
     glDisable(GL_DEPTH_TEST);
 
     glEnable(GL_BLEND);
 
     glBlendFunc(
         GL_SRC_ALPHA,
         GL_ONE_MINUS_SRC_ALPHA
     );
 
     renderer_ready = 1;
 
     printf(
         "[KitEngine] OpenGL %s\n",
         (const char *)glGetString(GL_VERSION)
     );
 
     printf(
         "[KitEngine] Renderer %s\n",
         (const char *)glGetString(GL_RENDERER)
     );
 
     fflush(stdout);
 
     return 1;
 }
 
 /* ============================================================
  * WINDOW STATUS
  * ============================================================ */
 
 int ke_should_close(void) {
     return !window ||
            glfwWindowShouldClose(window)
                ? 1
                : 0;
 }
 
 /* ============================================================
  * WINDOW EVENTS
  * ============================================================ */
 
 void ke_poll_events(void) {
     if (!window) {
         return;
     }
 
     glfwPollEvents();
 
     if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS) {
         glfwSetWindowShouldClose(
             window,
             GLFW_TRUE
         );
     }
 }
 
 /* ============================================================
  * KEYBOARD INPUT
  * ============================================================ */
 
 int ke_key_down(int key) {
     if (!window ||
         key < GLFW_KEY_SPACE ||
         key > GLFW_KEY_LAST) {
         return 0;
     }
 
     int state = glfwGetKey(window, key);
 
     return state == GLFW_PRESS ||
            state == GLFW_REPEAT;
 }
 
 /* ============================================================
  * BEGIN FRAME
  * ============================================================ */
 
 void ke_begin_frame(
     float r,
     float g,
     float b,
     float a
 ) {
     if (!renderer_ready) {
         return;
     }
 
     int width = 0;
     int height = 0;
 
     glfwGetFramebufferSize(
         window,
         &width,
         &height
     );
 
     if (width < 1 || height < 1) {
         return;
     }
 
     glViewport(
         0,
         0,
         width,
         height
     );
 
     glClearColor(r, g, b, a);
 
     glClear(GL_COLOR_BUFFER_BIT);
 }
 
 /* ============================================================
  * END FRAME
  * ============================================================ */
 
 void ke_end_frame(void) {
     if (renderer_ready) {
         glfwSwapBuffers(window);
     }
 }
 
 /* ============================================================
  * CREATE GPU MESH
  *
  * Vertex layout:
  *
  * float vertices[] = {
  *     x0, y0,
  *     x1, y1,
  *     x2, y2
  * };
  *
  * vertex_count = number of vertices, NOT floats.
  * ============================================================ */
 
 void *ke_create_mesh(
     const float *vertices,
     int vertex_count
 ) {
     if (!renderer_ready ||
         !vertices ||
         vertex_count < 3 ||
         vertex_count > 1000000 ||
         vertex_count % 3 != 0) {
         return NULL;
     }
 
     KEMesh *mesh = (KEMesh *)calloc(
         1,
         sizeof(KEMesh)
     );
 
     if (!mesh) {
         return NULL;
     }
 
     mesh->vertex_count = (GLsizei)vertex_count;
 
     glGenVertexArrays(
         1,
         &mesh->vao
     );
 
     glGenBuffers(
         1,
         &mesh->vbo
     );
 
     if (!mesh->vao || !mesh->vbo) {
         if (mesh->vbo) {
             glDeleteBuffers(1, &mesh->vbo);
         }
 
         if (mesh->vao) {
             glDeleteVertexArrays(1, &mesh->vao);
         }
 
         free(mesh);
         return NULL;
     }
 
     glBindVertexArray(mesh->vao);
 
     glBindBuffer(
         GL_ARRAY_BUFFER,
         mesh->vbo
     );
 
     glBufferData(
         GL_ARRAY_BUFFER,
         (GLsizeiptr)vertex_count *
             2 *
             (GLsizeiptr)sizeof(float),
         vertices,
         GL_STATIC_DRAW
     );
 
     glVertexAttribPointer(
         0,
         2,
         GL_FLOAT,
         GL_FALSE,
         2 * (GLsizei)sizeof(float),
         (void *)0
     );
 
     glEnableVertexAttribArray(0);
 
     glBindBuffer(
         GL_ARRAY_BUFFER,
         0
     );
 
     glBindVertexArray(0);
 
     GLenum error = glGetError();
 
     if (error != GL_NO_ERROR) {
         fprintf(
             stderr,
             "[KitEngine] Mesh upload GL error 0x%X\n",
             error
         );
 
         glDeleteBuffers(
             1,
             &mesh->vbo
         );
 
         glDeleteVertexArrays(
             1,
             &mesh->vao
         );
 
         free(mesh);
         return NULL;
     }
 
     return mesh;
 }
 
 /* ============================================================
  * DESTROY GPU MESH
  * ============================================================ */
 
 void ke_destroy_mesh(void *handle) {
     if (!handle) {
         return;
     }
 
     KEMesh *mesh = (KEMesh *)handle;
 
     if (renderer_ready) {
         if (mesh->vbo) {
             glDeleteBuffers(
                 1,
                 &mesh->vbo
             );
         }
 
         if (mesh->vao) {
             glDeleteVertexArrays(
                 1,
                 &mesh->vao
             );
         }
     }
 
     free(mesh);
 }
 
 /* ============================================================
  * DRAW GPU MESH
  *
  * Draw params = 16 floats:
  *
  *   0..8  : column-major 3x3 model matrix
  *   9     : camera X
  *   10    : camera Y
  *   11    : camera zoom
  *   12    : red
  *   13    : green
  *   14    : blue
  *   15    : alpha
  *
  * This layout matches the Dart scene graph runtime.
  * ============================================================ */
 
 void ke_draw_mesh(
     void *handle,
     const float *params
 ) {
     if (!renderer_ready ||
         !handle ||
         !params) {
         return;
     }
 
     KEMesh *mesh = (KEMesh *)handle;
 
     if (!mesh->vao || mesh->vertex_count < 3) {
         return;
     }
 
     int width = 0;
     int height = 0;
 
     glfwGetFramebufferSize(
         window,
         &width,
         &height
     );
 
     if (width < 1 || height < 1) {
         return;
     }
 
     glUseProgram(program);
 
     glUniformMatrix3fv(
         loc_model,
         1,
         GL_FALSE,
         params
     );
 
     glUniform2f(
         loc_camera,
         params[9],
         params[10]
     );
 
     glUniform1f(
         loc_zoom,
         params[11] > 0.0f
             ? params[11]
             : 1.0f
     );
 
     glUniform2f(
         loc_viewport,
         (float)width,
         (float)height
     );
 
     glUniform4f(
         loc_color,
         params[12],
         params[13],
         params[14],
         params[15]
     );
 
     glBindVertexArray(mesh->vao);
 
     glDrawArrays(
         GL_TRIANGLES,
         0,
         mesh->vertex_count
     );
 
     glBindVertexArray(0);
 }
 
 /* ============================================================
  * WINDOW TITLE
  * ============================================================ */
 
 void ke_set_window_title(const char *title) {
     if (window && title) {
         glfwSetWindowTitle(
             window,
             title
         );
     }
 }
 
 /* ============================================================
  * REQUEST WINDOW CLOSE
  * ============================================================ */
 
 void ke_request_close(void) {
     if (window) {
         glfwSetWindowShouldClose(
             window,
             GLFW_TRUE
         );
     }
 }
 
 /* ============================================================
  * VSYNC CONTROL
  * ============================================================ */
 
 void ke_set_vsync(int enabled) {
     if (window) {
         glfwSwapInterval(
             enabled ? 1 : 0
         );
     }
 }
 
 /* ============================================================
  * FRAMEBUFFER SIZE
  * ============================================================ */
 
 int ke_framebuffer_width(void) {
     int w = 0;
     int h = 0;
 
     if (window) {
         glfwGetFramebufferSize(
             window,
             &w,
             &h
         );
     }
 
     return w;
 }
 
 int ke_framebuffer_height(void) {
     int w = 0;
     int h = 0;
 
     if (window) {
         glfwGetFramebufferSize(
             window,
             &w,
             &h
         );
     }
 
     return h;
 }