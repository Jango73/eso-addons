NoteRenderer = {
    owner = nil,
    MAX_NOTES = 20,
    MAX_VISIBLE = 3,
}
NoteRenderer.__index = NoteRenderer

local EDITOR_WIDTH = 500
local EDITOR_HEIGHT = 400
local NOTE_ITEM_HEIGHT = 28

local function SetCenterColor(control, color)
    control:SetCenterColor(color[1], color[2], color[3], color[4])
end

local function SetEdgeColor(control, color)
    control:SetEdgeColor(color[1], color[2], color[3], color[4])
end

local function GetRaisedEdgeColor(color)
    return {
        math.min(color[1] + 0.25, 1),
        math.min(color[2] + 0.25, 1),
        math.min(color[3] + 0.25, 1),
        1,
    }
end

local function NormalizeNoteTitle(title, fallback)
    title = title or ""
    if zo_strtrim then
        title = zo_strtrim(title)
    else
        title = title:match("^%s*(.-)%s*$") or ""
    end
    if title == "" then
        return fallback or "Note"
    end
    return title
end

function NoteRenderer:Init(owner)
    self.owner = owner
    self:CreateControls()
end

function NoteRenderer:CreateControls()
    local notesPanel = WINDOW_MANAGER:CreateTopLevelWindow("MiniMapNotesPanel")
    notesPanel:SetDrawTier(DT_HIGH)
    notesPanel:SetClampedToScreen(true)
    notesPanel:SetMouseEnabled(true)
    notesPanel:SetHidden(true)

    local notesBg = WINDOW_MANAGER:CreateControl("MiniMapNotesBg", notesPanel, CT_BACKDROP)
    notesBg:SetAnchorFill(notesPanel)
    SetCenterColor(notesBg, MINIMAP_NOTES_PANEL_COLOR)
    SetEdgeColor(notesBg, MINIMAP_ESO_BORDER_COLOR)
    notesBg:SetEdgeTexture("", 1, 1, 2)

    local addButton = WINDOW_MANAGER:CreateControl("MiniMapNotesAddBtn", notesPanel, CT_BUTTON)
    addButton:SetDimensions(24, 24)
    addButton:SetMouseOverTexture("EsoUI/Art/Buttons/left_up.dds")

    local addBg = WINDOW_MANAGER:CreateControl("MiniMapNotesAddBtnBg", addButton, CT_BACKDROP)
    addBg:SetAnchorFill(addButton)
    SetCenterColor(addBg, MINIMAP_NOTES_ADD_COLOR)
    SetEdgeColor(addBg, MINIMAP_NOTES_ADD_EDGE_COLOR)
    addBg:SetEdgeTexture("", 1, 1, 2)

    local addLabel = WINDOW_MANAGER:CreateControl("MiniMapNotesAddBtnLabel", addButton, CT_LABEL)
    addLabel:SetAnchor(CENTER, addButton, CENTER, 0, 0)
    addLabel:SetFont("ZoFontGameBold")
    addLabel:SetColor(1, 1, 1, 1)
    addLabel:SetText("+")

    local headerLabel = WINDOW_MANAGER:CreateControl("MiniMapNotesHeaderLabel", notesPanel, CT_LABEL)
    headerLabel:SetFont("ZoFontGameBold")
    headerLabel:SetColor(1, 1, 1, 1)
    headerLabel:SetText("Notes")

    local function CreateScrollButton(name, labelText)
        local button = WINDOW_MANAGER:CreateControl(name, notesPanel, CT_BUTTON)
        button:SetDimensions(24, 24)
        button:SetMouseOverTexture("EsoUI/Art/Buttons/left_up.dds")

        local bg = WINDOW_MANAGER:CreateControl(name .. "Bg", button, CT_BACKDROP)
        bg:SetAnchorFill(button)
        SetCenterColor(bg, MINIMAP_NOTES_CONTROL_COLOR)
        SetEdgeColor(bg, MINIMAP_NOTES_CONTROL_EDGE_COLOR)
        bg:SetEdgeTexture("", 1, 1, 2)

        local label = WINDOW_MANAGER:CreateControl(name .. "Label", button, CT_LABEL)
        label:SetAnchor(CENTER, button, CENTER, 0, 0)
        label:SetFont("ZoFontGameBold")
        label:SetColor(1, 1, 1, 1)
        label:SetText(labelText)

        return button
    end

    local scrollUpButton = CreateScrollButton("MiniMapNotesScrollUpBtn", "^")
    local scrollDownButton = CreateScrollButton("MiniMapNotesScrollDownBtn", "v")

    local notesList = WINDOW_MANAGER:CreateControl("MiniMapNotesList", notesPanel, CT_CONTROL)
    notesList:SetDrawLayer(DL_CONTROLS)

    self.notesPanel = notesPanel
    self.notesBg = notesBg
    self.addButton = addButton
    self.headerLabel = headerLabel
    self.scrollUpButton = scrollUpButton
    self.scrollDownButton = scrollDownButton
    self.notesList = notesList

    scrollUpButton:SetHandler("OnClicked", function()
        self:ScrollNotes(-1)
    end)
    scrollDownButton:SetHandler("OnClicked", function()
        self:ScrollNotes(1)
    end)

    self:CreateNoteItems()
    self:CreateEditor()
