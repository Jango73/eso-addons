local ADDON_NAME = "MiniMapMapDumper"

local function Print(message)
    if d then
        d("|c80d0ffMiniMapMapDumper|r " .. message)
    elseif CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage("MiniMapMapDumper " .. message)
    end
end

local function ToKey(mapId, texture)
    if mapId and mapId ~= 0 then
        return "map:" .. tostring(mapId)
    end
    if texture and texture ~= "" then
        return "texture:" .. zo_strlower(texture)
    end
    return nil
end

local function ReadCurrentMapEntry(index)
    local name = GetMapName and GetMapName() or ""
    local mapId = GetCurrentMapId and GetCurrentMapId() or nil
    local mapIndex = GetCurrentMapIndex and GetCurrentMapIndex() or nil
    local zoneIndex = GetCurrentMapZoneIndex and GetCurrentMapZoneIndex() or nil
    local texture = GetMapTileTexture and GetMapTileTexture(1) or nil
    local key = ToKey(mapId, texture)

    if not name or name == "" or not key then
        return nil
    end

    return {
        key = key,
        name = name,
        mapId = mapId,
        mapIndex = mapIndex,
        mapListIndex = index,
        zoneIndex = zoneIndex,
        texture = texture,
    }
end

local function SaveEntry(dump, entry)
    dump.byName[entry.name] = entry
    dump.byKey[entry.key] = dump.byKey[entry.key] or {}
    table.insert(dump.byKey[entry.key], entry.name)

    if entry.mapId and entry.mapId ~= 0 then
        dump.byMapId[tostring(entry.mapId)] = entry
    end
    if entry.texture and entry.texture ~= "" then
        dump.byTexture[zo_strlower(entry.texture)] = entry
    end
end

local function DumpMaps()
    if not GetNumMaps or not SetMapToMapListIndex then
        Print("missing map list API")
        return
    end

    local originalMapId = GetCurrentMapId and GetCurrentMapId() or nil
    local originalMapIndex = GetCurrentMapIndex and GetCurrentMapIndex() or nil
    local originalName = GetMapName and GetMapName() or nil
    local count = GetNumMaps() or 0

    local dump = {
        version = 1,
        generatedAt = GetTimeStamp and GetTimeStamp() or 0,
        language = GetCVar and GetCVar("language.2") or nil,
        original = {
            mapId = originalMapId,
            mapIndex = originalMapIndex,
            name = originalName,
        },
        byName = {},
        byKey = {},
        byMapId = {},
        byTexture = {},
    }

    local added = 0
    local skipped = 0

    for index = 1, count do
        local result = SetMapToMapListIndex(index)
        if result == SET_MAP_RESULT_MAP_CHANGED and CALLBACK_MANAGER then
            CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
        end

        local entry = ReadCurrentMapEntry(index)
        if entry then
            SaveEntry(dump, entry)
            added = added + 1
        else
            skipped = skipped + 1
        end
    end

    if originalMapId and SetMapToMapId then
        SetMapToMapId(originalMapId)
    elseif originalMapIndex and SetMapToMapListIndex then
        SetMapToMapListIndex(originalMapIndex)
    elseif SetMapToPlayerLocation then
        SetMapToPlayerLocation()
    end

    MiniMapMapKeyDump = dump
    Print(string.format("dumped %d map names, skipped %d. Reload UI or quit to write SavedVariables.", added, skipped))
end

local function DumpCurrentMap()
    local dump = MiniMapMapKeyDump or {}
    dump.version = dump.version or 1
    dump.generatedAt = GetTimeStamp and GetTimeStamp() or 0
    dump.language = dump.language or (GetCVar and GetCVar("language.2") or nil)
    dump.byName = dump.byName or {}
    dump.byKey = dump.byKey or {}
    dump.byMapId = dump.byMapId or {}
    dump.byTexture = dump.byTexture or {}

    local entry = ReadCurrentMapEntry(GetCurrentMapIndex and GetCurrentMapIndex() or nil)
    if not entry then
        Print("current map has no usable key")
        return
    end

    SaveEntry(dump, entry)
    MiniMapMapKeyDump = dump
    Print("saved current map: " .. entry.name .. " -> " .. entry.key)
end

local function RegisterSlashCommands()
    SLASH_COMMANDS["/minimapdumpmaps"] = function(arg)
        arg = zo_strlower(arg or "")
        if arg == "current" then
            DumpCurrentMap()
        else
            DumpMaps()
        end
    end
end

local function OnAddonLoaded(_event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    RegisterSlashCommands()
    Print("loaded. Use /minimapdumpmaps or /minimapdumpmaps current.")
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
