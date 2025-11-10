return function(Window, Shared)
    local tab = Window:CreateTab("Player", "user")
    
    local function enableNoclip()
        if Shared.noclipConnection then
            Shared.noclipConnection:Disconnect()
        end
        local character = Shared.localPlayer.Character
        if not character then return end
        Shared.originalCollision = {}
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                Shared.originalCollision[part] = part.CanCollide
            end
        end
        Shared.noclipConnection = Shared.RunService.Stepped:Connect(function()
            if Shared.localPlayer.Character then
                for _, part in pairs(Shared.localPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
        Shared.createNotification("Noclip ON", Color3.new(0,1,1))
    end

    local function disableNoclip()
        if Shared.noclipConnection then
            Shared.noclipConnection:Disconnect()
            Shared.noclipConnection = nil
        end
        spawn(function()
            wait(0.5)
            if Shared.localPlayer.Character then
                for part, originalState in pairs(Shared.originalCollision) do
                    if part and part.Parent then
                        part.CanCollide = originalState
                    end
                end
            end
        end)
        Shared.createNotification("Noclip OFF", Color3.new(1,0,0))
    end

    local function updateWalkSpeed()
        local character = Shared.localPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if Shared.MooSettings.WalkSpeedEnabled then
                    humanoid.WalkSpeed = Shared.MooSettings.WalkSpeed
                else
                    humanoid.WalkSpeed = Shared.originalWalkSpeed
                end
            end
        end
    end

    local function updateJumpPower()
        local character = Shared.localPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if Shared.MooSettings.JumpPowerEnabled then
                    humanoid.JumpPower = Shared.MooSettings.JumpPower
                else
                    humanoid.JumpPower = Shared.originalJumpPower
                end
            end
        end
    end

    Shared.localPlayer.CharacterAdded:Connect(function(character)
        wait(1)
        updateWalkSpeed()
        updateJumpPower()
    end)

    Shared.RunService.Heartbeat:Connect(function()
        if Shared.MooSettings.WalkSpeedEnabled then
            updateWalkSpeed()
        end
        if Shared.MooSettings.JumpPowerEnabled then
            updateJumpPower()
        end
    end)

    tab:CreateSection("Player Movement")
    tab:CreateToggle({
        Name = "Noclip",
        CurrentValue = Shared.MooSettings.NoclipEnabled,
        Flag = "NoclipEnabled",
        Callback = function(val)
            Shared.MooSettings.NoclipEnabled = val
            if val then
                enableNoclip()
            else
                disableNoclip()
            end
        end
    })

    tab:CreateToggle({
        Name = "Walk Speed",
        CurrentValue = Shared.MooSettings.WalkSpeedEnabled,
        Flag = "WalkSpeedEnabled",
        Callback = function(val)
            Shared.MooSettings.WalkSpeedEnabled = val
            if val then
                updateWalkSpeed()
                Shared.createNotification("Walk Speed enabled: "..Shared.MooSettings.WalkSpeed, Color3.new(0,1,0))
            else
                updateWalkSpeed()
                Shared.createNotification("Walk Speed disabled", Color3.new(1,0,0))
            end
        end
    })

    tab:CreateSlider({
        Name = "Walk Speed Value",
        Range = {16, 200},
        Increment = 1,
        Suffix = "speed",
        CurrentValue = Shared.MooSettings.WalkSpeed,
        Flag = "WalkSpeedValue",
        Callback = function(val)
            Shared.MooSettings.WalkSpeed = val
            updateWalkSpeed()
            Shared.createNotification("Walk Speed set to "..tostring(val), Color3.new(0,1,1))
        end
    })

    tab:CreateToggle({
        Name = "Jump Power",
        CurrentValue = Shared.MooSettings.JumpPowerEnabled,
        Flag = "JumpPowerEnabled",
        Callback = function(val)
            Shared.MooSettings.JumpPowerEnabled = val
            if val then
                updateJumpPower()
                Shared.createNotification("Jump Power enabled: "..Shared.MooSettings.JumpPower, Color3.new(0,1,0))
            else
                updateJumpPower()
                Shared.createNotification("Jump Power disabled", Color3.new(1,0,0))
            end
        end
    })

    tab:CreateSlider({
        Name = "Jump Power Value",
        Range = {50, 200},
        Increment = 1,
        Suffix = "power",
        CurrentValue = Shared.MooSettings.JumpPower,
        Flag = "JumpPowerValue",
        Callback = function(val)
            Shared.MooSettings.JumpPower = val
            updateJumpPower()
            Shared.createNotification("Jump Power set to "..tostring(val), Color3.new(0,1,1))
        end
    })

    tab:CreateButton({
        Name = "Refresh Player Stats",
        Callback = function()
            updateWalkSpeed()
            updateJumpPower()
            Shared.createNotification("Player stats refreshed", Color3.new(0,1,1))
        end
    })

    return tab
end
