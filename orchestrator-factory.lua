-- Orchestrator Factory for Flowweave
-- Creates orchestrator processes for workflows

-- Initialize state
if not orchestrators then
  orchestrators = {}
end

-- Handler for creating orchestrators
Handlers.add(
  "CreateOrchestrator",
  { Action = "CreateOrchestrator" },
  function(msg)
    -- Basic validation
    if not msg.Data or type(msg.Data) ~= "table" then
      return msg.reply({ Data = "Invalid workflow data" })
    end

    local workflowId = msg.Tags.Workflowid
    if not workflowId then
      return msg.reply({ Data = "Workflow ID required" })
    end

    -- Spawn new orchestrator process
    local spawn = ao.spawn(
      ao.env.Module.Id,  -- Using same module for simplicity
      {
        Data = {
          workflowId = workflowId,
          nodes = msg.Data.nodes,
          connections = msg.Data.connections
        },
        Tags = {
          Processtype = "orchestrator",
          Workflowid = workflowId
        }
      }
    )

    -- Wait for spawn confirmation
    local result = Receive({ Action = "Spawned" })
    local orchestratorId = result.Process

    -- Record the orchestrator
    orchestrators[workflowId] = {
      id = orchestratorId,
      status = "active",
      createdAt = os.time()
    }

    msg.reply({
      Data = "Orchestrator created successfully",
      Tags = {
        Orchestratorid = orchestratorId,
        Workflowid = workflowId
      }
    })
  end
)

-- Handler for getting orchestrator info
Handlers.add(
  "GetOrchestrator",
  { Action = "GetOrchestrator" },
  function(msg)
    local workflowId = msg.Tags.Workflowid
    if not workflowId or not orchestrators[workflowId] then
      return msg.reply({ Data = "Orchestrator not found" })
    end
    
    msg.reply({
      Data = orchestrators[workflowId]
    })
  end
)