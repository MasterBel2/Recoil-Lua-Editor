function widget:GetInfo()
    return {
        name = "Lua File Editor",
        description = "",
        author = "MasterBel2",
        date = "April 2023",
        license = "GNU GPL, v2 or later",
        layer = math.huge,
        handler = true
    }
end

------------------------------------------------------------------------------------------------------------
-- MasterFramework
------------------------------------------------------------------------------------------------------------

local requiredFrameworkVersion = "Dev"
local key

------------------------------------------------------------------------------------------------------------
-- Imports
------------------------------------------------------------------------------------------------------------

local math_max = math.max
local math_min = math.min

VFS.Include(LUAUI_DIRNAME .. "Widgets/Lua File Editor/Include/LuaTextEntry.lua")
VFS.Include(LUAUI_DIRNAME .. "Widgets/Lua File Editor/Include/TakeAvailableWidth.lua")
VFS.Include(LUAUI_DIRNAME .. "Widgets/Lua File Editor/Include/TakeAvailableHeight.lua")
VFS.Include(LUAUI_DIRNAME .. "Widgets/Lua File Editor/Include/VerticalSplit.lua")
VFS.Include(LUAUI_DIRNAME .. "Widgets/Lua File Editor/Include/TabBar.lua")

------------------------------------------------------------------------------------------------------------
-- Widget Internals
------------------------------------------------------------------------------------------------------------

local tabBar
local searchEntry
local mainEditor
local secondaryEditor

local fileBrowserStackContents

local editedFileColor
local savedFileColor

local debugInfoText
local profileText

local errorHighlightColor
local searchHighlightColor
local selectedSearchHighlightColor

local lastSelectedSearchResult
local searchResults = {}
local searchStack

local editedFiles = {}
local fileScrollIndices = {}

local folderMenus = {}
local fileButtons = {}

local errors = {}
local errorDisplays = {}
local errorHighlightIDs = {}

local widgetPathToWidgetName = {}
local widgetNameToFileName = {}
local fileNameToWidgetName = {}
local runningWidgets = {}
local messages = {}

local fileNamePattern = "([%w%s%._&-]+)/?$"

-- Only use these to cache between SetConfigData and Initialize
local _init_mainEditorFilePath
local _init_secondaryEditorFilePath

local function FileDir(filePath)
    return filePath:match("(.+/)[^/]+")
end

local function RefreshDirIfVisible(dir)
    if folderMenus[dir] then
        folderMenus[dir]:HideChildren()
        folderMenus[dir]:ShowChildren()
    end
end

local function CorrespondingTestFile(path)
    local rootWidgetFileName = path:match("LuaUI/Widgets/([^/]+%.lua)")
    if rootWidgetFileName then
        return "LuaUI/Widget Tests/", "LuaUI/Widget Tests/test_" .. rootWidgetFileName
    else
        local widgetDirectory, fileSubdirectory, fileName = path:match("(LuaUI/Widgets/[^/]+/)(.-)([^/]+%.lua)")
        if widgetDirectory and fileSubdirectory and fileName then
            testFileSubDir = widgetDirectory .. "Tests/" .. fileSubdirectory
            return testFileSubDir, testFileSubDir .. "test_" .. fileName
        end
    end
end

