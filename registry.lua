-- Registry for Flowweave
-- Maintains a list of available nodes and their capabilities

-- Initialize state
if not nodes then
  nodes = {}
  print("Initialized empty nodes table")
end

-- JSON utility functions
local function serializeToJson(data)
  if type(data) == "table" then
    local json = "{"
    local first = true
    for k, v in pairs(data) do
      if not first then json = json .. "," end
      json = json .. string.format('"%s":', k)
      if type(v) == "table" then
        json = json .. serializeToJson(v)
      elseif type(v) == "string" then
        json = json .. string.format('"%s"', v)
      else
        json = json .. tostring(v)
      end
      first = false
    end
    return json .. "}"
  elseif type(data) == "string" then
    return string.format('"%s"', data)
  else
    return tostring(data)
  end
end

local function deserializeJson(jsonStr)
  if type(jsonStr) ~= "string" then return jsonStr end
  -- Basic JSON parsing
  local function parseValue(str)
    str = str:match("^%s*(.-)%s*$") -- Trim whitespace
    if str:sub(1,1) == "{" then
      local obj = {}
      str = str:sub(2, -2) -- Remove braces
      for k, v in str:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
        obj[k] = parseValue(v)
      end
      return obj
    elseif str:sub(1,1) == '"' then
      return str:sub(2, -2) -- Remove quotes
    else
      -- Try to convert to number if possible
      local num = tonumber(str)
      return num or str
    end
  end
  return parseValue(jsonStr)
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
    
    local nodeData = deserializeJson(msg.Data)
    if not nodeData then
      print("Registration failed: No data provided")
      return msg.reply({
        Action = "RegisterResponse",
        Data = serializeToJson({
          status = "error",
          error = "Registration data required"
        })
      })
    end

    -- Validate required fields
    local required = {"name", "type", "description", "capabilities"}
    for _, field in ipairs(required) do
      if not nodeData[field] then
        print("Registration failed: Missing field " .. field)
        return msg.reply({
          Action = "RegisterResponse",
          Data = serializeToJson({
            status = "error",
            error = field .. " is required"
          })
        })
      end
    end

    -- Store node information
    local currentTime = getCurrentTime()
    nodes[msg.From] = {
      status = "active",
      name = nodeData.name,
      type = nodeData.type,
      description = nodeData.description,
      capabilities = nodeData.capabilities,
      lastSeen = currentTime
    }

    print(string.format("Successfully registered node %s at time %d", msg.From, currentTime))
    printNodes()

    -- Send registration confirmation
    msg.reply({
      Action = "RegisterResponse",
      Data = serializeToJson({
        status = "success",
        nodeId = msg.From,
        timestamp = currentTime
      }),
      Tags = {
        ["Content-Type"] = "application/json",
        ["Message-Type"] = "Registration",
        ["Node-Type"] = nodeData.type
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
      Data = serializeToJson(filteredNodes),
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
        Data = serializeToJson({
          status = "error",
          error = "Node not registered"
        })
      })
    end

    -- Update last seen timestamp
    local currentTime = getCurrentTime()
    nodes[msg.From].lastSeen = currentTime
    
    print(string.format("Updated heartbeat for node %s at time %d", msg.From, currentTime))
    
    msg.reply({
      Data = serializeToJson({
        status = "active",
        lastSeen = currentTime
      })
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
        Data = serializeToJson({
          status = "error",
          error = "Node-Id tag required"
        })
      })
    end

    if not nodes[nodeId] then
      return msg.reply({
        Data = serializeToJson({
          status = "error",
          error = "Node not found"
        })
      })
    end

    -- Store node info for response
    local nodeInfo = nodes[nodeId]
    
    -- Remove the node
    nodes[nodeId] = nil
    print(string.format("Removed node %s of type '%s'", nodeId, nodeInfo.type))
    printNodes()

    msg.reply({
      Data = serializeToJson({
        status = "success",
        nodeId = nodeId,
        type = nodeInfo.type,
        name = nodeInfo.name
      })
    })
  end
)