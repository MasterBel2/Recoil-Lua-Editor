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

local MasterFramework
local requiredFrameworkVersion = "Dev"
local key

------------------------------------------------------------------------------------------------------------
-- Imports
------------------------------------------------------------------------------------------------------------

local math_max = math.max
local math_min = math.min

VFS.Include(LUAUI_DIRNAME .. "Widgets/Lua File Editor/Include/LuaTextEntry.lua")

------------------------------------------------------------------------------------------------------------
-- Interface
------------------------------------------------------------------------------------------------------------

local function TakeAvailableHeight(body)
    local cachedHeight
    local cachedAvailableHeight
    return {
        Layout = function(_, availableWidth, availableHeight)
            local width, height = body:Layout(availableWidth, availableHeight)
            cachedHeight = height
            cachedAvailableHeight = math_max(availableHeight, height)
            return width, cachedAvailableHeight
        end,
        Position = function(_, x, y) body:Position(x, y + cachedAvailableHeight - cachedHeight) end
    }
end
local function TakeAvailableWidth(body)
    return {
        Layout = function(_, availableWidth, availableHeight)
            local _, height = body:Layout(availableWidth, availableHeight)
            return availableWidth, height
        end,
        Position = function(_, x, y) body:Position(x, y) end
    }
end

------------------------------------------------------------------------------------------------------------
-- Widget Internals
------------------------------------------------------------------------------------------------------------

local fileName
local filePath
local showFullFilePath

local tabBar
local searchEntry

local textEntry
local codeScrollContainer
local fileBrowserStackContents

local editedFileColor
local savedFileColor

local errorHighlightColor
local searchHighlightColor
local selectedSearchHighlightColor

local fileNameText
local saveButton
local revertButton

local lastSelectedSearchResult
local searchResults = {}

local editedFiles = {}
local fileScrollIndices = {}

local folderMenus = {}
local fileButtons = {}

local errors = {}
local errorDisplays = {}
local errorHighlightIDs = {}

local fileNamePattern = "([%w%s%._&-]+)/?$"

local verticalSplitDividerXCache = {}

local function ConfigureErrorHighlight()
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

local function SelectFile(path, _fileName, targetCharacterIndex)
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
            ConfigureErrorHighlight()
        end
    end
end


local function RevealPath(path)
    if path == nil or path == "" then return true end
    if not RevealPath(path:match("(.+/)[%w%s%._&-]+/?$")) then
        return false
    end
    if fileButtons[path] then
        SelectFile(path)
        return true
    elseif folderMenus[path] then
        folderMenus[path]:ShowChildren()
        return true
    else
        return false
    end
end

local function MarkFileEdited(path, isEdited)
    if not path or (editedFiles[path] and isEdited) or ((not editedFiles[path]) and (not isEdited)) then
        return
    end
    local pattern = "(.+/)[%w%s%._&-]+/?$"
    
    fileButtons[path].visual:SetBaseColor(isEdited and editedFileColor or savedFileColor)

    local change = isEdited and 1 or -1

    local trimmedPath = path:match(pattern)
    while trimmedPath and trimmedPath ~= "" do
        local menu = folderMenus[trimmedPath]
        menu.editedSubfileCount = menu.editedSubfileCount + change
        if isEdited then 
            menu.title:SetBaseColor(editedFileColor)
        elseif menu.editedSubfileCount == 0 then
            menu.title:SetBaseColor(savedFileColor)
        end 
        trimmedPath = trimmedPath:match(pattern)
    end
end

local function Save()
    if not filePath then return end
    local fh = io.open(filePath, "w")
    fh:write(textEntry.text:GetRawString())
    fh:close()
    
    MarkFileEdited(filePath, false)
    editedFiles[filePath] = nil
end

function widget:GetConfigData()
    return {
        fileScrollIndices = fileScrollIndices,
        editedFiles = editedFiles,
        filePath = filePath,
        verticalSplitDividerXCache = verticalSplitDividerXCache
    }
