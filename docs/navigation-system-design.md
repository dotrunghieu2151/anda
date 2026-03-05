# Slint Navigation System Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    MainWindow                            │
│  - Manages viewport (width, height, docking)            │
│  - Navigation state (current page, history, retained)   │
│  - Global state (shared across pages)                   │
│  - Page registry (path → Page component)                │
│  - Navigation functions (Navigate, Back, Next)           │
└────────────────────┬────────────────────────────────────┘
                     │
                     │ (manages lifecycle)
                     │
┌────────────────────▼────────────────────────────────────┐
│                    Page Component                        │
│  - Composes UI components                                │
│  - Exposes interface via globals                         │
│  - Lifecycle: init(), destroy()                          │
│  - Receives route params                                 │
│  - Accesses Window global state                          │
└─────────────────────────────────────────────────────────┘
```

---

## Design Decisions

### 1. **Page Registration**
- Pages register with unique path identifier
- Each page provides init function (callback)
- Registration happens in C++ presenter layer

### 2. **Navigation State**
- Current page path
- Navigation history (for Back button)
- Retained pages map (path → Page instance)
- Route parameters

### 3. **Component Instantiation**
- Use conditional rendering (`if` statements) to show/hide pages
- All pages instantiated but only one visible
- Retained pages remain in memory but hidden

### 4. **State Management**
- Window global state (shared)
- Page-specific state (via page globals)
- Route params (passed during navigation)

---

## Implementation

### Step 1: MainWindow Component

```slint
// src/ui/navigation/main-window.slint

import { VerticalBox } from "std-widgets.slint";

// Window global state (shared across all pages)
export global WindowState {
    in-out property <string> current-page-path: "";
    in-out property <string> previous-page-path: "";
    in-out property <[string]> navigation-history: [];
    in-out property <string> route-params: "";  // JSON string
    
    // Navigation functions
    callback navigate(string path, string params, bool retain-current);
    callback navigate-back();
    callback navigate-forward();
    
    // Page lifecycle
    callback page-initialized(string path);
    callback page-destroyed(string path);
}

// Main window component
export component MainWindow inherits Window {
    title: "Anda - Real-time Transcription & Translation";
    background: #0f0f1e;
    preferred-width: 1200px;
    preferred-height: 900px;
    min-width: 900px;
    min-height: 700px;
    
    // Window global state
    in-out property <string> global-state: "";  // JSON string for arbitrary state
    
    // Page registry (managed by C++)
    in property <[string]> registered-pages: [];
    
    // Current page component (set by C++)
    in property <string> current-page-component: "";
    
    // Retained pages (set by C++)
    in property <[string]> retained-page-paths: [];
    
    VerticalBox {
        spacing: 0;
        
        // Render current page (conditional)
        // This will be managed by C++ presenter
        // Pages are rendered conditionally based on current-page-component
    }
}
```

### Step 2: Page Component Base

```slint
// src/ui/navigation/page.slint

import { WindowState } from "./main-window.slint";

// Base page component that all pages inherit from
export component Page {
    in property <string> page-path;
    in property <string> route-params: "";  // JSON string
    in property <bool> is-active: false;
    in property <bool> is-retained: false;
    
    // Page-specific global adapter (each page defines its own)
    // This is a placeholder - each page will export its own adapter
    
    // Lifecycle callbacks (called by C++)
    callback on-init(string params);
    callback on-destroy();
    
    // Access to window state
    in property <string> window-global-state: WindowState.global-state;
    
    // Hide page when not active
    visible: root.is-active || root.is-retained;
    opacity: root.is-active ? 1.0 : 0.0;
    
    // Page content (to be overridden by specific pages)
    Rectangle {
        background: transparent;
        // Page-specific content goes here
    }
}
```

### Step 3: Example Page Implementation

```slint
// src/ui/pages/home-page.slint

import { Page } from "../navigation/page.slint";
import { VerticalBox } from "std-widgets.slint";
import { AppHeader } from "../components/header.slint";

// Page-specific global adapter
export global HomePageAdapter {
    in-out property <string> welcome-message: "Welcome to Anda";
    callback button-clicked();
}

// Home page component
export component HomePage inherits Page {
    VerticalBox {
        spacing: 16px;
        padding: 20px;
        
        AppHeader {
            title: "Home";
        }
        
        Text {
            text: HomePageAdapter.welcome-message;
            font-size: 18px;
            color: #e0e0e0;
        }
        
        Button {
            text: "Go to Settings";
            clicked => {
                WindowState.navigate("settings", "", false);
            }
        }
    }
}
```

### Step 4: C++ Navigation Manager

```cpp
// src/navigation/navigation_manager.hpp
#pragma once

