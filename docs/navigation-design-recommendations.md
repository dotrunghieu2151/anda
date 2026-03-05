# Navigation System Design Recommendations

## Design Review

Your requirements are well-thought-out! Here are my recommendations and potential improvements:

---

## ✅ What's Good About Your Design

1. **Clear separation** - MainWindow handles viewport, Pages handle content
2. **Lifecycle management** - Init/destroy hooks are essential
3. **State management** - Window global state + Page state is a good pattern
4. **Page retention** - Useful for complex pages that are expensive to recreate
5. **Route parameters** - Essential for deep linking and passing data

---

## 🔧 Recommended Improvements

### 1. **Component Instantiation Strategy**

**Current:** All pages instantiated, shown/hidden conditionally

**Recommendation:** Use a factory pattern or lazy loading

```slint
// Option A: Factory pattern (what I implemented)
if root.current-page-component == "home": HomePage { ... }
if root.current-page-component == "settings": SettingsPage { ... }

// Option B: Single page container (more dynamic)
Rectangle {
    // C++ sets which page component to show
    // Only one page instance exists at a time
}
```

**Why:** Reduces memory usage, especially with many pages.

### 2. **Route Parameters - Use Struct Instead of JSON**

**Current:** JSON string for route params

**Better:** Use Slint struct

```slint
struct RouteParam {
    key: string,
    value: string,
}

export global WindowState {
    in-out property <[RouteParam]> route-params: [];
    // ...
}
```

**Why:** Type-safe, easier to work with in Slint, no JSON parsing needed.

### 3. **Navigation Guards**

**Add:** Before/after navigation hooks

```cpp
class NavigationManager {
    using NavigationGuard = std::function<bool(const std::string&, const RouteParams&)>;
    
    void addBeforeGuard(NavigationGuard guard);
    void addAfterGuard(NavigationGuard guard);
    
    // Example: Prevent navigation if form is dirty
    navigation_manager_->addBeforeGuard([this](const std::string& path, const RouteParams&) {
        if (hasUnsavedChanges()) {
            // Show confirmation dialog
            return false;  // Cancel navigation
        }
        return true;  // Allow navigation
    });
};
```

**Why:** Essential for preventing data loss, handling permissions, etc.

### 4. **Page State Persistence**

**Add:** Save/restore page state automatically

```cpp
class PageLifecycle {
    virtual std::string saveState() const = 0;
    virtual void restoreState(const std::string& state) = 0;
};

// NavigationManager automatically saves/restores state
void navigate(const std::string& path) {
    // Save current page state
    if (current_lifecycle_) {
        saved_states_[current_page_path_] = current_lifecycle_->saveState();
    }
    
    // Navigate...
    
    // Restore target page state if it exists
    if (saved_states_.find(path) != saved_states_.end()) {
        target_lifecycle_->restoreState(saved_states_[path]);
    }
}
```

**Why:** Better UX - users don't lose their work when navigating.

### 5. **Deep Linking Support**

**Add:** URL-based navigation

```cpp
void navigateFromUrl(const std::string& url) {
    // Parse: /page/path?param=value&param2=value2#fragment
    URLParser parser(url);
    
    RouteParams params;
    for (const auto& [key, value] : parser.queryParams()) {
        params.params[key] = value;
    }
    
    navigate(parser.path(), params);
}
```

**Why:** Enables bookmarking, external links, browser integration.

### 6. **Page Transitions/Animations**

**Add:** Transition effects between pages

```slint
export component Page {
    // ... existing properties
    
    animate opacity {
        duration: 200ms;
        easing: ease-in-out;
    }
    
    animate x {
        duration: 300ms;
        easing: ease-out;
    }
    
    // Slide transition
    x: root.is-active ? 0px : (root.is-entering ? -parent.width : parent.width);
    opacity: root.is-active ? 1.0 : 0.0;
}
```

**Why:** Better UX, smoother navigation experience.

### 7. **Page Stack Management**

**Current:** Simple history array

**Better:** Explicit stack with max depth

```cpp
class NavigationManager {
    struct PageStackEntry {
        std::string path;
        RouteParams params;
        std::string saved_state;
    };
    
    std::vector<PageStackEntry> page_stack_;
    size_t max_stack_depth_ = 10;
    
    void pushPage(const std::string& path, const RouteParams& params) {
        if (page_stack_.size() >= max_stack_depth_) {
            page_stack_.erase(page_stack_.begin());  // Remove oldest
        }
        page_stack_.push_back({path, params, ""});
    }
};
```

**Why:** Prevents memory bloat, better control over navigation history.

### 8. **Error Handling**

**Add:** Navigation error handling

```cpp
enum class NavigationError {
    PageNotFound,
    NavigationBlocked,
    InvalidParams,
    LifecycleError
};

using NavigationResult = std::expected<void, NavigationError>;

NavigationResult navigate(const std::string& path, ...) {
    if (!isPageRegistered(path)) {
        return std::unexpected(NavigationError::PageNotFound);
    }
    
    // Check guards
    for (auto& guard : before_guards_) {
        if (!guard(path, params)) {
            return std::unexpected(NavigationError::NavigationBlocked);
        }
    }
    
    // ... navigation logic
    
    return {};
}
```

**Why:** Better error handling, easier debugging.

---

## 🎯 Alternative Architecture Consideration

### Option: Single Page Container

Instead of conditional rendering, use a single container:

```slint
export component MainWindow inherits Window {
    // C++ sets page component dynamically
    in property <component> current-page;
    
    VerticalBox {
        @children
    }
}
```

**Pros:**
- More dynamic
- Only one page in memory
- Easier to add transitions

**Cons:**
- Requires Slint component references (more complex)
- Less type-safe

**Recommendation:** Stick with conditional rendering for now (simpler, more type-safe).

---

## 📋 Implementation Checklist

- [x] MainWindow component with viewport management
- [x] Page base component with lifecycle
- [x] NavigationManager C++ class
- [x] Page registration system
- [x] Navigation functions (Navigate, Back, Forward)
- [x] Route parameters
- [x] Page retention
- [x] Global state management
- [ ] Navigation guards (recommended)
- [ ] Page state persistence (recommended)
- [ ] Deep linking (recommended)
- [ ] Page transitions (optional)
- [ ] Error handling (recommended)

---

## 🚀 Quick Start

1. **Create MainWindow** - ✅ Done
2. **Create Page base** - ✅ Done  
3. **Create example pages** - ✅ Done (HomePage, SettingsPage)
4. **Create NavigationManager** - ✅ Done
5. **Wire up in presenter** - See `navigation-usage-example.md`

---

## Summary

Your design is solid! The main recommendations are:

1. **Use structs for route params** (instead of JSON strings)
2. **Add navigation guards** (prevent unwanted navigation)
3. **Add state persistence** (save/restore page state)
4. **Add deep linking** (URL-based navigation)
5. **Add error handling** (better robustness)

The current implementation provides a solid foundation that you can extend with these features as needed! 🎉
