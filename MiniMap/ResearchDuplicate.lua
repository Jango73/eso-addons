
local function Print(message)
    if d then
        d("|c80d0ffMiniMap|r " .. message)
    end
end

local function Echo(message)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage(message)
    end
end

local function IsCompanionArmorWithBadTrait(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false, nil, nil
    end

    if not GetItemFilterTypeInfo then
        return false, nil, nil
    end

    local filterTypes = { GetItemFilterTypeInfo(bagId, slotIndex) }
    local isCompanion = ZO_IsElementInNumericallyIndexedTable(filterTypes, ITEMFILTERTYPE_COMPANION)
    if not isCompanion then
        return false, nil, nil
    end

    local link = GetItemLink(bagId, slotIndex)
    if not link or link == "" then
        return false, nil, nil
    end

    local itemType = GetItemLinkItemType(link)
    if itemType ~= ITEMTYPE_ARMOR then
        return false, nil, nil
    end

    local armorType = GetItemLinkArmorType(link)
    if armorType ~= ARMORTYPE_LIGHT and armorType ~= ARMORTYPE_MEDIUM and armorType ~= ARMORTYPE_HEAVY then
        return false, nil, nil
    end

    local traitType = GetItemLinkTraitType(link)
    if not traitType then
        return false, nil, nil
    end

    local isTanking = COMPANION_TANKING_TRAITS[traitType]
    local isDamage = COMPANION_DAMAGE_TRAITS[traitType]

    if isTanking and isDamage then
        return false, nil, nil
    end

    if (armorType == ARMORTYPE_LIGHT or armorType == ARMORTYPE_MEDIUM) and isTanking then
        return true, traitType, armorType
    elseif armorType == ARMORTYPE_HEAVY and isDamage then
        return true, traitType, armorType
    end

    return false, nil, nil
end

local function IsPlayerArmorWithBadTrait(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false, nil
    end

    local link = GetItemLink(bagId, slotIndex)
    if not link or link == "" then
        return false, nil
    end

    local itemType = GetItemLinkItemType(link)
    if itemType ~= ITEMTYPE_ARMOR then
        return false, nil
    end

    local armorType = GetItemLinkArmorType(link)
    if armorType ~= ARMORTYPE_LIGHT and armorType ~= ARMORTYPE_MEDIUM and armorType ~= ARMORTYPE_HEAVY then
        return false, nil
    end

    if GetItemRequiredLevel and GetItemRequiredLevel(bagId, slotIndex) < 50 then
        return false, nil
    end

    local traitType = GetItemLinkTraitType(link)
    if not traitType then
        return false, nil
    end

    if PC_TANKING_TRAITS[traitType] and (armorType == ARMORTYPE_LIGHT or armorType == ARMORTYPE_MEDIUM) then
        return true, traitType
    end

    return false, nil
end

local function IsResearchDuplicateItemType(link)
    local itemType = GetItemLinkItemType(link)
    local equipType = GetItemLinkEquipType(link)
    local armorType = GetItemLinkArmorType(link)

    local isArmor = itemType == ITEMTYPE_ARMOR
        and (armorType == ARMORTYPE_LIGHT
            or armorType == ARMORTYPE_MEDIUM
            or armorType == ARMORTYPE_HEAVY)
    local isWeapon = itemType == ITEMTYPE_WEAPON
    local isJewelry = (itemType == ITEMTYPE_JEWELRY)
        or (equipType == EQUIP_TYPE_RING)
        or (equipType == EQUIP_TYPE_NECK)

    return isArmor or isWeapon or isJewelry
end

local function IsResearchDuplicateQualityEnabled(saved, quality)
    local superiorQuality = ITEM_QUALITY_SUPERIOR or 3
    local epicQuality = ITEM_QUALITY_EPIC or 4
    local legendaryQuality = ITEM_QUALITY_LEGENDARY or 5

    if quality == superiorQuality then
        return saved.researchIncludeSuperior ~= false
    elseif quality == epicQuality then
        return saved.researchIncludeEpic == true
    elseif quality == legendaryQuality then
        return saved.researchIncludeLegendary == true
    end

    return true
end

local function IsResearchableTraitType(traitType)
    if not traitType then
        return false
    end

    if traitType == ITEM_TRAIT_TYPE_NONE then
        return false
    end

    if traitType == ITEM_TRAIT_TYPE_ORNATE or traitType == ITEM_TRAIT_TYPE_INTRICATE then
        return false
    end

    return true
end

local function BuildResearchDuplicateGroups(saved, includeBank)
    local groups = {}
    local bags = { BAG_BACKPACK }

    if includeBank then
        table.insert(bags, BAG_BANK)
    end

    for _, bag in ipairs(bags) do
        local bagName = (bag == BAG_BANK) and "bank" or "backpack"
        local bagSize = GetBagSize and GetBagSize(bag) or 0
        for slot = 0, bagSize - 1 do
            local link = GetItemLink(bag, slot)
            if link and link ~= "" and IsResearchDuplicateItemType(link) then
                local quality = GetItemLinkQuality(link)
                local traitType = GetItemLinkTraitType(link)
                if IsResearchableTraitType(traitType) and IsResearchDuplicateQualityEnabled(saved, quality) then
                    local canBeResearched = true
                    if CanItemLinkBeTraitResearched then
                        canBeResearched = CanItemLinkBeTraitResearched(link)
                    end

                    if canBeResearched then
                        local name = GetItemLinkName(link)
                        local equipType = GetItemLinkEquipType(link)
                        local itemType = GetItemLinkItemType(link)
                        local uniqueId = GetItemUniqueId(bag, slot)

                        local key
                        if itemType == ITEMTYPE_WEAPON then
                            key = "w|" .. GetItemLinkWeaponType(link) .. "|" .. traitType
                        elseif equipType == EQUIP_TYPE_RING or equipType == EQUIP_TYPE_NECK then
                            key = "j|" .. equipType .. "|" .. traitType
                        else
                            key = "a|" .. GetItemLinkArmorType(link) .. "|" .. equipType .. "|" .. traitType
                        end

                        local group = groups[key]
                        if not group then
                            group = {
                                name = name,
                                traitType = traitType,
                                quality = quality,
                                count = 0,
                                slots = {},
                                itemNames = {},
                                keepSlot = nil,
                            }
                            groups[key] = group
                        end

                        local slotData = {
                            bag = bag,
                            slot = slot,
                            bagName = bagName,
                            name = name,
                            quality = quality,
                            uniqueId = uniqueId,
                        }

                        group.count = group.count + 1
                        table.insert(group.slots, slotData)
                        table.insert(group.itemNames, name)

                        if quality > group.quality then
                            group.quality = quality
                            group.name = name
                        end

                        if not group.keepSlot or quality > group.keepSlot.quality then
                            group.keepSlot = slotData
                        end
                    end
                end
            end
        end
    end

    return groups
end

local function BuildResearchDuplicateResults(saved, includeBank)
    local groups = BuildResearchDuplicateGroups(saved, includeBank)
    local dupes = {}
    local excessSlots = {}
    local keepSlots = {}
    local excessToKeepIds = {}
    local excessToKeepTraitTypes = {}
    local excessToKeepQualities = {}

    for _, data in pairs(groups) do
        if data.count > 1 then
            table.insert(dupes, data)
            if data.keepSlot and data.keepSlot.uniqueId then
                keepSlots[data.keepSlot.uniqueId] = true
            end
            for _, slotData in ipairs(data.slots) do
                local isKeepSlot = data.keepSlot
                    and slotData.uniqueId == data.keepSlot.uniqueId
                if not isKeepSlot and slotData.uniqueId then
                    excessSlots[slotData.uniqueId] = true
                    excessToKeepIds[slotData.uniqueId] = data.keepSlot.uniqueId
                    excessToKeepTraitTypes[slotData.uniqueId] = data.traitType
                    excessToKeepQualities[slotData.uniqueId] = data.quality
                end
            end
        end
    end

    table.sort(dupes, function(a, b) return a.count > b.count end)
    local excessCount = 0
    for _ in pairs(excessSlots) do
        excessCount = excessCount + 1
    end
    return dupes, excessSlots, keepSlots, excessToKeepIds, excessToKeepTraitTypes, excessToKeepQualities
end

local function GetSlotBagAndIndex(slotControl, slotData)
    if slotData and ZO_Inventory_GetBagAndIndex then
        local b, s = ZO_Inventory_GetBagAndIndex(slotData)
        if type(b) == "number" and type(s) == "number" then
            return b, s
        end
    end

    local data = slotData

    if not data and ZO_ScrollList_GetData then
        data = ZO_ScrollList_GetData(slotControl)
    end

    if data and data.dataEntry and data.dataEntry.data then
        data = data.dataEntry.data
    end

    if data and data.slotData then
        data = data.slotData
    end

    local bag = data and (data.bagId or data.bag)
    local slot = data and (data.slotIndex or data.slot)

    if bag == nil and slotControl then
        bag = slotControl.bagId or slotControl.bag
    end

    if slot == nil and slotControl then
        slot = slotControl.slotIndex or slotControl.slot
    end

    if type(bag) ~= "number" or type(slot) ~= "number" then
        return nil, nil
    end

    return bag, slot
end

local function GetSlotResearchIndicator(slotControl)
    if not slotControl or not slotControl.GetNamedChild then
        return nil
    end

    return slotControl:GetNamedChild("StatusIndicator")
        or slotControl:GetNamedChild("TraitInfo")
        or slotControl:GetNamedChild("ResearchIcon")
end

function MiniMap:InvalidateResearchDuplicateCache(reason)
    self._researchDuplicateCacheDirty = true
end

function MiniMap:RefreshResearchDuplicateOverlays()
    if not self._researchDuplicateSlotControls then
        return
    end
    for slotControl in pairs(self._researchDuplicateSlotControls) do
        if slotControl._researchDuplicateOverlay then
            self:UpdateResearchDuplicateSlotOverlay(slotControl, nil)
        end
    end
end

function MiniMap:IsResearchDuplicateExcessSlot(bagId, slotIndex)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_BANK then
        return false
    end

    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    if not uniqueId then
        return false
    end

    if self._researchDuplicateCacheDirty or not self._researchDuplicateExcessSlots then
        local _, excessSlots, keepSlots, excessToKeepIds, excessToKeepTraitTypes, excessToKeepQualities = BuildResearchDuplicateResults(self.saved, true)
        self._researchDuplicateExcessSlots = excessSlots
        self._researchDuplicateKeepSlots = keepSlots
        self._researchDuplicateExcessToKeepIds = excessToKeepIds
        self._researchDuplicateExcessToKeepTraitTypes = excessToKeepTraitTypes
        self._researchDuplicateExcessToKeepQualities = excessToKeepQualities
        self._researchDuplicateCacheDirty = false
    end

    if self._researchDuplicateKeepSlots[uniqueId] then
        return false
    end

    return self._researchDuplicateExcessSlots[uniqueId] or false
end

function MiniMap:GetResearchDuplicateKeepItemName(bagId, slotIndex)
    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    if not uniqueId then
        return nil
    end

    if self._researchDuplicateCacheDirty or not self._researchDuplicateExcessToKeepIds then
        self:IsResearchDuplicateExcessSlot(bagId, slotIndex)
    end

    local keepId = self._researchDuplicateExcessToKeepIds and self._researchDuplicateExcessToKeepIds[uniqueId]
    if keepId then
        local traitType = self._researchDuplicateExcessToKeepTraitTypes and self._researchDuplicateExcessToKeepTraitTypes[uniqueId]
        for _, searchBag in ipairs({ BAG_BACKPACK, BAG_BANK }) do
            local searchBagSize = GetBagSize and GetBagSize(searchBag) or 0
            for searchSlot = 0, searchBagSize - 1 do
                if GetItemUniqueId(searchBag, searchSlot) == keepId then
                    local keepName = GetItemName(searchBag, searchSlot)
                    if traitType then
                        return keepName .. " (" .. Locale.GetTraitName(traitType) .. ")"
                    end
                    return keepName
                end
            end
        end
    end
    return nil
end

function MiniMap:UpdateResearchDuplicateSlotOverlay(slotControl, slotData)
    if not slotControl then
        return
    end

    if not self._researchDuplicateSlotControls then
        self._researchDuplicateSlotControls = {}
    end
    self._researchDuplicateSlotControls[slotControl] = true

    local researchIndicator = GetSlotResearchIndicator(slotControl)
    local overlay = slotControl._researchDuplicateOverlay
    local keepLabel = slotControl._researchDuplicateKeepLabel
    local bagId, slotIndex = GetSlotBagAndIndex(slotControl, slotData)
    local hasCompanionBadTrait, companionTraitType, companionArmorType = IsCompanionArmorWithBadTrait(bagId, slotIndex)
    local hasPlayerBadTrait, playerTraitType = IsPlayerArmorWithBadTrait(bagId, slotIndex)
    local isBadArmor = hasCompanionBadTrait or hasPlayerBadTrait

    if bagId ~= nil and slotIndex ~= nil and isBadArmor then
        local link = GetItemLink(bagId, slotIndex)
        if link and link ~= "" and IsResearchDuplicateItemType(link) then
            local researchExcess = self:IsResearchDuplicateExcessSlot(bagId, slotIndex)
            if not researchExcess then
                hasCompanionBadTrait = false
                hasPlayerBadTrait = false
                isBadArmor = false
            end
        end
    end

    if not researchIndicator then
        local anchorTarget = slotControl:GetNamedChild("Icon")
        if not anchorTarget then
            anchorTarget = slotControl
        end

        if not overlay then
            overlay = WINDOW_MANAGER:CreateControl(nil, slotControl, CT_LABEL)
            overlay:SetFont("ZoFontGameLargeBold")
            overlay:SetText("X")
            overlay:SetColor(1, 0.1, 0.1, 1)
            overlay:SetDrawLayer(DL_OVERLAY)
            overlay:SetDrawLevel(20)
            slotControl._researchDuplicateOverlay = overlay
        end

        if not keepLabel then
            keepLabel = WINDOW_MANAGER:CreateControl(nil, slotControl, CT_LABEL)
            keepLabel:SetFont("ZoFontGameSmall")
            keepLabel:SetDrawLayer(DL_OVERLAY)
            keepLabel:SetDrawLevel(50)
            keepLabel:SetWidth(200)
            keepLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            keepLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
            slotControl._researchDuplicateKeepLabel = keepLabel
        end

        overlay:ClearAnchors()
        overlay:SetAnchor(CENTER, anchorTarget, CENTER, 0, 0)
        overlay:SetDrawLevel(50)

        local researchExcessFallback = bagId ~= nil and slotIndex ~= nil and self:IsResearchDuplicateExcessSlot(bagId, slotIndex)
        local showDuplicates = self.saved.researchShowDuplicates ~= false
        local showBadTrait = self.saved.researchShowBadTrait ~= false
        local shouldShowFallback = (researchExcessFallback and showDuplicates) or (isBadArmor and showBadTrait)
        overlay:SetHidden(not shouldShowFallback)

        if shouldShowFallback then
            keepLabel:ClearAnchors()
            local iconControl = slotControl:GetNamedChild("Icon")
            if iconControl then
                keepLabel:SetAnchor(TOPLEFT, iconControl, BOTTOMLEFT, 60, -8)
            else
                keepLabel:SetAnchor(TOPLEFT, slotControl, TOPLEFT, 60, -8)
            end

            if researchExcessFallback and showDuplicates then
                local keepName = self:GetResearchDuplicateKeepItemName(bagId, slotIndex)
                if keepName then
                    keepLabel:SetText(keepName)
                    self:ApplyResearchDuplicateKeepLabelColor(keepLabel, bagId, slotIndex)
                    keepLabel:SetHidden(false)
                else
                    keepLabel:SetHidden(true)
                end
            elseif hasCompanionBadTrait and showBadTrait then
                local traitName = Locale.GetTraitName(companionTraitType)
                keepLabel:SetText(self:Text("badTraitArmor"):format(traitName))
                keepLabel:SetColor(1, 0.1, 0.1, 1)
                keepLabel:SetHidden(false)
            elseif hasPlayerBadTrait and showBadTrait then
                local traitName = Locale.GetTraitName(playerTraitType)
                keepLabel:SetText(self:Text("badTraitArmor"):format(traitName))
                keepLabel:SetColor(1, 0.1, 0.1, 1)
                keepLabel:SetHidden(false)
            else
                keepLabel:SetHidden(true)
            end
        else
            keepLabel:SetHidden(true)
        end
        return
    end

    if not overlay then
        overlay = WINDOW_MANAGER:CreateControl(nil, slotControl, CT_LABEL)
        overlay:SetFont("ZoFontGameLargeBold")
        overlay:SetText("X")
        overlay:SetColor(1, 0.1, 0.1, 1)
        overlay:SetAnchor(CENTER, researchIndicator, CENTER, 0, 0)
        overlay:SetDrawLayer(DL_OVERLAY)
        overlay:SetDrawLevel(50)
        slotControl._researchDuplicateOverlay = overlay
    end

    if not keepLabel then
        keepLabel = WINDOW_MANAGER:CreateControl(nil, slotControl, CT_LABEL)
        keepLabel:SetFont("ZoFontGameSmall")
        keepLabel:SetDrawLayer(DL_OVERLAY)
        keepLabel:SetDrawLevel(50)
        keepLabel:SetWidth(200)
        keepLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        keepLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        slotControl._researchDuplicateKeepLabel = keepLabel
    end

    local researchExcess = bagId ~= nil and slotIndex ~= nil and self:IsResearchDuplicateExcessSlot(bagId, slotIndex)
    local showDuplicates = self.saved.researchShowDuplicates ~= false
    local showBadTrait = self.saved.researchShowBadTrait ~= false
    local shouldShow = (researchExcess and showDuplicates) or (isBadArmor and showBadTrait)
    if shouldShow and researchIndicator.IsHidden and researchIndicator:IsHidden() then
        shouldShow = false
    end

    overlay:SetHidden(not shouldShow)

    if shouldShow then
        keepLabel:ClearAnchors()
        local iconControl = slotControl:GetNamedChild("Icon")
        if iconControl then
            keepLabel:SetAnchor(TOPLEFT, iconControl, BOTTOMLEFT, 60, -8)
        else
            keepLabel:SetAnchor(TOPLEFT, slotControl, TOPLEFT, 60, -8)
        end

        if researchExcess and showDuplicates then
            local keepName = self:GetResearchDuplicateKeepItemName(bagId, slotIndex)
            if keepName then
                keepLabel:SetText(keepName)
                self:ApplyResearchDuplicateKeepLabelColor(keepLabel, bagId, slotIndex)
                keepLabel:SetHidden(false)
            else
                keepLabel:SetHidden(true)
            end
        elseif hasCompanionBadTrait and showBadTrait then
            local traitName = Locale.GetTraitName(companionTraitType)
            keepLabel:SetText(self:Text("badTraitArmor"):format(traitName))
            keepLabel:SetColor(1, 0.1, 0.1, 1)
            keepLabel:SetHidden(false)
        elseif hasPlayerBadTrait and showBadTrait then
            local traitName = Locale.GetTraitName(playerTraitType)
            keepLabel:SetText(self:Text("badTraitArmor"):format(traitName))
            keepLabel:SetColor(1, 0.1, 0.1, 1)
            keepLabel:SetHidden(false)
        else
            keepLabel:SetHidden(true)
        end
    else
        keepLabel:SetHidden(true)
    end
end

function MiniMap:ApplyResearchDuplicateKeepLabelColor(keepLabel, bagId, slotIndex)
    local uniqueId = GetItemUniqueId(bagId, slotIndex)
    if uniqueId and self._researchDuplicateExcessToKeepQualities then
        local quality = self._researchDuplicateExcessToKeepQualities[uniqueId]
        if quality then
            local color = GetItemQualityColor(quality)
            keepLabel:SetColor(color.r, color.g, color.b, color.a)
            return
        end
    end
    keepLabel:SetColor(0.2, 0.9, 0.2, 1)
end

function MiniMap:InstallResearchDuplicateOverlays()
    if self._researchDuplicateOverlaysInstalled then
        return
    end

    self._researchDuplicateOverlaysInstalled = true
    local hooked = false
    local hookTargets = {
        "ZO_Inventory_SetupSlot",
        "ZO_Inventory_SetupSingleSlot",
        "ZO_Inventory_SetupListVisualEntry",
        "ZO_InventorySlot_SetupSlot",
        "ZO_SharedInventorySlot_SetupSlot",
        "ZO_InventorySlot_Setup",
    }

    for _, functionName in ipairs(hookTargets) do
        if rawget(_G, functionName) then
            SecurePostHook(functionName, function(...)
                local slotControl = nil
                local slotData = nil
                for i = 1, select("#", ...) do
                    local argument = select(i, ...)
                    if not slotControl and argument and argument.GetNamedChild then
                        slotControl = argument
                    elseif not slotData and type(argument) == "table" then
                        slotData = argument
                    end
                end
                MiniMap:UpdateResearchDuplicateSlotOverlay(slotControl, slotData)
            end)
            hooked = true
        end
    end

    if not hooked and CHAT_ROUTER and CHAT_ROUTER.AddDebugMessage then
        CHAT_ROUTER:AddDebugMessage("[MiniMap] No compatible inventory slot setup hook found for research overlays")
    end
end

function MiniMap:ShowResearchDupes()
    local dupes = BuildResearchDuplicateResults(self.saved, true)

    if #dupes == 0 then
        Print(self:Text("noResearchDupes"))
        return
    end

    Print("--------------------")
    Print(string.format(self:Text("researchDupesFound"), #dupes))
    for _, data in ipairs(dupes) do
        local traitName = Locale.GetTraitName(data.traitType)
        local keepStr = data.name .. " (" .. traitName .. ")"
        local dupeCount = data.count - 1
        local junkNames = {}
        for _, n in ipairs(data.itemNames) do
            if n ~= data.name then
                table.insert(junkNames, n)
            end
        end
        local junkStr = table.concat(junkNames, ", ")
        if junkStr == "" then
            local fallbackName = (data.name and data.name ~= "") and data.name or "Unknown item"
            junkStr = string.format("%s x%d", fallbackName, dupeCount)
        end
        Print(string.format(self:Text("researchCanExcessLine"), junkStr, keepStr))
    end
end
