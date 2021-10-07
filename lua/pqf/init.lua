local api = vim.api
local fn = vim.fn
local M = {}
local type_mapping = {
  E = 'E ',
  W = 'W ',
  I = 'I ',
  -- "N" stands for "note" in regular quickfix items. We map it to "H" for
  -- "hint" here so it matches more closely with LSP diagnostic signs.
  N = 'H ',
}

local function pad_right(string, pad_to)
  local new = string

  for i = #string, pad_to do
    new = new .. ' '
  end

  return new
end

local function trim_path(path)
  return fn.fnamemodify(path, ':p:.')
end

local function list_items(info)
  if info.quickfix == 1 then
    return fn.getqflist({ id = info.id, items = 1 }).items
  else
    return fn.getloclist(info.winid, { id = info.id, items = 1 }).items
  end
end

function M.format(info)
  local items = list_items(info)
  local lines = {}
  local pad_to = 0

  for i = info.start_idx, info.end_idx do
    local item = items[i]

    if item then
      local path = trim_path(fn.bufname(item.bufnr))
      local location = path .. ':' .. item.lnum

      if item.col > 0 then
        location = location .. ':' .. item.col
      end

      local size = #location

      if size > pad_to then
        pad_to = size
      end

      item.location = location
    end
  end

  for list_index = info.start_idx, info.end_idx do
    local item = items[list_index]

    if item then
      -- Quickfix items only support singe-line messages, and show newlines as
      -- funny characters. In addition, many language servers (e.g.
      -- rust-analyzer) produce super noisy multi-line messages where only the
      -- first line is relevant.
      --
      -- To handle this, we only include the first line of the message in the
      -- quickfix line.
      local text = vim.split(fn.trim(item.text), "\n")[1]
      local location = item.location

      if text ~= '' then
        location = pad_right(location, pad_to)
      end

      local kind = type_mapping[item.type] or ''

      table.insert(lines, kind .. location .. text)
    end
  end

  return lines
end

function M.setup()
  -- This is needed until https://github.com/neovim/neovim/pull/14909 is merged.
  vim.cmd([[
    function! PqfQuickfixTextFunc(info)
      return luaeval('require("pqf").format(_A)', a:info)
    endfunction
  ]])

  vim.opt.quickfixtextfunc = 'PqfQuickfixTextFunc'
end

return M
