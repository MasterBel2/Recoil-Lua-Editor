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
    setfenv(chunk, {
        widget = widget,
        
        Spring = environment.Spring, 
        GL = environment.GL,
        gl = environment.gl, 
        WG = environment.WG,
        widgetHandler = environment.widgetHandler,
        VFS = environment.VFS,
        LUAUI_DIRNAME = LUAUI_DIRNAME,
        
        error = error,
        pairs = pairs,
        ipairs = ipairs,
        type = type,
        string = environment.string,
        math = environment.math,
        table = environment.table,
        tostring = tostring,
        tonumber = tonumber,
        pcall = pcall,
        xpcall = xpcall,
        unpack = unpack,
        loadstring = loadstring,
        setfenv = setfenv,
        setmetatable = setmetatable,
        os = environment.os,
        io = environment.io,
        next = next,
        debug = environment.debug,
    })
    chunk()

    if widget.Initialize then
        widget:Initialize()
    end
end

local function prepare(widget)
    widget.gl.GetViewGeometry = function() return 1920, 1080 end

    loadWidget("gui_master_framework_dev.lua", widget)
    -- loadWidget("gui_master_framework_extensions.lua", widget)
    loadWidget("gui_flowui.lua", widget)
    -- loadWidget("gui_master_framework_flowui_extensions.lua", widget)

    widget:Initialize()

    MasterFramework = widget.WG["MasterFramework " .. widget.getLocal_requiredFrameworkVersion()]
    -- MasterFramework.activeDrawingGroup = { drawTargets = {} }
end

return {
    targetFileName = "LuaUI/Widgets/Lua File Editor/gui_lua_file_editor.lua",

    test_testPreparation = function(widget)
        prepare(widget)
    end,

    test_whitespaceEnding = function(widget)
        prepare(widget)
        widget:Initialize()

        local textEntry = widget.WG.LuaTextEntry(MasterFramework, "", "", function() end)

        local coloredString = textEntry.text:ColoredString("end\n")
        local expectedString = "\255\170\001\085end\n"
        
        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n---\nGot:\n" .. coloredString .. "\n---")
        end
    end,

    test_coloredStringGeneration = function(widget)
        prepare(widget)
        widget:Initialize()

        local textEntry = widget.WG.LuaTextEntry(MasterFramework, "", "", function() end)

        local coloredString = textEntry.text:ColoredString("local keywords = {\n    [\"function\"] = true\n}")
        local expectedString = "\255\170\001\085local\255\255\170\085 keywords\255\255\255\255 = {\n    [\255\001\170\085\"function\"\255\255\255\255] =\255\170\001\085 true\255\255\255\255\n}"
        
        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n\nGot:\n" .. coloredString)
        end
    end,

    test_coloredStringGeneration2 = function(widget)
        prepare(widget)
        widget:Initialize()
        local textEntry = widget.WG.LuaTextEntry(MasterFramework, "", "", function() end)

        local coloredString = textEntry.text:ColoredString("function widget:GetInfo()\n    return {\n        name = \"Lua File Editor\"\n    }\nend")
        local expectedString = "\255\170\001\085function\255\255\170\085 widget\255\255\255\255:\255\255\170\085GetInfo\255\255\255\255()\255\170\001\085\n    return\255\255\255\255 {\255\255\170\085\n        name\255\255\255\255 =\255\001\170\085 \"Lua File Editor\"\255\255\255\255\n    }\255\170\001\085\nend"
        
        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n---\nGot:\n" .. coloredString .. "\n---")
        end
    end,

    test_coloredStringGeneration3 = function(widget)
        prepare(widget)
        widget:Initialize()

        local textEntry = widget.WG.LuaTextEntry(MasterFramework, "", "", function() end)

        local coloredString = textEntry.text:ColoredString("local pairs = Include.pairs\nlocal ipairs = Include.ipairs\n")
        local expectedString = "\255\170\001\085local\255\255\170\085 pairs\255\255\255\255 =\255\255\170\085 Include\255\255\255\255.\255\255\170\085pairs\255\170\001\085\nlocal\255\255\170\085 ipairs\255\255\255\255 =\255\255\170\085 Include\255\255\255\255.\255\255\170\085ipairs\n"
        
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

        local textEntry = widget.WG.LuaTextEntry(MasterFramework, "", "", function() end)
        local coloredString = textEntry.text:ColoredString(inputString)
        local expectedString =
"\255\170\001\085    if\255\255\255\255 (\255\255\170\085text\255\255\255\255)\255\170\001\085       then\255\255\170\085 tSuccess\255\255\255\255 =\255\255\170\085 remove\255\255\255\255(\255\255\170\085self\255\255\255\255.\255\255\170\085textActions\255\255\255\255)\255\170\001\085       end\255\170\001\085\n" ..
"    if\255\255\255\255 (\255\255\170\085keyPress\255\255\255\255)\255\170\001\085   then\255\255\170\085 pSuccess\255\255\255\255 =\255\255\170\085 remove\255\255\255\255(\255\255\170\085self\255\255\255\255.\255\255\170\085keyPressActions\255\255\255\255)\255\170\001\085   end\255\170\001\085\n" ..
"    if\255\255\255\255 (\255\255\170\085keyRepeat\255\255\255\255)\255\170\001\085  then\255\255\170\085 RSuccess\255\255\255\255 =\255\255\170\085 remove\255\255\255\255(\255\255\170\085self\255\255\255\255.\255\255\170\085keyRepeatActions\255\255\255\255)\255\170\001\085  end\255\170\001\085\n" ..
"    if\255\255\255\255 (\255\255\170\085keyRelease\255\255\255\255)\255\170\001\085 then\255\255\170\085 rSuccess\255\255\255\255 =\255\255\170\085 remove\255\255\255\255(\255\255\170\085self\255\255\255\255.\255\255\170\085KeyReleaseActions\255\255\255\255)\255\170\001\085 end\n"

        if coloredString ~= expectedString then
            error("Expected:\n" .. expectedString .. "\n---\nGot:\n" .. coloredString .. "\n---")
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

    test_indexCalculation = function(widget)
        prepare(widget)
        local string = VFS.LoadFile("LuaUI/Widgets/Lua File Editor/tests.lua")

        local text = MasterFramework:WrappingText(string)
        local textGroup = MasterFramework:TextGroup(text)
       
        textGroup:Layout(200, 10000000)
        textGroup:Position(0, 0)
        
        --widget.Spring.Echo("Raw String:")
        --widget.Spring.Echo(text:GetRawString())
        --widget.Spring.Echo("Display String:")
        --widget.Spring.Echo(text:GetDisplayString())

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

    test_indexCalculationWithTextColors2 = function(widget)
        prepare(widget)
        -- local string = VFS.LoadFile("LuaUI/Widgets/test.lua")

        local text = MasterFramework:WrappingText("testing123")
        local textGroup = MasterFramework:TextGroup(text)
       
        textGroup:Layout(200, 10000000)
        textGroup:Position(0, 0)

        -- Spring.Echo(text:GetDisplayString())

        --widget.Spring.Echo("" .. text:RawIndexToDisplayIndex(text:GetRawString():len()) .. ":" .. text:GetDisplayString():len() .. ":" .. text:GetRawString():len())
        --widget.Spring.Echo("" .. text:DisplayIndexToRawIndex(text:GetDisplayString():len()) .. ":" .. text:GetRawString():len() .. ":" .. text:GetDisplayString():len())

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