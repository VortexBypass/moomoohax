-- MooVerify Key System
-- Complete implementation with proper error handling

local KeySystem = {}
KeySystem.__index = KeySystem
KeySystem.WebsiteURL = "https://carminestoat.onpella.app/generate?token="
KeySystem.APIBaseURL = "https://carminestoat.onpella.app"
KeySystem.RequiredKeyLength = 19

function KeySystem.new(shared)
    local self = setmetatable({}, KeySystem)
    self.Shared = shared or {}
    self.LocalPlayer = shared and shared.localPlayer or game:GetService("Players").LocalPlayer
    self.APIEnabled = true
    self.DataStoreService = game:GetService("DataStoreService")
    self.VerifiedKeysStore = self.DataStoreService:GetDataStore("MooVerifyKeys")
    
    print("🔧 MooVerify KeySystem initialized for player:", self.LocalPlayer.Name)
    return self
end

function KeySystem:GetUserToken()
    return (self.LocalPlayer and self.LocalPlayer.Name) or "unknown"
end

function KeySystem:ValidateMOOKeyFormat(key)
    if type(key) ~= "string" then 
        print("❌ Key is not a string")
        return false 
    end
    if #key ~= self.RequiredKeyLength then 
        print("❌ Key length incorrect:", #key, "expected:", self.RequiredKeyLength)
        return false 
    end
    if not string.match(key:upper(), "^MOO%-") then 
        print("❌ Key doesn't start with MOO-")
        return false 
    end
    
    local pattern = "^MOO%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]$"
    local isValid = string.match(key:upper(), pattern) ~= nil
    print("🔍 Key format validation:", isValid)
    return isValid
end

function KeySystem:LoadVerifiedKey()
    local success, result = pcall(function()
        return self.VerifiedKeysStore:GetAsync(self.LocalPlayer.UserId)
    end)
    
    if success and result then
        local keyAge = tick() - result.verifiedAt
        print("📦 Found stored key, age:", math.floor(keyAge), "seconds")
        
        if keyAge < 21600 then -- 6 hours
            print("✅ Stored key is valid")
            return result.key, result.verifiedAt
        else
            print("❌ Stored key expired")
            self:RemoveVerifiedKey()
            return nil
        end
    elseif not success then
        print("⚠️ Could not load verified key:", result)
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
    
    print("💾 Save verified key result:", success)
    return success
end

function KeySystem:RemoveVerifiedKey()
    local success, result = pcall(function()
        self.VerifiedKeysStore:RemoveAsync(self.LocalPlayer.UserId)
        return true
    end)
    
    print("🗑️ Remove verified key result:", success)
    return success
end

function KeySystem:IsKeyVerified(key)
    local storedKey, verifiedAt = self:LoadVerifiedKey()
    if storedKey and storedKey == key then
        print("🔑 Key is already verified")
        return true
    end
    return false
end

function KeySystem:ValidateKeyWithFlask(key)
    if not self.APIEnabled then
        print("❌ API disabled")
        return false, "API disabled"
    end
    
    print("🌐 Validating key with server...")
    local HttpService = game:GetService("HttpService")
    
    local success, result = pcall(function()
        local url = self.APIBaseURL .. "/validate_key"
        local payload = {
            key = key,
            username = self.LocalPlayer and self.LocalPlayer.Name or "unknown"
        }
        
        print("📤 Sending request to:", url)
        print("📦 Payload:", HttpService:JSONEncode(payload))
        
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
        
        print("📥 Response status:", response.StatusCode)
        print("📥 Response body:", response.Body)
        
        if response.Success then
            local decoded = HttpService:JSONDecode(response.Body)
            print("✅ Server response decoded successfully")
            return decoded
        else
            error("HTTP " .. tostring(response.StatusCode) .. ": " .. tostring(response.StatusMessage or "Unknown error"))
        end
    end)
    
    if not success then
        local errorMsg = tostring(result)
        print("❌ Validation error:", errorMsg)
        
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
        print("🎉 Key validation successful!")
        local saved = pcall(function() return self:SaveVerifiedKey(key) end)
        if not saved then
            warn("⚠️ Could not save verified key locally.")
        end
        
        return true, result.message or "Key validated"
    else
        local message = tostring((result and result.message) or "Unknown reason")
        print("❌ Key validation failed:", message)
        return false, message
    end
end

function KeySystem:CreateVerificationGUI()
    print("🎨 Creating verification GUI...")
    
    -- Clear any existing GUI first
    local existingGui = self.LocalPlayer.PlayerGui:FindFirstChild("MooVerifyKeySystem")
    if existingGui then
        existingGui:Destroy()
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "MooVerifyKeySystem"
    gui.ResetOnSpawn = false
    gui.Parent = self.LocalPlayer.PlayerGui
    
    -- Main Container
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 500)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(56, 189, 248)
    stroke.Thickness = 2
    stroke.Parent = mainFrame
    
    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 80)
    header.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
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
    subtitle.TextColor3 = Color3.fromRGB(148, 163, 184)
    subtitle.TextSize = 14
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = mainFrame
    
    -- User Token Section
    local tokenSection = Instance.new("Frame")
    tokenSection.Size = UDim2.new(1, -40, 0, 80)
    tokenSection.Position = UDim2.new(0, 20, 0, 130)
    tokenSection.BackgroundColor3 = Color3.fromRGB(51, 65, 85)
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
    tokenLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
    tokenLabel.TextSize = 12
    tokenLabel.Font = Enum.Font.GothamMedium
    tokenLabel.Parent = tokenSection
    
    local tokenValue = Instance.new("TextLabel")
    tokenValue.Size = UDim2.new(1, 0, 0, 40)
    tokenValue.Position = UDim2.new(0, 0, 0, 35)
    tokenValue.BackgroundTransparency = 1
    tokenValue.Text = self:GetUserToken()
    tokenValue.TextColor3 = Color3.fromRGB(56, 189, 248)
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
    keyInput.TextColor3 = Color3.fromRGB(226, 232, 240)
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
    copyButton.BackgroundColor3 = Color3.fromRGB(56, 189, 248)
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
    verifyButton.BackgroundColor3 = Color3.fromRGB(34, 197, 94)
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
    statusLabel.TextColor3 = Color3.fromRGB(203, 213, 225)
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
    instructions.TextColor3 = Color3.fromRGB(148, 163, 184)
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
        print("📋 Copying URL:", fullURL)
        
        if self.Shared and self.Shared.setclipboard then
            self.Shared.setclipboard(fullURL)
        else
            print("📋 Verification Link: " .. fullURL)
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
        print("🔑 Verifying key:", key)
        
        if not self:ValidateMOOKeyFormat(key) then
            statusLabel.Text = "❌ Invalid MOO key format. Use: MOO-XXX-XXX-XXX-XXX"
            statusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
            return
        end
        
        if self:IsKeyVerified(key) then
            statusLabel.Text = "✅ Key already verified! Loading script..."
            statusLabel.TextColor3 = Color3.fromRGB(34, 197, 94)
            self:LoadMainScript()
            return
        end
        
        statusLabel.Text = "⏳ Verifying key with MooVerify server..."
        statusLabel.TextColor3 = Color3.fromRGB(245, 158, 11)
        verifyButton.Text = "🔄 VERIFYING..."
        verifyButton.BackgroundColor3 = Color3.fromRGB(100, 116, 139)
        verifyButton.Active = false
        
        local success, message = self:ValidateKeyWithFlask(key)
        
        verifyButton.Text = "✅ VERIFY & EXECUTE"
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
    
    print("✅ Verification GUI created successfully")
    return gui
