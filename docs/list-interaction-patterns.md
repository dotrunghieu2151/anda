# Handling List Component Interactions in Slint

## Problem

Slint callbacks register a single function, but you need to handle interactions with multiple items in a list. How do you identify which item triggered the callback?

## Solution Patterns

There are several patterns depending on your use case:

---

## Pattern 1: Pass Index/ID as Callback Parameter (Recommended)

**Best for:** Simple lists where you need to know which item was clicked.

### Slint Component

```slint
// List item component
export component ListItem {
    in property <string> item-text;
    in property <int> item-index;
    
    callback item-clicked(int);
    
    Rectangle {
        background: touch-area.pressed ? #2a2a3e : #1a1a2e;
        border-radius: 4px;
        
        touch-area := TouchArea {
            clicked => {
                root.item-clicked(root.item-index);
            }
        }
        
        Text {
            text: root.item-text;
            color: #e0e0e0;
        }
    }
}

// List container using for loop
export component ItemList {
    in property <[string]> items: [];
    
    callback item-selected(int);
    
    VerticalLayout {
        spacing: 8px;
        
        for item[index] in root.items: ListItem {
            item-text: item;
            item-index: index;
            item-clicked => {
                root.item-selected(index);
            }
        }
    }
}
```

### C++ Binding

```cpp
// In presenter
void AppPresenter::initialize() {
    window_->global<MyAdapter>().on_item_selected([this](int index) {
        handleItemSelected(index);
    });
}

void AppPresenter::handleItemSelected(int index) {
    // You know exactly which item was clicked!
    auto item = my_service_->getItem(index);
    // Handle the item...
}
```

---

## Pattern 2: Use ListView with Model (Best for Large Lists)

**Best for:** Large lists, dynamic lists, or when you need Slint's built-in virtualization.

### Slint Component

```slint
import { ListView } from "std-widgets.slint";

export component TranscriptionHistoryList {
    in property <[string]> transcriptions: [];
    
    callback transcription-selected(int);
    callback transcription-deleted(int);
    
    ListView {
        model: root.transcriptions;
        
        delegate := Rectangle {
            height: 60px;
            background: touch-area.pressed ? #2a2a3e : #1a1a2e;
            
            HorizontalLayout {
                spacing: 12px;
                padding: 12px;
                
                // Text content
                Text {
                    text: model-data;
                    color: #e0e0e0;
                    vertical-stretch: 1;
                }
                
                // Delete button
                Rectangle {
                    width: 30px;
                    height: 30px;
                    background: delete-btn.pressed ? #ff3366 : #4a4a5e;
                    border-radius: 4px;
                    
                    delete-btn := TouchArea {
                        clicked => {
                            // model-data is the string, but we need the index
                            // Use a custom approach (see below)
                        }
                    }
                    
                    Text {
                        text: "×";
                        color: #ffffff;
                    }
                }
            }
            
            touch-area := TouchArea {
                clicked => {
                    // Get index from model
                    root.transcription-selected(model-data);
                }
            }
        }
    }
}
```

### Problem: ListView doesn't directly provide index

**Solution A: Use a struct model with index**

```slint
struct TranscriptionItem {
    text: string,
    id: int,
}

export component TranscriptionHistoryList {
    in property <[TranscriptionItem]> transcriptions: [];
    
    callback transcription-selected(int);  // receives id
    
    ListView {
        model: root.transcriptions;
        
        delegate := Rectangle {
            height: 60px;
            background: touch-area.pressed ? #2a2a3e : #1a1a2e;
            
            Text {
                text: model-data.text;
                color: #e0e0e0;
            }
            
            touch-area := TouchArea {
                clicked => {
                    root.transcription-selected(model-data.id);
                }
            }
        }
    }
}
```

### C++ with Struct Model

```cpp
// Define struct in Slint
// In globals.slint:
struct TranscriptionItem {
    text: string,
    id: int,
}

// In C++
#include <slint.h>

struct TranscriptionItem {
    slint::SharedString text;
    int id;
};

class TranscriptionService {
public:
    std::vector<TranscriptionItem> getTranscriptions() const {
        return transcriptions_;
    }
    
private:
    std::vector<TranscriptionItem> transcriptions_;
};

// In presenter
void AppPresenter::syncTranscriptionList() {
    auto items = transcription_service_->getTranscriptions();
    
    // Convert to Slint model
    auto model = std::make_shared<slint::VectorModel<TranscriptionItem>>(items);
    window_->global<TranscriptionAdapter>().set_transcriptions(model);
}

void AppPresenter::handleTranscriptionSelected(int id) {
    // Find item by id
    auto item = transcription_service_->getTranscriptionById(id);
    // Handle selection...
}
```

