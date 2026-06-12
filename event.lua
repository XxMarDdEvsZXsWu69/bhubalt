local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService  = game:GetService("TeleportService")
    local RunService       = game:GetService("RunService")
    local Players          = game:GetService("Players")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== TAB UI =====================
    local Event = Window:CreateTab("Craft", "hammer")

    -- ---- Crafting Section ----
    Event:CreateSection("Crafting status")

    Event:CreateParagraph({
        Title   = "Status:",
        Content = "Still Updating..."
    })
end

return M