local function RunTestsAtPath(path)
    tabBar:Select(6)
    local _, testFilePath = CorrespondingTestFile(path)
    local _Spring_Echo = Spring.Echo
    local testOutput = {}
    function Spring.Echo(message)
        testOutput[#testOutput + 1] = message
    end
    WG.Tests.RunAllTestsInFile(testFilePath, { testsFailed = 0, testsPassed = 0 })
    Spring.Echo = _Spring_Echo
    testResultText:SetString(table.concat(testOutput, "\n"))
end

local function Search()
    local searchTerm = searchEntry.text:GetRawString()

    for _, result in ipairs(searchResults) do
        _ = result.highlightID and mainEditor.textEntry.text:RemoveHighlight(result.highlightID)
    end

    if searchTerm:len() < 3 then
        searchStack:SetMembers({})
        return
    end

    local searchBegin = 1
    searchResults = {}
    lastSelectedSearchResult = nil
    local searchee = mainEditor.textEntry.text:GetRawString()
    while searchBegin < searchee:len() do
        local start, _end = searchee:find(searchTerm, searchBegin)
        if start and _end then
            table.insert(searchResults, { 
                filePath = mainEditor:GetFilePath(), 
                start = start, 
                _end = _end, 
                highlightID = mainEditor.textEntry.text:HighlightRange(searchHighlightColor, start, _end + 1)
            })
            searchBegin = _end + 1
        else
            break
        end
    end

    searchStack:SetMembers(table.imap(searchResults, function(_, result)
        return MasterFramework:Button(
            MasterFramework:WrappingText(
                "\255\122\122\122" .. (searchee:sub(1, result.start - 1):match("[^\n]*[\n][^\n]*$") or "") .. 
                "\255\255\255\255" .. searchee:sub(result.start, result._end) ..
                "\255\122\122\122" .. (searchee:match("([^\n]*[\n][^\n]*)", result._end + 1) or "")
            ),
            function()
                _ = lastSelectedSearchResult and mainEditor.textEntry.text:UpdateHighlight(lastSelectedSearchResult.highlightID, searchHighlightColor, lastSelectedSearchResult.start, lastSelectedSearchResult._end + 1)
                mainEditor.textEntry.text:UpdateHighlight(result.highlightID, selectedSearchHighlightColor, result.start, result._end + 1)
                lastSelectedSearchResult = result
                mainEditor:SelectFile(result.filePath, nil, result.start)
            end
        )
    end))
    mainEditor.textEntry.text:NeedsRedraw()
end

local function RevealPath(path)
    if path == nil or path == "" then return true end
    if not RevealPath(path:match("(.+/)[%w%s%._&-]+/?$")) then
        return false
    end
    if fileButtons[path] then
        return true
    elseif folderMenus[path] then
        folderMenus[path]:ShowChildren()
        return true
    else
        return false
    end
end

local function OpenCorrespondingTestFile(path, ctrl)
    local testFileSubDir, testFilePath = CorrespondingTestFile(path)

    if testFilePath then
        if not VFS.FileExists(testFilePath) then
            Spring.CreateDir(testFileSubDir)
            local file = io.open(testFilePath, "w")
            file:write("return {\n\ttargetFileName = \"" .. path .. "\",\n\ttest_example = function()\n\t\terror(\"Test failure!\")\n\tend,\n}")
            file:close()
        end

        RevealPath(testFilePath)
        if ctrl then
            secondaryEditor:SelectFile(testFilePath)
        else
            mainEditor:SelectFile(testFilePath)
        end
    else
        Spring.Echo("No configured test directory for files at this location!")
    end
end

local function MarkFileEdited(path, isEdited)
    if (not path) or (editedFiles[path] and isEdited) or ((not editedFiles[path]) and (not isEdited)) then
        return
    end
    local pattern = "(.+/)[%w%s%._&-]+/?$"
    
    if fileButtons[path] then
        fileButtons[path].text:SetBaseColor(isEdited and editedFileColor or savedFileColor)
    end

    local change = isEdited and 1 or -1

    local trimmedPath = path:match(pattern)
    while trimmedPath and trimmedPath ~= "" do
        local menu = folderMenus[trimmedPath]
        if menu then
            menu.editedSubfileCount = menu.editedSubfileCount + change
            if isEdited then 
                menu.title:SetBaseColor(editedFileColor)
            elseif menu.editedSubfileCount == 0 then
                menu.title:SetBaseColor(savedFileColor)
            end
        end
        trimmedPath = trimmedPath:match(pattern)
    end
end

local function Editor()
    local fileName
    local filePath
    local showFullFilePath
    local editor

    local textEntry = WG.LuaTextEntry(MasterFramework, "", "Select File To Edit", function() editor:Save() end)

    local textEntry_KeyPress = textEntry.KeyPress
    function textEntry:KeyPress(key, mods, isRepeat)
        if key == 0x65 and mods.ctrl then -- Ctrl+F
            tabBar:Select(3)
        elseif key == 0x66 and mods.ctrl then -- Ctrl+F
            tabBar:Select(2)
            searchEntry:TakeFocus()
        elseif key == 0x72 and mods.ctrl then -- Ctrl+R
            self.saveFunc()
            local widgetName = widgetPathToWidgetName[filePath]
            if not widgetName then return end
            if mods.shift then
                Spring.SendCommands("luaui reload")
            elseif widgetName then
                widgetHandler:DisableWidget(widgetName)
                widgetHandler:EnableWidget(widgetName)
            end
        elseif key == 0x74 and mods.ctrl then -- Ctrl+T
            if mods.shift then
                OpenCorrespondingTestFile(filePath, editor == mainEditor)
            else
                RunTestsAtPath(filePath)
            end
        else
            textEntry_KeyPress(self, key, mods, isRepeat)
        end
    end

    local fileNameDisplay = MasterFramework:Button(MasterFramework:Text("<no file>", MasterFramework:Color(0.3, 0.3, 0.3, 1)), function(fileNameDisplay)
        showFullFilePath = not showFullFilePath
        fileNameDisplay.visual:SetString(showFullFilePath and filePath or fileName or "<no file>")
    end)
    local saveButton = MasterFramework:Button(MasterFramework:Text("Save", MasterFramework:Color(0.3, 0.3, 0.6, 1)), function(button)
        editor:Save()
    end)
    local revertButton = MasterFramework:Button(MasterFramework:Text("Revert", MasterFramework:Color(0.6, 0.3, 0.3, 1)), function(button)
        if not filePath then return end
        textEntry.text:SetString(VFS.LoadFile(filePath))
        MarkFileEdited(filePath, false)
        editedFiles[filePath] = nil
    end)

    local codeScrollContainer = MasterFramework:VerticalScrollContainer(textEntry)

    -- Capture this after we do our first SelectFile so we don't overwrite the loaded value until the UI is properly configured.
    local codeScrollContainer_viewport_SetYOffset = codeScrollContainer.viewport.SetYOffset
    local indexHighlightID
    function codeScrollContainer.viewport:SetYOffset(newYOffset)
        codeScrollContainer_viewport_SetYOffset(self, newYOffset)
        if not filePath then return end
        local _, yOffset = self:GetOffsets()
        local x, y = textEntry.text:CachedPositionTranslatedToGlobalContext()
        if not x or not y then return end
        local _, height = textEntry.text:Size()
        fileScrollIndices[filePath] = textEntry.text:CoordinateToCharacterDisplayIndex(x, y + height - yOffset)
    end

    editor = MasterFramework:VerticalHungryStack(
        MasterFramework:HorizontalStack({
                fileNameDisplay,
                saveButton,
                revertButton
            }, 
            MasterFramework:AutoScalingDimension(8), 0.5
        ),
        TakeAvailableWidth(TakeAvailableHeight(codeScrollContainer)),
        MasterFramework:Rect(MasterFramework:AutoScalingDimension(0), MasterFramework:AutoScalingDimension(0)), 
        0
    )

    function editor:GetFilePath() return filePath end
    function editor:GetFileName() return fileName end

    function editor:Save()
        if not filePath then return end
        local fh = io.open(filePath, "w")
        fh:write(textEntry.text:GetRawString())
        fh:close()
        
        MarkFileEdited(filePath, false)
        editedFiles[filePath] = nil
    end

    function editor:SelectFile(path, _fileName, targetCharacterIndex)
        textEntry.placeholder:SetString("")
        if VFS.FileExists(path, VFS.RAW) then
            fileName = _fileName or path:match(fileNamePattern)
            filePath = path
            textEntry.text:SetString(editedFiles[path] or VFS.LoadFile(path))
            if textEntry.text.availableWidth and textEntry.text.availableHeight then
                textEntry.text:Layout(textEntry.text.availableWidth, textEntry.text.availableHeight)
                
                targetCharacterIndex = targetCharacterIndex or fileScrollIndices[path]
                if targetCharacterIndex then
                    local lineCount = #textEntry.text:GetDisplayString():sub(1, textEntry.text:RawIndexToDisplayIndex(targetCharacterIndex)):lines_MasterFramework()
                    local offset = (lineCount - 10) * textEntry.text._readOnly_font:ScaledSize()
                    codeScrollContainer.viewport:SetYOffset(math.max(0, offset))
                else
                    codeScrollContainer.viewport:SetYOffset(0)
                end
                fileNameDisplay.visual:SetString(showFullFilePath and path or fileName)
                self:ConfigureErrorHighlight()
            end
        end
    end

    function editor:ConfigureErrorHighlight()
        for i = 1, errors[filePath] and #errors[filePath] or 0 do
            local lineStarts, lineEnds = textEntry.text:GetRawString():lines_MasterFramework()
            local line = errors[filePath][i].line

            if errorHighlightIDs[i] then
                textEntry.text:UpdateHighlight(errorHighlightIDs[i], errorHighlightColor, lineStarts[line], lineEnds[line] + 1)
            else
                errorHighlightIDs[i] = textEntry.text:HighlightRange(errorHighlightColor, lineStarts[line], lineEnds[line] + 1)
            end
        end
        for i = errors[filePath] and #errors[filePath] + 1 or 1, #errorHighlightIDs do
            textEntry.text:RemoveHighlight(errorHighlightIDs[i])
            errorHighlightIDs[i] = nil
        end
    end

    textEntry:SetPostEditEffect(function()
        if filePath then 
            MarkFileEdited(filePath, true)
            editedFiles[filePath] = textEntry.text:GetRawString() -- Would be nice to cache the `no file` case also?
        end

        Search()
    end)

    editor.textEntry = textEntry

    return editor
end

function widget:GetConfigData()
    return {
        fileScrollIndices = fileScrollIndices,
        editedFiles = editedFiles,
        mainEditorFilePath = mainEditor:GetFilePath(),
        secondaryEditorFilePath = secondaryEditor:GetFilePath(),
        verticalSplitDividerXCache = verticalSplitDividerXCache
    }
end
function widget:SetConfigData(data)
    fileScrollIndices = data.fileScrollIndices or {}
    editedFiles = data.editedFiles or {}
    _init_mainEditorFilePath = data.mainEditorFilePath or data.filePath
    _init_secondaryEditorFilePath = data.secondaryEditorFilePath
    verticalSplitDividerXCache = data.verticalSplitDividerXCache or {}
    for path, _ in pairs(editedFiles) do
        MarkFileEdited(path, true)
    end
end

local function UIFileButton(path)
    local _fileName = path:match(fileNamePattern)
    local text = MasterFramework:Text(_fileName, editedFiles[path] and editedFileColor or savedFileColor)
    local button = MasterFramework:RightClickMenuAnchor(
        MasterFramework:Button(
            text,
            function()
                local _, ctrl = Spring.GetModKeyState()
                if ctrl then
                    secondaryEditor:SelectFile(path, _fileName)
                else
                    mainEditor:SelectFile(path, _fileName)
                end
            end
        ),
        {
            { title = "Open Tests (Ctrl+Shift+T)", action = function() 
                local _, ctrl = Spring.GetModKeyState()
                OpenCorrespondingTestFile(path, ctrl)
            end, enabled = true },
            { title = "Run Tests (Ctrl+T)", action = function()
                local _, testFilePath = CorrespondingTestFile(path)
                RunTestsAtPath(path)
            end, enabled = true },
            { title = "Rename/Move", action = function()
                local pathEntry = MasterFramework:TextEntry(path)
                MasterFramework:Dialog(
                    "Rename/Move",
                    { pathEntry },
                    {
                        { name = "Confirm", color = MasterFramework.color.green, 
                            action = function()
                                local newPath = pathEntry.text:GetRawString()
                                if VFS.FileExists(newPath) then error("File already exists!") end
                                local fileContents = VFS.LoadFile(path)
                                local file = io.open(newPath, "w")
                                file:write(fileContents)
                                file:close()
                                os.remove(path)
                                editedFiles[newPath] = editedFiles[path]
                                editedFiles[path] = nil
                                                                
                                if mainEditor:GetFilePath() == path then
                                    mainEditor:SelectFile(newPath)
                                end
                                if secondaryEditor:GetFilePath() == path then
                                    secondaryEditor:SelectFile(newPath)
                                end
                                
                                RefreshDirIfVisible(FileDir(path))
                                RefreshDirIfVisible(FileDir(newPath))
                                
                                RevealPath(newPath)
                            end 
                        },
                        { name = "Cancel", color = MasterFramework.color.red, action = function() end }
                    }
                ):PresentAbove(key) 
            end, enabled = true },
        },
        path
    )
    
    button.text = text
    fileButtons[path] = button

    function button:Deregister()
        fileButtons[path] = nil
    end

    return button
end
local function UIFolderMenu(path)
    local folderMenu
    local contentsVisible = false
    local spacing = MasterFramework:AutoScalingDimension(2)

    local checkBox = MasterFramework:CheckBox(12, function(_, checked)
        if checked then
            folderMenu:ShowChildren()
        else
            folderMenu:HideChildren()
        end
    end)
    local title = MasterFramework:Text(path:match("([%w%s%._&-]+)/?$") or "error")

    local registeredChildren

    local function deregisterChildren()
        if registeredChildren then
            for _, child in ipairs(registeredChildren) do
                child:Deregister()
            end
        end

        registeredChildren = nil
    end

    local folderRow = MasterFramework:HorizontalStack({ checkBox, title }, MasterFramework:AutoScalingDimension(8), 0.5)

    folderMenu = MasterFramework:VerticalStack({ folderRow }, spacing, 0)

    function folderMenu:Deregister()
        deregisterChildren()
        folderMenus[path] = nil
    end

    function folderMenu:ShowChildren()
        if not folderMenu:GetMembers()[2] then
            registeredChildren = table.joinArrays({ table.imap(VFS.SubDirs(path, "*", VFS.RAW), function(_, subDir) return UIFolderMenu(subDir) end), table.imap(VFS.DirList(path, "*", VFS.RAW), function(_, filePath) return UIFileButton(filePath) end) })
            folderMenu:SetMembers({ folderRow, MasterFramework:MarginAroundRect(
                MasterFramework:VerticalStack(registeredChildren, spacing, 0),
                MasterFramework:AutoScalingDimension(20),
                MasterFramework:AutoScalingDimension(0),
                MasterFramework:AutoScalingDimension(0),
                MasterFramework:AutoScalingDimension(0)
            ) })
        end
        checkBox:SetChecked(true)
    end
    function folderMenu:HideChildren()
        if self:GetMembers()[2] then
            folderMenu:SetMembers({ folderRow })
            deregisterChildren()
        end
        checkBox:SetChecked(false)
    end

    folderMenu.editedSubfileCount = 0

    local escapedPath = path:gsub("([%-%.])", "%%%1")

    for editedFilePath, _ in pairs(editedFiles) do
        if editedFilePath:find("^" .. path) then
            folderMenu.editedSubfileCount = folderMenu.editedSubfileCount + 1
        end
    end

    if folderMenu.editedSubfileCount == 0 then
        title:SetBaseColor(savedFileColor)
    else
        title:SetBaseColor(editedFileColor)
    end

    folderMenu.title = title

    folderMenus[path] = folderMenu

    return folderMenu
end

function ErrorDisplay(error)
    local text = MasterFramework:WrappingText("", MasterFramework.color.red)
    local errorDisplay
    errorDisplay = MasterFramework:Button(text, function()
        if errorDisplay.path then
            shownError = false
            local lineStarts, lineEnds = mainEditor.textEntry.text:GetRawString():lines_MasterFramework()
            mainEditor:SelectFile(errorDisplay.path, nil, lineStarts[error.line])
            RevealPath(errorDisplay.path)
        end
    end)
    errorDisplay.descriptionText = text

    return errorDisplay
end

local failedToLoad = {}

local function RegisterLoadedFile(path)
    runningWidgets[path] = { enabled = true }
    errorDisplays[path] = {}
    errors[path] = {}
    
    if path == mainEditor:GetFilePath() then
        mainEditor:ConfigureErrorHighlight()
    end
    if path == secondaryEditor:GetFilePath() then
        secondaryEditor:ConfigureErrorHighlight()
    end
end

local function RegisterLoadedWidget(widgetName, fileName)
    widgetNameToFileName[widgetName] = fileName
    fileNameToWidgetName[fileName] = widgetName
    widgetPathToWidgetName["LuaUI/Widgets/" .. fileName] = widgetName
    
    RegisterLoadedFile("LuaUI/Widgets/" .. fileName)
end

function widget:DebugInfo()
    return { fileScrollIndices = fileScrollIndices }
end

local consoleStrings = {
    ["^Loading:  (.*)"] = function(fullMessage, widgetPath)
        RegisterLoadedFile(widgetPath)
    end,
    ["^Loading widget from user:  (.+[^%s])%s+<([^%s]+)> ...$"] = function(fullMessage, widgetName, fileName)
        -- If we get this, we dont get an "Added" message when the widget is successfully loaded
        failedToLoad["LuaUI/Widgets/" .. fileName] = nil
        
        RegisterLoadedWidget(widgetName, fileName)
    end,
    ["^Added:  (.*)"] = function(fullMessage, widgetPath) 
        -- We only get this if the widget was manually enabled by the user, not when the widget is loaded by the game.
        RegisterLoadedFile(widgetPath)
    end,
    ["^Removed:  (.*)"] = function(fullMessage, widgetPath) -- disabled by user
        runningWidgets[widgetPath] = nil

        if widgetPath == mainEditor:GetFilePath() then
            mainEditor:ConfigureErrorHighlight()
        end
        if widgetPath == secondaryEditor:GetFilePath() then
            secondaryEditor:ConfigureErrorHighlight()
        end
    end,
    ["^Failed to load: (.+[^%s])  %((.*)%)"] = function(fullMessage, fileName, description) -- widget crash
        -- failedToLoad[fileName] = 
        failedToLoad[fileName] = description
        local path, line, errorMessage = description:match("%[string \"([^\"]+)\"%]:(%d+): (.*)")
        -- local path = "LuaUI/Widgets/" .. fileName
        if path then
            local error = { message = errorMessage, line = tonumber(line) }
            local errorDisplay = ErrorDisplay(error)
            errorDisplay.descriptionText:SetString(widgetPathToWidgetName[path] or path .. ":" .. errorMessage)
            errorDisplay.path = path

            errors[path] = { error }
            errorDisplays[path] = { errorDisplay }
        end
    end,
    ["^Error in ([^%s\n]+)%(%): %[string \"([^\"]+)\"%]:(%d+): (.*)"] = function(fullMessage, func, path, line, errorMessage)
        local error = { message = errorMessage, line = tonumber(line), func = func }
        local errorDisplay = ErrorDisplay(error)

        -- I don't know why, but some errors don't report the widget they're associated with.
        if not errors[path] then errors[path] = {} end
        if not errorDisplays[path] then errorDisplays[path] = {} end

        errorDisplay.descriptionText:SetString(widgetPathToWidgetName[path] or path .. ":" .. errorMessage)
        errorDisplay.path = path
        table.insert(errorDisplays[path], errorDisplay)
        table.insert(errors[path], error)

        if path == mainEditor:GetFilePath() then
            mainEditor:ConfigureErrorHighlight()
        end
        if path == secondaryEditor:GetFilePath() then
            secondaryEditor:ConfigureErrorHighlight()
        end
    end,
    -- ["^Error(.+)%[string \"([^\"]+)\"%]:(%d+): (.*)"] = function(fullMessage, func, path, line, errorMessage)
    --     local error = { message = errorMessage, line = tonumber(line), func = func }
    --     local errorDisplay = ErrorDisplay(error)

    --     -- I don't know why, but some errors don't report the widget they're associated with.
    --     if not errors[path] then errors[path] = {} end
    --     if not errorDisplays[path] then errorDisplays[path] = {} end

    --     errorDisplay.descriptionText:SetString(widgetPathToWidgetName[path] or path .. ":" .. errorMessage)
    --     errorDisplay.path = path
    --     table.insert(errorDisplays[path], errorDisplay)
    --     table.insert(errors[path], error)

    --     if path == mainEditor:GetFilePath() then
        --     mainEditor:ConfigureErrorHighlight()
        -- end
        -- if path == secondaryEditor:GetFilePath() then
        --     secondaryEditor:ConfigureErrorHighlight()
        -- end
    -- end,
    ["^Removed widget: (.*)"] = function(fullMessage, widgetName) -- widget crash
        -- runningWidgets["LuaUI/Widgets/" .. widgetNameToFileName[widgetName]].enabled = false
    end
}

function widget:AddConsoleLine(msg)
    for pattern, func in pairs(consoleStrings) do
        local returnValues = { msg:match(pattern) }
        if #returnValues > 0 then
            -- if pattern == "Error in ([^%s\n]+)%(%): %[string \"([^\"]+)\"%]:(%d+): (.*)" then
            --     returnValues.msg = msg
            --     table.insert(messages, returnValues)
            -- end
            func(msg, unpack(returnValues))
        end
    end
    return true
end

------------------------------------------------------------------------------------------------------------
-- Setup/Update/Teardown
------------------------------------------------------------------------------------------------------------

function widget:Update()
    if tabBar:GetSelectedIndex() == 3 then
        local errors = {}
        for fileName, pathErrorDisplays in pairs(errorDisplays) do
            for i = 1, #pathErrorDisplays do
                errors[#errors + 1] = { name = fileName, display = pathErrorDisplays[i] }
            end
        end
        table.sort(errors, function(a, b)
            return a.name > b.name
        end)
        errorStack:SetMembers(table.imap(errors, function(_, x) return x.display end))
    elseif tabBar:GetSelectedIndex() == 4 and fileNameToWidgetName[mainEditor:GetFileName()] then
        local index = widgetHandler.orderList[fileNameToWidgetName[mainEditor:GetFileName()]]
        local widget = widgetHandler.widgets[index]
        if widget then
            local success, value = pcall(widget.DebugInfo, widget)
            if success and type(value) == "table" then
                debugInfoText:SetString(MasterFramework.debugDescriptionString(value, "Debug Info for widget \"" .. widget.whInfo.name .. "\""))
            else
                debugInfoText:SetString("Error in widget:DebugInfo(): " .. (value or "nil"))
                widget.DebugInfo = nil
            end
        end        
    elseif tabBar:GetSelectedIndex() == 5 then
        local statsArray = table.mapToArray(MasterFramework.stats, function(key, value)
            return "\255\050\100\255" .. key .. " - \255\255\255\255".. value
        end)
    
        table.sort(statsArray)
        profileText:SetString(table.concat(statsArray, "\n"))
    end
end

function widget:Initialize()
    MasterFramework = WG["MasterFramework " .. requiredFrameworkVersion]
    if not MasterFramework then
        error("[Lua File Editor] MasterFramework " .. requiredFrameworkVersion .. " not found!")
    end

    errorHighlightColor = MasterFramework:Color(1, 0.2, 0.1, 0.5)
    searchHighlightColor = MasterFramework:Color(0.3, 0.6, 1, 0.3)
    selectedSearchHighlightColor = MasterFramework:Color(1, 1, 0.0, 0.3)

    table = MasterFramework.table

    local monospaceFont = MasterFramework:Font("fonts/monospaced/SourceCodePro-Medium.otf", 12)
    searchEntry = MasterFramework:TextEntry("", "Search", nil, monospaceFont)
    searchStack = MasterFramework:VerticalStack({}, MasterFramework:AutoScalingDimension(2), 0)

    function searchEntry:SetPostEditEffect(postEditEffect)
        local function ReplaceEditFunction(name)
            local cachedFunction = searchEntry[name]
            searchEntry[name] = function(...)
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

    searchEntry:SetPostEditEffect(Search)

    editedFileColor = MasterFramework:Color(1, 0.6, 0.3, 1)
    savedFileColor = MasterFramework:Color(1, 1, 1, 1)
    
    debugInfoText = MasterFramework:WrappingText("")
    profileText = MasterFramework:WrappingText("")
    testResultText = MasterFramework:WrappingText("")

    errorStack = MasterFramework:VerticalStack({}, MasterFramework:AutoScalingDimension(2), 0)

    tabBar = TabBar({
        { title = "Files", display = MasterFramework:VerticalScrollContainer(UIFolderMenu(LUAUI_DIRNAME)) },
        { title = "Search", display = MasterFramework:VerticalHungryStack(searchEntry, MasterFramework:VerticalScrollContainer(searchStack), MasterFramework:Rect(MasterFramework:AutoScalingDimension(0), MasterFramework:AutoScalingDimension(0)), 0) },
        { title = "Errors", display = MasterFramework:VerticalScrollContainer(errorStack) },
        { title = "Debug", display = MasterFramework:VerticalScrollContainer(debugInfoText) },
        { title = "Profile", display = MasterFramework:VerticalScrollContainer(profileText) },
        { title = "Test Results", display = MasterFramework:VerticalScrollContainer(testResultText) },
    })

    mainEditor = Editor()
    secondaryEditor = Editor()

    local resizableFrame = MasterFramework:ResizableMovableFrame(
        "Lua File Editor",
        MasterFramework:PrimaryFrame(
                MasterFramework:Background(
                    MasterFramework:MarginAroundRect(
                    VerticalSplit(
                        tabBar,
                        VerticalSplit(mainEditor, secondaryEditor, 1, "Lua File Editor Split: Main Editor & Secondary Editor", true),
                        1,
                        "Lua File Editor Split: Side Bar & Editors",
                        false
                    ),
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20),
                    MasterFramework:AutoScalingDimension(20)
                ),
                { MasterFramework.FlowUIExtensions:Element() },
                MasterFramework:AutoScalingDimension(5)
            )
        ),
        MasterFramework.viewportWidth * 0.1, MasterFramework.viewportHeight * 0.1, 
        MasterFramework.viewportWidth * 0.8, MasterFramework.viewportHeight * 0.8,
        false
    )

    key = MasterFramework:InsertElement(resizableFrame, "Lua File Editor", MasterFramework.layerRequest.anywhere())

    if _init_mainEditorFilePath then
        mainEditor:SelectFile(_init_mainEditorFilePath)
        RevealPath(_init_mainEditorFilePath)
    end
    if _init_secondaryEditorFilePath then
        secondaryEditor:SelectFile(_init_secondaryEditorFilePath)
    end

    local buffer = Spring.GetConsoleBuffer()
    for _, line in ipairs(buffer) do
        widget:AddConsoleLine(line.text)
    end
    
    for widgetName, widgetInfo in pairs(widgetHandler.knownWidgets) do
        runningWidgets[widgetInfo.filename] = widgetInfo.active or nil
        widgetPathToWidgetName[widgetInfo.filename] = widgetName
        widgetNameToFileName[widgetName] = widgetInfo.basename
        fileNameToWidgetName[widgetInfo.basename] = widgetName
        
        errorDisplays[widgetInfo.filename] = {}
        errors[widgetInfo.filename] = {}
    end
end

function widget:Shutdown() 
    MasterFramework:RemoveElement(key)
    WG.MasterStats = nil
end