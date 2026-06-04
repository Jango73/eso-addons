MiniMapDebug = {}

---Print a debug message if DEBUG_ENABLED is set.
---@param message string The message to log.
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

---Print a coalesced debug message, throttling repeated logs to every 25th occurrence.
---First occurrences at count 1, 2, 5, then every 25th are shown.
---@param key string Unique key to track the message group.
---@param message string The message to log.
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