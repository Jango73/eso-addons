MiniMapRenderUtils = {}

---Clamp a value between a minimum and maximum.
---@param value number The input value.
---@param minValue number Lower bound.
---@param maxValue number Upper bound.
---@return number The clamped value.
function MiniMapRenderUtils.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end

    return value
end

---Get the angle (in radians) of a direction vector relative to "up" (negative Y).
---@param dx number X component of the direction vector.
---@param dy number Y component of the direction vector.
---@return number Angle in radians.
function MiniMapRenderUtils.GetRotationFromUp(dx, dy)
    if math.atan2 then
        return math.atan2(dx, dy)
    end

    return math.atan(dx, dy)
end

---Rotate a 2D vector by the given angle in radians.
---@param x number X component.
---@param y number Y component.
---@param radians number Rotation angle in radians.
---@return number Rotated X component.
---@return number Rotated Y component.
function MiniMapRenderUtils.RotateVector(x, y, radians)
    if radians == 0 then
        return x, y
    end

    local cos = math.cos(radians)
    local sin = math.sin(radians)
    return (x * cos) - (y * sin), (x * sin) + (y * cos)
end

---Build a unique map key string from the current map ID or tile texture.
---@return string|nil A unique key identifying the current map, or nil if unavailable.
function MiniMapRenderUtils.GetCurrentMapKey()
    if GetCurrentMapId then
        local mapId = GetCurrentMapId()
        if mapId and mapId ~= 0 then
            return "map:" .. tostring(mapId)
        end
    end

    if GetMapTileTexture then
        local texture = GetMapTileTexture(1)
        if texture and texture ~= "" then
            return "texture:" .. string.lower(texture)
        end
    end

    return nil
end

---Convert world-normalised coordinates to local minimap pixel coordinates (with rotation).
---@param targetX number Target world X.
---@param targetY number Target world Y.
---@param playerX number Player world X.
---@param playerY number Player world Y.
---@param mapSize number Map texture size in pixels.
---@param mapRotation number Map rotation in radians.
---@param center number Minimap centre in pixels.
---@return number localX Pixel X on the minimap.
---@return number localY Pixel Y on the minimap.
---@return number distFromCenter Distance (px) from the minimap centre.
---@return number dx Unrotated X offset in pixels.
---@return number dy Unrotated Y offset in pixels.
function MiniMapRenderUtils.WorldToLocal(targetX, targetY, playerX, playerY, mapSize, mapRotation, center)
    local dx = (targetX - playerX) * mapSize
    local dy = (targetY - playerY) * mapSize
    dx, dy = MiniMapRenderUtils.RotateVector(dx, dy, mapRotation)
    local localX = center + dx
    local localY = center + dy
    local distFromCenter = math.sqrt((localX - center) ^ 2 + (localY - center) ^ 2)
    return localX, localY, distFromCenter, dx, dy
end
