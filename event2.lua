local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players           = game:GetService("Players")
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

    -- ===================== SUMMER HARVEST V2 LOOP =====================
    task.spawn(function()
        while true do
            task.wait(SubmitSpeedDelay)

            if AutoSubmitPlantsEnabled and HarvestPlantSelected and HarvestPlantSelected ~= "None" then
                pcall(function()
                    local ActivationRemote = safeWaitPath(LocalPlayer, 5,
                        "PlayerScripts", "InputGateway", "Activation")
                    local GameEvents   = safeWait(ReplicatedStorage, "GameEvents", 5)
                    local SubmitRemote = GameEvents and safeWaitPath(GameEvents, 5, "SummerFire", "Submit")

                    if not ActivationRemote or not SubmitRemote then
                        if HarvestParagraph then
                            HarvestParagraph:Set({
                                Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                Content = "Status: Error (Remotes missing!)"
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
                                    Content = "Status: Paused (Out of chosen plant...)"
                                })
                            end
                            task.wait(1)
                            return
                        end
                    end

                    if foundPlant then
                        if HarvestParagraph then
                            HarvestParagraph:Set({
                                Title   = "Selected Plant: " .. tostring(HarvestPlantSelected),
                                Content = "Status: Submitting to High Tide Harvest..."
                            })
                        end

                        -- Coordinates set facing toward the new sandcastle submit platform
                        local fakeCFrame = CFrame.new(
                            -184.319519, 0, 43.1255341,
                            0.830478072, 0.265547037, -0.489684522,
                            -0, 0.879065394, 0.47670123,
                            0.557051301, -0.395889908, 0.730044544
                        )
                        ActivationRemote:FireServer(true, fakeCFrame)
                        task.wait(0.1)
                        SubmitRemote:FireServer()

                        if SubmitSpeedDelay == 1.0 then
                            task.wait(0.4)
                        else
                            task.wait(0.1)
                        end
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

    -- Dynamic Dropdown tied to the Search Box
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

    -- Forward declaration so the Input element can interact with it
    local PlantDropdown 

    -- Search Box for filtering dropdown items
    CampfireTab:CreateInput({
        Name = "Search Plant...",
        PlaceholderText = "Type plant name here...",
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
