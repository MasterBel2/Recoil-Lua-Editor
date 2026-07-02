local math_max = math.max
local string_sub = string.sub

local lexer = VFS.Include("LuaUI/Widgets/Lua File Editor/Include/lexer.lua")
local lex = lexer.lex
local TOKEN_TYPE_WHITESPACE = lexer.TOKEN_TYPE.WHITESPACE

local tokenTypeColors = {
    [lexer.TOKEN_TYPE.STRING_LITERAL] = "\255\001\170\085",
    [lexer.TOKEN_TYPE.MULTILINE_STRING_LITERAL] = "\255\001\170\085",
    [lexer.TOKEN_TYPE.COMMENT] = "\255\085\085\085",
    [lexer.TOKEN_TYPE.MULTILINE_COMMENT] = "\255\085\085\085",
    [lexer.TOKEN_TYPE.NUMBER_LITERAL] = "\255\001\085\170",
    [lexer.TOKEN_TYPE.KEYWORD] = "\255\170\001\085",
    [lexer.TOKEN_TYPE.ATTRIBUTE] = "\255\255\170\085",
}

function WG.LuaTextEntry(framework, content, placeholderText, saveFunc)
    local monospaceFont = framework:Font("fonts/monospaced/SourceCodePro-Medium.otf", 12)
    local textEntry = framework:TextEntry(content, placeholderText, nil, monospaceFont)
    textEntry.saveFunc = saveFunc

    function textEntry:SetPostEditEffect(postEditEffect)
        local function ReplaceEditFunction(name)
            local cachedFunction = textEntry[name]
            textEntry[name] = function(...)
                cachedFunction(...)
                postEditEffect()
            end
        end
        ReplaceEditFunction("InsertText")
        ReplaceEditFunction("editUndo")
        ReplaceEditFunction("editRedo")
        ReplaceEditFunction("editBackspace")
        ReplaceEditFunction("editDelete")
    end

    local textEntry_KeyPress = textEntry.KeyPress
    function textEntry:KeyPress(key, mods, isRepeat)
        if key == 0x73 and mods.ctrl then 
            saveFunc()
        elseif key == 0x09 then
            self:editTab()
        end

        return textEntry_KeyPress(self, key, mods, isRepeat)
    end

    function textEntry:editTab()
        local rawString = textEntry.text:GetRawString()
        local _, _, spaces = rawString:find("\n([ \t]+)[^\n^ ^\t]")
        self:InsertText(spaces or "    ")
    end

    function textEntry:editReturn(isCtrl)
        if isCtrl then
            self:InsertText("\n")
            return
        end

        local rawString = textEntry.text:GetRawString()
        local clipped = rawString:sub(1, self.selectionBegin)
        while true do
            local lineStart, _, spaces, text = clipped:find("\n([ \t]*)([^\n]*)$")
            
            if not lineStart then
                local spaces, text = clipped:match("^([ \t]*)([^\n]*)$")
                self:InsertText("\n" .. spaces)
                return
            end

            if text:len() > 0 then
                self:InsertText("\n" .. spaces)
                return
            else
                clipped = rawString:sub(1, lineStart - 1)
            end
        end
    end

    local text_Layout = textEntry.text.Layout
    local text_Position = textEntry.text.Position

    local textHeight
    local codeNumbersWidth
    local spacing = framework:AutoScalingDimension(2)
    local codeNumbersColor = framework:Color(0.2, 0.2, 0.2, 1)

    local textEntryWidth = 0
    
    local displayString

    local lineTitles = {}
    local lineOffsets = {}
    textEntry.lineOffsets = lineOffsets
    local lineStarts, lineEnds
    local lineCount

    local lineHeight
    local oldLineHeight

    function textEntry.text:Layout(availableWidth, availableHeight)
        -- framework.startProfile("wrappingText:Layout() - custom layout: update line title widths")
        lineStarts, lineEnds = self:GetRawString():lines_MasterFramework()
        lineHeight = monospaceFont:ScaledSize()

        self.availableWidth = availableWidth
        self.availableHeight = availableHeight

        local oldLineCount
        lineCount = #lineStarts
        
        codeNumbersWidth = 0

        if lineCount ~= oldLineCount or oldLineHeight ~= lineHeight then
            oldLineHeight = lineHeight
            for i = 1, lineCount do
                local lineTitleWidth
                local lineTitle = lineTitles[i]
                if not lineTitles[i] then
                    lineTitle = framework:Text(tostring(i), codeNumbersColor, monospaceFont)
                    lineTitleWidth, _ = lineTitle:Layout(math.huge, math.huge)
                    lineTitles[i] = lineTitle
                else
                    lineTitleWidth, _ = lineTitle:Layout(math.huge, math.huge)
                end

                codeNumbersWidth = math_max(lineTitleWidth, codeNumbersWidth)
            end

            for i = lineCount + 1, #lineTitles do
                lineTitles[i] = nil
            end
        end
        -- framework.endProfile("wrappingText:Layout() - custom layout: update line title widths") -- negligible apart from first run

        local width, height = text_Layout(self, availableWidth - codeNumbersWidth - spacing(), availableHeight)

        -- framework.startProfile("wrappingText:Layout() - custom layout: record added newlines")

        textHeight = height
        textEntryWidth = width + codeNumbersWidth

        displayString = self:GetDisplayString()

        local insertedNewlineCount = 0
        local addedCharactersIndex = 1
        local removedSpacesIndex = 1
        local computedOffset = 0

        local addedCharacters = self.addedCharacters
        local string_sub = displayString.sub
        for i = 1, lineCount do
            local lineStartDisplayIndex, _addedCharactersIndex, _removedSpacesIndex, _computedOffset = self:RawIndexToDisplayIndex(lineStarts[i], addedCharactersIndex, removedSpacesIndex, computedOffset)
            for i = addedCharactersIndex, _addedCharactersIndex do
                local index = addedCharacters[i]
                if string_sub(displayString, index, index) == "\n" then
                    insertedNewlineCount = insertedNewlineCount + 1
                end
            end
            addedCharactersIndex = _addedCharactersIndex
            removedSpacesIndex = _removedSpacesIndex
            computedOffset = _computedOffset

            lineOffsets[i] = i + insertedNewlineCount
            lineTitles[i]._insertedNewlineCount = insertedNewlineCount
        end

        -- framework.endProfile("wrappingText:Layout() - custom layout: record added newlines")

        return textEntryWidth, height
    end
    local placeholder_Layout = textEntry.placeholder.Layout
    function textEntry.placeholder:Layout(availableWidth, availableHeight)
        local width, height = placeholder_Layout(self, availableWidth - codeNumbersWidth - spacing(), availableHeight)
        return width + codeNumbersWidth + spacing(), height
    end
    local placeholder_Position = textEntry.placeholder.Position
    function textEntry.placeholder:Position(x, y)
        placeholder_Position(self, x + codeNumbersWidth + spacing(), y)
    end
    function textEntry.text:Position(x, y)
        -- framework.startProfile("wrappingText:Position() - line numbers")
        local rightX = x + codeNumbersWidth
        local topY = y + textHeight
        for i = 1, lineCount do
            local lineTitle = lineTitles[i]
            local width, _ = lineTitle:Size()
            lineTitle:Position(rightX - width, topY - lineOffsets[i] * lineHeight)
        end
        -- framework.endProfile("wrappingText:Position() - line numbers")
        -- framework.startProfile("wrappingText:Position()")
        text_Position(self, rightX + spacing(), y)
        -- framework.endProfile("wrappingText:Position()")
    end
    
    function textEntry.text:ColoredString(string)
        local tokenCount, tokenTypes, tokenStartIndices, tokenEndIndices = lex(string)

        local stringComponents = {}
        local componentIndex = 1
        local characterIndex = 1
        local lastColor
        for tokenIndex = 1, tokenCount do
            local tokenType = tokenTypes[tokenIndex]
            if tokenType ~= TOKEN_TYPE_WHITESPACE then
                local color = tokenTypeColors[tokenType]
                if lastColor or color then
                    lastColor = color
                    stringComponents[componentIndex] = color or "\255\255\255\255"
                    componentIndex = componentIndex + 1
                end
                stringComponents[componentIndex] = string:sub(characterIndex, tokenEndIndices[tokenIndex])
                componentIndex = componentIndex + 1

                characterIndex = tokenEndIndices[tokenIndex] + 1
            end
        end
        stringComponents[componentIndex] = string:sub(characterIndex, string:len())

        return table.concat(stringComponents)
    end

    return textEntry
end