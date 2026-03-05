local tasks = require("nvimtasks.tasks")

---@class NvimTasksHighlights
---@field pending string Highlight group for pending tasks with no urgency threshold
---@field done string Highlight group for completed tasks
---@field urgency_high string Highlight group for high urgency tasks
---@field urgency_medium string Highlight group for medium urgency tasks
---@field blocked string Highlight group for blocked tasks

---@class NvimTasksConfig
---@field filter string? Taskwarrior filter (default: pending tasks)
---@field window "split"|"vsplit"|"float" How to open the tasks window
---@field urgency_thresholds { high: number, medium: number } Urgency cutoffs
---@field highlights NvimTasksHighlights

---@type NvimTasksConfig
local config = {
  filter = "status:pending",
  window = "split",
  urgency_thresholds = {
    high = 10,
    medium = 5,
  },
  highlights = {
    pending = "NvimTasksPending",
    done = "NvimTasksDone",
    urgency_high = "NvimTasksUrgencyHigh",
    urgency_medium = "NvimTasksUrgencyMedium",
    urgency_low = "NvimTasksUrgencyLow",
    blocked = "NvimTasksBlocked",
  },
}

local M = {}

---@type NvimTasksConfig
M.config = config

local function setup_highlights()
  vim.api.nvim_set_hl(0, "NvimTasksTitle", { default = true, link = "Title" })
  vim.api.nvim_set_hl(0, "NvimTasksPending", { default = true, link = "Normal" })
  vim.api.nvim_set_hl(0, "NvimTasksDone", { default = true, link = "Comment" })
  vim.api.nvim_set_hl(0, "NvimTasksBlocked", { default = true, link = "DiagnosticHint" })
  vim.api.nvim_set_hl(0, "NvimTasksHints", { default = true, link = "Comment" })
  vim.api.nvim_set_hl(0, "NvimTasksTags", { default = true, link = "Comment" })
  vim.api.nvim_set_hl(0, "NvimTasksRecur", { default = true, link = "Special" })
  vim.api.nvim_set_hl(0, "NvimTasksUrgencyHigh", { default = true, link = "DiagnosticError" })
  vim.api.nvim_set_hl(0, "NvimTasksUrgencyMedium", { default = true, link = "DiagnosticWarn" })
  vim.api.nvim_set_hl(0, "NvimTasksUrgencyLow", { default = true, link = "DiagnosticInfo" })
end

---@param args NvimTasksConfig?
M.setup = function(args)
  M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

