function widget:GetInfo()
	return {
		name	= "Tests",
		desc	= "Provides commands for running tests.\n\nExample usage:\n  /test path/to/test_file.lua\n  /test path/to/test_file.lua:test_name\n\n See widget code for additional documentation.",
		author	= "MasterBel2",
		date	= "June 2022",
        version = 1,
		layer	= 0,
		enabled	= false
	}
end

--[[

A test file returns a table containing:
 `targetFileName` field, which stores a string that contains the path to a file that will be loaded. This file will be re-loaded for each individual test run.
 zero or more `test_<name>` fields that will be executable tests. These tests are handed a single parameter - the environment table provided to the target file. This environment contains an abridged version of Recoil's Lua API - most importantly, most gl functions will be no-ops. See the code for further details.
 
The test file itself is run in an abridged environment. Again, see code for further details.

The target file environment provides access to local variables. Use `environment.setLocal_<local property name>()` to set a local value, `environment.getLocal_<local property name>()` to access a local value, and `environment.callLocal_<local property name>()` to call a local function.
`environment.widget` and `environment.gadget` are set to `environment`; thus the environment serves as the widget/gadget, just like how a traditional widget/gadget handler would operate.
`environment.targetFileEnvironment` also is set to `environment`


Throw an error to fail a test.
]]

-- Example test file:

--[[

return {
    targetFileName = "LuaUI/Widgets/tests.lua",
    test_pattern = function(widget)
        if not (widget.getLocal_wordPattern() == "[^%s]+") then
            error("Could not access pattern local!")
        end

        Spring.Echo("The pattern is " .. widget.getLocal_wordPattern())
    end,
    test_other = function(widget)
        if not (widget.getLocal_pathPattern() == "[^%s:]+") then
            error("Could not access pattern local!")
        end

        Spring.Echo("The pattern is " .. widget.getLocal_pathPattern())
    end
}

]]

local errorColor = "\255\200\001\001"
local warningColor = "\255\200\200\001"
local successColor = "\255\001\200\001"
local reset = "\b"

local wordPattern = "[^%s]+"
local pathPattern = "[^:]+"

local nullFunction = function() end
local DummyGLTable = {}
for key, _ in pairs(gl) do
    DummyGLTable[key] = nullFunction
end

DummyGLTable.LoadFont = function(...)
    local trueFont = gl.LoadFont(...)

    return {
        Print = nullFunction,
        SetTextColor = nullFunction,
        SetOutlineColor = nullFunction,
        SetAutoOutlineColor = nullFunction,
        GetTextWidth = function(_, ...) return trueFont:GetTextWidth(...) end,
        GetTextHeight = function(_, ...) return trueFont:GetTextHeight(...) end,
        WrapText = function(_, ...) return trueFont:WrapText(...) end,
        BindTexture = nullFunction,
        Begin = nullFunction,
        End = nullFunction,

        path = trueFont.path,
        family = trueFont.family,
        style = trueFont.style,
        size = trueFont.size,
        height = trueFont.height,
        lineheight = trueFont.lineheight,
        descender = trueFont.descender,
        outlinewidth = trueFont.outlinewidth,
        outlineweight = trueFont.outlineweight,
        texturewidth = trueFont.texturewidth,
        textureheight = trueFont.textureheight
    }
    -- font.Begin = nullFunction
    -- font.End = nullFunction
    -- font.Print = nullFunction
end


local function ForAllFiles(fileTree, action, ...)
    for fileName, table in pairs(fileTree) do

        if not type(table) == "table" then break end -- Let people put functions in there - like this one!

        if table.type == "file" then
            action(fileName, ...)
        elseif table.type == "subDir" then
            ForAllFiles(table.fileTree, action, ...)
        end
    end
end
local function FileTree(directoryName)
    local files = {}

    for _, fileName in ipairs(VFS.DirList(directoryName), "*", VFS.RAW_FIRST) do
        files[fileName] = {
            type = "file"
        }
    end
    for _, subDir in ipairs(VFS.SubDirs(directoryName), "*", VFS.RAW_FIRST) do
        files[subDir] = {
            type = "subDir",
            fileTree = FileTree(directoryName .. subDir)
        }
    end

    return files
end