end

function NoteRenderer:CreateNoteItems()
    self.noteItems = {}
    for i = 1, self.MAX_VISIBLE do
        local item = WINDOW_MANAGER:CreateControl("MiniMapNotesItem" .. i, self.notesList, CT_BUTTON)
        item:SetDimensions(120, NOTE_ITEM_HEIGHT)
        item:SetMouseOverTexture("EsoUI/Art/Buttons/left_up.dds")

        local itemBg = WINDOW_MANAGER:CreateControl("MiniMapNotesItem" .. i .. "Bg", item, CT_BACKDROP)
        itemBg:SetAnchorFill(item)
        SetCenterColor(itemBg, MINIMAP_NOTES_ITEM_COLOR)
        SetEdgeColor(itemBg, MINIMAP_NOTES_ITEM_EDGE_COLOR)
        itemBg:SetEdgeTexture("", 1, 1, 1)

        local nameLabel = WINDOW_MANAGER:CreateControl("MiniMapNotesItem" .. i .. "Name", item, CT_LABEL)
        nameLabel:SetAnchor(CENTER, item, CENTER, 0, 0)
        nameLabel:SetFont("ZoFontGame")
        nameLabel:SetColor(1, 1, 1, 1)
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetText("")

        self.noteItems[i] = { control = item, label = nameLabel, index = 0 }
    end
end

