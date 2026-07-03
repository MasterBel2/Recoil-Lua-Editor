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