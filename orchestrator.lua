-- Orchestrator for Flowweave
-- Manages and executes workflow nodes

-- Initialize state from spawn data
if not state then
  state = {
    workflowId = nil,
    nodes = {},
    connections = {},
    nodeStates = {},
    executionHistory = {}
  }

  -- Load initial state from spawn data if available
  if ao.env and ao.env.Data then
    local envData = deserializeJson(ao.env.Data)
    state.workflowId = envData.workflowId
    state.nodes = envData.nodes or {}
    state.connections = envData.connections or {}
    print(string.format("Initialized orchestrator for workflow %s", state.workflowId))
  end
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

-- Helper function to find next nodes in workflow
local function getNextNodes(currentNodeId)
  local nextNodes = {}
  for _, connection in pairs(state.connections) do
    if connection.from == currentNodeId then
      table.insert(nextNodes, connection.to)
    end
  end
  return nextNodes
end

-- Handler for workflow trigger events
Handlers.add(
  "WorkflowTrigger",
  { Action = "WorkflowTrigger" },
  function(msg)
    print(string.format("Received workflow trigger for workflow %s", msg.Tags.Workflowid))
    
    if msg.Tags.Workflowid ~= state.workflowId then
      return msg.reply({
        Data = serializeToJson({
          status = "error",
          error = "Wrong workflow ID"
        })
      })
    end

    -- Find the trigger node that sent this
    local triggerNodeId = msg.From
    if not triggerNodeId then
      return msg.reply({
        Data = serializeToJson({
          status = "error",
          error = "Missing trigger node ID"
        })
      })
    end

    -- Verify this is a valid trigger node in our workflow
    local found = false
    for id, node in pairs(state.nodes) do
      if node.processId == triggerNodeId then
        found = true
        break
      end
    end

    if not found then
      return msg.reply({
        Data = serializeToJson({
          status = "error",
          error = "Invalid trigger node"
        })
      })
    end

    -- Get next nodes to execute
    local nextNodes = getNextNodes("trigger")
    print(string.format("Found %d next nodes to execute", #nextNodes))

    -- Execute each next node
    for _, nodeId in ipairs(nextNodes) do
      local node = state.nodes[nodeId]
      if node then
        print(string.format("Executing node %s (processId: %s)", nodeId, node.processId))
        
        -- Send execution request
        ao.send({
          Target = node.processId,
          Action = "Log",
          Data = serializeToJson(msg.Data),
          Tags = {
            Workflowid = state.workflowId,
            Nodeid = nodeId,
            ["Content-Type"] = "application/json"
          }
        })
      end
    end

    msg.reply({
      Data = serializeToJson({
        status = "success",
        message = "Workflow execution started"
      })
    })
  end
)

Handlers.add(
  "Ping",
  { Action = "Ping" },
  function(msg)
    msg.reply({
      Data = serializeToJson({
        status = "success",
        message = "Pong"
      })
    })
  end
)

-- Handler for node execution results
Handlers.add(
  "NodeExecutionComplete",
  { Action = "NodeExecutionComplete" },
  function(msg)
    local nodeId = msg.Tags.Nodeid
    if not nodeId then return end

    -- Record execution result
    table.insert(state.executionHistory, {
      nodeId = nodeId,
      timestamp = os.time(),
      result = deserializeJson(msg.Data)
    })

    -- Find and execute next nodes
    local nextNodes = getNextNodes(nodeId)
    for _, nextNodeId in ipairs(nextNodes) do
      local node = state.nodes[nextNodeId]
      if node then
        ao.send({
          Target = node.processId,
          Action = "Log",
          Data = serializeToJson(msg.Data),
          Tags = {
            Workflowid = state.workflowId,
            Nodeid = nextNodeId,
            ["Content-Type"] = "application/json"
          }
        })
      end
    end
  end
)