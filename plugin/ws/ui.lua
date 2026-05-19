local wezterm = require 'wezterm' ---@type Wezterm
local act = wezterm.action

local os_date = os.date
local string_rep = string.rep
local table_concat = table.concat
local table_insert = table.insert
local tostring = tostring
local type = type

local wezterm_format = wezterm.format
local wezterm_column_width = wezterm.column_width
local wezterm_nerdfonts = wezterm.nerdfonts or {}

local Config = require 'ws.config'
local Utils = require 'ws.utils'

local M = {}

local selector_alphabet = 'saoxced1234567890brfghilmnpqtuvwyz'
local selector_padding = ' '
local no_workspaces_body = 'No live workspaces found.'
local no_saved_workspaces_body =
  'No saved workspace states found. Open the selector, then press s or a.'

local display_width

---@param window Window
---@param title string
---@param body string
function M.notify(window, title, body)
  window:toast_notification(title, body)
end

---@param window Window
function M.notify_no_workspaces(window)
  M.notify(window, 'No Workspaces', no_workspaces_body)
end

---@param window Window
function M.notify_no_saved_workspaces(window)
  M.notify(window, 'No Saved Workspace States', no_saved_workspaces_body)
end

---@param window Window
---@param pane Pane
---@param opts WsWezInputSelectorOpts
function M.show_input_selector(window, pane, opts)
  window:perform_action(
    act.InputSelector {
      action = wezterm.action_callback(opts.on_select),
      title = opts.title,
      choices = opts.choices,
      alphabet = selector_alphabet,
      description = opts.description,
      fuzzy_description = opts.fuzzy_description,
    },
    pane
  )
end

---@param title string|nil
---@param width integer|nil
---@return string
function M.selector_separator(title, width)
  local content
  local colors = Config.get().colors
  local content_width = type(width) == 'number' and width or 0

  if type(title) ~= 'string' or title == '' then
    content = string_rep('─', content_width)
  else
    local title_width = display_width(title)
    local remaining_width = content_width - title_width - 1

    if remaining_width <= 0 then
      content = title
    else
      content = title .. ' ' .. string_rep('─', remaining_width)
    end
  end

  return wezterm_format {
    { Text = selector_padding },
    { Foreground = { Color = colors.separator } },
    { Attribute = { Intensity = 'Half' } },
    { Text = content },
    { Attribute = { Intensity = 'Normal' } },
    { Text = selector_padding },
  }
end

---@param value string|nil
---@return string
local function resolve_style_component(value)
  if type(value) ~= 'string' or value == '' then
    return ''
  end

  return wezterm_nerdfonts[value] or value
end

---@param icon string
---@param text string
---@return string
local function join_icon_and_text(icon, text)
  local parts = {}

  if icon ~= '' then
    table_insert(parts, icon)
  end

  if text ~= '' then
    table_insert(parts, text)
  end

  return table_concat(parts, ' ')
end

---@param text string|nil
---@return integer
display_width = function(text)
  if type(text) ~= 'string' or text == '' then
    return 0
  end

  if type(wezterm_column_width) == 'function' then
    return wezterm_column_width(text)
  end

  return #text
end

---@param text string|nil
---@param width integer|nil
---@return string
local function pad_text(text, width)
  text = type(text) == 'string' and text or ''

  if type(width) ~= 'number' or width <= 0 then
    return text
  end

  local padding_width = width - display_width(text)

  if padding_width <= 0 then
    return text
  end

  return text .. string_rep(' ', padding_width)
end

---@param text string|nil
---@return integer
function M.display_width(text)
  return display_width(text)
end

---@param config WsWezResolvedConfig
---@return string
function M.action_prefix_text(config)
  return join_icon_and_text(resolve_style_component(config.style.action), '')
end

---@param config WsWezResolvedConfig
---@return string
function M.live_workspace_prefix_text(config)
  return join_icon_and_text(resolve_style_component(config.style.workspace), config.labels.workspace)
end

---@param config WsWezResolvedConfig
---@return string
function M.current_indicator_text(config)
  return join_icon_and_text(resolve_style_component(config.style.current), config.labels.current)
end

---@param config WsWezResolvedConfig
---@return string
function M.zoxide_prefix_text(config)
  return join_icon_and_text(resolve_style_component(config.style.zoxide), config.labels.zoxide)
end

---@param pane_count integer
---@param config WsWezResolvedConfig
---@return string
function M.live_workspace_pane_count_text(pane_count, config)
  local pane_count_parts = {}
  local pane_count_icon = resolve_style_component(config.style.pane_count)

  table_insert(pane_count_parts, tostring(pane_count))

  if pane_count_icon ~= '' then
    table_insert(pane_count_parts, 1, pane_count_icon)
  end

  return '(' .. table_concat(pane_count_parts, ' ') .. ')'