---

## Pattern 3: Component with Index Property

**Best for:** Reusable components that need to know their position.

### Slint Component

```slint
export component DeviceListItem {
    in property <string> device-name;
    in property <int> device-index;
    in property <bool> is-selected: false;
    
    callback device-clicked(int);
    callback device-deleted(int);
    
    Rectangle {
        background: root.is-selected ? #2d1f3d : (touch-area.pressed ? #2a2a3e : #1a1a2e);
        border-width: root.is-selected ? 2px : 0px;
        border-color: #00d9ff;
        border-radius: 4px;
        
        HorizontalLayout {
            spacing: 12px;
            padding: 12px;
            
            Text {
                text: root.device-name;
                color: #e0e0e0;
                vertical-stretch: 1;
            }
            
            Rectangle {
                width: 30px;
                height: 30px;
                background: delete-btn.pressed ? #ff3366 : #4a4a5e;
                border-radius: 4px;
                
                delete-btn := TouchArea {
                    clicked => {
                        root.device-deleted(root.device-index);
                    }
                }
                
                Text {
                    text: "×";
                    color: #ffffff;
                }
            }
        }
        
        touch-area := TouchArea {
            clicked => {
                root.device-clicked(root.device-index);
            }
        }
    }
}

// Usage in parent
export component DeviceList {
    in property <[string]> devices: [];
    in property <int> selected-index: -1;
    
    callback device-selected(int);
    callback device-deleted(int);
    
    VerticalLayout {
        spacing: 8px;
        
        for device[index] in root.devices: DeviceListItem {
            device-name: device;
            device-index: index;
            is-selected: index == root.selected-index;
            device-clicked => {
                root.device-selected(index);
            }
            device-deleted => {
                root.device-deleted(index);
            }
        }
    }
}
```

### C++ Binding

```cpp
void AppPresenter::initialize() {
    // Handle device selection
    window_->global<DeviceAdapter>().on_device_selected([this](int index) {
        audio_service_->selectDevice(index);
        syncDeviceList();
    });
    
    // Handle device deletion
    window_->global<DeviceAdapter>().on_device_deleted([this](int index) {
        audio_service_->removeDevice(index);
        syncDeviceList();
    });
}
```

---

## Pattern 4: Using Model Data Directly (For Simple Cases)

**Best for:** When the model data itself is sufficient identifier.

### Slint Component

```slint
export component LanguageList {
    in property <[string]> languages: [];
    
    callback language-selected(string);  // Pass the string itself
    
    VerticalLayout {
        spacing: 8px;
        
        for lang in root.languages: Rectangle {
            height: 40px;
            background: touch-area.pressed ? #2a2a3e : #1a1a2e;
            
            Text {
                text: lang;
                color: #e0e0e0;
            }
            
            touch-area := TouchArea {
                clicked => {
                    root.language-selected(lang);
                }
            }
        }
    }
}
```

### C++ Binding

```cpp
void AppPresenter::initialize() {
    window_->global<LanguageAdapter>().on_language_selected(
        [this](slint::SharedString language) {
            // Find by string value
            auto index = language_service_->findLanguageIndex(
                std::string(language));
            language_service_->selectLanguage(index);
        });
}
```

---

## Pattern 5: Multiple Callbacks per Item (Complex Actions)

**Best for:** Items with multiple actions (edit, delete, select, etc.).

### Slint Component