local function TestFileTree(luaEnvDirectoryName)
    return FileTree(luaEnvDirectoryName .. "tests")
end

local function TestsInFile(path)
    Spring.Echo("Loading test file: " .. path)

    local testFile = VFS.LoadFile(path)
    local chunk, _error = loadstring(testFile, path)

    if not chunk or _error then
        Spring.Echo(errorColor .. "Failed to compile test file: " .. reset .. path .. " - " .. _error)
        return
    end

    local capturedFuncs = {}
    local testEnvironment = {
        error = error,
        pairs = pairs,
        ipairs = ipairs,
        type = type,
        string = table.copy(string),
        math = table.copy(math),
        table = table.copy(table),
        tostring = tostring,
        tonumber = tonumber,
        pcall = pcall,
        xpcall = xpcall,
        unpack = unpack,
        loadstring = loadstring,
        setfenv = setfenv,
        setmetatable = setmetatable,
        os = table.copy(os),
        next = next,

        captureFunc = function(func, name, preHook, postHook)
            return function(...)
                capturedFuncs[name] = capturedFuncs[name] or {}
                local capture = { args = {...}, returns = false }
                table.insert(capturedFuncs[name], capture)

                _ = preHook and preHook()
                local returns = { func(...) }
                _ = postHook and postHook()
                
                capture.returns = returns
                return unpack(returns)
            end
        end,
        capturedFuncs = capturedFuncs,

        debug = table.copy(debug),

        widgetHandler = {
            AddAction = function() end, RemoveAction = function() end, OwnText = function() return true end, DisownText = function() end,
            RegisterGlobal = function() end, DeregisterGlobal = function() end
        },

        GL = table.copy(GL),
        gl = table.copy(DummyGLTable),

        Spring = {
            Echo = Spring.Echo,
            GetTimer = Spring.GetTimerMicros,
            DiffTimers = Spring.DiffTimers,
        },
        VFS = table.copy(VFS),
        WG = {},
        GG = {},
        UnitDefNames = table.copy(UnitDefNames),
        UnitDefs =table.copy(UnitDefs),
        LUAUI_DIRNAME = LUAUI_DIRNAME,
    }
    testEnvironment.testEnvironment = testEnvironment
    setfenv(chunk, testEnvironment)
    local resultSuccess, resultValue = xpcall(chunk, debug.traceback)
    
    if not resultSuccess then
        Spring.Echo(errorColor .. "Failed to call test file: " .. reset .. path .." - " .. resultValue)
        return
    end

    resultValue.path = path

    return resultValue
end