end

function KeySystem:LoadMainScript()
    print("🚀 Loading main script...")
    
    -- Clear GUI
    local gui = self.LocalPlayer.PlayerGui:FindFirstChild("MooVerifyKeySystem")
    if gui then
        gui:Destroy()
        print("🗑️ GUI destroyed")
    end
    
    if self.Shared and self.Shared.createNotification then
        self.Shared.createNotification("✅ Key verified! Loading MooVerify...", Color3.fromRGB(34, 197, 94))
    end
    
    local success, err = pcall(function()
        print("🌐 Fetching main script from GitHub...")
        local mainScript = game:HttpGet("https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua", true)
        
        if not mainScript or #mainScript < 10 then
            error("Fetched main script is empty or too short.")
        end
        
        print("📝 Loadstring main script...")
        local fn, loadErr = loadstring(mainScript)
        if not fn then 
            error("Loadstring error: " .. tostring(loadErr)) 
        end
        
        print("▶️ Executing main script...")
        fn()
        print("✅ Main script executed successfully")
    end)
    
    if not success then
        print("❌ Failed to load main script:", err)
        
        if self.Shared and self.Shared.createNotification then
            self.Shared.createNotification("❌ Failed to load main script: " .. err, Color3.fromRGB(239, 68, 68))
        end
        
        -- Recreate GUI with error message
        self:CreateVerificationGUI()
        local newGui = self.LocalPlayer.PlayerGui:FindFirstChild("MooVerifyKeySystem")
        if newGui then
            local statusLabel = newGui:FindFirstChild("StatusLabel") or newGui:WaitForChild("MainFrame"):WaitForChild("StatusLabel")
            if statusLabel then
                statusLabel.Text = "❌ Failed to load script: " .. tostring(err)
                statusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
            end
        end
    end