```slint
export component TranscriptionItem {
    in property <string> text;
    in property <int> id;
    
    callback selected(int);
    callback edited(int);
    callback deleted(int);
    callback copied(int);
    
    Rectangle {
        background: #1a1a2e;
        border-radius: 4px;
        
        HorizontalLayout {
            spacing: 8px;
            padding: 12px;
            
            // Main content (selectable)
            Rectangle {
                vertical-stretch: 1;
                background: select-area.pressed ? #2a2a3e : transparent;
                
                select-area := TouchArea {
                    clicked => {
                        root.selected(root.id);
                    }
                }
                
                Text {
                    text: root.text;
                    color: #e0e0e0;
                }
            }
            
            // Action buttons
            Rectangle {
                width: 30px;
                height: 30px;
                background: edit-btn.pressed ? #00d9ff : #4a4a5e;
                
                edit-btn := TouchArea {
                    clicked => {
                        root.edited(root.id);
                    }
                }
                
                Text { text: "✎"; }
            }
            
            Rectangle {
                width: 30px;
                height: 30px;
                background: copy-btn.pressed ? #4ecdc4 : #4a4a5e;
                
                copy-btn := TouchArea {
                    clicked => {
                        root.copied(root.id);
                    }
                }
                
                Text { text: "📋"; }
            }
            
            Rectangle {
                width: 30px;
                height: 30px;
                background: delete-btn.pressed ? #ff3366 : #4a4a5e;
                
                delete-btn := TouchArea {
                    clicked => {
                        root.deleted(root.id);
                    }
                }
                
                Text { text: "×"; }
            }
        }
    }
}

// Usage
export component TranscriptionHistory {
    in property <[TranscriptionItem]> items: [];
    
    callback item-selected(int);
    callback item-edited(int);
    callback item-deleted(int);
    callback item-copied(int);
    
    VerticalLayout {
        spacing: 8px;
        
        for item in root.items: TranscriptionItem {
            text: item.text;
            id: item.id;
            selected => {
                root.item-selected(item.id);
            }
            edited => {
                root.item-edited(item.id);
            }
            deleted => {
                root.item-deleted(item.id);
            }
            copied => {
                root.item-copied(item.id);
            }
        }
    }
}
```

### C++ Binding

```cpp
void AppPresenter::initialize() {
    auto& adapter = window_->global<TranscriptionAdapter>();
    
    adapter.on_item_selected([this](int id) {
        transcription_service_->selectItem(id);
    });
    
    adapter.on_item_edited([this](int id) {
        transcription_service_->editItem(id);
    });
    
    adapter.on_item_deleted([this](int id) {
        transcription_service_->deleteItem(id);
        syncTranscriptionList();
    });
    
    adapter.on_item_copied([this](int id) {
        transcription_service_->copyToClipboard(id);
    });
}
```

---

## Pattern 6: Global Callback with Context (Advanced)

**Best for:** When you want a single callback handler but need context.

### Slint Component

```slint
export global ActionAdapter {
    callback item-action(string action-type, int item-id, string item-data);
}

export component ItemList {
    in property <[string]> items: [];
    
    VerticalLayout {
        for item[index] in root.items: Rectangle {
            height: 40px;
            
            HorizontalLayout {
                Rectangle {
                    background: select-btn.pressed ? #00d9ff : #4a4a5e;
                    
                    select-btn := TouchArea {
                        clicked => {
                            ActionAdapter.item-action("select", index, item);
                        }
                    }
                    
                    Text { text: "Select"; }
                }
                
                Rectangle {
                    background: delete-btn.pressed ? #ff3366 : #4a4a5e;
                    
                    delete-btn := TouchArea {
                        clicked => {
                            ActionAdapter.item-action("delete", index, item);
                        }
                    }
                    
                    Text { text: "Delete"; }
                }
            }
        }
    }
}
```

### C++ Binding

```cpp
void AppPresenter::initialize() {
    window_->global<ActionAdapter>().on_item_action(
        [this](slint::SharedString action_type, int item_id, 
               slint::SharedString item_data) {
            std::string action = std::string(action_type);
            
            if (action == "select") {
                handleItemSelected(item_id);
            } else if (action == "delete") {
                handleItemDeleted(item_id);
            }
            // etc.
        });
}
```

---

## Recommended Approach Summary

| Use Case | Recommended Pattern |
|----------|-------------------|
| Simple list with single action | **Pattern 1**: Pass index as parameter |
| Large/dynamic lists | **Pattern 2**: ListView with struct model (includes id) |
| Reusable components | **Pattern 3**: Component with index property |
| Items identified by value | **Pattern 4**: Pass model data directly |
| Multiple actions per item | **Pattern 5**: Multiple callbacks per item |
| Complex routing needed | **Pattern 6**: Global callback with context |

---

## Complete Example: Transcription History

### Slint (globals.slint)

```slint
struct TranscriptionEntry {
    id: int,
    text: string,
    timestamp: string,
}

export global TranscriptionHistoryAdapter {
    in-out property <[TranscriptionEntry]> entries: [];
    in-out property <int> selected-id: -1;
    
    callback entry-selected(int);
    callback entry-deleted(int);
    callback entry-copied(int);
}
```

### Slint Component

