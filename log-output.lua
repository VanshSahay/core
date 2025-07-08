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
      return msg.reply({ Data = "Registry ID required" })
    end

    state.registryId = msg.Tags.Registryid
    print("[LOGGER] Set registry ID to: " .. state.registryId)
    
    -- Send registration message with proper tags
    print("[LOGGER] Sending registration to registry")
    local result = ao.send({
      Target = state.registryId,
      Action = "Register",
      Data = {
        name = "Logger",
        type = "logger",
        description = "A node that logs workflow data",
        capabilities = {
          input = true,
          output = false,
          trigger = false
        }
      },
      Tags = {
        ["Content-Type"] = "application/json",
        ["Message-Type"] = "Registration",
        ["Node-Type"] = "logger"
      }
    })

    state.lastRegistrationAttempt = os.time()
    print("[LOGGER] Registration message sent")
    msg.reply({ Data = "Configuration received, registration sent" })
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

    if msg.Data and msg.Data.status == "success" then
      state.isRegistered = true
      print("[LOGGER] Registration confirmed by registry")
    else
      state.isRegistered = false
      print("[LOGGER] Registration failed or invalid response")
    end

    msg.reply({
      Data = {
        status = state.isRegistered and "registered" or "failed",
        timestamp = os.time()
      }
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
      Data = {
        isRegistered = state.isRegistered,
        registryId = state.registryId,
        logCount = state.logCount,
        lastRegistrationAttempt = state.lastRegistrationAttempt
      }
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
      return msg.reply({ Data = "Node not registered with registry" })
    end

    -- Increment log count and log the data
    state.logCount = state.logCount + 1
    print("[LOGGER] Log count incremented to: " .. state.logCount)
    print("[LOGGER] Logging data: " .. tostring(msg.Data))

    -- Send confirmation
    msg.reply({
      Data = {
        status = "logged",
        count = state.logCount,
        timestamp = os.time()
      }
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
      return msg.reply({ Data = "Node not registered with registry" })
    end

    -- Optional workflow filter
    local workflowId = msg.Tags.Workflowid
    
    msg.reply({
      Data = {
        logCount = state.logCount,
        registryId = state.registryId,
        timestamp = getCurrentTime()
      }
    })
  end
)