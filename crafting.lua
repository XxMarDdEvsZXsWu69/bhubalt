local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
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
    local CampfireRecipeSelected   = "1:1:Firepit Flower"
    local GearRecipeSelected       = nil
    local SeedRecipeSelected       = nil
    local IsCraftingCampfire       = false
    local IsCraftingGear           = false
    local IsCraftingSeeds          = false
    local GearRecipeParagraph      = nil
    local SeedRecipeParagraph      = nil

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

    -- ===================== SERVICES =====================
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

    local hiddenPlants    = nil
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

    -- ===================== CRAFT HELPERS =====================
    local function waitForAction(prompt, expected, timeout, enabledRef, recipeRef)
        local elapsed = 0
        while prompt.ActionText ~= expected do
            if elapsed >= timeout then return false end
            if not enabledRef() or not recipeRef() then return false end
            task.wait(0.5)
            elapsed = elapsed + 0.5
        end
        return true
    end

    -- ===================== CRAFT LOOPS =====================

    -- ---- Campfire Loop ----
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
                    repeat task.wait(2) until
                        not AutoCraftCampfireEnabled
                        or not CampfireRecipeSelected
                        or not TL1.Visible or not TL2.Visible or not TL3.Visible
                        or TL1.Text == "CLAIM!" or TL2.Text == "CLAIM!" or TL3.Text == "CLAIM!"
                end

                task.wait(0.1)
            end
        end)

        IsCraftingCampfire = false
        if not ok then
            warn("[BeastHub] AutoCraftCampfireLoop error: " .. tostring(err))
            notify("Campfire Craft Error", tostring(err):sub(1, 90), 8)
        end
    end

    -- ---- Gear Loop ----
    local function AutoCraftGearLoop()
        if IsCraftingGear then return end

        local handler = getCraftingStationHandler()
        if not handler then
            notify("Gear Craft Error", "Auto-Craft Gear is not supported on your executor.", 10)
            return
        end

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

            local p    = GearCraftingProximityPrompt
            local wb   = EventCraftingWorkBench
            local wbId = "GearEventWorkbench"
            local function gearOn()    return AutoCraftGearEnabled end
            local function gearRecipe() return GearRecipeSelected end

            while AutoCraftGearEnabled and GearRecipeSelected do
                local action = p.ActionText
                if action == "Claim" then
                    CraftService:FireServer("Claim", wb, wbId, 1)
                    waitForAction(p, "Select Recipe", 10, gearOn, gearRecipe)
                elseif action ~= "Select Recipe" and action ~= "Craft" and action ~= "Submit Item" then
                    CraftService:FireServer("Cancel", wb, wbId)
                    waitForAction(p, "Select Recipe", 10, gearOn, gearRecipe)
                end

                if not AutoCraftGearEnabled or not GearRecipeSelected then break end

                CraftService:FireServer("SetRecipe", wb, wbId, GearRecipeSelected)
                if not waitForAction(p, "Submit Item", 10, gearOn, gearRecipe) then
                    task.wait(1); continue
                end

                handler:SubmitAllRequiredItems(wb)

                local elapsed = 0
                while p.ActionText == "Submit Item" and elapsed < 10 do
                    task.wait(0.5); elapsed = elapsed + 0.5
                end

                if not AutoCraftGearEnabled or not GearRecipeSelected then break end

                CraftService:FireServer("Craft", wb, wbId)
                if not waitForAction(p, "Skip", 10, gearOn, gearRecipe) then
                    task.wait(1); continue
                end

                repeat task.wait(1) until
                    not AutoCraftGearEnabled
                    or not GearRecipeSelected
                    or p.ActionText ~= "Skip"

                if AutoCraftGearEnabled and GearRecipeSelected and p.ActionText == "Claim" then
                    CraftService:FireServer("Claim", wb, wbId, 1)
                    waitForAction(p, "Select Recipe", 10, gearOn, gearRecipe)
                end

                task.wait(0.1)
            end
        end)

        IsCraftingGear = false
        if not ok then
            warn("[BeastHub] AutoCraftGearLoop error: " .. tostring(err))
            notify("Gear Craft Error", tostring(err):sub(1, 90), 8)
        end
    end

    -- ---- Seeds Loop (Now identical to Gear Logic) ----
    local function AutoCraftSeedsLoop()
        if IsCraftingSeeds then return end

        local handler = getCraftingStationHandler()
        if not handler then
            notify("Seed Craft Error", "Auto-Craft Seeds is not supported on your executor.", 10)
            return
        end

        local function findSeedWorkbench()
            local CraftingTables = workspace:FindFirstChild("CraftingTables")
            if not CraftingTables then return nil, nil end
            local wb = CraftingTables:FindFirstChild("SeedEventCraftingWorkBench")
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

        local SeedCraftingWorkBench, SeedCraftingProximityPrompt = findSeedWorkbench()
        if not SeedCraftingWorkBench or not SeedCraftingProximityPrompt then
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

            local p    = SeedCraftingProximityPrompt
            local wb   = SeedCraftingWorkBench
            local wbId = "SeedEventWorkbench"
            local function seedOn()     return AutoCraftSeedsEnabled end
            local function seedRecipe() return SeedRecipeSelected end

            while AutoCraftSeedsEnabled and SeedRecipeSelected do
                local action = p.ActionText
                if action == "Claim" then
                    CraftService:FireServer("Claim", wb, wbId, 1)
                    waitForAction(p, "Select Recipe", 10, seedOn, seedRecipe)
                elseif action ~= "Select Recipe" and action ~= "Craft" and action ~= "Submit Item" then
                    CraftService:FireServer("Cancel", wb, wbId)
                    waitForAction(p, "Select Recipe", 10, seedOn, seedRecipe)
                end

                if not AutoCraftSeedsEnabled or not SeedRecipeSelected then break end

                -- Match dynamic recipe assignment via SetRecipe
                CraftService:FireServer("SetRecipe", wb, wbId, SeedRecipeSelected)
                if not waitForAction(p, "Submit Item", 10, seedOn, seedRecipe) then
                    task.wait(1); continue
                end

                handler:SubmitAllRequiredItems(wb)

                local elapsed = 0
                while p.ActionText == "Submit Item" and elapsed < 10 do
                    task.wait(0.5); elapsed = elapsed + 0.5
                end

                if not AutoCraftSeedsEnabled or not SeedRecipeSelected then break end

                CraftService:FireServer("Craft", wb, wbId)
                if not waitForAction(p, "Skip", 10, seedOn, seedRecipe) then
                    task.wait(1); continue
                end

                repeat task.wait(1) until
                    not AutoCraftSeedsEnabled
                    or not SeedRecipeSelected
                    or p.ActionText ~= "Skip"

                if AutoCraftSeedsEnabled and SeedRecipeSelected and p.ActionText == "Claim" then
                    CraftService:FireServer("Claim", wb, wbId, 1)
                    waitForAction(p, "Select Recipe", 10, seedOn, seedRecipe)
                end

                task.wait(0.1)
            end
        end)

        IsCraftingSeeds = false
        if not ok then
            warn("[BeastHub] AutoCraftSeedsLoop error: " .. tostring(err))
            notify("Seed Craft Error", tostring(err):sub(1, 90), 8)
        end
    end

    -- ===================== TAB UI =====================
    local Event = Window:CreateTab("Craft", "hammer")

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
        CurrentOption  = "1:1:Firepit Flower",
        MultipleOptions = false,
        Flag           = "eventCampfireRecipe",
        Callback       = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            CampfireRecipeSelected = (choice ~= "" and choice) or nil
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
            local choice = typeof(Option) == "table" and Option[1] or Option
            GearRecipeSelected = (choice and choice ~= "") and choice or nil
            
            task.spawn(function()
                if GearRecipeParagraph then
                    GearRecipeParagraph:Set("Selected Gear Recipe", GearRecipeSelected or "None")
                end
            end)

            if AutoCraftGearEnabled and GearRecipeSelected then
                task.spawn(AutoCraftGearLoop)
            end
        end,
    })
    
    GearRecipeParagraph = Event:CreateParagraph({
        Title   = "Selected Gear Recipe",
        Content = "None",
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
            local choice = typeof(Option) == "table" and Option[1] or Option
            SeedRecipeSelected = (choice and choice ~= "") and choice or nil
            
            task.spawn(function()
                if SeedRecipeParagraph then
                    SeedRecipeParagraph:Set("Selected Seed Recipe", SeedRecipeSelected or "None")
                end
            end)

            if AutoCraftSeedsEnabled and SeedRecipeSelected then
                task.spawn(AutoCraftSeedsLoop)
            end
        end,
    })
    
    SeedRecipeParagraph = Event:CreateParagraph({
        Title   = "Selected Seed Recipe",
        Content = "None",
    })

    Event:CreateDivider()
end

return M
