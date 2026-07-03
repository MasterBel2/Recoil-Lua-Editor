local MasterFramework

local function loadWidget(filename, environment)
    environment.Spring.Echo("Loading " .. filename .. "...")
    local path = "LuaUI/Widgets/" .. filename
    local file = VFS.LoadFile(path)
    local chunk, _error = loadstring(file, path)
    if not chunk or _error then
        error(_error)
    end

    local widget = {}
    setfenv(chunk, { Spring = environment.Spring, GL = environment.GL, gl = environment.gl, WG = environment.WG,
        widget = widget,
        widgetHandler = {},
        error = error,
        pairs = pairs,
        ipairs = ipairs,
        type = type,
        string = string,
        math = math,
        table = table,
        tostring = tostring,
        tonumber = tonumber,
        pcall = pcall,
        unpack = unpack,
        loadstring = loadstring,
        setfenv = setfenv,
        LUAUI_DIRNAME = LUAUI_DIRNAME,
        VFS = VFS,
        os = os
    })
    chunk()

    if widget.Initialize then
        widget:Initialize()
    end
end

local function prepare(widget)
    widget.gl.GetViewGeometry = function() return 1920, 1080 end

    loadWidget("gui_master_framework_39.lua", widget)
    -- loadWidget("gui_master_framework_extensions.lua", widget)
    loadWidget("gui_flowui.lua", widget)
    -- loadWidget("gui_master_framework_flowui_extensions.lua", widget)

    widget:Initialize()

    MasterFramework = widget.WG.MasterFramework[widget.getLocal_requiredFrameworkVersion()]
    MasterFramework.activeDrawingGroup = { drawTargets = {} }
end

