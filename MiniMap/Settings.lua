
DEFAULTS = {
    corner = 'bottomright',
    sizePercent = 22,
    orientation = 'north',
    zoom = 6,
    opacity = 100,
    debug = false,
    hidden = false,
    showResourceIndicators = true,
    autoSaveSpots = true,
    showToolbar = false,
}

CORNERS = {
    topleft = { anchor = TOPLEFT, relative = TOPLEFT, x = 24, y = 24 },
    topright = { anchor = TOPRIGHT, relative = TOPRIGHT, x = -24, y = 24 },
    bottomleft = { anchor = BOTTOMLEFT, relative = BOTTOMLEFT, x = 24, y = -24 },
    bottomright = { anchor = BOTTOMRIGHT, relative = BOTTOMRIGHT, x = -24, y = -24 },
    left = { anchor = LEFT, relative = LEFT, x = 24, y = 0 },
    right = { anchor = RIGHT, relative = RIGHT, x = -24, y = 0 },
    top = { anchor = TOP, relative = TOP, x = 0, y = 24 },
    bottom = { anchor = BOTTOM, relative = BOTTOM, x = 0, y = -24 },
}

STRINGS = {
    en = {
        helpCorner = '/minimap corner tl|tr|bl|br|left|right|top|bottom',
        helpSize = '/minimap size 10-40',
        helpOrientation = '/minimap orientation north|player',
        helpOpacity = '/minimap opacity 20-100',
        helpZoom = '/minimap zoom 2-8',
        helpVisibility = '/minimap hide | /minimap show',
        settingsMissing = 'LibAddonMenu-2.0 is missing: the settings menu will not be created.',
        positionName = 'Position',
        positionTooltip = 'Minimap position on the screen.',
        positionTopLeft = 'Top left',
        positionTopRight = 'Top right',
        positionBottomLeft = 'Bottom left',
        positionBottomRight = 'Bottom right',
        positionLeft = 'Center left',
        positionRight = 'Center right',
        positionTop = 'Top center',
        positionBottom = 'Bottom center',
        sizeName = 'Size',
        sizeTooltip = 'Percentage of the screen smallest dimension.',
        orientationName = 'Orientation',
        orientationTooltip = 'Choose whether north or the player direction stays at the top.',
        orientationNorth = 'North up',
        orientationPlayer = 'Player direction up',
        opacityName = 'Opacity',
        opacityTooltip = 'Minimap opacity.',
        invalidPosition = 'Invalid position. Use tl, tr, bl, br, left, right, top or bottom.',
        positionChanged = 'Position: %s',
        invalidSize = 'Invalid size. Example: /minimap size 22',
        sizeChanged = 'Size: %s%%',
        invalidOrientation = 'Invalid orientation. Use north or player.',
        orientationChanged = 'Orientation: %s',
        invalidOpacity = 'Invalid opacity. Example: /minimap opacity 80',
        opacityChanged = 'Opacity: %s%%',
        invalidZoom = 'Invalid zoom. Example: /minimap zoom 6',
        zoomChanged = 'Zoom: %s',
        hidden = 'Hidden.',
        shown = 'Shown.',
        autoSaveSpotsName = 'Auto save spots',
        autoSaveSpotsTooltip = 'Automatically save resource spots when loot is collected.',
        showToolbarName = 'Show toolbar',
        showToolbarTooltip = 'Show toolbar with buttons to manually add resource spots and delete spots.',
    },
    fr = {
        helpCorner = '/minimap corner tl|tr|bl|br|left|right|top|bottom',
        helpSize = '/minimap size 10-40',
        helpOrientation = '/minimap orientation north|player',
        helpOpacity = '/minimap opacity 20-100',
        helpZoom = '/minimap zoom 2-8',
        helpVisibility = '/minimap hide | /minimap show',
        settingsMissing = 'LibAddonMenu-2.0 est introuvable: le menu de settings ne sera pas cree.',
        positionName = 'Position',
        positionTooltip = 'Position de la minimap sur lecran.',
        positionTopLeft = 'Haut gauche',
        positionTopRight = 'Haut droite',
        positionBottomLeft = 'Bas gauche',
        positionBottomRight = 'Bas droite',
        positionLeft = 'Centre gauche',
        positionRight = 'Centre droite',
        positionTop = 'Centre haut',
        positionBottom = 'Centre bas',
        sizeName = 'Taille',
        sizeTooltip = 'Pourcentage de la plus petite dimension de lecran.',
        orientationName = 'Orientation',
        orientationTooltip = 'Choisit si le nord ou la direction du joueur reste en haut.',
        orientationNorth = 'Nord en haut',
        orientationPlayer = 'Direction du joueur en haut',
        opacityName = 'Transparence',
        opacityTooltip = 'Opacite de la minimap.',
        invalidPosition = 'Position invalide. Utilise tl, tr, bl, br, left, right, top ou bottom.',
        positionChanged = 'Position: %s',
        invalidSize = 'Taille invalide. Exemple: /minimap size 22',
        sizeChanged = 'Taille: %s%%',
        invalidOrientation = 'Orientation invalide. Utilise north ou player.',
        orientationChanged = 'Orientation: %s',
        invalidOpacity = 'Opacite invalide. Exemple: /minimap opacity 80',
        opacityChanged = 'Opacite: %s%%',
        invalidZoom = 'Zoom invalide. Exemple: /minimap zoom 6',
        zoomChanged = 'Zoom: %s',
        hidden = 'Masquee.',
        shown = 'Affichee.',
        autoSaveSpotsName = 'Sauvegarde auto des spots',
        autoSaveSpotsTooltip = 'Sauvegarder automatiquement les spots de ressources quand le butin est ramasse.',
        showToolbarName = 'Afficher la barre d\'outils',
        showToolbarTooltip = 'Afficher la barre d\'outils avec des boutons pour ajouter des spots de ressources manuellement et supprimer des spots.',
    },
}

local function GetLanguage()
    local language = GetCVar and GetCVar('Language.2') or nil
    language = zo_strlower(language or '')

    if string.sub(language, 1, 2) == 'fr' then
        return 'fr'
    end

    return 'en'
end

local function GetString(key)
    local strings = STRINGS[GetLanguage()] or STRINGS.en
    return strings[key] or STRINGS.en[key] or key
end