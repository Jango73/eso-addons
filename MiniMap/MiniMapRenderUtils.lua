MiniMapRenderUtils = {}

function MiniMapRenderUtils.Clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end

    return value
end

function MiniMapRenderUtils.GetRotationFromUp(dx, dy)
    if math.atan2 then
        return math.atan2(dx, dy)
    end

    return math.atan(dx, dy)
end

function MiniMapRenderUtils.RotateVector(x, y, radians)
    if radians == 0 then
        return x, y
    end

    local cos = math.cos(radians)
    local sin = math.sin(radians)
    return (x * cos) - (y * sin), (x * sin) + (y * cos)
end

function MiniMapRenderUtils.WorldToLocal(targetX, targetY, playerX, playerY, mapSize, mapRotation, center)
    local dx = (targetX - playerX) * mapSize
    local dy = (targetY - playerY) * mapSize
    dx, dy = MiniMapRenderUtils.RotateVector(dx, dy, mapRotation)
    local localX = center + dx
    local localY = center + dy
    local distFromCenter = math.sqrt((localX - center) ^ 2 + (localY - center) ^ 2)
    return localX, localY, distFromCenter, dx, dy
end
