# Todo Flattened Tree Structure

## Overview

Since Slint doesn't support recursive structs, we use a **flattened tree structure** with parent references and indentation levels. This approach is inspired by the [Slint tree view discussion](https://github.com/slint-ui/slint/discussions/1042).

## Data Structure

### Task Struct
```slint
export struct Task {
    id: string,              // Unique identifier for the task
    title: string,           // Task title
    description: string,     // Task description
    checked: bool,          // Completion status
    parent-id: string,      // Empty string for root tasks, parent task ID for sub-tasks
    indentation-level: int,  // 0 for root tasks, 1+ for nested sub-tasks
}
```

### Example Flattened Structure

**Hierarchical Structure (C++ internal):**
```
Todo: "Project Setup"
├── Task: "Design" (id: "task-1")
│   ├── Sub-task: "Wireframes" (id: "task-1-1")
│   └── Sub-task: "Mockups" (id: "task-1-2")
├── Task: "Development" (id: "task-2")
│   ├── Sub-task: "Backend" (id: "task-2-1")
│   │   └── Sub-sub-task: "API" (id: "task-2-1-1")
│   └── Sub-task: "Frontend" (id: "task-2-2")
└── Task: "Testing" (id: "task-3")
```

**Flattened Structure (passed to Slint):**
```cpp
[
    Task { id: "task-1", title: "Design", parent-id: "", indentation-level: 0 },
    Task { id: "task-1-1", title: "Wireframes", parent-id: "task-1", indentation-level: 1 },
    Task { id: "task-1-2", title: "Mockups", parent-id: "task-1", indentation-level: 1 },
    Task { id: "task-2", title: "Development", parent-id: "", indentation-level: 0 },
    Task { id: "task-2-1", title: "Backend", parent-id: "task-2", indentation-level: 1 },
    Task { id: "task-2-1-1", title: "API", parent-id: "task-2-1", indentation-level: 2 },
    Task { id: "task-2-2", title: "Frontend", parent-id: "task-2", indentation-level: 1 },
    Task { id: "task-3", title: "Testing", parent-id: "", indentation-level: 0 },
]
```

## C++ Implementation

### Flattening Algorithm

```cpp
struct HierarchicalTask {
    std::string id;
    std::string title;
    std::string description;
    bool checked = false;
    std::vector<std::unique_ptr<HierarchicalTask>> sub_tasks;
};

struct FlattenedTask {
    std::string id;
    std::string title;
    std::string description;
    bool checked;
    std::string parent_id;  // Empty for root tasks
    int indentation_level;  // 0 for root, 1+ for nested
};

class TaskFlattener {
public:
    std::vector<FlattenedTask> flatten(const std::vector<HierarchicalTask>& tasks) {
        std::vector<FlattenedTask> result;
        flatten_recursive(tasks, "", 0, result);
        return result;
    }

private:
    void flatten_recursive(
        const std::vector<HierarchicalTask>& tasks,
        const std::string& parent_id,
        int level,
        std::vector<FlattenedTask>& result
    ) {
        for (const auto& task : tasks) {
            FlattenedTask flattened;
            flattened.id = task.id;
            flattened.title = task.title;
            flattened.description = task.description;
            flattened.checked = task.checked;
            flattened.parent_id = parent_id;
            flattened.indentation_level = level;
            
            result.push_back(flattened);
            
            // Recursively flatten sub-tasks
            if (!task.sub_tasks.empty()) {
                flatten_recursive(task.sub_tasks, task.id, level + 1, result);
            }
        }
    }
};
```

### Updating Slint from C++

```cpp
#include "app-window.h"
#include "todo-page.h"
#include <slint.h>

void updateTodoTasks(slint::ComponentHandle<AppWindow>& app, const std::string& todo_id) {
    auto& view_model = app->global<TodoPageViewModel>();
    
    // Get hierarchical tasks from your data model
    auto hierarchical_tasks = todo_service_->getTasks(todo_id);
    
    // Flatten the structure
    TaskFlattener flattener;
    auto flattened = flattener.flatten(hierarchical_tasks);
    
    // Convert to Slint types
    std::vector<slint::Task> slint_tasks;
    for (const auto& task : flattened) {
        slint::Task slint_task;
        slint_task.id = slint::SharedString(task.id);
        slint_task.title = slint::SharedString(task.title);
        slint_task.description = slint::SharedString(task.description);
        slint_task.checked = task.checked;
        slint_task.parent_id = slint::SharedString(task.parent_id);
        slint_task.indentation_level = task.indentation_level;
        slint_tasks.push_back(slint_task);
    }
    
    // Update the Todo in the todos array
    auto todos = view_model.get_todos();
    for (auto& todo : todos) {
        if (std::string(todo.id) == todo_id) {
            todo.tasks = slint::VectorModel<slint::Task>(slint_tasks);
            break;
        }
    }
    view_model.set_todos(todos);
}
```

## Visual Indentation

The `TaskItem` component automatically indents tasks based on `indentation-level`:

- Level 0: No indentation (root tasks)
- Level 1: 24px indentation (sub-tasks)
- Level 2: 48px indentation (sub-sub-tasks)
- Level N: N * 24px indentation

## Progress Calculation

Progress is calculated based on **all tasks** in the flattened list, regardless of nesting level:

```slint
private property <int> total-tasks: {
    let count = 0;
    for (task in root.todo-data.tasks) {
        count += 1;
    }
    return count;
};

private property <int> checked-tasks: {
    let count = 0;
    for (task in root.todo-data.tasks) {
        if (task.checked) {
            count += 1;
        }
    }
    return count;
};
```

## Adding Sub-tasks

When a user clicks "Add Sub-task" on a task:

1. Slint calls `sub-task-add-requested()` callback
2. C++ receives the callback and identifies which task was clicked (via task index or ID)
3. C++ creates a new sub-task in the hierarchical structure
4. C++ flattens the structure again
5. C++ updates the Slint `todos` array with the flattened structure

## Benefits

✅ **No recursive structs** - Works within Slint's limitations  
✅ **Simple iteration** - Slint can iterate over flat arrays easily  
✅ **Visual hierarchy** - Indentation provides clear visual nesting  
✅ **Flexible depth** - Supports unlimited nesting levels  
✅ **Easy updates** - C++ manages hierarchy, Slint just displays  

## C++ Responsibilities

1. **Maintain hierarchical structure** internally
2. **Flatten structure** before passing to Slint
3. **Handle sub-task creation** - When user adds sub-task, update hierarchy and re-flatten
4. **Handle task updates** - When task is checked/unchecked, update hierarchy and re-flatten
5. **Maintain parent-child relationships** - Use `parent-id` to track hierarchy

## Slint Responsibilities

1. **Display flattened list** with visual indentation
2. **Handle user interactions** - Check/uncheck, add sub-task
3. **Calculate progress** from flattened list
4. **Visual feedback** - Show checked state, indentation levels
