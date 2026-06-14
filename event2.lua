local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService   = game:GetService("TeleportService")
    local RunService        = game:GetService("RunService")
    local Players          = game:GetService("Players")
    local Workspace        = game:GetService("Workspace")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    local AutoCraftCampfireEnabled = false
    local CampfireRecipeSelected   = nil
    local IsCraftingCampfire       = false
    local CampfireRecipeParagraph  = nil

    -- Ember Burning State
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

    -- Dynamic Dropdown Scraper for Fruits Pool
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

        local handler = getCraftingStationHandler()
        if not handler then
            notify("Campfire Craft Error", "Auto-Craft Campfire is not supported on your executor.", 10)
            return
        end

        local function findCampfireWorkbench()
            local CraftingTables = workspace:FindFirstChild("CraftingTables")
            if not CraftingTables then return nil, nil end
            local wb = CraftingTables:FindFirstChild("CampfireEventCraftingWorkBench") or CraftingTables:FindFirstChild("CampfireCraftingWorkBench")
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

        local CampfireCraftingWorkBench, CampfireCraftingProximityPrompt = findCampfireWorkbench()
        if not CampfireCraftingWorkBench or not CampfireCraftingProximityPrompt then
            notify("Campfire Craft Error", "Campfire Workbench structure not found in this server.", 10)
            return
        end

        IsCraftingCampfire = true

        local ok, err = pcall(function()
            local GameEvents = getGameEvents()
            if not GameEvents then
                notify("Campfire Craft Error", "GameEvents not found.", 8)
                return
            end
            local CraftService = GameEvents:FindFirstChild("CraftingGlobalObjectService")
            if not CraftService then
                notify("Campfire Craft Error", "CraftingGlobalObjectService not found.", 8)
                return
            end

            local p    = CampfireCraftingProximityPrompt
            local wb   = CampfireCraftingWorkBench
            local wbId = "CampfireEventWorkbench"
            local function campfireOn()     return AutoCraftCampfireEnabled end
            local function campfireRecipe() return CampfireRecipeSelected end

            while AutoCraftCampfireEnabled and CampfireRecipeSelected do
                local action = p.ActionText
                if action == "Claim" then
                    CraftService:FireServer("Claim", wb, wbId, 1)
                    waitForAction(p, "Select Recipe", 10, campfireOn, campfireRecipe)
                elseif action ~= "Select Recipe" and action ~= "Craft" and action ~= "Submit Item" then
                    CraftService:FireServer("Cancel", wb, wbId)
                    waitForAction(p, "Select Recipe", 10, campfireOn, campfireRecipe)
                end

                if not AutoCraftCampfireEnabled or not CampfireRecipeSelected then break end

                CraftService:FireServer("SetRecipe", wb, wbId, CampfireRecipeSelected)
                if not waitForAction(p, "Submit Item", 10, campfireOn, campfireRecipe) then
                    task.wait(1); continue
                end

                handler:SubmitAllRequiredItems(wb)

                local elapsed = 0
                while p.ActionText == "Submit Item" and elapsed < 10 do
                    task.wait(0.5); elapsed = elapsed + 0.5
                end

                if not AutoCraftCampfireEnabled or not CampfireRecipeSelected then break end

                CraftService:FireServer("Craft", wb, wbId)
                if not waitForAction(p, "Skip", 10, campfireOn, campfireRecipe) then
                    task.wait(1); continue
                end

                repeat task.wait(1) until
                    not AutoCraftCampfireEnabled
                    or not CampfireRecipeSelected
                    or p.ActionText ~= "Skip"

                if AutoCraftCampfireEnabled and CampfireRecipeSelected and p.ActionText == "Claim" then
                    CraftService:FireServer("Claim", wb, wbId, 1)
                    waitForAction(p, "Select Recipe", 10, campfireOn, campfireRecipe)
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

    -- ===================== BURNING LOOP =====================
    task.spawn(function()
        while true do
            task.wait(BurnSpeedDelay)
            
            if AutoBurnPlantsEnabled and BurnFruitSelected and BurnFruitSelected ~= "None" then
                pcall(function()
                    local character = LocalPlayer.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                    
                    if character and humanoid and backpack and humanoid.Health > 0 then
                        local targetTool = nil
                        for _, obj in ipairs(backpack:GetChildren()) do
                            if obj:IsA("Tool") and not string.find(string.lower(obj.Name), "seed") then
                                if obj.Name == BurnFruitSelected or string.find(string.lower(obj.Name), string.lower(BurnFruitSelected)) then
                                    targetTool = obj; break
                                end
                            end
                        end
                        
                        if not targetTool then
                            for _, obj in ipairs(character:GetChildren()) do
                                if obj:IsA("Tool") and not string.find(string.lower(obj.Name), "seed") then
                                    if obj.Name == BurnFruitSelected or string.find(string.lower(obj.Name), string.lower(BurnFruitSelected)) then
                                        targetTool = obj; break
                                    end
                                end
                            end
                        end

                        if not targetTool then
                            if BurnParagraph then
                                BurnParagraph:Set({
                                    Title = "Selected Fruit to Burn: " .. tostring(BurnFruitSelected), 
                                    Content = "Status: Paused (Waiting for items...)"
                                })
                            end
                            return
                        end

                        if targetTool then
                            if BurnParagraph then
                                BurnParagraph:Set({
                                    Title = "Selected Fruit to Burn: " .. tostring(BurnFruitSelected), 
                                    Content = "Status: Burning..."
                                })
                            end

                            if targetTool.Parent == backpack then
                                humanoid:EquipTool(targetTool)
                                local startTimeout = os.clock()
                                repeat task.wait(0.02) until targetTool.Parent == character or os.clock() - startTimeout > 1.0
                            end
                            
                            if targetTool.Parent == character then
                                local promptTriggered = false
                                for _, desc in ipairs(Workspace:GetDescendants()) do
                                    if desc:IsA("ProximityPrompt") then
                                        if desc.ObjectText == "Held Plant" and desc.ActionText == "Burn" then
                                            desc.RequiresLineOfSight = false
                                            desc.MaxActivationDistance = math.huge
                                            desc:InputHoldBegin()
                                            task.wait(0.02)
                                            desc:InputHoldEnd()
                                            promptTriggered = true
                                            break
                                        end
                                    end
                                end
                                
                                if not promptTriggered then
                                    local GameEvents = getGameEvents()
                                    local burnRemote = GameEvents and GameEvents:FindFirstChild("SummerCraftingService") and GameEvents.SummerCraftingService:FindFirstChild("BurnItem")
                                    if burnRemote then burnRemote:FireServer() end
                                end
                            end
                        end
                    end
                end)
            else
                if BurnParagraph then
                    BurnParagraph:Set({
                        Title = "Selected Fruit to Burn: " .. tostring(BurnFruitSelected or "None"), 
                        Content = "Status: Idle / Off"
                    })
                end
            end
        end
    end)

    -- ===================== TAB UI =====================
    local Event = Window:CreateTab("Craft", "hammer")

    -- ---- Campfire Crafting ----
    Event:CreateSection("Campfire Crafting")

    CampfireRecipeParagraph = Event:CreateParagraph({
        Title   = "Selected Campfire Recipe:",
        Content = "None",
    })

    Event:CreateToggle({
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

    Event:CreateDropdown({
        Name    = "Campfire Recipe",
        Options = {
            "Firepit Flower", "Cauliflower", "Campfire Crate",
            "Common Summer Egg", "Green Apple", "Avocado",
            "Super Watering Can", "Areaclaimer", "Banana", "Kiwi",
            "Hearth Reed", "Rare Summer Egg", "Prickly Pear",
            "Feijoa", "Paradise Egg", "Energy Chew",
            "Pitcher Plant", "Campfire Egg",
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

    Event:CreateDivider()

    -- ---- Ember Burning ----
    Event:CreateSection("Ember Burning")

    BurnParagraph = Event:CreateParagraph({
        Title = "Selected Fruit to Burn: None", 
        Content = "Status: Idle / Off"
    })

    Event:CreateToggle({
        Name         = "Auto Hold & Burn Plants",
        CurrentValue = false,
        Flag         = "eventAutoBurnPlants",
        Callback     = function(Value)
            AutoBurnPlantsEnabled = Value
        end,
    })

    Event:CreateDropdown({
        Name    = "Burn Process Speed",
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

    Event:CreateDropdown({
        Name    = "Select Fruit to Burn",
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
                    BurnParagraph:Set({Title = "Selected Fruit to Burn: " .. choice, Content = "Status: Initializing..."})
                end
            end
        end,
    })

    Event:CreateDivider()
end

return M
