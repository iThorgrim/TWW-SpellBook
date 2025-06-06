-- Create the Adapter module
SpellBook_PagingAdapter = {}

--[[
 * Initialize the adapter and ensure the SpellBook is compatible
 * with the new version of PagedContentFrame
 *
 * @return void
]]
function SpellBook_PagingAdapter:Initialize()
    self:SetupCompatibility()
end

--[[
 * Configure compatibility between the new pagination system
 * and existing SpellBook frames
 *
 * @return void
]]
function SpellBook_PagingAdapter:SetupCompatibility()
    if not SpellBook_UI or not SpellBook_UI.PlayerFrame then
        print("SpellBook: Paging adapter could not find player frame")
        return
    end

    local frame = SpellBook_UI.PlayerFrame
    local spellBookFrame = frame.SpellBookFrame

    if not spellBookFrame then
        print("SpellBook: SpellBook frame not found")
        return
    end

    -- Configure the render mode
    spellBookFrame.renderMode = PagedContent.RenderMode.GRID

    -- Configuration for compatibility
    local config = {
        viewsPerPage = 2,
        itemsPerView = 25,
        columnWidth = 130,
        columnSpacing = 30,
        rowHeight = 35,
        rowSpacing = 15,
        headerHeight = 30,
        headerBottomMargin = 10,
        headerTopMargin = 15,
        maxColumnsPerRow = 3,
        fadeOutDuration = 0.2,
        fadeInDuration = 0.2,
        animationDelay = 0.1,
        throttleTime = 1.0,
        -- Number of additional spells to display when there's no header
        extraRowsWithoutHeader = 2
    }

    -- Apply the configuration
    spellBookFrame:Configure(config)

    -- Replace the element distribution method to account for additional rows
    self:ApplyCustomDistribution(spellBookFrame)

    -- Define a fallback for empty data (in case of search with no results)
    spellBookFrame:SetEmptyDataProviderFallback(function()
        return SpellBook_SpellFilter:FilterAllSpells()
    end)

    -- Adapt existing methods to maintain compatibility
    self:AdaptMethods(spellBookFrame)
end

--[[
 * Apply custom distribution method that accounts for additional rows
 *
 * @param spellBookFrame table The main SpellBook frame
 * @return void
]]
function SpellBook_PagingAdapter:ApplyCustomDistribution(spellBookFrame)
    if not spellBookFrame.originalSplitElementsIntoGrid then
        spellBookFrame.originalSplitElementsIntoGrid = spellBookFrame.SplitElementsIntoGrid
    end

    -- New method that accounts for additional rows
    spellBookFrame.SplitElementsIntoGrid = function(self)
        local views = {}
        local currentView = {}
        local currentHeight = 0
        local viewHeight = self.ViewFrames[1]:GetHeight()

        -- Adaptive configuration
        local headerHeight = self.config.headerHeight or 30
        local headerTopMargin = self.config.headerTopMargin or 15
        local headerBottomMargin = self.config.headerBottomMargin or 10
        local rowHeight = self.config.rowHeight or 35
        local rowSpacing = self.config.rowSpacing or 15
        local itemsPerRow = self.config.maxColumnsPerRow or 3

        -- Default and additional number of spells
        local baseMaxItemsPerView = self.config.itemsPerView or 25
        local extraRows = self.config.extraRowsWithoutHeader or 2
        local extraItemsWithoutHeader = extraRows * itemsPerRow

        -- Variable to track if current view contains a header
        local currentViewHasHeader = false

        for _, group in ipairs(self.dataProvider) do
            -- Check if this group contains a header
            local hasHeader = (group.header ~= nil)
            local elementsCount = #(group.elements or {})

            -- If this group has a header
            if hasHeader then
                -- Check if there's enough space for the header
                if currentHeight + headerHeight + headerTopMargin + headerBottomMargin > viewHeight or
                        #currentView >= baseMaxItemsPerView then
                    -- Finish current view and start a new one
                    if #currentView > 0 then
                        table.insert(views, currentView)
                        currentView = {}
                        currentHeight = 0
                        currentViewHasHeader = false
                    end
                end

                -- Add header to the view
                group.header._isHeader = true
                table.insert(currentView, group.header)
                currentHeight = currentHeight + headerHeight + headerTopMargin + headerBottomMargin
                currentViewHasHeader = true

                -- Limit to base number of elements
                maxItemsPerView = baseMaxItemsPerView
            elseif not currentViewHasHeader and #currentView == 0 then
                -- If this view doesn't have a header yet, we can display more elements
                maxItemsPerView = baseMaxItemsPerView + extraItemsWithoutHeader
            end

            -- Process elements by rows for grid mode
            local currentPos = 0

            while currentPos < elementsCount do
                local remainingInRow = math.min(itemsPerRow, elementsCount - currentPos)

                -- Check if we need a new view
                if currentHeight + rowHeight + rowSpacing > viewHeight or
                        #currentView + remainingInRow > maxItemsPerView then
                    -- Finish current view and start a new one
                    table.insert(views, currentView)
                    currentView = {}
                    currentHeight = 0
                    currentViewHasHeader = false

                    -- Update max elements for new view
                    maxItemsPerView = baseMaxItemsPerView + extraItemsWithoutHeader
                end

                -- Add elements in this row
                for i = 1, remainingInRow do
                    local element = group.elements[currentPos + i]
                    element._gridPosition = i
                    element._gridSize = remainingInRow
                    table.insert(currentView, element)
                end

                currentHeight = currentHeight + rowHeight + rowSpacing
                currentPos = currentPos + remainingInRow
            end
        end

        -- Add the last view if not empty
        if #currentView > 0 then
            table.insert(views, currentView)
        end

        return views
    end