local function RunTests(testSet, results)
    Spring.Echo("Loading target file: " .. testSet.targetFileName)
    local targetFile = VFS.LoadFile(testSet.targetFileName)
    if not targetFile then
        Spring.Echo("Failed to load target file: " .. testSet.targetFileName)
        return
    end

    -- Must start with a blank line
    targetFileLocalVariableDecoder = targetFile .."\n" .. [[
        local i = 1
        while true do
            local name, _ = debug.getlocal(1, i)
            if not name then break end

            table.insert(targetFileEnvironment.localVariableRegister, name)

            i = i + 1
        end
    ]]

    local chunk, _error = loadstring(targetFileLocalVariableDecoder, testSet.targetFileName)

    if not chunk or _error then
        Spring.Echo(errorColor .. "Failed to compile target file: " .. reset .. testSet.targetFileName .. _error)
        return
    end

    local function targetFileEnvironment()
        local targetFileEnvironment = {
            error = error,
            pairs = pairs,
            ipairs = ipairs,
            type = type,
            string = table.copy(string),
            math = table.copy(math),
            table = table.copy(table),
            tostring = tostring,
            tonumber = tonumber,
            pcall = pcall,
            xpcall = xpcall,
            unpack = unpack,
            loadstring = loadstring,
            setfenv = setfenv,
            setmetatable = setmetatable,
            os = table.copy(os),
            io = table.copy(io),
            next = next,
    
            debug = table.copy(debug),
    
            widgetHandler = { 
                AddAction = function() end, RemoveAction = function() end, OwnText = function() return true end, DisownText = function() end,
                RegisterGlobal = function() end, DeregisterGlobal = function() end
            },
            
            GL = table.copy(GL),
            gl = table.copy(DummyGLTable),
    
            Spring = table.copy(Spring),
            VFS = table.copy(VFS),
            UnitDefNames = table.copy(UnitDefNames),
            UnitDefs = table.copy(UnitDefs),
            WG = {},
            GG = {},
            LUAUI_DIRNAME = LUAUI_DIRNAME,
        }
        targetFileEnvironment.widget = targetFileEnvironment
        targetFileEnvironment.gadget = targetFileEnvironment
        targetFileEnvironment.targetFileEnvironment = targetFileEnvironment

        return targetFileEnvironment
    end

    local preloadEnvironment = targetFileEnvironment()
    preloadEnvironment.localVariableRegister = {}
    setfenv(chunk, preloadEnvironment)
    local resultSuccess, _error = xpcall(chunk, debug.traceback)

    if not resultSuccess then
        Spring.Echo(errorColor .. "Failed to generate local variables for target file: " .. reset .. testSet.targetFileName .. _error)
        return
    end

    local localVariableCaptureInjection = "\n"
    for _, localVariableName in ipairs(preloadEnvironment.localVariableRegister) do
        local newString = [[
            function getLocal_##() return ## end
            function setLocal_##(newValue) ## = newValue end
            function callLocal_##(...) return ##(...) end
        ]]

        localVariableCaptureInjection = localVariableCaptureInjection .. newString:gsub("##", localVariableName)
    end

    for key, value in pairs(testSet) do
        if key:sub(1, 4) == "test" and type(value) == "function" then
            local _SpringEcho = Spring.Echo

            local testLog = ""

            Spring.Echo = function(...)
                _SpringEcho(...)

                testLog = testLog .. "\n" .. table.concat(table.imap({ ... }, function(_, toPrint)
                    local rawString = tostring(toPrint)
                    -- local colorsRevealedString = ""
                    -- local i = 1
                    -- while i <= rawString:len() do
                    --     local character = rawString:sub(i, i)
                    --     if character == "\b" then
                    --         colorsRevealedString = colorsRevealedString .. "\\b"
                    --     elseif character == "\255" then
                    --         local x = rawString:sub(i, i + 3)
                    --         for j = 1, 4 do
                    --             if i + j > rawString:len() then return colorsRevealedString end
                    --             colorsRevealedString = colorsRevealedString .. string.format("\\%03d", string.byte(rawString:sub(i + j - 1, i + j - 1)))
                    --         end
                    --         i = i + 3
                    --     else
                    --         colorsRevealedString = colorsRevealedString .. character
                    --     end
                        
                    --     i = i + 1
                    -- end
                    -- return colorsRevealedString
                    return rawString:unEscaped_MasterFramework()
                end), ", ")
            end

            Spring.Echo("Loading test: " .. key)

            local chunk, _error = loadstring(targetFile .. localVariableCaptureInjection, testSet.targetFileName)

            if not chunk or _error then
                Spring.Echo(errorColor .. "Failed to compile target file: " .. reset .. testSet.targetFileName .. _error)
                return -- we'll return instead of breaking here, because if the file failed to load for this test, it's gonna fail to load for all tests relying on this file
            end

            local environment = targetFileEnvironment()
            environment.Spring.Echo = Spring.Echo
            environment.WG.FlowUI = WG.FlowUI
            environment.gl.CreateList = gl.CreateList
            environment.gl.DeleteLlist = gl.DeleteList

            setfenv(chunk, environment)
            local resultSuccess, _error = xpcall(chunk, debug.traceback)

            if not resultSuccess then
                Spring.Echo("Failed to pre-load target file: " .. testSet.targetFileName .. _error)
                return -- we'll return instead of breaking here, because if the file failed to load for this test, it's gonna fail to load for all tests relying on this file
            end

            Spring.Echo("Starting test: " .. key)

            local lhsBytesAllocatedBefore, lhsAllocationCountBefore, lgsBytesAllocatedBefore, lgsAllocationCountBefore = Spring.GetLuaMemUsage()
            local startTimer = Spring.GetTimer()
            local succeeded, _error = xpcall(function()
                value(environment)
            end, debug.traceback)
            local duration = Spring.DiffTimers(Spring.GetTimer(), startTimer)
            local lhsBytesAllocatedAfter, lhsAllocationCountAfter, lgsBytesAllocatedAfter, lgsAllocationCountAfter = Spring.GetLuaMemUsage()
            
            if succeeded then
                results.testsPassed = results.testsPassed + 1
                Spring.Echo(successColor .. "Test succeeded!" .. reset .. " Duration: " .. duration .. "s")
            else
                results.testsFailed = results.testsFailed + 1
                if type(_error) == "string" then
                    Spring.Echo(errorColor .. "Test failed!" .. reset .. " (Duration " .. duration .. "s) " .. key .. _error)
                else
                    Spring.Echo(errorColor .. "Test failed!" .. reset .. " (Duration " .. duration .. "s) No description available.")
                end
            end

            Spring.Echo("Memory Usage Deltas:\n - lhsBytesAllocated: " .. (lhsBytesAllocatedAfter - lhsBytesAllocatedBefore) * 1024 .. "\n - lhsAllocationCount: " .. (lhsAllocationCountAfter - lhsAllocationCountBefore) * 1000 .. "\n - lgsBytesAllocated: " .. (lgsBytesAllocatedAfter - lgsBytesAllocatedBefore) * 1024 .. "\n - lgsAllocationCount: " .. (lgsAllocationCountAfter - lgsAllocationCountBefore) * 1000)

            local testFileName = testSet.path:match(".+/([^/]+)%.lua")

            local testLogFilePath = 'LuaUI/Config/TestLogs-' .. testFileName .. '-' .. key .. ".txt"

            -- os.execute("mkdir -p " .. testLogFileDirecotry)
            local logFile = io.open(testLogFilePath, "w")
            logFile:write(testLog)
            logFile:close()

            Spring.Echo("Wrote test log to: " .. testLogFilePath)

            Spring.Echo = _SpringEcho
        end
    end
