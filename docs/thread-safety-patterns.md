# Thread Safety Patterns for Slint C++ Integration

## Problem

Slint callbacks run on the **UI thread** (event loop thread). When these callbacks modify C++ state that's also accessed from other threads (e.g., audio processing thread), you get **race conditions**.

## Solution: Thread-Safe Service Layer

The key is to make your **service layer thread-safe** so it can be safely accessed from both:
- UI thread (via Slint callbacks)
- Background threads (audio processing, transcription, etc.)

---

## Pattern 1: Mutex Protection (Most Common)

### Service with Mutex Protection

```cpp
// src/services/transcription_service.hpp
#pragma once

#include <string>
#include <mutex>
#include <atomic>
#include <chrono>

class TranscriptionService {
public:
    enum class State {
        Idle,
        Recording,
        Paused
    };

    // Thread-safe getters (use mutex)
    State getState() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return state_;
    }

    bool isRecording() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return state_ == State::Recording;
    }

    std::string getTranscriptionText() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return transcription_text_;
    }

    float getDuration() const {
        std::lock_guard<std::mutex> lock(mutex_);
        if (state_ == State::Idle) return 0.0f;
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration<float>(
            now - start_time_).count();
        return accumulated_duration_ + 
            (state_ == State::Recording ? elapsed : 0.0f);
    }

    // Thread-safe setters (use mutex)
    void startRecording() {
        std::lock_guard<std::mutex> lock(mutex_);
        state_ = State::Recording;
        start_time_ = std::chrono::steady_clock::now();
        accumulated_duration_ = 0.0f;
        
        // Notify presenter (will be called on UI thread)
        if (on_state_changed_) {
            on_state_changed_();
        }
    }

    void pauseRecording() {
        std::lock_guard<std::mutex> lock(mutex_);
        if (state_ == State::Recording) {
            accumulated_duration_ += getDurationUnlocked();
            state_ = State::Paused;
            if (on_state_changed_) {
                on_state_changed_();
            }
        }
    }

    // Called from audio processing thread
    void updateTranscription(const std::string& text) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            transcription_text_ = text;
        }
        // Notify outside of lock to avoid deadlock
        if (on_text_changed_) {
            on_text_changed_();
        }
    }

    // Signal registration (called from UI thread only)
    void setOnStateChanged(std::function<void()> callback) {
        std::lock_guard<std::mutex> lock(mutex_);
        on_state_changed_ = callback;
    }

    void setOnTextChanged(std::function<void()> callback) {
        std::lock_guard<std::mutex> lock(mutex_);
        on_text_changed_ = callback;
    }

private:
    // Helper (assumes mutex is already locked)
    float getDurationUnlocked() const {
        if (state_ == State::Idle) return 0.0f;
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration<float>(
            now - start_time_).count();
        return accumulated_duration_ + 
            (state_ == State::Recording ? elapsed : 0.0f);
    }

    mutable std::mutex mutex_;  // mutable for const getters
    State state_ = State::Idle;
    std::string transcription_text_;
    std::string translation_text_;
    std::chrono::steady_clock::time_point start_time_;
    float accumulated_duration_ = 0.0f;
    
    // Callbacks (protected by mutex)
    std::function<void()> on_state_changed_;
    std::function<void()> on_text_changed_;
};
```

### Presenter (UI Thread Only)

```cpp
// src/presenters/app_presenter.cpp
void AppPresenter::initialize() {
    // Set up callbacks (runs on UI thread)
    window_->global<TranscriptionAdapter>().on_start_transcription([this]() {
        // This callback runs on UI thread
        transcription_service_->startRecording();
        // Service method is thread-safe, so this is safe
    });

    // Set up service signals (runs on UI thread)
    transcription_service_->setOnStateChanged([this]() {
        // This callback is invoked from service (could be any thread)
        // Use invoke_from_event_loop to ensure UI updates happen on UI thread
        slint::invoke_from_event_loop([this]() {
            syncTranscriptionState();
        });
    });

    transcription_service_->setOnTextChanged([this]() {
        // Called from audio processing thread
        slint::invoke_from_event_loop([this]() {
            syncTranscriptionState();
        });
    });
}
```

---

## Pattern 2: Atomic Operations (For Simple State)

**Best for:** Simple boolean flags or counters that don't need complex synchronization.

```cpp
class TranscriptionService {
public:
    void startRecording() {
        is_recording_.store(true, std::memory_order_release);
        // ... other initialization
    }

    bool isRecording() const {
        return is_recording_.load(std::memory_order_acquire);
    }

private:
    std::atomic<bool> is_recording_{false};
    std::atomic<float> duration_{0.0f};
};
```

**Note:** Use atomics only for simple types. For complex state (strings, structs), use mutexes.

---

## Pattern 3: Message Queue (Producer-Consumer)

**Best for:** High-frequency updates from background threads.

### Thread-Safe Message Queue