end

--[[
 * Adapt existing methods to maintain compatibility with code 
 * that uses the old version of PagedContentFrame
 *
 * @param spellBookFrame table The main SpellBook frame
 * @return void
]]
function SpellBook_PagingAdapter:AdaptMethods(spellBookFrame)
    -- Ensure these methods remain compatible with existing code

    -- Save original SetDataProvider method
    if not spellBookFrame._orig_SetDataProvider then
        spellBookFrame._orig_SetDataProvider = spellBookFrame.SetDataProvider
    end

    -- Replace with version that handles special cases for SpellBook
    spellBookFrame.SetDataProvider = function(self, dataProvider, preservePage)
        -- For empty data, use fallback system
        if not dataProvider or #dataProvider == 0 then
            if SpellBook_SpellFilter then
                dataProvider = SpellBook_SpellFilter:FilterAllSpells()
            end
        end

        -- Call original method
        self:_orig_SetDataProvider(dataProvider, preservePage)
    end

    -- Maintain compatibility with the old method
    if not spellBookFrame.SetDataProviderWithFade then
        spellBookFrame.SetDataProviderWithFade = function(self, dataProvider)
            -- Check if the new method exists (it should exist now)
            if self._orig_SetDataProviderWithFade then
                return self:_orig_SetDataProviderWithFade(dataProvider)
            else
                -- Fallback just in case
                self:SetDataProvider(dataProvider)
            end
        end
    end

    -- Adapt UpdateElementDistribution to add hooks if needed
    if not spellBookFrame._orig_UpdateElementDistribution then
        spellBookFrame._orig_UpdateElementDistribution = spellBookFrame.UpdateElementDistribution

        spellBookFrame.UpdateElementDistribution = function(self)
            self:_orig_UpdateElementDistribution()

            -- Additional SpellBook-specific actions if needed
            if SpellBook_UI and SpellBook_UI.UpdatePageText then
                SpellBook_UI:UpdatePageText()
            end
        end
    end

    -- Adapt DisplayCurrentPage to be compatible with existing hooks
    if not spellBookFrame._orig_DisplayCurrentPage then
        spellBookFrame._orig_DisplayCurrentPage = spellBookFrame.DisplayCurrentPage

        spellBookFrame.DisplayCurrentPage = function(self)
            self:_orig_DisplayCurrentPage()

            -- Trigger UI update if needed
            if SpellBook_UI and SpellBook_UI.OnPageChanged then
                SpellBook_UI:OnPageChanged()
            end
        end
    end
end

--[[
 * Update pagination buttons to use the new system
 *
 * @param prevButton table Previous page button
 * @param nextButton table Next page button
 * @param pageText table Pagination text
 * @param spellBookFrame table Main SpellBook frame
 * @return void
]]
function SpellBook_PagingAdapter:UpdatePaginationControls(prevButton, nextButton, pageText, spellBookFrame)
    if not prevButton or not nextButton or not spellBookFrame then
        return
    end

    -- Update button behaviors
    prevButton:SetScript("OnClick", function()
        local currentPage = spellBookFrame.currentPage
        if currentPage > 1 then
            spellBookFrame:SetCurrentPageWithFade(currentPage - 1)
        end
    end)

    nextButton:SetScript("OnClick", function()
        local currentPage = spellBookFrame.currentPage
        local maxPages = spellBookFrame.maxPages
        if currentPage < maxPages then
            spellBookFrame:SetCurrentPageWithFade(currentPage + 1)
        end
    end)

    -- Update page text
    if pageText then
        spellBookFrame:RegisterCallback("OnPageChanged", function()
            if spellBookFrame.currentPage and spellBookFrame.maxPages then
                pageText:SetText(string.format("Page %d / %d", spellBookFrame.currentPage, spellBookFrame.maxPages))
            end
        end)
    end

    -- Store references
    spellBookFrame.PagingButtons = {
        Prev = prevButton,
        Next = nextButton,
        Text = pageText
    }
