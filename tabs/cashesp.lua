return function(Window, Shared)
    local tab = Window:CreateTab("Cash ESP", "dollar-sign")
    
    local function getCashColor(cashPile)
        local name = cashPile.Name:lower()
        if string.find(name, "huge") then
            return Color3.fromRGB(255, 215, 0)
        elseif string.find(name, "medium") then
            return Color3.fromRGB(192, 192, 192)
        elseif string.find(name, "small") then
            return Color3.fromRGB(205, 127, 50)
        end
        return Color3.fromRGB(0, 255, 0)
    end

    local function createCashESP()
        if Shared.cashEspConnection then
            Shared.cashEspConnection:Disconnect()
            Shared.cashEspConnection = nil
        end
        
        for cashPile, highlight in pairs(Shared.cashEspFolders) do
            if highlight then
                pcall(function() highlight:Destroy() end)
            end
        end
        Shared.cashEspFolders = {}
        
        local function addCashESP(cashPile)
            if not cashPile:IsA("BasePart") and not cashPile:IsA("Model") then return end
            if Shared.cashEspFolders[cashPile] then return end
            
            local highlight = Instance.new("Highlight")
            highlight.Name = "CashESP"
            highlight.FillColor = getCashColor(cashPile)
            highlight.OutlineColor = Color3.new(1, 1, 1)
            highlight.FillTransparency = 0.3
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = cashPile
            highlight.Parent = Shared.Workspace
            Shared.cashEspFolders[cashPile] = highlight
        end
        
        local function scanForCashPiles()
            for _, obj in pairs(Shared.Workspace:GetDescendants()) do
                if obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("Model") then
                    local name = obj.Name:lower()
                    if string.find(name, "cash") then
                        addCashESP(obj)
                    end
                end
            end
        end
        
        Shared.cashEspConnection = Shared.RunService.Heartbeat:Connect(function()
            if not Shared.MooSettings.CashESPEnabled then return end
            
            scanForCashPiles()
            
            for cashPile, highlight in pairs(Shared.cashEspFolders) do
                if not cashPile or not cashPile.Parent or cashPile.Parent == nil then
                    pcall(function() highlight:Destroy() end)
                    Shared.cashEspFolders[cashPile] = nil
                end
            end
        end)
        
        scanForCashPiles()
        Shared.createNotification("Cash ESP activated", Color3.new(0,1,0))
    end

    local function disableCashESP()
        if Shared.cashEspConnection then
            Shared.cashEspConnection:Disconnect()
            Shared.cashEspConnection = nil
        end
        
        for cashPile, highlight in pairs(Shared.cashEspFolders) do
            if highlight then
                pcall(function() highlight:Destroy() end)
            end
        end
        Shared.cashEspFolders = {}
        Shared.createNotification("Cash ESP disabled", Color3.new(1,0,0))
    end

    tab:CreateSection("Cash ESP")
    tab:CreateToggle({
        Name = "Enable Cash ESP",
        CurrentValue = Shared.MooSettings.CashESPEnabled,
        Flag = "CashESPEnabled",
        Callback = function(val)
            Shared.MooSettings.CashESPEnabled = val
            if val then
                createCashESP()
            else
                disableCashESP()
            end
        end
    })

    tab:CreateParagraph({
        Title = "Cash ESP Info",
        Content = "Highlights any object with 'Cash' in its name"
    })

    return tab
end
