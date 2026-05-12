local pairs = pairs
local type = type

local M = {}

---@param dest table
---@param src table
---@return table
function M.table_merge(dest, src)
  local function merge(left, right, depth)
    if depth > 100 then
      return left
    end

    for key, value in pairs(right) do
      if type(value) == 'table' then
        left[key] = type(left[key]) == 'table' and left[key] or {}
        merge(left[key], value, depth + 1)
      else
        left[key] = value
      end
    end

    return left
  end

  return merge(dest, src, 0)
end

---@param text string
---@return string
function M.escape_lua_pattern(text)
  local escaped = text:gsub('(%W)', '%%%1')

  return escaped
end

---@param path string
---@return string
function M.basename(path)
  if type(path) ~= 'string' or path == '' then
    return ''
  end

  local normalized = path:gsub('[\\/]+$', '')

  return normalized:match '([^\\/]+)$' or normalized
end

---@param path string
---@param home string|nil
---@return string
function M.replace_home_with_tilde(path, home)
  if type(path) ~= 'string' or path == '' then
    return path
  end

  if type(home) ~= 'string' or home == '' then
    return path
  end

  local replaced = path:gsub('^' .. M.escape_lua_pattern(home), '~')

  return replaced
end

---@param path string
---@param home string|nil
---@return string
function M.expand_home(path, home)
  if type(path) ~= 'string' or path == '' then
    return path
  end

  if type(home) ~= 'string' or home == '' then
    return path
  end

  local expanded = path:gsub('^~', home, 1)

  return expanded
end

return M
