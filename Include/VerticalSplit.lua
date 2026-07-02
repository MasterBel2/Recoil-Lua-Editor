verticalSplitDividerXCache = {}

function VerticalSplit(left, right, yAnchor, key, proportionallyResize)
    local split = MasterFramework:Component(true, false)
    local isDragging

    local minWidth = MasterFramework:AutoScalingDimension(40)

    local dividerWidth = MasterFramework:AutoScalingDimension(2)
    local previousAvailableWidth
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

        if proportionallyResize and (availableWidth ~= previousAvailableWidth) then
            proportion = availableWidth / (previousAvailableWidth or availableWidth)
            previousAvailableWidth = availableWidth
            dividerX = dividerX * proportion
        end

        dividerX = math.min(math.max((minWidth() - dividerWidth()) / 2, dividerX), availableWidth - (minWidth() - dividerWidth()) / 2)

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
        height = math.max(leftHeight, rightHeight)
        
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