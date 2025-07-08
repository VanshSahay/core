-- Registry for Flowweave
-- Maintains a list of available nodes and their capabilities

-- Initialize state
if not nodes then
  nodes = {}
  print("Initialized empty nodes table")
end

-- Debug function to print nodes
local function printNodes()
  print("Current nodes in registry:")
  for id, node in pairs(nodes) do
    print(string.format("Node ID: %s, Type: %s, Name: %s, Last Seen: %d",
      id, node.type, node.name, node.lastSeen))
  end
end

-- Helper function to get current timestamp in seconds
local function getCurrentTime()
  return os.time()
end

-- Handler for node registration
Handlers.add(
  "Register",
  { Action = "Register" },
  function(msg)
    print("Received registration request from: " .. msg.From)
    
    if not msg.Data then
      print("Registration failed: No data provided")
      return msg.reply({
        Action = "RegisterResponse",
        Data = {
          status = "error",
          error = "Registration data required"
        }
      })
    end

    -- Validate required fields
    local required = {"name", "type", "description", "capabilities"}
    for _, field in ipairs(required) do
      if not msg.Data[field] then
        print("Registration failed: Missing field " .. field)
        return msg.reply({
          Action = "RegisterResponse",
          Data = {
            status = "error",
            error = field .. " is required"
          }
        })
      end
    end

    -- Store node information
    local currentTime = getCurrentTime()
    nodes[msg.From] = {
      status = "active",
      name = msg.Data.name,
      type = msg.Data.type,
      description = msg.Data.description,
      capabilities = msg.Data.capabilities,
      lastSeen = currentTime
    }

    print(string.format("Successfully registered node %s at time %d", msg.From, currentTime))
    printNodes()

    -- Send registration confirmation
    msg.reply({
      Action = "RegisterResponse",
      Data = {
        status = "success",
        nodeId = msg.From,
        timestamp = currentTime
      },
      Tags = {
        ["Content-Type"] = "application/json",
        ["Message-Type"] = "Registration",
        ["Node-Type"] = msg.Data.type
      }
    })
  end
)

-- Handler for discovering nodes
Handlers.add(
  "DiscoverNodes",
  { Action = "DiscoverNodes" },
  function(msg)
    print("Processing DiscoverNodes request")
    
    -- Optional type filter
    local nodeType = msg.Tags["Node-Type"]
    local filteredNodes = {}
    
    if nodeType then
      for id, node in pairs(nodes) do
        if node.type == nodeType then
          filteredNodes[id] = node
        end
      end
    else
      filteredNodes = nodes
    end
    
    local nodeCount = 0
    for _ in pairs(filteredNodes) do
      nodeCount = nodeCount + 1
    end
    
    print(string.format("Found %d nodes%s", 
      nodeCount, 
      nodeType and string.format(" of type '%s'", nodeType) or ""))
    printNodes()
    
    -- Return nodes
    msg.reply({
      Data = filteredNodes,
      Tags = {
        ["Content-Type"] = "application/json",
        ["Node-Count"] = tostring(nodeCount)
      }
    })
  end
)

-- Handler for node heartbeat
Handlers.add(
  "Heartbeat",
  { Action = "Heartbeat" },
  function(msg)
    if not nodes[msg.From] then
      return msg.reply({
        Data = {
          status = "error",
          error = "Node not registered"
        }
      })
    end

    -- Update last seen timestamp
    local currentTime = getCurrentTime()
    nodes[msg.From].lastSeen = currentTime
    
    print(string.format("Updated heartbeat for node %s at time %d", msg.From, currentTime))
    
    msg.reply({
      Data = {
        status = "active",
        lastSeen = currentTime
      }
    })
  end
)

-- Handler for removing nodes
Handlers.add(
  "RemoveNode",
  { Action = "RemoveNode" },
  function(msg)
    local nodeId = msg.Tags["Node-Id"]
    if not nodeId then
      return msg.reply({
        Data = {
          status = "error",
          error = "Node-Id tag required"
        }
      })
    end

    if not nodes[nodeId] then
      return msg.reply({
        Data = {
          status = "error",
          error = "Node not found"
        }
      })
    end

    -- Store node info for response
    local nodeInfo = nodes[nodeId]
    
    -- Remove the node
    nodes[nodeId] = nil
    print(string.format("Removed node %s of type '%s'", nodeId, nodeInfo.type))
    printNodes()

    msg.reply({
      Data = {
        status = "success",
        nodeId = nodeId,
        type = nodeInfo.type,
        name = nodeInfo.name
      }
    })
  end
)