#include <string>
#include <unordered_map>
#include <vector>
#include <functional>
#include <memory>
#include "main-window.h"

struct RouteParams {
    std::unordered_map<std::string, std::string> params;
    
    std::string toJson() const {
        // Simple JSON serialization
        std::string json = "{";
        bool first = true;
        for (const auto& [key, value] : params) {
            if (!first) json += ",";
            json += "\"" + key + "\":\"" + value + "\"";
            first = false;
        }
        json += "}";
        return json;
    }
    
    static RouteParams fromJson(const std::string& json) {
        RouteParams params;
        // Simple JSON parsing (use proper library in production)
        // For now, just return empty
        return params;
    }
};

class PageLifecycle {
public:
    virtual ~PageLifecycle() = default;
    virtual void init(const RouteParams& params) = 0;
    virtual void destroy() = 0;
};

class NavigationManager {
public:
    struct PageRegistration {
        std::string path;
        std::function<void(const RouteParams&)> init_fn;
        std::shared_ptr<PageLifecycle> lifecycle;
        bool is_retained = false;
    };
    
    NavigationManager(std::shared_ptr<MainWindow> window);
    
    // Register a page
    void registerPage(
        const std::string& path,
        std::function<void(const RouteParams&)> init_fn,
        std::shared_ptr<PageLifecycle> lifecycle = nullptr
    );
    
    // Navigation functions
    void navigate(const std::string& path, const RouteParams& params = {}, bool retain_current = false);
    void navigateBack();
    void navigateForward();
    
    // Page lifecycle
    void initializePage(const std::string& path, const RouteParams& params);
    void destroyPage(const std::string& path, bool force = false);
    
    // State management
    void setGlobalState(const std::string& state_json);
    std::string getGlobalState() const;
    
private:
    std::shared_ptr<MainWindow> window_;
    std::unordered_map<std::string, PageRegistration> registered_pages_;
    std::vector<std::string> navigation_history_;
    std::string current_page_path_;
    std::unordered_map<std::string, bool> retained_pages_;
    int history_index_ = -1;
    
    void updateWindowState();
    void cleanupRetainedPages();
};
```

### Step 5: C++ Implementation

```cpp
// src/navigation/navigation_manager.cpp
#include "navigation_manager.hpp"
#include "main-window.h"
#include <slint.h>

NavigationManager::NavigationManager(std::shared_ptr<MainWindow> window)
    : window_(window)
{
    // Set up navigation callbacks
    window_->global<WindowState>().on_navigate([this](slint::SharedString path, 
                                                       slint::SharedString params,
                                                       bool retain_current) {
        RouteParams route_params = RouteParams::fromJson(std::string(params));
        navigate(std::string(path), route_params, retain_current);
    });
    
    window_->global<WindowState>().on_navigate_back([this]() {
        navigateBack();
    });
    
    window_->global<WindowState>().on_navigate_forward([this]() {
        navigateForward();
    });
}

void NavigationManager::registerPage(
    const std::string& path,
    std::function<void(const RouteParams&)> init_fn,
    std::shared_ptr<PageLifecycle> lifecycle)
{
    PageRegistration reg;
    reg.path = path;
    reg.init_fn = init_fn;
    reg.lifecycle = lifecycle;
    registered_pages_[path] = reg;
    
    // Update window with registered pages list
    std::vector<slint::SharedString> paths;
    for (const auto& [p, _] : registered_pages_) {
        paths.push_back(slint::SharedString(p));
    }
    window_->global<WindowState>().set_registered_pages(
        slint::SharedStringVector(paths));
}

void NavigationManager::navigate(const std::string& path, 
                                 const RouteParams& params,
                                 bool retain_current) {
    // Check if page exists
    if (registered_pages_.find(path) == registered_pages_.end()) {
        spdlog::warn("Page not found: {}", path);
        return;
    }
    
    // Destroy current page (unless retained)
    if (!current_page_path_.empty() && !retain_current) {
        destroyPage(current_page_path_, false);
    }
    
    // Retain current page if requested
    if (retain_current && !current_page_path_.empty()) {
        retained_pages_[current_page_path_] = true;
    }
    
    // Update history
    if (history_index_ >= 0 && 
        history_index_ < navigation_history_.size() - 1) {
        // We're in the middle of history, truncate forward
        navigation_history_.erase(
            navigation_history_.begin() + history_index_ + 1,
            navigation_history_.end());
    }
    
    navigation_history_.push_back(path);
    history_index_ = navigation_history_.size() - 1;
    
    // Initialize new page
    current_page_path_ = path;
    initializePage(path, params);
    
    updateWindowState();
}

