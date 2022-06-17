local api = vim.api
local util = require "markdown_runner.util"
local parser = require "markdown_runner.parser"
local runners = require "markdown_runner.runners"

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
    local resp = runner(block)
    if string.sub(resp, -1, -1) == "\n" then
      resp = resp + "\n"
    end
    return resp
  else
    error("Invalid command type")
  end
end

local function echo()
  print(run(parser.get_code_block()))
end

local function insert()
  local block = parser.get_code_block()
  local content = "\n```markdown-runner\n" .. run(block) .. "```"
  local l = block.end_line
  local line_count = api.nvim_buf_line_count(0)

  -- Delete existing results block if present
  if l + 2 < line_count and util.buf_get_line(l+1) == "" and util.buf_get_line(l+2) == "```markdown-runner" then
    local blk = parser.get_code_block(l+2)
    local end_line = blk.end_line
    if end_line + 1 < line_count and util.buf_get_line(end_line + 1) == "" then 
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
      util.echo_err(string.match(err, "^.+%:%d+%: (.*)$"))
    end
  end
end

local function clear_cache()
  vim.fn.delete(util.cookie_path())
  print("MarkdownRunner: Cleared all cached data")
end

return {
  echo=wrap_handle_error(echo),
  insert=wrap_handle_error(insert),
  clear_cache=wrap_handle_error(clear_cache)
}