end
function widget:SetConfigData(data)
    fileScrollIndices = data.fileScrollIndices or {}
    editedFiles = data.editedFiles or {}
    filePath = data.filePath
    verticalSplitDividerXCache = data.verticalSplitDividerXCache or {}
    for path, _ in pairs(editedFiles) do
        MarkFileEdited(path, true)
    end
end

local function UIFileButton(path)
    local _fileName = path:match(fileNamePattern)
    local button = MasterFramework:Button(MasterFramework:Text(_fileName, editedFiles[path] and editedFileColor or savedFileColor), function()
        SelectFile(path, _fileName)
    end)

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

local function VerticalSplit(left, right, yAnchor, key)
    local split = MasterFramework:Component(true, false)
    local isDragging

    local minWidth = MasterFramework:AutoScalingDimension(40)

    local dividerWidth = MasterFramework:AutoScalingDimension(2)
    local width, height
    local dividerRect = MasterFramework:Background(MasterFramework:Rect(dividerWidth, function() return height end), { MasterFramework.color.hoverColor }, nil)

    local previousScale = MasterFramework.combinedScaleFactor

    local dragStartX
    local dividerStartX
    local dividerX = (verticalSplitDividerXCache[key] or 100) * previousScale

    local hoverColor = MasterFramework.color.hoverColor

    local divider = MasterFramework:MouseOverChangeResponder(
        MasterFramework:MousePressResponder(
            dividerRect,
            function(_, x)
                dividerRect:SetDecorations({ MasterFramework.color.pressColor })
                isDragging = true
                dragStartX = x
                dividerStartX = dividerX
                return true
            end,
            function(_, x)
                local dx = x - dragStartX
                dividerX = dividerStartX + dx
                -- dividerX = math_max(math.min((minWidth() - dividerWidth()) / 2, dragStartX + dx), width - math.min((minWidth() - dividerWidth()) / 2))
                verticalSplitDividerXCache[key] = dividerX / previousScale
                split:NeedsLayout()
            end,
            function()
                dividerRect:SetDecorations({ hoverColor })
                isDragging = false
            end
        ),
        function(isOver)
            hoverColor = isOver and MasterFramework.color.selectedColor or MasterFramework.color.hoverColor
            if not isDragging then
                dividerRect:SetDecorations({ hoverColor })
            end
        end
    )

    function split:Layout(availableWidth, availableHeight)
        self:RegisterDrawingGroup()
        if previousScale ~= MasterFramework.combinedScaleFactor then
            dividerX = dividerX / previousScale * MasterFramework.combinedScaleFactor
            previousScale = MasterFramework.combinedScaleFactor
        end

        dividerX = math.min(math_max((minWidth() - dividerWidth()) / 2, dividerX), availableWidth - (minWidth() - dividerWidth()) / 2)

        if availableWidth < minWidth() then
            availableWidth = minWidth()
            dividerX = math.floor((availableWidth - dividerWidth()) / 2)
        end

        local leftWidth, leftHeight = left:Layout(dividerX, availableHeight)
        local rightWidth, rightHeight = right:Layout(availableWidth - (leftWidth + dividerWidth()), availableHeight)

        
        left._split_cachedHeight = leftHeight
        
        right._split_xOffset = leftWidth + dividerWidth()
        right._split_cachedHeight = rightHeight
        
        width = leftWidth + dividerWidth() + rightWidth
        height = math_max(leftHeight, rightHeight)
        
        divider:Layout(dividerWidth(), height)

        return width, height
    end
    function split:Position(x, y)
        left:Position(x, y + (height - left._split_cachedHeight) * yAnchor)
        right:Position(x + right._split_xOffset, y + (height - right._split_cachedHeight) * yAnchor)
        divider:Position(x + dividerX, y)
    end

    return split
end

