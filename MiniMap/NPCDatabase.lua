
NPCDatabase = {
    _data = nil,
}
NPCDatabase.__index = NPCDatabase

local NPC_REACTION_FRIENDLY = 4
local NPC_REACTION_HOSTILE = 3
local NPC_REACTION_NEUTRAL = 2

function NPCDatabase:Init(savedVars)
    self._metadata = savedVars
    if not self._metadata["data"] then
        self._metadata["data"] = {}
    end
    self._data = self._metadata["data"]
end

function NPCDatabase:AddNPC(npcName, x, y, mapName, extraData)
    if not self._data then return false end
    if not npcName or npcName == "" or not x or not y then return false end
    
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then
        self._data[currentMap] = {}
    end
    
    local existing = self._data[currentMap][npcName]
    if existing then
        existing.x = x
        existing.y = y
        existing.ts = GetTimeStamp()
        if extraData then
            for k, v in pairs(extraData) do
                existing[k] = v
            end
        end
        return true
    end
    
    self._data[currentMap][npcName] = {
        x = x,
        y = y,
        ts = GetTimeStamp(),
    }
    if extraData then
        local entry = self._data[currentMap][npcName]
        for k, v in pairs(extraData) do
            entry[k] = v
        end
    end
    return true
end

function NPCDatabase:UpdateNPCPosition(npcName, x, y, mapName)
    if not self._data then return false end
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] or not self._data[currentMap][npcName] then return false end
    self._data[currentMap][npcName].x = x
    self._data[currentMap][npcName].y = y
    self._data[currentMap][npcName].ts = GetTimeStamp()
    return true
end

function NPCDatabase:GetNPCByName(npcName, mapName)
    if not npcName then return nil end
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then return nil end
    return self._data[currentMap][npcName]
end

function NPCDatabase:GetNPCsByMap(mapName)
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then return {} end
    local result = {}
    for name, data in pairs(self._data[currentMap]) do
        if type(name) == "string" and type(data) == "table" then
            result[name] = data
        end
    end
    return result
end

function NPCDatabase:GetAllNPCs()
    local result = {}
    for mapName, npcs in pairs(self._data) do
        if type(mapName) == "string" and type(npcs) == "table" then
            result[mapName] = {}
            for npcName, data in pairs(npcs) do
                if type(npcName) == "string" and type(data) == "table" then
                    result[mapName][npcName] = data
                end
            end
        end
    end
    return result
end

function NPCDatabase:SearchNPCs(query, mapName)
    if not query or query == "" then return {} end
    local results = {}
    query = zo_strlower(query)
    
    local function processMap(map, name)
        if type(name) ~= "string" or type(map) ~= "table" then return end
        if string.find(zo_strlower(name), query, 1, true) then
            table.insert(results, {
                name = name,
                map = mapName,
                x = map.x,
                y = map.y,
                ts = map.ts,
            })
        end
    end
    
    if mapName then
        local mapData = self._data[mapName]
        if mapData then
            for name, data in pairs(mapData) do
                processMap(data, name)
            end
        end
    else
        for mapNameIter, mapData in pairs(self._data) do
            if type(mapNameIter) == "string" then
                for name, data in pairs(mapData) do
                    if type(name) == "string" then
                        processMap(data, name)
                    end
                end
            end
        end
    end
    
    table.sort(results, function(a, b) return a.name < b.name end)
    return results
end

function NPCDatabase:GetNPCsInRadius(px, py, radius, mapName)
    if not px or not py or not radius then return {} end
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then return {} end
    
    local thresholdSq = radius * radius
    local results = {}
    
    for name, data in pairs(self._data[currentMap]) do
        if type(name) == "string" and type(data) == "table" then
            local dx = data.x - px
            local dy = data.y - py
            if (dx * dx + dy * dy) <= thresholdSq then
                table.insert(results, {
                    name = name,
                    x = data.x,
                    y = data.y,
                    ts = data.ts,
                })
            end
        end
    end
    return results
end

function NPCDatabase:GetNearestNPC(px, py, mapName, maxDistance)
    if not px or not py then return nil end
    maxDistance = maxDistance or 1
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then return nil end
    
    local best = nil
    local bestDistSq = nil
    local maxDistSq = maxDistance * maxDistance
    
    for name, data in pairs(self._data[currentMap]) do
        if type(name) == "string" and type(data) == "table" then
            local dx = data.x - px
            local dy = data.y - py
            local distSq = dx * dx + dy * dy
            if distSq < bestDistSq or bestDistSq == nil then
                if distSq <= maxDistSq then
                    bestDistSq = distSq
                    best = {
                        name = name,
                        x = data.x,
                        y = data.y,
                        ts = data.ts,
                        distance = math.sqrt(distSq),
                    }
                end
            end
        end
    end
    return best
end

function NPCDatabase:GetAllMaps()
    local maps = {}
    for mapName, npcs in pairs(self._data) do
        if type(mapName) == "string" and type(npcs) == "table" then
            local count = 0
            for _ in pairs(npcs) do count = count + 1 end
            if count > 0 then
                maps[mapName] = count
            end
        end
    end
    return maps
end

function NPCDatabase:GetNpcCount(mapName)
    if mapName then
        local mapData = self._data[mapName]
        if not mapData then return 0 end
        local count = 0
        for _ in pairs(mapData) do count = count + 1 end
        return count
    else
        local total = 0
        for _, npcs in pairs(self._data) do
            if type(npcs) == "table" then
                for _ in pairs(npcs) do total = total + 1 end
            end
        end
        return total
    end
end

function NPCDatabase:RemoveNPC(npcName, mapName)
    if not self._data then return false end
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then return false end
    if not self._data[currentMap][npcName] then return false end
    self._data[currentMap][npcName] = nil
    return true
end

function NPCDatabase:Clear(mapName)
    if mapName then
        if self._data[mapName] then
            self._data[mapName] = {}
        end
    else
        for k in pairs(self._data) do
            if type(k) == "string" then
                self._data[k] = {}
            end
        end
    end
end

function NPCDatabase:CleanDuplicates()
    if not self._data then return 0 end
    local removed = 0
    local THRESHOLD = MINIMAP_SPOT_DUPLICATE_THRESHOLD or 0.0005
    local THRESHOLD_SQ = THRESHOLD * THRESHOLD
    
    for mapName, npcs in pairs(self._data) do
        if type(mapName) == "string" and type(npcs) == "table" then
            local names = {}
            for name, data in pairs(npcs) do
                if type(name) == "string" then
                    table.insert(names, {name = name, x = data.x, y = data.y})
                end
            end
            
            local toRemove = {}
            for i = 1, #names do
                for j = i + 1, #names do
                    if names[i].name == names[j].name then
                        local dx = names[i].x - names[j].x
                        local dy = names[i].y - names[j].y
                        if (dx * dx + dy * dy) <= THRESHOLD_SQ then
                            toRemove[names[j].name] = true
                        end
                    end
                end
            end
            
            for nameToRemove, _ in pairs(toRemove) do
                npcs[nameToRemove] = nil
                removed = removed + 1
            end
        end
    end
    return removed
end

function NPCDatabase:Exists(npcName, mapName)
    local currentMap = mapName or GetMapName()
    if not self._data[currentMap] then return false end
    return self._data[currentMap][npcName] ~= nil
end

return NPCDatabase
