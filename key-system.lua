local KeySystem = {}
KeySystem.__index = KeySystem
KeySystem.WebsiteURL = "https://carminestoat.onpella.app/generate?token="
KeySystem.APIBaseURL = "https://carminestoat.onpella.app"
KeySystem.RequiredKeyLength = 19

function KeySystem.new(shared)
    local self = setmetatable({}, KeySystem)
    self.Shared = shared
    self.LocalPlayer = shared and shared.localPlayer
    self.APIEnabled = true
    self.DataStoreService = game:GetService("DataStoreService")
    self.VerifiedKeysStore = self.DataStoreService:GetDataStore("MooVerifyKeys")
    return self
end

function KeySystem:GetUserToken()
    return (self.LocalPlayer and self.LocalPlayer.Name) or "unknown"
end

function KeySystem:ValidateMOOKeyFormat(key)
    if type(key) ~= "string" then return false end
    if #key ~= self.RequiredKeyLength then return false end
    if not string.match(key:upper(), "^MOO%-") then return false end
    local pattern = "^MOO%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]$"
    return string.match(key:upper(), pattern) ~= nil
end

function KeySystem:LoadVerifiedKey()
    local success, result = pcall(function()
        return self.VerifiedKeysStore:GetAsync(self.LocalPlayer.UserId)
    end)
    if success and result then
        if tick() - result.verifiedAt < 21600 then
            return result.key, result.verifiedAt
        else
            self:RemoveVerifiedKey()
            return nil
        end
    end
    return nil
end

function KeySystem:SaveVerifiedKey(key)
    local success, result = pcall(function()
        local data = {
            key = key,
            verifiedAt = tick(),
            username = self.LocalPlayer and self.LocalPlayer.Name or "unknown"
        }
        self.VerifiedKeysStore:SetAsync(self.LocalPlayer.UserId, data)
        return true
    end)
    return success
end

function KeySystem:RemoveVerifiedKey()
    local success, result = pcall(function()
        self.VerifiedKeysStore:RemoveAsync(self.LocalPlayer.UserId)
        return true
    end)
    return success
end

function KeySystem:IsKeyVerified(key)
    local storedKey, verifiedAt = self:LoadVerifiedKey()
    if storedKey and storedKey == key then
        return true
    end
    return false
end

function KeySystem:ValidateKeyWithFlask(key)
    if not self.APIEnabled then
        return false, "API disabled"
    end
    local HttpService = game:GetService("HttpService")
    local success, result = pcall(function()
        local url = self.APIBaseURL .. "/validate_key"
        local payload = {
            key = key,
            username = self.LocalPlayer and self.LocalPlayer.Name or "unknown"
        }
        local jsonPayload = HttpService:JSONEncode(payload)
        local response = HttpService:RequestAsync({
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/MooVerify"
            },
            Body = jsonPayload
        })
        if response.Success then
            return HttpService:JSONDecode(response.Body)
        else
            error("HTTP " .. tostring(response.StatusCode) .. ": " .. tostring(response.StatusMessage or response.StatusCode))
        end
    end)
    if not success then
        local errorMsg = tostring(result)
        if string.find(errorMsg, "403", 1, true) then
            return false, "Access denied (403)"
        elseif string.find(errorMsg, "404", 1, true) then
            return false, "Endpoint not found (404)"
        elseif string.find(errorMsg, "500", 1, true) then
            return false, "Server error (500)"
        elseif string.find(errorMsg:lower(), "timeout", 1, true) then
            return false, "Request timeout"
        else
            return false, "Connection failed: " .. errorMsg
        end
    end
    if type(result) == "table" and result.valid then
        print("Key validated successfully!")
        local saved = pcall(function() return self:SaveVerifiedKey(key) end)
        if not saved then
            warn("Warning: could not save verified key locally.")
        end
        local mainUrl = "https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua"
        local ok, loadErr = pcall(function()
            local scriptText = game:HttpGet(mainUrl, true)
            if not scriptText or #scriptText < 10 then
                error("Fetched main script is empty or too short.")
            end
            local fn, compileErr = loadstring(scriptText)
            if not fn then error("Loadstring compile error: " .. tostring(compileErr)) end
            fn()
        end)
        if not ok then
            warn("Failed to load main script after validation: " .. tostring(loadErr))
            return false, "Validated but failed to load main script: " .. tostring(loadErr)
        end
        return true, result.message or "Key validated"
    else
        warn("Key validation failed: " .. tostring((result and result.message) or "Unknown reason"))
        return false, (result and result.message) or "Key validation failed"
    end
end

