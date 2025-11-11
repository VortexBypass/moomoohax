return function(Window, Shared)
    local tab = Window:CreateTab("ESP", "eye")
    local espRefreshConnection = nil

    local function createESP(targetPlayer)
        if not targetPlayer then return end
        if Shared.espFolders[targetPlayer] then
            pcall(function() Shared.espFolders[targetPlayer]:Destroy() end)
            Shared.espFolders[targetPlayer] = nil
        end

        local function setupESP(character)
            if not character then return end
            local tries = 0
            while tries < 10 and not character:FindFirstChildOfClass("Humanoid") do
                wait(0.1)
                tries = tries + 1
            end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then return end
            local highlight = Instance.new("Highlight")
            highlight.Name = "PlayerESP"
            highlight.FillColor = Shared.MooSettings.ESPFillColor or Color3.fromRGB(255,0,0)
            highlight.OutlineColor = Color3.new(1,1,1)
            highlight.FillTransparency = Shared.MooSettings.ESPFillTransparency or 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = character
            highlight.Parent = Shared.Workspace
            Shared.espFolders[targetPlayer] = highlight
            humanoid.Died:Connect(function()
                if Shared.espFolders[targetPlayer] then
                    pcall(function() Shared.espFolders[targetPlayer]:Destroy() end)
                    Shared.espFolders[targetPlayer] = nil
                end
            end)
        end

        if targetPlayer.Character then
            setupESP(targetPlayer.Character)
        end
        targetPlayer.CharacterAdded:Connect(function(character)
            setupESP(character)
        end)
    end

    local function initializeESP()
        for player, highlight in pairs(Shared.espFolders) do
            if highlight then
                pcall(function() highlight:Destroy() end)
            end
        end
        Shared.espFolders = {}
        for _, player in ipairs(Shared.Players:GetPlayers()) do
            createESP(player)
        end
    end

    local function startAutoRefresh()
        if espRefreshConnection then
            espRefreshConnection:Disconnect()
        end
        espRefreshConnection = Shared.RunService.Heartbeat:Connect(function()
            if not Shared.MooSettings.ESPEnabled then return end
            for _, player in ipairs(Shared.Players:GetPlayers()) do
                if not Shared.espFolders[player] then
                    createESP(player)
                else
                    local h = Shared.espFolders[player]
                    if h and h.Parent and h.Adornee ~= player.Character then
                        pcall(function() h:Destroy() end)
                        Shared.espFolders[player] = nil
                        createESP(player)
                    end
                end
            end
        end)
    end

    local function stopAutoRefresh()
        if espRefreshConnection then
            espRefreshConnection:Disconnect()
            espRefreshConnection = nil
        end
    end

    local function refreshESP()
        initializeESP()
        Shared.createNotification("ESP refreshed", Color3.new(0,1,1))
    end

    Shared.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.ButtonX then
            refreshESP()
        end
    end)

    Shared.Players.PlayerAdded:Connect(function(player)
        wait(0.5)
        if Shared.MooSettings.ESPEnabled then
            createESP(player)
        end
    end)

    Shared.Players.PlayerRemoving:Connect(function(player)
        if Shared.espFolders[player] then
            pcall(function() Shared.espFolders[player]:Destroy() end)
            Shared.espFolders[player] = nil
        end
    end)

    tab:CreateSection("ESP")
    tab:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = Shared.MooSettings.ESPEnabled,
        Flag = "ESPEnabled",
        Callback = function(val)
            Shared.MooSettings.ESPEnabled = val
            if val then
                initializeESP()
                startAutoRefresh()
                Shared.createNotification("ESP enabled", Color3.new(0,1,0))
            else
                stopAutoRefresh()
                for player, highlight in pairs(Shared.espFolders) do
                    if highlight then
                        pcall(function() highlight:Destroy() end)
                    end
                end
                Shared.espFolders = {}
                Shared.createNotification("ESP disabled", Color3.new(1,0,0))
            end
        end
    })

    tab:CreateColorPicker({
        Name = "ESP Color",
        Color = Shared.MooSettings.ESPFillColor,
        Flag = "ESPColor",
        Callback = function(val)
            Shared.MooSettings.ESPFillColor = val
            for _, h in pairs(Shared.espFolders) do
                pcall(function() if h and h.Parent then h.FillColor = val end end)
            end
            Shared.createNotification("ESP color updated", Color3.new(0,1,1))
        end
    })

    tab:CreateSlider({
        Name = "ESP Transparency",
        Range = {0,100},
        Increment = 1,
        Suffix = "%",
        CurrentValue = math.floor((Shared.MooSettings.ESPFillTransparency or 0.5)*100),
        Flag = "ESPTrans",
        Callback = function(val)
            local t = math.clamp(val/100,0,1)
            Shared.MooSettings.ESPFillTransparency = t
            for _, h in pairs(Shared.espFolders) do
                pcall(function() if h and h.Parent then h.FillTransparency = t end end)
            end
            Shared.createNotification("ESP transparency set to "..t, Color3.new(0,1,1))
        end
    })

    tab:CreateButton({
        Name = "Refresh ESP",
        Callback = refreshESP
    })

    if Shared.MooSettings.ESPEnabled then
        initializeESP()
        startAutoRefresh()
    end

    return tab
end