end

function KeySystem:Initialize()
    print("🎯 Initializing MooVerify KeySystem...")
    
    -- Wait for player to be fully loaded
    if not self.LocalPlayer then
        warn("❌ LocalPlayer not found")
        return false
    end
    
    print("👤 Player:", self.LocalPlayer.Name)
    print("🆔 UserId:", self.LocalPlayer.UserId)
    
    local storedKey = self:LoadVerifiedKey()
    if storedKey then
        print("🔑 Using stored key, loading main script...")
        self:LoadMainScript()
        return true
    else
        print("🆕 No stored key found, creating verification GUI...")
        self:CreateVerificationGUI()
        return false
    end
end

-- Main execution
print("🚀 Starting MooVerify KeySystem...")

-- Wait for everything to load
local success, err = pcall(function()
    -- Wait for players service
    local Players = game:GetService("Players")
    
    -- Wait for local player
    local localPlayer = Players.LocalPlayer
    while not localPlayer do
        wait(0.1)
        localPlayer = Players.LocalPlayer
    end
    
    print("✅ LocalPlayer found:", localPlayer.Name)
    
    -- Wait for player GUI
    while not localPlayer:FindFirstChild("PlayerGui") do
        wait(0.1)
    end
    
    print("✅ PlayerGui found")
    
    -- Create and initialize key system
    local keySystem = KeySystem.new({
        localPlayer = localPlayer,
        setclipboard = setclipboard,
        createNotification = function(msg, color)
            -- Simple notification system
            print("📢 " .. msg)
        end
    })
    
    -- Initialize after a short delay to ensure everything is ready
    wait(1)
    keySystem:Initialize()
    
    print("🎉 MooVerify KeySystem started successfully!")
end)

if not success then
    warn("❌ MooVerify KeySystem failed to start: " .. tostring(err))
    
    -- Try to show basic error GUI
    pcall(function()
        local Players = game:GetService("Players")
        local localPlayer = Players.LocalPlayer
        if localPlayer and localPlayer:FindFirstChild("PlayerGui") then
            local errorGui = Instance.new("ScreenGui")
            errorGui.Name = "MooVerifyError"
            errorGui.Parent = localPlayer.PlayerGui
            
            local errorFrame = Instance.new("Frame")
            errorFrame.Size = UDim2.new(0, 400, 0, 200)
            errorFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
            errorFrame.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
            errorFrame.BorderSizePixel = 0
            errorFrame.Parent = errorGui
            
            local errorLabel = Instance.new("TextLabel")
            errorLabel.Size = UDim2.new(1, 0, 1, 0)
            errorLabel.BackgroundTransparency = 1
            errorLabel.Text = "MooVerify Error:\n" .. tostring(err)
            errorLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
            errorLabel.TextSize = 14
            errorLabel.TextWrapped = true
            errorLabel.Parent = errorFrame
        end
    end)
end

return KeySystem
