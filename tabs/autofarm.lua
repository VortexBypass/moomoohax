return function(Window, Shared)
    local tab = Window:CreateTab("AutoFarm", "truck")
    local originalPosition = nil
    local originalTransparency = {}
    local invisibilityEnabled = false
    local runningThread = nil

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
            if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Model") then
                local ok, name = pcall(function() return tostring(obj.Name):lower() end)
                if ok and name and string.find(name, "cash") then
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

    local function collectPile(pile, character)
        if not pile or not character or not character:FindFirstChild("HumanoidRootPart") then return false end
        local root = character.HumanoidRootPart
        local targetPos
        if pile:IsA("Model") then
            local primaryPart = pile.PrimaryPart or pile:FindFirstChildWhichIsA("BasePart")
            if not primaryPart then
                for _, p in pairs(pile:GetDescendants()) do
                    if p:IsA("BasePart") then
                        primaryPart = p
                        break
                    end
                end
            end
            if not primaryPart then return false end
            targetPos = primaryPart.Position
        else
            targetPos = pile.Position
        end
        local attempts = 0
        local maxAttempts = 6
        while attempts < maxAttempts and pile.Parent and Shared.MooSettings.AutoFarmEnabled do
            root.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
            wait(0.12)
            if pile:IsA("Model") then
                for _, part in pairs(pile:GetDescendants()) do
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
                    firetouchinterest(root, pile, 0)
                    wait()
                    firetouchinterest(root, pile, 1)
                end)
            end
            attempts = attempts + 1
            wait(0.25)
        end
        if not pile.Parent then
            return true
        end
        if pile:IsA("Model") then
            local primaryPart = pile.PrimaryPart or pile:FindFirstChildWhichIsA("BasePart")
            if not primaryPart then
                local anyPart = nil
                for _, p in pairs(pile:GetDescendants()) do
                    if p:IsA("BasePart") then
                        anyPart = p
                        break
                    end
                end
                if anyPart and anyPart.Parent == nil then
                    return true
                end
            elseif primaryPart.Parent == nil then
                return true
            end
        end
        return false
    end

    local function startAutoFarm()
        if runningThread then return end
        runningThread = true
        local char = Shared.localPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            originalPosition = char.HumanoidRootPart.Position
            makePlayerInvisible(char)
        end
        createAirPlatform()
        Shared.createNotification("AutoFarm started", Color3.new(0,1,0))
        spawn(function()
            while runningThread and Shared.MooSettings.AutoFarmEnabled do
                local character = Shared.localPlayer.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then
                    wait(0.6)
                    goto continue_loop
                end
                if not invisibilityEnabled then
                    makePlayerInvisible(character)
                end
                safeTeleportToPlatform(character)
                local waitBeforeCollect = Shared.MooSettings.CollectDelay or 5
                for i = waitBeforeCollect, 1, -1 do
                    if not Shared.MooSettings.AutoFarmEnabled then break end
                    Shared.createNotification("Collecting in "..tostring(i).."s", Color3.new(0,1,1))
                    wait(1)
                end
                if not Shared.MooSettings.AutoFarmEnabled then break end
                local closestPile = getClosestCashPile()
                if not closestPile then
                    Shared.createNotification("No cash piles found in range", Color3.new(1,1,0))
                    safeTeleportToPlatform(character)
                    local loopDelay = Shared.MooSettings.LoopDelay or 5
                    for t = loopDelay, 1, -1 do
                        if not Shared.MooSettings.AutoFarmEnabled then break end
                        if t % 1 == 0 then
                            Shared.createNotification("Next attempt in "..tostring(t).."s", Color3.new(0.7,0.7,1))
                        end
                        wait(1)
                    end
                    goto continue_loop
                end
                local ok = collectPile(closestPile, character)
                if ok then
                    Shared.createNotification("AutoFarm: Collected cash", Color3.new(0,1,0))
                else
                    Shared.createNotification("AutoFarm: Collect failed, will retry", Color3.new(1,0.6,0))
                end
                safeTeleportToPlatform(character)
                local loopDelay2 = Shared.MooSettings.LoopDelay or 5
                for t = loopDelay2, 1, -1 do
                    if not Shared.MooSettings.AutoFarmEnabled then break end
                    if t % 1 == 0 then
                        Shared.createNotification("Next run in "..tostring(t).."s", Color3.new(0.7,0.7,1))
                    end
                    wait(1)
                end
                ::continue_loop::
                wait(0.1)
            end
            runningThread = nil
            if not Shared.MooSettings.AutoFarmEnabled then
                if Shared.airPlatform then
                    pcall(function() Shared.airPlatform:Destroy() end)
                    Shared.airPlatform = nil
                end
                local c = Shared.localPlayer.Character
                if c then
                    restorePlayerVisibility(c)
                end
                if originalPosition then
                    local c2 = Shared.localPlayer.Character
                    if c2 and c2:FindFirstChild("HumanoidRootPart") then
                        c2.HumanoidRootPart.CFrame = CFrame.new(originalPosition)
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
        runningThread = nil
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
                    local ok = collectPile(pile, char)
                    if ok then
                        Shared.createNotification("Manual collect succeeded", Color3.new(0,1,0))
                    else
                        Shared.createNotification("Manual collect failed", Color3.new(1,0.6,0))
                    end
                    safeTeleportToPlatform(char)
                end
            else
                Shared.createNotification("No cash pile nearby", Color3.new(1,1,0))
            end
        end
    })

    return tab
end
