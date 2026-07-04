local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players           = game:GetService("Players")
    local Workspace         = game:GetService("Workspace")
    local LocalPlayer       = Players.LocalPlayer

    -- ===================== STATE =====================
    local AutoSubmitPlantsEnabled  = false
    local AutoTakeFruitsEnabled    = false -- New state variable
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

    -- Helper to find Georgia's Talk ProximityPrompt
    local function findGeorgiaPrompt()
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.ActionText == "Talk" and desc.Parent and desc.Parent.Name == "Georgia" then
                return desc
            end
            -- Fallback if the parent isn't named Georgia but the prompt text matches
            if desc:IsA("ProximityPrompt") and desc.ActionText == "Talk" and desc.Parent and desc.Parent:FindFirstChild("Georgia") then
                return desc
            end
        end
        -- General fallback for any "Talk" prompt near the event area if structure names differ
        for _, desc in ipairs(Workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.ActionText == "Talk" then
                return desc
            end
        end
        return nil
    end
    
    -- Returns true only while High Tide Harvest is ACTIVE
    local function isHighTideHarvestRunning()
        local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not PlayerGui then
            return false
        end

        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") then
                local txt = tostring(obj.Text)

                -- Waiting timer
                if txt:find("Next High Tide Harvest") then
                    return false
                end

                -- Event has started
                if txt:find("High Tide Harvest") and not txt:find("Next") then
                    return true
                end
            end
        end

        return false
    end

    -- ===================== AUTO TAKE ALL FRUITS LOOP =====================
    task.spawn(function()
        while true do
            task.wait(1.5) -- Reasonable loop delay to prevent spamming while waiting
            
            if AutoTakeFruitsEnabled then
                if isHighTideHarvestRunning() then
                    pcall(function()
                        local prompt = findGeorgiaPrompt()
                        if prompt then
                            fireproximityprompt(prompt, 1)
                            
                            -- Handle selecting option #2 ["Take all my summer fruits"] if a dialogue UI pops up
                            task.wait(0.3)
                            local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
                            if PlayerGui then
                                for _, obj in ipairs(PlayerGui:GetDescendants()) do
                                    if obj:IsA("TextLabel") and (obj.Text:find("Take all my summer fruits") or obj.Text:find("Take all my summer")) then
                                        -- Try to click the parent button of the text label
                                        local button = obj:FindFirstAncestorOfClass("TextButton") or obj.Parent:IsA("TextButton") and obj.Parent
                                        if button then
                                            local virtualInput = game:GetService("VirtualInputManager")
                                            virtualInput:SendMouseButtonEvent(button.AbsolutePosition.X + (button.AbsoluteSize.X / 2), button.AbsolutePosition.Y + (button.AbsoluteSize.Y / 2), 0, true, game, 1)
                                            virtualInput:SendMouseButtonEvent(button.AbsolutePosition.X + (button.AbsoluteSize.X / 2), button.AbsolutePosition.Y + (button.AbsoluteSize.Y / 2), 0, false, game, 1)
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)

    -- ===================== SUMMER HARVEST V2 LOOP =====================
    task.spawn(function()
        while true do
            task.wait(SubmitSpeedDelay)

            if AutoSubmitPlantsEnabled
            and HarvestPlantSelected
            and HarvestPlantSelected ~= "None" then
                -- Pause while High Tide is not active
                if not isHighTideHarvestRunning() then
                    if HarvestParagraph then
                        HarvestParagraph:Set({
                            Title = "Selected Plant: " .. tostring(HarvestPlantSelected),
                            Content = "Status: Waiting for High Tide Harvest..."
                            
                        })
                    end
                    task.wait(1)
                    continue
                end
                pcall(function()
                    local prompt = findSubmitPrompt()

                    if not prompt then
                        if HarvestParagraph then
                            HarvestParagraph:Set({
                                Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                Content = "Status: Waiting for 'Submit Plant' structure/prompt..."
                            })
                        end
                        return
                    end

                    local character  = LocalPlayer.Character
                    local backpack   = LocalPlayer:FindFirstChild("Backpack")
                    local foundPlant = false
                    local searchName = tostring(HarvestPlantSelected):lower()

                    if character and backpack then
                        -- Check if currently equipped
                        for _, item in ipairs(character:GetChildren()) do
                            if item:IsA("Tool") and string.find(item.Name:lower(), searchName) then
                                foundPlant = true
                                break
                            end
                        end

                        -- Equip from Backpack if needed
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

                        -- Handle scenario where the plant asset runs out
                        if not foundPlant then
                            local Humanoid = character:FindFirstChildOfClass("Humanoid")
                            if Humanoid then Humanoid:UnequipTools() end
                            if HarvestParagraph then
                                HarvestParagraph:Set({
                                    Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                    Content = "Status: Paused (Out of chosen plant...)"
                                })
                            end
                            task.wait(1)
                            return
                        end
                    end

                    -- Fire interaction with the prompt directly
                    if foundPlant and prompt then
                        if HarvestParagraph then
                            HarvestParagraph:Set({
                                Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                Content = "Status: High Tide Active - Auto Submitting..."
                            })
                        end

                        -- Triggers the ProximityPrompt action directly
                        fireproximityprompt(prompt, 1)
                        task.wait(0.2)
                    end
                end)
            else
                if HarvestParagraph then
                    HarvestParagraph:Set({
                        Title   = "Selected Plant: " .. tostring(HarvestPlantSelected or "None"),
                        Content = "Status: Idle / Off (Waiting for High Tide Harvest)"
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

    -- NEW TOGGLE FOR GEORGIA NPC FRUIT HARVEST
    CampfireTab:CreateToggle({
        Name         = "Auto Take All Summer Fruits",
        CurrentValue = false,
        Flag         = "eventAutoTakeSummerFruits",
        Callback     = function(Value)
            AutoTakeFruitsEnabled = Value
        end,
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
            end
        end,
    })

    -- Forward declaration so the Input element below can interact with it
    local PlantDropdown 

    -- Dynamic Dropdown
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

    -- Search Box placed AFTER the dropdown, tied directly to it
    CampfireTab:CreateInput({
        Name = "Search Plant",
        PlaceholderText = "Type here",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local query = tostring(Text):lower()
            local filteredPool = {}

            -- Filter the main list based on query
            if query == "" then
                filteredPool = plantDropdownPool
            else
                for _, plantName in ipairs(plantDropdownPool) do
                    if string.find(plantName:lower(), query) then
                        table.insert(filteredPool, plantName)
                    end
                end
            end

            -- Automatically push "None" fallback if no search items match
            if #filteredPool == 0 then
                table.insert(filteredPool, "No results found")
            end

            -- Update Rayfield Dropdown elements dynamically
            if PlantDropdown then
                PlantDropdown:Refresh(filteredPool, true)
            end
        end,
    })

    CampfireTab:CreateDivider()
end

return M