function NoteRenderer:CreateEditor()
    local editor = WINDOW_MANAGER:CreateTopLevelWindow("MiniMapNotesEditor")
    editor:SetDrawTier(DT_HIGH)
    editor:SetClampedToScreen(true)
    editor:SetMouseEnabled(true)
    editor:SetHidden(true)

    local editorBg = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorBg", editor, CT_BACKDROP)
    editorBg:SetAnchorFill(editor)
    SetCenterColor(editorBg, MINIMAP_NOTES_EDITOR_COLOR)
    SetEdgeColor(editorBg, MINIMAP_ESO_BORDER_COLOR)
    editorBg:SetEdgeTexture("", 1, 1, 2)

    local titleEdit = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorTitle", editor, CT_EDITBOX)
    titleEdit:SetAnchor(TOP, editor, TOP, 0, 12)
    titleEdit:SetDimensions(EDITOR_WIDTH - 80, 32)
    titleEdit:SetMouseEnabled(true)
    titleEdit:SetFont("ZoFontHeader")
    titleEdit:SetColor(1, 1, 1, 1)
    titleEdit:SetMaxInputChars(80)
    if titleEdit.SetHorizontalAlignment then
        titleEdit:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end
    if titleEdit.SetEditEnabled then
        titleEdit:SetEditEnabled(true)
    end
    if titleEdit.SetTextType and TEXT_TYPE_ALL then
        titleEdit:SetTextType(TEXT_TYPE_ALL)
    end
    titleEdit:SetHandler("OnMouseUp", function(control)
        if control.TakeFocus then
            control:TakeFocus()
        end
    end)
    titleEdit:SetHandler("OnEscape", function()
        self:CloseEditor()
    end)

    local textArea = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorText", editor, CT_EDITBOX)
    textArea:SetAnchor(TOP, titleEdit, BOTTOM, 0, 12)
    textArea:SetDimensions(EDITOR_WIDTH - 40, EDITOR_HEIGHT - 120)
    textArea:SetMouseEnabled(true)
    textArea:SetFont("ZoFontGame")
    textArea:SetColor(1, 1, 1, 1)
    textArea:SetMaxInputChars(5000)
    if textArea.SetEditEnabled then
        textArea:SetEditEnabled(true)
    end
    if textArea.SetMultiLine then
        textArea:SetMultiLine(true)
    end
    if textArea.SetNewLineEnabled then
        textArea:SetNewLineEnabled(true)
    end
    if textArea.SetTextType and TEXT_TYPE_ALL then
        textArea:SetTextType(TEXT_TYPE_ALL)
    end
    textArea:SetHandler("OnMouseUp", function(control)
        if control.TakeFocus then
            control:TakeFocus()
        end
    end)
    textArea:SetHandler("OnEscape", function()
        self:CloseEditor()
    end)

    local btnWidth = 60
    local btnHeight = 28
    local btnSpacing = 10

    local closeBtn = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorClose", editor, CT_BUTTON)
    closeBtn:SetDimensions(btnHeight, btnHeight)
    local function StyleButton(btn, color)
        local btnBg = WINDOW_MANAGER:CreateControl(btn:GetName() .. "Bg", btn, CT_BACKDROP)
        btnBg:SetAnchorFill(btn)
        btnBg:SetDrawLayer(DL_BACKGROUND)
        SetCenterColor(btnBg, color)
        SetEdgeColor(btnBg, GetRaisedEdgeColor(color))
        btnBg:SetEdgeTexture("", 1, 1, 2)
        return btnBg
    end
    StyleButton(closeBtn, MINIMAP_NOTES_CLOSE_COLOR)
    local closeLabel = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorCloseLabel", closeBtn, CT_LABEL)
    closeLabel:SetAnchor(CENTER, closeBtn, CENTER, 0, 0)
    closeLabel:SetFont("ZoFontGame")
    closeLabel:SetColor(1, 1, 1, 1)
    closeLabel:SetText("X")

    local prevBtn = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorPrev", editor, CT_BUTTON)
    prevBtn:SetDimensions(btnWidth, btnHeight)
    StyleButton(prevBtn, MINIMAP_NOTES_NAV_COLOR)
    local prevLabel = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorPrevLabel", prevBtn, CT_LABEL)
    prevLabel:SetAnchor(CENTER, prevBtn, CENTER, 0, 0)
    prevLabel:SetFont("ZoFontGame")
    prevLabel:SetColor(1, 1, 1, 1)
    prevLabel:SetText("<")

    local nextBtn = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorNext", editor, CT_BUTTON)
    nextBtn:SetDimensions(btnWidth, btnHeight)
    StyleButton(nextBtn, MINIMAP_NOTES_NAV_COLOR)
    local nextLabel = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorNextLabel", nextBtn, CT_LABEL)
    nextLabel:SetAnchor(CENTER, nextBtn, CENTER, 0, 0)
    nextLabel:SetFont("ZoFontGame")
    nextLabel:SetColor(1, 1, 1, 1)
    nextLabel:SetText(">")

    local deleteBtn = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorDelete", editor, CT_BUTTON)
    deleteBtn:SetDimensions(btnWidth * 2, btnHeight)
    StyleButton(deleteBtn, MINIMAP_NOTES_DELETE_COLOR)
    local deleteLabel = WINDOW_MANAGER:CreateControl("MiniMapNotesEditorDeleteLabel", deleteBtn, CT_LABEL)
    deleteLabel:SetAnchor(CENTER, deleteBtn, CENTER, 0, 0)
    deleteLabel:SetFont("ZoFontGame")
    deleteLabel:SetColor(1, 1, 1, 1)
    deleteLabel:SetText("DELETE")

    self.editor = editor
    self.editorTitle = titleEdit
    self.editorText = textArea
    self.closeBtn = closeBtn
    self.prevBtn = prevBtn
    self.nextBtn = nextBtn
    self.deleteBtn = deleteBtn

    self.currentEditIndex = 0
    self.scrollOffset = 0
end

