local api = vim.api

-- Util Functions

local function buf_get_line(l)
  return api.nvim_buf_get_lines(0, l-1, l, true)[1]
end

local function echo_err(msg)
  api.nvim_echo({{"MarkdownRunner: " .. msg, "ErrorMsg"}}, false, {})
end

local function get_code_block(line)
  local lines = {}
  local s = line or unpack(api.nvim_win_get_cursor(0))

  -- Get start line
  while not string.match(buf_get_line(s), "^```") do
    s = s - 1
    assert(s > 0, "not in a markdown code block")
  end

  -- Get ned line
  local start_line = buf_get_line(s)
  local e = s + 1
  local line_count = api.nvim_buf_line_count(0)
  while true do
    local line = buf_get_line(e)
    if string.match(line, "^```") then break end
    table.insert(lines, line)
    e = e + 1
    assert(e < line_count, "not in a markdown code block")
  end

  assert(#lines > 0, "code block is empty")

  return {
    start_line=s,
    end_line=e,
    cmd=string.match(start_line, "^```(%w+)"),
    src=lines
  }
end

-- Code Runners

local function run_go(block)
  local tmp = vim.fn.tempname() .. ".go"
  local src = table.concat(block.src, "\n")

  if not string.match(src, "^func main") then
    src = "func main() {\n" .. src .. "\n}"
  end

  if not string.match(src, "^package") then
    src = "package main\n" .. src
  end

  vim.fn.writefile(vim.split(src, "\n"), tmp)
  vim.fn.system("goimports -w " .. tmp, block.src)
  local stdout = vim.fn.system("go run " .. tmp, block.src)
  vim.fn.delete(tmp)

  return stdout
end

local function run_vim(block)
  local tmp = vim.fn.tempname() .. ".vim"
  vim.fn.writefile(block.src, tmp)
  api.nvim_exec("source " .. tmp, false)
  vim.fn.delete(tmp)
  return ""
end

local runners = {
  javascript = "node",
  js = "node",
  go = run_go,
  vim = run_vim,
}

local function get_cmd(block)
  local lookup = vim.tbl_extend("force", runners, vim.g.markdown_runners or {})
  return lookup[block.cmd] or block.cmd or vim.env.SHELL or "sh"
end

local function run(block)
  local cmd = get_cmd(block)
  if type(cmd) == "string" then
    return vim.fn.system(cmd, block.src)
  elseif type(cmd) == "function" then
    return cmd(block)
  else
    error("Invalid command type")
  end
end

-- Entry Points

local function echo()
  print(run(get_code_block()))
end

local function insert()
  local block = get_code_block()
  local content = "\n```markdown-runner\n" .. run(block) .. "```"
  local l = block.end_line

  -- Delete existing results block if present
  if buf_get_line(l+1) == "" and buf_get_line(l+2) == "```markdown-runner" then
    local blk = get_code_block(l+2)
    local end_line = blk.end_line
    if buf_get_line(end_line + 1) == "" then 
      end_line = end_line + 1
    end
    api.nvim_buf_set_lines(0, blk.start_line - 1, end_line, true, {})
  end

  api.nvim_buf_set_lines(0, l, l, true, vim.split(content, "\n"))
end

local function wrap_handle_error(fn)
  return function ()
    local status, err = pcall(fn)
    if not status then 
      echo_err(string.match(err, "^.+%:%d+%: (.*)$"))
    end
  end
end

return {
  echo=wrap_handle_error(echo),
  insert=wrap_handle_error(insert)
}
