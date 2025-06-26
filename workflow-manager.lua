-- Workflow Manager for Flowweave
-- Handles deployment and configuration of workflows

-- Initialize state
if not workflows then
  workflows = {}
end

if not registryId then
  registryId = nil
end

if not factoryId then
  factoryId = nil
end

-- Handlers for workflow management
Handlers.add(
  "DeployWorkflow",
  { Action = "DeployWorkflow" },
  function(msg)
    -- Basic validation
    if not msg.Data or type(msg.Data) ~= "table" then
      return msg.reply({ Data = "Invalid workflow data" })
    end

    -- Create workflow record
    local workflowId = msg.Id
    workflows[workflowId] = {
      owner = msg.From,
      nodes = msg.Data.nodes or {},
      connections = msg.Data.connections or {},
      status = "created"
    }

    -- Request orchestrator creation from factory
    if factoryId then
      ao.send({
        Target = factoryId,
        Action = "CreateOrchestrator",
        Tags = {
          ["Workflowid"] = workflowId
        },
        Data = msg.Data
      })
    end

    msg.reply({
      Data = "Workflow deployed successfully",
      Tags = {
        ["Workflow-ID"] = workflowId
      }
    })
  end
)

-- Handler for configuring registry
Handlers.add(
  "ConfigureRegistry",
  { Action = "ConfigureRegistry" },
  function(msg)
    if not msg.Tags["Registryid"] then
        return msg.reply({ Data = "Registry ID required" })
    end
    print(msg.Tags)
    registryId = msg.Tags["Registryid"]
    msg.reply({ Data = "Registry configured" })
  end
)

-- Handler for configuring factory
Handlers.add(
  "ConfigureFactory",
  { Action = "ConfigureFactory" },
  function(msg)
    if not msg.Tags["Factoryid"] then
      return msg.reply({ Data = "Factory ID required" })
    end
    
    factoryId = msg.Tags["Factoryid"]
    msg.reply({ Data = "Factory configured" })
  end
)

-- Handler for getting workflow status
Handlers.add(
  "GetWorkflow",
  { Action = "GetWorkflow" },
  function(msg)
    local workflowId = msg.Tags["Workflowid"]
    if not workflowId or not workflows[workflowId] then
      return msg.reply({ Data = "Workflow not found" })
    end
    
    msg.reply({
      Data = workflows[workflowId]
    })
  end
)
