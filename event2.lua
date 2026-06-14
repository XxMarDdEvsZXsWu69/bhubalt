local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players          = game:GetService("Players")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    local AutoBurnPlantsEnabled = false
    local BurnFruitSelected     = nil
    local IsBurningPlants       = false
    local BurnStatusParagraph   = nil
    local BurnFruitDropdown     = nil

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

    -- ===================== DATA LOADING =====================
    local function getAllSeedsTableV2()
        local PlantDataModule = safeWaitPath(ReplicatedStorage, 15, 
            "Modules", "GardenGuideModules", "DataModules", "PlantData")
        if not PlantDataModule then return nil end
        
        local ok, PlantData = pcall(function() return require(PlantDataModule) end)
        return (ok and typeof(PlantData) == "table" and typeof(PlantData.Data) == "table") and PlantData.Data or nil
    end

    local allSeedsData = getAllSeedsTableV2()
    local fruitOptions = {}
    if allSeedsData then
        for seedName, _ in pairs(allSeedsData) do
            table.insert(fruitOptions, seedName)
        end
        table.sort(fruitOptions)
    end

    -- ===================== AUTO EQUIP & BURN LOOP =====================
    local function AutoBurnPlantsLoop()
        if IsBurningPlants then return end
        IsBurningPlants = true

        local ok, err = pcall(function()
            local GameEvents = safeWait(ReplicatedStorage, "GameEvents", 15)
            local SummerService = safeWait(GameEvents, "SummerCraftingService", 10)
            if not SummerService then return end

            while AutoBurnPlantsEnabled and BurnFruitSelected do
                local Char = LocalPlayer.Character
                local BP = LocalPlayer:FindFirstChild("Backpack")
                local Humanoid = Char and Char:FindFirstChildOfClass("Humanoid")
                
                if Char and BP and Humanoid and Humanoid.Health > 0 then
                    -- Locate tool across both potential inventory containers
                    local tool = BP:FindFirstChild(BurnFruitSelected) or Char:FindFirstChild(BurnFruitSelected)
                    
                    if tool and tool:IsA("Tool") then
                        -- Auto-Held: Force equip the fruit if it's currently unequipped
                        if tool.Parent == BP then
                            Humanoid:EquipTool(tool)
                            task.wait(0.25) -- Safe physical attachment replication block
                        end

                        -- Auto-Burn: Instantly execute fire action on server setup
                        if tool.Parent == Char then
                            SummerService.BurnItem:FireServer()
                            task.wait(0.4) -- Delay for burn transaction processing
                        end
                    else
                        -- Selection isn't owned yet, yield back to check again shortly
                        task.wait(1.5)
                    end
                else
                    task.wait(1)
                end
                task.wait(0.1)
            end
        end)

        IsBurningPlants = false
        if not ok then
            warn("[BeastHub] AutoBurnPlantsLoop error: " .. tostring(err))
        end
    end

    -- ===================== TAB UI =====================
    local CampfireTab = Window:CreateTab("Campfire", "flame")
    CampfireTab:CreateSection("Auto Burn Event")

    BurnStatusParagraph = CampfireTab:CreateParagraph({
        Title   = "Selected Fruit to Burn:",
        Content = "None",
    })

    CampfireTab:CreateToggle({
        Name         = "Auto Hold & Burn Plants",
        CurrentValue = false,
        Flag         = "eventAutoBurnPlants",
        Callback     = function(Value)
            AutoBurnPlantsEnabled = Value
            if Value and BurnFruitSelected then
                task.spawn(AutoBurnPlantsLoop)
            end
        end,
    })

    BurnFruitDropdown = CampfireTab:CreateDropdown({
        Name    = "Select Fruit to Burn",
        Options = fruitOptions,
        CurrentOption   = {},
        MultipleOptions = false,
        Flag            = "eventBurnFruitSelect",
        Callback        = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            BurnFruitSelected = (choice and choice ~= "") and choice or nil
            
            if BurnStatusParagraph then
                BurnStatusParagraph:Set({
                    Title = "Selected Fruit to Burn:",
                    Content = BurnFruitSelected or "None"
                })
            end

            if AutoBurnPlantsEnabled and BurnFruitSelected then
                task.spawn(AutoBurnPlantsLoop)
            end
        end,
    })

    CampfireTab:CreateButton({
        Name = "Clear Selected Fruit",
        Callback = function()
            BurnFruitSelected = nil
            
            if BurnStatusParagraph then
                BurnStatusParagraph:Set({
                    Title = "Selected Fruit to Burn:",
                    Content = "None"
                })
            end
            
            if BurnFruitDropdown then
                BurnFruitDropdown:Set({})
            end
        end,
    })

    CampfireTab:CreateDivider()
end

return M
