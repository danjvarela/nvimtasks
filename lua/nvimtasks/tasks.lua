---@class Task
---@field id number
---@field description string
---@field status string
---@field project string?
---@field priority string?
---@field due string?
---@field urgency number?
---@field tags string[]?

local M = {}

---Fetch tasks from taskwarrior via `task export`
---@param filter string? Optional taskwarrior filter string
---@return Task[]|nil
M.fetch = function(filter)
  local cmd = "task " .. (filter or "") .. " export"
  local output = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 and (output == nil or output == "") then
    return nil
  end
  -- Strip any header lines before the JSON array (e.g. TASKRC/TASKDATA override notices)
  local start = output:find("%[")
  if not start then
    return {}
  end
  local json_str = output:sub(start)
  local ok, decoded = pcall(vim.json.decode, json_str)
  if not ok then
    return {}
  end
  return decoded
end

---Add a new task with the given description (and optional extra args)
---@param description string
---@return boolean
M.add = function(args, rc)
  local prefix = rc and (rc .. " ") or ""
  vim.fn.system("task " .. prefix .. "add " .. args .. " rc.confirmation=off")
  return vim.v.shell_error == 0
end

---Modify a task with raw taskwarrior arguments
---@param task Task
---@param args string
---@param rc string? rc overrides (e.g. "rc.data.location=...")
---@return boolean
M.modify = function(task, args, rc)
  local prefix = rc and (rc .. " ") or ""
  vim.fn.system("task " .. prefix .. task.uuid .. " modify " .. args .. " rc.confirmation=off")
  return vim.v.shell_error == 0
end

---Toggle a task between done and pending
---@param task Task
---@param rc string? rc overrides
---@return boolean
M.toggle = function(task, rc)
  local prefix = rc and (rc .. " ") or ""
  if task.status == "completed" then
    vim.fn.system("task " .. prefix .. task.uuid .. " modify rc.confirmation=off status:pending")
  else
    vim.fn.system("task " .. prefix .. task.id .. " done rc.confirmation=off")
  end
  return vim.v.shell_error == 0
end

---Toggle a task between started and stopped
---@param task Task
---@param rc string? rc overrides
---@return boolean
M.toggle_start = function(task, rc)
  local prefix = rc and (rc .. " ") or ""
  if task.start then
    vim.fn.system("task " .. prefix .. task.id .. " stop rc.confirmation=off")
  else
    vim.fn.system("task " .. prefix .. task.id .. " start rc.confirmation=off")
  end
  return vim.v.shell_error == 0
end

---Delete a task
---@param task Task
---@param rc string? rc overrides
---@return boolean
M.delete = function(task, rc)
  local prefix = rc and (rc .. " ") or ""
  vim.fn.system("task " .. prefix .. task.uuid .. " delete rc.confirmation=off")
  return vim.v.shell_error == 0
end

---@param date_str string?
---@return string
local function fmt_date(date_str)
  if not date_str or #date_str < 8 then
    return ""
  end
  return date_str:sub(1, 4) .. "-" .. date_str:sub(5, 6) .. "-" .. date_str:sub(7, 8)
end

---Format a list of tasks with inline project prefix.
---Returns lines for display and a line_map (1-based line index -> Task).
---Blocked tasks (with unmet dependencies) have `_blocked = true` set on them.
---@param task_list Task[]
---@return string[], table<number, Task>
M.format = function(task_list)
  if #task_list == 0 then
    return { "No tasks found." }, {}
  end

  -- Strip deleted tasks before any processing
  local active = {}
  for _, t in ipairs(task_list) do
    if t.status ~= "deleted" then
      active[#active + 1] = t
    end
  end
  task_list = active

  table.sort(task_list, function(a, b)
    local ua, ub = a.urgency or 0, b.urgency or 0
    if ua ~= ub then
      return ua > ub
    end
    return (a.uuid or "") < (b.uuid or "")
  end)

  local by_uuid = {}
  for _, t in ipairs(task_list) do
    if t.uuid then
      by_uuid[t.uuid] = t
    end
  end

  local function is_blocked(task)
    if not task.depends or #task.depends == 0 then
      return false
    end
    for _, dep_uuid in ipairs(task.depends) do
      local dep = by_uuid[dep_uuid]
      if dep and dep.status ~= "completed" then
        return true
      end
    end
    return false
  end

  local function task_icon(task)
    if task.status == "completed" then
      return "󰄵"
    elseif task._blocked then
      return "󰌾"
    elseif task.start then
      return "󱎫"
    else
      return "󰄱"
    end
  end

  local lines = {}
  local line_map = {}

  for _, task in ipairs(task_list) do
    task._blocked = is_blocked(task)
    local prefix = task.project and ("[" .. task.project .. "] ") or ""
    table.insert(lines, task_icon(task) .. " " .. prefix .. (task.description or ""))
    line_map[#lines] = task
  end

  return lines, line_map
end

---Build detail lines for a single task shown in the popup.
---@param task Task
---@param by_uuid table<string, Task>? lookup for resolving blocking tasks
---@return string[]
M.detail_lines = function(task, by_uuid)
  local lines = {}
  local function add(label, value)
    if value and value ~= "" then
      table.insert(lines, string.format(" %-12s %s", label .. ":", value))
    end
  end
  add("ID", tostring(task.id or ""))
  add("Status", task.status or "")
  add("Project", task.project or "")
  add("Priority", task.priority or "")
  add("Due", fmt_date(task.due))
  add("Urgency", task.urgency and string.format("%.2f", task.urgency) or "")
  if task.tags and #task.tags > 0 then
    add("Tags", table.concat(task.tags, ", "))
  end
  if task.depends and #task.depends > 0 and by_uuid then
    local blockers = {}
    for _, dep_uuid in ipairs(task.depends) do
      local dep = by_uuid[dep_uuid]
      if dep and dep.status ~= "completed" then
        table.insert(blockers, string.format("   #%-4d %s", dep.id, dep.description))
      end
    end
    if #blockers > 0 then
      table.insert(lines, string.format(" %-12s", "Blocked by:"))
      for _, bl in ipairs(blockers) do
        table.insert(lines, bl)
      end
    end
  end
  return lines
end

return M
