function TabBar(options)
    local tabBar
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