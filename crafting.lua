local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService  = game:GetService("TeleportService")
    local RunService       = game:GetService("RunService")
    local Players          = game:GetService("Players")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    local AutoCraftCampfireEnabled = false
    local AutoCraftGearEnabled     = false
    local AutoCraftSeedsEnabled    = false
    local CampfireRecipeSelected   = nil
    local GearRecipeSelected       = nil
    local SeedRecipeSelected       = nil
    local OrangutanSlot            = nil
    local ForgerHamsterSlot        = nil
    local PachySlot                = nil
    local IsCraftingCampfire       = false
    local IsCraftingGear           = false
    local IsCraftingSeeds          = false

    -- ===================== SAFE WAIT-FOR =====================
    -- Returns the child or nil after timeout, never errors
    local function safeWait(parent, name, timeout)
        if not parent then return nil end
        local ok, result = pcall(function()
            return parent:WaitForChild(name, timeout or 10)
        end)
        return ok and result or nil
    end

    -- Walk a path like safeWaitPath(root, 10, "A", "B", "C")
    local function safeWaitPath(root, timeout, ...)
        local cur = root
        for _, name in ipairs({...}) do
            cur = safeWait(cur, name, timeout)
            if not cur then return nil end
        end
        return cur
    end

    -- ===================== SERVICES (resolved lazily) =====================
    local function getGameEvents()
        return safeWait(ReplicatedStorage, "GameEvents", 15)
    end

    local function getCraftingStationHandler()
        local ok, handler = pcall(function()
            return require(ReplicatedStorage.Modules.CraftingStationHandler)
        end)
        return ok and handler or nil
    end

    -- ===================== HELPERS =====================
    local function notify(title, content, duration)
        Rayfield:Notify({
            Title    = title,
            Content  = content,
            Duration = duration or 6,
            Image    = beastHubIcon,
        })
    end

    local function SwapToLoadout(LoadoutNum)
        local ButtonHolder = safeWaitPath(PlayerGui,
            5, "ActivePetUI", "Frame", "Main", "PetLoadout", "Main", "ButtonHolder")
        if not ButtonHolder then return end
        local LoadoutSlot = ButtonHolder:FindFirstChild("PET_LOADOUT_" .. LoadoutNum)
        if LoadoutSlot and LoadoutSlot.BackgroundColor3 ~= Color3.fromRGB(36, 227, 36) then
            local GameEvents = getGameEvents()
            if not GameEvents then return end
            local attempts = 0
            repeat
                attempts = attempts + 1
                if attempts > 10 then break end
                GameEvents.PetsService:FireServer("SwapPetLoadout", tonumber(LoadoutNum))
                task.wait(5)
                LoadoutSlot = ButtonHolder:FindFirstChild("PET_LOADOUT_" .. LoadoutNum)
            until not LoadoutSlot or LoadoutSlot.BackgroundColor3 == Color3.fromRGB(36, 227, 36)
        end
    end

    -- ===================== FARM HELPERS =====================
    local function getMyFarmImportant()
        local Farms = workspace:FindFirstChild("Farm")
        if not Farms then return nil end
        for _, Farm in pairs(Farms:GetChildren()) do
            local Important = Farm:FindFirstChild("Important")
            local Owner = Important
                and Important:FindFirstChild("Data")
                and Important.Data:FindFirstChild("Owner")
            if Owner and Owner.Value == LocalPlayer.Name then
                return Important
            end
        end
        return nil
    end

    local hiddenPlants    = nil -- original parent when hidden
    local hiddenCosmetics = nil

    local function SetPlantVisibility(hide)
        local imp = getMyFarmImportant()
        if not imp then return end
        local plants = imp:FindFirstChild("Plants_Physical")
            or (hiddenPlants and hiddenPlants.Parent == nil and hiddenPlants)
        if not plants then return end
        if hide then
            hiddenPlants = plants
            plants.Parent = nil
        else
            if hiddenPlants then
                hiddenPlants.Parent = imp
                hiddenPlants = nil
            end
        end
    end

    local function SetCosmeticVisibility(hide)
        local imp = getMyFarmImportant()
        if not imp then return end
        local cos = imp:FindFirstChild("Cosmetic_Physical")
            or (hiddenCosmetics and hiddenCosmetics.Parent == nil and hiddenCosmetics)
        if not cos then return end
        if hide then
            hiddenCosmetics = cos
            cos.Parent = nil
        else
            if hiddenCosmetics then
                hiddenCosmetics.Parent = imp
                hiddenCosmetics = nil
            end
        end
    end

    -- ===================== CRAFT LOOPS =====================

    -- ---- Campfire ----
    local function AutoCraftCampfireLoop()
        if IsCraftingCampfire then return end
        IsCraftingCampfire = true

        local ok, err = pcall(function()
            local GameEvents = getGameEvents()
            if not GameEvents then
                notify("Campfire Error", "GameEvents not found.", 8)
                return
            end
            local SummerCraftingService = safeWait(GameEvents, "SummerCraftingService", 10)
            if not SummerCraftingService then
                notify("Campfire Error", "SummerCraftingService not found.", 8)
                return
            end

            -- Resolve the three slot TimeLeft labels
            local CampfireRoot = safeWaitPath(PlayerGui, 10,
                "SummerCrafting", "Crafting", "Main", "Campfire", "Crafting")
            if not CampfireRoot then
                notify("Campfire Error", "Campfire UI not found.", 8)
                return
            end
            local TL1 = safeWait(CampfireRoot, "Craft1", 5)
            local TL2 = safeWait(CampfireRoot, "Craft2", 5)
            local TL3 = safeWait(CampfireRoot, "Craft3", 5)
            if not (TL1 and TL2 and TL3) then
                notify("Campfire Error", "Craft slot UI not found.", 8)
                return
            end
            TL1 = TL1:WaitForChild("TimeLeft", 5)
            TL2 = TL2:WaitForChild("TimeLeft", 5)
            TL3 = TL3:WaitForChild("TimeLeft", 5)
            if not (TL1 and TL2 and TL3) then
                notify("Campfire Error", "TimeLeft labels not found.", 8)
                return
            end
            local TimesLeft = {TL1, TL2, TL3}

            while AutoCraftCampfireEnabled and CampfireRecipeSelected do
                local HasOpenSlot = false
                local HasClaim    = false

                for Index, TimeLeft in ipairs(TimesLeft) do
                    local ok2 = pcall(function()
                        if TimeLeft.Visible and TimeLeft.Text == "CLAIM!" then
                            HasClaim = true
                            SummerCraftingService.ClaimCraft:FireServer(Index)
                            task.wait(0.2)
                        end
                        if not TimeLeft.Visible then
                            HasOpenSlot = true
                        end
                    end)
                    if not ok2 then task.wait(0.5) end
                end

                if HasOpenSlot then
                    SummerCraftingService.StartCraft:FireServer(CampfireRecipeSelected)
                    task.wait(0.5)
                elseif not HasClaim then
                    -- wait until any slot opens or becomes claimable
                    repeat task.wait(2) until
                        not AutoCraftCampfireEnabled
                        or not CampfireRecipeSelected
                        or not TL1.Visible or not TL2.Visible or not TL3.Visible
                        or TL1.Text == "CLAIM!" or TL2.Text == "CLAIM!" or TL3.Text == "CLAIM!"
                end

                task.wait(0.1) -- safety throttle
            end
        end)

        IsCraftingCampfire = false
        if not ok then
            warn("[BeastHub] AutoCraftCampfireLoop error: " .. tostring(err))
            notify("Campfire Craft Error", tostring(err):sub(1, 90), 8)
        end
    end

    -- ---- Gear ----
    local function AutoCraftGearLoop()
        if IsCraftingGear then return end

        local handler = getCraftingStationHandler()
        if not handler then
            notify("Gear Craft Error", "Auto-Craft Gear is not supported on your executor.", 10)
            return
        end

        -- Resolve workbench + proximity prompt
        local function findGearWorkbench()
            local CraftingTables = workspace:FindFirstChild("CraftingTables")
            if not CraftingTables then return nil, nil end
            local wb = CraftingTables:FindFirstChild("EventCraftingWorkBench")
            if not wb then return nil, nil end
            local prompt = nil
            for _, Model in ipairs(wb:GetChildren()) do
                if Model.Name == "Model" then
                    for _, Part in ipairs(Model:GetChildren()) do
                        if #Part:GetChildren() > 0 then
                            local p = Part:FindFirstChild("CraftingProximityPrompt")
                            if p then prompt = p; break end
                        end
                    end
                end
                if prompt then break end
            end
            return wb, prompt
        end

        local EventCraftingWorkBench, GearCraftingProximityPrompt = findGearWorkbench()
        if not EventCraftingWorkBench or not GearCraftingProximityPrompt then
            notify("Gear Craft Error", "You cannot craft items in tutorial servers.", 10)
            return
        end

        IsCraftingGear = true

        local ok, err = pcall(function()
            local GameEvents = getGameEvents()
            if not GameEvents then
                notify("Gear Craft Error", "GameEvents not found.", 8)
                return
            end
            local CraftService = GameEvents:FindFirstChild("CraftingGlobalObjectService")
            if not CraftService then
                notify("Gear Craft Error", "CraftingGlobalObjectService not found.", 8)
                return
            end

            while AutoCraftGearEnabled and GearRecipeSelected do
                -- Reset to clean state if not on Select Recipe
                local action = GearCraftingProximityPrompt.ActionText
                if action ~= "Select Recipe" then
                    if action == "Claim" then
                        if PachySlot then SwapToLoadout(PachySlot) end
                        CraftService:FireServer("Claim", EventCraftingWorkBench, "GearEventWorkbench", 1)
                        task.wait(1)
                    elseif action ~= "Skip" then
                        CraftService:FireServer("Cancel", EventCraftingWorkBench, "GearEventWorkbench")
                        task.wait(1)
                    end
                end

                -- Set recipe
                CraftService:FireServer("SetRecipe", EventCraftingWorkBench, "GearEventWorkbench", GearRecipeSelected)
                task.wait(1)

                -- Swap to Orangutans before submitting
                if GearCraftingProximityPrompt.ActionText == "Submit Item" and OrangutanSlot then
                    SwapToLoadout(OrangutanSlot)
                end

                -- Submit all required items
                handler:SubmitAllRequiredItems(EventCraftingWorkBench)
                task.wait(1)

                if not AutoCraftGearEnabled or not GearRecipeSelected then break end

                -- Fire craft
                CraftService:FireServer("Craft", EventCraftingWorkBench, "GearEventWorkbench")
                task.wait(1)

                -- Swap to Forger/Hamster while crafting is in progress
                if GearCraftingProximityPrompt.ActionText == "Skip" and ForgerHamsterSlot then
                    SwapToLoadout(ForgerHamsterSlot)
                end

                -- Wait for craft to finish
                repeat task.wait(2) until
                    not AutoCraftGearEnabled
                    or not GearRecipeSelected
                    or GearCraftingProximityPrompt.ActionText ~= "Skip"

                -- Claim if still running
                if AutoCraftGearEnabled and GearRecipeSelected then
                    if GearCraftingProximityPrompt.ActionText == "Claim" and PachySlot then
                        SwapToLoadout(PachySlot)
                    end
                    CraftService:FireServer("Claim", EventCraftingWorkBench, "GearEventWorkbench", 1)
                    task.wait(1)
                end

                task.wait(0.1) -- safety throttle
            end
        end)

        IsCraftingGear = false
        if not ok then
            warn("[BeastHub] AutoCraftGearLoop error: " .. tostring(err))
            notify("Gear Craft Error", tostring(err):sub(1, 90), 8)
        end
    end

    -- ---- Seeds ----
    local function AutoCraftSeedsLoop()
        if IsCraftingSeeds then return end

        local handler = getCraftingStationHandler()
        if not handler then
            notify("Seed Craft Error", "Auto-Craft Seeds is not supported on your executor.", 10)
            return
        end

        -- Resolve seed workbench
        local function findSeedWorkbench()
            local CraftingTables = workspace:FindFirstChild("CraftingTables")
            if not CraftingTables then return nil, nil end
            local wb = CraftingTables:FindFirstChild("SeedEventCraftingWorkBench")
            if not wb then return nil, nil end
            local Model = wb:FindFirstChild("Model")
            if not Model then return nil, nil end
            local BenchTable = Model:FindFirstChild("BenchTable")
            if not BenchTable then return nil, nil end
            local prompt = BenchTable:FindFirstChild("CraftingProximityPrompt")
            return wb, prompt
        end

        local SeedWorkbench, SeedPrompt = findSeedWorkbench()
        if not SeedWorkbench or not SeedPrompt then
            notify("Seed Craft Error", "You cannot craft items in tutorial servers.", 10)
            return
        end

        IsCraftingSeeds = true

        local ok, err = pcall(function()
            local GameEvents = getGameEvents()
            if not GameEvents then
                notify("Seed Craft Error", "GameEvents not found.", 8)
                return
            end
            local CraftService = GameEvents:FindFirstChild("CraftingGlobalObjectService")
            if not CraftService then
                notify("Seed Craft Error", "CraftingGlobalObjectService not found.", 8)
                return
            end

            while AutoCraftSeedsEnabled and SeedRecipeSelected do
                -- Re-find workbench each iteration in case it reloads
                local wb, prompt = findSeedWorkbench()
                if not wb or not prompt then
                    task.wait(2)
                    -- try once more
                    wb, prompt = findSeedWorkbench()
                    if not wb or not prompt then
                        notify("Seed Craft Error", "Seed workbench lost. Stopping.", 8)
                        break
                    end
                end

                -- Reset to clean state
                local action = prompt.ActionText
                if action ~= "Select Recipe" then
                    if action == "Claim" then
                        if PachySlot then SwapToLoadout(PachySlot) end
                        CraftService:FireServer("Claim", wb, "SeedEventWorkbench", 1)
                        task.wait(1)
                    elseif action ~= "Skip" then
                        CraftService:FireServer("Cancel", wb, "SeedEventWorkbench")
                        task.wait(1)
                    end
                end

                -- Set recipe
                CraftService:FireServer("SetRecipe", wb, "SeedEventWorkbench", SeedRecipeSelected)
                task.wait(1)

                -- Swap to Orangutans before submitting
                if OrangutanSlot and prompt.ActionText == "Submit Item" then
                    SwapToLoadout(OrangutanSlot)
                end

                -- Submit all required items
                handler:SubmitAllRequiredItems(wb)
                task.wait(1)

                if not AutoCraftSeedsEnabled or not SeedRecipeSelected then break end

                -- Fire craft
                CraftService:FireServer("Craft", wb, "SeedEventWorkbench")
                task.wait(1)

                -- Swap to Forger/Hamster while crafting
                if ForgerHamsterSlot and prompt.ActionText == "Skip" then
                    SwapToLoadout(ForgerHamsterSlot)
                end

                -- Wait for craft to finish
                repeat task.wait(2) until
                    not AutoCraftSeedsEnabled
                    or not SeedRecipeSelected
                    or prompt.ActionText ~= "Skip"

                -- Claim if still running
                if AutoCraftSeedsEnabled and SeedRecipeSelected then
                    if PachySlot and prompt.ActionText == "Claim" then
                        SwapToLoadout(PachySlot)
                    end
                    CraftService:FireServer("Claim", wb, "SeedEventWorkbench", 1)
                    task.wait(1)
                end

                task.wait(0.1) -- safety throttle
            end
        end)

        IsCraftingSeeds = false
        if not ok then
            warn("[BeastHub] AutoCraftSeedsLoop error: " .. tostring(err))
            notify("Seed Craft Error", tostring(err):sub(1, 90), 8)
        end
    end

    -- ===================== TAB UI =====================
    local Event = Window:CreateTab("Event", "hammer")

    -- ---- Campfire Crafting ----
    Event:CreateSection("Campfire Crafting")

    Event:CreateToggle({
        Name         = "Auto-Craft Campfire Recipe",
        CurrentValue = false,
        Flag         = "eventAutoCraftCampfire",
        Callback     = function(Value)
            AutoCraftCampfireEnabled = Value
            if Value and CampfireRecipeSelected then
                task.spawn(AutoCraftCampfireLoop)
            end
        end,
    })

    Event:CreateDropdown({
        Name    = "Campfire Recipe",
        Options = {
            "1:1:Firepit Flower", "1:2:Cauliflower", "2:1:Campfire Crate",
            "2:2:Common Summer Egg", "2:3:Green Apple", "2:4:Avocado",
            "3:1:Super Watering Can", "3:2:Areaclaimer", "3:3:Banana", "3:4:Kiwi",
            "4:1:Hearth Reed", "4:2:Rare Summer Egg", "4:3:Prickly Pear",
            "5:1:Feijoa", "5:2:Paradise Egg", "5:3:Energy Chew",
            "5:4:Pitcher Plant", "5:5:Campfire Egg",
        },
        CurrentOption  = {},
        MultipleOptions = false,
        Flag           = "eventCampfireRecipe",
        Callback       = function(Option)
            CampfireRecipeSelected = (Option ~= "" and Option) or nil
            if AutoCraftCampfireEnabled and CampfireRecipeSelected then
                task.spawn(AutoCraftCampfireLoop)
            end
        end,
    })

    Event:CreateDivider()

    -- ---- Gear Crafting ----
    Event:CreateSection("Gear Crafting")

    Event:CreateToggle({
        Name         = "Auto-Craft Gear",
        CurrentValue = false,
        Flag         = "eventAutoCraftGear",
        Callback     = function(Value)
            AutoCraftGearEnabled = Value
            if Value and GearRecipeSelected then
                task.spawn(AutoCraftGearLoop)
            end
        end,
    })

    Event:CreateDropdown({
        Name    = "Gear Recipe",
        Options = {
            "Lightning Rod", "Tanning Mirror", "Reclaimer", "Event Lantern",
            "Anti Bee Egg", "Small Toy", "Small Treat", "Pet Pouch", "Pack Bee",
            "Silver Ingot", "Gold Ingot", "Chimera Stone", "Black Spotty Egg",
            "Tropical Mist Sprinkler", "Berry Blusher Sprinkler", "Spice Spritzer Sprinkler",
            "Flower Froster Sprinkler", "Stalk Sprout Sprinkler", "Sweet Soaker Sprinkler",
            "Mutation Spray Pollinated", "Honey Crafters Crate", "Mutation Spray Glimmering",
            "Mutation Spray Chilled", "Mutation Spray Shocked", "Mutation Spray Choc",
        },
        CurrentOption  = {},
        MultipleOptions = false,
        Flag           = "eventGearRecipe",
        Callback       = function(Option)
            GearRecipeSelected = (Option ~= "" and Option) or nil
            if AutoCraftGearEnabled and GearRecipeSelected then
                task.spawn(AutoCraftGearLoop)
            end
        end,
    })

    Event:CreateDivider()

    -- ---- Seed Crafting ----
    Event:CreateSection("Seed Crafting")

    Event:CreateToggle({
        Name         = "Auto-Craft Seeds",
        CurrentValue = false,
        Flag         = "eventAutoCraftSeeds",
        Callback     = function(Value)
            AutoCraftSeedsEnabled = Value
            if Value and SeedRecipeSelected then
                task.spawn(AutoCraftSeedsLoop)
            end
        end,
    })

    Event:CreateDropdown({
        Name    = "Seed Recipe",
        Options = {
            "Egg Melon", "Mandrake", "Evo Apple I", "Evo Apple II", "Evo Apple III",
            "Evo Apple IV", "Olive", "Hollow Bamboo", "Yarrow", "Grand Volcania",
            "Peace Lily", "Aloe Vera", "Guanabana", "Crafters Seed Pack",
            "Manuka Flower", "Dandelion", "Lumira", "Honeysuckle", "Bee Balm",
            "Nectar Thorn", "Suncoil", "Twisted Tangle", "Veinpetal",
            "Horsetail", "Lingonberry", "Amber Spine",
        },
        CurrentOption  = {},
        MultipleOptions = false,
        Flag           = "eventSeedRecipe",
        Callback       = function(Option)
            SeedRecipeSelected = (Option ~= "" and Option) or nil
            if AutoCraftSeedsEnabled and SeedRecipeSelected then
                task.spawn(AutoCraftSeedsLoop)
            end
        end,
    })

    Event:CreateDivider()

  

    -- ===================== UTILITIES TAB =====================
    local UtilTab = Window:CreateTab("Utilities", "zap")

    local AutoHoldSubmitEnabled = false

    UtilTab:CreateToggle({
        Name         = "Auto Hold & Submit Fruits",
        CurrentValue = false,
        Flag         = "eventAutoHoldSubmit",
        Callback     = function(Value)
            AutoHoldSubmitEnabled = Value
            task.spawn(function()
                local ActivationRemote = safeWaitPath(LocalPlayer, 15,
                    "PlayerScripts", "InputGateway", "Activation")
                if not ActivationRemote then
                    notify("Utilities Error", "Activation remote not found.", 8)
                    return
                end

                local GameEventsFolder = getGameEvents()
                local SubmitRemote = GameEventsFolder
                    and safeWaitPath(GameEventsFolder, 10, "SummerFire", "Submit")
                if not SubmitRemote then
                    notify("Utilities Error", "SummerFire Submit remote not found.", 8)
                    return
                end

                while AutoHoldSubmitEnabled do
                    local character = LocalPlayer.Character
                    local backpack  = LocalPlayer:FindFirstChild("Backpack")
                    local foundFruit = false

                    if character and backpack then
                        for _, item in ipairs(backpack:GetChildren()) do
                            if item:IsA("Tool") then
                                local name = item.Name:lower()
                                if not name:find("seed")
                                    and not name:find("sprinkler")
                                    and not name:find("can")
                                    and not name:find("crate")
                                    and not name:find("tool")
                                    and not name:find("pet")
                                    and not name:find("egg")
                                    and not name:find("ticket")
                                then
                                    item.Parent = character
                                    foundFruit = true
                                    task.wait(0.1)
                                    break
                                end
                            end
                        end

                        if not foundFruit then
                            local Humanoid = character:FindFirstChildOfClass("Humanoid")
                            if Humanoid then Humanoid:UnequipTools() end
                        end
                    end

                    if foundFruit then
                        local fakeCFrame = CFrame.new(
                            -184.319519, 0, 43.1255341,
                            0.830478072, 0.265547037, -0.489684522,
                            -0, 0.879065394, 0.47670123,
                            0.557051301, -0.395889908, 0.730044544
                        )
                        ActivationRemote:FireServer(true, fakeCFrame)
                        task.wait(0.1)
                        SubmitRemote:FireServer()
                        task.wait(0.4)
                    else
                        task.wait(1)
                    end
                end
            end)
        end,
    })
end

return M
