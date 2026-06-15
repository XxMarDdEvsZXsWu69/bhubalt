local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService   = game:GetService("TeleportService")
    local RunService        = game:GetService("RunService")
    local Players          = game:GetService("Players")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    -- Original Crafting States
    local AutoCraftGearEnabled     = false
    local AutoCraftSeedsEnabled    = false
    local GearRecipeSelected       = nil
    local SeedRecipeSelected       = nil
    local IsCraftingGear           = false
    local IsCraftingSeeds          = false
    local GearRecipeParagraph      = nil
    local SeedRecipeParagraph      = nil

    -- Campfire States
    local AutoCraftCampfireEnabled = false
    local CampfireRecipeSelected   = nil
    local IsCraftingCampfire       = false
    local CampfireRecipeParagraph  = nil

    -- Ember Burning States
    local AutoBurnPlantsEnabled    = false
    local BurnFruitSelected        = nil
    local BurnSpeedDelay           = 1.0
    local BurnParagraph            = nil

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

    -- Dynamic Dropdown Scraper for Fruits Pool (Campfire Dependency)
    local function getAllSeedsTableV2()
        local success, result = pcall(function()
            local PlantDataModule = safeWaitPath(ReplicatedStorage, 5, "Modules", "GardenGuideModules", "DataModules", "PlantData")
            if PlantDataModule then
                return require(PlantDataModule).Data
            end
        end)
        return success and result or {}
    end

    local fruitDropdownPool = {}
    for fruitName, _ in pairs(getAllSeedsTableV2()) do
        table.insert(fruitDropdownPool, tostring(fruitName))
    end
    table.sort(fruitDropdownPool)

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

    -- Deep prompt locator function to bypass missing/hidden table models
    local function locatePromptInModel(targetModel)
        if not targetModel then return nil end
        for _, child in ipairs(targetModel:GetDescendants()) do
            if child:IsA("ProximityPrompt") and string.find(child.Name, "Crafting") then
                return child
            end
        end
        return nil
    end

    -- ===================== CRAFT LOOPS =====================

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
            
            -- Primary Search Method
            local wb = CraftingTables:FindFirstChild("EventCraftingWorkBench")
            local prompt = locatePromptInModel(wb)
            
            -- Foolproof Fallback Method: Scans all layout tables if primary target isn't named correctly
            if not prompt then
                for _, child in ipairs(CraftingTables:GetChildren()) do
                    if string.find(child.Name:lower(), "gear") or string.find(child.Name:lower(), "event") then
                        local foundPrompt = locatePromptInModel(child)
                        if foundPrompt then
                            wb = child
                            prompt = foundPrompt
                            break
                        end
                    end
                end
            end
            
            -- Absolute Last Resort: Use any table with a crafting prompt that isn't seed-based
            if not prompt then
                for _, child in ipairs(CraftingTables:GetChildren()) do
                    if not string.find(child.Name:lower(), "seed") then
                        local foundPrompt = locatePromptInModel(child)
                        if foundPrompt then
                            wb = child
                            prompt = foundPrompt
                            break
                        end
                    end
                end
            end
            
            return wb, prompt
        end

        local EventCraftingWorkBench, GearCraftingProximityPrompt = findGearWorkbench()
        if not EventCraftingWorkBench or not GearCraftingProximityPrompt then
            notify("Gear Craft Error", "Could not locate a valid Gear Workbench structure.", 10)
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

    -- ---- Seeds Loop ----
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
            
            -- Primary Search Method
            local wb = CraftingTables:FindFirstChild("SeedEventCraftingWorkBench")
            local prompt = locatePromptInModel(wb)
            
            -- Foolproof Fallback Method: Scans all layout tables if primary target isn't found
            if not prompt then
                for _, child in ipairs(CraftingTables:GetChildren()) do
                    if string.find(child.Name:lower(), "seed") then
                        local foundPrompt = locatePromptInModel(child)
                        if foundPrompt then
                            wb = child
                            prompt = foundPrompt
                            break
                        end
                    end
                end
            end
            
            return wb, prompt
        end

        local SeedCraftingWorkBench, SeedCraftingProximityPrompt = findSeedWorkbench()
        if not SeedCraftingWorkBench or not SeedCraftingProximityPrompt then
            notify("Seed Craft Error", "Could not locate a valid Seed Workbench structure.", 10)
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

    -- ---- Campfire Loop ----
    local function AutoCraftCampfireLoop()
        if IsCraftingCampfire then return end
        IsCraftingCampfire = true

        local ok, err = pcall(function()
            local GameEvents = safeWait(ReplicatedStorage, "GameEvents", 15)
            if not GameEvents then return end
            
            local SummerCraftingService = safeWait(GameEvents, "SummerCraftingService", 10)
            if not SummerCraftingService then return end

            local CampfireRoot = safeWaitPath(PlayerGui, 10,
                "SummerCrafting", "Crafting", "Main", "Campfire", "Crafting")
            
            if not CampfireRoot then
                notify("Campfire Error", "Please open the Campfire menu.", 5)
                return
            end

            while AutoCraftCampfireEnabled and CampfireRecipeSelected do
                local HasOpenSlot = false
                local HasClaim    = false

                for i = 1, 3 do
                    local SlotUI = CampfireRoot:FindFirstChild("Craft" .. i)
                    if SlotUI then
                        local TimeLeft = SlotUI:FindFirstChild("TimeLeft")
                        if TimeLeft then
                            if TimeLeft.Visible and TimeLeft.Text == "CLAIM!" then
                                HasClaim = true
                                SummerCraftingService.ClaimCraft:FireServer(i)
                                task.wait(0.3)
                            end
                            if not TimeLeft.Visible then
                                HasOpenSlot = true
                            end
                        end
                    end
                end

                if HasOpenSlot then
                    SummerCraftingService.StartCraft:FireServer(CampfireRecipeSelected)
                    task.wait(0.8)
                elseif not HasClaim then
                    task.wait(2)
                end
                task.wait(0.1)
            end
        end)

        IsCraftingCampfire = false
    end

    -- ---- Submit Fruits / Ember Burning Loop ----
    task.spawn(function()
        while true do
            task.wait(BurnSpeedDelay)
            
            if AutoBurnPlantsEnabled and BurnFruitSelected and BurnFruitSelected ~= "None" then
                pcall(function()
                    local ActivationRemote = safeWaitPath(LocalPlayer, 5, "PlayerScripts", "InputGateway", "Activation")
                    local GameEvents = safeWait(ReplicatedStorage, "GameEvents", 5)
                    local SubmitRemote = GameEvents and safeWaitPath(GameEvents, 5, "SummerFire", "Submit")
                    
                    if not ActivationRemote or not SubmitRemote then
                        if BurnParagraph then
                            BurnParagraph:Set({
                                Title = "Selected Fruit: " .. tostring(BurnFruitSelected),
                                Content = "Status: Error (Remotes missing!)"
                            })
                        end
                        return
                    end

                    local character = LocalPlayer.Character
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    local foundFruit = false
                    local searchName = tostring(BurnFruitSelected):lower()

                    if character and backpack then
                        -- Check if we are already holding the targeted fruit
                        for _, item in ipairs(character:GetChildren()) do
                            if item:IsA("Tool") and string.find(item.Name:lower(), searchName) then
                                foundFruit = true
                                break
                            end
                        end

                        -- If not holding it, look inside the backpack
                        if not foundFruit then
                            for _, item in ipairs(backpack:GetChildren()) do
                                if item:IsA("Tool") and string.find(item.Name:lower(), searchName) then
                                    local name = item.Name:lower()
                                    if not name:find("seed") and not name:find("sprinkler") and not name:find("can") and not name:find("crate") and not name:find("tool") and not name:find("pet") and not name:find("egg") and not name:find("ticket") then
                                        item.Parent = character
                                        foundFruit = true
                                        task.wait(0.15)
                                        break
                                    end
                                end
                            end
                        end

                        -- If still not found anywhere, clear tool selections
                        if not foundFruit then
                            local Humanoid = character:FindFirstChildOfClass("Humanoid")
                            if Humanoid then
                                Humanoid:UnequipTools()
                            end
                            
                            if BurnParagraph then
                                BurnParagraph:Set({
                                    Title = "Selected Fruit: " .. tostring(BurnFruitSelected), 
                                    Content = "Status: Paused (Out of chosen item...)"
                                })
                            end
                            task.wait(1)
                            return
                        end
                    end

                    if foundFruit then
                        if BurnParagraph then
                            BurnParagraph:Set({
                                Title = "Selected Fruit: " .. tostring(BurnFruitSelected), 
                                Content = "Status: Submitting Fruit..."
                            })
                        end

                        local fakeCFrame = CFrame.new(-184.319519, 0, 43.1255341, 0.830478072, 0.265547037, -0.489684522, -0, 0.879065394, 0.47670123, 0.557051301, -0.395889908, 0.730044544)
                        ActivationRemote:FireServer(true, fakeCFrame)
                        task.wait(0.1)

                        SubmitRemote:FireServer()
                        
                        if BurnSpeedDelay == 1.0 then
                            task.wait(0.4)
                        else
                            task.wait(0.1)
                        end
                    end
                end)
            else
                if BurnParagraph then
                    BurnParagraph:Set({
                        Title = "Selected Fruit: " .. tostring(BurnFruitSelected or "None"), 
                        Content = "Status: Idle / Off"
                    })
                end
            end
        end
    end)

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
        CurrentOption  = {},
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
        CurrentOption  = {},
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

    local CampfireTab = Window:CreateTab("Campfire", "flame")

    -- ---- Campfire Crafting UI ----
    CampfireTab:CreateSection("Campfire Crafting")

    CampfireRecipeParagraph = CampfireTab:CreateParagraph({
        Title   = "Selected Campfire Recipe:",
        Content = "None",
    })

    CampfireTab:CreateToggle({
        Name         = "Auto-Craft Campfire",
        CurrentValue = false,
        Flag         = "eventAutoCraftCampfire",
        Callback     = function(Value)
            AutoCraftCampfireEnabled = Value
            if Value and CampfireRecipeSelected then
                task.spawn(AutoCraftCampfireLoop)
            end
        end,
    })

    CampfireTab:CreateDropdown({
        Name    = "Campfire Recipe",
        Options = {
            "1:1:Firepit Flower", "1:2:Cauliflower", "2:1:Campfire Crate",
            "2:2:Common Summer Egg", "2:3:Green Apple", "2:4:Avocado",
            "3:1:Super Watering Can", "3:2:Areaclaimer", "3:3:Banana", "3:4:Kiwi",
            "4:1:Hearth Reed", "4:2:Rare Summer Egg", "4:3:Prickly Pear",
            "5:1:Feijoa", "5:2:Paradise Egg", "5:3:Energy Chew",
            "5:4:Pitcher Plant", "5:5:Campfire Egg",
        },
        CurrentOption   = {},
        MultipleOptions = false,
        Flag            = "eventCampfireRecipe",
        Callback        = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            CampfireRecipeSelected = (choice and choice ~= "") and choice or nil
            
            local listText = CampfireRecipeSelected or "None"
            if CampfireRecipeParagraph then
                CampfireRecipeParagraph:Set({
                    Title = "Selected Campfire Recipe:",
                    Content = listText
                })
            end

            if AutoCraftCampfireEnabled and CampfireRecipeSelected then
                task.spawn(AutoCraftCampfireLoop)
            end
        end,
    })

    CampfireTab:CreateDivider()

    -- ---- Ember Burning UI ----
    CampfireTab:CreateSection("Ember Burning")

    BurnParagraph = CampfireTab:CreateParagraph({
        Title = "Selected Fruit: None", 
        Content = "Status: Idle / Off"
    })

    CampfireTab:CreateToggle({
        Name         = "Auto Hold & Submit Fruits",
        CurrentValue = false,
        Flag         = "eventAutoBurnPlants",
        Callback     = function(Value)
            AutoBurnPlantsEnabled = Value
        end,
    })

    CampfireTab:CreateDropdown({
        Name    = "Submit Process Speed",
        Options = {"Slow (1.0s Delay)", "Fast (0.5s Delay)"},
        CurrentOption   = {"Slow (1.0s Delay)"},
        MultipleOptions = false,
        Flag            = "eventBurnProcessSpeed",
        Callback        = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            if choice and string.find(choice, "Fast") then
                BurnSpeedDelay = 0.5
            else
                BurnSpeedDelay = 1.0
            end
        end,
    })

    CampfireTab:CreateDropdown({
        Name    = "Select Fruit to Submit",
        Options = fruitDropdownPool,
        CurrentOption   = {},
        MultipleOptions = false,
        UseAutoComplete = true,
        Flag            = "eventSelectFruitToBurn",
        Callback        = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            if choice and choice ~= "" then
                BurnFruitSelected = choice
                if BurnParagraph then
                    BurnParagraph:Set({Title = "Selected Fruit: " .. choice, Content = "Status: Initializing..."})
                end
            end
        end,
    })

    CampfireTab:CreateDivider()
end

return M
