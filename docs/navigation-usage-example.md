# Navigation System Usage Example

## Complete Example: Setting Up Navigation

### Step 1: Update MainWindow to Render Pages

```slint
// src/ui/navigation/main-window.slint
import { HomePage } from "../pages/home-page.slint";
import { SettingsPage } from "../pages/settings-page.slint";

export component MainWindow inherits Window {
    // ... existing properties
    
    VerticalBox {
        spacing: 0;
        width: 100%;
        height: 100%;
        
        // Render pages conditionally based on current-page-component
        if root.current-page-component == "home": HomePage {
            page-path: "home";
            route-params: WindowState.route-params;
            is-active: WindowState.current-page-path == "home";
            is-retained: root.retained-page-paths.find("home") != -1;
            on-init(params) => {
                // Called when page is initialized
            }
            on-destroy => {
                // Called when page is destroyed
            }
        }
        
        if root.current-page-component == "settings": SettingsPage {
            page-path: "settings";
            route-params: WindowState.route-params;
            is-active: WindowState.current-page-path == "settings";
            is-retained: root.retained-page-paths.find("settings") != -1;
            on-init(params) => {
                // Called when page is initialized
            }
            on-destroy => {
                // Called when page is destroyed
            }
        }
    }
}
```

### Step 2: Create Presenter with Navigation

```cpp
// src/presenters/app_presenter.hpp
#pragma once

#include "main-window.h"
#include "../navigation/navigation_manager.hpp"
#include <memory>

class AppPresenter {
public:
    AppPresenter(std::shared_ptr<MainWindow> window);
    void initialize();

private:
    std::shared_ptr<MainWindow> window_;
    std::unique_ptr<NavigationManager> navigation_manager_;
    
    // Page initialization functions
    void initHomePage(const RouteParams& params);
    void initSettingsPage(const RouteParams& params);
    
    // Page lifecycle handlers
    void setupHomePageCallbacks();
    void setupSettingsPageCallbacks();
};
```

### Step 3: Implement Presenter

```cpp
// src/presenters/app_presenter.cpp
#include "app_presenter.hpp"
#include "main-window.h"
#include "../navigation/navigation_manager.hpp"
#include <slint.h>

AppPresenter::AppPresenter(std::shared_ptr<MainWindow> window)
    : window_(window)
    , navigation_manager_(std::make_unique<NavigationManager>(window))
{
}

void AppPresenter::initialize() {
    // Register pages
    navigation_manager_->registerPage(
        "home",
        "home",  // Component name
        [this](const RouteParams& params) {
            initHomePage(params);
        }
    );
    
    navigation_manager_->registerPage(
        "settings",
        "settings",  // Component name
        [this](const RouteParams& params) {
            initSettingsPage(params);
        }
    );
    
    // Set up page callbacks
    setupHomePageCallbacks();
    setupSettingsPageCallbacks();
    
    // Navigate to home page
    navigation_manager_->navigate("home");
}

void AppPresenter::initHomePage(const RouteParams& params) {
    auto& adapter = window_->global<HomePageAdapter>();
    
    // Initialize page state
    adapter.set_welcome_message("Welcome to Anda!");
    adapter.set_visit_count(adapter.get_visit_count() + 1);
    
    spdlog::info("Home page initialized");
}

void AppPresenter::initSettingsPage(const RouteParams& params) {
    auto& adapter = window_->global<SettingsPageAdapter>();
    
    // Check for route params
    auto device_id = params.params.find("device");
    if (device_id != params.params.end()) {
        // Use device_id parameter
        spdlog::info("Settings page initialized with device: {}", device_id->second);
    }
    
    // Initialize page state
    // ... load settings, etc.
    
    spdlog::info("Settings page initialized");
}

void AppPresenter::setupHomePageCallbacks() {
    auto& adapter = window_->global<HomePageAdapter>();
    
    adapter.on_navigate_to_settings([this]() {
        navigation_manager_->navigate("settings");
    });
    
    adapter.on_button_clicked([this]() {
        spdlog::info("Home page button clicked");
    });
}

void AppPresenter::setupSettingsPageCallbacks() {
    auto& adapter = window_->global<SettingsPageAdapter>();
    
    adapter.on_navigate_back([this]() {
        navigation_manager_->navigateBack();
    });
    
    adapter.on_save_settings([this]() {
        // Save settings logic
        spdlog::info("Settings saved");
        
        // Navigate back
        navigation_manager_->navigateBack();
    });
    
    adapter.on_input_device_changed([this](int index) {
        spdlog::info("Input device changed to index: {}", index);
        // Update audio service, etc.
    });
}
```

### Step 4: Navigate with Parameters

```cpp
// Navigate to settings with device parameter
void navigateToDeviceSettings(int device_id) {
    RouteParams params;
    params.params["device"] = std::to_string(device_id);
    navigation_manager_->navigate("settings", params);
}

// Navigate and retain current page
void navigateToSettingsAndKeepHome() {
    navigation_manager_->navigate("settings", RouteParams{}, true);
    // Home page remains in memory
}
```

### Step 5: Access Window Global State

```cpp
// Set global state (shared across all pages)
void setUserPreferences(const std::string& preferences_json) {
    navigation_manager_->setGlobalState(preferences_json);
}

// In page initialization, access global state
void initPage() {
    std::string global_state = navigation_manager_->getGlobalState();
    // Parse and use global state
}
```

---

## Advanced: Page Lifecycle with State Persistence

```cpp
class HomePageLifecycle : public PageLifecycle {
public:
    void init(const RouteParams& params) override {
        // Initialize page
        visit_count_++;
    }
    
    void destroy() override {
        // Cleanup resources
    }
    
    std::string saveState() const override {
        // Save page state to JSON
        return "{\"visit_count\":" + std::to_string(visit_count_) + "}";
    }
    
    void restoreState(const std::string& state) override {
        // Restore page state from JSON
        // Parse state and restore visit_count_, etc.
    }

private:
    int visit_count_ = 0;
};

// Register with lifecycle
auto lifecycle = std::make_shared<HomePageLifecycle>();
navigation_manager_->registerPage(
    "home",
    "home",
    [this](const RouteParams& params) { initHomePage(params); },
    lifecycle
);
```

---

## Summary

The navigation system provides:

1. **MainWindow** - Manages viewport and navigation state
2. **Page components** - Individual pages with lifecycle
3. **NavigationManager** - C++ class handling navigation logic
4. **Route parameters** - Pass data between pages
5. **Page retention** - Keep pages in memory
6. **Global state** - Share state across pages
7. **Navigation history** - Back/forward support

This gives you a complete navigation system for your Slint application! 🚀