---Open the tasks window
---@param opts { filter: string?, window: string?, options: string? }?
M.open = function(opts)
  opts = opts or {}
  local filter = opts.filter or M.config.filter
  local window = opts.window or M.config.window
  local rc_overrides = opts.options and vim.fn.expand(opts.options) or nil
  setup_highlights()

  local task_list = tasks.fetch((rc_overrides and rc_overrides .. " " or "") .. filter)
  if task_list == nil then
    vim.notify("nvimtasks: could not run 'task' — is taskwarrior installed?", vim.log.levels.ERROR)
    return
  end

  local lines, line_map = tasks.format(task_list)

  -- Header is rebuilt on every refresh so filter/options stay current
  local function build_header()
    local lines = {
      " Tasks",
      " a add · e edit · d del · x done · s start · K details · n annotate · f filter · o options · q close",
      " filter:  " .. filter,
    }
    if rc_overrides and rc_overrides ~= "" then
      lines[#lines + 1] = " options: " .. rc_overrides
    end
    lines[#lines + 1] = ""
    return lines
  end

  local header = build_header()
  local offset = #header
  local offset_map = {}
  for i, task in pairs(line_map) do
    offset_map[i + offset] = task
  end
  line_map = offset_map
  for i = #header, 1, -1 do
    table.insert(lines, 1, header[i])
  end

  -- Wipe any existing Tasks buffer to avoid E95 on re-open
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b):match("Tasks$") then
      vim.api.nvim_buf_delete(b, { force = true })
      break
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)

  local ns = vim.api.nvim_create_namespace("nvimtasks")

  local function apply_highlights(lmap)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    -- Title line
    vim.api.nvim_buf_add_highlight(buf, ns, "NvimTasksTitle", 0, 0, -1)
    -- All header lines after the title use the hints highlight (up to the first task)
    for i = 1, offset - 1 do
      vim.api.nvim_buf_add_highlight(buf, ns, "NvimTasksHints", i, 0, -1)
    end
    local thresh = M.config.urgency_thresholds
    for i, task in pairs(lmap) do
      local hl
      if task.status == "completed" then
        hl = M.config.highlights.done
      elseif task._blocked then
        hl = M.config.highlights.blocked
      else
        local u = task.urgency or 0
        if u >= thresh.high then
          hl = M.config.highlights.urgency_high
        elseif u >= thresh.medium then
          hl = M.config.highlights.urgency_medium
        else
          hl = M.config.highlights.urgency_low
        end
      end
      vim.api.nvim_buf_add_highlight(buf, ns, hl, i - 1, 0, -1)
      local virt = {}
      if task.tags and #task.tags > 0 then
        local prefixed = vim.tbl_map(function(t)
          return "+" .. t
        end, task.tags)
        table.insert(virt, { " " .. table.concat(prefixed, ","), "NvimTasksTags" })
      end
      if task.recur then
        table.insert(virt, { " ↻" .. task.recur, "NvimTasksRecur" })
      end
      if #virt > 0 then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
          virt_text = virt,
          virt_text_pos = "eol",
        })
      end
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  apply_highlights(line_map)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "nvimtasks", { buf = buf })
  vim.api.nvim_buf_set_name(buf, "Tasks")

  local win
  if window == "float" then
    local width = math.floor(vim.o.columns * 0.85)
    local height = math.floor(vim.o.lines * 0.75)
    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
      border = "rounded",
      title = " Tasks ",
      title_pos = "center",
    })
  elseif window == "vsplit" then
    vim.cmd("vsplit")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  else
    vim.cmd("split")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.api.nvim_win_set_height(win, math.floor(vim.o.lines * 0.25))
  end

  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })

  -- Close with q
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true, nowait = true })

  -- Track the popup window so we can close it when cursor moves away
  local popup_win = nil

  local function close_popup()
    if popup_win and vim.api.nvim_win_is_valid(popup_win) then
      vim.api.nvim_win_close(popup_win, true)
      popup_win = nil
    end
  end

  local function show_popup()
    close_popup()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_map[row]
    if not task then
      return
    end

    local by_uuid = {}
    for _, t in pairs(line_map) do
      if t.uuid then
        by_uuid[t.uuid] = t
      end
    end
    local detail = tasks.detail_lines(task, by_uuid)
    if #detail == 0 then
      return
    end

    local popup_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(popup_buf, 0, -1, false, detail)
    vim.api.nvim_set_option_value("modifiable", false, { buf = popup_buf })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = popup_buf })

    local max_width = 0
    for _, l in ipairs(detail) do
      if #l > max_width then
        max_width = #l
      end
    end

    popup_win = vim.api.nvim_open_win(popup_buf, false, {
      relative = "cursor",
      row = 1,
      col = 0,
      width = max_width,
      height = #detail,
      style = "minimal",
      border = "rounded",
    })
  end

  vim.keymap.set("n", "q", function()
    close_popup()
    vim.cmd("close")
  end, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "K", show_popup, { buffer = buf, silent = true })

  local function refresh_buf()
    local new_lines, new_line_map =
      tasks.format(tasks.fetch((rc_overrides and rc_overrides .. " " or "") .. filter) or {})
    local new_header = build_header()
    offset = #new_header
    local new_offset_map = {}
    for i, t in pairs(new_line_map) do
      new_offset_map[i + offset] = t
    end
    line_map = new_offset_map
    for i = #new_header, 1, -1 do
      table.insert(new_lines, 1, new_header[i])
    end
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
    apply_highlights(line_map)
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  end

  vim.keymap.set("n", "o", function()
    close_popup()
    vim.ui.input({ prompt = "Options (rc overrides): ", default = rc_overrides or "" }, function(input)
      if input ~= nil then
        rc_overrides = input ~= "" and vim.fn.expand(input) or nil
        refresh_buf()
      end
    end)
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "f", function()
    close_popup()
    vim.ui.input({ prompt = "Filter: ", default = filter }, function(input)
      if input ~= nil then
        filter = input
        refresh_buf()
      end
    end)
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "a", function()
    close_popup()
    local rc_prefix = rc_overrides and (rc_overrides .. " ") or ""
    vim.ui.input({ prompt = "task " .. rc_prefix .. "add " }, function(input)
      if input and input ~= "" then
        if tasks.add(input, rc_overrides) then
          refresh_buf()
        end
      end
    end)
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "d", function()
    close_popup()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_map[row]
    if not task then
      return
    end
    vim.ui.input({ prompt = 'Delete "' .. task.description .. '"? (y/N) ' }, function(input)
      if input and input:lower() == "y" then
        if tasks.delete(task, rc_overrides) then
          refresh_buf()
        end
      end
    end)
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "e", function()
    close_popup()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_map[row]
    if not task then
      return
    end
    vim.ui.input(
      { prompt = "task " .. (rc_overrides and rc_overrides .. " " or "") .. task.id .. " modify " },
      function(input)
        if input and input ~= "" then
          if tasks.modify(task, input, rc_overrides) then
            refresh_buf()
          end
        end
      end
    )
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "x", function()
    close_popup()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_map[row]
    if not task then
      return
    end
    if tasks.toggle(task, rc_overrides) then
      refresh_buf()
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "s", function()
    close_popup()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_map[row]
    if not task then
      return
    end
    if tasks.toggle_start(task, rc_overrides) then
      refresh_buf()
    end
  end, { buffer = buf, silent = true })

  vim.keymap.set("n", "n", function()
    close_popup()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local task = line_map[row]
    if not task then
      return
    end
    local choices = { "Add annotation" }
    if task.annotations then
      for _, ann in ipairs(task.annotations) do
        table.insert(choices, "Delete: " .. ann.description)
      end
    end
    vim.ui.select(choices, { prompt = "Annotations" }, function(choice, idx)
      if not choice then
        return
      end
      if idx == 1 then
        vim.ui.input({ prompt = "Annotation: " }, function(input)
          if input and input ~= "" then
            if tasks.annotate(task, input, rc_overrides) then
              refresh_buf()
            end
          end
        end)
      else
        local ann = task.annotations[idx - 1]
        if tasks.denotate(task, ann.description, rc_overrides) then
          refresh_buf()
        end
      end
    end)
  end, { buffer = buf, silent = true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = buf,
    callback = close_popup,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinClosed" }, {
    buffer = buf,
    callback = close_popup,
  })
end

return M