function KeySystem:CreateVerificationGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MooVerifyKeySystem"
    gui.Parent = self.LocalPlayer.PlayerGui
    
    -- Main Container
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 41, 59)  -- Dark blue from site
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(56, 189, 248)  -- Sky blue accent
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    
    -- Header with logo style
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 80)
    header.BackgroundColor3 = Color3.fromRGB(15, 23, 42)  -- Darker header
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 15)
    headerCorner.Parent = header
    
    local titleContainer = Instance.new("Frame")
    titleContainer.Size = UDim2.new(1, 0, 1, 0)
    titleContainer.BackgroundTransparency = 1
    titleContainer.Parent = header
    
    local logoIcon = Instance.new("TextLabel")
    logoIcon.Size = UDim2.new(0, 40, 0, 40)
    logoIcon.Position = UDim2.new(0.5, -80, 0.5, -20)
    logoIcon.BackgroundTransparency = 1
    logoIcon.Text = "🔒"
    logoIcon.TextColor3 = Color3.fromRGB(56, 189, 248)
    logoIcon.TextSize = 24
    logoIcon.Font = Enum.Font.GothamBold
    logoIcon.Parent = titleContainer
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 0, 40)
    title.Position = UDim2.new(0.5, -40, 0.5, -20)
    title.BackgroundTransparency = 1
    title.Text = "MOOVERIFY"
    title.TextColor3 = Color3.fromRGB(56, 189, 248)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleContainer
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -40, 0, 20)
    subtitle.Position = UDim2.new(0, 20, 0, 100)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Security Verification Required"
    subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)  -- Gray text
    subtitle.TextSize = 14
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = mainFrame
    
    -- User Token Section
    local tokenSection = Instance.new("Frame")
    tokenSection.Size = UDim2.new(1, -40, 0, 80)
    tokenSection.Position = UDim2.new(0, 20, 0, 130)
    tokenSection.BackgroundColor3 = Color3.fromRGB(51, 65, 85)  -- Card background
    tokenSection.BorderSizePixel = 0
    tokenSection.Parent = mainFrame
    
    local tokenCorner = Instance.new("UICorner")
    tokenCorner.CornerRadius = UDim.new(0, 10)
    tokenCorner.Parent = tokenSection
    
    local tokenLabel = Instance.new("TextLabel")
    tokenLabel.Size = UDim2.new(1, 0, 0, 30)
    tokenLabel.Position = UDim2.new(0, 0, 0, 10)
    tokenLabel.BackgroundTransparency = 1
    tokenLabel.Text = "YOUR VERIFICATION TOKEN"
    tokenLabel.TextColor3 = Color3.fromRGB(203, 213, 225)  -- Light gray
    tokenLabel.TextSize = 12
    tokenLabel.Font = Enum.Font.GothamMedium
    tokenLabel.Parent = tokenSection
    
    local tokenValue = Instance.new("TextLabel")
    tokenValue.Size = UDim2.new(1, 0, 0, 40)
    tokenValue.Position = UDim2.new(0, 0, 0, 35)
    tokenValue.BackgroundTransparency = 1
    tokenValue.Text = self:GetUserToken()
    tokenValue.TextColor3 = Color3.fromRGB(56, 189, 248)  -- Sky blue
    tokenValue.TextSize = 18
    tokenValue.Font = Enum.Font.GothamBold
    tokenValue.Parent = tokenSection
    
    -- Key Input
    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, -40, 0, 50)
    keyInput.Position = UDim2.new(0, 20, 0, 230)
    keyInput.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    keyInput.BorderSizePixel = 0
    keyInput.PlaceholderText = "Enter MOO Key (MOO-XXX-XXX-XXX-XXX)"
    keyInput.PlaceholderColor3 = Color3.fromRGB(148, 163, 184)
    keyInput.Text = ""
    keyInput.TextColor3 = Color3.fromRGB(226, 232, 240)  -- Light text
    keyInput.TextSize = 14
    keyInput.Font = Enum.Font.Gotham
    keyInput.Parent = mainFrame
    
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = keyInput
    
    -- Copy Button
    local copyButton = Instance.new("TextButton")
    copyButton.Size = UDim2.new(1, -40, 0, 45)
    copyButton.Position = UDim2.new(0, 20, 0, 295)
    copyButton.BackgroundColor3 = Color3.fromRGB(56, 189, 248)  -- Sky blue
    copyButton.BorderSizePixel = 0
    copyButton.Text = "📋 COPY VERIFICATION LINK"
    copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyButton.TextSize = 14
    copyButton.Font = Enum.Font.GothamBold
    copyButton.Parent = mainFrame
    
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 8)
    copyCorner.Parent = copyButton
    
    -- Verify Button
    local verifyButton = Instance.new("TextButton")
    verifyButton.Size = UDim2.new(1, -40, 0, 50)
    verifyButton.Position = UDim2.new(0, 20, 0, 355)
    verifyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)  -- Green
    verifyButton.BorderSizePixel = 0
    verifyButton.Text = "✅ VERIFY & EXECUTE"
    verifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    verifyButton.TextSize = 16
    verifyButton.Font = Enum.Font.GothamBold
    verifyButton.Parent = mainFrame
    
    local verifyCorner = Instance.new("UICorner")
    verifyCorner.CornerRadius = UDim.new(0, 8)
    verifyCorner.Parent = verifyButton
    
    -- Status Label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -40, 0, 60)
    statusLabel.Position = UDim2.new(0, 20, 0, 420)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Ready for verification. Follow the steps below."
    statusLabel.TextColor3 = Color3.fromRGB(203, 213, 225)  -- Light gray
    statusLabel.TextSize = 13
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextWrapped = true
    statusLabel.Parent = mainFrame
    
    -- Instructions
    local instructions = Instance.new("TextLabel")
    instructions.Size = UDim2.new(1, -40, 0, 40)
    instructions.Position = UDim2.new(0, 20, 1, -50)
    instructions.BackgroundTransparency = 1
    instructions.Text = "1. Copy link • 2. Visit website • 3. Generate key • 4. Paste key here"
    instructions.TextColor3 = Color3.fromRGB(148, 163, 184)  -- Gray
    instructions.TextSize = 11
    instructions.Font = Enum.Font.Gotham
    instructions.TextWrapped = true
    instructions.Parent = mainFrame
    
    -- Check for stored key
    local storedKey = self:LoadVerifiedKey()
    if storedKey then
        keyInput.Text = storedKey
        statusLabel.Text = "🔑 Found stored key! Click verify to use it."
        statusLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    end
    
    -- Copy Button Functionality
    copyButton.MouseButton1Click:Connect(function()
        local fullURL = self.WebsiteURL .. self:GetUserToken()
        if self.Shared and self.Shared.setclipboard then
            self.Shared.setclipboard(fullURL)
        else
            print("Verification Link: " .. fullURL)
        end
        statusLabel.Text = "🔗 Link copied to clipboard! Visit the website to generate your key."
        statusLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
        
        -- Button feedback
        copyButton.Text = "✅ COPIED!"
        copyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
        wait(1.5)
        copyButton.Text = "📋 COPY VERIFICATION LINK"
        copyButton.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
    end)
    
    -- Verify Button Functionality
    verifyButton.MouseButton1Click:Connect(function()
        local key = keyInput.Text:upper():gsub("%s+", "")
        if not self:ValidateMOOKeyFormat(key) then
            statusLabel.Text = "❌ Invalid MOO key format. Use: MOO-XXX-XXX-XXX-XXX"
            statusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)  -- Red
            return
        end
        
        if self:IsKeyVerified(key) then
            statusLabel.Text = "✅ Key already verified! Loading script..."
            statusLabel.TextColor3 = Color3.fromRGB(34, 197, 94)  -- Green
            self:LoadMainScript()
            return
        end
        
        statusLabel.Text = "⏳ Verifying key with MooVerify server..."
        statusLabel.TextColor3 = Color3.fromRGB(245, 158, 11)  -- Orange
        verifyButton.Text = "🔄 VERIFYING..."
        verifyButton.BackgroundColor3 = Color3.fromRGB(100, 116, 139)  -- Gray
        verifyButton.Active = false
        
        local success, message = self:ValidateKeyWithFlask(key)
        
        verifyButton.Text = "✅ VERIFY & EXECUTE"
        verifyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)  -- Green
        verifyButton.Active = true
        
        if success then
            statusLabel.Text = "✅ " .. message .. " Loading script..."
            statusLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
            wait(1)
            self:LoadMainScript()
        else
            statusLabel.Text = "❌ " .. message
            statusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
            self:RemoveVerifiedKey()
        end
    end)
    
    -- Auto-format key input
    keyInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = keyInput.Text:upper():gsub("[^A-Z0-9%-]", "")
        if #text > 19 then
            text = text:sub(1, 19)
        end
        
        -- Auto-insert dashes
        if #text >= 4 and text:sub(4,4) ~= "-" then
            text = text:sub(1,3) .. "-" .. text:sub(4)
        end
        if #text >= 8 and text:sub(8,8) ~= "-" then
            text = text:sub(1,7) .. "-" .. text:sub(8)
        end
        if #text >= 12 and text:sub(12,12) ~= "-" then
            text = text:sub(1,11) .. "-" .. text:sub(12)
        end
        if #text >= 16 and text:sub(16,16) ~= "-" then
            text = text:sub(1,15) .. "-" .. text:sub(16)
        end
        
        if keyInput.Text ~= text then
            keyInput.Text = text
        end
    end)
    
    return gui
