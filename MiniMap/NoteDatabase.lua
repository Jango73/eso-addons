NoteDatabase = {
    _data = nil,
    MAX_NOTES = 20,
}
NoteDatabase.__index = NoteDatabase

function NoteDatabase:Init(savedVars)
    self._metadata = savedVars
    if not self._metadata["data"] then
        self._metadata["data"] = {}
    end
    self._data = self._metadata["data"]
end

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

function NoteDatabase:GetNote(index)
    if not self._data or not index then
        return nil
    end
    return self._data[index]
end

function NoteDatabase:GetNoteByName(name)
    local index = self:FindNoteByName(name)
    if index then
        return self._data[index]
    end
    return nil
end

function NoteDatabase:GetAllNotes()
    return self._data or {}
end

function NoteDatabase:GetNoteCount()
    return self._data and #self._data or 0
end

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

function NoteDatabase:DeleteNoteByName(name)
    local index = self:FindNoteByName(name)
    if index then
        return self:DeleteNote(index)
    end
    return false
end

function NoteDatabase:Clear()
    if not self._data then
        return
    end
    for i = #self._data, 1, -1 do
        table.remove(self._data, i)
    end
end

return NoteDatabase