local function TabBar(options)
    local box = MasterFramework:Box(MasterFramework:Rect(MasterFramework:AutoScalingDimension(0), MasterFramework:AutoScalingDimension(0)))
    local body = MasterFramework:MarginAroundRect(
        box,
        MasterFramework:AutoScalingDimension(0),
        MasterFramework:AutoScalingDimension(20),
        MasterFramework:AutoScalingDimension(0),
        MasterFramework:AutoScalingDimension(20)
    )

    local buttons = table.imap(options, function(index, tab)
        local titleText = MasterFramework:Text(tab.title)
        local button = MasterFramework:Button(
            titleText,
            function()
                tabBar:Select(index)
            end
        )

        button.titleText = titleText
        return button
    end)

    local tabBar
    tabBar = MasterFramework:VerticalHungryStack(
        MasterFramework:HorizontalStack(buttons, MasterFramework:AutoScalingDimension(8), 1),
        TakeAvailableWidth(body),
        MasterFramework:Rect(MasterFramework:AutoScalingDimension(0), MasterFramework:AutoScalingDimension(0)),
        0.5
    )

    local lastSelectedButton
    function tabBar:Select(index)
        if not buttons[index] then return end
        if lastSelectedButton then
            lastSelectedButton.titleText:SetBaseColor(MasterFramework:Color(1, 1, 1, 1))
        end
        lastSelectedButton = buttons[index]
        buttons[index].titleText:SetBaseColor(MasterFramework:Color(0.3, 0.6, 1, 1))
        box:SetChild(options[index].display)
    end

    tabBar:Select(1)

    return tabBar
end

local widgetPathToWidgetName = {}
local widgetNameToFileName = {}
local fileNameToWidgetName = {}
local runningWidgets = {}
local messages = {}