```slint
import { ListView } from "std-widgets.slint";
import { TranscriptionHistoryAdapter } from "../globals.slint";

export component TranscriptionHistoryList {
    ListView {
        model: TranscriptionHistoryAdapter.entries;
        
        delegate := Rectangle {
            height: 80px;
            background: model-data.id == TranscriptionHistoryAdapter.selected-id 
                ? #2d1f3d : #1a1a2e;
            border-width: model-data.id == TranscriptionHistoryAdapter.selected-id ? 2px : 0px;
            border-color: #00d9ff;
            
            HorizontalLayout {
                spacing: 12px;
                padding: 12px;
                
                VerticalLayout {
                    spacing: 4px;
                    vertical-stretch: 1;
                    
                    Text {
                        text: model-data.text;
                        color: #e0e0e0;
                        wrap: word-wrap;
                    }
                    
                    Text {
                        text: model-data.timestamp;
                        font-size: 12px;
                        color: #6c757d;
                    }
                }
                
                Rectangle {
                    width: 30px;
                    height: 30px;
                    background: copy-btn.pressed ? #4ecdc4 : #4a4a5e;
                    
                    copy-btn := TouchArea {
                        clicked => {
                            TranscriptionHistoryAdapter.entry-copied(model-data.id);
                        }
                    }
                    
                    Text { text: "📋"; }
                }
                
                Rectangle {
                    width: 30px;
                    height: 30px;
                    background: delete-btn.pressed ? #ff3366 : #4a4a5e;
                    
                    delete-btn := TouchArea {
                        clicked => {
                            TranscriptionHistoryAdapter.entry-deleted(model-data.id);
                        }
                    }
                    
                    Text { text: "×"; }
                }
            }
            
            touch-area := TouchArea {
                clicked => {
                    TranscriptionHistoryAdapter.entry-selected(model-data.id);
                }
            }
        }
    }
}
```

### C++ Service

```cpp
struct TranscriptionEntry {
    int id;
    std::string text;
    std::string timestamp;
};

class TranscriptionHistoryService {
public:
    std::vector<TranscriptionEntry> getEntries() const {
        return entries_;
    }
    
    void addEntry(const std::string& text) {
        TranscriptionEntry entry;
        entry.id = next_id_++;
        entry.text = text;
        entry.timestamp = getCurrentTimestamp();
        entries_.push_back(entry);
    }
    
    void deleteEntry(int id) {
        entries_.erase(
            std::remove_if(entries_.begin(), entries_.end(),
                [id](const TranscriptionEntry& e) { return e.id == id; }),
            entries_.end());
    }
    
    TranscriptionEntry* findEntry(int id) {
        auto it = std::find_if(entries_.begin(), entries_.end(),
            [id](const TranscriptionEntry& e) { return e.id == id; });
        return it != entries_.end() ? &*it : nullptr;
    }

private:
    std::vector<TranscriptionEntry> entries_;
    int next_id_ = 1;
};
```

### C++ Presenter

```cpp
void AppPresenter::syncTranscriptionHistory() {
    auto entries = history_service_->getEntries();
    
    // Convert to Slint model
    std::vector<TranscriptionEntry> slint_entries;
    for (const auto& entry : entries) {
        TranscriptionEntry slint_entry;
        slint_entry.id = entry.id;
        slint_entry.text = slint::SharedString(entry.text);
        slint_entry.timestamp = slint::SharedString(entry.timestamp);
        slint_entries.push_back(slint_entry);
    }
    
    auto model = std::make_shared<slint::VectorModel<TranscriptionEntry>>(
        slint_entries);
    window_->global<TranscriptionHistoryAdapter>().set_entries(model);
}

void AppPresenter::initialize() {
    auto& adapter = window_->global<TranscriptionHistoryAdapter>();
    
    adapter.on_entry_selected([this](int id) {
        auto* entry = history_service_->findEntry(id);
        if (entry) {
            adapter.set_selected_id(id);
            // Load entry for editing/viewing
        }
    });
    
    adapter.on_entry_deleted([this](int id) {
        history_service_->deleteEntry(id);
        syncTranscriptionHistory();
    });
    
    adapter.on_entry_copied([this](int id) {
        auto* entry = history_service_->findEntry(id);
        if (entry) {
            // Copy to clipboard
            copyToClipboard(entry->text);
        }
    });
}
```

---

## Key Takeaways

1. **Always pass identifier** (index or id) in callback parameters
2. **Use struct models** for ListView when you need both data and id
3. **Keep callbacks simple** - one action per callback is clearest
4. **Use component properties** to pass context (like index) to child components
5. **Prefer id over index** for dynamic lists (indexes change when items are deleted)

This approach gives you full control over which item triggered an action while keeping your code clean and maintainable!
