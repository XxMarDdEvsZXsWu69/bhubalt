local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players           = game:GetService("Players")
    local Workspace         = game:GetService("Workspace")
    local LocalPlayer       = Players.LocalPlayer

    -- ===================== STATE =====================
    local AutoSubmitPlantsEnabled  = false
    local HarvestPlantSelected     = nil
    local SubmitSpeedDelay         = 1.0
    local HarvestParagraph         = nil

    -- ===================== SAFE WAIT-FOR =====================
    local function safeWait(parent, name, timeout)
        if not parent then return nil end
        local ok, result = pcall(function()
            return parent:WaitForChild(name, timeout or 10)
        end)
        return ok and result or nil
    end

    local function safeWaitPath(root, timeout, ...)
        local cur = root
        for _, name in ipairs({...}) do
            cur = safeWait(cur, name, timeout)
            if not cur then return nil end
        end
        return cur
    end

    -- Dynamic Dropdown Scraper for Plants Pool
    local function getAllSeedsTableV2()
        local success, result = pcall(function()
            local PlantDataModule = safeWaitPath(ReplicatedStorage, 5,
                "Modules", "GardenGuideModules", "DataModules", "PlantData")
            if PlantDataModule then
                return require(PlantDataModule).Data
            end
        end)
        return success and result or {}
    end

    local plantDropdownPool = {}
    for plantName, _ in pairs(getAllSeedsTableV2()) do
        table.insert(plantDropdownPool, tostring(plantName))
    end
    table.sort(plantDropdownPool)

    -- Helper to find the Submit Plant ProximityPrompt in the Workspace
    local function findSubmitPrompt()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.ActionText == "Submit Plant" then
                return desc
            end
        end
        return nil
    end

    -- Helper to read the High Tide Event Timer Text from your game screen billboard
    local function getHighTideTimerText()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("TextLabel") and desc.Name == "SummerHarvestTimer" then
                return desc.Text
            end
        end
        return ""
    end

    -- ===================== SUMMER HARVEST V2 LOOP =====================
    task.spawn(function()
        while true do
            task.wait(SubmitSpeedDelay)

            if AutoSubmitPlantsEnabled then
                local timerText = getHighTideTimerText()
                local isHighTideActive = true
                
                -- Checks string match against the screen notification text
                if string.find(timerText, "not started yet") or 
                   string.find(timerText, "Next") or 
                   string.find(timerText, "Minutes") or 
                   string.find(timerText, "Seconds") then
                    isHighTideActive = false
                end

                if not isHighTideActive then
                    -- Forcefully stop tool actions by unequipping back to inventory
                    local character = LocalPlayer.Character
                    if character then
                        local Humanoid = character:FindFirstChildOfClass("Humanoid")
                        if Humanoid then Humanoid:UnequipTools() end
                    end

                    if HarvestParagraph then
                        HarvestParagraph:Set({
                            Title   = "Selected Plant: " .. tostring(HarvestPlantSelected or "None"),
                            Content = "Status: STOPPED (Waiting for High Tide Harvest to start...)"
                        })
                    end
                    task.wait(1) -- Optimized loop frequency during downtime
                    continue
                end

                -- High Tide Harvest is running! Continue to processing code blocks
                if HarvestPlantSelected and HarvestPlantSelected ~= "None" then
                    pcall(function()
                        local prompt = findSubmitPrompt()

                        if not prompt then
                            if HarvestParagraph then
                                HarvestParagraph:Set({
                                    Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                    Content = "Status: High Tide Active! Searching for Submit structural prompt..."
                                })
                            end
                            return
                        end

                        local character  = LocalPlayer.Character
                        local backpack   = LocalPlayer:FindFirstChild("Backpack")
                        local foundPlant = false
                        local searchName = tostring(HarvestPlantSelected):lower()

                        if character and backpack then
                            for _, item in ipairs(character:GetChildren()) do
                                if item:IsA("Tool") and string.find(item.Name:lower(), searchName) then
                                    foundPlant = true
                                    break
                                end
                            end

                            if not foundPlant then
                                for _, item in ipairs(backpack:GetChildren()) do
                                    if item:IsA("Tool") and string.find(item.Name:lower(), searchName) then
                                        local name = item.Name:lower()
                                        if not name:find("seed") and not name:find("sprinkler")
                                            and not name:find("can") and not name:find("crate")
                                            and not name:find("tool") and not name:find("pet")
                                            and not name:find("egg") and not name:find("ticket") then
                                            item.Parent = character
                                            foundPlant  = true
                                            task.wait(0.15)
                                            break
                                        end
                                    end
                                end
                            end

                            if not foundPlant then
                                local Humanoid = character:FindFirstChildOfClass("Humanoid")
                                if Humanoid then Humanoid:UnequipTools() end
                                if HarvestParagraph then
                                    HarvestParagraph:Set({
                                        Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                        Content = "Status: High Tide Active! Stopped (Out of chosen inventory plant...)"
                                    })
                                end
                                task.wait(1)
                                return
                            end
                        end

                        if foundPlant and prompt then
                            if HarvestParagraph then
                                HarvestParagraph:Set({
                                    Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                    Content = "Status: SUBMITTING - High Tide Active!"
                                })
                            end

                            fireproximityprompt(prompt, 1)
                            task.wait(0.2)
                        end
                    end)
                else
                    if HarvestParagraph then
                        HarvestParagraph:Set({
                            Title   = "Selected Plant: None",
                            Content = "Status: High Tide is Active! Please choose a plant tool to submit."
                        })
                    end
                end
            else
                if HarvestParagraph then
                    HarvestParagraph:Set({
                        Title   = "Selected Plant: " .. tostring(HarvestPlantSelected or "None"),
                        Content = "Status: Idle / Off"
                    })
                end
            end
        end
    end)

    -- ===================== TAB UI =====================
    local CampfireTab = Window:CreateTab("Event", "gift")

    CampfireTab:CreateSection("Summer Harvest Event V2")

    HarvestParagraph = CampfireTab:CreateParagraph({
        Title   = "Selected Plant: None",
        Content = "Status: Idle / Off"
    })

    CampfireTab:CreateToggle({
        Name         = "Auto Submit Plant (High Tide)",
        CurrentValue = false,
        Flag         = "eventAutoSubmitPlantsV2",
        Callback     = function(Value)
            AutoSubmitPlantsEnabled = Value
        end,
    })

    CampfireTab:CreateDropdown({
        Name            = "Submit Process Speed",
        Options         = {"Slow (1.0s Delay)", "Fast (0.5s Delay)"},
        CurrentOption   = {"Slow (1.0s Delay)"},
        MultipleOptions = false,
        Flag            = "eventHarvestProcessSpeed",
        Callback        = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            if choice and string.find(choice, "Fast") then
                SubmitSpeedDelay = 0.5
            else
                SubmitSpeedDelay = 1.0
            end
        end,
    })

    local PlantDropdown 

    PlantDropdown = CampfireTab:CreateDropdown({
        Name            = "Select Plant to Submit",
        Options         = plantDropdownPool,
        CurrentOption   = {},
        MultipleOptions = false,
        UseAutoComplete = true,
        Flag            = "eventSelectPlantToHarvest",
        Callback        = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            if choice and choice ~= "" and choice ~= "No results found" then
                HarvestPlantSelected = choice
                if HarvestParagraph then
                    HarvestParagraph:Set({
                        Title   = "Selected Plant: " .. choice,
                        Content = "Status: Initializing..."
                    })
                end
            end
        end,
    })

    CampfireTab:CreateInput({
        Name = "Search Plant",
        PlaceholderText = "Type here",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local query = tostring(Text):lower()
            local filteredPool = {}

            if query == "" then
                filteredPool = plantDropdownPool
            else
                for _, plantName in ipairs(plantDropdownPool) do
                    if string.find(plantName:lower(), query) then
                        table.insert(filteredPool, plantName)
                    end
                end
            end

            if #filteredPool == 0 then
                table.insert(filteredPool, "No results found")
            end

            if PlantDropdown then
                PlantDropdown:Refresh(filteredPool, true)
            end
        end,
    })

    CampfireTab:CreateDivider()

    -- ===================== INTEGRATED SUMMER SEED SHOP =====================
    CampfireTab:CreateSection("Summer Seed Shop")

    local curEventName = "Summer Seed Stand"
    local function getEventItems()
        local dataTbl = require(ReplicatedStorage.Data.EventShopData)
        local listItems = {}

        for eventName, eventItems in pairs(dataTbl) do
            if eventName == curEventName or eventName:match("Summer") then
                curEventName = eventName
                for itemName, itemData in pairs(eventItems) do
                    local itemType = tostring(itemData.ItemType or "")
                    local itemToType = itemName.." | "..itemType
                    table.insert(listItems, itemToType)
                end
            end
        end

        return listItems
    end

    local allShopItems = getEventItems()
    task.wait()

    local autoBuyEventLookup = {}
    local dropdown_eventShopItems = CampfireTab:CreateDropdown({
        Name = "Select Items",
        Options = allShopItems,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "autoBuyEventShopItems",
        Callback = function(Options)
            autoBuyEventLookup = {}
            if #Options > 0 then
                for _, option in ipairs(Options) do
                    local curItemName = option:match("^(.-)%s*|")
                    if curItemName then
                        autoBuyEventLookup[curItemName] = true
                    end
                end
            end
        end,
    })

    CampfireTab:CreateButton({
        Name = "Clear Items Selection",
        Callback = function()
            dropdown_eventShopItems:Set({})
            autoBuyEventLookup = {}
        end,
    })

    local allowShopBuy = {"Summer Seed Stand", "Summer HarvestEvent"}
    local autoBuyEventShopEnabled = false

    CampfireTab:CreateToggle({
        Name = "Auto Buy Summer Shop",
        CurrentValue = false,
        Flag = "autoBuyEventShop",
        Callback = function(Value)
            autoBuyEventShopEnabled = Value
            
            if autoBuyEventShopEnabled then
                task.spawn(function()
                    local dataService = require(ReplicatedStorage.Modules.DataService)
                    
                    while autoBuyEventShopEnabled do
                        local listToBuy = dropdown_eventShopItems and dropdown_eventShopItems.CurrentOption or {}
                        
                        if #listToBuy == 0 then
                            task.wait(1)
                            continue
                        end
                        
                        local playerData = dataService:GetData()
                        local eventStock = playerData and playerData.EventShopStock
                        
                        if eventStock then
                            for eventName, eventData in pairs(eventStock) do
                                local isTargetEvent = (eventName == curEventName)
                                local isAllowedFallback = false
                                
                                for _, allowedName in ipairs(allowShopBuy) do
                                   if eventName == allowedName then
                                       isAllowedFallback = true
                                       break
                                   end
                                end
                                
                                if isTargetEvent or isAllowedFallback then
                                    local stocks = eventData.Stocks
                                    if stocks then
                                        for itemName, stockData in pairs(stocks) do
                                            local curStock = stockData.Stock
                                            
                                            if curStock and curStock > 0 and autoBuyEventLookup[itemName] then
                                                for i = 1, curStock do
                                                    if not autoBuyEventShopEnabled then break end
                                                    
                                                    local args = {
                                                        [1] = itemName,
                                                        [2] = eventName
                                                    }
                                                    ReplicatedStorage.GameEvents.BuyEventShopStock:FireServer(unpack(args))
                                                    task.wait(0.15)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(5)
                    end
                end)
            end
        end,
    })

    CampfireTab:CreateDivider()
end

return M
