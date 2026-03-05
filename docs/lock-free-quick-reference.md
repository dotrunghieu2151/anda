# Lock-Free Patterns Quick Reference

## Why Lock-Free?

- ✅ **Zero latency spikes** - No mutex contention
- ✅ **Predictable performance** - Constant time operations
- ✅ **Real-time safe** - Suitable for audio callbacks
- ✅ **High throughput** - No blocking

---

## Pattern 1: Lock-Free Queue (Most Common)

```cpp
// Audio thread (lock-free!)
void processAudio(const float* samples, size_t count) {
    audio_queue_.push(samples, count);  // Zero locks!
}

// UI thread (periodic processing)
void updateUI() {
    float samples[1024];
    size_t count = audio_queue_.pop(samples, 1024);
    if (count > 0) {
        updateWaveform(samples, count);
    }
}
```

---

## Pattern 2: Separate Data Ownership

```cpp
class Service {
    // Audio thread owns this
    AudioData audio_data_;  // No synchronization!
    
    // UI thread owns this  
    UIData ui_data_;  // No synchronization!
    
    // Communication only
    LockFreeQueue<Message> queue_;  // Lock-free!
};
```

---

## Pattern 3: Copy-on-Write

```cpp
// Update (creates new state, no locks!)
void updateText(const std::string& text) {
    auto new_state = std::make_shared<State>(*state_);
    new_state->text = text;
    state_.store(new_state);  // Single atomic!
}

// Read (single atomic load)
State getState() const {
    return *state_.load();  // Copy (safe)
}
```

---

## Quick Decision Tree

```
Need real-time performance?
├─ Yes → Use lock-free queues
│   └─> Audio → UI: SPSC queue
│       High-frequency: Ring buffer
│
└─ No → Copy-on-write or mutex OK

Data update frequency?
├─ High (audio samples) → Ring buffer
├─ Medium (text chunks) → SPSC queue  
└─ Low (state changes) → Copy-on-write
```

---

## Template: Lock-Free Service

```cpp
class LockFreeService {
public:
    // Audio thread (lock-free!)
    void queueUpdate(const Data& data) {
        queue_.push(data);  // Zero locks!
    }

    // UI thread (periodic)
    void processUpdates() {
        Data data;
        while (queue_.tryPop(data)) {
            ui_data_ = data;  // Update UI data
        }
        if (on_changed_) on_changed_();
    }

    // UI thread only (no sync needed)
    Data getData() const {
        return ui_data_;
    }

private:
    SPSCQueue<Data, 64> queue_;
    Data ui_data_;  // UI thread owns this
    std::function<void()> on_changed_;
};
```

---

## Performance Tips

1. **Batch updates** - Process multiple items per frame
2. **Separate cache lines** - Use `alignas(64)` for atomics
3. **Avoid allocations** - Pre-allocate buffers
4. **Process periodically** - Don't process every item immediately
5. **Use SPSC** - Simpler and faster than general lock-free

---

## Example: Your Transcription Service

```cpp
class TranscriptionService {
public:
    // Audio thread (lock-free!)
    void queueTranscription(const std::string& text) {
        text_queue_.push(text);
    }

    // UI thread (processes every 50ms)
    void processUpdates() {
        std::string chunk;
        while (text_queue_.tryPop(chunk)) {
            ui_text_ += chunk;
        }
        if (!chunk.empty() && on_changed_) {
            on_changed_();
        }
    }

    // UI thread only
    std::string getText() const {
        return ui_text_;
    }

private:
    SPSCQueue<std::string, 32> text_queue_;  // Lock-free!
    std::string ui_text_;  // UI thread owns this
    std::function<void()> on_changed_;
};
```

**Result:** Zero locks, predictable latency, real-time safe! 🚀
