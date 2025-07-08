-- Manual Trigger Node for Flowweave
-- A node that can manually trigger workflow execution

-- Initialize state
if not state then
  state = {
    isRegistered = false,
    registryId = nil,
    triggerCount = 0,
    lastRegistrationAttempt = 0
  }
  print("[TRIGGER] Initialized new state")
end

-- Handler for configuration
Handlers.add(
  "Configure",
  { Action = "Configure" },
  function(msg)
    print("[TRIGGER] Received Configure request")
    
    if not msg.Tags.Registryid then
      print("[TRIGGER] Error: Registry ID missing")
      return msg.reply({ Data = "Registry ID required" })
    end

    state.registryId = msg.Tags.Registryid
    print("[TRIGGER] Set registry ID to: " .. state.registryId)
    
    -- Send registration message with proper tags
    print("[TRIGGER] Sending registration to registry")
    local result = ao.send({
      Target = state.registryId,
      Action = "Register",
      Data = {
        name = "Manual Trigger",
        type = "trigger",
        description = "A node that can manually trigger workflow execution",
        capabilities = {
          input = false,
          output = true,
          trigger = true
        }
      },
      Tags = {
        ["Content-Type"] = "application/json",
        ["Message-Type"] = "Registration",
        ["Node-Type"] = "trigger"
      }
    })

    state.lastRegistrationAttempt = os.time()
    print("[TRIGGER] Registration message sent")
    msg.reply({ Data = "Configuration received, registration sent" })
  end
)

-- Handler for registration response
Handlers.add(
  "RegisterResponse",
  { Action = "RegisterResponse" },
  function(msg)
    print("[TRIGGER] Received RegisterResponse")
    
    if msg.From ~= state.registryId then
      print("[TRIGGER] Warning: Response from unknown source: " .. msg.From)
      return
    end

    if msg.Data and msg.Data.status == "success" then
      state.isRegistered = true
      print("[TRIGGER] Registration confirmed by registry")
    else
      state.isRegistered = false
      print("[TRIGGER] Registration failed or invalid response")
    end

    msg.reply({
      Data = {
        status = state.isRegistered and "registered" or "failed",
        timestamp = os.time()
      }
    })
  end
)

-- Handler for status check
Handlers.add(
  "Status",
  { Action = "Status" },
  function(msg)
    print("[TRIGGER] Status check requested")
    msg.reply({
      Data = {
        isRegistered = state.isRegistered,
        registryId = state.registryId,
        triggerCount = state.triggerCount,
        lastRegistrationAttempt = state.lastRegistrationAttempt
      }
    })
  end
)

-- Handler for triggering
Handlers.add(
  "Trigger",
  { Action = "Trigger" },
  function(msg)
    print("[TRIGGER] Received trigger request")
    
    if not state.isRegistered then
      print("[TRIGGER] Error: Node not registered")
      return msg.reply({ Data = "Node not registered with registry" })
    end

    if not msg.Tags.Workflowid or not msg.Tags.Orchestratorid then
      print("[TRIGGER] Error: Workflow ID or Orchestrator ID missing")
      return msg.reply({ Data = "Workflow ID and Orchestrator ID required" })
    end

    -- Increment trigger count and send trigger event
    state.triggerCount = state.triggerCount + 1
    print("[TRIGGER] Trigger count incremented to: " .. state.triggerCount)
    
    -- Send trigger event to orchestrator
    print("[TRIGGER] Sending WorkflowTrigger to orchestrator: " .. msg.Tags.Orchestratorid)
    ao.send({
      Target = msg.Tags.Orchestratorid,
      Action = "WorkflowTrigger",
      Data = msg.Data or {},
      Tags = {
        ["Content-Type"] = "application/json",
        ["Trigger-Type"] = "manual",
        Workflowid = msg.Tags.Workflowid,
        Nodeid = ao.id
      }
    })
    print("[TRIGGER] WorkflowTrigger sent")

    -- Send confirmation
    msg.reply({
      Data = {
        status = "triggered",
        count = state.triggerCount,
        timestamp = os.time()
      }
    })
    print("[TRIGGER] Trigger confirmation sent to caller")
  end
)