return {
    targetFileName = "LuaUI/Widgets/gui_lua_file_editor.lua",

    test_testPreparation = function(widget)
        prepare(widget)
    end,

    test_whitespaceEnding = function(widget)
        prepare(widget)
        widget:Initialize()

        local coloredString = widget.getLocal_textEntry().text:ColoredString("end\n")
        local expectedString = "\255\255\001\255end\n"
        
        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n---\nGot:\n" .. coloredString .. "\n---")
        end
    end,

    test_coloredStringGeneration = function(widget)
        prepare(widget)
        widget:Initialize()

        local coloredString = widget.getLocal_textEntry().text:ColoredString("local keywords = {\n    [\"function\"] = true\n}")
        
        if coloredString ~= "\255\255\001\255local \255\255\100\001keywords \b= {\n    [\255\255\001\001\"function\"\b] = \255\255\001\255true\n\b}" then
            error("Expected:\n\255\255\001\255local \255\255\100\001keywords \b= {\n    [\255\255\001\001\"function\"\b] = \255\255\001\255true\n\b}\n\nGot:\n" .. coloredString)
        end
    end,

    test_coloredStringGeneration2 = function(widget)
        prepare(widget)
        widget:Initialize()

        local coloredString = widget.getLocal_textEntry().text:ColoredString("function widget:GetInfo()\n    return {\n        name = \"Lua File Editor\"\n    }\nend")
        local expectedString = "\255\255\001\255function \255\255\100\001widget\b:\255\255\100\001GetInfo\b()\n    \255\255\001\255return \b{\n        \255\255\100\001name \b= \255\255\001\001\"Lua File Editor\"\n    \b}\n\255\255\001\255end"
        
        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n---\nGot:\n" .. coloredString .. "\n---")
        end
    end,

    test_coloredStringGeneration3 = function(widget)
        prepare(widget)
        widget:Initialize()

        local coloredString = widget.getLocal_textEntry().text:ColoredString("local pairs = Include.pairs\nlocal ipairs = Include.ipairs\n")
        local expectedString = "\255\255\001\255local \255\255\100\001pairs \b= \255\255\100\001Include\b.\255\255\100\001pairs\n\255\255\001\255local \255\255\100\001ipairs \b= \255\255\100\001Include\b.\255\255\100\001ipairs\n"
        
        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n---\nGot:\n" .. coloredString .. "\n---")
        end
    end,

    test_coloredStringGeneration4 = function(widget)
        prepare(widget)
        widget:Initialize()

        local inputString = [[
    if (text)       then tSuccess = remove(self.textActions)       end
    if (keyPress)   then pSuccess = remove(self.keyPressActions)   end
    if (keyRepeat)  then RSuccess = remove(self.keyRepeatActions)  end
    if (keyRelease) then rSuccess = remove(self.KeyReleaseActions) end
]]

        local coloredString = widget.getLocal_textEntry().text:ColoredString([[
    if (text)       then tSuccess = remove(self.textActions)       end
    if (keyPress)   then pSuccess = remove(self.keyPressActions)   end
    if (keyRepeat)  then RSuccess = remove(self.keyRepeatActions)  end
    if (keyRelease) then rSuccess = remove(self.KeyReleaseActions) end
]])
        local expectedString =
"    \255\255\001\255if \b(\255\255\100\001text\b)       \255\255\001\255then \255\255\100\001tSuccess \b= \255\255\100\001remove\b(\255\255\100\001self\b.\255\255\100\001textActions\b)       \255\255\001\255end\n" ..
"    \255\255\001\255if \b(\255\255\100\001keyPress\b)   \255\255\001\255then \255\255\100\001pSuccess \b= \255\255\100\001remove\b(\255\255\100\001self\b.\255\255\100\001keyPressActions\b)   \255\255\001\255end\n" ..
"    \255\255\001\255if \b(\255\255\100\001keyRepeat\b)  \255\255\001\255then \255\255\100\001RSuccess \b= \255\255\100\001remove\b(\255\255\100\001self\b.\255\255\100\001keyRepeatActions\b)  \255\255\001\255end\n" ..
"    \255\255\001\255if \b(\255\255\100\001keyRelease\b) \255\255\001\255then \255\255\100\001rSuccess \b= \255\255\100\001remove\b(\255\255\100\001self\b.\255\255\100\001KeyReleaseActions\b) \255\255\001\255end\n"

        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n---\nGot:\n" .. coloredString .. "\n---")
        end

        local text = MasterFramework:WrappingText(inputString, nil, MasterFramework:Font("fonts/monospaced/SourceCodePro-Medium.otf", 12))
        local textGroup = MasterFramework:TextGroup(text)

        textGroup:Layout(468, 1024)
        textGroup:Position(0, 0)

        widget.Spring.Echo(text:GetRawString())
        widget.Spring.Echo(text:GetDisplayString())
    end,

    test_indexCalculationNoWrappingNoColorsNoLineBreaks = function(widget)
        prepare(widget)
        local string = "testing123"

        local text = MasterFramework:WrappingText(string)
        local textGroup = MasterFramework:TextGroup(text)
        local horizontalStack = MasterFramework:HorizontalStack({ textGroup }, MasterFramework:Dimension(8), 0)
       
        horizontalStack:Layout(100000, 10000000)
        horizontalStack:Position(0, 0)

        -- Spring.Echo(text:GetDisplayString())

        local rawString = text:GetRawString()
        local displayString = text:GetDisplayString()

        for rawIndex = 1, rawString:len() do
            local rawCharacter = rawString:sub(rawIndex, rawIndex) -- deliberately re-using rawIndex to force assumption of no inserted characterss
            local displayCharacter = displayString:sub(rawIndex, rawIndex)
            if rawCharacter ~= displayCharacter then
                error("rawCharacter \"" .. rawCharacter .. "\" does not match displayCharacter \"" .. displayCharacter .. "\" at rawIndex: " .. rawIndex .. ", displayIndex: " .. rawIndex)
            end
            if text:RawIndexToDisplayIndex(rawIndex) ~= rawIndex then
                error("rawIndex (" .. rawIndex .. ") does not match displayIndex (" .. displayIndex .. ")")
            end
        end
    end,

    test_indexCalculationNoWrappingNoColors_withLineBreaks = function(widget)
        prepare(widget)
        local string = VFS.LoadFile("LuaUI/Widgets/test.lua")

        local text = MasterFramework:WrappingText(string)
        local textGroup = MasterFramework:TextGroup(text)
       
        textGroup:Layout(100000, 10000000)
        textGroup:Position(0, 0)

        -- Spring.Echo(text:GetDisplayString())

        local rawString = text:GetRawString()
        local displayString = text:GetDisplayString()

        local rCount = 0

        for displayIndex = 1, displayString:len() do
            local displayCharacter = displayString:sub(displayIndex, displayIndex)

            local rawIndex = displayIndex - rCount
            local rawCharacter = rawString:sub(rawIndex, rawIndex)

            if displayCharacter == "\r" then
                rCount = rCount + 1
            elseif rawCharacter ~= displayCharacter then
                error("rawCharacter \"" .. rawCharacter .. "\" does not match displayCharacter \"" .. displayCharacter .. "\" at index: " .. rawIndex .. ", rCount: " .. rCount)
            end
        end

        if rawString:len() ~= displayString:len() - rCount then
            error("String lengths do not match when factoring in rCount (" .. rCount .. ")!\n\nRawString (" .. rawString:len() .. "):\n\n" .. rawString .."\n\nDisplayString (" .. displayString:len() .. "):\n\n" .. displayString)
        end
    end,

    test_selection_lineBreakEnd = function(widget)
        prepare(widget)
        local string = "\n"

        local text = MasterFramework:WrappingText(string)
        local textGroup = MasterFramework:TextGroup(text)
        textGroup:Layout(math.huge, math.huge)
        textGroup:Position(0, 0)

        text:CoordinateToCharacterDisplayIndex(0, 16)
    end,

    test_indexCalculation_lineBreakEnd = function(widget)
        prepare(widget)
        local string = "end\n"

        local text = MasterFramework:WrappingText(string)
        local textGroup = MasterFramework:TextGroup(text)
       
        textGroup:Layout(100000, 10000000)
        textGroup:Position(0, 0)

        -- Spring.Echo(text:GetDisplayString())

        local rawString = text:GetRawString()
        local displayString = text:GetDisplayString()

        local rCount = 0

        for displayIndex = 1, displayString:len() do
            local displayCharacter = displayString:sub(displayIndex, displayIndex)

            local rawIndex = displayIndex - rCount
            local rawCharacter = rawString:sub(rawIndex, rawIndex)

            if displayCharacter == "\r" then
                rCount = rCount + 1
            elseif rawCharacter ~= displayCharacter then
                error("rawCharacter \"" .. rawCharacter .. "\" does not match displayCharacter \"" .. displayCharacter .. "\" at index: " .. rawIndex .. ", rCount: " .. rCount)
            end
        end

        if rawString:len() ~= displayString:len() - rCount then
            error("String lengths do not match when factoring in rCount (" .. rCount .. ")!\n\nRawString (" .. rawString:len() .. "):\n\n" .. rawString .."\n\nDisplayString (" .. displayString:len() .. "):\n\n" .. displayString)
        end
    end,

    test_indexCalculation = function(widget)
        prepare(widget)
        local string = VFS.LoadFile("LuaUI/Widgets/test.lua")

        local text = MasterFramework:WrappingText(string)
        local textGroup = MasterFramework:TextGroup(text)
       
        textGroup:Layout(200, 10000000)
        textGroup:Position(0, 0)
        
        widget.Spring.Echo("Raw String:")
        widget.Spring.Echo(text:GetRawString())
        widget.Spring.Echo("Display String:")
        widget.Spring.Echo(text:GetDisplayString())

        -- widget.Spring.Echo("\n???:")

        -- widget.Spring.Echo(text:GetRawString():sub(text:RawIndexToDisplayIndex(text:GetRawString():len()), text:RawIndexToDisplayIndex(text:GetRawString():len())))
        -- widget.Spring.Echo("(end of ???)")
        -- widget.Spring.Echo("??? 2:")
        -- widget.Spring.Echo(text:GetRawString():sub(text:DisplayIndexToRawIndex(text:GetDisplayString():len()), text:DisplayIndexToRawIndex(text:GetDisplayString():len())))
        -- widget.Spring.Echo("(end of ??? 2)")
        -- widget.Spring.Echo("\n")

        -- if text:RawIndexToDisplayIndex(text:GetRawString():len()) ~= text:GetDisplayString():len() then
        --     error("RawIndexToDisplayIndex ".. text:RawIndexToDisplayIndex(text:GetRawString():len()) .. " does not match text:GetDisplayString():len() " .. text:GetDisplayString():len())
        -- end
        -- if text:DisplayIndexToRawIndex(text:GetDisplayString():len()) ~= text:GetRawString():len() then 
        --     error("DisplayIndexToRawIndex ".. text:DisplayIndexToRawIndex(text:GetDisplayString():len()) .. " does not match text:GetRawString():len() " .. text:GetRawString():len())
        -- end

        local rawString = text:GetRawString()
        local displayString = text:GetDisplayString()

        for rawIndex = 1, rawString:len() do
            local displayIndex, addedCharactersIndex, removedSpacesIndex, computedOffset, isInexactMatch = text:RawIndexToDisplayIndex(rawIndex)
            local rawCharacter = rawString:sub(rawIndex, rawIndex)
            local displayCharacter = displayString:sub(displayIndex, displayIndex)
            if rawCharacter ~= displayCharacter and not (rawCharacter == " ") then
                -- widget.Spring.Echo(text:RawIndexToDisplayIndex(rawIndex - 2))
                -- widget.Spring.Echo(text:RawIndexToDisplayIndex(rawIndex - 1))
                -- widget.Spring.Echo(displayString:sub(text:RawIndexToDisplayIndex(rawIndex - 2), text:RawIndexToDisplayIndex(rawIndex - 1)))
                -- widget.Spring.Echo("#text.addedCharacters: " .. #text.addedCharacters)
                -- for _, addedCharacterDisplayIndex in ipairs(text.addedCharacters) do
                --     local extraCharacter = displayString:sub(addedCharacterDisplayIndex, addedCharacterDisplayIndex)
                --     if extraCharacter == "\n" then extraCharacter = "\\n" elseif extraCharacter == "\r" then extraCharacter = "\\r" elseif extraCharacter == "\t" then extraCharacter = "\\t" end

                --     widget.Spring.Echo("Extra character \"" .. extraCharacter .. "\" at index " .. addedCharacterDisplayIndex)
                -- end

                -- widget.Spring.Echo(MasterFramework.debugDescriptionString(text.addedCharacters))
                widget.Spring.Echo(widget.table.concat(widget.table.imap(text.removedSpaces, function(_, character) return "(" .. character .. ")" end)))
                widget.Spring.Echo(widget.table.concat(widget.table.imap(text.addedCharacters, function(_, character) return "\"" .. displayString:sub(character, character) .. "\"" .. ", (" .. character .. ")" end)))
                error("Character \"" .. displayCharacter .. "\"  at display index " .. displayIndex .. " does not match character \"" .. rawCharacter .. "\" at rawIndex " .. rawIndex .. 
                      "\naddedCharactersIndex: " .. addedCharactersIndex - 1 .. ", added character index: " .. text.addedCharacters[addedCharactersIndex - 1] .. ", added character: " .. displayString:sub(text.addedCharacters[addedCharactersIndex], text.addedCharacters[addedCharactersIndex]) ..
                      ", removedSpacesIndex: " .. removedSpacesIndex - 1 .. ", removed space index: " .. text.removedSpaces[removedSpacesIndex - 1] .. ", computedOffset: " .. computedOffset ..
                      "\n----- Display string up to this point:\n\"" .. displayString:sub(1, displayIndex) .. "\"\n----- Raw string up to this point:\n\"" .. rawString:sub(1, rawIndex) .. "\"")
            end
        end

        for displayIndex = 1, displayString:len() do
            local rawIndex, inexactMatch = text:DisplayIndexToRawIndex(displayIndex)

            if not inexactMatch then
                local rawCharacter = rawString:sub(rawIndex, rawIndex)
                local displayCharacter = displayString:sub(displayIndex, displayIndex)
                if rawCharacter ~= displayCharacter then
                    Spring.Echo("rawString:len(): " .. rawString:len())
                    Spring.Echo("displayString:len(): " .. displayString:len())
                    -- widget.Spring.Echo(MasterFramework.debugDescriptionString(text.addedCharacters))
                    -- widget.Spring.Echo(MasterFramework.debugDescriptionString(text.removedSpaces))
                    error("Character \"" .. displayCharacter .. "\" at display index " .. displayIndex .. " does not match character \"" .. rawCharacter .. "\" at rawIndex " .. rawIndex .. "\nDisplay string up to this point:\n\"" .. displayString:sub(1, displayIndex) .. "\"\nRaw string up to this point:\n\"" .. rawString:sub(1, rawIndex) .. "\"")
                end
            end
        end
    end,

    test_indexCalculationWithTextColors = function(widget)
        prepare(widget)
        local string = "testing123asdjflkadsk\255\001\255\001jldfaskjadslktesting123"

        local text = MasterFramework:WrappingText(string)
        local textGroup = MasterFramework:TextGroup(text)
       
        textGroup:Layout(100, 1024)
        textGroup:Position(0, 0)
        widget.Spring.Echo("RawString    : " .. text:GetRawString())
        widget.Spring.Echo("DisplayString: " .. text:GetDisplayString())

        -- testing123asdjflk = 17 characters
        -- adsk\255\001\255\001jldfaskjadsl = 20 characters

        if text:GetDisplayString() ~= "testing123asdjflk\r\nadsk\255\001\255\001jldfaskjadslk\r\ntesting123" then
            error("DisplayString was \"" .. text:GetDisplayString() .. "\" not \"testing123asdjflk\r\nadsk\255\001\255\001jldfaskjadslk\r\ntesting123\"")
        end

        widget.Spring.Echo("RawIndex:" .. text:RawIndexToDisplayIndex(text:GetRawString():len()) .. ":" .. text:GetDisplayString():len() .. ":" .. text:GetRawString():len())
        widget.Spring.Echo("DisplayIndex:" .. text:DisplayIndexToRawIndex(text:GetDisplayString():len()) .. ":" .. text:GetRawString():len() .. ":" .. text:GetDisplayString():len())

        if text:RawIndexToDisplayIndex(text:GetRawString():len()) ~= text:GetDisplayString():len() then 
            error("" .. text:RawIndexToDisplayIndex(text:GetRawString():len()) .. ":" .. text:GetDisplayString():len() .. ":" .. text:GetRawString():len())
        end

        if text:DisplayIndexToRawIndex(text:GetDisplayString():len()) ~= text:GetRawString():len() then 
            error("" .. text:DisplayIndexToRawIndex(text:GetDisplayString():len()) .. ":" .. text:GetRawString():len() .. ":" .. text:GetDisplayString():len())
        end

        -- if text:CoordinateToCharacterRawIndex(100, 1020) ~= 17 then
        --     error("Expected coordinate to be 17, was " .. text:CoordinateToCharacterRawIndex(100, 1020))
        -- end
    end,

    test_indexCalculationWithTextColors2 = function(widget)
        prepare(widget)
        -- local string = VFS.LoadFile("LuaUI/Widgets/test.lua")

        local text = MasterFramework:WrappingText("testing123")
        local textGroup = MasterFramework:TextGroup(text)
       
        textGroup:Layout(200, 10000000)
        textGroup:Position(0, 0)

        -- Spring.Echo(text:GetDisplayString())

        widget.Spring.Echo("" .. text:RawIndexToDisplayIndex(text:GetRawString():len()) .. ":" .. text:GetDisplayString():len() .. ":" .. text:GetRawString():len())
        widget.Spring.Echo("" .. text:DisplayIndexToRawIndex(text:GetDisplayString():len()) .. ":" .. text:GetRawString():len() .. ":" .. text:GetDisplayString():len())

        if text:RawIndexToDisplayIndex(text:GetRawString():len()) ~= text:GetDisplayString():len() then
            error("RawIndexToDisplayIndex ".. text:RawIndexToDisplayIndex(text:GetRawString():len()) .. " does not match text:GetDisplayString():len() " .. text:GetDisplayString():len())
        end
        if text:DisplayIndexToRawIndex(text:GetDisplayString():len()) ~= text:GetRawString():len() then 
            error("DisplayIndexToRawIndex ".. text:DisplayIndexToRawIndex(text:GetDisplayString():len()) .. " does not match text:GetRawString():len() " .. text:GetRawString():len())
        end

        local rawString = text:GetRawString()
        local displayString = text:GetDisplayString()

        for rawIndex = 1, rawString:len() do
            local displayIndex = text:RawIndexToDisplayIndex(rawIndex)
            local rawCharacter = rawString:sub(rawIndex, rawIndex)
            local displayCharacter = displayString:sub(displayIndex, displayIndex)
            if rawCharacter ~= displayCharacter and not (rawCharacter == " ") then
                widget.Spring.Echo(text:RawIndexToDisplayIndex(rawIndex - 2))
                widget.Spring.Echo(text:RawIndexToDisplayIndex(rawIndex - 1))
                widget.Spring.Echo(displayString:sub(text:RawIndexToDisplayIndex(rawIndex - 2), text:RawIndexToDisplayIndex(rawIndex - 1)))
                widget.Spring.Echo("#text.addedCharacters: " .. #text.addedCharacters)
                for _, addedCharacterDisplayIndex in ipairs(text.addedCharacters) do
                    local extraCharacter = displayString:sub(addedCharacterDisplayIndex, addedCharacterDisplayIndex)
                    if extraCharacter == "\n" then extraCharacter = "\\n" elseif extraCharacter == "\r" then extraCharacter = "\\r" elseif extraCharacter == "\t" then extraCharacter = "\\t" end

                    widget.Spring.Echo("Extra character \"" .. extraCharacter .. "\" at index " .. addedCharacterDisplayIndex)
                end

                widget.Spring.Echo(text.addedCharacters[1])
                error("Character \"" .. displayCharacter .. "\"  at display index " .. displayIndex .. " does not match character \"" .. rawCharacter .. "\" at rawIndex " .. rawIndex .. " (string up to this point: \"" .. rawString:sub(1, rawIndex) .. "\")")
            end
        end

        for displayIndex = 1, displayString:len() do
            local rawIndex, inexactMatch = text:DisplayIndexToRawIndex(displayIndex)

            if not inexactMatch then
                local rawCharacter = rawString:sub(rawIndex, rawIndex)
                local displayCharacter = displayString:sub(displayIndex, displayIndex)
                if rawCharacter ~= displayCharacter and not (rawCharacter == " " and displayCharacter == "\n") then
                    Spring.Echo("rawString:len(): " .. rawString:len())
                    Spring.Echo("displayString:len(): " .. displayString:len())
                    error("Character \"" .. displayCharacter .. "\" at display index " .. displayIndex .. " does not match character \"" .. rawCharacter .. "\" at rawIndex " .. rawIndex .. " (string up to this point: \"" .. displayString:sub(1, displayIndex) .. "\")")
                end
            end
        end
    end,

    test_characterCodes = function(widget)
        widget.Spring.Echo(string.byte("\001"), string.byte("\002"))
        widget.Spring.Echo("\001", "\b", "\012", "\125")
    end
}