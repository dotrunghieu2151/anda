# Separate Data Ownership Pattern - Detailed Explanation

## Core Concept

**Each thread owns its data completely.** There is **no shared mutable state** between threads. Communication happens only through **lock-free queues** that copy data.

```
┌─────────────────────────┐         ┌─────────────────────────┐
│   Audio Thread          │         │      UI Thread          │
│                         │         │                         │
│  Owns:                  │         │  Owns:                 │
│  - audio_buffer_        │         │  - display_text_        │
│  - raw_samples_         │         │  - waveform_path_      │
│  - is_recording_        │         │  - is_recording_        │
│                         │         │                         │
│  No locks needed!       │         │  No locks needed!       │
│  No synchronization!    │         │  No synchronization!    │
└───────────┬─────────────┘         └───────────┬─────────────┘
            │                                   │
            │  Copy data via                    │
            │  lock-free queue ─────────────────┘
            │  (only synchronization point)
```

---

## Why This Works

### Traditional Approach (Shared State)

```cpp
// ❌ PROBLEM: Both threads access same data
class TranscriptionService {
    std::string transcription_text_;  // Shared!
    std::mutex mutex_;                // Need lock!
    
    // Audio thread
    void updateText(const std::string& text) {
        std::lock_guard<std::mutex> lock(mutex_);  // Lock!
        transcription_text_ = text;                // Write
    }
    
    // UI thread
    std::string getText() const {
        std::lock_guard<std::mutex> lock(mutex_);  // Lock!
        return transcription_text_;                 // Read
    }
};
```

**Problems:**
- Lock contention (threads wait for each other)
- Cache line bouncing (both threads access same memory)
- Unpredictable latency (lock wait time varies)
- Not suitable for real-time audio

### Separate Ownership Approach

```cpp
// ✅ SOLUTION: Each thread owns its data
class TranscriptionService {
    // Audio thread owns this (only accessed from audio thread)
    struct AudioThreadData {
        std::string transcription_text_;
        std::vector<float> audio_samples_;
        bool is_recording_;
    } audio_data_;
    
    // UI thread owns this (only accessed from UI thread)
    struct UIThreadData {
        std::string display_text_;
        std::string waveform_path_;
        bool is_recording_;
    } ui_data_;
    
    // Communication only (lock-free queue)
    LockFreeQueue<std::string> text_queue_;
    
    // Audio thread methods (no locks!)
    void updateTranscription(const std::string& text) {
        // Update audio thread's own data - no synchronization needed!
        audio_data_.transcription_text_ = text;
        
        // Send copy to UI thread via queue
        text_queue_.push(text);  // Lock-free push
    }
    
    // UI thread methods (no locks!)
    void syncToUI() {
        // Process queue (lock-free)
        std::string chunk;
        while (text_queue_.tryPop(chunk)) {
            ui_data_.display_text_ += chunk;  // Update UI data
        }
    }
    
    std::string getDisplayText() const {
        return ui_data_.display_text_;  // Read own data - no sync!
    }
};
```

**Benefits:**
- ✅ Zero locks in hot paths
- ✅ No cache line contention
- ✅ Predictable performance
- ✅ Real-time safe

---

## Detailed Example: Transcription Service

### Step 1: Define Separate Data Structures

```cpp
class TranscriptionService {
public:
    // Data owned by audio processing thread
    struct AudioThreadState {
        std::string current_transcription;  // Latest transcription
        std::vector<float> audio_buffer;    // Raw audio samples
        bool is_recording = false;
        int sample_rate = 44100;
        float recording_duration = 0.0f;
        
        // Audio thread can read/write these freely - no locks!
    };
    
    // Data owned by UI thread
    struct UIThreadState {
        std::string display_text;           // Text shown in UI
        std::string waveform_path;          // SVG path for visualization
        bool is_recording = false;
        float display_duration = 0.0f;
        
        // UI thread can read/write these freely - no locks!
    };
    
private:
    // Each thread's data (separate ownership)
    AudioThreadState audio_state_;
    UIThreadState ui_state_;
    
    // Communication channels (lock-free)
    LockFreeQueue<std::string> transcription_queue_;
    LockFreeQueue<std::vector<float>> audio_queue_;
    LockFreeQueue<bool> state_queue_;  // For recording state changes
};
```

