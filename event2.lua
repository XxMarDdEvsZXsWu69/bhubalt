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

    -- ===================== SUMMER HARVEST V2 LOOP =====================
    task.spawn(function()
        while true do
            task.wait(SubmitSpeedDelay)

            if AutoSubmitPlantsEnabled and HarvestPlantSelected and HarvestPlantSelected ~= "None" then
                pcall(function()
                    -- Locate the ProximityPrompt shown in Screenshot_20260705-050811.jpg
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
                                Content = "Status: Interacting with Submit Prompt..."
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
    local fullPlantDropdownPool = table.clone(plantDropdownPool)
    
    CampfireTab:CreateInput({
    Name = "Search Fruit",
    PlaceholderText = "Type fruit name...",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        Text = tostring(Text or ""):lower()

        local filtered = {}

        if Text == "" then
            filtered = table.clone(fullPlantDropdownPool)
        else
            for _, plant in ipairs(fullPlantDropdownPool) do
                if plant:lower():find(Text, 1, true) then
                    table.insert(filtered, plant)
                end
            end
        end

        PlantDropdown:Refresh(filtered, true)
    end
})

    local PlantDropdown = CampfireTab:CreateDropdown({
        Name            = "Select Plant to Submit",
        Options         = plantDropdownPool,
        CurrentOption   = {},
        MultipleOptions = false,
        UseAutoComplete = true,
        Flag            = "eventSelectPlantToHarvest",
        Callback        = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            if choice and choice ~= "" then
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

    CampfireTab:CreateDivider()
end

return M