```cpp
// src/core/thread_safe_queue.hpp
#pragma once

#include <queue>
#include <mutex>
#include <condition_variable>

template<typename T>
class ThreadSafeQueue {
public:
    void push(const T& item) {
        std::lock_guard<std::mutex> lock(mutex_);
        queue_.push(item);
        condition_.notify_one();
    }

    bool tryPop(T& item) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (queue_.empty()) {
            return false;
        }
        item = queue_.front();
        queue_.pop();
        return true;
    }

    void waitAndPop(T& item) {
        std::unique_lock<std::mutex> lock(mutex_);
        condition_.wait(lock, [this] { return !queue_.empty(); });
        item = queue_.front();
        queue_.pop();
    }

private:
    std::queue<T> queue_;
    mutable std::mutex mutex_;
    std::condition_variable condition_;
};
```

### Service Using Message Queue

```cpp
class TranscriptionService {
public:
    // Called from audio processing thread
    void queueTranscriptionUpdate(const std::string& text) {
        update_queue_.push(text);
    }

    // Called from UI thread (via timer)
    void processUpdates() {
        std::string text;
        while (update_queue_.tryPop(text)) {
            {
                std::lock_guard<std::mutex> lock(mutex_);
                transcription_text_ = text;
            }
            if (on_text_changed_) {
                on_text_changed_();
            }
        }
    }

private:
    ThreadSafeQueue<std::string> update_queue_;
    mutable std::mutex mutex_;
    std::string transcription_text_;
    std::function<void()> on_text_changed_;
};
```

### Presenter Processing Queue

```cpp
void AppPresenter::initialize() {
    // Process updates every 100ms on UI thread
    update_timer_.start(slint::TimerMode::Repeated,
                       std::chrono::milliseconds(100),
                       [this]() {
        transcription_service_->processUpdates();
    });
}
```

---

## Pattern 4: Read-Write Lock (For Read-Heavy Workloads)

**Best for:** Many readers, few writers.

```cpp
#include <shared_mutex>

class TranscriptionService {
public:
    // Multiple threads can read simultaneously
    std::string getTranscriptionText() const {
        std::shared_lock<std::shared_mutex> lock(mutex_);
        return transcription_text_;
    }

    // Only one thread can write
    void updateTranscription(const std::string& text) {
        std::unique_lock<std::shared_mutex> lock(mutex_);
        transcription_text_ = text;
    }

private:
    mutable std::shared_mutex mutex_;
    std::string transcription_text_;
};
```

---

## Pattern 5: Lock-Free with Atomic Pointers (Advanced)

**Best for:** High-performance scenarios where you can tolerate some staleness.

```cpp
class TranscriptionService {
public:
    void updateTranscription(const std::string& text) {
        // Create new string (on any thread)
        auto new_text = std::make_shared<std::string>(text);
        
        // Atomically swap pointer (very fast)
        text_ptr_.store(new_text, std::memory_order_release);
        
        // Notify UI thread
        if (on_text_changed_) {
            on_text_changed_();
        }
    }

    std::string getTranscriptionText() const {
        // Get current pointer (very fast, no lock)
        auto ptr = text_ptr_.load(std::memory_order_acquire);
        return ptr ? *ptr : std::string();
    }

private:
    std::atomic<std::shared_ptr<std::string>> text_ptr_;
    std::function<void()> on_text_changed_;
};
```

---

## Complete Example: Thread-Safe Audio Service

```cpp
// src/services/audio_service.hpp
#pragma once

#include <string>
#include <vector>
#include <mutex>
#include <atomic>
#include <functional>
#include <memory>

class AudioService {
public:
    struct DeviceInfo {
        std::string name;
        int index;
    };

    // Thread-safe getters
    std::vector<DeviceInfo> getInputDevices() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return input_devices_;
    }

    int getSelectedInputDevice() const {
        return selected_input_.load(std::memory_order_acquire);
    }

    // Thread-safe setters (called from UI thread)
    void selectInputDevice(int index) {
        // Validate index
        {
            std::lock_guard<std::mutex> lock(mutex_);
            if (index < 0 || index >= input_devices_.size()) {
                return;
            }
        }
        
        // Update atomic (fast, no lock needed)
        int old_index = selected_input_.exchange(index, std::memory_order_acq_rel);
        
        // If changed, notify
        if (old_index != index && on_device_changed_) {
            on_device_changed_();
        }
    }

    // Called from audio thread
    void processAudioChunk(const float* samples, size_t count) {
        // Process audio (no locks needed for processing)
        // Only lock when updating shared state
        {
            std::lock_guard<std::mutex> lock(mutex_);
            // Update internal audio buffer
            audio_buffer_.assign(samples, samples + count);
        }
        
        // Notify UI thread
        if (on_audio_processed_) {
            on_audio_processed_();
        }
    }

    // Get audio data (called from UI thread)
    std::vector<float> getAudioBuffer() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return audio_buffer_;
    }

    // Signal registration (UI thread only)
    void setOnDeviceChanged(std::function<void()> callback) {
        std::lock_guard<std::mutex> lock(mutex_);
        on_device_changed_ = callback;
    }

    void setOnAudioProcessed(std::function<void()> callback) {
        std::lock_guard<std::mutex> lock(mutex_);
        on_audio_processed_ = callback;
    }

private:
    mutable std::mutex mutex_;
    std::vector<DeviceInfo> input_devices_;
    std::atomic<int> selected_input_{0};  // Atomic for frequent reads
    
    std::vector<float> audio_buffer_;  // Protected by mutex
    
    std::function<void()> on_device_changed_;
    std::function<void()> on_audio_processed_;
};
```

