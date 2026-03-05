# Technical Context: Anda

## Technologies Used

### Core Technologies
- **C++20**: Modern C++ standard with features like concepts, ranges, coroutines
- **CMake 3.31.10+**: Build system configuration
- **vcpkg**: C++ package manager with custom registry support

### UI Framework
- **Slint 1.14.0+**: Declarative UI framework
  - Custom vcpkg port (built from source)
  - Requires Rust toolchain (via rustbin and corrosion)
  - Live preview feature enabled
  - Generates C++ headers from .slint files

### Audio Libraries
- **PortAudio 19.7+**: Cross-platform audio I/O library
  - Used for real-time audio capture from input devices
  - Provides device enumeration and selection
  - Handles audio streaming in buffers/chunks
- **SoXR 0.1.3+**: High-quality audio resampling library
  - Used for audio format conversion and resampling

### AI/ML Libraries (To Be Integrated)
- **OpenAI Whisper** (or similar open-source models): Speech-to-text transcription
  - Will be integrated for real-time audio transcription
  - Processes audio chunks/buffers for low-latency transcription
- **Translation Model/API**: For real-time translation of transcribed text
  - To be determined (may use Whisper-based translation or separate model)

### Utility Libraries
- **fmt 12.0.0+**: Fast formatting library
- **spdlog 1.15.3+**: Fast C++ logging library

### Build Tools
- **Ninja**: Build system generator (via CMake presets)
- **clang-format**: Code formatting
- **clang-tidy**: Static analysis
- **cppcheck**: Additional static analysis

## Development Setup

### Compiler Support
- **Windows**: MSVC (primary), Clang-cl (alternative)
- **macOS**: Clang (Apple Clang)
- **Linux**: GCC

### Build Configurations
- **Debug**: Full debugging symbols, no optimizations
- **Release**: Optimized builds with LTO
- **Fast**: Maximum optimizations including fast-math

### Platform-Specific Requirements

#### Windows
- MSVC runtime: Static linking (`MultiThreaded$<$<CONFIG:Debug>:Debug>`)
- DLL copying: Slint DLLs copied to output directory
- Frameworks: None (native Windows)

#### macOS
- Deployment target: macOS 15.0+
- Frameworks: Foundation, AppKit, QuartzCore, OpenGL, Carbon
- Architecture: Auto-detected (x86_64 or arm64)

#### Linux
- Standard POSIX environment
- X11/Wayland support via Slint backends

## Dependency Management

### vcpkg Configuration
- **Default Registry**: Microsoft vcpkg (builtin, baseline locked)
- **Local Registry**: Custom ports in `vcpkg-registry/`
- **Auto-setup**: `cmake/toolchains/vcpkg.cmake` handles cloning and bootstrapping

### Custom Ports
1. **slint**: Custom build from GitHub (v1.14.0)
2. **rustbin**: Rust toolchain wrapper (required by Slint)
3. **corrosion**: Rust-C++ integration bridge
4. **soxr-config**: SoXR configuration package

## Code Quality Tools

### Formatting
- **clang-format**: Enforced via `.clang-format` config
- Targets: `format`, `check-format`

### Static Analysis
- **clang-tidy**: Enabled via `.clang-tidy` config
- **cppcheck**: Optional static analysis
- **MSVC /analyze**: Windows-specific analysis

### Header Validation
- Include header checks via CMake module

## Build Output Structure
```
.build/[preset-name]/[Config]/
├── bin/          # Executables
├── lib/          # Libraries
├── archive/      # Static libraries
└── assets/       # Copied assets
```

## Development Workflow
1. Configure: `cmake --preset <preset-name>`
2. Build: `cmake --build --preset <build-preset>`
3. Format: `cmake --build --target format`
4. Test: `ctest --preset <test-preset>`
5. Package: `cmake --build --preset <package-preset>`
