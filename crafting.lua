local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, beastHubIcon)
    local HttpService = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local GameEvents = ReplicatedStorage:FindFirstChild("GameEvents")
    local TeleportService = game:GetService("TeleportService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local PlayerGui = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    local AutoCraftCampfireEnabled = false
    local AutoCraftGearEnabled = false
    local AutoCraftSeedsEnabled = false
    local CampfireRecipeSelected = nil
    local GearRecipeSelected = nil
    local SeedRecipeSelected = nil
    local OrangutanSlot = nil
    local ForgerHamsterSlot = nil
    local PachySlot = nil
    local IsCraftingCampfire = false
    local IsCraftingGear = false
    local IsCraftingSeeds = false

    -- ===================== GUI REFERENCES =====================
    local SummerCrafting = PlayerGui:FindFirstChild("SummerCrafting")
    local Craft1, Craft2, Craft3
    if SummerCrafting then
        local Crafting = SummerCrafting:FindFirstChild("Crafting")
        local Main = Crafting and Crafting:FindFirstChild("Main")
        local Campfire = Main and Main:FindFirstChild("Campfire")
        local CampfireCrafting = Campfire and Campfire:FindFirstChild("Crafting")
        Craft1 = CampfireCrafting and CampfireCrafting:FindFirstChild("Craft1")
        Craft2 = CampfireCrafting and CampfireCrafting:FindFirstChild("Craft2")
        Craft3 = CampfireCrafting and CampfireCrafting:FindFirstChild("Craft3")
    end

    local ActivePetUI = PlayerGui:FindFirstChild("ActivePetUI")
    local ActivePetButtonHolder
    if ActivePetUI then
        local ActivePetFrame = ActivePetUI:FindFirstChild("Frame")
        local ActivePetMain = ActivePetFrame and ActivePetFrame:FindFirstChild("Main")
        local ActivePetLoadout = ActivePetMain and ActivePetMain:FindFirstChild("PetLoadout")
        local ActivePetLoadoutMain = ActivePetLoadout and ActivePetLoadout:FindFirstChild("Main")
        ActivePetButtonHolder = ActivePetLoadoutMain and ActivePetLoadoutMain:FindFirstChild("ButtonHolder")
    end

    local GearCraftingProximityPrompt = nil

    local RequirePassed, CraftingStationHandler = pcall(function()
        return require(ReplicatedStorage.Modules.CraftingStationHandler)
    end)

    local WorkbenchFound, EventCraftingWorkBench = pcall(function()
        local CraftingTables = workspace:FindFirstChild("CraftingTables")
        local EventCraftingWorkBench = CraftingTables.EventCraftingWorkBench
        for _, Model in ipairs(EventCraftingWorkBench:GetChildren()) do
            if Model.Name == "Model" then
                for _, Part in ipairs(Model:GetChildren()) do
                    if #Part:GetChildren() > 0 then
                        GearCraftingProximityPrompt = Part.CraftingProximityPrompt
                        break
                    end
                end
            end
        end
        return EventCraftingWorkBench
    end)

    local MyFarm = nil
    local Farms = workspace:FindFirstChild("Farm")
    if Farms then
        for _, Farm in pairs(Farms:GetChildren()) do
            local Important = Farm:FindFirstChild("Important")
            local Data = Important and Important:FindFirstChild("Data")
            local Owner = Data and Data:FindFirstChild("Owner")
            if Owner and Owner.Value == LocalPlayer.Name then
                MyFarm = Farm
                break
            end
        end
    end

    local MyImportant = MyFarm and MyFarm:FindFirstChild("Important")
    local MyPlants = MyImportant and MyImportant:FindFirstChild("Plants_Physical")
    local MyCosmetics = MyImportant and MyImportant:FindFirstChild("Cosmetic_Physical")

    -- ===================== HELPERS =====================
    local function SetPlantVisibility(hide)
        if not MyPlants then return end
        if hide then
            MyPlants.Parent = nil
        else
            MyPlants.Parent = MyImportant
        end
    end

    local function SetCosmeticVisibility(hide)
        if not MyCosmetics then return end
        if hide then
            MyCosmetics.Parent = nil
        else
            MyCosmetics.Parent = MyImportant
        end
    end

    local function SwapToLoadout(LoadoutNum)
        if not ActivePetButtonHolder then return end
        local LoadoutSlot = ActivePetButtonHolder:FindFirstChild("PET_LOADOUT_" .. LoadoutNum)
        if LoadoutSlot and LoadoutSlot.BackgroundColor3 ~= Color3.fromRGB(36, 227, 36) then
            repeat
                GameEvents.PetsService:FireServer("SwapPetLoadout", tonumber(LoadoutNum))
                task.wait(5)
                LoadoutSlot = ActivePetButtonHolder:FindFirstChild("PET_LOADOUT_" .. LoadoutNum)
            until LoadoutSlot and LoadoutSlot.BackgroundColor3 == Color3.fromRGB(36, 227, 36)
        end
    end

    -- ===================== CRAFT LOOPS =====================
    local function AutoCraftCampfireLoop()
        if IsCraftingCampfire then return end
        IsCraftingCampfire = true
        local SummerCraftingService = GameEvents.SummerCraftingService
        local TimesLeft = {}
        if Craft1 and Craft2 and Craft3 then
            TimesLeft = {Craft1.TimeLeft, Craft2.TimeLeft, Craft3.TimeLeft}
        end
        while AutoCraftCampfireEnabled and CampfireRecipeSelected do
            local HasOpenSlot = nil
            local HasClaim = nil
            for Index, TimeLeft in ipairs(TimesLeft) do
                if TimeLeft.Visible and TimeLeft.Text == "CLAIM!" then
                    HasClaim = true
                    SummerCraftingService.ClaimCraft:FireServer(Index)
                    task.wait(0.2)
                end
                if not TimeLeft.Visible then
                    HasOpenSlot = true
                end
            end
            if HasOpenSlot then
                SummerCraftingService.StartCraft:FireServer(CampfireRecipeSelected)
                task.wait(0.5)
            elseif not HasClaim then
                repeat
                    task.wait(2)
                until not AutoCraftCampfireEnabled or not CampfireRecipeSelected
                    or not TimesLeft[1].Visible or not TimesLeft[2].Visible or not TimesLeft[3].Visible
                    or TimesLeft[1].Text == "CLAIM!" or TimesLeft[2].Text == "CLAIM!" or TimesLeft[3].Text == "CLAIM!"
            end
        end
        IsCraftingCampfire = false
    end

    local function AutoCraftGearLoop()
        if not RequirePassed then
            Rayfield:Notify({
                Title = "Event Crafting Error",
                Content = "Auto-Craft Gear is not supported on your executor.",
                Duration = 10,
                Image = beastHubIcon,
            })
            return
        end
        if not WorkbenchFound then
            Rayfield:Notify({
                Title = "Event Crafting Error",
                Content = "You cannot craft items in tutorial servers.",
                Duration = 10,
                Image = beastHubIcon,
            })
            return
        end
        if IsCraftingGear then return end
        IsCraftingGear = true
        while AutoCraftGearEnabled and GearRecipeSelected do
            if GearCraftingProximityPrompt.ActionText ~= "Select Recipe" then
                if GearCraftingProximityPrompt.ActionText == "Claim" then
                    if PachySlot then SwapToLoadout(PachySlot) end
                    GameEvents.CraftingGlobalObjectService:FireServer("Claim", EventCraftingWorkBench, "GearEventWorkbench", 1)
                    task.wait(1)
                elseif GearCraftingProximityPrompt.ActionText ~= "Skip" then
                    GameEvents.CraftingGlobalObjectService:FireServer("Cancel", EventCraftingWorkBench, "GearEventWorkbench")
                    task.wait(1)
                end
            end
            GameEvents.CraftingGlobalObjectService:FireServer("SetRecipe", EventCraftingWorkBench, "GearEventWorkbench", GearRecipeSelected)
            task.wait(1)
            if GearCraftingProximityPrompt.ActionText == "Submit Item" and OrangutanSlot then
                SwapToLoadout(OrangutanSlot)
            end
            CraftingStationHandler:SubmitAllRequiredItems(EventCraftingWorkBench)
            task.wait(1)
            if not AutoCraftGearEnabled or not GearRecipeSelected then break end
            GameEvents.CraftingGlobalObjectService:FireServer("Craft", EventCraftingWorkBench, "GearEventWorkbench")
            task.wait(1)
            if GearCraftingProximityPrompt.ActionText == "Skip" and ForgerHamsterSlot then
                SwapToLoadout(ForgerHamsterSlot)
            end
            repeat
                task.wait(2)
            until not AutoCraftGearEnabled or not GearRecipeSelected or GearCraftingProximityPrompt.ActionText ~= "Skip"
            if AutoCraftGearEnabled and GearRecipeSelected then
                if GearCraftingProximityPrompt.ActionText == "Claim" and PachySlot then
                    SwapToLoadout(PachySlot)
                end
                GameEvents.CraftingGlobalObjectService:FireServer("Claim", EventCraftingWorkBench, "GearEventWorkbench", 1)
                task.wait(1)
            end
        end
        IsCraftingGear = false
    end

    local function AutoCraftSeedsLoop()
        if not RequirePassed then
            Rayfield:Notify({
                Title = "Event Crafting Error",
                Content = "Auto-Craft Seeds is not supported on your executor.",
                Duration = 10,
                Image = beastHubIcon,
            })
            return
        end
        if not WorkbenchFound then
            Rayfield:Notify({
                Title = "Event Crafting Error",
                Content = "You cannot craft items in tutorial servers.",
                Duration = 10,
                Image = beastHubIcon,
            })
            return
        end
        if IsCraftingSeeds then return end
        IsCraftingSeeds = true
        while AutoCraftSeedsEnabled and SeedRecipeSelected do
            local SeedEventCraftingWorkBench = workspace.CraftingTables.SeedEventCraftingWorkBench
            local Model = SeedEventCraftingWorkBench.Model
            local BenchTable = Model.BenchTable
            local SeedCraftingProximityPrompt = BenchTable.CraftingProximityPrompt
            if SeedCraftingProximityPrompt.ActionText ~= "Select Recipe" then
                if SeedCraftingProximityPrompt.ActionText == "Claim" then
                    if PachySlot then SwapToLoadout(PachySlot) end
                    GameEvents.CraftingGlobalObjectService:FireServer("Claim", SeedEventCraftingWorkBench, "SeedEventWorkbench", 1)
                    task.wait(1)
                elseif SeedCraftingProximityPrompt.ActionText ~= "Skip" then
                    GameEvents.CraftingGlobalObjectService:FireServer("Cancel", SeedEventCraftingWorkBench, "SeedEventWorkbench")
                    task.wait(1)
                end
            end
            GameEvents.CraftingGlobalObjectService:FireServer("SetRecipe", SeedEventCraftingWorkBench, "SeedEventWorkbench", SeedRecipeSelected)
            task.wait(1)
            if OrangutanSlot and SeedCraftingProximityPrompt.ActionText == "Submit Item" then
                SwapToLoadout(OrangutanSlot)
            end
            CraftingStationHandler:SubmitAllRequiredItems(SeedEventCraftingWorkBench)
            task.wait(1)
            if not AutoCraftSeedsEnabled or not SeedRecipeSelected then break end
            GameEvents.CraftingGlobalObjectService:FireServer("Craft", SeedEventCraftingWorkBench, "SeedEventWorkbench")
            task.wait(1)
            if ForgerHamsterSlot and SeedCraftingProximityPrompt.ActionText == "Skip" then
                SwapToLoadout(ForgerHamsterSlot)
            end
            repeat
                task.wait(2)
            until not AutoCraftSeedsEnabled or not SeedRecipeSelected or SeedCraftingProximityPrompt.ActionText ~= "Skip"
            if AutoCraftSeedsEnabled and SeedRecipeSelected then
                if PachySlot and SeedCraftingProximityPrompt.ActionText == "Claim" then
                    SwapToLoadout(PachySlot)
                end
                GameEvents.CraftingGlobalObjectService:FireServer("Claim", SeedEventCraftingWorkBench, "SeedEventWorkbench", 1)
                task.wait(1)
            end
        end
        IsCraftingSeeds = false
    end

    -- ===================== TAB UI =====================
    local Event = Window:CreateTab("Event", "hammer")

    -- ---- Campfire Crafting ----
    Event:CreateSection("Campfire Crafting")

    Event:CreateToggle({
        Name = "Auto-Craft Campfire Recipe",
        CurrentValue = false,
        Flag = "eventAutoCraftCampfire",
        Callback = function(Value)
            AutoCraftCampfireEnabled = Value
            if Value and CampfireRecipeSelected then
                task.spawn(AutoCraftCampfireLoop)
            end
        end,
    })

    Event:CreateDropdown({
        Name = "Campfire Recipe",
        Options = {
            "1:1:Firepit Flower", "1:2:Cauliflower", "2:1:Campfire Crate",
            "2:2:Common Summer Egg", "2:3:Green Apple", "2:4:Avocado",
            "3:1:Super Watering Can", "3:2:Areaclaimer", "3:3:Banana", "3:4:Kiwi",
            "4:1:Hearth Reed", "4:2:Rare Summer Egg", "4:3:Prickly Pear",
            "5:1:Feijoa", "5:2:Paradise Egg", "5:3:Energy Chew",
            "5:4:Pitcher Plant", "5:5:Campfire Egg"
        },
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "eventCampfireRecipe",
        Callback = function(Option)
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
        Name = "Auto-Craft Gear",
        CurrentValue = false,
        Flag = "eventAutoCraftGear",
        Callback = function(Value)
            AutoCraftGearEnabled = Value
            if Value and GearRecipeSelected then
                task.spawn(AutoCraftGearLoop)
            end
        end,
    })

    Event:CreateDropdown({
        Name = "Gear Recipe",
        Options = {
            "Lightning Rod", "Tanning Mirror", "Reclaimer", "Event Lantern",
            "Anti Bee Egg", "Small Toy", "Small Treat", "Pet Pouch", "Pack Bee",
            "Silver Ingot", "Gold Ingot", "Chimera Stone", "Black Spotty Egg",
            "Tropical Mist Sprinkler", "Berry Blusher Sprinkler", "Spice Spritzer Sprinkler",
            "Flower Froster Sprinkler", "Stalk Sprout Sprinkler", "Sweet Soaker Sprinkler",
            "Mutation Spray Pollinated", "Honey Crafters Crate", "Mutation Spray Glimmering",
            "Mutation Spray Chilled", "Mutation Spray Shocked", "Mutation Spray Choc"
        },
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "eventGearRecipe",
        Callback = function(Option)
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
        Name = "Auto-Craft Seeds",
        CurrentValue = false,
        Flag = "eventAutoCraftSeeds",
        Callback = function(Value)
            AutoCraftSeedsEnabled = Value
            if Value and SeedRecipeSelected then
                task.spawn(AutoCraftSeedsLoop)
            end
        end,
    })

    Event:CreateDropdown({
        Name = "Seed Recipe",
        Options = {
            "Egg Melon", "Mandrake", "Evo Apple I", "Evo Apple II", "Evo Apple III",
            "Evo Apple IV", "Olive", "Hollow Bamboo", "Yarrow", "Grand Volcania",
            "Peace Lily", "Aloe Vera", "Guanabana", "Crafters Seed Pack",
            "Manuka Flower", "Dandelion", "Lumira", "Honeysuckle", "Bee Balm",
            "Nectar Thorn", "Suncoil", "Twisted Tangle", "Veinpetal",
            "Horsetail", "Lingonberry", "Amber Spine"
        },
        CurrentOption = {},
        MultipleOptions = false,
        Flag = "eventSeedRecipe",
        Callback = function(Option)
            SeedRecipeSelected = (Option ~= "" and Option) or nil
            if AutoCraftSeedsEnabled and SeedRecipeSelected then
                task.spawn(AutoCraftSeedsLoop)
            end
        end,
    })

    Event:CreateDivider()

return M