### Step 2: Audio Thread Methods (No Synchronization!)

```cpp
class TranscriptionService {
public:
    // Called from audio callback (real-time, lock-free!)
    void processAudioChunk(const float* samples, size_t count) {
        // Update audio thread's own data - no locks!
        audio_state_.audio_buffer.assign(samples, samples + count);
        
        // Process audio (your transcription logic)
        if (audio_state_.is_recording) {
            std::string transcription = transcribeAudio(samples, count);
            audio_state_.current_transcription = transcription;
            audio_state_.recording_duration += count / float(audio_state_.sample_rate);
            
            // Send copy to UI thread via queue (lock-free!)
            transcription_queue_.push(transcription);
            
            // Send audio samples for visualization (lock-free!)
            std::vector<float> samples_copy(samples, samples + count);
            audio_queue_.push(std::move(samples_copy));
        }
    }
    
    // Called from audio thread to start recording
    void startRecording() {
        // Update audio thread's own state - no locks!
        audio_state_.is_recording = true;
        audio_state_.recording_duration = 0.0f;
        audio_state_.current_transcription.clear();
        
        // Notify UI thread via queue
        state_queue_.push(true);  // Lock-free!
    }
    
    // Called from audio thread to stop recording
    void stopRecording() {
        audio_state_.is_recording = false;
        state_queue_.push(false);  // Lock-free!
    }
    
    // Audio thread can read its own data freely
    bool isRecordingOnAudioThread() const {
        return audio_state_.is_recording;  // No synchronization needed!
    }
    
    float getRecordingDurationOnAudioThread() const {
        return audio_state_.recording_duration;  // No synchronization needed!
    }
};
```

### Step 3: UI Thread Methods (No Synchronization!)

```cpp
class TranscriptionService {
public:
    // Called from UI thread periodically (e.g., every 50ms)
    void syncToUI() {
        // Process transcription updates (lock-free!)
        std::string chunk;
        while (transcription_queue_.tryPop(chunk)) {
            ui_state_.display_text += chunk;  // Update UI data
        }
        
        // Process audio samples for visualization
        std::vector<float> samples;
        while (audio_queue_.tryPop(samples)) {
            ui_state_.waveform_path = samplesToSVGPath(samples);
        }
        
        // Process state changes
        bool state;
        while (state_queue_.tryPop(state)) {
            ui_state_.is_recording = state;
            if (!state) {
                ui_state_.display_duration = 0.0f;
            }
        }
        
        // Update duration (approximate, based on last update)
        if (ui_state_.is_recording) {
            ui_state_.display_duration += 0.05f;  // ~50ms per call
        }
        
        // Notify presenter if anything changed
        if (on_ui_changed_) {
            on_ui_changed_();
        }
    }
    
    // UI thread can read its own data freely
    std::string getDisplayText() const {
        return ui_state_.display_text;  // No synchronization needed!
    }
    
    std::string getWaveformPath() const {
        return ui_state_.waveform_path;  // No synchronization needed!
    }
    
    bool isRecordingOnUIThread() const {
        return ui_state_.is_recording;  // No synchronization needed!
    }
    
    float getDisplayDuration() const {
        return ui_state_.display_duration;  // No synchronization needed!
    }
    
    // UI thread can update its own state
    void clearDisplay() {
        ui_state_.display_text.clear();
        ui_state_.waveform_path.clear();
        if (on_ui_changed_) {
            on_ui_changed_();
        }
    }
    
private:
    std::function<void()> on_ui_changed_;
};
```

### Step 4: Presenter Integration

```cpp
class AppPresenter {
public:
    void initialize() {
        // Set up UI sync timer (runs on UI thread)
        sync_timer_.start(slint::TimerMode::Repeated,
                         std::chrono::milliseconds(50),  // 20 FPS
                         [this]() {
            transcription_service_->syncToUI();
            syncTranscriptionState();
        });
        
        // Set up callbacks
        transcription_service_->setOnUIChanged([this]() {
            syncTranscriptionState();
        });
        
        // Handle UI actions (runs on UI thread)
        window_->global<TranscriptionAdapter>().on_start_transcription([this]() {
            transcription_service_->startRecording();  // Queues message to audio thread
        });
    }
    
private:
    void syncTranscriptionState() {
        auto& adapter = window_->global<TranscriptionAdapter>();
        
        // Read from UI thread's data (no synchronization needed!)
        adapter.set_transcription_text(
            slint::SharedString(transcription_service_->getDisplayText()));
        adapter.set_waveform_path(
            slint::SharedString(transcription_service_->getWaveformPath()));
        adapter.set_is_recording(
            transcription_service_->isRecordingOnUIThread());
        adapter.set_recording_duration(
            transcription_service_->getDisplayDuration());
    }
    
    slint::Timer sync_timer_;
};
```