end

---@return table[], { has_content: boolean }
local function start_label()
  return {
    { Text = selector_padding },
  }, { has_content = false }
end

---@param label table[]
---@return string
local function finish_label(label)
  table_insert(label, { Text = selector_padding })

  return wezterm_format(label)
end

---@param elements table[]
---@param state { has_content: boolean }
---@param color string
---@param text string
---@param intensity 'Normal'|'Half'|'Bold'|nil
local function append_segment(elements, state, color, text, intensity)
  if text == '' then
    return
  end

  if state.has_content then
    table_insert(elements, { Text = ' ' })
  else
    state.has_content = true
  end

  table_insert(elements, { Foreground = { Color = color } })

  if intensity and intensity ~= 'Normal' then
    table_insert(elements, { Attribute = { Intensity = intensity } })
  end

  table_insert(elements, { Text = text })

  if intensity and intensity ~= 'Normal' then
    table_insert(elements, { Attribute = { Intensity = 'Normal' } })
  end
end

---@param text string
---@param config WsWezResolvedConfig
---@param layout { prefix_width?: integer, text_width?: integer }|nil
---@return string
function M.format_action_label(text, config, layout)
  local label, state = start_label()
  local prefix_text = pad_text(M.action_prefix_text(config), layout and layout.prefix_width)
  local action_text = pad_text(text, layout and layout.text_width)

  append_segment(
    label,
    state,
    config.colors.action_prefix,
    prefix_text,
    nil
  )
  append_segment(label, state, config.colors.text, action_text, nil)

  return finish_label(label)
end

---@param name string
---@param is_current boolean
---@param pane_count integer
---@param config WsWezResolvedConfig
---@param layout { current_width?: integer, name_width?: integer, pane_count_width?: integer, prefix_width?: integer }|nil
---@return string
function M.format_live_workspace_label(name, is_current, pane_count, config, layout)
  local colors = config.colors
  local label, state = start_label()
  local prefix_text = pad_text(M.live_workspace_prefix_text(config), layout and layout.prefix_width)
  local workspace_name = pad_text(name, layout and layout.name_width)
  local pane_count_text =
    pad_text(M.live_workspace_pane_count_text(pane_count, config), layout and layout.pane_count_width)

  append_segment(
    label,
    state,
    colors.workspace_prefix,
    prefix_text,
    nil
  )
  append_segment(label, state, colors.text, workspace_name, nil)
  append_segment(
    label,
    state,
    colors.pane_count,
    pane_count_text,
    'Half'
  )

  if is_current then
    append_segment(
      label,
      state,
      colors.current_indicator,
      pad_text(M.current_indicator_text(config), layout and layout.current_width),
      nil
    )
  end

  return finish_label(label)
end

---@param directory string
---@param config WsWezResolvedConfig
---@param layout { name_width?: integer, prefix_width?: integer }|nil
---@return string
function M.format_directory_label(directory, config, layout)
  local colors = config.colors
  local label, state = start_label()
  local prefix_text = pad_text(M.zoxide_prefix_text(config), layout and layout.prefix_width)
  local directory_name = pad_text(Utils.basename(directory), layout and layout.name_width)

  append_segment(
    label,
    state,
    colors.zoxide_prefix,
    prefix_text,
    nil
  )
  append_segment(label, state, colors.text, directory_name, nil)
  append_segment(label, state, colors.path, '(' .. directory .. ')', nil)

  return finish_label(label)
end

---@param saved_name string
---@param state WsWezSavedState|nil
---@param config WsWezResolvedConfig
---@param layout { name_width?: integer }|nil
---@return string
function M.format_saved_workspace_label(saved_name, state, config, layout)
  local details = {}
  local label, segment_state = start_label()

  if
    type(state) == 'table'
    and type(state.timestamp) == 'number'
    and state.timestamp > 0
  then
    table_insert(details, os_date('%Y-%m-%d %H:%M', state.timestamp))
  end

  if type(state) == 'table' and type(state.cwd) == 'string' and state.cwd ~= '' then
    table_insert(details, state.cwd)
  end

  append_segment(
    label,
    segment_state,
    config.colors.text,
    pad_text(saved_name, layout and layout.name_width),
    nil
  )

  if #details > 0 then
    append_segment(
      label,
      segment_state,
      config.colors.path,
      '(' .. table_concat(details, ' | ') .. ')',
      nil
    )
  end

  return finish_label(label)
end

return M
