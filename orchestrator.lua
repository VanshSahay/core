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
    state.workflowId = ao.env.Data.workflowId
    state.nodes = ao.env.Data.nodes or {}
    state.connections = ao.env.Data.connections or {}
  end
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

-- Helper function to execute a node
local function executeNode(nodeId, input)
  local node = state.nodes[nodeId]
  if not node then return nil, "Node not found" end

  -- Send execution request to node process
  ao.send({
    Target = node.processId,
    Action = "Execute",
    Data = input,
    Tags = {
      ["Workflow-ID"] = state.workflowId,
      ["Node-ID"] = nodeId
    }
  })

  -- Wait for node execution result
  local result = Receive({
    Action = "ExecutionComplete",
    Tags = {
      ["Node-ID"] = nodeId
    }
  })

  return result.Data
end

-- Handler for starting workflow execution
Handlers.add(
  "StartExecution",
  { Action = "StartExecution" },
  function(msg)
    -- Find start nodes (nodes with no incoming connections)
    local startNodes = {}
    local hasIncoming = {}
    
    for _, connection in pairs(state.connections) do
      hasIncoming[connection.to] = true
    end
    
    for nodeId, _ in pairs(state.nodes) do
      if not hasIncoming[nodeId] then
        table.insert(startNodes, nodeId)
      end
    end

    -- Execute start nodes
    for _, nodeId in ipairs(startNodes) do
      local output = executeNode(nodeId, msg.Data)
      if output then
        -- Execute next nodes in sequence
        local nextNodes = getNextNodes(nodeId)
        for _, nextNodeId in ipairs(nextNodes) do
          executeNode(nextNodeId, output)
        end
      end
    end

    msg.reply({
      Data = "Workflow execution completed",
      Tags = {
        ["Workflow-ID"] = state.workflowId
      }
    })
  end
)

-- Handler for node execution results
Handlers.add(
  "NodeExecutionComplete",
  { Action = "NodeExecutionComplete" },
  function(msg)
    local nodeId = msg.Tags["Node-ID"]
    if not nodeId then return end

    -- Record execution result
    table.insert(state.executionHistory, {
      nodeId = nodeId,
      timestamp = os.time(),
      result = msg.Data
    })

    -- Find and execute next nodes
    local nextNodes = getNextNodes(nodeId)
    for _, nextNodeId in ipairs(nextNodes) do
      executeNode(nextNodeId, msg.Data)
    end
  end
) 