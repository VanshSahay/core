-- Logger Node for Flowweave
-- A node that logs workflow data

-- Initialize state
if not state then
  state = {
    isRegistered = false,
    registryId = nil,
    logCount = 0,
    lastRegistrationAttempt = 0
  }
  print("[LOGGER] Initialized new state")
end

-- JSON utility functions
local function serializeToJson(data)
  if type(data) == "table" then
    local json = "{"
    local first = true
    for k, v in pairs(data) do
      if not first then json = json .. "," end
      json = json .. string.format('"%s":', k)
      if type(v) == "table" then
        json = json .. serializeToJson(v)
      elseif type(v) == "string" then
        json = json .. string.format('"%s"', v)
      else
        json = json .. tostring(v)
      end
      first = false
    end
    return json .. "}"
  elseif type(data) == "string" then
    return string.format('"%s"', data)
  else
    return tostring(data)
  end
end

local function deserializeJson(jsonStr)
  if type(jsonStr) ~= "string" then return jsonStr end
  -- Basic JSON parsing
  local function parseValue(str)
    str = str:match("^%s*(.-)%s*$") -- Trim whitespace
    if str:sub(1,1) == "{" then
      local obj = {}
      str = str:sub(2, -2) -- Remove braces
      for k, v in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
        obj[k] = parseValue(v)
      end
      return obj
    elseif str:sub(1,1) == '"' then
      return str:sub(2, -2) -- Remove quotes
    else
      -- Try to convert to number if possible
      local num = tonumber(str)
      return num or str
    end
  end
  return parseValue(jsonStr)
end

-- Helper function to get current timestamp in milliseconds
local function getCurrentTime()
  return os.time() * 1000
end

-- Handler for configuration
Handlers.add(
  "Configure",
  { Action = "Configure" },
  function(msg)
    print("[LOGGER] Received Configure request")
    
    if not msg.Tags.Registryid then
      print("[LOGGER] Error: Registry ID missing")
      return msg.reply({ Data = serializeToJson({ error = "Registry ID required" }) })
    end

    state.registryId = msg.Tags.Registryid
    print("[LOGGER] Set registry ID to: " .. state.registryId)
    
    -- Send registration message with proper tags
    print("[LOGGER] Sending registration to registry")
    local result = ao.send({
      Target = state.registryId,
      Action = "Register",
      Data = serializeToJson({
        name = "Logger",
        type = "logger",
        description = "A node that logs workflow data",
        capabilities = {
          input = true,
          output = false,
          trigger = false
        }
      }),
      Tags = {
        ["Content-Type"] = "application/json",
        ["Message-Type"] = "Registration",
        ["Node-Type"] = "logger"
      }
    })

    state.lastRegistrationAttempt = os.time()
    print("[LOGGER] Registration message sent")
    msg.reply({ Data = serializeToJson({ message = "Configuration received, registration sent" }) })
  end
)

-- Handler for registration response
Handlers.add(
  "RegisterResponse",
  { Action = "RegisterResponse" },
  function(msg)
    print("[LOGGER] Received RegisterResponse")
    
    if msg.From ~= state.registryId then
      print("[LOGGER] Warning: Response from unknown source: " .. msg.From)
      return
    end

    local responseData = deserializeJson(msg.Data)
    if responseData and responseData.status == "success" then
      state.isRegistered = true
      print("[LOGGER] Registration confirmed by registry")
    else
      state.isRegistered = false
      print("[LOGGER] Registration failed or invalid response")
    end

    msg.reply({
      Data = serializeToJson({
        status = state.isRegistered and "registered" or "failed",
        timestamp = os.time()
      })
    })
  end
)

-- Handler for status check
Handlers.add(
  "Status",
  { Action = "Status" },
  function(msg)
    print("[LOGGER] Status check requested")
    msg.reply({
      Data = serializeToJson({
        isRegistered = state.isRegistered,
        registryId = state.registryId,
        logCount = state.logCount,
        lastRegistrationAttempt = state.lastRegistrationAttempt
      })
    })
  end
)

-- Handler for logging
Handlers.add(
  "Log",
  { Action = "Log" },
  function(msg)
    print("[LOGGER] Received Log request")
    
    if not state.isRegistered then
      print("[LOGGER] Error: Node not registered")
      return msg.reply({ Data = serializeToJson({ error = "Node not registered with registry" }) })
    end

    -- Increment log count and log the data
    state.logCount = state.logCount + 1
    print("[LOGGER] Log count incremented to: " .. state.logCount)
    print("[LOGGER] Logging data: " .. tostring(msg.Data))

    -- Send confirmation
    msg.reply({
      Data = serializeToJson({
        status = "logged",
        count = state.logCount,
        timestamp = os.time()
      })
    })
    print("[LOGGER] Log confirmation sent to caller")
  end
)

-- Handler for getting logs
Handlers.add(
  "GetLogs",
  { Action = "GetLogs" },
  function(msg)
    if not state.isRegistered then
      return msg.reply({ Data = serializeToJson({ error = "Node not registered with registry" }) })
    end

    -- Optional workflow filter
    local workflowId = msg.Tags.Workflowid
    
    msg.reply({
      Data = serializeToJson({
        logCount = state.logCount,
        registryId = state.registryId,
        timestamp = getCurrentTime()
      })
    })
  end
)