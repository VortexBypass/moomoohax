return function(Window, Shared)
    local tab = Window:CreateTab("Aimlock", "target")
    
    local MAX_DISTANCE = 1000
    local FOV_RADIUS = 60
    local r2TapCount = 0
    local lastR2Tap = 0
    local mobileTapCount = 0
    local lastMobileTap = 0
    local mobileAimlockButton = nil

    local function createCrosshair(position)
        if Shared.crosshairGui then
            pcall(function() Shared.crosshairGui:Destroy() end)
            Shared.crosshairFrame = nil
            Shared.outerRingFrame = nil
            table.clear(Shared.crosshairElements)
        end
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "Crosshair"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.Parent = Shared.Players.LocalPlayer:WaitForChild("PlayerGui")
        local outerRing = Instance.new("Frame")
        outerRing.Name = "OuterRing"
        outerRing.Size = UDim2.new(0,18,0,18)
        outerRing.AnchorPoint = Vector2.new(0.5,0.5)
        outerRing.BackgroundColor3 = Color3.new(0,0,0)
        outerRing.BackgroundTransparency = 0
        outerRing.BorderSizePixel = 0
        outerRing.ZIndex = 998
        outerRing.Parent = screenGui
        local outerCorner = Instance.new("UICorner")
        outerCorner.CornerRadius = UDim.new(1,0)
        outerCorner.Parent = outerRing
        local crosshair = Instance.new("Frame")
        crosshair.Name = "InnerCrosshair"
        crosshair.Size = UDim2.new(0,14,0,14)
        crosshair.AnchorPoint = Vector2.new(0.5,0.5)
        crosshair.BackgroundColor3 = Color3.new(1,1,1)
        crosshair.BackgroundTransparency = 0
        crosshair.BorderSizePixel = 0
        crosshair.ZIndex = 999
        crosshair.Parent = screenGui
        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(1,0)
        UICorner.Parent = crosshair
        if position then
            crosshair.Position = position
            outerRing.Position = position
        else
            crosshair.Position = UDim2.new(0.5,0,0.5,0)
            outerRing.Position = UDim2.new(0.5,0,0.5,0)
        end
        Shared.crosshairGui = screenGui
        Shared.crosshairFrame = crosshair
        Shared.outerRingFrame = outerRing
        Shared.crosshairElements = { screenGui = screenGui, crosshair = crosshair, outerRing = outerRing }
        return screenGui
    end

    local function moveCrosshairToPosition(position)
        if Shared.crosshairFrame and Shared.outerRingFrame then
            Shared.crosshairFrame.Position = position
            Shared.outerRingFrame.Position = position
            Shared.createNotification("Crosshair moved", Color3.new(1,1,0))
        end
    end

    local function moveCrosshairToMouse()
        local mouse = Shared.Players.LocalPlayer:GetMouse()
        moveCrosshairToPosition(UDim2.new(0, mouse.X, 0, mouse.Y))
    end

    local function findTargetNearCrosshair()
        local camera = Shared.Workspace.CurrentCamera
        local localCharacter = Shared.localPlayer.Character
        if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return nil end
        local bestTarget = nil
        local closestScreenDistance = math.huge
        local localPos = localCharacter.HumanoidRootPart.Position
        local screenCenter
        if Shared.crosshairFrame then
            local absPos = Shared.crosshairFrame.AbsolutePosition
            local absSize = Shared.crosshairFrame.AbsoluteSize
            screenCenter = absPos + absSize / 2
        else
            screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        end
        for _, player in ipairs(Shared.Players:GetPlayers()) do
            if player ~= Shared.localPlayer and player.Character then
                local targetPart = player.Character:FindFirstChild("Head") or player.Character:FindFirstChild("HumanoidRootPart")
                local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
                local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
                if targetPart and humanoid and humanoid.Health > 0 and rootPart then
                    local distanceToPlayer = (rootPart.Position - localPos).Magnitude
                    if distanceToPlayer <= MAX_DISTANCE then
                        local screenPos, onScreen = camera:WorldToScreenPoint(targetPart.Position)
                        if onScreen then
                            local screenPoint = Vector2.new(screenPos.X, screenPos.Y)
                            local distanceToCenter = (screenPoint - screenCenter).Magnitude
                            if distanceToCenter <= FOV_RADIUS then
                                if distanceToCenter < closestScreenDistance then
                                    closestScreenDistance = distanceToCenter
                                    bestTarget = player
                                end
                            end
                        end
                    end
                end
            end
        end
        return bestTarget
    end

    local function toggleAimlock()
        if not Shared.MooSettings.AimlockEnabled then
            Shared.MooAimlock.Enabled = false
            Shared.MooAimlock.CurrentTarget = nil
            Shared.MooAimlock.LockedTarget = nil
            Shared.createNotification("Aimlock disabled", Color3.new(1,0,0))
            return
        end
        if Shared.MooAimlock.Enabled then
            Shared.MooAimlock.Enabled = false
            Shared.MooAimlock.CurrentTarget = nil
            Shared.MooAimlock.LockedTarget = nil
            Shared.createNotification("Aimlock OFF", Color3.new(1,0,0))
        else
            local target = findTargetNearCrosshair()
            if target then
                Shared.MooAimlock.Enabled = true
                Shared.MooAimlock.CurrentTarget = target
                Shared.MooAimlock.LockedTarget = target
                Shared.createNotification("Locked "..target.Name, Color3.new(0,1,0))
            else
                Shared.createNotification("No target found", Color3.new(1,0,0))
            end
        end
    end

    local function createMobileAimlockButton()
        if mobileAimlockButton then
            mobileAimlockButton:Destroy()
        end
        
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "MobileAimlockButton"
        screenGui.ResetOnSpawn = false
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        screenGui.Parent = Shared.Players.LocalPlayer:WaitForChild("PlayerGui")
        
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 80, 0, 80)
        button.Position = UDim2.new(0.5, -40, 0.8, 0)
        button.BackgroundColor3 = Color3.new(1, 0, 0)
        button.BackgroundTransparency = 0.3
        button.Text = "AIM\nLOCK"
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextScaled = true
        button.Font = Enum.Font.GothamBold
        button.BorderSizePixel = 0
        button.ZIndex = 1000
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = button
        
        button.Parent = screenGui
        mobileAimlockButton = screenGui
        
        local dragging = false
        local dragInput
        local dragStart
        local startPos
        
        button.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = button.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        button.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        
        Shared.UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                button.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        
        button.MouseButton1Click:Connect(function()
            if Shared.MooSettings.AimlockEnabled then
                toggleAimlock()
                if Shared.MooAimlock.Enabled then
                    button.BackgroundColor3 = Color3.new(0, 1, 0)
                    button.Text = "AIM\nON"
                else
                    button.BackgroundColor3 = Color3.new(1, 0, 0)
                    button.Text = "AIM\nOFF"
                end
            else
                Shared.createNotification("Enable Aimlock first", Color3.new(1,0,0))
            end
        end)
        
        return screenGui
    end

    local function mobileToggleAimlock()
        if not Shared.MooSettings.AimlockEnabled then
            Shared.createNotification("Enable Aimlock first", Color3.new(1,0,0))
            return
        end
        toggleAimlock()
    end

    Shared.UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Q and Shared.MooSettings.AimlockEnabled then
                toggleAimlock()
            end
        end
        
        if input.UserInputType == Enum.UserInputType.Gamepad1 then
            if input.KeyCode == Enum.KeyCode.ButtonL2 and Shared.MooSettings.AimlockEnabled then
                toggleAimlock()
            end
            if input.KeyCode == Enum.KeyCode.ButtonR2 then
                local currentTime = tick()
                if currentTime - lastR2Tap < 1 then
                    r2TapCount = r2TapCount + 1
                else
                    r2TapCount = 1
                end
                lastR2Tap = currentTime
                if r2TapCount >= 4 then
                    r2TapCount = 0
                    moveCrosshairToMouse()
                end
            end
        end
        
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            local currentTime = tick()
            if currentTime - lastR2Tap < 1 then
                r2TapCount = r2TapCount + 1
            else
                r2TapCount = 1
            end
            lastR2Tap = currentTime
            if r2TapCount >= 4 then
                r2TapCount = 0
                moveCrosshairToMouse()
            end
        end
        
        if input.UserInputType == Enum.UserInputType.Touch then
            local currentTime = tick()
            if currentTime - lastMobileTap < 1 then
                mobileTapCount = mobileTapCount + 1
            else
                mobileTapCount = 1
            end
            lastMobileTap = currentTime
            if mobileTapCount >= 4 then
                mobileTapCount = 0
                moveCrosshairToPosition(UDim2.new(0, input.Position.X, 0, input.Position.Y))
            end
        end
    end)

    Shared.RunService.RenderStepped:Connect(function()
        if Shared.MooAimlock.Enabled and Shared.MooAimlock.LockedTarget then
            local targetPlayer = Shared.MooAimlock.LockedTarget
            if targetPlayer and targetPlayer.Character then
                local targetPart = targetPlayer.Character:FindFirstChild("Head") or targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                local camera = Shared.Workspace.CurrentCamera
                local localCharacter = Shared.localPlayer.Character
                if targetPart and camera and localCharacter then
                    local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
                    local rootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
                    if humanoid and humanoid.Health > 0 and rootPart then
                        local targetPosition = targetPart.Position
                        camera.CFrame = CFrame.new(camera.CFrame.Position, targetPosition)
                    else
                        Shared.MooAimlock.Enabled = false
                        Shared.MooAimlock.CurrentTarget = nil
                        Shared.MooAimlock.LockedTarget = nil
                        Shared.createNotification("Target lost", Color3.new(1,0,0))
                    end
                else
                    Shared.MooAimlock.Enabled = false
                    Shared.MooAimlock.CurrentTarget = nil
                    Shared.MooAimlock.LockedTarget = nil
                end
            else
                Shared.MooAimlock.Enabled = false
                Shared.MooAimlock.CurrentTarget = nil
                Shared.MooAimlock.LockedTarget = nil
            end
        end
    end)

    tab:CreateSection("Aimlock Controls")
    tab:CreateParagraph({Title = "PC Controls", Content = "Aimlock: Q Key | Move Crosshair: Right Click 4 times quickly"})
    tab:CreateParagraph({Title = "Mobile Controls", Content = "Aimlock: Use button below | Move Crosshair: Tap screen 4 times quickly"})
    tab:CreateParagraph({Title = "Controller Controls", Content = "Aimlock: L2 Button | Move Crosshair: R2 Button 4 times quickly"})

    tab:CreateSection("Aimlock Settings")
    tab:CreateToggle({
        Name = "Enable Aimlock",
        CurrentValue = Shared.MooSettings.AimlockEnabled,
        Flag = "AimlockEnabled",
        Callback = function(val)
            Shared.MooSettings.AimlockEnabled = val
            if val then
                Shared.createNotification("Aimlock enabled", Color3.new(0,1,0))
            else
                Shared.MooAimlock.Enabled = false
                Shared.MooAimlock.CurrentTarget = nil
                Shared.MooAimlock.LockedTarget = nil
                Shared.createNotification("Aimlock disabled", Color3.new(1,0,0))
            end
        end
    })

    tab:CreateButton({
        Name = "Show Mobile Aimlock Button",
        Callback = function()
            createMobileAimlockButton()
            Shared.createNotification("Mobile aimlock button created", Color3.new(0,1,0))
        end
    })

    tab:CreateButton({
        Name = "Hide Mobile Aimlock Button",
        Callback = function()
            if mobileAimlockButton then
                mobileAimlockButton:Destroy()
                mobileAimlockButton = nil
                Shared.createNotification("Mobile aimlock button hidden", Color3.new(1,0,0))
            end
        end
    })

    tab:CreateSlider({
        Name = "FOV Radius",
        Range = {10,300},
        Increment = 1,
        Suffix = "px",
        CurrentValue = FOV_RADIUS,
        Flag = "FOVSlider",
        Callback = function(val)
            FOV_RADIUS = val
            Shared.createNotification("FOV set to "..tostring(val), Color3.new(0,1,1))
        end
    })

    tab:CreateSlider({
        Name = "Max Distance",
        Range = {100,4000},
        Increment = 50,
        Suffix = "studs",
        CurrentValue = MAX_DISTANCE,
        Flag = "MaxDistSlider",
        Callback = function(val)
            MAX_DISTANCE = val
            Shared.createNotification("Max distance set to "..tostring(val), Color3.new(0,1,1))
        end
    })

    tab:CreateKeybind({
        Name = "PC Aimlock Keybind",
        CurrentKeybind = "Q",
        HoldToInteract = false,
        Flag = "AimKeybind",
        Callback = toggleAimlock
    })

    tab:CreateButton({
        Name = "Lock Nearest",
        Callback = function()
            local target = findTargetNearCrosshair()
            if target then
                Shared.MooAimlock.Enabled = true
                Shared.MooAimlock.CurrentTarget = target
                Shared.MooAimlock.LockedTarget = target
                Shared.createNotification("Locked "..target.Name, Color3.new(0,1,0))
            else
                Shared.createNotification("No target", Color3.new(1,0,0))
            end
        end
    })

    tab:CreateButton({
        Name = "Unlock",
        Callback = function()
            Shared.MooAimlock.Enabled = false
            Shared.MooAimlock.CurrentTarget = nil
            Shared.MooAimlock.LockedTarget = nil
            Shared.createNotification("Aimlock unlocked", Color3.new(1,0,0))
        end
    })

    spawn(function()
        wait(1)
        createCrosshair()
    end)

    return tab
end
