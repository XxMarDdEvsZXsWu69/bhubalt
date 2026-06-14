local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players          = game:GetService("Players")
    local Workspace        = game:GetService("Workspace")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    local AutoCraftCampfireEnabled = false
    local CampfireRecipeSelected   = nil -- Default to nil/none
    local IsCraftingCampfire       = false
    local CampfireRecipeParagraph  = nil

    -- Ember Burning State
    local AutoBurnPlantsEnabled    = false
    local BurnFruitSelected        = nil
    local BurnSpeedDelay           = 1.0 -- Default configuration set to SLOW (1.0s)
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

    -- ===================== CRAFT LOOPS =====================
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
                        
                        -- Find matching tools inside player instances (STRICT FILTERING: No seeds allowed)
                        local targetTool = nil
                        for _, obj in ipairs(backpack:GetChildren()) do
                            if obj:IsA("Tool") and not string.find(string.lower(obj.Name), "seed") then
                                if obj.Name == BurnFruitSelected or string.find(string.lower(obj.Name), string.lower(BurnFruitSelected)) then
                                    targetTool = obj
                                    break
                                end
                            end
                        end
                        
                        if not targetTool then
                            for _, obj in ipairs(character:GetChildren()) do
                                if obj:IsA("Tool") and not string.find(string.lower(obj.Name), "seed") then
                                    if obj.Name == BurnFruitSelected or string.find(string.lower(obj.Name), string.lower(BurnFruitSelected)) then
                                        targetTool = obj
                                        break
                                    end
                                end
                            end
                        end

                        -- SMART PAUSE: If item is missing, idle the loop and wait until items reappear
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
                            -- Update UI status back to active burning
                            if BurnParagraph then
                                BurnParagraph:Set({
                                    Title = "Selected Fruit to Burn: " .. tostring(BurnFruitSelected), 
                                    Content = "Status: Burning..."
                                })
                            end

                            -- Equip Tool Block
                            if targetTool.Parent == backpack then
                                humanoid:EquipTool(targetTool)
                                local startTimeout = os.clock()
                                repeat 
                                    task.wait(0.02) 
                                until targetTool.Parent == character or os.clock() - startTimeout > 1.0
                            end
                            
                            -- Active Prompt Intersect & Burn execution block
                            if targetTool.Parent == character then
                                local promptTriggered = false
                                
                                for _, desc in ipairs(Workspace:GetDescendants()) do
                                    if desc:IsA("ProximityPrompt") then
                                        local isHeldPlantPrompt = (desc.ObjectText == "Held Plant" and desc.ActionText == "Burn")
                                        if isHeldPlantPrompt then
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
                                    local burnRemote = safeWaitPath(ReplicatedStorage, 5, "GameEvents", "SummerCraftingService", "BurnItem")
                                    if burnRemote then
                                        burnRemote:FireServer()
                                    end
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
    local CampfireTab = Window:CreateTab("Campfire", "flame")

    -- SECTION 1: CRAFTING
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

    -- SECTION 2: EMBER BURNING
    CampfireTab:CreateSection("Ember Burning")

    BurnParagraph = CampfireTab:CreateParagraph({
        Title = "Selected Fruit to Burn: None", 
        Content = "Status: Idle / Off"
    })

    CampfireTab:CreateDropdown({
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

    CampfireTab:CreateDropdown({
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
    
    CampfireTab:CreateToggle({
        Name         = "Auto Hold & Burn Plants",
        CurrentValue = false,
        Flag         = "eventAutoBurnPlants",
        Callback     = function(Value)
            AutoBurnPlantsEnabled = Value
        end,
    })

    CampfireTab:CreateDivider()
end

return M
