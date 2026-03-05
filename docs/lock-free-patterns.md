# Lock-Free Patterns for Slint C++ Integration

## Problem with Mutexes

Mutexes can cause:
- **Latency spikes** - Threads waiting for locks
- **Priority inversion** - High-priority threads blocked by low-priority
- **Cache line contention** - Performance degradation
- **Not suitable for real-time audio** - Unpredictable timing

## Solution: Message Passing & Copy Semantics

Instead of shared mutable state, use:
1. **Message passing** - Lock-free queues
2. **Copy data** - No shared mutable state
3. **Single ownership** - Each thread owns its data
4. **Periodic sync** - Batch updates instead of real-time

---

## Pattern 1: Lock-Free Message Queue (Recommended)

### Implementation

```cpp
// src/core/lock_free_queue.hpp
#pragma once

#include <atomic>
#include <memory>

template<typename T>
class LockFreeQueue {
public:
    LockFreeQueue() : head_(new Node), tail_(head_.load()) {}

    ~LockFreeQueue() {
        while (Node* old_head = head_.load()) {
            head_.store(old_head->next);
            delete old_head;
        }
    }

    void push(const T& item) {
        Node* new_node = new Node(item);
        Node* prev_tail = tail_.exchange(new_node, std::memory_order_acq_rel);
        prev_tail->next.store(new_node, std::memory_order_release);
    }

    bool tryPop(T& item) {
        Node* head = head_.load(std::memory_order_acquire);
        Node* next = head->next.load(std::memory_order_acquire);
        
        if (next == nullptr) {
            return false;  // Empty
        }
        
        item = next->data;
        head_.store(next, std::memory_order_release);
        delete head;
        return true;
    }

private:
    struct Node {
        T data;
        std::atomic<Node*> next{nullptr};
        
        Node() = default;
        Node(const T& d) : data(d) {}
    };

    std::atomic<Node*> head_;
    std::atomic<Node*> tail_;
};
```

### Usage: Audio Thread → UI Thread

```cpp
class TranscriptionService {
public:
    // Called from audio processing thread (lock-free!)
    void queueTranscriptionUpdate(const std::string& text) {
        update_queue_.push(text);  // Lock-free push
    }

    // Called from UI thread (periodic, lock-free!)
    void processUpdates() {
        std::string text;
        while (update_queue_.tryPop(text)) {  // Lock-free pop
            // Process on UI thread - no locks needed
            transcription_text_ = text;
            if (on_text_changed_) {
                on_text_changed_();
            }
        }
    }

    // UI thread only - no synchronization needed
    std::string getTranscriptionText() const {
        return transcription_text_;  // Only read from UI thread
    }

private:
    LockFreeQueue<std::string> update_queue_;  // Lock-free!
    std::string transcription_text_;  // Owned by UI thread only
    std::function<void()> on_text_changed_;
};
```

### Presenter Setup

```cpp
void AppPresenter::initialize() {
    // Process updates every 50ms (20 FPS is fine for text)
    update_timer_.start(slint::TimerMode::Repeated,
                       std::chrono::milliseconds(50),
                       [this]() {
        transcription_service_->processUpdates();  // Lock-free!
    });
}
```

**Benefits:**
- ✅ Zero locks in hot path (audio thread)
- ✅ Predictable latency
- ✅ No cache line contention
- ✅ Suitable for real-time audio

---

## Pattern 2: Copy-on-Write (Immutable State)

### Implementation

