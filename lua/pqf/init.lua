local api = vim.api
local fn = vim.fn
local M = {}
local signs = {
  error = 'E',
  warning = 'W',
  info = 'I',
  hint = 'H'
}

-- The start of a line that contains a file path.
local visible_with_location = '<'

-- The start of a line that doesn't contain a file path.
local visible_without_location = '>'

-- The start of a line that contains a file path, and the placeholder should be
-- hidden completely.
local hidden_with_location = '{'

-- The start of a line that doesn't contain a file path, and the placeholder
-- should be hidden completely.
local hidden_without_location = '}'

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
  setlocal conceallevel=2
  setlocal concealcursor=nvic

  syn match qfError '^%s ' nextgroup=qfPath
  syn match qfWarning '^%s ' nextgroup=qfPath
  syn match qfHint '^%s ' nextgroup=qfPath
  syn match qfInfo '^%s ' nextgroup=qfPath

  syn match qfVisibleWithPath '^%s' nextgroup=qfPath cchar= conceal
  syn match qfVisibbleWithoutPath '^%s' cchar= conceal
  syn match qfHiddenWithPath '^%s' nextgroup=qfPath conceal
  syn match qfHiddenWithoutPath '^%s' conceal

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

  -- If none of the items have a `type` value (e.g. the output of `:grep`), we
  -- want the file paths to not have any leading whitespace (due to the conceal
  -- rules). To achieve this we'll insert a different start placeholder that is
  -- concealed differently.
  local hide_placeholder = true

  for i = info.start_idx, info.end_idx do
    local item = items[i]

    if item then
      local location = ''

      if item.bufnr > 0 then
        location = trim_path(fn.bufname(item.bufnr))
      elseif type_mapping[item.type] then
        -- If a type is given but a path is not, highlights can get messed up if
        -- a line/column number _is_ present. To prevent this from happening we
        -- use "?" as a placeholder. So instead of this:
        --
        -- E             this is the text
        -- W foo.lua:1:2 this is the text
        --
        -- We display this (if no line/column number is present):
        --
        -- E ?           this is the text
        -- W foo.lua:1:2 this is the text
        --
        -- Or this (when a line/column number _is_ present):
        --
        -- E ?:1:2       this is the text
        -- W foo.lua:1:2 this is the text
        --
        -- Both these cases probably won't occur in practise, but it's best to
        -- cover them anyway just in case.
        location = '?'
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

      if type_mapping[item.type] then
        hide_placeholder = false
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
      local text = vim.split(item.text, "\n")[1]
      local location = item.location

      -- If a location isn't given, we're likely dealing with arbitrary text
      -- that's displayed (e.g. a multi-line error message with each line being
      -- a quickfix item). In this case we leave the text as-is.
      if #location > 0 then
        text = fn.trim(text)
      end

      if text ~= '' then
        location = pad_right(location, pad_to)
      end

      local kind = type_mapping[item.type]

      -- Highlights for file paths depend on a known prefix for the line.
      -- Without the use of such a prefix, we'd end up highlighting text as a
      -- path if _only_ text is displayed.
      --
      -- To solve this, we start each line with a specific placeholder,
      -- depending on whether a file path is present. If all the entries are
      -- missing a type (such as "E"), we use a unique placeholder for all
      -- lines. This way we don't start lines with leading whitespace, which can
      -- look weird/like a bug.
      if kind then
        kind = kind .. ' '
      elseif hide_placeholder then
        if #item.location > 0 then
          kind = hidden_with_location
        else
          kind = hidden_without_location
        end
      else
        if #item.location > 0 then
          kind = visible_with_location .. ' '
        else
          kind = visible_without_location .. ' '
        end
      end

      local line = kind .. location .. text

      -- If a line is completely empty, Vim uses the default format, which
      -- involves inserting `|| `. To prevent this from happening we'll just
      -- insert an empty space instead.
      if line == '' then
        line = ' '
      end

      table.insert(lines, line)
    end
  end

  return lines
end

function M.syntax()
  local command = syntax_template:format(
    signs.error,
    signs.warning,
    signs.hint,
    signs.info,
    visible_with_location,
    visible_without_location,
    hidden_with_location,
    hidden_without_location
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