void NavigationManager::initializePage(const std::string& path, 
                                      const RouteParams& params) {
    auto& reg = registered_pages_[path];
    
    // Call init function
    if (reg.init_fn) {
        reg.init_fn(params);
    }
    
    // Call lifecycle init
    if (reg.lifecycle) {
        reg.lifecycle->init(params);
    }
    
    // Notify window
    window_->global<WindowState>().invoke_page_initialized(
        slint::SharedString(path));
}

void NavigationManager::destroyPage(const std::string& path, bool force) {
    // Don't destroy if retained (unless forced)
    if (!force && retained_pages_.find(path) != retained_pages_.end()) {
        return;
    }
    
    auto& reg = registered_pages_[path];
    
    // Call lifecycle destroy
    if (reg.lifecycle) {
        reg.lifecycle->destroy();
    }
    
    // Remove from retained if present
    retained_pages_.erase(path);
    
    // Notify window
    window_->global<WindowState>().invoke_page_destroyed(
        slint::SharedString(path));
}

void NavigationManager::updateWindowState() {
    auto& state = window_->global<WindowState>();
    
    state.set_current_page_path(slint::SharedString(current_page_path_));
    
    // Update previous page path
    if (navigation_history_.size() > 1) {
        state.set_previous_page_path(
            slint::SharedString(navigation_history_[navigation_history_.size() - 2]));
    }
    
    // Update history
    std::vector<slint::SharedString> history;
    for (const auto& path : navigation_history_) {
        history.push_back(slint::SharedString(path));
    }
    state.set_navigation_history(slint::SharedStringVector(history));
    
    // Update retained pages
    std::vector<slint::SharedString> retained;
    for (const auto& [path, _] : retained_pages_) {
        retained.push_back(slint::SharedString(path));
    }
    window_->set_retained_page_paths(slint::SharedStringVector(retained));
}
```

---

## Recommendations & Improvements

### 1. **Component Factory Pattern**

Instead of conditional rendering, use a factory pattern:

```slint
// In MainWindow
export component MainWindow inherits Window {
    // ... other properties
    
    // Page factory - C++ sets which page component to show
    in property <string> current-page-type: "";
    
    VerticalBox {
        if root.current-page-type == "home": HomePage {
            page-path: "home";
            route-params: WindowState.route-params;
            is-active: true;
        }
        
        if root.current-page-type == "settings": SettingsPage {
            page-path: "settings";
            route-params: WindowState.route-params;
            is-active: true;
        }
        
        // ... other pages
    }
}
```

### 2. **Better Route Params**

Use a proper struct instead of JSON string:

```slint
struct RouteParams {
    path: string,
    query-params: [string],
    fragment: string,
}

export global WindowState {
    in-out property <RouteParams> route-params: { path: "", query-params: [], fragment: "" };
    // ...
}
```

### 3. **Navigation Guards**

Add before/after navigation hooks:

```cpp
class NavigationManager {
    using NavigationGuard = std::function<bool(const std::string&, const RouteParams&)>;
    
    void addBeforeGuard(NavigationGuard guard);
    void addAfterGuard(NavigationGuard guard);
    
private:
    std::vector<NavigationGuard> before_guards_;
    std::vector<NavigationGuard> after_guards_;
};
```

### 4. **Page State Persistence**

Allow pages to save/restore state:

```cpp
class PageLifecycle {
    virtual std::string saveState() const = 0;
    virtual void restoreState(const std::string& state) = 0;
};
```

### 5. **Deep Linking**

Support URL-based navigation:

```cpp
void navigateFromUrl(const std::string& url) {
    // Parse URL: /page/path?param=value#fragment
    // Extract path, query params, fragment
    // Navigate accordingly
}
```

---

## Usage Example

```cpp
// In presenter
void AppPresenter::initialize() {
    // Create navigation manager
    navigation_manager_ = std::make_unique<NavigationManager>(window_);
    
    // Register pages
    navigation_manager_->registerPage("home", [this](const RouteParams& params) {
        // Initialize home page
        window_->global<HomePageAdapter>().set_welcome_message("Welcome!");
    });
    
    navigation_manager_->registerPage("settings", [this](const RouteParams& params) {
        // Initialize settings page
        auto device_id = params.params.find("device");
        if (device_id != params.params.end()) {
            // Use device_id
        }
    });
    
    // Navigate to home
    navigation_manager_->navigate("home");
}

// Navigate with params
void navigateToSettings(int device_id) {
    RouteParams params;
    params.params["device"] = std::to_string(device_id);
    navigation_manager_->navigate("settings", params);
}
```

---

## Summary

This design provides:
- ✅ Clean separation of concerns
- ✅ Page lifecycle management
- ✅ State management (Window + Page)
- ✅ Navigation history
- ✅ Page retention
- ✅ Route parameters
- ✅ Easy C++ integration

The system is extensible and follows Slint best practices!