end


local function RunAllTestsInFile(path, results)
    local testsInFile = TestsInFile(path)
    if testsInFile then
        RunTests(testsInFile, results)
    else
        Spring.Echo(errorColor .. "Failed to load tests from " .. path .. reset)
    end
end

function widget:TextCommand(command)
    local start, _end = command:find(wordPattern)
    if not start or not _end then return end
    local commandName = command:sub(start, _end)
    
    if commandName ~= "test" then return false end

    start, _end = command:find(pathPattern, _end + 2)

    local results = { testsFailed = 0, testsPassed = 0 }

    if start and _end then
        local path = command:sub(start, _end)
        if VFS.FileExists(path) then

            local tests = TestsInFile(path)
            if not tests then
                Spring.Echo(errorColor .. "Could not load tests " .. reset .. "from " .. path)
                return
            end

            local start, _end = command:find(wordPattern, _end + 2)
            if start and _end then
                local testName = command:sub(start, _end)

                local test = tests[testName]
                if not test then
                    Spring.Echo(errorColor .. "Could not find test \"" .. testName .. "\" in file " .. reset)
                end

                RunTests({ path = path, targetFileName = tests.targetFileName, [testName] = test }, results)
            else
                RunTests(tests, results)
            end
        elseif #VFS.DirList(path) > 0 or #VFS.SubDirs(path) > 0 then
            ForAllFiles(FileTree(path), RunAllTestsInFile, results)
        else
            Spring.Echo(errorColor .. "Could not find any test files" .. reset .. " at " .. path)
        end
    else
        -- Spring.Echo("Running all tests in " .. LUAUI_DIRNAME .. "Widgets/tests/")
        ForAllFiles(TestFileTree(LUAUI_DIRNAME .. "widgets/"), RunAllTestsInFile, results)
        ForAllFiles(TestFileTree("luarules/gadgets/"), RunAllTestsInFile, results)
        ForAllFiles(TestFileTree("luaintro/"), RunAllTestsInFile, results)

        ForAllFiles(TestFileTree(LUAUI_DIRNAME .. "Widgets/"), RunAllTestsInFile, results)
    end

    Spring.Echo("Ran " .. results.testsFailed + results.testsPassed .. " tests: " .. successColor .. results.testsPassed .. reset .. " passed, " .. errorColor .. results.testsFailed .. reset .. " failed.")

    return true
end