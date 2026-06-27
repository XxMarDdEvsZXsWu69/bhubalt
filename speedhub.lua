local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local TeleportService  = game:GetService("TeleportService")
    local RunService       = game:GetService("RunService")
    local Players          = game:GetService("Players")
    local LocalPlayer      = Players.LocalPlayer
    local PlayerGui        = LocalPlayer.PlayerGui

    -- ===================== TAB UI =====================
    local Support = Window:CreateTab("Support", "message-circle")

    -- ---- Support Section ----
    Support:CreateSection("Devs Message")

    Support:CreateParagraph({
        Title   = "Notice:",
        Content = "Sorry for Being Always Late Update, Because I'm too busy and I can't Handle Multiple Works like update my script while grinding in Gag because i use only one devices and it's so hard for me.\n\n-Markdevs69"
    })
    
        -- ---- SpeedHub Section ----
    Support:CreateSection("Support Scripts")
    Support:CreateParagraph({
        Title   = "SpeedHub",
        Content = "SpeedHub No Need Code"
    })
    Support:CreateButton({
        Name     = "Execute SpeedHub",
        Callback = function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/AhmadV99/Script-Games/refs/heads/main/Grow%20a%20Garden.lua"))()
        end
    })

end

return M
