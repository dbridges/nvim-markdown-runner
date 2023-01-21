local api = vim.api
local util = require "markdown_runner.util"

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
  local cookie_file = util.cookie_path()
  local tmp = vim.fn.tempname() .. ".txt"
  local method, url = unpack(vim.split(block.src[1], " "))
  local in_body = false
  local body = {}
  local curl = {"curl", "-q", "-sS",
                "-b " .. vim.fn.shellescape(cookie_file),
                "-c " .. vim.fn.shellescape(cookie_file),
                "-X", method}
  local opts = vim.split(block.cmd, ".", true)
  local json = not vim.tbl_contains(opts, "raw")
  local info = vim.tbl_contains(opts, "info")
  local time = vim.tbl_contains(opts, "time")

  if info then
    table.insert(curl, "-D " .. vim.fn.shellescape(tmp))
  end

  if time then
    table.insert(curl, "-w '\n\nFetched in %{time_total}s'")
  end

  if method == "GET" or method == "get" then
    table.insert(curl, "-G")
  end

  table.insert(curl, url)

  if json then
    table.insert(curl, "-H 'Accept: application/json'")
    if method ~= "GET" then
      table.insert(curl, "-H 'Content-Type: application/json'")
    end
  end

  for i, line in pairs(block.src) do
    if i > 1 and not string.match(line, "^[#<]") then
      if line == "" then
        in_body = true
      elseif in_body then
        table.insert(body, line)
      elseif string.match(line, "^-") then
        table.insert(curl, line)
      elseif string.match(line, "^%S+=.+") then
        table.insert(curl, "--data-urlencode")
        table.insert(curl, vim.fn.shellescape(line))
      elseif string.match(line, "^%S+:.+") then
        table.insert(curl, "-H")
        table.insert(curl, vim.fn.shellescape(line))
      end
    end
  end

  if #body > 0 then
    table.insert(curl, "-d")
    table.insert(curl, vim.fn.shellescape(table.concat(body, "\n")))
  end

  local cmd = table.concat(curl, " ")

  local response = vim.fn.system(cmd)

  local lines = vim.split(response, "\n")
  local maybe_time = lines[#lines] .. "\n\n"

  if vim.startswith(maybe_time, "Fetched in") then
    table.remove(lines, #lines)
    response = table.concat(lines, "\n")
  else
    maybe_time = ""
  end

  if json then
    local pretty_response = vim.fn.system("json_pp -json_opt indent,space_after", response)
    if vim.v.shell_error == 0 then
      response = pretty_response
    end
  end

  if info then
    local headers = util.readfile_string(tmp)
    vim.fn.delete(tmp)
    return maybe_time .. headers .. "\n" .. response
  else
    return maybe_time .. response
  end
end

local runners = {
  javascript = "node",
  js = "node",
  go = run_go,
  vim = run_vim,
  api = run_api,
}

return runners
