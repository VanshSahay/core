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
# Save the registry process ID as REGISTRY_ID
```

3. Spawn the factory process:
```bash
aos factory --load orchestrator-factory.lua
# Save the factory process ID as FACTORY_ID
```

4. Spawn the workflow manager:
```bash
aos manager --load workflow-manager.lua
# Save the manager process ID as MANAGER_ID
```

5. Configure the workflow manager:
```lua
# Connect to manager process
aos manager

# Configure registry
Send({
  Target = MANAGER_ID,
  Action = "ConfigureRegistry",
  Tags = {
    Registryid = REGISTRY_ID
  }
}).receive().Data

# Configure factory
Send({
  Target = MANAGER_ID,
  Action = "ConfigureFactory",
  Tags = {
    Factoryid = FACTORY_ID
  }
}).receive().Data
```

6. Spawn and configure the nodes:
```bash
# Spawn trigger node
aos trigger --load manual-trigger.lua
# Save the trigger node ID as TRIGGER_ID

# Configure trigger node
Send({
  Target = TRIGGER_ID,
  Action = "Configure",
  Tags = {
    Registryid = REGISTRY_ID
  }
}).receive().Data

# Verify trigger node status
Send({
  Target = TRIGGER_ID,
  Action = "Status"
}).receive().Data

# Spawn logger node
aos logger --load log-output.lua
# Save the logger node ID as LOGGER_ID

# Configure logger node
Send({
  Target = LOGGER_ID,
  Action = "Configure",
  Tags = {
    Registryid = REGISTRY_ID
  }
}).receive().Data

# Verify logger node status
Send({
  Target = LOGGER_ID,
  Action = "Status"
}).receive().Data
```

7. Deploy a workflow:
```lua
# In the manager process
Send({
  Target = MANAGER_ID,
  Action = "DeployWorkflow",
  Data = '{"nodes":{"trigger":{"processId":"' .. TRIGGER_ID .. '","type":"trigger"},"logger":{"processId":"' .. LOGGER_ID .. '","type":"output"}},"connections":[{"from":"trigger","to":"logger"}]}'
}).receive()
# Save the workflow ID from the response as WORKFLOW_ID
```

## Testing the Workflow

1. Trigger the workflow:
```lua
# Connect to trigger node
aos trigger

# Send trigger message
Send({
  Target = TRIGGER_ID,
  Action = "Trigger",
  Data = '"Hello Flowweave!"',
  Tags = {
    Workflowid = WORKFLOW_ID,
    Orchestratorid = ORCHESTRATOR_ID
  }
}).receive().Data
```

2. Check the logs:
```lua
# Connect to logger node
aos logger

# Get logs
Send({
  Target = LOGGER_ID,
  Action = "GetLogs",
  Tags = {
    Workflowid = WORKFLOW_ID
  }
}).receive()
```

## Troubleshooting

If you're not seeing logs after triggering a workflow:

1. Check node registration:
```lua
# Check trigger node status
Send({
  Target = TRIGGER_ID,
  Action = "Status"
}).receive()

# Check logger node status
Send({
  Target = LOGGER_ID,
  Action = "Status"
}).receive()
```

2. If either node shows `isRegistered = false`, reconfigure the node:
```lua
Send({
  Target = NODE_ID,  # TRIGGER_ID or LOGGER_ID
  Action = "Configure",
  Tags = {
    Registryid = REGISTRY_ID
  }
}).receive()
```

3. Verify workflow deployment:
```lua
# In the manager process
Send({
  Target = MANAGER_ID,
  Action = "GetWorkflow",
  Tags = {
    Workflowid = WORKFLOW_ID
  }
}).receive()
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