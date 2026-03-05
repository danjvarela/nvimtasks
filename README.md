# nvimtasks

![Lua](https://img.shields.io/badge/Made%20with%20Lua-blueviolet.svg?style=for-the-badge&logo=lua)

A Neovim plugin that renders [Taskwarrior](https://taskwarrior.org) tasks inside Neovim. No external dependencies — uses only the Neovim Lua API.

## Requirements

- Neovim >= 0.9
- [Taskwarrior](https://taskwarrior.org/download/) (`task` CLI available in `$PATH`)
- A [Nerd Font](https://www.nerdfonts.com/) for task icons

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "danjvarela/nvimtasks",
  config = function()
    require("nvimtasks").setup()
  end
}
```

## Usage

```
:NvimTasks [filter]
```

Opens the task window with an optional Taskwarrior filter. Defaults to `status:pending`.

Or call `open()` directly from Lua:

```lua
require("nvimtasks").open({
  filter  = "status:pending project:work",
  window  = "split",   -- "split" | "vsplit" | "float"
  options = "rc.data.location=/path/to/data",
})
```

## Keymaps (inside the task window)

| Key | Action |
|-----|--------|
| `a` | Add a new task (full `task add` syntax) |
| `e` | Edit/modify the task under cursor |
| `d` | Delete task under cursor (asks confirmation) |
| `x` | Toggle task done / pending |
| `s` | Start / stop task |
| `K` | Show task details popup |
| `n` | Add / delete annotations on task under cursor |
| `f` | Change the active filter |
| `o` | Set rc overrides (e.g. `rc.data.location=...`) |
| `q` | Close the window |

## Configuration

```lua
require("nvimtasks").setup({
  filter = "status:pending",       -- default Taskwarrior filter
  window = "split",                -- "split" | "vsplit" | "float"
  urgency_thresholds = {
    high   = 10,
    medium = 5,
  },
  highlights = {
    pending        = "NvimTasksPending",
    done           = "NvimTasksDone",
    blocked        = "NvimTasksBlocked",
    urgency_high   = "NvimTasksUrgencyHigh",
    urgency_medium = "NvimTasksUrgencyMedium",
    urgency_low    = "NvimTasksUrgencyLow",
  },
})
```

### Highlight groups

| Group | Default link | Used for |
|-------|-------------|----------|
| `NvimTasksTitle` | `Title` | Header title line |
| `NvimTasksHints` | `Comment` | Keybinding hints, filter/options lines |
| `NvimTasksPending` | `Normal` | Pending tasks (low urgency) |
| `NvimTasksDone` | `Comment` | Completed tasks |
| `NvimTasksBlocked` | `DiagnosticHint` | Blocked tasks (unmet dependencies) |
| `NvimTasksUrgencyHigh` | `DiagnosticError` | High urgency tasks |
| `NvimTasksUrgencyMedium` | `DiagnosticWarn` | Medium urgency tasks |
| `NvimTasksUrgencyLow` | `DiagnosticInfo` | Low urgency tasks |
| `NvimTasksTags` | `Comment` | Tag inlay hints (`+tag1,+tag2`) |
| `NvimTasksRecur` | `Special` | Recurrence indicator (`↻`) |

## Task icons

Task icons are prefixed with a recurrence indicator (`󰑖`) when the task belongs to a recurring series.

| Icon | Meaning |
|------|---------|
| `󰄱` | Pending |
| `󱎫` | Started |
| `󰄵` | Done |
| `󰌾` | Blocked (has unmet dependencies) |

## Multiple Taskwarrior databases

Use the `options` parameter (or press `o` at runtime) to point at a different data directory:

```lua
require("nvimtasks").open({
  options = "rc.data.location=" .. vim.fn.expand("$HOME/.config/taskwarrior/work-data"),
})
```

## Running tests

```
make test
```

## Roadmap

### Current features

- View tasks in a readonly split window
- Add, edit, delete tasks
- Toggle task done/started
- Filter tasks and show active filter in header
- RC overrides for multiple Taskwarrior databases
- Urgency-based highlights
- Blocked task visualization (unmet dependencies)
- Tag inlay hints
- Annotations (add, view, delete)
- Recurring task indicator
