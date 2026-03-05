# TodoPage Design Documentation

## Overview

The TodoPage allows users to create and manage Todos, where each Todo contains hierarchical Tasks with nested sub-tasks. Progress is calculated automatically based on checked tasks.

## Component Structure

### 1. TodoPage (`src/ui/pages/todo-page.slint`)
- Main page component
- Contains form to create new Todos
- Displays list of TodoItems
- Uses `TodoPageViewModel` global for state management

### 2. TodoItem (`src/ui/components/todo-item.slint`)
- Represents a single Todo
- Displays Todo title, description
- Shows progress bar and progress percentage
- Contains list of TaskItems
- Provides "Add Task" button
- Provides "Delete Todo" button

### 3. TaskItem (`src/ui/components/task-item.slint`)
- Represents a single Task (recursive component)
- Displays checkbox, title, description
- Supports nested sub-tasks (indented)
- Provides "Add Sub-task" button
- When parent task is checked, visual feedback (strikethrough, grayed out)
- When all sub-tasks are checked, parent can be auto-checked

### 4. Todo Types (`src/ui/components/todo-types.slint`)
- Shared struct definitions:
  - `Task`: id, title, description, checked, sub-tasks (recursive)
  - `Todo`: id, title, description, tasks

## Data Structure

```
Todo
├── id: string
├── title: string
├── description: string
└── tasks: [Task]
    └── Task
        ├── id: string
        ├── title: string
        ├── description: string
        ├── checked: bool
        └── sub-tasks: [Task]  // Recursive - can nest infinitely
            └── Task
                └── ... (can nest deeper)
```

## Progress Calculation

Progress is calculated as:
```
progress = (checked_tasks / total_tasks) * 100%
```

Where:
- `total_tasks` = count of all tasks including nested sub-tasks (up to 2 levels deep)
- `checked_tasks` = count of all checked tasks including nested sub-tasks

**Note**: Currently supports up to 2 levels of nesting for progress calculation. For deeper nesting, C++ implementation would be needed.

## Slint Limitations

**Important**: Slint has a limitation with recursive struct arrays in for loops. The `Task` struct contains `sub-tasks: [Task]`, which creates a recursive type. Slint cannot iterate over recursive struct arrays in component rendering.

**Current Solution**: 
- Sub-tasks are stored in the data structure and counted for progress
- Sub-task rendering is handled via a separate `SubTaskItem` component for one level
- For deeper nesting (sub-tasks of sub-tasks), C++ will need to flatten the structure or handle rendering separately

**Future Enhancement**: Consider flattening the task hierarchy in C++ before passing to Slint, or using a different data structure that avoids recursion in the UI layer.

## Features

### Todo Management
- ✅ Create new Todos with title and description
- ✅ Delete Todos
- ✅ View Todo progress

### Task Management
- ✅ Add tasks to Todos
- ✅ Check/uncheck tasks
- ✅ Add nested sub-tasks to tasks
- ✅ Visual feedback for checked tasks (strikethrough, grayed out)
- ✅ Progress bar updates automatically

### UI Features
- ✅ Progress bar with percentage display
- ✅ Indented sub-tasks for visual hierarchy
- ✅ Form to add new sub-tasks inline
- ✅ Empty state message when no todos exist

## State Management

### TodoPageViewModel Global
```slint
export global TodoPageViewModel {
    in-out property <[Todo]> todos: [];
    callback todo-added(Todo todo);
    callback todo-deleted(string id);
    callback todo-updated(Todo todo);
}
```

## C++ Integration (To Be Implemented)

The C++ code needs to:
1. Handle `todo-added` callback - generate unique ID, add to todos list
2. Handle `todo-deleted` callback - remove todo from list
3. Handle `todo-updated` callback - update todo in list
4. Manage todo persistence (save/load from file/database)

Example C++ binding:
```cpp
auto& view_model = app->global<TodoPageViewModel>();

view_model.on_todo_added([&](const Todo& todo) {
    // Generate unique ID
    auto new_todo = todo;
    new_todo.id = generate_uuid();
    
    // Add to list
    auto todos = view_model.get_todos();
    todos.push_back(new_todo);
    view_model.set_todos(todos);
});

view_model.on_todo_deleted([&](const slint::SharedString& id) {
    auto todos = view_model.get_todos();
    todos.erase(std::remove_if(todos.begin(), todos.end(),
        [&](const Todo& t) { return std::string(t.id) == std::string(id); }),
        todos.end());
    view_model.set_todos(todos);
});

view_model.on_todo_updated([&](const Todo& todo) {
    auto todos = view_model.get_todos();
    auto it = std::find_if(todos.begin(), todos.end(),
        [&](const Todo& t) { return std::string(t.id) == std::string(todo.id); });
    if (it != todos.end()) {
        *it = todo;
        view_model.set_todos(todos);
    }
});
```

## Translation Keys Needed

Add these to your translation files:
- `TodoPage.title`
- `TodoPage.subtitle`
- `TodoPage.create-new`
- `TodoPage.todo-title-placeholder`
- `TodoPage.todo-description-placeholder`
- `TodoPage.add-todo`
- `TodoPage.no-todos`
- `TodoItem.progress`
- `TodoItem.add-task`
- `TodoItem.new-task-title`
- `TodoItem.delete`
- `TaskItem.add-subtask`
- `TaskItem.subtask-title-placeholder`
- `TaskItem.subtask-description-placeholder`
- `TaskItem.add`
- `TaskItem.cancel`

## Usage

1. Navigate to TodoPage via `AppWindowViewModel.navigate(Pages.todos)`
2. Enter Todo title and description
3. Click "Add Todo"
4. Click "Add Task" on a Todo to add tasks
5. Check tasks to update progress
6. Click "Add Sub-task" on a task to add nested tasks
7. Progress bar updates automatically as tasks are checked
