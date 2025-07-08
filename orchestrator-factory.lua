-- Orchestrator Factory for Flowweave
-- Creates orchestrator processes for workflows

-- Initialize state
if not orchestrators then
  orchestrators = {}
  print("[FACTORY] Initialized orchestrators table")
end

-- Handler for creating orchestrators
Handlers.add(
  "CreateOrchestrator",
  { Action = "CreateOrchestrator" },
  function(msg)
    print("[FACTORY] Received CreateOrchestrator request")
    
    -- Basic validation
    if not msg.Data or type(msg.Data) ~= "table" then
      print("[FACTORY] Error: Invalid workflow data")
      return msg.reply({ Data = { error = "Invalid workflow data" } })
    end

    local workflowId = msg.Tags.Workflowid
    if not workflowId then
      print("[FACTORY] Error: Workflow ID missing")
      return msg.reply({ Data = { error = "Workflow ID required" } })
    end

    print("[FACTORY] Creating new orchestrator")
    print(msg.Data)
    
    -- Spawn new orchestrator process
    local orchestratorId = ao.spawn("orchestrator.lua", {
      Data = msg.Data,
      Tags = {
        Workflowid = workflowId,
        Processtype = "orchestrator"
      }
    })

    if not orchestratorId then
      print("[FACTORY] Error: Failed to spawn orchestrator")
      return msg.reply({ Data = { error = "Failed to spawn orchestrator" } })
    end

    print("[FACTORY] Spawned orchestrator")
    print(orchestratorId)

    -- Store orchestrator reference
    orchestrators[workflowId] = {
      id = orchestratorId,
      status = "spawned",
      timestamp = os.time()
    }
    print("[FACTORY] Stored orchestrator reference")

    -- Send confirmation
    msg.reply({
      Data = {
        status = "success",
        orchestratorId = orchestratorId
      },
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
    local workflowId = msg.Tags.Workflowid
    if not workflowId or not orchestrators[workflowId] then
      return msg.reply({ 
        Data = {
          status = "error",
          error = "Orchestrator not found"
        }
      })
    end
    
    msg.reply({
      Data = orchestrators[workflowId],
      Tags = {
        Workflowid = workflowId,
        ["Content-Type"] = "application/json"
      }
    })
  end
)