function NoteRenderer:ApplyLayout(noteCount)
    if not self.notesPanel then
        return
    end

    local showNotes = self.owner and self.owner.saved and self.owner.saved.showNotes
    local corner = self.owner and self.owner.saved and self.owner.saved.corner or "bottomright"

    local panelHeight = NOTE_ITEM_HEIGHT * self.MAX_VISIBLE + 46
    local panelWidth = (self.owner and self.owner.size or 130) * 0.8
    local panelPadding = 6

    self.notesPanel:ClearAnchors()
    local isTop = (corner == "topleft" or corner == "topright" or corner == "top")
    local isBottom = (corner == "bottomleft" or corner == "bottomright" or corner == "bottom")
    local isLeft = (corner == "left")
    local isRight = (corner == "right")

    if isTop or isLeft or isRight then
        self.notesPanel:SetAnchor(TOP, self.owner.root, BOTTOM, 0, 8)
    elseif isBottom then
        self.notesPanel:SetAnchor(BOTTOM, self.owner.root, TOP, 0, -8)
    else
        self.notesPanel:SetAnchor(TOP, self.owner.root, BOTTOM, 0, 8)
    end

    self.notesPanel:SetDimensions(panelWidth, panelHeight)

    self.addButton:ClearAnchors()
    self.addButton:SetAnchor(TOPLEFT, self.notesPanel, TOPLEFT, panelPadding, panelPadding)

    self.headerLabel:ClearAnchors()
    self.headerLabel:SetAnchor(LEFT, self.addButton, RIGHT, 8, 0)

    self.scrollDownButton:ClearAnchors()
    self.scrollDownButton:SetAnchor(TOPRIGHT, self.notesPanel, TOPRIGHT, -panelPadding, panelPadding)

    self.scrollUpButton:ClearAnchors()
    self.scrollUpButton:SetAnchor(RIGHT, self.scrollDownButton, LEFT, -4, 0)

    self.notesList:ClearAnchors()
    self.notesList:SetAnchor(TOPLEFT, self.addButton, BOTTOMLEFT, 0, 4)
    self.notesList:SetDimensions(panelWidth - (panelPadding * 2), NOTE_ITEM_HEIGHT * self.MAX_VISIBLE)

    for i, item in ipairs(self.noteItems) do
        item.control:ClearAnchors()
        item.control:SetDimensions(panelWidth - (panelPadding * 2), NOTE_ITEM_HEIGHT)
        if i == 1 then
            item.control:SetAnchor(TOPLEFT, self.notesList, TOPLEFT, 0, 0)
        else
            item.control:SetAnchor(TOPLEFT, self.noteItems[i - 1].control, BOTTOMLEFT, 0, 2)
        end
    end

    local visible = showNotes and (noteCount > 0 or self.owner.saved.showNotes)
    self.notesPanel:SetHidden(not visible)
    self.addButton:SetHidden(not visible)
    self.scrollUpButton:SetHidden(not visible or noteCount <= self.MAX_VISIBLE)
    self.scrollDownButton:SetHidden(not visible or noteCount <= self.MAX_VISIBLE)
end

function NoteRenderer:Update(noteCount)
    if not self.notesList or not self.noteItems then
        return
    end

    noteCount = noteCount or 0
    self.scrollOffset = math.max(0, math.min(self.scrollOffset, math.max(0, noteCount - self.MAX_VISIBLE)))

    local maxScroll = math.max(0, noteCount - self.MAX_VISIBLE)
    if self.scrollOffset > maxScroll then
        self.scrollOffset = maxScroll
    end
    if self.scrollUpButton then
        self.scrollUpButton:SetHidden(noteCount <= self.MAX_VISIBLE)
    end
    if self.scrollDownButton then
        self.scrollDownButton:SetHidden(noteCount <= self.MAX_VISIBLE)
    end

    local data = NoteDatabase:GetAllNotes() or {}
    local count = #data

    for i = 1, self.MAX_VISIBLE do
        local item = self.noteItems[i]
        local dataIndex = self.scrollOffset + i
        if dataIndex <= count then
            local note = data[dataIndex]
            item.label:SetText(note and note.name or "")
            item.index = dataIndex
            item.control:SetHidden(false)
        else
            item.label:SetText("")
            item.index = 0
            item.control:SetHidden(true)
        end
    end
end

function NoteRenderer:ScrollNotes(delta)
    local count = NoteDatabase:GetNoteCount()
    local maxScroll = math.max(0, count - self.MAX_VISIBLE)
    self.scrollOffset = MiniMapRenderUtils.Clamp((self.scrollOffset or 0) + delta, 0, maxScroll)
    self:Update(count)
end