---

## Key Principles

### 1. **Single Writer Principle**

Each piece of data has **exactly one writer thread**:

```cpp
// ✅ CORRECT: Audio thread is the only writer
audio_state_.current_transcription = text;  // Only audio thread writes

// ✅ CORRECT: UI thread is the only writer  
ui_state_.display_text = text;  // Only UI thread writes

// ❌ WRONG: Multiple writers
shared_state_.text = text;  // Both threads write - needs lock!
```

### 2. **Copy Semantics**

Data is **copied** across thread boundaries, never shared:

```cpp
// ✅ CORRECT: Copy data
std::string copy = audio_state_.current_transcription;
transcription_queue_.push(copy);  // Copy goes to UI thread

// ❌ WRONG: Share reference
transcription_queue_.push(&audio_state_.current_transcription);  // Dangerous!
```

### 3. **Unidirectional Communication**

Data flows in **one direction** (audio → UI):

```cpp
// ✅ CORRECT: Audio → UI only
transcription_queue_.push(text);  // Audio thread pushes
// UI thread pops

// ❌ WRONG: Bidirectional sharing
shared_text_ = text;  // Both threads read/write - needs lock!
```

### 4. **Periodic Synchronization**

UI thread processes queues **periodically**, not continuously:

```cpp
// ✅ CORRECT: Process every 50ms
sync_timer_.start(50ms, [this]() {
    service_->syncToUI();  // Batch process all queued updates
});

// ❌ WRONG: Process on every update
void onTranscriptionUpdate() {
    syncToUI();  // Too frequent, wastes CPU
}
```

---

## Advanced: Handling Bidirectional Communication

Sometimes you need UI → Audio communication too. Use **separate queues**:

```cpp
class TranscriptionService {
    // Audio → UI queues
    LockFreeQueue<std::string> transcription_queue_;
    LockFreeQueue<std::vector<float>> audio_queue_;
    
    // UI → Audio queues  
    LockFreeQueue<Command> command_queue_;  // Start, stop, pause commands
    
    // Audio thread processes commands
    void processCommands() {
        Command cmd;
        while (command_queue_.tryPop(cmd)) {
            switch (cmd.type) {
                case Command::Start:
                    audio_state_.is_recording = true;
                    break;
                case Command::Stop:
                    audio_state_.is_recording = false;
                    break;
            }
        }
    }
    
    // UI thread sends commands
    void startRecording() {
        command_queue_.push(Command{Command::Start});  // Lock-free!
    }
};
```

---

## Performance Characteristics

### Memory Access Pattern

```
Audio Thread Cache          UI Thread Cache
──────────────────          ──────────────
audio_state_ (hot)         ui_state_ (hot)
  ↓                            ↓
  │ (separate cache lines)    │
  │                            │
  └──────── Queue ────────────┘
     (separate cache line)
```

**Benefits:**
- No false sharing (separate cache lines)
- No cache line bouncing
- Predictable memory access patterns

### Latency Breakdown

```
Audio Thread:
  Update audio_state_        : ~1ns (L1 cache)
  Push to queue              : ~20ns (lock-free)
  Total                      : ~21ns ✅

UI Thread (every 50ms):
  Pop from queue             : ~20ns (lock-free)
  Update ui_state_           : ~1ns (L1 cache)
  Total                      : ~21ns ✅
```

Compare to mutex approach:
```
Audio Thread:
  Lock mutex                 : ~100ns-10μs (unpredictable!)
  Update shared state         : ~1ns
  Unlock mutex               : ~100ns-10μs
  Total                      : ~200ns-20μs ❌
```

---

## When to Use This Pattern

### ✅ Use When:

