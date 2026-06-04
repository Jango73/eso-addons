
---Print a formatted MiniMap debug message.
---@param message string The message to print.
local function Print(message)
    if d then
        d("|c80d0ffMiniMap|r " .. message)
    end
end

---Initialize the minimap: load saved variables, set up spots/notes/route managers,
---create UI controls, apply layout, register events and settings menu.
function MiniMap:Initialize()
    ZO_CreateStringId("SI_BINDING_NAME_MINIMAP_CLOSEST_QUEST", "Activate Closest Quest")
    self.saved = ZO_SavedVars:NewAccountWide("MiniMapSavedVariables", 1, nil, DEFAULTS)

    self.spots = ZO_SavedVars:NewAccountWide("MiniMapSpots", 1, nil, {})
    SpotDatabase:Init(self.spots)

    self.notes = ZO_SavedVars:NewAccountWide("MiniMapNotes", 1, nil, {})
    NoteDatabase:Init(self.notes)

    self.routeManager = RouteManager
    self.routeManager:Init()

    self.language = Locale.GetLanguage()
    self:InvalidateResearchDuplicateCache("initialize")
    self:InstallResearchDuplicateOverlays()

    self:CreateControls()
    self:ApplyLayout()
    self:RefreshMapToPlayerLocation(true)
    self:RegisterSettingsMenu()

    SLASH_COMMANDS["/minimap"] = function(arguments)
        self:HandleSlashCommand(arguments)
    end

    local lastLootTargetType = nil
    local lastLootTargetName = nil

    local updateCounter = 0
    local lastMapOpen = false
    ---Periodic update callback: refresh map, player, quest indicators, and toolbar visibility.
    local function OnMinimapUpdate()
        if MiniMap.refreshRateDirty then
            MiniMap.refreshRateDirty = false
            EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME .. "Update")
            EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Update", MiniMap.saved.refreshRate or MINIMAP_REFRESH_MS, OnMinimapUpdate)
        end

        local sceneShown = MiniMap:IsWorldMapShowing()

        if not sceneShown then
            MiniMap:RefreshMapIfPlayerLocationChanged()
        end

        MiniMap:UpdatePlayer()
        MiniMap:UpdateQuestIndicatorWayshrine()

        if sceneShown then
            MiniMap.root:SetHidden(true)
            MiniMap:UpdateToolbarVisibility(false)
            if MiniMap.noteRenderer then MiniMap.noteRenderer:CloseEditor() end
            if MiniMap.noteRenderer and MiniMap.noteRenderer.notesPanel then MiniMap.noteRenderer.notesPanel:SetHidden(true) end
            lastMapOpen = true

            if MiniMap.worldMapOverlay and MiniMap.nearestQuestShortcutX then
                MiniMap.worldMapOverlay:Update(MiniMap.nearestQuestDestX, MiniMap.nearestQuestDestY)
            else
                MiniMap.worldMapOverlay:Hide()
            end
        elseif not MiniMap.saved.hidden then
            local isHudShowing = MiniMap:IsHudShowing()
            MiniMap:UpdateToolbarVisibility(isHudShowing)
            MiniMap.root:SetHidden(not isHudShowing)
            if MiniMap.noteRenderer and MiniMap.noteRenderer.notesPanel then
                local notesVisible = MiniMap.saved.showNotes and isHudShowing
                MiniMap.noteRenderer.notesPanel:SetHidden(not notesVisible)
            end
            if lastMapOpen then
                lastMapOpen = false
                MiniMap:RefreshMapToPlayerLocation(true)
            end
        end
    end

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "Update", self.saved.refreshRate or MINIMAP_REFRESH_MS, OnMinimapUpdate)

    ---Refresh the map to the player's current location, with a delayed follow-up.
    local function RefreshMapAfterLocationChange()
        MiniMap:RefreshMapToPlayerLocation(true)
        if zo_callLater then
            zo_callLater(function()
                MiniMap:RefreshMapToPlayerLocation(true)
                MiniMap:UpdatePlayer()
            end, 250)
        end
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_PLAYER_ACTIVATED", EVENT_PLAYER_ACTIVATED, RefreshMapAfterLocationChange)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_INVENTORY_SLOT_CHANGED", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
        MiniMap:InvalidateResearchDuplicateCache("EVENT_INVENTORY_SINGLE_SLOT_UPDATE")
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_BANK_OPEN", EVENT_OPEN_BANK, function()
        MiniMap:InvalidateResearchDuplicateCache("EVENT_OPEN_BANK")
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_BANK_CLOSE", EVENT_CLOSE_BANK, function()
        MiniMap:InvalidateResearchDuplicateCache("EVENT_CLOSE_BANK")
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_STORE_OPEN", EVENT_OPEN_STORE, function()
        MiniMap:InvalidateResearchDuplicateCache("EVENT_OPEN_STORE")
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_STORE_CLOSE", EVENT_CLOSE_STORE, function()
        MiniMap:InvalidateResearchDuplicateCache("EVENT_CLOSE_STORE")
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_ZONE_CHANGED", EVENT_ZONE_CHANGED, function()
        RefreshMapAfterLocationChange()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LOOT_UPDATED", EVENT_LOOT_UPDATED, function()
        local lootName, actionName, isOwned = GetLootTargetInfo()
        
        local isMonster = IsGameCameraInteractableUnitMonster()
        
        if lootName and lootName ~= "" then
            if isMonster then
                lastLootTargetType = "MONSTER"
            else
                lastLootTargetType = "OBJECT"
            end
            lastLootTargetName = lootName
        elseif isMonster then
            lastLootTargetType = "MONSTER"
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LOOT_CLOSED", EVENT_LOOT_CLOSED, function()
        lastLootTargetType = nil
        lastLootTargetName = nil
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_LOOT", EVENT_LOOT_RECEIVED, function(eventCode, characterName, itemName, quantity, lootType, lootedBySelf)
        if lastLootTargetType == "MONSTER" then
            return
        end

        local category = SpotDatabase:GetResourceCategory(lootType)
        if not category then
            return
        end

        local x, y = GetMapPlayerPosition("player")
        if x and y then
            SpotDatabase:SetCollectedTimestamp(x, y)
        end

        if not MiniMap.saved.autoSaveSpots then
            return
        end

        MiniMap:AddSpotAtPlayer(category)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_QUEST_COMPLETE", EVENT_QUEST_COMPLETE, function(eventCode, questName, level, prevExp, curExp, rank, prevPoints, curPoints)
        if not MiniMap.saved.autoActivateQuest then
            return
        end

        zo_callLater(function()
            MiniMap:ActivateClosestQuest()
        end, 2000)
    end)