function ErrorDisplay(error)
    local text = MasterFramework:WrappingText("", MasterFramework.color.red)
    local errorDisplay
    errorDisplay = MasterFramework:Button(text, function()
        if errorDisplay.path then
            shownError = false
            local lineStarts, lineEnds = textEntry.text:GetRawString():lines_MasterFramework()
            SelectFile(errorDisplay.path, nil, lineStarts[error.line])
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
    
    if path == filePath then
        ConfigureErrorHighlight()
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

        if widgetPath == filePath then
            ConfigureErrorHighlight()
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

        if path == filePath then
            ConfigureErrorHighlight()
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

    --     if path == filePath then
    --         ConfigureErrorHighlight()
    --     end
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

    textEntry = WG.LuaTextEntry(MasterFramework, "", "Select File To Edit", Save)
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
            if mods.shift then
                Spring.SendCommands("luaui reload")
            elseif widgetName then
                widgetHandler:DisableWidget(widgetName)
                widgetHandler:EnableWidget(widgetName)
            end
        else
            textEntry_KeyPress(self, key, mods, isRepeat)
        end
    end
    

    local monospaceFont = MasterFramework:Font("fonts/monospaced/SourceCodePro-Medium.otf", 12)
    searchEntry = MasterFramework:TextEntry("", "Search", nil, monospaceFont)
    local searchStack = MasterFramework:VerticalStack({}, MasterFramework:AutoScalingDimension(2), 0)

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

    local function Search()
        local searchTerm = searchEntry.text:GetRawString()

        for _, result in ipairs(searchResults) do
            _ = result.highlightID and textEntry.text:RemoveHighlight(result.highlightID)
        end

        if searchTerm:len() < 3 then
            searchStack:SetMembers({})
            return
        end

        local searchBegin = 1
        searchResults = {}
        lastSelectedSearchResult = nil
        local searchee = textEntry.text:GetRawString()
        while searchBegin < searchee:len() do
            local start, _end = searchee:find(searchTerm, searchBegin)
            if start and _end then
                table.insert(searchResults, { 
                    filePath = filePath, 
                    start = start, 
                    _end = _end, 
                    highlightID = textEntry.text:HighlightRange(searchHighlightColor, start, _end + 1)
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
                    _ = lastSelectedSearchResult and textEntry.text:UpdateHighlight(lastSelectedSearchResult.highlightID, searchHighlightColor, lastSelectedSearchResult.start, lastSelectedSearchResult._end + 1)
                    textEntry.text:UpdateHighlight(result.highlightID, selectedSearchHighlightColor, result.start, result._end + 1)
                    lastSelectedSearchResult = result
                    SelectFile(result.filePath, nil, result.start)
                end
            )
        end))
        textEntry.text:NeedsRedraw()
    end

    textEntry:SetPostEditEffect(function()
        if filePath then 
            MarkFileEdited(filePath, true)
            editedFiles[filePath] = textEntry.text:GetRawString() -- Would be nice to cache the `no file` case also?
        end

        saveButton.visual:SetString("Save")
        revertButton.visual:SetString("Revert")

        Search()
    end)

    searchEntry:SetPostEditEffect(Search)

    editedFileColor = MasterFramework:Color(1, 0.6, 0.3, 1)
    savedFileColor = MasterFramework:Color(1, 1, 1, 1)

    fileNameDisplay = MasterFramework:Button(MasterFramework:Text("<no file>", MasterFramework:Color(0.3, 0.3, 0.3, 1)), function()
        showFullFilePath = not showFullFilePath
        fileNameDisplay.visual:SetString(showFullFilePath and filePath or fileName or "<no file>")
    end)
    saveButton = MasterFramework:Button(MasterFramework:Text("Save", MasterFramework:Color(0.3, 0.3, 0.6, 1)), function(button)
        Save()
    end)
    revertButton = MasterFramework:Button(MasterFramework:Text("Revert", MasterFramework:Color(0.6, 0.3, 0.3, 1)), function(button)
        if not filePath then return end
        textEntry.text:SetString(VFS.LoadFile(filePath))
        MarkFileEdited(filePath, false)
        editedFiles[filePath] = nil
    end)

    errorStack = MasterFramework:VerticalStack({}, MasterFramework:AutoScalingDimension(2), 0)

    tabBar = TabBar({
        { title = "Files", display = MasterFramework:VerticalScrollContainer(UIFolderMenu(LUAUI_DIRNAME)) },
        { title = "Search", display = MasterFramework:VerticalHungryStack(searchEntry, MasterFramework:VerticalScrollContainer(searchStack), MasterFramework:Rect(MasterFramework:AutoScalingDimension(0), MasterFramework:AutoScalingDimension(0)), 0) },
        { title = "Errors", display = errorStack },
        --{ title = "Debug", display =  },
        --{ title = "Profile", display =  }
    })

    codeScrollContainer = MasterFramework:VerticalScrollContainer(textEntry)

    local resizableFrame = MasterFramework:ResizableMovableFrame(
        "Lua File Editor",
        MasterFramework:PrimaryFrame(
                MasterFramework:Background(
                    MasterFramework:MarginAroundRect(
                    VerticalSplit(
                        tabBar,
                        MasterFramework:VerticalHungryStack(
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
                        ),
                        1,
                        "Lua File Editor Split: Side Bar & Editor 1"
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

    if filePath then
        SelectFile(filePath)
        RevealPath(filePath)
    end

    -- Capture this after we do our first SelectFile so we don't overwrite the loaded value until the UI is properly configured.
    local codeScrollContainer_viewport_SetYOffset = codeScrollContainer.viewport.SetYOffset
    local indexHighlightID
    function codeScrollContainer.viewport:SetYOffset(newYOffset)
        codeScrollContainer_viewport_SetYOffset(self, newYOffset)
        local _, yOffset = self:GetOffsets()
        local x, y = textEntry.text:CachedPositionTranslatedToGlobalContext()
        if not x or not y then return end
        local _, height = textEntry.text:Size()
        fileScrollIndices[filePath] = textEntry.text:CoordinateToCharacterDisplayIndex(x, y + height - yOffset)
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