```cpp
class TranscriptionService {
public:
    struct State {
        bool is_recording;
        std::string text;
        float duration;
    };

    // Called from audio thread - creates new state (no locks!)
    void updateTranscription(const std::string& text) {
        // Create new state (copy)
        State new_state = current_state_;  // Copy current
        new_state.text = text;
        
        // Atomically swap pointer (single atomic operation)
        auto new_state_ptr = std::make_shared<State>(std::move(new_state));
        state_ptr_.store(new_state_ptr, std::memory_order_release);
        
        // Notify UI thread
        if (on_changed_) {
            slint::invoke_from_event_loop([this]() {
                on_changed_();
            });
        }
    }

    // Called from UI thread - reads current state (single atomic load)
    State getState() const {
        auto state = state_ptr_.load(std::memory_order_acquire);
        return *state;  // Copy (safe, state is immutable)
    }

    // Called from UI thread - updates state
    void startRecording() {
        State new_state = *state_ptr_.load();
        new_state.is_recording = true;
        state_ptr_.store(std::make_shared<State>(new_state), 
                        std::memory_order_release);
    }

private:
    std::atomic<std::shared_ptr<State>> state_ptr_{
        std::make_shared<State>()};
    std::function<void()> on_changed_;
};
```

**Benefits:**
- ✅ Only one atomic operation per update
- ✅ No mutexes
- ✅ Readers never block writers
- ✅ Predictable performance

---

## Pattern 3: Separate Data Ownership (Best for Real-Time)

### Architecture

```
Audio Thread                    UI Thread
    │                              │
    │ Owns:                        │ Owns:
    │ - Audio buffer               │ - UI state
    │ - Raw samples                │ - Display text
    │                              │
    │ Periodically copies          │ Periodically reads
    │ to message queue ────────────> from message queue
```

### Implementation

```cpp
class TranscriptionService {
public:
    // Audio thread owns this data
    struct AudioThreadData {
        std::string transcription_text;
        std::vector<float> audio_samples;
        bool is_recording;
    };

    // UI thread owns this data
    struct UIThreadData {
        std::string display_text;
        bool is_recording;
        float duration;
    };

    // Called from audio thread - owns its data, no locks!
    void updateTranscription(const std::string& text) {
        // Update audio thread's own data (no synchronization needed)
        audio_data_.transcription_text = text;
        
        // Send copy to UI thread via lock-free queue
        text_queue_.push(text);
    }

    // Called from UI thread - processes updates
    void syncToUI() {
        std::string text;
        while (text_queue_.tryPop(text)) {
            ui_data_.display_text = text;  // Update UI data
        }
        
        // Update UI
        if (on_text_changed_) {
            on_text_changed_();
        }
    }

    // UI thread only - no synchronization needed
    std::string getDisplayText() const {
        return ui_data_.display_text;  // Owned by UI thread
    }

    // Audio thread only - no synchronization needed
    bool isRecordingOnAudioThread() const {
        return audio_data_.is_recording;  // Owned by audio thread
    }

private:
    // Audio thread data (accessed only from audio thread)
    AudioThreadData audio_data_;
    
    // UI thread data (accessed only from UI thread)
    UIThreadData ui_data_;
    
    // Lock-free communication
    LockFreeQueue<std::string> text_queue_;
    std::function<void()> on_text_changed_;
};
```

**Benefits:**
- ✅ Zero synchronization overhead in hot paths
- ✅ Each thread owns its data
- ✅ Only copies cross thread boundaries
- ✅ Perfect for real-time audio

---

## Pattern 4: Ring Buffer (For High-Frequency Audio Data)

### Implementation

