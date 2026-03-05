# Slint C++ Binding Pattern - Quick Reference

## Core Principle

**Globals = Communication Channel (No State)**  
**Services = Business Logic & State**  
**Presenter = Coordinator**

---

## File Structure

```
src/
├── main.cpp                    # Entry point, creates presenter
├── presenters/
│   └── app_presenter.hpp       # Coordinates UI ↔ Services
├── services/
│   ├── audio_service.hpp       # Audio device management
│   ├── transcription_service.hpp  # Transcription logic
│   └── language_service.hpp   # Language selection
└── ui/
    ├── app-window.slint        # Main UI
    └── globals.slint           # Communication bridge (no state!)
```

---

## Pattern Checklist

### ✅ DO:
- [ ] Keep globals as thin communication bridges
- [ ] Store all state in C++ service classes
- [ ] Use presenter to coordinate UI ↔ Services
- [ ] Use `slint::invoke_from_event_loop()` for thread-safe UI updates
- [ ] Make services testable independently
- [ ] Use callbacks/signals for reactive updates

### ❌ DON'T:
- [ ] Store state in globals
- [ ] Put business logic in UI callbacks
- [ ] Access services directly from UI
- [ ] Update UI from background threads without `invoke_from_event_loop()`
- [ ] Mix presentation logic with business logic

---

## Code Template

### 1. Service Class Template

```cpp
class MyService {
public:
    // State getters
    SomeType getState() const { return state_; }
    
    // Actions
    void doSomething() {
        // Update state
        state_ = new_value;
        // Notify presenter
        if (on_changed_) on_changed_();
    }
    
    // Signal registration
    void setOnChanged(std::function<void()> callback) {
        on_changed_ = callback;
    }

private:
    SomeType state_;
    std::function<void()> on_changed_;
};
```

### 2. Presenter Setup Template

```cpp
void AppPresenter::initialize() {
    // 1. Wire up global callbacks
    window_->global<MyAdapter>().on_action([this]() {
        my_service_->doSomething();
        syncToUI();
    });
    
    // 2. Wire up service signals
    my_service_->setOnChanged([this]() {
        slint::invoke_from_event_loop([this]() {
            syncToUI();
        });
    });
    
    // 3. Initial sync
    syncToUI();
}

void AppPresenter::syncToUI() {
    auto& adapter = window_->global<MyAdapter>();
    adapter.set_property(slint::SharedString(my_service_->getState()));
}
```

### 3. Thread-Safe Updates Template

```cpp
// From background thread (e.g., audio processing)
void AudioThread::processAudio() {
    // Update service
    transcription_service_->updateTranscription(text);
    // Service will notify presenter via callback
}

// In presenter (already set up)
transcription_service_->setOnChanged([this]() {
    slint::invoke_from_event_loop([this]() {
        // Safe to update UI here
        syncToUI();
    });
});
```

---

## Common Patterns

### Pattern 1: Simple Property Binding

**Slint:**
```slint
export global MyAdapter {
    in-out property <string> text: "";
}
```

**C++:**
```cpp
// Read
auto text = window_->global<MyAdapter>().get_text();

// Write
window_->global<MyAdapter>().set_text(slint::SharedString("Hello"));
```

### Pattern 2: Callback Binding

**Slint:**
```slint
export global MyAdapter {
    callback button-clicked();
}
```

**C++:**
```cpp
window_->global<MyAdapter>().on_button_clicked([this]() {
    my_service_->handleButtonClick();
    syncToUI();
});
```

### Pattern 3: Array Binding

**Slint:**
```slint
export global MyAdapter {
    in-out property <[string]> items: [];
}
```

**C++:**
```cpp
std::vector<slint::SharedString> items;
for (const auto& item : my_service_->getItems()) {
    items.push_back(slint::SharedString(item));
}
window_->global<MyAdapter>().set_items(slint::SharedStringVector(items));
```

### Pattern 4: Two-Way Binding

**Slint:**
```slint
export global MyAdapter {
    in-out property <int> value: 0;
}
```

**C++:**
```cpp
// Bind in presenter
auto& adapter = window_->global<MyAdapter>();
adapter.set_value(my_service_->getValue());

// Listen for changes
// Note: Two-way binding in Slint automatically updates both sides
// But you can still listen for changes if needed
```

---

## Migration Steps

1. **Identify state** - What data needs to persist?
2. **Create service** - Move state to service class
3. **Create presenter** - Move callback handlers to presenter
4. **Wire up** - Connect UI → Presenter → Service
5. **Add signals** - Service notifies presenter of changes
6. **Sync UI** - Presenter updates globals from service state

---

## Testing Strategy

### Unit Test Service (No UI)
```cpp
TEST(TranscriptionService, StartRecording) {
    TranscriptionService service;
    service.startRecording();
    EXPECT_TRUE(service.isRecording());
}
```

### Integration Test Presenter (Mock Services)
```cpp
TEST(AppPresenter, HandlesStartRecording) {
    auto mock_service = std::make_unique<MockTranscriptionService>();
    auto window = AppWindow::create();
    AppPresenter presenter(window, std::move(mock_service));
    
    presenter.initialize();
    // Trigger callback
    window->global<TranscriptionAdapter>().invoke_start_transcription();
    
    // Verify service was called
    EXPECT_TRUE(mock_service->wasStartCalled());
}
```

---

## Benefits Summary

| Aspect | Benefit |
|--------|---------|
| **Testability** | Services testable without UI |
| **Maintainability** | Clear separation of concerns |
| **Extensibility** | Easy to add new features |
| **Thread Safety** | Clear pattern for safe updates |
| **Reusability** | Services can be used elsewhere |
| **Debugging** | Easy to trace data flow |

---

## When to Use This Pattern

✅ **Use when:**
- You have complex business logic
- You need to test logic independently
- You have multiple UI screens
- You need thread-safe updates
- You want to reuse logic

❌ **Consider simpler approach when:**
- Very simple UI with minimal logic
- Prototyping quickly
- Single-use application

---

## Example: Adding a New Feature

**Step 1:** Create service
```cpp
class SettingsService {
    // ... state and methods
};
```

**Step 2:** Add to presenter
```cpp
class AppPresenter {
    std::unique_ptr<SettingsService> settings_service_;
    // ... wire up in initialize()
};
```

**Step 3:** Add global (if needed)
```slint
export global SettingsAdapter {
    in-out property <string> theme: "dark";
    callback theme-changed(string);
}
```

**Step 4:** Wire up in presenter
```cpp
window_->global<SettingsAdapter>().on_theme_changed([this](auto theme) {
    settings_service_->setTheme(theme);
});
```

Done! No changes to existing code needed.