end

--[[
 * Utility function to convert old data formats to the new one
 *
 * @param oldData table Data in old format
 * @return table Data in format compatible with new PagedContentFrame
]]
function SpellBook_PagingAdapter:ConvertDataFormat(oldData)
    -- If format is already compatible, return as is
    if not oldData or type(oldData) ~= "table" then
        return oldData
    end

    -- Check if data is already in the correct format
    local hasCorrectFormat = true
    for _, item in ipairs(oldData) do
        if not item.header or not item.elements then
            hasCorrectFormat = false
            break
        end
    end

    if hasCorrectFormat then
        return oldData
    end

    -- Convert old format to new
    local newData = {}
    local currentGroup = nil

    for _, item in ipairs(oldData) do
        if item.isHeader then
            -- Create a new group
            currentGroup = {
                header = {
                    templateKey = "Header",
                    text = item.text or "Unknown"
                },
                elements = {}
            }
            table.insert(newData, currentGroup)
        elseif item.isElement and currentGroup then
            -- Add element to current group
            table.insert(currentGroup.elements, item)
        end
    end

    return newData
end

--[[
 * Enable or disable debug mode for PagedContentFrame
 *
 * @param enable boolean Enable or disable debug mode
 * @return void
]]
function SpellBook_PagingAdapter:EnableDebug(enable)
    if not SpellBook_UI or not SpellBook_UI.SpellBookFrame then
        print("SpellBook: Unable to find SpellBook frame for debugging")
        return
    end

    local spellBookFrame = SpellBook_UI.SpellBookFrame

    if spellBookFrame.EnableDebug then
        spellBookFrame:EnableDebug(enable or false)
        print("SpellBook: Debug mode " .. (enable and "enabled" or "disabled"))
    else
        print("SpellBook: EnableDebug method not available")
    end
end

--[[
 * Check and fix common issues in PagedContentFrame implementation
 *
 * @return void
]]
function SpellBook_PagingAdapter:DiagnoseAndFix()
    if not SpellBook_UI or not SpellBook_UI.SpellBookFrame then
        print("SpellBook: Unable to find SpellBook frame for diagnosis")
        return
    end

    local spellBookFrame = SpellBook_UI.SpellBookFrame
    local problems = 0

    print("|cFF00FF00Starting PagedContentFrame diagnosis:|r")

    -- Check if essential methods exist
    if not spellBookFrame.SetCurrentPageWithFade then
        print("|cFFFF0000Error:|r Missing SetCurrentPageWithFade method")
        problems = problems + 1
    end

    if not spellBookFrame.SetDataProviderWithFade then
        print("|cFFFF0000Error:|r Missing SetDataProviderWithFade method")
        problems = problems + 1
    end

    -- Check configuration
    if not spellBookFrame.config then
        print("|cFFFF0000Error:|r Missing configuration")
        problems = problems + 1
    else
        -- Check critical parameters
        if not spellBookFrame.config.viewsPerPage then
            print("|cFFFF0000Error:|r Missing viewsPerPage parameter in configuration")
            problems = problems + 1
        end
    end

    -- Check render mode
    if not spellBookFrame.renderMode then
        print("|cFFFF0000Error:|r Render mode not defined")
        problems = problems + 1
    end

    -- Check ViewFrames
    if not spellBookFrame.ViewFrames or #spellBookFrame.ViewFrames == 0 then
        print("|cFFFF0000Error:|r Missing or empty ViewFrames")
        problems = problems + 1
    end

    -- Check pagination buttons
    if not spellBookFrame.PagingButtons then
        print("|cFFFF0000Error:|r Missing pagination buttons")
        problems = problems + 1
    elseif not spellBookFrame.PagingButtons.Prev or not spellBookFrame.PagingButtons.Next then
        print("|cFFFF0000Error:|r Missing Prev/Next buttons")
        problems = problems + 1
    end

    -- Apply fixes if needed
    if problems > 0 then
        print(string.format("|cFFFF9900%d problem(s) detected. Attempting to fix...|r", problems))

        -- Try to reset and reconfigure PagedContentFrame
        self:ResetAndReconfigure(spellBookFrame)
    else
        print("|cFF00FF00No problems detected!|r")
    end

    -- Force display update
    if spellBookFrame.dataProvider then
        print("Forcing display update...")
        spellBookFrame:SetDataProvider(spellBookFrame.dataProvider, true)
    end
