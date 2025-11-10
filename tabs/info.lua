return function(Window, Shared)
    local tab = Window:CreateTab("Info", "info")
    
    local aimLabelElement = tab:CreateLabel("Aimlock Target: None", "target", Color3.fromRGB(255,255,255), false)
    local statusLabelElement = tab:CreateLabel("Status: Ready", "sliders", Color3.fromRGB(255,255,255), false)

    Shared.RunService.RenderStepped:Connect(function()
        if aimLabelElement then
            pcall(function()
                local locked = Shared.MooAimlock.LockedTarget
                if locked and locked.Name then
                    aimLabelElement:Set("Aimlock Target: "..locked.Name, "target", Color3.fromRGB(255,255,255), false)
                else
                    aimLabelElement:Set("Aimlock Target: None", "target", Color3.fromRGB(255,255,255), false)
                end
            end)
        end
        if statusLabelElement then
            pcall(function()
                local status = "Ready"
                if Shared.MooSettings.CashESPEnabled then status = status.." | CashESP: ON" end
                if Shared.MooSettings.ESPEnabled then status = status.." | ESP: ON" end
                if Shared.MooSettings.AutoFarmEnabled then status = status.." | AutoFarm: ON" end
                if Shared.MooSettings.NoclipEnabled then status = status.." | Noclip: ON" end
                if Shared.MooSettings.WalkSpeedEnabled then status = status.." | WalkSpeed: ON" end
                if Shared.MooSettings.JumpPowerEnabled then status = status.." | JumpPower: ON" end
                statusLabelElement:Set("Status: "..status, "sliders", Color3.fromRGB(255,255,255), false)
            end)
        end
    end)

    tab:CreateParagraph({Title = "About", Content = "Moo Moo Hax by afk.l0l. All actions notify."})

    return tab
end
