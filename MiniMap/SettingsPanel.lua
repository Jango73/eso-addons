
---Print a formatted MiniMap debug message.
---@param message string The message to print.
local function Print(message)
    if d then
        d("|c80d0ffMiniMap|r " .. message)
    end
end

---Register the LibAddonMenu-2.0 settings panel and all option controls for the minimap.
function MiniMap:RegisterSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then
        Print(self:Text('settingsMissing'))
        return
    end

    local panelData = {
        type = 'panel',
        name = 'MiniMap',
        displayName = 'MiniMap',
        author = 'Jango73',
        version = '1.3.0',
        slashCommand = '/minimapsettings',
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable = {
        {
            type = 'dropdown',
            name = self:Text('orientationName'),
            tooltip = self:Text('orientationTooltip'),
            choices = { self:Text('orientationNorth'), self:Text('orientationPlayer') },
            choicesValues = { 'north', 'player' },
            getFunc = function()
                return self.saved.orientation
            end,
            setFunc = function(value)
                self.saved.orientation = value
                self:UpdatePlayer()
            end,
            default = DEFAULTS.orientation,
            width = 'full',
        },
        {
            type = 'dropdown',
            name = self:Text('positionName'),
            tooltip = self:Text('positionTooltip'),
            choices = {
                self:Text('positionTopLeft'),
                self:Text('positionTopRight'),
                self:Text('positionBottomLeft'),
                self:Text('positionBottomRight'),
                self:Text('positionLeft'),
                self:Text('positionRight'),
                self:Text('positionTop'),
                self:Text('positionBottom'),
            },
            choicesValues = {
                'topleft',
                'topright',
                'bottomleft',
                'bottomright',
                'left',
                'right',
                'top',
                'bottom',
            },
            getFunc = function()
                return self.saved.corner
            end,
            setFunc = function(value)
                self.saved.corner = value
                self:ApplyLayout()
            end,
            default = DEFAULTS.corner,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('sizeName'),
            tooltip = self:Text('sizeTooltip'),
            min = MINIMAP_SIZE_PERCENT_MIN,
            max = MINIMAP_SIZE_PERCENT_MAX,
            step = 1,
            getFunc = function()
                return self.saved.sizePercent
            end,
            setFunc = function(value)
                self.saved.sizePercent = MiniMapRenderUtils.Clamp(value, MINIMAP_SIZE_PERCENT_MIN, MINIMAP_SIZE_PERCENT_MAX)
                self:ApplyLayout()
            end,
            default = DEFAULTS.sizePercent,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('zoomName'),
            tooltip = self:Text('zoomTooltip'),
            min = MINIMAP_ZOOM_MIN,
            max = MINIMAP_ZOOM_MAX,
            step = 1,
            getFunc = function()
                return self.saved.zoom or DEFAULTS.zoom
            end,
            setFunc = function(value)
                self.saved.zoom = MiniMapRenderUtils.Clamp(value, MINIMAP_ZOOM_MIN, MINIMAP_ZOOM_MAX)
                self:RefreshMap(true)
            end,
            default = DEFAULTS.zoom,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('opacityName'),
            tooltip = self:Text('opacityTooltip'),
            min = MINIMAP_OPACITY_MIN,
            max = MINIMAP_OPACITY_MAX,
            step = 5,
            getFunc = function()
                return self.saved.opacity or DEFAULTS.opacity
            end,
            setFunc = function(value)
                self.saved.opacity = MiniMapRenderUtils.Clamp(value, MINIMAP_OPACITY_MIN, MINIMAP_OPACITY_MAX)
                self.root:SetAlpha(self.saved.opacity / 100)
            end,
            default = DEFAULTS.opacity,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('refreshRateName'),
            tooltip = self:Text('refreshRateTooltip'),
            getFunc = function()
                return self.saved.refreshRate or DEFAULTS.refreshRate
            end,
            setFunc = function(value)
                self.saved.refreshRate = value
                self.refreshRateDirty = true
            end,
            min = 50,
            max = 1000,
            step = 100,
            default = DEFAULTS.refreshRate,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('autoSaveSpotsName'),
            tooltip = self:Text('autoSaveSpotsTooltip'),
            getFunc = function()
                return self.saved.autoSaveSpots
            end,
            setFunc = function(value)
                self.saved.autoSaveSpots = value
            end,
            default = DEFAULTS.autoSaveSpots,
            width = 'full',
        },
        {
            type = 'slider',
            name = self:Text('respawnTimeName'),
            tooltip = self:Text('respawnTimeTooltip'),
            min = 60,
            max = 3600,
            step = 60,
            getFunc = function()
                return self.saved.respawnTime or MINIMAP_DEFAULT_RESPAWN_TIME
            end,
            setFunc = function(value)
                self.saved.respawnTime = value
            end,
            default = MINIMAP_DEFAULT_RESPAWN_TIME,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('showToolbarName'),
            tooltip = self:Text('showToolbarTooltip'),
            getFunc = function()
                return self.saved.showToolbar
            end,
            setFunc = function(value)
                self.saved.showToolbar = value
                self:ApplyToolbarLayout()
                self:UpdateToolbarVisibility()
            end,
            default = DEFAULTS.showToolbar,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('showNotesName'),
            tooltip = self:Text('showNotesTooltip'),
            getFunc = function()
                return self.saved.showNotes
            end,
            setFunc = function(value)
                self.saved.showNotes = value
                self:ApplyLayout()
            end,
            default = DEFAULTS.showNotes,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('autoActivateQuestOnCompleteName'),
            tooltip = self:Text('autoActivateQuestOnCompleteTooltip'),
            getFunc = function()
                return self.saved.autoActivateQuestOnComplete
            end,
            setFunc = function(value)
                self.saved.autoActivateQuestOnComplete = value
            end,
            default = DEFAULTS.autoActivateQuestOnComplete,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('autoActivateQuestOnNewName'),
            tooltip = self:Text('autoActivateQuestOnNewTooltip'),
            getFunc = function()
                return self.saved.autoActivateQuestOnNew
            end,
            setFunc = function(value)
                self.saved.autoActivateQuestOnNew = value
            end,
            default = DEFAULTS.autoActivateQuestOnNew,
            width = 'full',
        },
        {
            type = 'header',
            name = self:Text('researchFiltersHeader'),
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchIncludeSuperiorName'),
            tooltip = self:Text('researchIncludeSuperiorTooltip'),
            getFunc = function()
                return self.saved.researchIncludeSuperior ~= false
            end,
            setFunc = function(value)
                self.saved.researchIncludeSuperior = value
                self:InvalidateResearchDuplicateCache("settings.researchIncludeSuperior")
                self:RefreshResearchDuplicateOverlays()
            end,
            default = DEFAULTS.researchIncludeSuperior,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchIncludeEpicName'),
            tooltip = self:Text('researchIncludeEpicTooltip'),
            getFunc = function()
                return self.saved.researchIncludeEpic == true
            end,
            setFunc = function(value)
                self.saved.researchIncludeEpic = value
                self:InvalidateResearchDuplicateCache("settings.researchIncludeEpic")
                self:RefreshResearchDuplicateOverlays()
            end,
            default = DEFAULTS.researchIncludeEpic,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchIncludeLegendaryName'),
            tooltip = self:Text('researchIncludeLegendaryTooltip'),
            getFunc = function()
                return self.saved.researchIncludeLegendary == true
            end,
            setFunc = function(value)
                self.saved.researchIncludeLegendary = value
                self:InvalidateResearchDuplicateCache("settings.researchIncludeLegendary")
                self:RefreshResearchDuplicateOverlays()
            end,
            default = DEFAULTS.researchIncludeLegendary,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchShowDuplicatesName'),
            tooltip = self:Text('researchShowDuplicatesTooltip'),
            getFunc = function()
                return self.saved.researchShowDuplicates ~= false
            end,
            setFunc = function(value)
                self.saved.researchShowDuplicates = value
                self:RefreshResearchDuplicateOverlays()
            end,
            default = DEFAULTS.researchShowDuplicates,
            width = 'full',
        },
        {
            type = 'checkbox',
            name = self:Text('researchShowBadTraitName'),
            tooltip = self:Text('researchShowBadTraitTooltip'),
            getFunc = function()
                return self.saved.researchShowBadTrait ~= false
            end,
            setFunc = function(value)
                self.saved.researchShowBadTrait = value
                self:RefreshResearchDuplicateOverlays()
            end,
            default = DEFAULTS.researchShowBadTrait,
            width = 'full',
        },
        {
            type = 'header',
            name = self:Text('helpHeader'),
            width = 'full',
        },
        {
            type = 'description',
            text = self:Text('helpOverview') .. "\n\n"
                .. self:Text('helpResources') .. "\n\n"
                .. self:Text('helpRoutes') .. "\n\n"
                .. self:Text('helpNotes') .. "\n\n"
                .. self:Text('helpResearchSort') .. "\n\n"
                .. self:Text('helpCommandsTitle') .. "\n"
                .. self:Text('helpSettings') .. "\n"
                .. self:Text('helpVisibility') .. "\n"
                .. self:Text('helpRoute') .. "\n"
                .. self:Text('helpResearch'),
            width = 'full',
        },
    }

    LAM:RegisterAddonPanel('MiniMapSettings', panelData)
    LAM:RegisterOptionControls('MiniMapSettings', optionsTable)
end
