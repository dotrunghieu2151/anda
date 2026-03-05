# Type-Safe Navigation API

## Overview

The navigation system now supports **compile-time type safety** through templated `navigate()` functions. When you pass a PageComponent type, the compiler automatically infers the correct PageParams type.

---

## Setup

### Step 1: Define PageParams Struct in C++

```cpp
// src/pages/home_page_params.hpp
#pragma once

#include "../navigation/navigation_manager.hpp"
#include <string>

struct HomePageParams {
    std::string user_id;
    std::string source;
    
    // Convert to RouteParams
    RouteParams toRouteParams() const {
        RouteParams params;
        if (!user_id.empty()) params.set("user-id", user_id);
        if (!source.empty()) params.set("source", source);
        return params;
    }
    
    // Create from RouteParams
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

### Step 2: Register Page Traits

```cpp
// src/navigation/page_traits.hpp
#include "home_page_params.hpp"
#include "home-page.h"  // Generated Slint header

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

### Step 3: Include Traits in NavigationManager

```cpp
// In your presenter or where NavigationManager is used
#include "navigation/navigation_manager.hpp"
#include "navigation/page_traits.hpp"  // Include after Slint headers
```

---

## Usage

### Type-Safe Navigation

```cpp
// ✅ Type-safe: Compiler knows HomePageParams is required
navigation_manager_->navigate<HomePage>(
    HomePageParams{"12345", "dashboard"}
);

// ✅ Compile error if wrong params type
// navigation_manager_->navigate<HomePage>(SettingsPageParams{});  // ERROR!

// ✅ Default params (empty struct)
navigation_manager_->navigate<HomePage>();

// ✅ With retain
navigation_manager_->navigate<HomePage>(
    HomePageParams{"12345", "dashboard"},
    true  // retain current page
);
```

### Benefits

1. **Compile-time type checking** - Wrong params type = compile error
2. **IDE autocomplete** - IDE knows what params are needed
3. **Self-documenting** - Code shows exactly what params are expected
4. **Refactoring safe** - Changing params type updates all call sites

---

## Complete Example

### Define PageParams

```cpp
// src/pages/settings_page_params.hpp
struct SettingsPageParams {
    std::string device_id;
    std::string section;
    
    RouteParams toRouteParams() const {
        RouteParams params;
        if (!device_id.empty()) params.set("device-id", device_id);
        if (!section.empty()) params.set("section", section);
        return params;
    }
    
    static SettingsPageParams fromRouteParams(const RouteParams& route_params) {
        SettingsPageParams params;
        if (auto device_id = route_params.get("device-id")) {
            params.device_id = *device_id;
        }
        if (auto section = route_params.get("section")) {
            params.section = *section;
        }
        return params;
    }
};
```

### Register Traits

```cpp
// src/navigation/page_traits.hpp
#include "settings_page_params.hpp"
#include "settings-page.h"

template<>
struct PageParamsType<SettingsPage> {
    using type = SettingsPageParams;
};

template<>
struct PagePath<SettingsPage> {
    static constexpr const char* value = "settings";
};
```

### Use Type-Safe Navigation

```cpp
// Type-safe navigation
navigation_manager_->navigate<SettingsPage>(
    SettingsPageParams{"2", "audio"}
);

// Helper function for convenience
void navigateToSettings(int device_id, const std::string& section) {
    navigation_manager_->navigate<SettingsPage>(
        SettingsPageParams{
            .device_id = std::to_string(device_id),
            .section = section
        }
    );
}
```

---

## Template Specialization Pattern

For each page, you need:

1. **Define PageParams struct** (C++ struct matching Slint struct)
2. **Specialize PageParamsType** (map Component -> ParamsType)
3. **Specialize PagePath** (map Component -> path string)

```cpp
// For a new page "ProfilePage"

// 1. Define params
struct ProfilePageParams {
    std::string user_id;
    int tab_index;
    
    RouteParams toRouteParams() const { /* ... */ }
    static ProfilePageParams fromRouteParams(const RouteParams&) { /* ... */ }
};

// 2. Register traits
template<>
struct PageParamsType<ProfilePage> {
    using type = ProfilePageParams;
};

template<>
struct PagePath<ProfilePage> {
    static constexpr const char* value = "profile";
};
```

---

## Advanced: Builder Pattern

You can also create builder helpers:

```cpp
// Helper for HomePage
struct HomePageNavigation {
    static NavigationResult go(const std::string& user_id = "", 
                              const std::string& source = "",
                              bool retain = false) {
        HomePageParams params;
        params.user_id = user_id;
        params.source = source;
        return navigation_manager_->navigate<HomePage>(params, retain);
    }
};

// Usage
HomePageNavigation::go("12345", "dashboard");
```

---

## Summary

The templated `navigate()` function provides:

- ✅ **Compile-time type safety** - Wrong params = compile error
- ✅ **IDE support** - Autocomplete for params
- ✅ **Self-documenting** - Code shows expected params
- ✅ **Refactoring safe** - Type changes propagate automatically

This makes navigation much safer and easier to use! 🎉
