# System Patterns: Anda

## Architecture Overview

### Component Structure
```
Application Layer (C++)
    ↓
Slint UI Layer (.slint files)
    ↓
Generated C++ Bindings
    ↓
Business Logic (C++)
```

## Slint Integration Pattern

### Component Generation Flow
1. `.slint` files define UI components
2. CMake `slint_target_sources()` compiles Slint files
3. Slint compiler generates C++ headers (e.g., `app-window.h`)
4. C++ code includes generated headers and instantiates components

### Component Lifecycle
```cpp
// 1. Create component instance
auto app = AppWindow::create();  // Returns ComponentHandle<AppWindow>

// 2. Set up callbacks
app->on_request_increase_value([&]() { /* handler */ });

// 3. Update properties
app->set_counter(42);
app->set_drawCommands(slint::SharedString("..."));

// 4. Show window and run event loop
app->show();
slint::run_event_loop();
```

## Data Flow Patterns

### Property Binding
- **One-way binding**: `property: expression` in Slint
- **Two-way binding**: `property <=> other.property` in Slint
- **C++ access**: `get_<property>()` and `set_<property>()` methods

### Callback Pattern
- **Slint declaration**: `callback callback-name();`
- **C++ handler**: `on_<callback_name>(lambda)` method
- **Thread safety**: Use `slint::invoke_from_event_loop()` from other threads

### Global Singletons Pattern
- **Slint declaration**: `export global AdapterName { ... }`
- **C++ access**: `app->global<AdapterName>()`
- **Usage**: Shared state across components, bridge to C++ backend

## Model Pattern (Arrays/Lists)

### VectorModel Usage
```cpp
// Create model from vector
std::vector<float> data = {0.1f, 0.5f, 0.9f};
auto model = std::make_shared<slint::VectorModel<float>>(data);

// Assign to Slint property
app->global<Adapter>().set_audio_levels(model);
```

### Model Types Available
- `slint::VectorModel<T>` - Backed by std::vector
- `slint::FilterModel<T>` - Filtered view
- `slint::SortModel<T>` - Sorted view
- Custom models inheriting from `slint::Model<T>`

## Timer Pattern

### Periodic Updates
```cpp
slint::Timer timer;
timer.start(
    slint::TimerMode::Repeated,
    std::chrono::milliseconds(16),  // ~60 FPS
    [&]() {
        // Update UI state
        app->set_drawCommands(slint::SharedString(path));
    }
);
```

## Asset Management Pattern

### Asset Copying
- **Source**: `assets/` directory
- **Destination**: `$<CONFIG>/bin/assets/` in build output
- **Mechanism**: Custom CMake function `copy_assets_to_build_dir()`
- **Tracking**: Stamp file prevents unnecessary copies

## Build System Patterns

### CMake Preset Pattern
- **Configure presets**: Platform-specific toolchain selection
- **Build presets**: Configuration-specific builds (Debug/Release/Fast)
- **Test presets**: Platform-specific test execution
- **Package presets**: Platform-specific packaging (ZIP, MSI, DEB, DMG)

### Toolchain Pattern
- **Base toolchain**: `vcpkg.cmake` (auto-setup vcpkg)
- **Platform toolchains**: Inherit from base, add compiler-specific flags
- **Conditional inclusion**: Check for `VCPKG_ROOT` environment variable

## Error Handling Patterns

### Thread Safety
- UI updates must happen on event loop thread
- Use `slint::invoke_from_event_loop()` from worker threads
- Use `slint::blocking_invoke_from_event_loop()` for blocking operations

### Property Access
- Properties accessed via getter/setter methods
- Type-safe access through generated C++ API
- SharedString for string properties (reference-counted)

## Code Organization Patterns

### File Structure
- **UI components**: `src/ui/*.slint`
- **Source code**: `src/*.cpp`, `src/*.hpp`
- **Assets**: `assets/`
- **Build config**: `cmake/`

### Component Composition
- **Base components**: Reusable UI components (e.g., `WaveformVisualizer`)
- **Main components**: Top-level windows (e.g., `AppWindow`)
- **Global adapters**: Shared state singletons

## Dependency Injection Pattern

### Global Adapters
- Declared in Slint: `export global AdapterName { ... }`
- Accessed in C++: `app->global<AdapterName>()`
- Used for: Bridging UI and business logic, shared state

### Callback Injection
- Callbacks declared in Slint components
- Handlers set in C++ code via `on_<callback>()` methods
- Enables: UI events triggering C++ business logic
