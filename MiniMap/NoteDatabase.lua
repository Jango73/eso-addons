NoteDatabase = {
    _data = nil,
    MAX_NOTES = 20,
}
NoteDatabase.__index = NoteDatabase

---Initialise the note database from saved variables.
---@param savedVars table The ZO_SavedVars table with a "data" key.
function NoteDatabase:Init(savedVars)
    self._metadata = savedVars
    if not self._metadata["data"] then
        self._metadata["data"] = {}
    end
    self._data = self._metadata["data"]
end

---Add a new note or update an existing one with the same name.
---@param name string Note name.
---@param content string Note content.
---@return boolean success True if the note was added or updated.
---@return boolean isNew True if a brand new note was created.
function NoteDatabase:AddNote(name, content)
    if not self._data then
        return false
    end

    local existingIndex = self:FindNoteByName(name)
    if existingIndex then
        self._data[existingIndex].content = content or ""
        self._data[existingIndex].ts = GetTimeStamp()
        return true, false
    end

    if #self._data >= self.MAX_NOTES then
        return false, false
    end

    table.insert(self._data, {
        name = name,
        content = content or "",
        ts = GetTimeStamp(),
    })
    return true, true
end

---Find a note index by its name.
---@param name string The note name to search for.
---@return number|nil The 1-based index, or nil if not found.
function NoteDatabase:FindNoteByName(name)
    if not self._data or not name then
        return nil
    end
    for i, note in ipairs(self._data) do
        if note.name == name then
            return i
        end
    end
    return nil
end

---Get a note by its numeric index.
---@param index number 1-based index.
---@return table|nil The note table {name, content, ts}, or nil.
function NoteDatabase:GetNote(index)
    if not self._data or not index then
        return nil
    end
    return self._data[index]
end

---Get a note by its name.
---@param name string Note name.
---@return table|nil The note table, or nil.
function NoteDatabase:GetNoteByName(name)
    local index = self:FindNoteByName(name)
    if index then
        return self._data[index]
    end
    return nil
end

---Get all notes.
---@return table List of note tables {name, content, ts}.
function NoteDatabase:GetAllNotes()
    return self._data or {}
end

---Get the total number of stored notes.
---@return number Note count.
function NoteDatabase:GetNoteCount()
    return self._data and #self._data or 0
end

---Delete a note by its numeric index.
---@param index number 1-based index.
---@return boolean True if the note was deleted.
function NoteDatabase:DeleteNote(index)
    if not self._data or not index then
        return false
    end
    if index < 1 or index > #self._data then
        return false
    end
    table.remove(self._data, index)
    return true
end

---Delete a note by its name.
---@param name string Note name.
---@return boolean True if a note was found and deleted.
function NoteDatabase:DeleteNoteByName(name)
    local index = self:FindNoteByName(name)
    if index then
        return self:DeleteNote(index)
    end
    return false
end

---Remove all notes from the database.
function NoteDatabase:Clear()
    if not self._data then
        return
    end
    for i = #self._data, 1, -1 do
        table.remove(self._data, i)
    end
end

return NoteDatabase