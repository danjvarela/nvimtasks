vim.api.nvim_create_user_command("Tasks", function(cmd)
  local filter = cmd.args ~= "" and cmd.args or nil
  require("nvimtasks").open({ filter = filter })
end, { nargs = "?" })
