-- Log Output Node for Flowweave
-- A node that logs workflow execution results

-- Initialize state
if not logs then
  logs = {}
end

-- Register this node with the registry on startup
if ao.env and ao.env.Data and ao.env.Data.registryId then
  ao.send({
    Target = ao.env.Data.registryId,
    Action = "RegisterNode",
    Data = {
      type = "output",
      name = "Log Output",
      description = "A node that logs workflow execution results",
      capabilities = {
        trigger = false,
        input = true,
        output = false
      }
    }
  })
end

-- Handler for executing the node
Handlers.add(
  "Execute",
  { Action = "Execute" },
  function(msg)
    -- Record the log entry
    local logEntry = {
      timestamp = os.time(),
      workflowId = msg.Tags["Workflow-ID"],
      nodeId = msg.Tags["Node-ID"],
      data = msg.Data
    }
    
    table.insert(logs, logEntry)

    -- Send execution complete
    msg.reply({
      Action = "ExecutionComplete",
      Data = logEntry,
      Tags = msg.Tags  -- Preserve workflow context tags
    })
  end
)

-- Handler for retrieving logs
Handlers.add(
  "GetLogs",
  { Action = "GetLogs" },
  function(msg)
    -- Optional workflow filter
    local workflowId = msg.Tags["Workflow-ID"]
    local results = {}
    
    if workflowId then
      for _, log in ipairs(logs) do
        if log.workflowId == workflowId then
          table.insert(results, log)
        end
      end
    else
      results = logs
    end
    
    msg.reply({
      Data = results
    })
  end
) 