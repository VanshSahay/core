-- Manual Trigger Node for Flowweave
-- A node that can manually trigger workflow execution

-- Register this node with the registry on startup
if ao.env and ao.env.Data and ao.env.Data.registryId then
  ao.send({
    Target = ao.env.Data.registryId,
    Action = "RegisterNode",
    Data = {
      type = "trigger",
      name = "Manual Trigger",
      description = "A node that can manually trigger workflow execution",
      capabilities = {
        trigger = true,
        input = false,
        output = true
      }
    }
  })
end

-- Handler for executing the node
Handlers.add(
  "Execute",
  { Action = "Execute" },
  function(msg)
    -- For manual trigger, just pass through the input data
    msg.reply({
      Action = "ExecutionComplete",
      Data = msg.Data,
      Tags = msg.Tags  -- Preserve workflow context tags
    })
  end
)

-- Handler for manual triggering
Handlers.add(
  "Trigger",
  { Action = "Trigger" },
  function(msg)
    -- Validate workflow context
    if not msg.Tags["Workflow-ID"] then
      return msg.reply({ Data = "Workflow ID required" })
    end

    -- Send execution complete with trigger data
    msg.reply({
      Action = "ExecutionComplete",
      Data = msg.Data,
      Tags = {
        ["Workflow-ID"] = msg.Tags["Workflow-ID"],
        ["Node-ID"] = ao.id
      }
    })
  end
) 