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
    local BurnFruitDropdown     = nil -- Stored for dynamic resets

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

    -- ===================== AUTO BURN LOOP =====================
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
                
                if Char and BP then
                    -- Explicit inventory matching for the specific selected tool name
                    local tool = BP:FindFirstChild(BurnFruitSelected) or Char:FindFirstChild(BurnFruitSelected)
                    
                    if tool and tool:IsA("Tool") then
                        if tool.Parent == BP then
                            Char:WaitForChild("Humanoid"):EquipTool(tool)
                            task.wait(0.3)
                        end
                        SummerService.BurnItem:FireServer()
                        task.wait(0.5)
                    else
                        -- Target item not found in backpack, wait before recheck loop
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
            
            -- Reset status visuals
            if BurnStatusParagraph then
                BurnStatusParagraph:Set({
                    Title = "Selected Fruit to Burn:",
                    Content = "None"
                })
            end
            
            -- Force Rayfield UI assignment back to empty
            if BurnFruitDropdown then
                BurnFruitDropdown:Set({})
            end
        end,
    })

    CampfireTab:CreateDivider()
end

return M
