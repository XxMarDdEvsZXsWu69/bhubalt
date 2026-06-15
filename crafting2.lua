local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    
    local AutoCraftCampfireEnabled = false
    local CampfireRecipeSelected   = nil
    local IsCraftingCampfire       = false

    local AutoBurnPlantsEnabled    = false
    local BurnFruitSelected        = nil
    local BurnSpeedDelay           = 1.0

    -- ===================== HELPERS =====================
    local function safeWait(parent, name, timeout)
        if not parent then return nil end
        local ok, result = pcall(function() return parent:WaitForChild(name, timeout or 10) end)
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

    local function notify(title, content, duration)
        Rayfield:Notify({
            Title = title,
            Content = content,
            Duration = duration or 6,
            Image = beastHubIcon,
        })
    end

    -- ===================== CRAFT LOOPS (FIXED) =====================

    -- NEW: Unified Remote-Only Crafting Logic for Gear/Seeds
    local function UnifiedGlobalCraftLoop(mode)
        local isGear = (mode == "Gear")
        if isGear and IsCraftingGear then return end
        if not isGear and IsCraftingSeeds then return end

        local GameEvents = safeWait(ReplicatedStorage, "GameEvents", 15)
        local CraftService = GameEvents and GameEvents:FindFirstChild("CraftingGlobalObjectService")
        
        if not CraftService then
            notify(mode .. " Craft Error", "Crafting service not found. Are you in the tutorial?", 10)
            return
        end

        if isGear then IsCraftingGear = true else IsCraftingSeeds = true end

        pcall(function()
            -- Mode Config
            local wbId = isGear and "GearEventWorkbench" or "SeedEventWorkbench"
            local getEnabled = function() return isGear and AutoCraftGearEnabled or AutoCraftSeedsEnabled end
            local getRecipe = function() return isGear and GearRecipeSelected or SeedRecipeSelected end

            while getEnabled() and getRecipe() do
                -- 1. Claim any finished items first
                CraftService:FireServer("Claim", nil, wbId, 1)
                task.wait(0.5)

                -- 2. Set the Recipe
                CraftService:FireServer("SetRecipe", nil, wbId, getRecipe())
                task.wait(0.5)

                -- 3. Use the global object service to "Submit All" 
                -- We use the Remote directly instead of the proximity prompt handler
                CraftService:FireServer("SubmitAll", nil, wbId)
                task.wait(0.5)

                -- 4. Start the Craft
                CraftService:FireServer("Craft", nil, wbId)
                
                -- Wait for craft time (typical for these workbenches)
                -- We check every 2 seconds to see if we can claim/restart
                task.wait(2)
            end
        end)

        if isGear then IsCraftingGear = false else IsCraftingSeeds = false end
    end

    -- ---- Campfire Loop (Kept Original) ----
    local function AutoCraftCampfireLoop()
        if IsCraftingCampfire then return end
        local GameEvents = safeWait(ReplicatedStorage, "GameEvents", 15)
        local SummerCraftingService = GameEvents and GameEvents:FindFirstChild("SummerCraftingService")
        local CampfireRoot = safeWaitPath(PlayerGui, 10, "SummerCrafting", "Crafting", "Main", "Campfire", "Crafting")

        if not SummerCraftingService or not CampfireRoot then
            notify("Campfire Error", "Open Campfire Menu & ensure Service exists.", 5)
            return
        end

        IsCraftingCampfire = true
        pcall(function()
            while AutoCraftCampfireEnabled and CampfireRecipeSelected do
                local HasOpenSlot = false
                for i = 1, 3 do
                    local SlotUI = CampfireRoot:FindFirstChild("Craft" .. i)
                    if SlotUI then
                        local TimeLeft = SlotUI:FindFirstChild("TimeLeft")
                        if TimeLeft and TimeLeft.Visible and TimeLeft.Text == "CLAIM!" then
                            SummerCraftingService.ClaimCraft:FireServer(i)
                            task.wait(0.3)
                        end
                        if TimeLeft and not TimeLeft.Visible then HasOpenSlot = true end
                    end
                end
                if HasOpenSlot then
                    SummerCraftingService.StartCraft:FireServer(CampfireRecipeSelected)
                    task.wait(0.8)
                else
                    task.wait(2)
                end
            end
        end)
        IsCraftingCampfire = false
    end

    -- ===================== UI SETUP (ABRIDGED) =====================
    -- I've kept your UI structure exactly the same, just updated the callbacks 
    -- to point to the new UnifiedGlobalCraftLoop logic.

    local CraftTab = Window:CreateTab("Craft", "hammer")
    
    -- Gear Section
    CraftTab:CreateToggle({
        Name = "Auto-Craft Gear",
        CurrentValue = false,
        Callback = function(Value)
            AutoCraftGearEnabled = Value
            if Value then task.spawn(function() UnifiedGlobalCraftLoop("Gear") end) end
        end,
    })

    -- Seed Section
    CraftTab:CreateToggle({
        Name = "Auto-Craft Seeds",
        CurrentValue = false,
        Callback = function(Value)
            AutoCraftSeedsEnabled = Value
            if Value then task.spawn(function() UnifiedGlobalCraftLoop("Seed") end) end
        end,
    })

    -- ... [Rest of your Dropdowns and Campfire UI remain unchanged] ...
end

return M