---

## Pattern 6: Immutable State Updates

**Best for:** Functional-style programming, easier reasoning.

```cpp
struct TranscriptionState {
    bool is_recording;
    std::string text;
    float duration;
};

class TranscriptionService {
public:
    // Get current state (snapshot)
    TranscriptionState getState() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return state_;
    }

    // Update state atomically
    void updateState(std::function<void(TranscriptionState&)> updater) {
        std::lock_guard<std::mutex> lock(mutex_);
        updater(state_);
        if (on_state_changed_) {
            on_state_changed_();
        }
    }

private:
    mutable std::mutex mutex_;
    TranscriptionState state_;
    std::function<void()> on_state_changed_;
};
```

**Usage:**

```cpp
// From UI thread
transcription_service_->updateState([](TranscriptionState& state) {
    state.is_recording = true;
    state.text = "";
});

// From audio thread
transcription_service_->updateState([](TranscriptionState& state) {
    state.text += new_text;
    state.duration += elapsed_time;
});
```

---

## Best Practices Summary

### ✅ DO:

1. **Protect all shared state** with mutexes or atomics
2. **Use `slint::invoke_from_event_loop()`** when updating UI from non-UI threads
3. **Keep locks short** - don't hold locks during expensive operations
4. **Use atomics** for simple flags/counters
5. **Document thread-safety** - which methods are safe from which threads
6. **Test with thread sanitizer** (`-fsanitize=thread`)

### ❌ DON'T:

1. **Don't hold locks during callbacks** - can cause deadlocks
2. **Don't update UI directly** from background threads
3. **Don't access Slint objects** from non-UI threads
4. **Don't use raw pointers** for shared state
5. **Don't ignore race conditions** - they will cause bugs

---

## Thread Safety Checklist

For each service method, ask:

- [ ] Is this method called from multiple threads?
- [ ] Is shared state accessed?
- [ ] Is it protected with mutex/atomic?
- [ ] Are callbacks invoked outside locks?
- [ ] Are UI updates wrapped in `invoke_from_event_loop()`?

---

## Example: Complete Thread-Safe Service

```cpp
class TranscriptionService {
public:
    // UI Thread Methods
    void startRecording() {
        std::lock_guard<std::mutex> lock(mutex_);
        state_ = State::Recording;
        start_time_ = std::chrono::steady_clock::now();
        notifyStateChanged();
    }

    // Audio Thread Methods
    void updateTranscription(const std::string& text) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            transcription_text_ = text;
        }
        // Notify outside lock
        notifyTextChanged();
    }

    // Any Thread Methods (thread-safe getters)
    bool isRecording() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return state_ == State::Recording;
    }

private:
    void notifyStateChanged() {
        // Callback may invoke UI updates, so use invoke_from_event_loop
        if (on_state_changed_) {
            slint::invoke_from_event_loop([this]() {
                on_state_changed_();
            });
        }
    }

    void notifyTextChanged() {
        if (on_text_changed_) {
            slint::invoke_from_event_loop([this]() {
                on_text_changed_();
            });
        }
    }

    mutable std::mutex mutex_;
    State state_;
    std::string transcription_text_;
    std::chrono::steady_clock::time_point start_time_;
    std::function<void()> on_state_changed_;
    std::function<void()> on_text_changed_;
};
```

---

## Testing Thread Safety

### Compile with Thread Sanitizer

```cmake
# In CMakeLists.txt
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    target_compile_options(${PROJECT_NAME} PRIVATE -fsanitize=thread)
    target_link_options(${PROJECT_NAME} PRIVATE -fsanitize=thread)
endif()
```

### Stress Test

```cpp
// Test multiple threads accessing service
void stressTest() {
    TranscriptionService service;
    
    std::vector<std::thread> threads;
    
    // UI thread simulation
    threads.emplace_back([&]() {
        for (int i = 0; i < 1000; ++i) {
            service.startRecording();
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
            service.stopRecording();
        }
    });
    
    // Audio thread simulation
    threads.emplace_back([&]() {
        for (int i = 0; i < 10000; ++i) {
            service.updateTranscription("Test " + std::to_string(i));
        }
    });
    
    // Reader thread simulation
    threads.emplace_back([&]() {
        for (int i = 0; i < 10000; ++i) {
            auto text = service.getTranscriptionText();
            (void)text;  // Use result
        }
    });
    
    for (auto& t : threads) {
        t.join();
    }
}
```

---

## Summary

**Key Principle:** Make your **service layer thread-safe**, not your presenter or UI code.

1. **Use mutexes** for complex shared state
2. **Use atomics** for simple flags/counters  
3. **Always use `invoke_from_event_loop()`** when updating UI from background threads
4. **Keep locks short** - release before callbacks
5. **Test with thread sanitizer** to catch race conditions

This ensures your Slint callbacks can safely modify C++ state even when that state is accessed from other threads!
