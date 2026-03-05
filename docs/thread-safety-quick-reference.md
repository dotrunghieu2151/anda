# Thread Safety Quick Reference

## The Problem

```
UI Thread (Slint callbacks) ──┐
                               ├──> Race Condition! ⚠️
Audio Thread ──────────────────┘
```

**Solution:** Make services thread-safe.

---

## Quick Patterns

### Pattern 1: Mutex Protection (Most Common)

```cpp
class MyService {
public:
    void updateState(const std::string& value) {
        std::lock_guard<std::mutex> lock(mutex_);
        state_ = value;
        // Notify outside lock
        if (on_changed_) on_changed_();
    }

    std::string getState() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return state_;
    }

private:
    mutable std::mutex mutex_;
    std::string state_;
    std::function<void()> on_changed_;
};
```

### Pattern 2: Atomic for Simple Flags

```cpp
class MyService {
private:
    std::atomic<bool> is_active_{false};
    
public:
    void activate() { is_active_.store(true); }
    bool isActive() const { return is_active_.load(); }
};
```

### Pattern 3: UI Updates from Background Threads

```cpp
// In service (called from audio thread)
void updateTranscription(const std::string& text) {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        text_ = text;
    }
    // Notify UI thread safely
    if (on_changed_) {
        slint::invoke_from_event_loop([this]() {
            on_changed_();
        });
    }
}
```

---

## Thread Safety Rules

### ✅ Safe Operations

| Operation | Thread | Notes |
|-----------|--------|-------|
| Read atomic | Any | Use `load()` |
| Write atomic | Any | Use `store()` |
| Read with mutex | Any | Lock, read, unlock |
| Write with mutex | Any | Lock, write, unlock |
| Update UI | UI only | Use `invoke_from_event_loop()` from other threads |

### ❌ Unsafe Operations

| Operation | Problem |
|-----------|---------|
| Direct UI update from background thread | Crash/undefined behavior |
| Access shared state without lock | Race condition |
| Hold lock during callback | Deadlock risk |
| Access Slint objects from non-UI thread | Not thread-safe |

---

## Template: Thread-Safe Service

```cpp
class ThreadSafeService {
public:
    // UI Thread Methods
    void start() {
        std::lock_guard<std::mutex> lock(mutex_);
        state_ = State::Active;
        notifyChanged();
    }

    // Background Thread Methods
    void updateData(const Data& data) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            data_ = data;
        }
        notifyChanged();
    }

    // Any Thread Methods
    State getState() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return state_;
    }

    void setOnChanged(std::function<void()> callback) {
        std::lock_guard<std::mutex> lock(mutex_);
        on_changed_ = callback;
    }

private:
    void notifyChanged() {
        if (on_changed_) {
            slint::invoke_from_event_loop([this]() {
                on_changed_();
            });
        }
    }

    mutable std::mutex mutex_;
    State state_;
    Data data_;
    std::function<void()> on_changed_;
};
```

---

## Common Mistakes

### ❌ Mistake 1: No Lock

```cpp
// WRONG - Race condition!
void updateText(const std::string& text) {
    text_ = text;  // Not protected!
}
```

### ✅ Fix: Use Lock

```cpp
void updateText(const std::string& text) {
    std::lock_guard<std::mutex> lock(mutex_);
    text_ = text;
}
```

### ❌ Mistake 2: Direct UI Update from Background Thread

```cpp
// WRONG - Can crash!
void audioThread() {
    window_->global<Adapter>().set_text("...");  // Not on UI thread!
}
```

### ✅ Fix: Use invoke_from_event_loop

```cpp
void audioThread() {
    slint::invoke_from_event_loop([this]() {
        window_->global<Adapter>().set_text("...");
    });
}
```

### ❌ Mistake 3: Hold Lock During Callback

```cpp
// WRONG - Deadlock risk!
void updateState() {
    std::lock_guard<std::mutex> lock(mutex_);
    state_ = new_state;
    on_changed_();  // Callback might try to lock again!
}
```

### ✅ Fix: Release Lock First

```cpp
void updateState() {
    {
        std::lock_guard<std::mutex> lock(mutex_);
        state_ = new_state;
    }
    // Now safe to call callback
    if (on_changed_) on_changed_();
}
```

---

## Checklist

Before deploying, verify:

- [ ] All shared state protected with mutex/atomic
- [ ] UI updates use `invoke_from_event_loop()` from background threads
- [ ] Locks released before callbacks
- [ ] No direct Slint object access from background threads
- [ ] Thread sanitizer tests pass

---

## Quick Decision Tree

```
Need to protect shared state?
├─ Simple flag/counter?
│  └─> Use std::atomic
│
└─ Complex data (string, struct)?
   └─> Use std::mutex + std::lock_guard

Updating UI from background thread?
└─> Use slint::invoke_from_event_loop()

Calling callback after state change?
└─> Release lock first, then call callback
```

---

## Example: Your Transcription Service

```cpp
class TranscriptionService {
public:
    // Called from UI thread (Slint callback)
    void startRecording() {
        std::lock_guard<std::mutex> lock(mutex_);
        state_ = State::Recording;
        start_time_ = std::chrono::steady_clock::now();
    }
    // Lock released automatically

    // Called from audio processing thread
    void updateTranscription(const std::string& text) {
        {
            std::lock_guard<std::mutex> lock(mutex_);
            transcription_text_ = text;
        }
        // Lock released, safe to notify
        
        if (on_text_changed_) {
            slint::invoke_from_event_loop([this]() {
                on_text_changed_();  // Runs on UI thread
            });
        }
    }

    // Called from any thread
    bool isRecording() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return state_ == State::Recording;
    }

private:
    mutable std::mutex mutex_;
    State state_;
    std::string transcription_text_;
    std::chrono::steady_clock::time_point start_time_;
    std::function<void()> on_text_changed_;
};
```

**Key Points:**
1. ✅ All state access protected by mutex
2. ✅ Lock released before callback
3. ✅ UI updates use `invoke_from_event_loop()`
4. ✅ Thread-safe from both UI and audio threads

---

## Testing

```bash
# Compile with thread sanitizer
cmake -DCMAKE_CXX_FLAGS="-fsanitize=thread" ..
make

# Run your app - it will detect race conditions
./anda
```

Thread sanitizer will report any race conditions it finds!
