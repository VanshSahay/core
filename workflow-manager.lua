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

-- Handlers for workflow management
Handlers.add(
  "DeployWorkflow",
  { Action = "DeployWorkflow" },
  function(msg)
    print("[MANAGER] Received DeployWorkflow request")
    
    -- Basic validation
    if not msg.Data or type(msg.Data) ~= "table" then
      print("[MANAGER] Error: Invalid workflow data")
      return msg.reply({ Data = "Invalid workflow data" })
    end

    -- Validate required workflow structure
    if not msg.Data.nodes or type(msg.Data.nodes) ~= "table" then
      print("[MANAGER] Error: Invalid nodes data")
      return msg.reply({ Data = "Invalid nodes data - must be a table" })
    end

    if not msg.Data.connections or type(msg.Data.connections) ~= "table" then
      print("[MANAGER] Error: Invalid connections data")
      return msg.reply({ Data = "Invalid connections data - must be a table" })
    end

    -- Create workflow record
    local workflowId = msg.Id
    print("[MANAGER] Creating workflow with ID: " .. workflowId)
    
    workflows[workflowId] = {
      owner = msg.From,
      nodes = msg.Data.nodes,
      connections = msg.Data.connections,
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
        Data = {
          nodes = msg.Data.nodes,
          connections = msg.Data.connections
        }
      })
      print("[MANAGER] Orchestrator creation request sent")
      print(result)
    else
      print("[MANAGER] Warning: Factory ID not set, skipping orchestrator creation")
    end

    msg.reply({
      Data = "Workflow deployed successfully",
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
      return msg.reply({ Data = "Registry ID required" })
    end
    
    registryId = msg.Tags.Registryid
    print("[MANAGER] Set registry ID to: " .. registryId)
    
    msg.reply({ Data = { Registryid = registryId, status = "configured" } })
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
      return msg.reply({ Data = "Factory ID required" })
    end
    
    factoryId = msg.Tags.Factoryid
    print("[MANAGER] Set factory ID to: " .. factoryId)
    
    msg.reply({ Data = { Factoryid = factoryId, status = "configured" } })
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
      return msg.reply({ Data = "Workflow not found" })
    end
    
    print("[MANAGER] Returning workflow data for: " .. workflowId)
    msg.reply({
      Data = workflows[workflowId]
    })
  end
)
