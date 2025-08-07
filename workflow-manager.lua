-- Workflow Manager for Flowweave
-- Handles deployment and configuration of workflows

-- Initialize state
if not workflows then
  workflows = {}
  print("[MANAGER] Initialized workflows table")
end

if not registryId then
  registryId = nil
  print("[MANAGER] Registry ID not set")
end

if not factoryId then
  factoryId = nil
  print("[MANAGER] Factory ID not set")
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

-- Handlers for workflow management
Handlers.add(
  "DeployWorkflow",
  { Action = "DeployWorkflow" },
  function(msg)
    print("[MANAGER] Received DeployWorkflow request")
    
    -- Parse incoming data
    local workflowData = deserializeJson(msg.Data)
    if not workflowData or type(workflowData) ~= "table" then
      print("[MANAGER] Error: Invalid workflow data")
      return msg.reply({ Data = serializeToJson({ error = "Invalid workflow data" }) })
    end

    -- Validate required workflow structure
    if not workflowData.nodes or type(workflowData.nodes) ~= "table" then
      print("[MANAGER] Error: Invalid nodes data")
      return msg.reply({ Data = serializeToJson({ error = "Invalid nodes data - must be a table" }) })
    end

    if not workflowData.connections or type(workflowData.connections) ~= "table" then
      print("[MANAGER] Error: Invalid connections data")
      return msg.reply({ Data = serializeToJson({ error = "Invalid connections data - must be a table" }) })
    end

    -- Create workflow record
    local workflowId = msg.Id
    print("[MANAGER] Creating workflow with ID: " .. workflowId)
    
    workflows[workflowId] = {
      owner = msg.From,
      nodes = workflowData.nodes,
      connections = workflowData.connections,
      status = "created"
    }
    print("[MANAGER] Workflow record created")

    -- Request orchestrator creation from factory
    if factoryId then
      print("[MANAGER] Requesting orchestrator creation from factory: " .. factoryId)
      local result = ao.send({
        Target = factoryId,
        Action = "CreateOrchestrator",
        Tags = {
          Workflowid = workflowId
        },
        Data = serializeToJson(workflowData)
      })
      print("[MANAGER] Orchestrator creation request sent")
      print(result)
    else
      print("[MANAGER] Warning: Factory ID not set, skipping orchestrator creation")
    end

    msg.reply({
      Data = serializeToJson({
        message = "Workflow deployed successfully",
        workflowId = workflowId
      }),
      Tags = {
        Workflowid = workflowId
      }
    })
    print("[MANAGER] Deployment confirmation sent to caller")
  end
)

-- Handler for configuring registry
Handlers.add(
  "ConfigureRegistry",
  { Action = "ConfigureRegistry" },
  function(msg)
    print("[MANAGER] Received ConfigureRegistry request")
    
    if not msg.Tags.Registryid then
      print("[MANAGER] Error: Registry ID missing")
      return msg.reply({ Data = serializeToJson({ error = "Registry ID required" }) })
    end
    
    registryId = msg.Tags.Registryid
    print("[MANAGER] Set registry ID to: " .. registryId)
    
    msg.reply({ Data = serializeToJson({ Registryid = registryId, status = "configured" }) })
    print("[MANAGER] Registry configuration confirmed")
  end
)

-- Handler for configuring factory
Handlers.add(
  "ConfigureFactory",
  { Action = "ConfigureFactory" },
  function(msg)
    print("[MANAGER] Received ConfigureFactory request")
    
    if not msg.Tags.Factoryid then
      print("[MANAGER] Error: Factory ID missing")
      return msg.reply({ Data = serializeToJson({ error = "Factory ID required" }) })
    end
    
    factoryId = msg.Tags.Factoryid
    print("[MANAGER] Set factory ID to: " .. factoryId)
    
    msg.reply({ Data = serializeToJson({ Factoryid = factoryId, status = "configured" }) })
    print("[MANAGER] Factory configuration confirmed")
  end
)

-- Handler for getting workflow status
Handlers.add(
  "GetWorkflow",
  { Action = "GetWorkflow" },
  function(msg)
    print("[MANAGER] Received GetWorkflow request")
    
    local workflowId = msg.Tags.Workflowid
    if not workflowId or not workflows[workflowId] then
      print("[MANAGER] Error: Workflow not found: " .. (workflowId or "nil"))
      return msg.reply({ Data = serializeToJson({ error = "Workflow not found" }) })
    end
    
    print("[MANAGER] Returning workflow data for: " .. workflowId)
    msg.reply({
      Data = serializeToJson(workflows[workflowId])
    })
  end
)
