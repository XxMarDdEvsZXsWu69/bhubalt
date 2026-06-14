local M = {}

function M.init(Rayfield, beastHubNotify, Window, myFunctions, reloadScript, beastHubIcon)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Lighting          = game:GetService("Lighting")
    local Players           = game:GetService("Players")
    local LocalPlayer       = Players.LocalPlayer
    local Terrain           = workspace:FindFirstChildOfClass("Terrain")

    -- ===================== STATE =====================
    local FPSBoostEnabled = false
    local DescendantConnection = nil

    -- Cache original lighting settings to restore them later
    local originalSettings = {
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        Brightness = Lighting.Brightness,
    }

    -- ===================== TAB UI =====================
    local PerformanceTab = Window:CreateTab("Performance", "zap")

    PerformanceTab:CreateSection("FPS Booster")

    PerformanceTab:CreateParagraph({
        Title   = "Smoothies Gameplay Mode",
        Content = "Removes heavy textures, particles, shadows, and environment lag from Grow a Garden."
    })

    PerformanceTab:CreateToggle({
        Name         = "Enable Extreme FPS Boost",
        CurrentValue = false,
        Flag         = "devsHubFpsBooster",
        Callback     = function(Value)
            FPSBoostEnabled = Value

            if Value then
                -- 1. Lower Engine Quality Level
                settings().Rendering.QualityLevel = 1

                -- 2. Clean Lighting Overhead
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 9e9
                Lighting.Brightness = 1
                
                for _, v in pairs(Lighting:GetChildren()) do
                    if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                        v.Enabled = false
                    end
                end

                -- 3. Smooth Existing World Terrain & Parts
                if Terrain then
                    Terrain.WaterWaveSize = 0
                    Terrain.WaterWaveSpeed = 0
                    Terrain.WaterReflectance = 0
                    Terrain.WaterTransparency = 0
                end

                for _, v in pairs(game:GetDescendants()) do
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v.Enabled = false
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        v.Transparency = 1
                    elseif v:IsA("BasePart") then
                        v.Material = Enum.Material.SmoothPlastic
                        v.Reflectance = 0
                    end
                end

                -- 4. Catch dynamically spawning garden plants/particles
                DescendantConnection = game.DescendantAdded:Connect(function(v)
                    if not FPSBoostEnabled then return end
                    task.skipFrame() -- Safe execution buffer
                    if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") then
                        v.Enabled = false
                    elseif v:IsA("Decal") or v:IsA("Texture") then
                        v.Transparency = 1
                    elseif v:IsA("BasePart") then
                        v.Material = Enum.Material.SmoothPlastic
                        v.Reflectance = 0
                    end
                end)

                Rayfield:Notify({
                    Title    = "FPS Booster",
                    Content  = "Smoothies Mode Activated!",
                    Duration = 4,
                    Image    = beastHubIcon,
                })
            else
                -- Restore original lighting profiles when toggled off
                if DescendantConnection then
                    DescendantConnection:Disconnect()
                    DescendantConnection = nil
                end

                Lighting.GlobalShadows = originalSettings.GlobalShadows
                Lighting.FogEnd = originalSettings.FogEnd
                Lighting.Brightness = originalSettings.Brightness
                
                for _, v in pairs(Lighting:GetChildren()) do
                    if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then
                        v.Enabled = true
                    end
                end

                settings().Rendering.QualityLevel = 0 -- Revert to automatic physics rendering

                Rayfield:Notify({
                    Title    = "FPS Booster",
                    Content  = "Graphics restored to default settings.",
                    Duration = 4,
                    Image    = beastHubIcon,
                })
            end
        end,
    })

    PerformanceTab:CreateDivider()
end

return M