end

function KeySystem:LoadMainScript()
    local gui = self.LocalPlayer.PlayerGui:FindFirstChild("MooVerifyKeySystem")
    if gui then
        gui:Destroy()
    end
    
    if self.Shared and self.Shared.createNotification then
        self.Shared.createNotification("✅ Key verified! Loading MooVerify...", Color3.fromRGB(34, 197, 94))
    end
    
    local success, err = pcall(function()
        local mainScript = game:HttpGet("https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua", true)
        local fn, loadErr = loadstring(mainScript)
        if not fn then error("Loadstring error: " .. tostring(loadErr)) end
        fn()
    end)
    
    if not success then
        if self.Shared and self.Shared.createNotification then
            self.Shared.createNotification("❌ Failed to load main script: " .. err, Color3.fromRGB(239, 68, 68))
        end
        warn("MooVerify Key System: Failed to load main script - " .. err)
        
        -- Error GUI with site styling
        local errorGui = Instance.new("ScreenGui")
        errorGui.Name = "MooVerifyError"
        errorGui.Parent = self.LocalPlayer.PlayerGui
        
        local errorFrame = Instance.new("Frame")
        errorFrame.Size = UDim2.new(0, 450, 0, 250)
        errorFrame.Position = UDim2.new(0.5, -225, 0.5, -125)
        errorFrame.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
        errorFrame.BorderSizePixel = 0
        errorFrame.Parent = errorGui
        
        local errorCorner = Instance.new("UICorner")
        errorCorner.CornerRadius = UDim.new(0, 15)
        errorCorner.Parent = errorFrame
        
        local errorStroke = Instance.new("UIStroke")
        errorStroke.Color = Color3.fromRGB(239, 68, 68)
        errorStroke.Thickness = 2
        errorStroke.Parent = errorFrame
        
        local errorHeader = Instance.new("Frame")
        errorHeader.Size = UDim2.new(1, 0, 0, 50)
        errorHeader.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
        errorHeader.BorderSizePixel = 0
        errorHeader.Parent = errorFrame
        
        local errorHeaderCorner = Instance.new("UICorner")
        errorHeaderCorner.CornerRadius = UDim.new(0, 15)
        errorHeaderCorner.Parent = errorHeader
        
        local errorTitle = Instance.new("TextLabel")
        errorTitle.Size = UDim2.new(1, 0, 1, 0)
        errorTitle.BackgroundTransparency = 1
        errorTitle.Text = "❌ LOADING ERROR"
        errorTitle.TextColor3 = Color3.fromRGB(239, 68, 68)
        errorTitle.TextSize = 18
        errorTitle.Font = Enum.Font.GothamBold
        errorTitle.Parent = errorHeader
        
        local errorMessage = Instance.new("TextLabel")
        errorMessage.Size = UDim2.new(1, -20, 0, 150)
        errorMessage.Position = UDim2.new(0, 10, 0, 60)
        errorMessage.BackgroundTransparency = 1
        errorMessage.Text = "Failed to load main script:\n\n" .. tostring(err)
        errorMessage.TextColor3 = Color3.fromRGB(226, 232, 240)
        errorMessage.TextSize = 14
        errorMessage.Font = Enum.Font.Gotham
        errorMessage.TextWrapped = true
        errorMessage.TextXAlignment = Enum.TextXAlignment.Left
        errorMessage.TextYAlignment = Enum.TextYAlignment.Top
        errorMessage.Parent = errorFrame
        
        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(0, 120, 0, 35)
        closeButton.Position = UDim2.new(0.5, -60, 1, -45)
        closeButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        closeButton.BorderSizePixel = 0
        closeButton.Text = "CLOSE"
        closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeButton.TextSize = 14
        closeButton.Font = Enum.Font.GothamBold
        closeButton.Parent = errorFrame
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 8)
        closeCorner.Parent = closeButton
        
        closeButton.MouseButton1Click:Connect(function()
            errorGui:Destroy()
        end)
    end
end

function KeySystem:Initialize()
    local storedKey = self:LoadVerifiedKey()
    if storedKey then
        self:LoadMainScript()
        return true
    else
        self:CreateVerificationGUI()
        return false
    end
end

return KeySystem
