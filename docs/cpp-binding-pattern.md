# C++ Binding Pattern for Slint UI

## Recommended Architecture: Presenter/Controller Pattern with Dependency Injection

### Overview

This pattern separates concerns into three layers:

1. **UI Layer (Slint)**: Pure presentation, no business logic
2. **Presenter/Controller Layer (C++)**: Coordinates UI updates and user actions
3. **Service/Model Layer (C++)**: Business logic and state management

### Key Principles

- **Globals are thin communication bridges** - They only pass data, never store state
- **State lives in C++ classes** - Easy to test, extend, and maintain
- **Presenter coordinates everything** - Single point of control for UI interactions
- **Services are independent** - Can be used without UI, tested separately

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Slint UI Layer                        │
│  (app-window.slint, components/*.slint)                 │
│  - Pure presentation                                      │
│  - Binds to globals for data                            │
│  - Triggers callbacks for actions                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ (reads/writes via globals)
                     │
┌────────────────────▼────────────────────────────────────┐
│              Presenter/Controller Layer                   │
│  (AppPresenter class)                                    │
│  - Listens to global callbacks                           │
│  - Updates globals from service state                   │
│  - Coordinates between UI and services                    │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ (calls methods, observes state)
                     │
┌────────────────────▼────────────────────────────────────┐
│              Service/Model Layer                         │
│  (AudioService, TranscriptionService, etc.)              │
│  - Holds actual state                                    │
│  - Implements business logic                            │
│  - Can emit signals/events for state changes             │
└─────────────────────────────────────────────────────────┘
```

---

## Implementation Structure

### 1. Service Classes (Business Logic & State)

```cpp
// src/services/audio_service.hpp
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <memory>

class AudioService {
public:
    struct DeviceInfo {
        std::string name;
        int index;
    };

    // State getters
    std::vector<DeviceInfo> getInputDevices() const;
    std::vector<DeviceInfo> getOutputDevices() const;
    int getSelectedInputDevice() const { return selected_input_device_; }
    int getSelectedOutputDevice() const { return selected_output_device_; }

    // Actions
    void selectInputDevice(int index);
    void selectOutputDevice(int index);

    // Signals (for notifying presenter of state changes)
    using DeviceListChangedCallback = std::function<void()>;
    void onDeviceListChanged(DeviceListChangedCallback callback);

private:
    std::vector<DeviceInfo> input_devices_;
    std::vector<DeviceInfo> output_devices_;
    int selected_input_device_ = 0;
    int selected_output_device_ = 0;
    DeviceListChangedCallback device_list_changed_callback_;
};
```

```cpp
// src/services/transcription_service.hpp
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <chrono>

class TranscriptionService {
public:
    enum class State {
        Idle,
        Recording,
        Paused
    };

    // State getters
    State getState() const { return state_; }
    bool isRecording() const { return state_ == State::Recording; }
    bool isPaused() const { return state_ == State::Paused; }
    float getDuration() const;
    std::string getTranscriptionText() const { return transcription_text_; }
    std::string getTranslationText() const { return translation_text_; }
    std::string getWaveformPath() const { return waveform_path_; }

    // Actions
    void startRecording();
    void pauseRecording();
    void continueRecording();
    void stopRecording();
    void saveAudio();
    void clearAll();

    // Update methods (called from audio processing thread)
    void updateTranscription(const std::string& text);
    void updateTranslation(const std::string& text);
    void updateWaveform(const std::vector<float>& samples, int width, int height);

    // Signals
    using StateChangedCallback = std::function<void()>;
    using TextChangedCallback = std::function<void()>;
    void onStateChanged(StateChangedCallback callback);
    void onTextChanged(TextChangedCallback callback);

private:
    State state_ = State::Idle;
    std::string transcription_text_;
    std::string translation_text_;
    std::string waveform_path_;
    std::chrono::steady_clock::time_point recording_start_time_;
    std::chrono::steady_clock::time_point paused_time_;
    float accumulated_duration_ = 0.0f;

    StateChangedCallback state_changed_callback_;
    TextChangedCallback text_changed_callback_;
};
```

### 2. Presenter Class (Coordinates UI & Services)

```cpp
// src/presenters/app_presenter.hpp
#pragma once

#include "app-window.h"
#include "../services/audio_service.hpp"
#include "../services/transcription_service.hpp"
#include "../services/language_service.hpp"
#include <memory>
#include <slint.h>

class AppPresenter {
public:
    AppPresenter(std::shared_ptr<AppWindow> window);

    // Initialize - sets up all bindings
    void initialize();

private:
    // Service references
    std::shared_ptr<AppWindow> window_;
    std::unique_ptr<AudioService> audio_service_;
    std::unique_ptr<TranscriptionService> transcription_service_;
    std::unique_ptr<LanguageService> language_service_;

    // Timer for periodic updates
    slint::Timer update_timer_;

    // Callback handlers (called from Slint globals)
    void handleInputDeviceSelected(int index);
    void handleOutputDeviceSelected(int index);
    void handleSourceLanguageSelected(int index);
    void handleTargetLanguageSelected(int index);
    void handleStartTranscription();
    void handlePauseTranscription();
    void handleContinueTranscription();
    void handleStopTranscription();
    void handleSaveAudio();
    void handleClearAll();

    // Update methods (sync service state to UI)
    void updateDeviceLists();
    void updateTranscriptionState();
    void updateLanguageLists();
    void updateWaveform();

    // Service signal handlers
    void onAudioServiceStateChanged();
    void onTranscriptionServiceStateChanged();
    void onTranscriptionTextChanged();
};
```

```cpp
// src/presenters/app_presenter.cpp
#include "app_presenter.hpp"
#include "../services/audio_service.hpp"
#include "../services/transcription_service.hpp"
#include "../services/language_service.hpp"
#include <slint.h>

AppPresenter::AppPresenter(std::shared_ptr<AppWindow> window)
    : window_(window)
    , audio_service_(std::make_unique<AudioService>())
    , transcription_service_(std::make_unique<TranscriptionService>())
    , language_service_(std::make_unique<LanguageService>())
{
}

void AppPresenter::initialize() {
    // Set up global callback handlers
    window_->global<AudioDeviceAdapter>().on_input_device_selected([this](int index) {
        handleInputDeviceSelected(index);
    });

    window_->global<AudioDeviceAdapter>().on_output_device_selected([this](int index) {
        handleOutputDeviceSelected(index);
    });

    window_->global<TranscriptionAdapter>().on_start_transcription([this]() {
        handleStartTranscription();
    });

    window_->global<TranscriptionAdapter>().on_pause_transcription([this]() {
        handlePauseTranscription();
    });

    window_->global<TranscriptionAdapter>().on_continue_transcription([this]() {
        handleContinueTranscription();
    });

    window_->global<TranscriptionAdapter>().on_stop_transcription([this]() {
        handleStopTranscription();
    });

    window_->global<TranscriptionAdapter>().on_save_audio([this]() {
        handleSaveAudio();
    });

    window_->global<TranscriptionAdapter>().on_clear_all([this]() {
        handleClearAll();
    });

    // Set up service signal handlers
    audio_service_->onDeviceListChanged([this]() {
        onAudioServiceStateChanged();
    });

    transcription_service_->onStateChanged([this]() {
        onTranscriptionServiceStateChanged();
    });

    transcription_service_->onTextChanged([this]() {
        onTranscriptionTextChanged();
    });

    // Initial UI update
    updateDeviceLists();
    updateLanguageLists();
    updateTranscriptionState();

    // Set up periodic timer for waveform updates
    update_timer_.start(slint::TimerMode::Repeated, std::chrono::milliseconds(16), [this]() {
        updateWaveform();
    });
}

void AppPresenter::handleInputDeviceSelected(int index) {
    audio_service_->selectInputDevice(index);
    // Update UI immediately
    window_->global<AudioDeviceAdapter>().set_selected_input_device(index);
}

void AppPresenter::handleStartTranscription() {
    transcription_service_->startRecording();
    updateTranscriptionState();
}

void AppPresenter::updateTranscriptionState() {
    auto& adapter = window_->global<TranscriptionAdapter>();
    
    adapter.set_is_recording(transcription_service_->isRecording());
    adapter.set_is_paused(transcription_service_->isPaused());
    adapter.set_recording_duration(transcription_service_->getDuration());
    adapter.set_transcription_text(
        slint::SharedString(transcription_service_->getTranscriptionText()));
    adapter.set_translation_text(
        slint::SharedString(transcription_service_->getTranslationText()));
    adapter.set_waveform_path(
        slint::SharedString(transcription_service_->getWaveformPath()));
}

void AppPresenter::updateDeviceLists() {
    auto& adapter = window_->global<AudioDeviceAdapter>();
    
    // Convert service device info to Slint string arrays
    auto input_devices = audio_service_->getInputDevices();
    std::vector<slint::SharedString> input_names;
    for (const auto& device : input_devices) {
        input_names.push_back(slint::SharedString(device.name));
    }
    adapter.set_input_devices(slint::SharedStringVector(input_names));

    auto output_devices = audio_service_->getOutputDevices();
    std::vector<slint::SharedString> output_names;
    for (const auto& device : output_devices) {
        output_names.push_back(slint::SharedString(device.name));
    }
    adapter.set_output_devices(slint::SharedStringVector(output_names));

    // Update selected indices
    adapter.set_selected_input_device(audio_service_->getSelectedInputDevice());
    adapter.set_selected_output_device(audio_service_->getSelectedOutputDevice());
}

void AppPresenter::onTranscriptionServiceStateChanged() {
    // Called when service state changes (from any thread)
    slint::invoke_from_event_loop([this]() {
        updateTranscriptionState();
    });
}

void AppPresenter::onTranscriptionTextChanged() {
    // Called when transcription text changes (from audio processing thread)
    slint::invoke_from_event_loop([this]() {
        auto& adapter = window_->global<TranscriptionAdapter>();
        adapter.set_transcription_text(
            slint::SharedString(transcription_service_->getTranscriptionText()));
        adapter.set_translation_text(
            slint::SharedString(transcription_service_->getTranslationText()));
    });
}
```

### 3. Main Function (Entry Point)

```cpp
// src/main.cpp
#include "presenters/app_presenter.hpp"
#include "app-window.h"
#include <slint.h>

int main() {
    // Create UI window
    auto window = AppWindow::create();

    // Create presenter (coordinates UI and services)
    AppPresenter presenter(window);
    presenter.initialize();

    // Show window and run event loop
    window->show();
    slint::run_event_loop();

    return 0;
}
```

---

## Benefits of This Pattern

### 1. **Separation of Concerns**
- UI is pure presentation
- Services contain business logic
- Presenter coordinates between them

### 2. **Testability**
- Services can be tested independently (no UI needed)
- Presenter can be tested with mock services
- UI can be tested with mock presenters

### 3. **Maintainability**
- Clear responsibilities for each class
- Easy to find where logic lives
- Changes in one layer don't affect others

### 4. **Extensibility**
- Add new features by adding new services
- UI changes don't require service changes
- Can swap implementations (e.g., different audio backends)

### 5. **Thread Safety**
- Services can run on background threads
- Presenter handles thread-safe UI updates using `invoke_from_event_loop()`

### 6. **No State in Globals**
- Globals are pure communication channels
- All state lives in C++ classes
- Easy to reason about and debug

---

## Alternative: Lock-Free Patterns (For Real-Time Performance)

If you need **real-time performance** (e.g., audio processing), mutexes may introduce latency. Consider lock-free patterns:

- **Lock-free queues** - Zero-lock communication between threads
- **Separate data ownership** - Each thread owns its data, copy across boundaries
- **Ring buffers** - High-throughput audio sample streaming
- **Copy-on-write** - Immutable state with atomic pointer swaps

See `lock-free-patterns.md` for detailed implementations.

**When to use:**
- Real-time audio processing
- High-frequency updates (>1000/sec)
- Low-latency requirements (<1ms)
- Predictable performance needed

**When mutexes are fine:**
- Low-frequency updates (<100/sec)
- Non-real-time operations
- Simpler code is more important than microsecond latency

---

## Alternative: Observer Pattern for Reactive Updates

If you want more reactive updates, you can use an observer pattern:

```cpp
// src/core/observable.hpp
#pragma once
#include <functional>
#include <vector>

template<typename T>
class Observable {
public:
    using Observer = std::function<void(const T&)>;
    
    void subscribe(Observer observer) {
        observers_.push_back(observer);
    }
    
    void notify(const T& value) {
        for (auto& observer : observers_) {
            observer(value);
        }
    }

private:
    std::vector<Observer> observers_;
};
```

Then in your service:

```cpp
class TranscriptionService {
public:
    Observable<std::string> transcriptionText;
    Observable<State> state;
    
    void updateTranscription(const std::string& text) {
        transcription_text_ = text;
        transcriptionText.notify(text);  // Notify all observers
    }
};
```

And in presenter:

```cpp
void AppPresenter::initialize() {
    transcription_service_->transcriptionText.subscribe([this](const std::string& text) {
        slint::invoke_from_event_loop([this, text]() {
            window_->global<TranscriptionAdapter>()
                .set_transcription_text(slint::SharedString(text));
        });
    });
}
```

---

## Migration Path

1. **Start with services**: Extract business logic into service classes
2. **Create presenter**: Move callback handlers from `main.cpp` to presenter
3. **Update globals**: Keep globals as-is (they're already thin)
4. **Wire up**: Connect presenter to services and UI
5. **Test**: Write unit tests for services, integration tests for presenter

---

## Example: Adding a New Feature

To add a new feature (e.g., audio effects):

1. **Create service**: `src/services/audio_effects_service.hpp`
2. **Add to presenter**: `AppPresenter` creates and manages the service
3. **Add global** (if needed): `export global AudioEffectsAdapter { ... }`
4. **Wire up**: Presenter connects service to global
5. **Update UI**: Add UI components that bind to the global

No changes needed to existing services or UI components!
