local api = vim.api
local fn = vim.fn
local M = {}
local signs = {
  error = 'E',
  warning = 'W',
  info = 'I',
  hint = 'H'
}

-- If any of NeoVim's diagnostic signs are defined and have text set, we'll
-- default to the text values of these signs. If some are missing, we'll fall
-- bach to the defaults set earlier.
--
-- This approach means users don't have to configure signs themselves, instead
-- their diagnostic signs are reused.
local diagnostic_signs = {
  DiagnosticSignError = 'error',
  DiagnosticSignWarn = 'warning',
  DiagnosticSignHint = 'hint',
  DiagnosticSignInfo = 'info'
}

for diagnostic_sign, key in pairs(diagnostic_signs) do
  local sign_def = fn.sign_getdefined(diagnostic_sign)[1]

  if sign_def and sign_def.text then
    signs[key] = vim.trim(sign_def.text)
  end
end

-- The template to use for generating the syntax rules. Relying on positional
-- placeholders isn't nice, but it's the most boring way of supporting custom
-- signs.
local syntax_template = [[
  syn match qfError '^%s ' nextgroup=qfPath
  syn match qfWarning '^%s ' nextgroup=qfPath
  syn match qfHint '^%s ' nextgroup=qfPath
  syn match qfInfo '^%s ' nextgroup=qfPath
  syn match qfPath '^\(%s \|%s \|%s \|%s \)\@![^:]\+' nextgroup=qfPosition

  syn match qfPath '[^:]\+' nextgroup=qfPosition contained
  syn match qfPosition ':[0-9]\+\(:[0-9]\+\)\?' contained

  hi def link qfPath Directory
  hi def link qfPosition Number

  hi def link qfError DiagnosticError
  hi def link qfWarning DiagnosticWarn
  hi def link qfInfo DiagnosticInfo
  hi def link qfHint DiagnosticHint
]]

local function pad_right(string, pad_to)
  local new = string

  if pad_to == 0 then
    return string
  end

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
  local type_mapping = {
    E = signs.error,
    W = signs.warning,
    I = signs.info,
    N = signs.hint,
  }

  for i = info.start_idx, info.end_idx do
    local item = items[i]

    if item then
      local location = ''

      if item.bufnr > 0 then
        location = trim_path(fn.bufname(item.bufnr))
      end

      if #location > 0 then
        location = location .. ':' .. item.lnum
      end

      if #location > 0 and item.col > 0 then
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

      local kind = type_mapping[item.type]

      if kind then
        kind = kind .. ' '
      else
        kind = ''
      end

      table.insert(lines, kind .. location .. text)
    end
  end

  return lines
end

function M.syntax()
  local command = syntax_template:format(
    -- The `syn match` rules.
    signs.error, signs.warning, signs.hint, signs.info,
    -- The `syn match qfPath` rule.
    signs.error, signs.warning, signs.hint, signs.info
  )

  vim.cmd(command)
end

function M.setup(options)
  if type(options) == 'table' and options.signs then
    signs = vim.tbl_extend('force', signs, options.signs)
  end

  -- This is needed until https://github.com/neovim/neovim/pull/14909 is merged.
  vim.cmd([[
    function! PqfQuickfixTextFunc(info)
      return luaeval('require("pqf").format(_A)', a:info)
    endfunction
  ]])

  vim.opt.quickfixtextfunc = 'PqfQuickfixTextFunc'
end

return M
