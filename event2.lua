local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players          = game:GetService("Players")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== STATE =====================
    local AutoCraftCampfireEnabled = false
    local CampfireRecipeSelected   = nil -- Default to nil/none
    local IsCraftingCampfire       = false
    local CampfireRecipeParagraph  = nil

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

    -- ===================== TAB UI =====================
    local CampfireTab = Window:CreateTab("Campfire", "flame")

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
end

return M
