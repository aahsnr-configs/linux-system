Now I have everything needed. Let me give a full, organized answer.

---

## `llvm-core/polly` itself

Add **`clang-lto-env` only**. Do not add `polly-on-env`.

Polly is a high-level loop and data-locality optimizer. It uses an abstract mathematical representation based on integer polyhedra to analyze and optimize memory access patterns. Its own source code is C++ analysis/transformation infrastructure — not computation-heavy nested loops. Using Polly to compile Polly's own source gives no meaningful benefit, and adding `-fopenmp` from `polly-on-env` to its compilation is gratuitous. This is consistent with how you already treat `llvm-core/llvm` — `clang-lto-env` only.

---

## New packages worth adding from your installed list

Your `make.conf` already applies GCC + `-flto` globally, so every package not in `package.env` already gets GCC LTO. Adding these packages to `package.env` switches them to Clang + ThinLTO (and optionally Polly), which is most valuable where: Clang produces better vectorized code than GCC, Polly can exploit loop structure, or cross-language LTO interop with other Clang-built packages matters.

### `clang-lto-env` only

These have substantial C/C++ computation but either use their own SIMD/threading, don't have Polly-suitable loop structure, or the `-fopenmp` injection from `polly-on-env` would be risky.

| Package | Reason |
|---|---|
| `app-arch/zstd` | Compression is CPU-intensive; used system-wide by systemd, btrfs, zram |
| `app-arch/brotli` | Compression loops, used heavily by browsers and network libs |
| `app-arch/lz4` | Fast path compression used by kernel, dracut, systemd |
| `app-arch/xz-utils` | XZ has intensive math; already benefits from better vectorization |
| `media-video/mpv` | C-heavy media player; interoperates with your Clang-built ffmpeg and libplacebo |
| `media-libs/libplacebo` | GPU shader/pipeline library for mpv; C with tight loops |
| `media-libs/harfbuzz` | Complex C++ text shaping used by every GTK/Qt app; has SIMD paths that Clang handles better |
| `media-libs/freetype` | Font rendering loops; used by everything on screen |
| `x11-libs/cairo` | 2D graphics compositing loops; Clang vectorizes its inner loops well |
| `x11-libs/pango` | Text layout; works as a unit with harfbuzz/freetype |
| `dev-libs/icu` | Large Unicode library with heavy string processing loops |
| `dev-libs/boost` | Large C++ template library; ThinLTO prunes dead template instantiations well |
| `dev-libs/re2` | Regex matching — tight inner loops, Clang auto-vectorizes better |
| `dev-libs/libpcre2` | Same reasoning as re2 |
| `dev-libs/openssl` | Crypto C code benefits from Clang's better constant-folding and LTO |
| `dev-libs/jemalloc` | Memory allocator — hot path for every allocation; Clang produces tighter code |
| `dev-libs/libsodium` | Crypto library with SIMD-friendly loops |
| `media-libs/libjpeg-turbo` | JPEG codec C fallbacks (non-asm paths) benefit from Clang LTO |
| `media-libs/libjxl` | JPEG XL uses highway SIMD; Clang integrates better with highway than GCC |
| `media-libs/shaderc` | GLSL/HLSL shader compiler — part of your Vulkan/graphics stack |
| `media-sound/jack2` | Audio server; real-time audio loops benefit from Clang optimization |
| `media-sound/lame` | MP3 encoder has intensive psychoacoustic computation loops |
| `media-libs/opus` | Codec has tight signal processing loops |
| `media-libs/libvorbis` | Vorbis decode loops; pairs with libogg |
| `gui-wm/hyprland` | Hyprland explicitly requires Clang to build — it should be using Clang anyway. Add `clang-lto-env` to ensure LTO and consistent toolchain |
| `gui-libs/aquamarine` | Hyprland's rendering backend; same reasoning |
| `gui-libs/libadwaita` | GTK4 UI library, C with rendering loops |
| `x11-terms/kitty` | Terminal emulator with C/C++ rendering; Clang produces measurably better output |
| `net-libs/curl` | HTTP client used by almost everything; ThinLTO helps cross-module inlining |
| `net-libs/nghttp2` | HTTP/2 library with frame processing loops |
| `dev-libs/libgit2` | Git operations library; tight diff/pack loops |
| `media-libs/libde265` | HEVC decoder with nested loop decode passes |

### `clang-lto-env polly-on-env`

These have computation-heavy nested loops with no conflicting threading model — Polly's prime targets.

| Package | Reason |
|---|---|
| `media-libs/kvazaar` | HEVC encoder: rate-distortion loops are textbook polyhedral targets — tiling and loop fusion apply directly |
| `media-libs/libvmaf` | Per-frame video quality metric: nested array traversals over video buffers; Polly's tiling helps cache locality significantly |
| `media-libs/libde265` | Decoder prediction/transform loops with regular access patterns suitable for Polly |

### `clang-lto-env polly-plugin-env`

These benefit from Polly's loop transformations (tiling, data locality) but should **not** get `-fopenmp`/`-polly-parallel` because they either have their own threading or the parallelism overhead would be counterproductive. Use your `polly-plugin-env` file (the lighter one you already reference for mesa/yazi) instead of `polly-on-env`.

| Package | Reason |
|---|---|
| `sci-libs/fftw` | FFT is Polly's canonical loop optimization target — tiling transforms are highly effective. However, FFTW has its own OpenMP threading (via `-lfftw3_omp`). Injecting `-fopenmp -polly-parallel` from `polly-on-env` on top of FFTW's own threading would create conflicting parallelism. Use `polly-plugin-env` (Polly without OpenMP) instead |
| `app-arch/zstd` | Has inner compression loops that benefit from tiling, but `-polly-parallel` is not needed — zstd manages its own thread pool |
| `media-libs/libjxl` | Transform loops benefit from Polly tiling; but uses highway SIMD internally, so avoid `-polly-parallel` interference |

---

### Packages to explicitly leave alone

- All `dev-haskell/*` — GHC compiles Haskell code, CFLAGS only affect GHC's C runtime (RTS). Adding `-fopenmp` to GHC's RTS would break it.
- `sci-libs/openblas` — Dominated by hand-written assembly for hot paths. Polly analyzing these would produce worse code than the existing asm.
- `dev-cpp/highway` — Explicit SIMD intrinsics library; Polly's vectorizer would interfere with its manually crafted SIMD.
- `dev-qt/*` — Qt's build system does its own flag filtering; Clang+LTO causes well-documented issues with Qt's moc-generated code.
- `dev-lang/perl`, `dev-lang/ruby` — Interpreter runtimes; `-fopenmp` injection into extension compilation is unreliable.
- `sys-libs/glibc`, `sys-devel/gcc` — Must build with GCC; never add Clang env files.
