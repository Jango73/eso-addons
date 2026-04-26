MiniMapDebug = {}

local DEBUG_ENABLED = true

function Debug(message)
    if not DEBUG_ENABLED then
        return
    end
    if CHAT_ROUTER and CHAT_ROUTER.AddDebugMessage then
        CHAT_ROUTER:AddDebugMessage("[MiniMap] " .. tostring(message))
    elseif d then
        d("[MiniMap] " .. tostring(message))
    end
end

function DebugCoalesced(key, message)
    if not DEBUG_ENABLED then
        return
    end
    MiniMapDebug._debugLogCounts = MiniMapDebug._debugLogCounts or {}
    local count = (MiniMapDebug._debugLogCounts[key] or 0) + 1
    MiniMapDebug._debugLogCounts[key] = count

    -- Keep first occurrences, then sample regularly.
    if count == 1 or count == 2 or count == 5 or (count % 25) == 0 then
        Debug(string.format("%s x%d", message, count))
    end
end