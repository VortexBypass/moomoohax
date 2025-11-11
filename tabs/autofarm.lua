return function(Window, Shared)
    local tab = Window:CreateTab("AutoFarm", "truck")
    local originalPosition = nil
    local originalTransparency = {}
    local invisibilityEnabled = false
    local farmingThread = nil

    local function createAirPlatform()
        if Shared.airPlatform then
            pcall(function() Shared.airPlatform:Destroy() end)
        end
        Shared.airPlatform = Instance.new("Part")
        Shared.airPlatform.Name = "MooHaxAirPlatform"
        Shared.airPlatform.Size = Vector3.new(50, 5, 50)
        Shared.airPlatform.Position = Vector3.new(0, 200, 0)
        Shared.airPlatform.Anchored = true
        Shared.airPlatform.CanCollide = true
        Shared.airPlatform.Transparency = 0.5
        Shared.airPlatform.BrickColor = BrickColor.new("Bright blue")
        Shared.airPlatform.Material = Enum.Material.Neon
        Shared.airPlatform.Parent = Shared.Workspace
    end

    local function makePlayerInvisible(character)
        if not character then return end
        invisibilityEnabled = true
        originalTransparency = {}
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                originalTransparency[part] = part.Transparency
                part.Transparency = 1
            end
        end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        end
    end

    local function restorePlayerVisibility(character)
        if not character then return end
        invisibilityEnabled = false
        for part, transparency in pairs(originalTransparency) do
            if part and part.Parent then
                part.Transparency = transparency
            end
        end
        originalTransparency = {}
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        end
    end

    local function onCharacterAdded(character)
        if invisibilityEnabled and Shared.MooSettings.AutoFarmEnabled then
            wait(1)
            makePlayerInvisible(character)
        end
    end

    Shared.localPlayer.CharacterAdded:Connect(onCharacterAdded)

    local function safeTeleportToPlatform(character)
        if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
        if not Shared.airPlatform then createAirPlatform() end
        local rootPart = character.HumanoidRootPart
        local savedNoclipState = Shared.MooSettings.NoclipEnabled
        if not savedNoclipState then
            Shared.MooSettings.NoclipEnabled = true
            if Shared.noclipConnection then
                pcall(function() Shared.noclipConnection:Disconnect() end)
            end
            Shared.originalCollision = {}
            for _, part in pairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    Shared.originalCollision[part] = part.CanCollide
                    part.CanCollide = false
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
        end

        local platPos = Shared.airPlatform.Position
        local platHalfY = Shared.airPlatform.Size.Y / 2
        local rootHalfY = (rootPart.Size and rootPart.Size.Y / 2) or 1
        local placeY = platPos.Y + platHalfY + rootHalfY + 1
        rootPart.CFrame = CFrame.new(platPos.X, placeY, platPos.Z)
        wait(0.05)
        rootPart.CFrame = CFrame.new(platPos.X, placeY, platPos.Z)
        local timeout = 0
        while timeout < 2 do
            if rootPart.Position.Y >= platPos.Y + platHalfY - 0.5 then break end
            wait(0.05)
            timeout = timeout + 0.05
        end

        if not savedNoclipState then
            wait(0.2)
            if Shared.noclipConnection then
                pcall(function() Shared.noclipConnection:Disconnect() end)
                Shared.noclipConnection = nil
            end
            spawn(function()
                wait(0.3)
                if Shared.localPlayer.Character then
                    for part, originalState in pairs(Shared.originalCollision) do
                        if part and part.Parent then
                            part.CanCollide = originalState
                        end
                    end
                end
            end)
            Shared.MooSettings.NoclipEnabled = false
        end

        return true
    end

    local function findCashPiles()
        local cashPiles = {}
        for _, obj in pairs(Shared.Workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("Model") then
                local name = tostring(obj.Name):lower()
                if string.find(name, "cash") then
                    table.insert(cashPiles, obj)
                end
            end
        end
        return cashPiles
    end

    local function getClosestCashPile()
        local character = Shared.localPlayer.Character
        if not character then return nil end
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return nil end
        local cashPiles = findCashPiles()
        local closestPile = nil
        local closestDistance = Shared.MooSettings.FarmRange or 100
        for _, pile in pairs(cashPiles) do
            local distance
            if pile:IsA("Model") then
                local primaryPart = pile.PrimaryPart or pile:FindFirstChildWhichIsA("BasePart")
                if primaryPart then
                    distance = (rootPart.Position - primaryPart.Position).Magnitude
                else
                    distance = math.huge
                end
            else
                distance = (rootPart.Position - pile.Position).Magnitude
            end
            if distance < closestDistance then
                closestDistance = distance
                closestPile = pile
            end
        end
        return closestPile
    end

    local function collectPile(closestPile, character)
        if not closestPile or not character or not character:FindFirstChild("HumanoidRootPart") then return false end
        local root = character.HumanoidRootPart
        local targetPos
        if closestPile:IsA("Model") then
            local primaryPart = closestPile.PrimaryPart or closestPile:FindFirstChildWhichIsA("BasePart")
            if not primaryPart then return false end
            targetPos = primaryPart.Position
        else
            targetPos = closestPile.Position
        end
        root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        wait(0.15)
        if closestPile:IsA("Model") then
            for _, part in pairs(closestPile:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(root, part, 0)
                        wait()
                        firetouchinterest(root, part, 1)
                    end)
                end
            end
        else
            pcall(function()
                firetouchinterest(root, closestPile, 0)
                wait()
                firetouchinterest(root, closestPile, 1)
            end)
        end
        wait(0.6)
        return true
    end

    local function startAutoFarm()
        if farmingThread then
            farmingThread = nil
        end
        local character = Shared.localPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            originalPosition = character.HumanoidRootPart.Position
            makePlayerInvisible(character)
        end
        createAirPlatform()
        Shared.createNotification("AutoFarm started", Color3.new(0,1,0))
        farmingThread = spawn(function()
            while Shared.MooSettings.AutoFarmEnabled do
                local character = Shared.localPlayer.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then
                    wait(0.5)
                    continue
                end
                if not invisibilityEnabled then
                    makePlayerInvisible(character)
                end
                safeTeleportToPlatform(character)
                local waitBeforeCollect = Shared.MooSettings.CollectDelay or 5
                wait(waitBeforeCollect)
                if not Shared.MooSettings.AutoFarmEnabled then break end
                local closestPile = getClosestCashPile()
                if closestPile then
                    local ok = collectPile(closestPile, character)
                    if ok then
                        safeTeleportToPlatform(character)
                        Shared.createNotification("AutoFarm: Collected cash", Color3.new(0,1,0))
                    else
                        safeTeleportToPlatform(character)
                        Shared.createNotification("AutoFarm: Collect failed", Color3.new(1,0.6,0))
                    end
                else
                    Shared.createNotification("No cash piles found in range", Color3.new(1,1,0))
                    safeTeleportToPlatform(character)
                end
                local loopDelay = Shared.MooSettings.LoopDelay or 5
                local elapsed = 0
                while elapsed < loopDelay and Shared.MooSettings.AutoFarmEnabled do
                    wait(0.25)
                    elapsed = elapsed + 0.25
                end
            end
            if not Shared.MooSettings.AutoFarmEnabled then
                if Shared.airPlatform then
                    pcall(function() Shared.airPlatform:Destroy() end)
                    Shared.airPlatform = nil
                end
                local char = Shared.localPlayer.Character
                if char then
                    restorePlayerVisibility(char)
                end
                if originalPosition then
                    local c = Shared.localPlayer.Character
                    if c and c:FindFirstChild("HumanoidRootPart") then
                        c.HumanoidRootPart.CFrame = CFrame.new(originalPosition)
                        Shared.createNotification("Returned to original position", Color3.new(0,1,1))
                    end
                    originalPosition = nil
                end
                Shared.createNotification("AutoFarm stopped", Color3.new(1,0,0))
            end
        end)
    end

    local function stopAutoFarm()
        Shared.MooSettings.AutoFarmEnabled = false
    end

    tab:CreateSection("Auto Farm")
    tab:CreateToggle({
        Name = "Auto Farm Cash",
        CurrentValue = Shared.MooSettings.AutoFarmEnabled,
        Flag = "AutoFarmToggle",
        Callback = function(val)
            Shared.MooSettings.AutoFarmEnabled = val
            if val then
                startAutoFarm()
            else
                stopAutoFarm()
            end
        end
    })

    tab:CreateParagraph({
        Title = "Auto Farm Info",
        Content = "Teleports to any object with 'Cash' in its name"
    })

    tab:CreateSlider({
        Name = "Farm Range",
        Range = {10,200},
        Increment = 1,
        Suffix = "studs",
        CurrentValue = Shared.MooSettings.FarmRange,
        Flag = "FarmRange",
        Callback = function(val)
            Shared.MooSettings.FarmRange = val
            Shared.createNotification("Farm range "..tostring(val), Color3.new(0,1,1))
        end
    })

    tab:CreateButton({
        Name = "Collect Nearest Now",
        Callback = function()
            local pile = getClosestCashPile()
            if pile then
                local char = Shared.localPlayer.Character
                if char then
                    collectPile(pile, char)
                    safeTeleportToPlatform(char)
                end
            else
                Shared.createNotification("No cash pile nearby", Color3.new(1,1,0))
            end
        end
    })

    return tab
end
