local api = vim.api
local util = require "markdown_runner.util"

local parser = {}

-- Returns the markdown code block on the given line for the current buffer.
function parser.get_code_block(line)
  local lines = {}
  local s = line or unpack(api.nvim_win_get_cursor(0))

  -- Get start line
  while not string.match(util.buf_get_line(s), "^```") do
    s = s - 1
    assert(s > 0, "not in a markdown code block")
  end

  -- Get end line
  local start_line = util.buf_get_line(s)
  local e = s + 1
  local line_count = api.nvim_buf_line_count(0)
  while true do
    local line = util.buf_get_line(e)
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

return parser
