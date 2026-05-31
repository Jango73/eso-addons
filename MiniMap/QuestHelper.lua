
local function Print(message)
    if d then
        d("|c80d0ffMiniMap|r " .. message)
    end
end

function MiniMap:GetFocusedQuestIndex()
    if QUEST_JOURNAL_MANAGER and QUEST_JOURNAL_MANAGER.GetFocusedQuestIndex then
        local questIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
        if questIndex then
            return questIndex
        end
    end

    if GetNumTracked and GetTrackedByIndex and GetTrackedIsAssisted then
        local numTracked = GetNumTracked()
        for index = 1, numTracked do
            local trackType, arg1, arg2 = GetTrackedByIndex(index)
            if GetTrackedIsAssisted(trackType, arg1, arg2) then
                return arg1
            end
        end
    end

    return nil
end

function MiniMap:GetAllQuestTargetPositions()
    local questIndex = self:GetFocusedQuestIndex()
    if not questIndex or not WORLD_MAP_QUEST_BREADCRUMBS or not self.playerMapX or not self.playerMapY then
        return {}
    end

    local positions = {}
    local mainStepIndex = QUEST_MAIN_STEP_INDEX or 1
    local numSteps = GetJournalQuestNumSteps and GetJournalQuestNumSteps(questIndex) or mainStepIndex
    local px, py = self.playerMapX, self.playerMapY

    for stepIndex = mainStepIndex, numSteps do
        local numPositions = WORLD_MAP_QUEST_BREADCRUMBS:GetNumQuestConditionPositions(questIndex, stepIndex)
        if numPositions then
            for conditionIndex = 1, numPositions do
                local positionData = WORLD_MAP_QUEST_BREADCRUMBS:GetQuestConditionPosition(questIndex, stepIndex, conditionIndex)
                if positionData and positionData.insideCurrentMapWorld and positionData.xLoc and positionData.yLoc then
                    local dx = positionData.xLoc - px
                    local dy = positionData.yLoc - py
                    table.insert(positions, {
                        x = positionData.xLoc,
                        y = positionData.yLoc,
                        isBreadcrumb = positionData.isBreadcrumb,
                        distanceSq = (dx * dx) + (dy * dy),
                    })
                end
            end
        end
    end

    table.sort(positions, function(a, b)
        if a.isBreadcrumb ~= b.isBreadcrumb then
            return b.isBreadcrumb and true or false
        end
        return a.distanceSq < b.distanceSq
    end)

    if #positions == 0 then
        local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        if WORLD_MAP_QUEST_BREADCRUMBS.RefreshQuest and now >= self.nextQuestBreadcrumbRefreshMs then
            self.nextQuestBreadcrumbRefreshMs = now + 3000
            WORLD_MAP_QUEST_BREADCRUMBS:RefreshQuest(questIndex)
        end
    end

    return positions
end

function MiniMap:ActivateClosestQuest()
    local px, py = self.playerMapX, self.playerMapY
    if not px or not py then
        Print(self:Text("positionUnknown"))
        return
    end

    local closestDistSq = math.huge
    local closestQuestIndex = nil
    local closestQuestName = nil
    local maxQuests = MAX_JOURNAL_QUESTS or 25

    for questIndex = 1, maxQuests do
        if IsValidQuestIndex(questIndex) then
            local questName = GetJournalQuestName(questIndex)
            local questType = GetJournalQuestType and GetJournalQuestType(questIndex) or -1
            local breakLoop = false

            if not (GetJournalQuestType and questType == QUEST_TYPE_MAIN_STORY) then
                local mainStepIndex = QUEST_MAIN_STEP_INDEX or 1
                local numSteps = GetJournalQuestNumSteps and GetJournalQuestNumSteps(questIndex) or mainStepIndex

                for stepIndex = mainStepIndex, numSteps do
                    local numPositions = WORLD_MAP_QUEST_BREADCRUMBS:GetNumQuestConditionPositions(questIndex, stepIndex)

                    if numPositions then
                        for conditionIndex = 1, numPositions do
                            local positionData = WORLD_MAP_QUEST_BREADCRUMBS:GetQuestConditionPosition(questIndex, stepIndex, conditionIndex)

                            if positionData and positionData.insideCurrentMapWorld and positionData.xLoc and positionData.yLoc then

                                if stepIndex == 1 and positionData.teleportNPCId and positionData.teleportNPCId > 0 then
                                    breakLoop = true
                                    break
                                end

                                local dx = positionData.xLoc - px
                                local dy = positionData.yLoc - py
                                local distSq = dx * dx + dy * dy

                                if distSq < closestDistSq then
                                    closestDistSq = distSq
                                    closestQuestIndex = questIndex
                                    closestQuestName = questName
                                end
                            end
                        end
                    end

                    if breakLoop then
                        break
                    end
                end
            end
        end
    end

    if closestQuestIndex then
        if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.ForceAssist then
            FOCUSED_QUEST_TRACKER:ForceAssist(closestQuestIndex)
        elseif QUEST_TRACKER and QUEST_TRACKER.ForceAssist then
            QUEST_TRACKER:ForceAssist(closestQuestIndex)
        elseif SetMapQuestPinsTrackingLevel then
            SetMapQuestPinsTrackingLevel(closestQuestIndex, 2)
        end
        Print(string.format(self:Text("closestQuestActivated"), closestQuestName))
        return
    end

    local anyQuest = false
    for questIndex = 1, (MAX_JOURNAL_QUESTS or 25) do
        if IsValidQuestIndex(questIndex) then
            anyQuest = true
            break
        end
    end

    if not anyQuest then
        Print(self:Text("noQuestsFound"))
    else
        Print(self:Text("noQuestObjectivesFound"))
    end
