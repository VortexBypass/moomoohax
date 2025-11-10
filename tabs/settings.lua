return function(Window, Shared)
    local tab = Window:CreateTab("Settings", "sliders")
    
    tab:CreateSection("Interface")
    tab:CreateDropdown({
        Name = "Theme",
        Options = {"Default","AmberGlow","Amethyst","Bloom","DarkBlue","Green","Light","Ocean","Serenity"},
        CurrentOption = {"Default"},
        MultipleOptions = false,
        Flag = "ThemeSelect",
        Callback = function(option)
            pcall(function() Window:ModifyTheme(option) end)
            Shared.createNotification("Theme set to "..option, Color3.new(0,1,1))
        end
    })

    tab:CreateColorPicker({
        Name = "Accent Color",
        Color = Color3.fromRGB(50,138,220),
        Flag = "Accent",
        Callback = function(val)
            Shared.createNotification("Accent color selected", Color3.new(0,1,1))
        end
    })

    tab:CreateButton({
        Name = "Minimize UI",
        Callback = function()
            pcall(function() getgenv().Rayfield:SetVisibility(false) end)
            Shared.createNotification("UI minimized", Color3.new(1,1,0))
        end
    })

    tab:CreateButton({
        Name = "Maximize UI",
        Callback = function()
            pcall(function() getgenv().Rayfield:SetVisibility(true) end)
            Shared.createNotification("UI maximized", Color3.new(0,1,0))
        end
    })

    tab:CreateButton({
        Name = "Open Discord Invite",
        Callback = function()
            pcall(function()
                getgenv().Rayfield:Notify({
                    Title = "Discord",
                    Content = "Join: discord.gg/vortex-x-sideload-bypass-1355388445509288047",
                    Duration = 3,
                    Image = "discord"
                })
            end)
            Shared.createNotification("Discord invite shown", Color3.new(0,1,1))
        end
    })

    return tab
end
