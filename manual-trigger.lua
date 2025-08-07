-- Manual Trigger Node for Flowweave
-- A node that can manually trigger workflow execution

-- Initialize state
if not state then
  state = {
    isRegistered = false,
    registryId = nil,
    triggerCount = 0,
    lastRegistrationAttempt = 0
  }
  print("[TRIGGER] Initialized new state")
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

-- Handler for configuration
Handlers.add(
  "Configure",
  { Action = "Configure" },
  function(msg)
    print("[TRIGGER] Received Configure request")
    
    if not msg.Tags.Registryid then
      print("[TRIGGER] Error: Registry ID missing")
      return msg.reply({ Data = serializeToJson({ error = "Registry ID required" }) })
    end

    state.registryId = msg.Tags.Registryid
    print("[TRIGGER] Set registry ID to: " .. state.registryId)
    
    -- Send registration message with proper tags
    print("[TRIGGER] Sending registration to registry")
    local result = ao.send({
      Target = state.registryId,
      Action = "Register",
      Data = serializeToJson({
        name = "Manual Trigger",
        type = "trigger",
        description = "A node that can manually trigger workflow execution",
        capabilities = {
          input = false,
          output = true,
          trigger = true
        }
      }),
      Tags = {
        ["Content-Type"] = "application/json",
        ["Message-Type"] = "Registration",
        ["Node-Type"] = "trigger"
      }
    })

    state.lastRegistrationAttempt = os.time()
    print("[TRIGGER] Registration message sent")
    msg.reply({ Data = serializeToJson({ message = "Configuration received, registration sent" }) })
  end
)

-- Handler for registration response
Handlers.add(
  "RegisterResponse",
  { Action = "RegisterResponse" },
  function(msg)
    print("[TRIGGER] Received Register Response")
    
    if msg.From ~= state.registryId then
      print("[TRIGGER] Warning: Response from unknown source: " .. msg.From)
      return
    end

    local responseData = deserializeJson(msg.Data)
    if responseData and responseData.status == "success" then
      state.isRegistered = true
      print("[TRIGGER] Registration confirmed by registry")
    else
      state.isRegistered = false
      print("[TRIGGER] Registration failed or invalid response")
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
    print("[TRIGGER] Status check requested")
    msg.reply({
      Data = serializeToJson({
        isRegistered = state.isRegistered,
        registryId = state.registryId,
        triggerCount = state.triggerCount,
        lastRegistrationAttempt = state.lastRegistrationAttempt
      })
    })
  end
)

-- Handler for triggering
Handlers.add(
  "Trigger",
  { Action = "Trigger" },
  function(msg)
    print("[TRIGGER] Received trigger request")
    
    if not state.isRegistered then
      print("[TRIGGER] Error: Node not registered")
      return msg.reply({ Data = serializeToJson({ error = "Node not registered with registry" }) })
    end

    if not msg.Tags.Workflowid or not msg.Tags.Orchestratorid then
      print("[TRIGGER] Error: Workflow ID or Orchestrator ID missing")
      return msg.reply({ Data = serializeToJson({ error = "Workflow ID and Orchestrator ID required" }) })
    end

    -- Increment trigger count and send trigger event
    state.triggerCount = state.triggerCount + 1
    print("[TRIGGER] Trigger count incremented to: " .. state.triggerCount)
    
    -- Send trigger event to orchestrator
    print("[TRIGGER] Sending WorkflowTrigger to orchestrator: " .. msg.Tags.Orchestratorid)
    ao.send({
      Target = msg.Tags.Orchestratorid,
      Action = "WorkflowTrigger",
      Data = serializeToJson(msg.Data or {}),
      Tags = {
        ["Content-Type"] = "application/json",
        ["Trigger-Type"] = "manual",
        Workflowid = msg.Tags.Workflowid,
        Nodeid = ao.id
      }
    })
    print("[TRIGGER] WorkflowTrigger sent")

    -- Send confirmation
    msg.reply({
      Data = serializeToJson({
        status = "triggered",
        count = state.triggerCount,
        timestamp = os.time()
      })
    })
    print("[TRIGGER] Trigger confirmation sent to caller")
  end
)