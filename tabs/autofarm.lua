return function(Window, Shared)
    local tab = Window:CreateTab("AutoFarm", "truck")
    
    local isFarming = false
    local originalPosition = nil
    local originalTransparency = {}

    local function createAirPlatform()
        if Shared.airPlatform then
            Shared.airPlatform:Destroy()
        end
        
        Shared.airPlatform = Instance.new("Part")
        Shared.airPlatform.Name = "MooHaxAirPlatform"
        Shared.airPlatform.Size = Vector3.new(50, 5, 50)
        Shared.airPlatform.Position = Vector3.new(0, 99, 0)
        Shared.airPlatform.Anchored = true
        Shared.airPlatform.CanCollide = true
        Shared.airPlatform.Transparency = 0.5
        Shared.airPlatform.BrickColor = BrickColor.new("Bright blue")
        Shared.airPlatform.Material = Enum.Material.Neon
        Shared.airPlatform.Parent = Shared.Workspace
    end

    local function makePlayerInvisible(character)
        if not character then return end
        originalTransparency = {}
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                originalTransparency[part] = part.Transparency
                part.Transparency = 1
            end
        end
    end

    local function restorePlayerVisibility(character)
        if not character then return end
        for part, transparency in pairs(originalTransparency) do
            if part and part.Parent then
                part.Transparency = transparency
            end
        end
        originalTransparency = {}
    end

    local function safeTeleportToPlatform(character)
        if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
        
        local rootPart = character.HumanoidRootPart
        
        local savedNoclipState = Shared.MooSettings.NoclipEnabled
        if not savedNoclipState then
            Shared.MooSettings.NoclipEnabled = true
            if Shared.noclipConnection then
                Shared.noclipConnection:Disconnect()
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
        
        rootPart.CFrame = CFrame.new(0, 105, 0)
        wait(0.1)
        rootPart.CFrame = CFrame.new(0, 105, 0)
        wait(0.1)
        rootPart.CFrame = CFrame.new(0, 102, 0)
        
        if not savedNoclipState then
            wait(0.5)
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
            Shared.MooSettings.NoclipEnabled = false
        end
        
        return true
    end

    local function findCashPiles()
        local cashPiles = {}
        for _, obj in pairs(Shared.Workspace:GetDescendants()) do
            if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("Model") then
                local name = obj.Name:lower()
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
        local closestDistance = Shared.MooSettings.FarmRange
        
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

    local function farmCashPile(cashPile)
        local character = Shared.localPlayer.Character
        if not character then return false end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return false end
        
        local targetPos
        if cashPile:IsA("Model") then
            local primaryPart = cashPile.PrimaryPart or cashPile:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                targetPos = primaryPart.Position
            else
                return false
            end
        else
            targetPos = cashPile.Position
        end
        
        rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        
        wait(0.5)
        
        if cashPile:IsA("Model") then
            for _, part in pairs(cashPile:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function() 
                        firetouchinterest(rootPart, part, 0) 
                        wait()
                        firetouchinterest(rootPart, part, 1) 
                    end)
                end
            end
        else
            pcall(function() 
                firetouchinterest(rootPart, cashPile, 0) 
                wait()
                firetouchinterest(rootPart, cashPile, 1) 
            end)
        end
        
        wait(0.5)
        
        safeTeleportToPlatform(character)
        
        Shared.createNotification("Collected cash", Color3.new(0,1,0))
        return true
    end

    local function startAutoFarm()
        if Shared.farmingConnection then
            Shared.farmingConnection:Disconnect()
            Shared.farmingConnection = nil
        end
        
        local character = Shared.localPlayer.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            originalPosition = character.HumanoidRootPart.Position
            makePlayerInvisible(character)
        end
        
        createAirPlatform()
        
        Shared.farmingConnection = Shared.RunService.Heartbeat:Connect(function()
            if not Shared.MooSettings.AutoFarmEnabled then return end
            
            Shared.farmingConnection:Disconnect()
            
            spawn(function()
                local character = Shared.localPlayer.Character
                if not character or not character:FindFirstChild("HumanoidRootPart") then 
                    if Shared.MooSettings.AutoFarmEnabled then
                        Shared.farmingConnection = Shared.RunService.Heartbeat:Connect(function() end)
                    end
                    return 
                end
                
                safeTeleportToPlatform(character)
                wait(5)
                
                if not Shared.MooSettings.AutoFarmEnabled then 
                    if Shared.MooSettings.AutoFarmEnabled then
                        Shared.farmingConnection = Shared.RunService.Heartbeat:Connect(function() end)
                    end
                    return 
                end
                
                local closestPile = getClosestCashPile()
                if closestPile then
                    local targetPos
                    if closestPile:IsA("Model") then
                        local primaryPart = closestPile.PrimaryPart or closestPile:FindFirstChildWhichIsA("BasePart")
                        if primaryPart then
                            targetPos = primaryPart.Position
                        else
                            if Shared.MooSettings.AutoFarmEnabled then
                                Shared.farmingConnection = Shared.RunService.Heartbeat:Connect(function() end)
                            end
                            return
                        end
                    else
                        targetPos = closestPile.Position
                    end
                    
                    character.HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
                    
                    wait(0.5)
                    
                    if closestPile:IsA("Model") then
                        for _, part in pairs(closestPile:GetDescendants()) do
                            if part:IsA("BasePart") then
                                pcall(function() 
                                    firetouchinterest(character.HumanoidRootPart, part, 0) 
                                    wait()
                                    firetouchinterest(character.HumanoidRootPart, part, 1) 
                                end)
                            end
                        end
                    else
                        pcall(function() 
                            firetouchinterest(character.HumanoidRootPart, closestPile, 0) 
                            wait()
                            firetouchinterest(character.HumanoidRootPart, closestPile, 1) 
                        end)
                    end
                    
                    wait(0.5)
                    
                    safeTeleportToPlatform(character)
                    
                    Shared.createNotification("AutoFarm: Collected cash", Color3.new(0,1,0))
                else
                    Shared.createNotification("No cash piles found in range", Color3.new(1,1,0))
                end
                
                wait(5)
                
                if Shared.MooSettings.AutoFarmEnabled then
                    Shared.farmingConnection = Shared.RunService.Heartbeat:Connect(function() end)
                end
            end)
        end)
        
        Shared.createNotification("AutoFarm started", Color3.new(0,1,0))
    end

    local function stopAutoFarm()
        if Shared.farmingConnection then
            Shared.farmingConnection:Disconnect()
            Shared.farmingConnection = nil
        end
        
        if Shared.airPlatform then
            Shared.airPlatform:Destroy()
            Shared.airPlatform = nil
        end
        
        local character = Shared.localPlayer.Character
        if character then
            restorePlayerVisibility(character)
        end
        
        if originalPosition then
            local character = Shared.localPlayer.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                character.HumanoidRootPart.CFrame = CFrame.new(originalPosition)
                Shared.createNotification("Returned to original position", Color3.new(0,1,1))
            end
            originalPosition = nil
        end
        
        Shared.createNotification("AutoFarm stopped", Color3.new(1,0,0))
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
                farmCashPile(pile)
            else
                Shared.createNotification("No cash pile nearby", Color3.new(1,1,0))
            end
        end
    })

    return tab
end
