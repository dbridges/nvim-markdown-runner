local api = vim.api

-- Util Functions

local function readfile_string(p)
  local lines = vim.fn.readfile(p)
  return table.concat(lines, "\n")
end

local function cookie_path()
  return vim.fn.stdpath("cache") .. "/mdr-cookies.txt"
end

local function buf_get_line(l)
  return api.nvim_buf_get_lines(0, l-1, l, true)[1]
end

local function echo_err(msg)
  api.nvim_echo({{"MarkdownRunner: " .. (msg or ""), "ErrorMsg"}}, false, {})
end

local function get_code_block(line)
  local lines = {}
  local s = line or unpack(api.nvim_win_get_cursor(0))

  -- Get start line
  while not string.match(buf_get_line(s), "^```") do
    s = s - 1
    assert(s > 0, "not in a markdown code block")
  end

  -- Get end line
  local start_line = buf_get_line(s)
  local e = s + 1
  local line_count = api.nvim_buf_line_count(0)
  while true do
    local line = buf_get_line(e)
    if string.match(line, "^```") then break end
    table.insert(lines, line)
    e = e + 1
    assert(e <= line_count, "not in a markdown code block")
  end

  assert(#lines > 0, "code block is empty")

  return {
    start_line=s,
    end_line=e,
    cmd=string.match(start_line, "^```(%S+)"),
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

local function run_api(block)
  local cookie_file = cookie_path()
  local tmp = vim.fn.tempname() .. ".txt"
  local method, url = unpack(vim.split(block.src[1], " "))
  local in_body = false
  local body = {}
  local curl = {"curl", "-q", "-sS",
                "-b " .. vim.fn.shellescape(cookie_file),
                "-c " .. vim.fn.shellescape(cookie_file),
                "-X", method}
  local json = string.match(block.cmd, "^api%.json") ~= nil
  local info = string.match(block.cmd, "%.info") ~= nil

  if info then
    -- table.insert(curl, "-w '%{stderr}Fetched in %{time_total}s\n\n'")
    table.insert(curl, "-D " .. vim.fn.shellescape(tmp))
  end

  if method == "GET" or method == "get" then
    table.insert(curl, "-G")
  end

  table.insert(curl, url)

  if json then
    table.insert(curl, "-H 'Content-Type: application/json'")
    table.insert(curl, "-H 'Accept: application/json'")
  end

  for i, line in pairs(block.src) do
    if i > 1 and not string.match(line, "^[#<]") then
      if line == "" then
        in_body = true
      elseif string.match(line, "^-") then
        table.insert(curl, line)
      elseif string.match(line, "^%w+=.+") then
        table.insert(curl, "--data-urlencode")
        table.insert(curl, vim.fn.shellescape(line))
      elseif string.match(line, "^[%w-]+:.+") then
        table.insert(curl, "-H")
        table.insert(curl, vim.fn.shellescape(line))
      elseif in_body then
        table.insert(body, line)
      end
    end
  end

  if #body > 0 then
    table.insert(curl, "-d")
    table.insert(curl, vim.fn.shellescape(table.concat(body, "\n")))
  end

  local cmd = table.concat(curl, " ")

  local response = vim.fn.system(cmd)

  if json then
    local pretty_response = vim.fn.system("json_pp -json_opt indent,space_after", response)
    if vim.v.shell_error == 0 then
      response = pretty_response
    end
  end

  if info then
    local headers = readfile_string(tmp)
    vim.fn.delete(tmp)
    return headers .. "\n" .. response
  else
    return response
  end
end

local runners = {
  javascript = "node",
  js = "node",
  go = run_go,
  vim = run_vim,
  api = run_api,
}

local function get_runner(block)
  local lookup = vim.tbl_extend("force", runners, vim.g.markdown_runners or {})
  if block.cmd == nil then return vim.env.SHELL end
  for k, v in pairs(lookup) do
    if vim.split(block.cmd, "%.")[1] == k then return v end
  end
  return block.cmd
end

local function run(block)
  local runner = get_runner(block)
  if type(runner) == "string" then
    return vim.fn.system(runner, block.src)
  elseif type(runner) == "function" then
    return runner(block)
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
  local line_count = api.nvim_buf_line_count(0)

  -- Delete existing results block if present
  if l + 2 < line_count and buf_get_line(l+1) == "" and buf_get_line(l+2) == "```markdown-runner" then
    local blk = get_code_block(l+2)
    local end_line = blk.end_line
    if end_line + 1 < line_count and buf_get_line(end_line + 1) == "" then 
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

local function clear_cache()
  vim.fn.delete(cookie_path())
  print("MarkdownRunner: Cleared all cached data")
end

return {
  echo=wrap_handle_error(echo),
  insert=wrap_handle_error(insert),
  clear_cache=wrap_handle_error(clear_cache)
}
