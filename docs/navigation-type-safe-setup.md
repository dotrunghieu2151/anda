# Type-Safe Navigation Setup Guide

## Quick Setup

### Step 1: Create PageParams Struct

```cpp
// src/pages/my_page_params.hpp
#pragma once

#include "../navigation/navigation_manager.hpp"
#include <string>

struct MyPageParams {
    std::string id;
    std::string mode;
    
    RouteParams toRouteParams() const {
        RouteParams params;
        if (!id.empty()) params.set("id", id);
        if (!mode.empty()) params.set("mode", mode);
        return params;
    }
    
    static MyPageParams fromRouteParams(const RouteParams& route_params) {
        MyPageParams params;
        if (auto id = route_params.get("id")) {
            params.id = *id;
        }
        if (auto mode = route_params.get("mode")) {
            params.mode = *mode;
        }
        return params;
    }
};
```

### Step 2: Add Traits Specialization

```cpp
// In page_traits_impl.hpp, add:

#include "pages/my_page_params.hpp"
#include "my-page.h"  // Generated Slint header

template<>
struct PageParamsType<MyPage> {
    using type = MyPageParams;
};

template<>
struct PagePath<MyPage> {
    static constexpr const char* value = "my-page";
};
```

### Step 3: Use Type-Safe Navigation

```cpp
// In your code
#include "navigation/navigation_manager.hpp"
#include "navigation/page_traits_impl.hpp"

// Type-safe navigation
navigation_manager_->navigate<MyPage>(
    MyPageParams{"123", "edit"}
);
```

---

## File Structure

```
src/
├── navigation/
│   ├── navigation_manager.hpp      # NavigationManager class
│   ├── navigation_manager.cpp
│   ├── page_traits.hpp             # Base template definitions
│   └── page_traits_impl.hpp        # Specializations (edit this)
├── pages/
│   ├── home_page_params.hpp         # HomePageParams definition
│   ├── settings_page_params.hpp     # SettingsPageParams definition
│   └── my_page_params.hpp           # Your new page params
└── presenters/
    └── app_presenter.cpp             # Uses NavigationManager
```

---

## Adding a New Page

### 1. Create PageParams Header

```cpp
// src/pages/profile_page_params.hpp
#pragma once

#include "../navigation/navigation_manager.hpp"
#include <string>

struct ProfilePageParams {
    std::string user_id;
    int tab_index = 0;
    
    RouteParams toRouteParams() const {
        RouteParams params;
        if (!user_id.empty()) params.set("user-id", user_id);
        params.set("tab-index", std::to_string(tab_index));
        return params;
    }
    
    static ProfilePageParams fromRouteParams(const RouteParams& route_params) {
        ProfilePageParams params;
        if (auto user_id = route_params.get("user-id")) {
            params.user_id = *user_id;
        }
        if (auto tab = route_params.get("tab-index")) {
            params.tab_index = std::stoi(*tab);
        }
        return params;
    }
};
```

### 2. Update page_traits_impl.hpp

```cpp
// Add includes
#include "pages/profile_page_params.hpp"
#include "profile-page.h"  // Generated Slint header

// Add specializations
template<>
struct PageParamsType<ProfilePage> {
    using type = ProfilePageParams;
};

template<>
struct PagePath<ProfilePage> {
    static constexpr const char* value = "profile";
};
```

### 3. Use It

```cpp
navigation_manager_->navigate<ProfilePage>(
    ProfilePageParams{"12345", 2}  // user_id, tab_index
);
```

---

## Benefits

✅ **Compile-time type checking** - Wrong params = compile error  
✅ **No string typos** - Path is inferred from type  
✅ **IDE autocomplete** - IDE knows what params are needed  
✅ **Self-documenting** - Code shows expected params  
✅ **Refactoring safe** - Type changes propagate automatically  

---

## Example: Complete Usage

```cpp
#include "navigation/navigation_manager.hpp"
#include "navigation/page_traits_impl.hpp"  // Include AFTER Slint headers

void AppPresenter::initialize() {
    navigation_manager_ = std::make_unique<NavigationManager>(window_);
    
    // Type-safe navigation
    navigation_manager_->navigate<HomePage>(
        HomePageParams{"12345", "dashboard"}
    );
    
    // Navigate to settings with params
    navigation_manager_->navigate<SettingsPage>(
        SettingsPageParams{"2", "audio"}
    );
    
    // Default params
    navigation_manager_->navigate<HomePage>();
}
```

That's it! Type-safe navigation is ready! 🎉
