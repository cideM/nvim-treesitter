local api = vim.api
local fn = vim.fn
local luv = vim.loop

local M = {}

function M.setup_commands(mod, commands)
  for command_name, def in pairs(commands) do
    local call_fn = string.format("lua require'nvim-treesitter.%s'.commands.%s.run(<f-args>)", mod, command_name)
    local parts = vim.tbl_flatten({
        "command!",
        def.args,
        command_name,
        call_fn,
      })
    api.nvim_command(table.concat(parts, " "))
  end
end

function M.get_path_sep()
  local path_sep = '/'
  if fn.has('win32') == 1 then
    path_sep = '\\'
  end

  return path_sep
end

function M.get_package_path()
  -- Path to this source file, removing the leading '@'
  local source = string.sub(debug.getinfo(1, 'S').source, 2)

  -- Path to the package root
  return fn.fnamemodify(source, ":p:h:h:h")
end

function M.get_cache_dir()
  local cache_dir = fn.stdpath('data')

  if luv.fs_access(cache_dir, 'RW') then
    return cache_dir
  elseif luv.fs_access('/tmp', 'RW') then
    return '/tmp'
  end

  return nil, 'Invalid cache rights, '..fn.stdpath('data')..' or /tmp should be read/write'
end

-- Returns $XDG_DATA_HOME/nvim/site, but could use any directory that is in
-- runtimepath
function M.get_site_dir()
  local path_sep = M.get_path_sep()
  return fn.stdpath('data')..path_sep..'site'
end

-- Try the package dir of the nvim-treesitter plugin first, followed by the
-- "site" dir from "runtimepath". "site" dir will be created if it doesn't
-- exist. Using only the package dir won't work when the plugin is installed
-- with Nix, since the "/nix/store" is read-only.
function M.get_parser_install_dir()
  local package_path = M.get_package_path()

  -- If package_path is read/write, use that
  if luv.fs_access(package_path, 'RW') then
    return package_path
  end

  local site_dir = M.get_site_dir()
  local path_sep = M.get_path_sep()
  local parser_dir = site_dir..path_sep..'parser'

  -- Try creating and using parser_dir if it doesn't exist
  if not luv.fs_stat(parser_dir) then
    local ok, error = pcall(vim.fn.mkdir, parser_dir, "p", "0755")
    if not ok then
      return nil, 'Couldn\'t create parser dir '..parser_dir..': '..error
    end

    return parser_dir
  end

  -- parser_dir exists, use it if it's read/write
  if luv.fs_access(parser_dir, 'RW') then
    return parser_dir
  end

  -- package_path isn't read/write, parser_dir exists but isn't read/write
  -- either, give up
  return nil, 'Invalid cache rights, '..package_path..' or '..parser_dir..' should be read/write'
end

-- Gets a property at path
-- @param tbl the table to access
-- @param path the '.' separated path
-- @returns the value at path or nil
function M.get_at_path(tbl, path)
  local segments = vim.split(path, '.', true)
  local result = tbl

  for _, segment in ipairs(segments) do
    if type(result) == 'table' then
      result = result[segment]
    end
  end

  return result
end

-- Prints a warning message
-- @param text the text message
function M.print_warning(text)
  api.nvim_command(string.format([[echohl WarningMsg | echo "%s" | echohl None]], text))
end

function M.set_jump()
  vim.cmd "normal! m'"
end

function M.index_of(tbl, obj)
  for i, o in ipairs(tbl) do
    if o == obj then
      return i
    end
  end
end

return M