- **Real-time audio processing** - Need predictable latency
- **High-frequency updates** - Audio samples at 44.1kHz
- **Separate concerns** - Audio processing vs UI display
- **Performance critical** - Every nanosecond matters

### ❌ Don't Use When:

- **Low-frequency updates** - Mutex overhead is negligible
- **Complex bidirectional sync** - May need shared state
- **Simple applications** - Overkill for basic apps
- **Tight coupling needed** - When threads must see exact same state

---

## Complete Example: Full Transcription Service

```cpp
class TranscriptionService {
public:
    // ============================================================
    // Audio Thread Interface (called from audio callback)
    // ============================================================
    
    void processAudioChunk(const float* samples, size_t count) {
        // Update audio thread's own state
        audio_state_.audio_buffer.assign(samples, samples + count);
        audio_state_.sample_count += count;
        
        if (audio_state_.is_recording) {
            // Process audio
            std::string transcription = transcribe(samples, count);
            
            // Update audio thread state
            audio_state_.current_transcription += transcription;
            audio_state_.duration = audio_state_.sample_count / 
                                   float(audio_state_.sample_rate);
            
            // Send to UI thread (lock-free!)
            if (!transcription.empty()) {
                transcription_queue_.push(transcription);
            }
            
            // Send samples for visualization
            std::vector<float> samples_copy(samples, samples + count);
            audio_queue_.push(std::move(samples_copy));
        }
    }
    
    void startRecording() {
        audio_state_.is_recording = true;
        audio_state_.sample_count = 0;
        audio_state_.current_transcription.clear();
        command_queue_.push(Command{Command::Start});
    }
    
    // ============================================================
    // UI Thread Interface (called from presenter)
    // ============================================================
    
    void syncToUI() {
        // Process transcription updates
        std::string chunk;
        int update_count = 0;
        while (transcription_queue_.tryPop(chunk) && update_count < 100) {
            ui_state_.display_text += chunk;
            update_count++;
        }
        
        // Process audio samples (limit to prevent UI lag)
        std::vector<float> samples;
        int sample_count = 0;
        while (audio_queue_.tryPop(samples) && sample_count < 10) {
            ui_state_.waveform_path = samplesToSVGPath(samples);
            sample_count++;
        }
        
        // Process commands (UI → Audio)
        Command cmd;
        while (command_queue_.tryPop(cmd)) {
            // Commands are processed by audio thread
            // This is just for UI → Audio communication
        }
        
        // Update duration estimate
        if (ui_state_.is_recording) {
            ui_state_.display_duration += 0.05f;  // ~50ms
        }
        
        // Notify if changed
        if (update_count > 0 || sample_count > 0) {
            if (on_ui_changed_) {
                on_ui_changed_();
            }
        }
    }
    
    std::string getDisplayText() const {
        return ui_state_.display_text;
    }
    
    std::string getWaveformPath() const {
        return ui_state_.waveform_path;
    }
    
    bool isRecording() const {
        return ui_state_.is_recording;
    }
    
    void clearDisplay() {
        ui_state_.display_text.clear();
        ui_state_.waveform_path.clear();
    }

private:
    // Audio thread data
    struct AudioThreadState {
        std::string current_transcription;
        std::vector<float> audio_buffer;
        bool is_recording = false;
        int sample_rate = 44100;
        int64_t sample_count = 0;
        float duration = 0.0f;
    } audio_state_;
    
    // UI thread data
    struct UIThreadState {
        std::string display_text;
        std::string waveform_path;
        bool is_recording = false;
        float display_duration = 0.0f;
    } ui_state_;
    
    // Communication queues
    LockFreeQueue<std::string> transcription_queue_;
    LockFreeQueue<std::vector<float>> audio_queue_;
    LockFreeQueue<Command> command_queue_;
    
    std::function<void()> on_ui_changed_;
};
```

---

## Summary

**Separate Data Ownership** means:
1. **Each thread owns its data** - No shared mutable state
2. **Copy across boundaries** - Data is copied, not shared
3. **Lock-free queues** - Only synchronization point
4. **Periodic sync** - UI processes queues periodically
5. **Zero locks in hot paths** - Perfect for real-time audio

This gives you **predictable, low-latency performance** perfect for real-time audio transcription! 🚀
