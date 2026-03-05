# Enhanced Navigation System Features

## Overview

This document describes the enhanced features added to the navigation system:
1. Type-safe route parameters (structs)
2. Navigation guards
3. State persistence
4. Deep linking
5. Error handling

---

## 1. Type-Safe Route Parameters

### Slint Definition

```slint
// In main-window.slint
struct RouteParam {
    key: string,
    value: string,
}

export global WindowState {
    in-out property <[RouteParam]> route-params: [];
    callback navigate(string path, [RouteParam] params, bool retain-current);
}
```

### Page-Specific Params

Each page defines its expected parameters:

```slint
// In home-page.slint
struct HomePageParams {
    user-id: string,
    source: string,
}

export component HomePage inherits Page {
    // Extract params using helper function
    private property <string> user-id: root.get-param("user-id");
    private property <string> source: root.get-param("source");
    
    // Use params in UI
    if root.user-id.length > 0: Text {
        text: "User: " + root.user-id;
    }
}
```

### C++ Usage

```cpp
// Navigate with type-safe params
RouteParams params;
params.set("user-id", "12345");
params.set("source", "dashboard");

auto result = navigation_manager_->navigate("home", params);
if (!result.success) {
    spdlog::error("Navigation failed: {}", result.error_message);
}
```

---

## 2. Navigation Guards

### Adding Guards

```cpp
// Prevent navigation if form has unsaved changes
navigation_manager_->addBeforeGuard([this](const std::string& path, const RouteParams& params) {
    if (hasUnsavedChanges()) {
        // Show confirmation dialog
        // Return false to block navigation
        return false;
    }
    return true;  // Allow navigation
});

// Log all navigation attempts
navigation_manager_->addAfterGuard([this](const std::string& path, const RouteParams& params) {
    spdlog::info("Navigated to: {}", path);
    return true;  // After guards can't block, but can perform actions
});
```

### Guard Execution Order

```
1. Before guards (can block navigation)
   ↓ (if all return true)
2. Save current page state
   ↓
3. Destroy current page
   ↓
4. Initialize new page
   ↓
5. After guards (for logging/cleanup)
```

---

## 3. State Persistence

### Page Lifecycle with State

```cpp
class SettingsPageLifecycle : public PageLifecycle {
public:
    void init(const RouteParams& params) override {
        // Initialize page
        loadSettings();
    }
    
    void destroy() override {
        // Cleanup
    }
    
    std::string saveState() const override {
        // Save form state to JSON
        return "{\"device_index\":" + std::to_string(device_index_) + 
               ",\"language_index\":" + std::to_string(language_index_) + "}";
    }
    
    void restoreState(const std::string& state) override {
        // Restore form state from JSON
        // Parse state and restore device_index_, language_index_, etc.
    }

private:
    int device_index_ = 0;
    int language_index_ = 0;
};
```

### Automatic State Management

```cpp
// Register page with lifecycle
auto lifecycle = std::make_shared<SettingsPageLifecycle>();
navigation_manager_->registerPage(
    "settings",
    "settings",
    [this](const RouteParams& params) { initSettingsPage(params); },
    lifecycle
);

// State is automatically saved/restored during navigation
navigation_manager_->navigate("home");  // Saves settings state
navigation_manager_->navigate("settings");  // Restores settings state
```

---

## 4. Deep Linking

### URL Format

```
/page/path?param1=value1&param2=value2#fragment
```

### Usage

```cpp
// Navigate from URL
auto result = navigation_manager_->navigateFromUrl("/settings?device=1&section=audio");

// Parse and navigate
if (result.success) {
    spdlog::info("Navigated successfully");
} else {
    spdlog::error("Navigation failed: {}", result.error_message);
}

// Example URLs:
navigation_manager_->navigateFromUrl("/home");
navigation_manager_->navigateFromUrl("/settings?device=2");
navigation_manager_->navigateFromUrl("/home?user-id=123&source=dashboard#welcome");
```

### URL Parsing

The `parseUrl` function extracts:
- **Path**: `/page/path` → `"page/path"`
- **Query params**: `?key=value` → `RouteParams{key: "value"}`
- **Fragment**: `#fragment` → stored but not used by default

---

## 5. Error Handling

### NavigationResult

```cpp
struct NavigationResult {
    bool success;
    NavigationError error;
    std::string error_message;
    
    static NavigationResult ok();
    static NavigationResult fail(NavigationError err, const std::string& msg = "");
};
```

### Error Types

```cpp
enum class NavigationError {
    PageNotFound,        // Page path not registered
    NavigationBlocked,   // Guard blocked navigation
    InvalidParams,       // Invalid route parameters
    LifecycleError,      // Page init/destroy failed
    UnknownError         // Unexpected error
};
```

### Usage

```cpp
// Check navigation result
auto result = navigation_manager_->navigate("invalid-page");
if (!result.success) {
    switch (result.error) {
        case NavigationError::PageNotFound:
            spdlog::error("Page not found: {}", result.error_message);
            break;
        case NavigationError::NavigationBlocked:
            spdlog::warn("Navigation blocked: {}", result.error_message);
            // Show user-friendly message
            break;
        // ... handle other errors
    }
}

// Error is also set in WindowState (accessible from Slint)
// WindowState.navigation-error contains the error message
```

### Error Display in UI

```slint
// In MainWindow or error component
if WindowState.navigation-error.length > 0: Rectangle {
    background: #ff3366;
    
    Text {
        text: "Error: " + WindowState.navigation-error;
        color: #ffffff;
    }
    
    Button {
        text: "Dismiss";
        clicked => {
            WindowState.navigation-error = "";
        }
    }
}
```

---

## Complete Example: Using All Features

```cpp
class AppPresenter {
public:
    void initialize() {
        navigation_manager_ = std::make_unique<NavigationManager>(window_);
        
        // Register pages with lifecycle
        auto settings_lifecycle = std::make_shared<SettingsPageLifecycle>();
        navigation_manager_->registerPage(
            "settings",
            "settings",
            [this](const RouteParams& params) { initSettingsPage(params); },
            settings_lifecycle
        );
        
        // Add navigation guard
        navigation_manager_->addBeforeGuard([this](const std::string& path, const RouteParams&) {
            if (hasUnsavedChanges() && path != "settings") {
                // Show confirmation dialog
                return showConfirmDialog("You have unsaved changes. Continue?");
            }
            return true;
        });
        
        // Navigate with params
        RouteParams params;
        params.set("device-id", "2");
        params.set("section", "audio");
        navigation_manager_->navigate("settings", params);
        
        // Or navigate from URL
        navigation_manager_->navigateFromUrl("/settings?device-id=2&section=audio");
    }
    
private:
    bool hasUnsavedChanges() {
        // Check if current page has unsaved changes
        return false;
    }
    
    bool showConfirmDialog(const std::string& message) {
        // Show dialog, return user's choice
        return true;
    }
};
```

---

## Summary

All recommended features are now implemented:

✅ **Type-safe route params** - Struct-based, each page defines its params  
✅ **Navigation guards** - Before/after hooks to control navigation  
✅ **State persistence** - Automatic save/restore of page state  
✅ **Deep linking** - URL-based navigation with query params  
✅ **Error handling** - Comprehensive error reporting and handling  

The navigation system is now production-ready! 🚀