```cpp
// src/core/ring_buffer.hpp
#pragma once

#include <atomic>
#include <vector>
#include <cstring>

template<typename T, size_t Size>
class LockFreeRingBuffer {
public:
    bool push(const T* data, size_t count) {
        size_t write_pos = write_pos_.load(std::memory_order_relaxed);
        size_t next_write = (write_pos + count) % Size;
        size_t read_pos = read_pos_.load(std::memory_order_acquire);
        
        // Check if there's space
        if ((next_write + 1) % Size == read_pos) {
            return false;  // Full
        }
        
        // Copy data
        for (size_t i = 0; i < count; ++i) {
            buffer_[(write_pos + i) % Size] = data[i];
        }
        
        write_pos_.store(next_write, std::memory_order_release);
        return true;
    }

    size_t pop(T* data, size_t max_count) {
        size_t read_pos = read_pos_.load(std::memory_order_relaxed);
        size_t write_pos = write_pos_.load(std::memory_order_acquire);
        
        size_t available = (write_pos + Size - read_pos) % Size;
        size_t to_read = std::min(available, max_count);
        
        if (to_read == 0) {
            return 0;  // Empty
        }
        
        // Copy data
        for (size_t i = 0; i < to_read; ++i) {
            data[i] = buffer_[(read_pos + i) % Size];
        }
        
        read_pos_.store((read_pos + to_read) % Size, std::memory_order_release);
        return to_read;
    }

private:
    alignas(64) std::atomic<size_t> write_pos_{0};  // Separate cache line
    alignas(64) std::atomic<size_t> read_pos_{0};   // Separate cache line
    alignas(64) T buffer_[Size];
};
```

### Usage for Audio Samples

```cpp
class AudioService {
public:
    // Called from audio callback (real-time, lock-free!)
    void processAudioChunk(const float* samples, size_t count) {
        // Push to ring buffer (lock-free, very fast)
        audio_buffer_.push(samples, count);
    }

    // Called from UI thread (periodic)
    void updateWaveform() {
        float samples[1024];
        size_t count = audio_buffer_.pop(samples, 1024);
        
        if (count > 0) {
            // Convert to waveform path
            std::string path = samplesToSVGPath(samples, count);
            waveform_path_ = path;
            
            if (on_waveform_changed_) {
                on_waveform_changed_();
            }
        }
    }

private:
    LockFreeRingBuffer<float, 8192> audio_buffer_;  // Lock-free!
    std::string waveform_path_;  // UI thread only
    std::function<void()> on_waveform_changed_;
};
```

**Benefits:**
- ✅ Lock-free, wait-free
- ✅ Constant time operations
- ✅ Perfect for audio streaming
- ✅ No memory allocations in hot path

---

## Pattern 5: Single Producer, Single Consumer (SPSC) Queue

### Optimized Implementation

```cpp
// src/core/spsc_queue.hpp
#pragma once

#include <atomic>
#include <vector>

template<typename T, size_t Size>
class SPSCQueue {
public:
    bool push(const T& item) {
        size_t current_write = write_pos_.load(std::memory_order_relaxed);
        size_t next_write = (current_write + 1) % Size;
        
        // Check if full (only producer writes, so relaxed is OK)
        if (next_write == read_pos_.load(std::memory_order_acquire)) {
            return false;  // Full
        }
        
        buffer_[current_write] = item;
        write_pos_.store(next_write, std::memory_order_release);
        return true;
    }

    bool pop(T& item) {
        size_t current_read = read_pos_.load(std::memory_order_relaxed);
        
        // Check if empty
        if (current_read == write_pos_.load(std::memory_order_acquire)) {
            return false;  // Empty
        }
        
        item = buffer_[current_read];
        read_pos_.store((current_read + 1) % Size, std::memory_order_release);
        return true;
    }

private:
    // Separate cache lines to avoid false sharing
    alignas(64) std::atomic<size_t> write_pos_{0};
    alignas(64) std::atomic<size_t> read_pos_{0};
    alignas(64) T buffer_[Size];
};
```

**Benefits:**
- ✅ Simpler than general lock-free queue
- ✅ Better performance (no CAS loops)
- ✅ Perfect for audio → UI communication
- ✅ Wait-free operations

---

## Complete Example: Lock-Free Transcription Service

