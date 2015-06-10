local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Logger        = require "cosy.logger"
local Methods       = require "cosy.methods"
local Store         = require "cosy.store"
local Value         = require "cosy.value"

Configuration.load "cosy.server"

local i18n   = I18n.load "cosy.server"
i18n._locale = Configuration.locale._

local function call_method (method, request, try_only)
  for _ = 1, Configuration.redis.retry._ do
    local err
    local ok, result = xpcall (function ()
      local store  = Store.new ()
      local result = method (request, store, try_only)
      if not try_only then
        Store.commit (store)
      end
      return result
    end, function (e)
      err = e
      Logger.debug ("Error: " .. Value.expression (e) .. " => " .. debug.traceback ())
    end)
    if ok then
      return result or true
    elseif err ~= Store.Error then
      return nil, err
    end
  end
  return nil, {
    _ = i18n ["redis:unreachable"],
  }
end

local function call_parameters (method)
  local _, result = pcall (method)
  return result
end

return function (message)
  local function translate (x)
    i18n (x)
    return x
  end
  Logger.warning (message)
  local decoded, request = pcall (Value.decode, message)
  if not decoded or type (request) ~= "table" then
    return Value.expression (translate {
      success = false,
      error   = {
        _ = i18n ["message:invalid"],
      },
    })
  end
  local identifier      = request.identifier
  local operation       = request.operation
  local parameters      = request.parameters or {}
  local try_only        = request.try_only
  local parameters_only = false
  local method          = Methods
  if operation:sub (-1) == "?" then
    operation       = operation:sub (1, #operation-1)
    parameters_only = true
  end
  for name in operation:gmatch "[^:]+" do
    if method ~= nil then
      name = name:gsub ("-", "_")
      method = method [name]
    end
  end
  if not method then
    return Value.expression (translate {
      identifier = identifier,
      success    = false,
      error      = {
        _         = i18n ["server:no-operation"],
        operation = request.operation,
      },
    })
  end
  local result, err
  if parameters_only then
    result      = call_parameters (method)
  else
    result, err = call_method (method, parameters or {}, try_only)
  end
  if result then
    translate (result)
    result = {
      identifier = identifier,
      success    = true,
      response   = result,
    }
  else
    translate (err)
    result = {
      identifier = identifier,
      success    = false,
      error      = err,
    }
  end
  return Value.expression (result)
end
