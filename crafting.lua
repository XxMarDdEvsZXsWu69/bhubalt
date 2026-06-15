local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService   = game:GetService("TeleportService")
    local RunService       = game:GetService("RunService")
    local Players          = game:GetService("Players")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    local AutoCraftGearEnabled     = false
    local AutoCraftSeedsEnabled    = false
    local GearRecipeSelected       = nil
    local SeedRecipeSelected       = nil
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

    -- ===================== MOCK PROXIMITY PROMPT FOR BYPASS =====================
    local function generateMockPrompt()
        return { ActionText = "Select Recipe" }
    end

    -- ===================== CRAFT LOOPS =====================

    -- ---- Gear Loop (Bypassed) ----
    local function AutoCraftGearLoop()
        if IsCraftingGear then return end

        local handler = getCraftingStationHandler()
        if not handler then
            notify("Gear Craft Error", "Auto-Craft Gear is not supported on your executor.", 10)
            return
        end

        -- Bypass active search: Look for the real workbench if it exists, otherwise pass an empty instance container to bypass the nil block
        local CraftingTables = workspace:FindFirstChild("CraftingTables")
        local RealWorkbench = CraftingTables and CraftingTables:FindFirstChild("EventCraftingWorkBench")
        local EventCraftingWorkBench = RealWorkbench or Instance.new("Folder") 
        
        -- Create a fake prompt to prevent script crashing during verification loops
        local p = generateMockPrompt()
        local wb = EventCraftingWorkBench
        local wbId = "GearEventWorkbench"

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
                -- Direct remote bypass firing sequences
                CraftService:FireServer("Claim", wb, wbId, 1)
                task.wait(0.3)
                
                if not AutoCraftGearEnabled or not GearRecipeSelected then break end

                CraftService:FireServer("SetRecipe", wb, wbId, GearRecipeSelected)
                task.wait(0.5)

                if RealWorkbench and handler.SubmitAllRequiredItems then
                    pcall(function() handler:SubmitAllRequiredItems(wb) end)
                end
                task.wait(0.5)

                if not AutoCraftGearEnabled or not GearRecipeSelected then break end

                CraftService:FireServer("Craft", wb, wbId)
                task.wait(0.5)
                
                CraftService:FireServer("Claim", wb, wbId, 1)
                task.wait(1)
            end
        end)

        IsCraftingGear = false
        if not ok then
            warn("[BeastHub] AutoCraftGearLoop error: " .. tostring(err))
            notify("Gear Craft Error", tostring(err):sub(1, 90), 8)
        end
    end

    -- ---- Seeds Loop (Bypassed) ----
    local function AutoCraftSeedsLoop()
        if IsCraftingSeeds then return end

        local handler = getCraftingStationHandler()
        if not handler then
            notify("Seed Craft Error", "Auto-Craft Seeds is not supported on your executor.", 10)
            return
        end

        -- Bypass active search
        local CraftingTables = workspace:FindFirstChild("CraftingTables")
        local RealWorkbench = CraftingTables and CraftingTables:FindFirstChild("SeedEventCraftingWorkBench")
        local SeedCraftingWorkBench = RealWorkbench or Instance.new("Folder")

        local p = generateMockPrompt()
        local wb = SeedCraftingWorkBench
        local wbId = "SeedEventWorkbench"

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
                -- Direct remote bypass firing sequences
                CraftService:FireServer("Claim", wb, wbId, 1)
                task.wait(0.3)

                if not AutoCraftSeedsEnabled or not SeedRecipeSelected then break end

                CraftService:FireServer("SetRecipe", wb, wbId, SeedRecipeSelected)
                task.wait(0.5)

                if RealWorkbench and handler.SubmitAllRequiredItems then
                    pcall(function() handler:SubmitAllRequiredItems(wb) end)
                end
                task.wait(0.5)

                if not AutoCraftSeedsEnabled or not SeedRecipeSelected then break end

                CraftService:FireServer("Craft", wb, wbId)
                task.wait(0.5)

                CraftService:FireServer("Claim", wb, wbId, 1)
                task.wait(1)
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

    -- ---- Gear Crafting ----
    Event:CreateSection("Gear Crafting")

    GearRecipeParagraph = Event:CreateParagraph({
        Title   = "Selected Gear Recipe:",
        Content = "None",
    })

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
        CurrentOption   = {},
        MultipleOptions = false,
        Flag           = "eventGearRecipe",
        Callback       = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            GearRecipeSelected = (choice and choice ~= "") and choice or nil
            
            local listText = GearRecipeSelected or "None"
            if GearRecipeParagraph then
                GearRecipeParagraph:Set({
                    Title = "Selected Gear Recipe:",
                    Content = listText
                })
            end

            if AutoCraftGearEnabled and GearRecipeSelected then
                task.spawn(AutoCraftGearLoop)
            end
        end,
    })
    
    Event:CreateDivider()

    -- ---- Seed Crafting ----
    Event:CreateSection("Seed Crafting")

    SeedRecipeParagraph = Event:CreateParagraph({
        Title   = "Selected Seed Recipe:",
        Content = "None",
    })

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
        CurrentOption   = {},
        MultipleOptions = false,
        Flag           = "eventSeedRecipe",
        Callback       = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            SeedRecipeSelected = (choice and choice ~= "") and choice or nil
            
            local listText = SeedRecipeSelected or "None"
            if SeedRecipeParagraph then
                SeedRecipeParagraph:Set({
                    Title = "Selected Seed Recipe:",
                    Content = listText
                })
            end

            if AutoCraftSeedsEnabled and SeedRecipeSelected then
                task.spawn(AutoCraftSeedsLoop)
            end
        end,
    })

    Event:CreateDivider()
end

return M