function NoteRenderer:ShowEditor(index)
    local data = NoteDatabase:GetAllNotes() or {}
    if index < 1 or index > #data then
        return
    end

    self.currentEditIndex = index
    local note = data[index]
    if not note then
        return
    end

    self.editorTitle:SetText(note.name)
    self.editorText:SetText(note.content)

    local screenWidth, screenHeight = GuiRoot:GetDimensions()
    self.editor:ClearAnchors()
    self.editor:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    self.editor:SetDimensions(EDITOR_WIDTH, EDITOR_HEIGHT)

    self.closeBtn:ClearAnchors()
    self.closeBtn:SetAnchor(TOPRIGHT, self.editor, TOPRIGHT, -12, 12)

    self.deleteBtn:ClearAnchors()
    self.deleteBtn:SetAnchor(BOTTOMRIGHT, self.editor, BOTTOMRIGHT, -12, -12)

    self.prevBtn:ClearAnchors()
    self.prevBtn:SetAnchor(BOTTOMLEFT, self.editor, BOTTOMLEFT, 12, -12)

    self.nextBtn:ClearAnchors()
    self.nextBtn:SetAnchor(LEFT, self.prevBtn, RIGHT, 10, 0)

    self.editorTitle:ClearAnchors()
    self.editorTitle:SetAnchor(TOP, self.editor, TOP, 0, 12)
    self.editorTitle:SetDimensions(EDITOR_WIDTH - 80, 32)

    self.editorText:ClearAnchors()
    self.editorText:SetAnchor(TOP, self.editorTitle, BOTTOM, 0, 12)
    self.editorText:SetDimensions(EDITOR_WIDTH - 40, EDITOR_HEIGHT - 120)

    self.editor:SetHidden(false)
    if self.editorText.TakeFocus then
        self.editorText:TakeFocus()
    end
    if self.editorText.SetCursorPosition then
        self.editorText:SetCursorPosition(string.len(note.content or ""))
    end
end

function NoteRenderer:CloseEditor()
    if self.editorTitle and self.editorTitle.LoseFocus then
        self.editorTitle:LoseFocus()
    end
    if self.editorText and self.editorText.LoseFocus then
        self.editorText:LoseFocus()
    end

    if self.currentEditIndex > 0 then
        self:SaveCurrentNote()
    end

    if self.editor then
        self.editor:SetHidden(true)
    end

    self.currentEditIndex = 0
    self:Update(NoteDatabase:GetNoteCount())
end

function NoteRenderer:GoToNextNote()
    local count = NoteDatabase:GetNoteCount()
    if count == 0 then
        return
    end

    if self.currentEditIndex > 0 then
        self:SaveCurrentNote()
    end

    local newIndex = self.currentEditIndex + 1
    if newIndex > count then
        newIndex = 1
    end

    self:ShowEditor(newIndex)
end

function NoteRenderer:GoToPrevNote()
    local count = NoteDatabase:GetNoteCount()
    if count == 0 then
        return
    end

    if self.currentEditIndex > 0 then
        self:SaveCurrentNote()
    end

    local newIndex = self.currentEditIndex - 1
    if newIndex < 1 then
        newIndex = count
    end

    self:ShowEditor(newIndex)
end

function NoteRenderer:SaveCurrentNote()
    if self.currentEditIndex > 0 and self.editorText and self.editorTitle then
        local text = self.editorText:GetText()
        local title = self.editorTitle:GetText()
        local data = NoteDatabase:GetAllNotes()
        if data and data[self.currentEditIndex] then
            data[self.currentEditIndex].name = NormalizeNoteTitle(title, data[self.currentEditIndex].name)
            data[self.currentEditIndex].content = text or ""
            data[self.currentEditIndex].ts = GetTimeStamp()
        end
    end
end

function NoteRenderer:DeleteCurrentNote()
    if self.currentEditIndex > 0 then
        NoteDatabase:DeleteNote(self.currentEditIndex)
        self.currentEditIndex = 0
        if self.editorTitle and self.editorTitle.LoseFocus then
            self.editorTitle:LoseFocus()
        end
        if self.editorText and self.editorText.LoseFocus then
            self.editorText:LoseFocus()
        end
        self.editor:SetHidden(true)
    end
end

function NoteRenderer:AddNewNote(name, content)
    local added, isNew = NoteDatabase:AddNote(name, content)
    if added then
        local count = NoteDatabase:GetNoteCount()
        self:Update(count)
        self:ApplyLayout(count)
        if isNew then
            self.scrollOffset = math.max(0, count - self.MAX_VISIBLE)
        end
        self:Update(count)
    end
    return added
end

function NoteRenderer:GetAddButton()
    return self.addButton
end

function NoteRenderer:GetCloseButton()
    return self.closeBtn
end

function NoteRenderer:GetPrevButton()
    return self.prevBtn
end

function NoteRenderer:GetNextButton()
    return self.nextBtn
end

function NoteRenderer:GetDeleteButton()
    return self.deleteBtn
end

function NoteRenderer:GetNoteItems()
    return self.noteItems
end

return NoteRenderer