```cpp
class TranscriptionService {
public:
    // Audio thread methods (lock-free!)
    void queueTranscriptionChunk(const std::string& chunk) {
        text_queue_.push(chunk);  // Lock-free
    }

    void queueAudioSamples(const float* samples, size_t count) {
        audio_buffer_.push(samples, count);  // Lock-free
    }

    // UI thread methods (processes queues)
    void processUpdates() {
        // Process text updates
        std::string chunk;
        while (text_queue_.tryPop(chunk)) {
            ui_text_ += chunk;  // Append to UI text
        }
        
        // Process audio samples
        float samples[512];
        size_t count = audio_buffer_.pop(samples, 512);
        if (count > 0) {
            updateWaveform(samples, count);
        }
        
        // Notify UI if changed
        if (!chunk.empty() || count > 0) {
            if (on_changed_) {
                on_changed_();
            }
        }
    }

    // UI thread only - no synchronization
    std::string getTranscriptionText() const {
        return ui_text_;
    }

    std::string getWaveformPath() const {
        return waveform_path_;
    }

    // UI thread only
    void startRecording() {
        ui_is_recording_ = true;
        ui_text_.clear();
        if (on_state_changed_) {
            on_state_changed_();
        }
    }

private:
    // Lock-free queues (audio → UI)
    SPSCQueue<std::string, 64> text_queue_;
    LockFreeRingBuffer<float, 4096> audio_buffer_;
    
    // UI thread data (no synchronization needed)
    std::string ui_text_;
    std::string waveform_path_;
    bool ui_is_recording_ = false;
    
    std::function<void()> on_changed_;
    std::function<void()> on_state_changed_;
    
    void updateWaveform(const float* samples, size_t count) {
        // Convert to SVG path
        waveform_path_ = samplesToSVGPath(samples, count);
    }
};
```

---

## Performance Comparison

| Pattern | Latency | Throughput | Complexity |
|---------|---------|------------|------------|
| Mutex | ~100ns-10μs | Medium | Low |
| Atomic (simple) | ~10-50ns | High | Low |
| Lock-free queue | ~20-100ns | Very High | Medium |
| Ring buffer | ~10-30ns | Very High | Medium |
| Copy-on-write | ~50-200ns | High | Low |
| Separate ownership | ~0ns (hot path) | Very High | Medium |

**For real-time audio:** Use lock-free queues or ring buffers.

---

## Best Practices

### ✅ DO:

1. **Use lock-free queues** for audio → UI communication
2. **Batch updates** - Process multiple items per UI frame
3. **Separate data ownership** - Each thread owns its data
4. **Copy data** across thread boundaries (not references)
5. **Use SPSC queues** when you have single producer/consumer
6. **Align to cache lines** (`alignas(64)`) to avoid false sharing

### ❌ DON'T:

1. **Don't share mutable state** between threads
2. **Don't use mutexes in audio callbacks** (unpredictable latency)
3. **Don't allocate memory** in hot paths
4. **Don't use general lock-free structures** when SPSC works
5. **Don't update UI from audio thread** (use queues)

---

## Recommended Architecture for Real-Time Audio

```
┌─────────────────────────────────────┐
│      Audio Processing Thread         │
│  (Real-time, lock-free operations)   │
│                                      │
│  - Process audio samples            │
│  - Generate transcription           │
│  - Push to lock-free queues ────────┼──┐
└─────────────────────────────────────┘  │
                                          │ Lock-free
                                          │ queues
┌─────────────────────────────────────┐  │
│          UI Thread                   │  │
│  (Periodic processing)             │  │
│                                      │  │
│  ← Pop from queues ──────────────────┼──┘
│  - Update UI state                   │
│  - Render waveform                   │
│  - Display text                      │
└─────────────────────────────────────┘
```

**Key Points:**
- Audio thread: Zero locks, zero allocations
- UI thread: Processes queues periodically (50-100ms)
- Communication: Lock-free queues only
- Data: Separate ownership, copy semantics

---

## Migration from Mutex-Based Code

1. **Identify shared state** → Make it thread-local
2. **Replace mutexes** → Use lock-free queues
3. **Replace direct updates** → Queue messages
4. **Add periodic processing** → Process queues on UI thread
5. **Test with real-time constraints** → Verify latency

This approach gives you **predictable, low-latency performance** perfect for real-time audio processing!
