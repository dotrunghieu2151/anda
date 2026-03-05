# Navigation System Quick Start Guide

## Quick Setup

### 1. Create a Page

```slint
// src/ui/pages/my-page.slint
import { Page } from "../navigation/page.slint";

// Define page params (optional, for documentation)
struct MyPageParams {
    id: string,
    mode: string,
}

// Page-specific adapter
export global MyPageAdapter {
    in-out property <string> title: "My Page";
    callback action-clicked();
}

// Page component
export component MyPage inherits Page {
    private property <string> id: root.get-param("id");
    private property <string> mode: root.get-param("mode");
    
    VerticalBox {
        Text {
            text: MyPageAdapter.title;
        }
        // ... page content
    }
}
```

### 2. Register Page in C++

```cpp
// In presenter
navigation_manager_->registerPage(
    "my-page",
    "my-page",  // Component name
    [this](const RouteParams& params) {
        // Initialize page
        auto& adapter = window_->global<MyPageAdapter>();
        adapter.set_title("My Page");
    }
);
```

### 3. Navigate

```cpp
// Simple navigation
navigation_manager_->navigate("my-page");

// With params
RouteParams params;
params.set("id", "123");
params.set("mode", "edit");
navigation_manager_->navigate("my-page", params);

// From URL
navigation_manager_->navigateFromUrl("/my-page?id=123&mode=edit");
```

---

## Common Patterns

### Pattern 1: Navigation Guard (Prevent Navigation)

```cpp
navigation_manager_->addBeforeGuard([this](const std::string& path, const RouteParams&) {
    if (hasUnsavedChanges() && path != "current-page") {
        // Show dialog, return user's choice
        return showConfirmDialog("Unsaved changes. Continue?");
    }
    return true;
});
```

### Pattern 2: State Persistence

```cpp
class MyPageLifecycle : public PageLifecycle {
    std::string saveState() const override {
        return "{\"scroll_position\":" + std::to_string(scroll_pos_) + "}";
    }
    
    void restoreState(const std::string& state) override {
        // Parse and restore scroll_pos_
    }
    
private:
    int scroll_pos_ = 0;
};

// Register with lifecycle
auto lifecycle = std::make_shared<MyPageLifecycle>();
navigation_manager_->registerPage("page", "page", init_fn, lifecycle);
```

### Pattern 3: Error Handling

```cpp
auto result = navigation_manager_->navigate("page");
if (!result.success) {
    switch (result.error) {
        case NavigationError::PageNotFound:
            showError("Page not found");
            break;
        case NavigationError::NavigationBlocked:
            showWarning("Navigation blocked: " + result.error_message);
            break;
        default:
            showError("Navigation failed: " + result.error_message);
    }
}
```

### Pattern 4: Deep Linking

```cpp
// Handle app startup with URL
void handleStartupUrl(const std::string& url) {
    if (!url.empty()) {
        navigation_manager_->navigateFromUrl(url);
    } else {
        navigation_manager_->navigate("home");
    }
}
```

---

## Complete Example

```cpp
class AppPresenter {
    void initialize() {
        navigation_manager_ = std::make_unique<NavigationManager>(window_);
        
        // Register pages
        navigation_manager_->registerPage("home", "home", 
            [this](const RouteParams&) { initHomePage(); });
        
        navigation_manager_->registerPage("settings", "settings",
            [this](const RouteParams& params) { initSettingsPage(params); });
        
        // Add guard
        navigation_manager_->addBeforeGuard([this](const std::string& path, const RouteParams&) {
            return canNavigate(path);
        });
        
        // Navigate to home
        navigation_manager_->navigate("home");
    }
};
```

That's it! Your navigation system is ready to use! 🚀
