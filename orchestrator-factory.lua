-- Orchestrator Factory for Flowweave
-- Creates orchestrator processes for workflows

-- Initialize state
if not orchestrators then
  orchestrators = {}
  print("[FACTORY] Initialized orchestrators table")
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

-- Handler for creating orchestrators
Handlers.add(
  "CreateOrchestrator",
  { Action = "CreateOrchestrator" },
  function(msg)
    print("[FACTORY] Received CreateOrchestrator request")
    
    -- Basic validation
    local workflowData = deserializeJson(msg.Data)
    if not workflowData then
      print("[FACTORY] Error: Missing workflow data")
      return msg.reply({ Data = serializeToJson({ error = "Missing workflow data" }) })
    end

    -- Validate workflow ID
    local workflowId = msg.Tags and msg.Tags.Workflowid
    if not workflowId or type(workflowId) ~= "string" then
      print("[FACTORY] Error: Invalid or missing Workflow ID")
      return msg.reply({ Data = serializeToJson({ error = "Valid Workflow ID required" }) })
    end

    print("[FACTORY] Creating new orchestrator")
    print("[FACTORY] Workflow ID:", workflowId)
    print("[FACTORY] Data type:", type(msg.Data))
    
    -- Spawn new orchestrator process
    local orchestratorId = ao.spawn(ao.env.Module.Id, {
      Data = [[
      Handlers.add(
      "Ping",
      { Action = "Ping" },
      function(msg)
        msg.reply({ Data = "Pong" })
      end
      )
      ]],
      Tags = {
        Workflowid = workflowId,
        Processtype = "orchestrator",
        ["On-Boot"] = "Data",
        ["Authority"]="fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY"
      }
    })

    -- Wait for confirmation from the new orchestrator
    local result = Receive({ Tags = { Workflowid = workflowId } })
    print("[FACTORY] Received result from new orchestrator:", result)

    if not orchestratorId then
      print("[FACTORY] Error: Failed to spawn orchestrator")
      return msg.reply({ Data = serializeToJson({ error = "Failed to spawn orchestrator" }) })
    end

    print("[FACTORY] Spawned orchestrator:", orchestratorId)

    -- Store orchestrator reference
    orchestrators[workflowId] = {
      id = orchestratorId,
      status = "spawned",
      timestamp = os.time()
    }
    print("[FACTORY] Stored orchestrator reference")

    -- Send confirmation
    msg.reply({
      Data = serializeToJson({
        status = "success",
        orchestratorId = orchestratorId
      }),
      Tags = {
        Workflowid = workflowId,
        Orchestratorid = orchestratorId
      }
    })
    print("[FACTORY] Sent confirmation")
  end
)

-- Handler for getting orchestrator info
Handlers.add(
  "GetOrchestrator",
  { Action = "GetOrchestrator" },
  function(msg)
    local workflowId = msg.Tags and msg.Tags.Workflowid
    if not workflowId or not orchestrators[workflowId] then
      return msg.reply({ 
        Data = serializeToJson({
          status = "error",
          error = "Orchestrator not found"
        })
      })
    end
    
    msg.reply({
      Data = serializeToJson(orchestrators[workflowId]),
      Tags = {
        Workflowid = workflowId,
        ["Content-Type"] = "application/json"
      }
    })
  end
)