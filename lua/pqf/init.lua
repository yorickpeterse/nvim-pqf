local api = vim.api
local fn = vim.fn
local M = {}

-- The names of the sign types, and the symbols to insert into the quickfix
-- window.
local signs = {
  error = 'E',
  warning = 'W',
  info = 'I',
  hint = 'H',
}

local namespace = api.nvim_create_namespace('pqf')
local show_multiple_lines = false
local max_filename_length = 0

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
  DiagnosticSignInfo = 'info',
}

for diagnostic_sign, key in pairs(diagnostic_signs) do
  local sign_def = fn.sign_getdefined(diagnostic_sign)[1]

  if sign_def and sign_def.text then
    signs[key] = vim.trim(sign_def.text)
  end
end

local function pad_right(string, pad_to)
  local new = string

  if pad_to == 0 then
    return string
  end

  for i = fn.strwidth(string), pad_to do
    new = new .. ' '
  end

  return new
end

local function trim_path(path)
  local fname = fn.fnamemodify(path, ':p:.')
  local len = fn.strchars(fname)
  if max_filename_length > 0 and len > max_filename_length then
    fname = '[...]'
      .. fn.strpart(
        fname,
        len - max_filename_length,
        max_filename_length,
        vim.v['true']
      )
  end
  return fname
end

local function list_items(info)
  if info.quickfix == 1 then
    return fn.getqflist({ id = info.id, items = 1, qfbufnr = 1 })
  else
    return fn.getloclist(info.winid, { id = info.id, items = 1, qfbufnr = 1 })
  end
end

local function apply_highlights(bufnr, highlights)
  for _, hl in ipairs(highlights) do
    vim.highlight.range(
      bufnr,
      namespace,
      hl.group,
      { hl.line, hl.col },
      { hl.line, hl.end_col }
    )
  end
end

function M.format(info)
  local list = list_items(info)
  local qf_bufnr = list.qfbufnr
  local raw_items = list.items
  local lines = {}
  local pad_to = 0
  local type_mapping = {
    E = { signs.error, 'DiagnosticError' },
    W = { signs.warning, 'DiagnosticWarn' },
    I = { signs.info, 'DiagnosticInfo' },
    N = { signs.hint, 'DiagnosticHint' },
  }

  local items = {}
  local show_sign = false

  -- If we're adding a new list rather than appending to an existing one, we
  -- need to clear existing highlights.
  if info.start_idx == 1 then
    api.nvim_buf_clear_namespace(qf_bufnr, namespace, 0, -1)
  end

  for i = info.start_idx, info.end_idx do
    local raw = raw_items[i]

    if raw then
      local item = {
        type = raw.type,
        text = raw.text,
        location = '',
        path_size = 0,
        line_col_size = 0,
        index = i,
      }

      if type_mapping[item.type] then
        show_sign = true
      end

      if raw.bufnr > 0 then
        item.location = trim_path(fn.bufname(raw.bufnr))
        item.path_size = #item.location
      end

      if raw.lnum and raw.lnum > 0 then
        if #item.location > 0 then
          item.location = item.location .. ' ' .. raw.lnum
        else
          item.location = tostring(raw.lnum)
        end

        -- Column numbers without line numbers make no sense, and may confuse
        -- the user into thinking they are actually line numbers.
        if raw.col and raw.col > 0 then
          item.location = item.location .. ':' .. raw.col
        end

        item.line_col_size = #item.location - item.path_size
      end

      local size = fn.strwidth(item.location)

      if size > pad_to then
        pad_to = size
      end

      table.insert(items, item)
    end
  end

  local highlights = {}

  for _, item in ipairs(items) do
    local line_idx = item.index - 1

    -- Quickfix items only support singe-line messages, and show newlines as
    -- funny characters. In addition, many language servers (e.g.
    -- rust-analyzer) produce super noisy multi-line messages where only the
    -- first line is relevant.
    --
    -- To handle this, we only include the first line of the message in the
    -- quickfix line.
    local text = vim.split(item.text, '\n')[1]
    local location = item.location

    -- Optionally show multiple lines joined with single space
    if show_multiple_lines then
      text = fn.substitute(item.text, '\n\\s*', ' ', 'g')
    end

    text = fn.trim(text)

    if text ~= '' then
      location = pad_right(location, pad_to)
    end

    local sign, sign_hl = unpack(type_mapping[item.type] or {})
    local prefix = show_sign and (sign or ' ') .. ' ' or ''
    local line = prefix .. location .. text

    -- If a line is completely empty, Vim uses the default format, which
    -- involves inserting `|| `. To prevent this from happening we'll just
    -- insert an empty space instead.
    if line == '' then
      line = ' '
    end

    if show_sign and sign_hl then
      table.insert(
        highlights,
        { group = sign_hl, line = line_idx, col = 0, end_col = #sign }
      )
    end

    if item.path_size > 0 then
      table.insert(highlights, {
        group = 'Directory',
        line = line_idx,
        col = #prefix,
        end_col = #prefix + item.path_size,
      })
    end

    if item.line_col_size > 0 then
      local col_start = #prefix + item.path_size

      table.insert(highlights, {
        group = 'Number',
        line = line_idx,
        col = col_start,
        end_col = col_start + item.line_col_size,
      })
    end

    table.insert(lines, line)
  end

  -- Applying highlights has to be deferred, otherwise they won't apply to the
  -- lines inserted into the quickfix window.
  vim.schedule(function()
    apply_highlights(qf_bufnr, highlights)
  end)

  return lines
end

function M.setup(opts)
  opts = opts or {}

  if opts.signs then
    assert(type(opts.signs) == 'table', 'the "signs" option must be a table')
    signs = vim.tbl_extend('force', signs, opts.signs)
  end

  if opts.show_multiple_lines then
    show_multiple_lines = true
  end

  if opts.max_filename_length then
    max_filename_length = opts.max_filename_length
    assert(
      type(max_filename_length) == 'number',
      'the "max_filename_length" option must be a number'
    )
  end

  vim.o.quickfixtextfunc = "v:lua.require'pqf'.format"
end

return M
