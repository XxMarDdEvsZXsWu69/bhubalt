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

    -- Ember Burning State (Updated to Auto Hold & Submit Fruits)
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

    -- ===================== NEW SUBMIT FRUITS LOOP =====================
    task.spawn(function()
        while true do
            -- Dynamic pause delay handler based on UI selections
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

                    if character and backpack then
                        -- First check if we are already holding the targeted fruit
                        for _, item in ipairs(character:GetChildren()) do
                            if item:IsA("Tool") and item.Name == BurnFruitSelected then
                                foundFruit = true
                                break
                            end
                        end

                        -- If not holding it, look for it in the backpack
                        if not foundFruit then
                            for _, item in ipairs(backpack:GetChildren()) do
                                if item:IsA("Tool") and item.Name == BurnFruitSelected then
                                    local name = item.Name:lower()
                                    -- Safety structural exclusions from your prompt logic
                                    if not name:find("seed") and not name:find("sprinkler") and not name:find("can") and not name:find("crate") and not name:find("tool") and not name:find("pet") and not name:find("egg") and not name:find("ticket") then
                                        item.Parent = character
                                        foundFruit = true
                                        task.wait(0.1) -- Equipment window buffer
                                        break
                                    end
                                end
                            end
                        end

                        -- Clear hands if the specifically selected fruit is gone/not found
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

                    -- Fire activation sequence and deliver payload if item is verified in hand
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
                        -- Additional throttle window compensation logic based on global delay selections
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
    local CampfireTab = Window:CreateTab("Campfire", "flame")

    -- ---- Campfire Crafting ----
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

    -- ---- Ember Burning ----
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