end

function MiniMap:GetNearestWayshrinePosition()
    local px, py = self.playerMapX, self.playerMapY
    if not px or not py then
        return nil
    end
    return self:GetNearestWayshrineToPosition(px, py)
end

function MiniMap:GetNearestWayshrineToPosition(px, py)
    if not px or not py then
        return nil, nil, nil
    end

    local numNodes = GetNumFastTravelNodes()
    if not numNodes or numNodes == 0 then
        return nil, nil, nil
    end

    local nearestDist = math.huge
    local nearestX, nearestY

    for i = 1, numNodes do
        local known, name, x, y, icon, glowIcon, poiType, isShown, linkedLocked = GetFastTravelNodeInfo(i)
        if x and y and poiType == POI_TYPE_WAYSHRINE then
            local dx = x - px
            local dy = y - py
            local dist = dx * dx + dy * dy
            if dist < nearestDist then
                nearestDist = dist
                nearestX, nearestY = x, y
            end
        end
    end

    if nearestX then
        return nearestX, nearestY, math.sqrt(nearestDist)
    end
    return nil, nil, nil
end

function MiniMap:GetNearestKnownWayshrineToPosition(px, py)
    if not px or not py then
        return nil, nil, nil
    end

    local numNodes = GetNumFastTravelNodes()
    if not numNodes or numNodes == 0 then
        return nil, nil, nil
    end

    local nearestDist = math.huge
    local nearestX, nearestY

    for i = 1, numNodes do
        local known, name, x, y, icon, glowIcon, poiType, isShown, linkedLocked = GetFastTravelNodeInfo(i)
        if known and x and y and poiType == POI_TYPE_WAYSHRINE then
            local dx = x - px
            local dy = y - py
            local dist = dx * dx + dy * dy
            if dist < nearestDist then
                nearestDist = dist
                nearestX, nearestY = x, y
            end
        end
    end

    if nearestX then
        return nearestX, nearestY, math.sqrt(nearestDist)
    end
    return nil, nil, nil
end

function MiniMap:UpdateQuestIndicatorWayshrine()
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    if now < self.nextWayshrineRouteUpdateMs then
        return
    end
    self.nextWayshrineRouteUpdateMs = now + 1000

    local px, py = self.playerMapX, self.playerMapY
    local objectives = self:GetAllQuestTargetPositions()

    self.nearestQuestShortcutX = nil
    self.nearestQuestShortcutY = nil
    self.nearestQuestDestX = nil
    self.nearestQuestDestY = nil

    if #objectives == 0 or not px or not py then
        return
    end

    local nearest = objectives[1]
    local qx, qy = nearest.x, nearest.y

    local dxD = qx - px
    local dyD = qy - py
    local distD = math.sqrt(dxD * dxD + dyD * dyD)

    local wayshrinePlayerX, wayshrinePlayerY, distA = self:GetNearestWayshrineToPosition(px, py)
    if not wayshrinePlayerX then
        return
    end

    local wayshrineQuestX, wayshrineQuestY, distB = self:GetNearestKnownWayshrineToPosition(qx, qy)
    if not wayshrineQuestX then
        return
    end

    local sameWayshrine = (wayshrinePlayerX == wayshrineQuestX and wayshrinePlayerY == wayshrineQuestY)
    if not sameWayshrine and distA + distB < distD then
        self.nearestQuestShortcutX = wayshrinePlayerX
        self.nearestQuestShortcutY = wayshrinePlayerY
        self.nearestQuestDestX = wayshrineQuestX
        self.nearestQuestDestY = wayshrineQuestY
    end
end
