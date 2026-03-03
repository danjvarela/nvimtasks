local tasks = require("nvimtasks.tasks")

describe("tasks.format", function()
  it("returns a message when task list is empty", function()
    local lines = tasks.format({})
    assert(#lines == 1 and lines[1] == "No tasks found.", "expected 'No tasks found.' for empty list")
  end)

  it("renders a checkbox per task with inline project prefix", function()
    local task_list = {
      { id = 1, description = "Buy milk",    status = "pending",   project = "home", urgency = 1, uuid = "a" },
      { id = 2, description = "Write tests", status = "completed", project = "work", urgency = 0, uuid = "b" },
    }
    local lines, line_map = tasks.format(task_list)
    assert(#lines == 2, "expected 2 lines, got " .. #lines)
    local task_lines = 0
    for _ in pairs(line_map) do task_lines = task_lines + 1 end
    assert(task_lines == 2, "expected 2 mapped task lines, got " .. task_lines)
    assert(lines[1]:find("%[home%]"), "should include [home] prefix")
    assert(lines[2]:find("%[work%]"), "should include [work] prefix")
  end)

  it("task lines contain the right icon", function()
    local task_list = {
      { id = 1, description = "Pending", status = "pending",   project = "p", urgency = 1 },
      { id = 2, description = "Done",    status = "completed", project = "p", urgency = 0 },
    }
    local lines, line_map = tasks.format(task_list)
    for i, task in pairs(line_map) do
      if task.status == "pending" then
        assert(lines[i]:find("󰄱"), "pending task line should have 󰄱")
      else
        assert(lines[i]:find("󰄵"), "completed task line should have 󰄵")
      end
    end
  end)

  it("sorts by urgency descending", function()
    local task_list = {
      { id = 1, description = "First",  status = "pending", project = "p", urgency = 1, uuid = "a" },
      { id = 2, description = "Second", status = "pending", project = "p", urgency = 9, uuid = "b" },
    }
    local lines = tasks.format(task_list)
    assert(lines[1]:find("Second"), "highest urgency task should be first")
  end)
end)

describe("tasks.detail_lines", function()
  it("includes id, status, project, due", function()
    local task = {
      id = 3,
      description = "Test task",
      status = "pending",
      project = "work",
      due = "20260305T120000Z",
      urgency = 5.0,
    }
    local lines = tasks.detail_lines(task)
    local joined = table.concat(lines, "\n")
    assert(joined:find("3"),            "should include id")
    assert(joined:find("work"),         "should include project")
    assert(joined:find("2026%-03%-05"), "should include formatted due date")
  end)
end)
