local M = {}

local _join = function(p1, p2)
  if string.sub(p1, -1) == "/" then
    p1 = string.sub(p1, 0, -2)
  end

  if string.sub(p2, 1, 1) ~= "/" then
    p2 = "/" .. p2
  end
  return p1 .. p2
end

M.join = function(p, ...)
  local paths = {...}
  local res = p
  for _, p2 in ipairs(paths) do
    res = _join(res, p2)
  end
  return res
end

M.current_script_path = function()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str
end

M.current_script_dir = function()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)")
end

return M
