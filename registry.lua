-- Registry for Flowweave
-- Maintains a list of available nodes and their capabilities

-- Initialize state
if not nodes then
  nodes = {}
end

-- Handler for node registration
Handlers.add(
  "RegisterNode",
  { Action = "RegisterNode" },
  function(msg)
    -- Basic validation
    if not msg.Data or type(msg.Data) ~= "table" then
      return msg.reply({ Data = "Invalid node data" })
    end

    -- Register the node
    local nodeId = msg.From
    nodes[nodeId] = {
      type = msg.Data.type,
      name = msg.Data.name,
      description = msg.Data.description,
      capabilities = msg.Data.capabilities or {},
      status = "active",
      lastSeen = os.time()
    }

    msg.reply({
      Data = "Node registered successfully",
      Tags = {
        Nodeid = nodeId
      }
    })
  end
)

-- Handler for node discovery
Handlers.add(
  "DiscoverNodes",
  { Action = "DiscoverNodes" },
  function(msg)
    -- Optional type filter
    local nodeType = msg.Tags.Nodetype
    local results = {}
    
    for id, node in pairs(nodes) do
      if not nodeType or node.type == nodeType then
        results[id] = node
      end
    end
    
    msg.reply({
      Data = results
    })
  end
)

-- Handler for getting specific node info
Handlers.add(
  "GetNode",
  { Action = "GetNode" },
  function(msg)
    local nodeId = msg.Tags.Nodeid
    if not nodeId or not nodes[nodeId] then
      return msg.reply({ Data = "Node not found" })
    end
    
    msg.reply({
      Data = nodes[nodeId]
    })
  end
)