local KeySystem = {}
KeySystem.__index = KeySystem
KeySystem.WebsiteURL = "https://mooverify.vercel.app/generate?token="
KeySystem.APIBaseURL = "https://mooverify.vercel.app"
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
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 350, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(56, 189, 248)
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "MOOVERIFY VERIFICATION"
    title.TextColor3 = Color3.fromRGB(56, 189, 248)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = header
    local tokenSection = Instance.new("Frame")
    tokenSection.Size = UDim2.new(1, -30, 0, 70)
    tokenSection.Position = UDim2.new(0, 15, 0, 60)
    tokenSection.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    tokenSection.BorderSizePixel = 0
    tokenSection.Parent = mainFrame
    local tokenCorner = Instance.new("UICorner")
    tokenCorner.CornerRadius = UDim.new(0, 8)
    tokenCorner.Parent = tokenSection
    local tokenLabel = Instance.new("TextLabel")
    tokenLabel.Size = UDim2.new(1, 0, 0, 25)
    tokenLabel.Position = UDim2.new(0, 0, 0, 5)
    tokenLabel.BackgroundTransparency = 1
    tokenLabel.Text = "YOUR VERIFICATION TOKEN:"
    tokenLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    tokenLabel.TextSize = 14
    tokenLabel.Font = Enum.Font.Gotham
    tokenLabel.Parent = tokenSection
    local tokenValue = Instance.new("TextLabel")
    tokenValue.Size = UDim2.new(1, 0, 0, 35)
    tokenValue.Position = UDim2.new(0, 0, 0, 25)
    tokenValue.BackgroundTransparency = 1
    tokenValue.Text = self:GetUserToken()
    tokenValue.TextColor3 = Color3.fromRGB(56, 189, 248)
    tokenValue.TextSize = 16
    tokenValue.Font = Enum.Font.GothamBold
    tokenValue.Parent = tokenSection
    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, -30, 0, 40)
    keyInput.Position = UDim2.new(0, 15, 0, 140)
    keyInput.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
    keyInput.BorderSizePixel = 0
    keyInput.PlaceholderText = "Enter MOO Key Here (MOO-XXX-XXX-XXX-XXX)"
    keyInput.Text = ""
    keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInput.TextSize = 14
    keyInput.Font = Enum.Font.Gotham
    keyInput.Parent = mainFrame
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = keyInput
    local copyButton = Instance.new("TextButton")
    copyButton.Size = UDim2.new(1, -30, 0, 35)
    copyButton.Position = UDim2.new(0, 15, 0, 190)
    copyButton.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
    copyButton.BorderSizePixel = 0
    copyButton.Text = "COPY VERIFICATION LINK"
    copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyButton.TextSize = 14
    copyButton.Font = Enum.Font.GothamBold
    copyButton.Parent = mainFrame
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 6)
    copyCorner.Parent = copyButton
    local verifyButton = Instance.new("TextButton")
    verifyButton.Size = UDim2.new(1, -30, 0, 40)
    verifyButton.Position = UDim2.new(0, 15, 0, 235)
    verifyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
    verifyButton.BorderSizePixel = 0
    verifyButton.Text = "VERIFY & EXECUTE"
    verifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    verifyButton.TextSize = 16
    verifyButton.Font = Enum.Font.GothamBold
    verifyButton.Parent = mainFrame
    local verifyCorner = Instance.new("UICorner")
    verifyCorner.CornerRadius = UDim.new(0, 6)
    verifyCorner.Parent = verifyButton
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -30, 0, 50)
    statusLabel.Position = UDim2.new(0, 15, 0, 285)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Ready for verification"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextSize = 13
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextWrapped = true
    statusLabel.Parent = mainFrame
    local instructions = Instance.new("TextLabel")
    instructions.Size = UDim2.new(1, -30, 0, 50)
    instructions.Position = UDim2.new(0, 15, 0, 340)
    instructions.BackgroundTransparency = 1
    instructions.Text = "1. Copy link 2. Visit website 3. Generate key 4. Paste key here"
    instructions.TextColor3 = Color3.fromRGB(150, 150, 200)
    instructions.TextSize = 11
    instructions.Font = Enum.Font.Gotham
    instructions.TextWrapped = true
    instructions.Parent = mainFrame
    local storedKey = self:LoadVerifiedKey()
    if storedKey then
        keyInput.Text = storedKey
        statusLabel.Text = "Found stored key! Click verify to use it."
        statusLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    end
    copyButton.MouseButton1Click:Connect(function()
        local fullURL = self.WebsiteURL .. self:GetUserToken()
        if self.Shared and self.Shared.setclipboard then
            self.Shared.setclipboard(fullURL)
        else
            print("Verification Link: " .. fullURL)
        end
        statusLabel.Text = "Link copied to clipboard! Visit the website to generate your key."
        statusLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    end)
    verifyButton.MouseButton1Click:Connect(function()
        local key = keyInput.Text:upper():gsub("%s+", "")
        if not self:ValidateMOOKeyFormat(key) then
            statusLabel.Text = "Invalid MOO key format. Use: MOO-XXX-XXX-XXX-XXX"
            statusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
            return
        end
        if self:IsKeyVerified(key) then
            statusLabel.Text = "Key already verified! Loading script..."
            statusLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
            self:LoadMainScript()
            return
        end
        statusLabel.Text = "Verifying key with MooVerify server..."
        statusLabel.TextColor3 = Color3.fromRGB(245, 158, 11)
        verifyButton.Text = "VERIFYING..."
        verifyButton.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
        verifyButton.Active = false
        local success, message = self:ValidateKeyWithFlask(key)
        verifyButton.Text = "VERIFY & EXECUTE"
        verifyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
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
    keyInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = keyInput.Text:upper():gsub("[^A-Z0-9%-]", "")
        if #text > 19 then
            text = text:sub(1, 19)
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
        self.Shared.createNotification("Key verified! Loading MooVerify...", Color3.fromRGB(34, 197, 94))
    end
    local success, err = pcall(function()
        local mainScript = game:HttpGet("https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua", true)
        local fn, loadErr = loadstring(mainScript)
        if not fn then error("Loadstring error: " .. tostring(loadErr)) end
        fn()
    end)
    if not success then
        if self.Shared and self.Shared.createNotification then
            self.Shared.createNotification("Failed to load main script: " .. err, Color3.fromRGB(239, 68, 68))
        end
        warn("MooVerify Key System: Failed to load main script - " .. err)
        local errorGui = Instance.new("ScreenGui")
        errorGui.Name = "MooVerifyError"
        errorGui.Parent = self.LocalPlayer.PlayerGui
        local errorFrame = Instance.new("Frame")
        errorFrame.Size = UDim2.new(0, 400, 0, 200)
        errorFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
        errorFrame.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
        errorFrame.BorderSizePixel = 0
        errorFrame.Parent = errorGui
        local errorCorner = Instance.new("UICorner")
        errorCorner.CornerRadius = UDim.new(0, 12)
        errorCorner.Parent = errorFrame
        local errorStroke = Instance.new("UIStroke")
        errorStroke.Color = Color3.fromRGB(239, 68, 68)
        errorStroke.Thickness = 2
        errorStroke.Parent = errorFrame
        local errorTitle = Instance.new("TextLabel")
        errorTitle.Size = UDim2.new(1, 0, 0, 40)
        errorTitle.BackgroundTransparency = 1
        errorTitle.Text = "LOADING ERROR"
        errorTitle.TextColor3 = Color3.fromRGB(239, 68, 68)
        errorTitle.TextSize = 18
        errorTitle.Font = Enum.Font.GothamBold
        errorTitle.Parent = errorFrame
        local errorMessage = Instance.new("TextLabel")
        errorMessage.Size = UDim2.new(1, -20, 0, 120)
        errorMessage.Position = UDim2.new(0, 10, 0, 50)
        errorMessage.BackgroundTransparency = 1
        errorMessage.Text = "Failed to load main script:\n" .. tostring(err)
        errorMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
        errorMessage.TextSize = 14
        errorMessage.Font = Enum.Font.Gotham
        errorMessage.TextWrapped = true
        errorMessage.TextXAlignment = Enum.TextXAlignment.Left
        errorMessage.TextYAlignment = Enum.TextYAlignment.Top
        errorMessage.Parent = errorFrame
        local closeButton = Instance.new("TextButton")
        closeButton.Size = UDim2.new(0, 100, 0, 30)
        closeButton.Position = UDim2.new(0.5, -50, 1, -40)
        closeButton.BackgroundColor3 = Color3.fromRGB(239, 68, 68)
        closeButton.BorderSizePixel = 0
        closeButton.Text = "CLOSE"
        closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeButton.TextSize = 14
        closeButton.Font = Enum.Font.GothamBold
        closeButton.Parent = errorFrame
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 6)
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
