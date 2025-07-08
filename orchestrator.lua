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
    print(string.format("Initialized orchestrator for workflow %s", state.workflowId))
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

-- Handler for workflow trigger events
Handlers.add(
  "WorkflowTrigger",
  { Action = "WorkflowTrigger" },
  function(msg)
    print(string.format("Received workflow trigger for workflow %s", msg.Tags.Workflowid))
    
    if msg.Tags.Workflowid ~= state.workflowId then
      return msg.reply({
        Data = {
          status = "error",
          error = "Wrong workflow ID"
        }
      })
    end

    -- Find the trigger node that sent this
    local triggerNodeId = msg.From
    if not triggerNodeId then
      return msg.reply({
        Data = {
          status = "error",
          error = "Missing trigger node ID"
        }
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
        Data = {
          status = "error",
          error = "Invalid trigger node"
        }
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
          Data = msg.Data,
          Tags = {
            Workflowid = state.workflowId,
            Nodeid = nodeId,
            ["Content-Type"] = "application/json"
          }
        })
      end
    end

    msg.reply({
      Data = {
        status = "success",
        message = "Workflow execution started"
      }
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
      result = msg.Data
    })

    -- Find and execute next nodes
    local nextNodes = getNextNodes(nodeId)
    for _, nextNodeId in ipairs(nextNodes) do
      local node = state.nodes[nextNodeId]
      if node then
        ao.send({
          Target = node.processId,
          Action = "Log",
          Data = msg.Data,
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