end

---Wire up note editor UI button handlers (add, close, prev, next, delete, item list).
local function SetupNoteEvents()
    if not MiniMap.noteRenderer then
        return
    end

    local addBtn = MiniMap.noteRenderer:GetAddButton()
    if addBtn then
        addBtn:SetHandler("OnClicked", function()
            local count = NoteDatabase:GetNoteCount()
            if count >= NoteRenderer.MAX_NOTES then
                ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, "Maximum notes reached (" .. NoteRenderer.MAX_NOTES .. ")")
                return
            end
            local noteName = "Note " .. (count + 1)
            MiniMap.noteRenderer:AddNewNote(noteName, "")
            local noteCount = NoteDatabase:GetNoteCount()
            MiniMap.noteRenderer:ShowEditor(noteCount)
        end)
    end

    local closeBtn = MiniMap.noteRenderer:GetCloseButton()
    if closeBtn then
        closeBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:CloseEditor()
        end)
    end

    local prevBtn = MiniMap.noteRenderer:GetPrevButton()
    if prevBtn then
        prevBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:GoToPrevNote()
        end)
    end

    local nextBtn = MiniMap.noteRenderer:GetNextButton()
    if nextBtn then
        nextBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:GoToNextNote()
        end)
    end

    local deleteBtn = MiniMap.noteRenderer:GetDeleteButton()
    if deleteBtn then
        deleteBtn:SetHandler("OnClicked", function()
            MiniMap.noteRenderer:DeleteCurrentNote()
            local noteCount = NoteDatabase:GetNoteCount()
            MiniMap.noteRenderer:ApplyLayout(noteCount)
            MiniMap.noteRenderer:Update(noteCount)
        end)
    end

    local noteItems = MiniMap.noteRenderer:GetNoteItems()
    if noteItems then
        for i, item in ipairs(noteItems) do
            local btn = item.control
            if btn then
                btn:SetHandler("OnClicked", function()
                    if item.index > 0 then
                        MiniMap.noteRenderer:ShowEditor(item.index)
                    end
                end)
            end
        end
    end
end

---Entry point when the add-on is loaded: run initialization and note event setup.
---@param _ any Unused event code.
---@param addonName string The name of the loaded add-on.
local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    MiniMap:Initialize()
    SetupNoteEvents()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
