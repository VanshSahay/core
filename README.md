# Flowweave

Flowweave is a no-code builder for creating permanent workflows and automations on Arweave. It makes it easy to connect apps, smart contracts, and data into reliable flows that run forever without needing a server or any backend.

Think of it as a decentralized version of tools like Zapier or IFTTT, but designed for the permaweb. Every automation is stored on-chain, can't be tampered with, and runs independently using AO processes.

## Architecture

The system consists of several components:

- **Workflow Manager**: Handles deployment and configuration of workflows
- **Registry**: Maintains a list of available nodes and their capabilities
- **Orchestrator Factory**: Creates orchestrator processes for workflows
- **Orchestrator**: Manages and executes workflow nodes
- **Nodes**: Individual components that perform specific tasks
  - Manual Trigger Node: Starts workflow execution
  - Log Output Node: Records workflow execution results

## Setup Instructions

1. First, create all the necessary files:
```bash
mkdir flowweave
cd flowweave
# Copy all the .lua files into this directory
```

2. Spawn the registry process:
```bash
aos registry --load registry.lua
# Save the registry process ID
```

3. Spawn the factory process:
```bash
aos factory --load orchestrator-factory.lua
# Save the factory process ID
```

4. Spawn the workflow manager:
```bash
aos manager --load workflow-manager.lua
# Save the manager process ID
```

5. Configure the workflow manager:
```lua
# Connect to manager process
aos manager

# Configure registry
Send({
  Target = ao.id,
  Action = "ConfigureRegistry",
  Tags = {
    Registryid = "YOUR_REGISTRY_PROCESS_ID"
  }
})

# Configure factory
Send({
  Target = ao.id,
  Action = "ConfigureFactory",
  Tags = {
    Factoryid = "YOUR_FACTORY_PROCESS_ID"
  }
})
```

6. Spawn the nodes:
```bash
# Spawn trigger node
aos trigger --load manual-trigger.lua
# Save the trigger node ID

# Spawn logger node
aos logger --load log-output.lua
# Save the logger node ID
```

7. Deploy a workflow:
```lua
# In the manager process
Send({
  Target = ao.id,
  Action = "DeployWorkflow",
  Data = {
    nodes = {
      trigger = {
        processId = "YOUR_TRIGGER_NODE_ID",
        type = "trigger"
      },
      logger = {
        processId = "YOUR_LOGGER_NODE_ID",
        type = "output"
      }
    },
    connections = {
      {
        from = "trigger",
        to = "logger"
      }
    }
  }
})
# Save the workflow ID from the response
```

## Testing the Workflow

1. Trigger the workflow:
```lua
# Connect to trigger node
aos trigger

# Send trigger message
Send({
  Target = ao.id,
  Action = "Trigger",
  Data = "Hello Flowweave!",
  Tags = {
    Workflowid = "YOUR_WORKFLOW_ID"
  }
})
```

2. Check the logs:
```lua
# Connect to logger node
aos logger

# Get logs
Send({
  Target = ao.id,
  Action = "GetLogs",
  Tags = {
    Workflowid = "YOUR_WORKFLOW_ID"
  }
})
```

## Tag Format

All tags in messages follow these rules:
- First letter is capitalized
- All other letters are lowercase
- No hyphens or special characters
- Examples: `Workflowid`, `Nodeid`, `Registryid`, `Factoryid`

## Future Enhancements

- HTTP Request Node
- Email Send Node
- Error handling and recovery
- Workflow versioning
- More sophisticated workflow patterns
- Monitoring and debugging capabilities 