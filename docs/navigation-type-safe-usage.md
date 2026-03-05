# Type-Safe Navigation - Complete Usage Guide

## Overview

The templated `navigate()` function provides **compile-time type safety** by inferring the correct PageParams type from the PageComponent type.

---

## Setup Steps

### Step 1: Define PageParams Struct in C++

```cpp
// src/pages/home_page_params.hpp
#pragma once

#include "../navigation/navigation_manager.hpp"
#include <string>

struct HomePageParams {
    std::string user_id;
    std::string source;
    
    RouteParams toRouteParams() const {
        RouteParams params;
        if (!user_id.empty()) params.set("user-id", user_id);
        if (!source.empty()) params.set("source", source);
        return params;
    }
    
    static HomePageParams fromRouteParams(const RouteParams& route_params) {
        HomePageParams params;
        if (auto user_id = route_params.get("user-id")) {
            params.user_id = *user_id;
        }
        if (auto source = route_params.get("source")) {
            params.source = *source;
        }
        return params;
    }
};
```

### Step 2: Register Traits

```cpp
// src/navigation/page_traits_impl.hpp
#include "page_traits.hpp"
#include "home-page.h"           // Generated Slint header
#include "pages/home_page_params.hpp"

// Map component type to params type
template<>
struct PageParamsType<HomePage> {
    using type = HomePageParams;
};

// Map component type to path
template<>
struct PagePath<HomePage> {
    static constexpr const char* value = "home";
};
```

### Step 3: Include Traits in Your Code

```cpp
// In presenter or wherever NavigationManager is used
#include "navigation/navigation_manager.hpp"
#include "navigation/page_traits_impl.hpp"  // Include AFTER Slint headers
```

---

## Usage Examples

### Basic Type-Safe Navigation

```cpp
// ✅ Type-safe: Compiler enforces HomePageParams
navigation_manager_->navigate<HomePage>(
    HomePageParams{"12345", "dashboard"}
);

// ✅ Default params (empty struct)
navigation_manager_->navigate<HomePage>();

// ✅ With retain
navigation_manager_->navigate<HomePage>(
    HomePageParams{"12345", "dashboard"},
    true  // retain current page
);
```

### Compile-Time Errors

```cpp
// ❌ COMPILE ERROR: Wrong params type
navigation_manager_->navigate<HomePage>(SettingsPageParams{});  // ERROR!

// ❌ COMPILE ERROR: Wrong component type
navigation_manager_->navigate<NonExistentPage>({});  // ERROR!

// ✅ Correct: Generic navigation still works
navigation_manager_->navigate("home", RouteParams{});  // OK
```

### Helper Functions

```cpp
// Create helper functions for convenience
void navigateToHome(const std::string& user_id, const std::string& source) {
    navigation_manager_->navigate<HomePage>(
        HomePageParams{user_id, source}
    );
}

void navigateToSettings(int device_id, const std::string& section) {
    navigation_manager_->navigate<SettingsPage>(
        SettingsPageParams{std::to_string(device_id), section}
    );
}

// Usage
navigateToHome("12345", "dashboard");
navigateToSettings(2, "audio");
```

### Builder Pattern

```cpp
// Create a builder for complex navigation
class NavigationBuilder {
public:
    template<typename PageComponent>
    static NavigationResult to(typename PageParamsType<PageComponent>::type params = {}) {
        return navigation_manager_->navigate<PageComponent>(params);
    }
    
    template<typename PageComponent>
    static NavigationResult toAndRetain(typename PageParamsType<PageComponent>::type params = {}) {
        return navigation_manager_->navigate<PageComponent>(params, true);
    }
};

// Usage
NavigationBuilder::to<HomePage>(HomePageParams{"123", "dashboard"});
NavigationBuilder::toAndRetain<SettingsPage>(SettingsPageParams{"2", "audio"});
```

---

## Complete Example

### File Structure

```
src/
├── navigation/
│   ├── navigation_manager.hpp
│   ├── navigation_manager.cpp
│   ├── page_traits.hpp          # Base template definitions
│   └── page_traits_impl.hpp     # Specializations (include this)
├── pages/
│   ├── home_page_params.hpp     # HomePageParams definition
│   └── settings_page_params.hpp  # SettingsPageParams definition
└── presenters/
    └── app_presenter.cpp         # Uses NavigationManager
```

### In Presenter

```cpp
// src/presenters/app_presenter.cpp
#include "navigation/navigation_manager.hpp"
#include "navigation/page_traits_impl.hpp"  // Include traits AFTER Slint headers
#include "home-page.h"
#include "settings-page.h"

void AppPresenter::initialize() {
    navigation_manager_ = std::make_unique<NavigationManager>(window_);
    
    // Register pages (path-based, for compatibility)
    navigation_manager_->registerPage("home", "home", 
        [this](const RouteParams& params) {
            // Convert to typed params
            auto typed_params = HomePageParams::fromRouteParams(params);
            initHomePage(typed_params);
        });
    
    // Type-safe navigation
    navigation_manager_->navigate<HomePage>(
        HomePageParams{"12345", "dashboard"}
    );
}

void AppPresenter::initHomePage(const HomePageParams& params) {
    auto& adapter = window_->global<HomePageAdapter>();
    
    // Use typed params
    if (!params.user_id.empty()) {
        // Handle user_id
    }
    if (!params.source.empty()) {
        // Handle source
    }
}
```

---

## Benefits

### 1. Compile-Time Type Safety

```cpp
// ✅ Correct
navigation_manager_->navigate<HomePage>(HomePageParams{"123", "dashboard"});

// ❌ Compile error - wrong params type
navigation_manager_->navigate<HomePage>(SettingsPageParams{});  // ERROR!
```

### 2. IDE Autocomplete

When you type `navigate<HomePage>(`, your IDE will:
- Show `HomePageParams` as the expected type
- Autocomplete param names
- Show type errors immediately

### 3. Self-Documenting Code

```cpp
// Clear what params are expected
navigation_manager_->navigate<HomePage>(
    HomePageParams{
        .user_id = "12345",
        .source = "dashboard"
    }
);
```

### 4. Refactoring Safe

If you change `HomePageParams`, all call sites will show compile errors, making refactoring safe.

---

## Migration from String-Based Navigation

### Before (String-based)

```cpp
RouteParams params;
params.set("user-id", "12345");
params.set("source", "dashboard");
navigation_manager_->navigate("home", params);
```

### After (Type-safe)

```cpp
navigation_manager_->navigate<HomePage>(
    HomePageParams{"12345", "dashboard"}
);
```

**Benefits:**
- ✅ Compile-time checking
- ✅ No typos in param names
- ✅ Clear what params are expected
- ✅ IDE autocomplete

---

## Summary

The templated `navigate()` function provides:

1. **Type safety** - Compiler enforces correct params type
2. **Path inference** - No need to specify path string
3. **IDE support** - Autocomplete and type checking
4. **Self-documenting** - Code shows expected params
5. **Refactoring safe** - Type changes propagate automatically

This makes navigation much safer and easier to use! 🎉