end

--[[
 * Reset and reconfigure PagedContentFrame in case of problems
 *
 * @param spellBookFrame table The main SpellBook frame
 * @return void
]]
function SpellBook_PagingAdapter:ResetAndReconfigure(spellBookFrame)
    if not spellBookFrame then return end

    -- Recreate configuration
    spellBookFrame.config = {
        viewsPerPage = 2,
        itemsPerView = 23,
        columnWidth = 130,
        columnSpacing = 30,
        rowHeight = 35,
        rowSpacing = 15,
        headerHeight = 30,
        headerBottomMargin = 10,
        headerTopMargin = 15,
        maxColumnsPerRow = 3,
        fadeOutDuration = 0.2,
        fadeInDuration = 0.2,
        animationDelay = 0.1,
        throttleTime = 1.0
    }

    -- Ensure render mode is defined
    spellBookFrame.renderMode = PagedContent.RenderMode.GRID

    -- Recheck ViewFrames
    if not spellBookFrame.ViewFrames or #spellBookFrame.ViewFrames == 0 then
        if spellBookFrame.PageView1 and spellBookFrame.PageView2 then
            spellBookFrame.ViewFrames = {spellBookFrame.PageView1, spellBookFrame.PageView2}
            print("ViewFrames reconfigured")
        else
            print("|cFFFF0000Unable to reconfigure ViewFrames: PageView1/2 not found|r")
        end
    end

    -- Recreate pagination buttons if needed
    if not spellBookFrame.PagingButtons then
        -- Buttons must be created by SpellBook_UI:CreatePaginationSystem
        print("|cFFFF9900Pagination buttons must be recreated manually|r")
    end

    -- Add flag to force update
    spellBookFrame.forceUpdate = true

    print("|cFF00FF00Reconfiguration completed|r")
end

--[[
 * Fix page synchronization issues
 *
 * @param spellBookFrame table The main SpellBook frame
 * @return boolean Whether the fix was successful
]]
function SpellBook_PagingAdapter:FixPageSynchronization(spellBookFrame)
    if not spellBookFrame then
        print("SpellBook: SpellBook frame not found")
        return false
    end

    print("Applying synchronization fixes...")

    -- Define an explicit update function for page text
    if not spellBookFrame.PageText then
        -- Look for pagination text
        for _, region in ipairs({spellBookFrame:GetRegions()}) do
            if region:GetObjectType() == "FontString" and region:GetText() and
                    region:GetText():match("Page %d+ / %d+") then
                spellBookFrame.PageText = region
                print("Pagination text automatically found")
                break
            end
        end
    end

    -- Ensure UpdatePageText method is available
    if not spellBookFrame.UpdatePageText then
        spellBookFrame.UpdatePageText = PagedContentFrameMixin.UpdatePageText
    end

    -- Create a hook to ensure text is always up to date
    if spellBookFrame.SetCurrentPage and not spellBookFrame._originalSetCurrentPage then
        spellBookFrame._originalSetCurrentPage = spellBookFrame.SetCurrentPage

        spellBookFrame.SetCurrentPage = function(self, pageNum)
            local result = self:_originalSetCurrentPage(pageNum)
            -- Force text update
            self:UpdatePageText()
            return result
        end
    end

    -- Force immediate update
    if spellBookFrame.currentPage and spellBookFrame.maxPages then
        spellBookFrame:UpdatePageText()
    end

    print("Synchronization fixes applied")
    return true
end

SLASH_SBDIAG1 = "/sbdiag"
SlashCmdList["SBDIAG"] = function(msg)
    if SpellBook_PagingAdapter then
        if msg == "debug" then
            SpellBook_PagingAdapter:EnableDebug(true)
        elseif msg == "nodebug" then
            SpellBook_PagingAdapter:EnableDebug(false)
        else
            SpellBook_PagingAdapter:DiagnoseAndFix()
        end
    else
        print("SpellBook: PagingAdapter module not available")
    end
end

SLASH_SBFIXSYNC1 = "/sbfixsync"
SlashCmdList["SBFIXSYNC"] = function()
    if SpellBook_PagingAdapter and SpellBook_UI and SpellBook_UI.SpellBookFrame then
        SpellBook_PagingAdapter:FixPageSynchronization(SpellBook_UI.SpellBookFrame)
    else
        print("SpellBook: Required components not available")
    end
end

-- Initialize the adapter
SpellBook_PagingAdapter:Initialize()