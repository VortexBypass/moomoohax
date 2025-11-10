local KeySystem = {}
KeySystem.__index = KeySystem
KeySystem.WebsiteURL = "https://carminestoat.onpella.app/?token="
KeySystem.APIBaseURL = "https://carminestoat.onpella.app"
KeySystem.RequiredKeyLength = 19
function KeySystem.new(shared)
    local self = setmetatable({}, KeySystem)
    self.Shared = shared
    self.LocalPlayer = shared.localPlayer
    self.UserTokens = {}
    self.VerifiedKeys = {}
    self.APIEnabled = true
    return self
end
function KeySystem:GenerateToken()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local token = ""
    for i = 1, 9 do
        if i == 4 or i == 7 then
            token = token .. "-"
        else
            local rand = math.random(1, #charset)
            token = token .. string.sub(charset, rand, rand)
        end
    end
    local userId = self.LocalPlayer.UserId
    self.UserTokens[userId] = token
    return token
end
function KeySystem:GetUserToken()
    local userId = self.LocalPlayer.UserId
    return self.UserTokens[userId] or self:GenerateToken()
end
function KeySystem:ValidateMOOKeyFormat(key)
    if type(key) ~= "string" then return false end
    if #key ~= self.RequiredKeyLength then return false end
    if not string.match(key:upper(), "^MOO%-") then
        return false
    end
    local pattern = "^MOO%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$"
    return string.match(key:upper(), pattern) ~= nil
end
function KeySystem:IsKeyVerified(key)
    local userId = self.LocalPlayer.UserId
    return self.VerifiedKeys[userId] == key
end
function KeySystem:ValidateKeyWithFlask(key)
    if not self.APIEnabled then
        return false, "API disabled"
    end
    local success, result = pcall(function()
        local url = self.APIBaseURL .. "/validate_key"
        local payload = {
            key = key,
            user_id = tostring(self.LocalPlayer.UserId)
        }
        local response = game:GetService("HttpService"):PostAsync(
            url,
            game:GetService("HttpService"):JSONEncode(payload),
            Enum.HttpContentType.ApplicationJson
        )
        return game:GetService("HttpService"):JSONDecode(response)
    end)
    if success and result.valid then
        local userId = self.LocalPlayer.UserId
        self.VerifiedKeys[userId] = key
        return true, result.message
    else
        local errorMsg = result and result.message or "Connection failed"
        return false, "API Error: " .. errorMsg
    end
end
function KeySystem:CreateVerificationGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "MooHaxKeySystem"
    gui.Parent = self.LocalPlayer.PlayerGui
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 350, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 136)
    stroke.Thickness = 1
    stroke.Parent = mainFrame
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 50)
    header.BackgroundColor3 = Color3.fromRGB(22, 33, 62)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 8)
    headerCorner.Parent = header
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 1, 0)
    title.BackgroundTransparency = 1
    title.Text = "MOOHAX VERIFICATION"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = header
    local tokenSection = Instance.new("Frame")
    tokenSection.Size = UDim2.new(1, -20, 0, 60)
    tokenSection.Position = UDim2.new(0, 10, 0, 60)
    tokenSection.BackgroundColor3 = Color3.fromRGB(0, 255, 136, 0.1)
    tokenSection.BorderSizePixel = 0
    tokenSection.Parent = mainFrame
    local tokenCorner = Instance.new("UICorner")
    tokenCorner.CornerRadius = UDim.new(0, 6)
    tokenCorner.Parent = tokenSection
    local tokenStroke = Instance.new("UIStroke")
    tokenStroke.Color = Color3.fromRGB(0, 255, 136)
    tokenStroke.Thickness = 1
    tokenStroke.Parent = tokenSection
    local tokenLabel = Instance.new("TextLabel")
    tokenLabel.Size = UDim2.new(1, 0, 0, 20)
    tokenLabel.Position = UDim2.new(0, 0, 0, 5)
    tokenLabel.BackgroundTransparency = 1
    tokenLabel.Text = "YOUR VERIFICATION TOKEN:"
    tokenLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    tokenLabel.TextScaled = false
    tokenLabel.TextSize = 14
    tokenLabel.Font = Enum.Font.Gotham
    tokenLabel.Parent = tokenSection
    local tokenValue = Instance.new("TextLabel")
    tokenValue.Size = UDim2.new(1, 0, 0, 30)
    tokenValue.Position = UDim2.new(0, 0, 0, 25)
    tokenValue.BackgroundTransparency = 1
    tokenValue.Text = self:GetUserToken()
    tokenValue.TextColor3 = Color3.fromRGB(0, 255, 136)
    tokenValue.TextScaled = false
    tokenValue.TextSize = 18
    tokenValue.Font = Enum.Font.GothamBold
    tokenValue.Parent = tokenSection
    local keyInput = Instance.new("TextBox")
    keyInput.Size = UDim2.new(1, -20, 0, 35)
    keyInput.Position = UDim2.new(0, 10, 0, 130)
    keyInput.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    keyInput.BorderSizePixel = 0
    keyInput.PlaceholderText = "MOO-XXXX-XXXX-XXXX"
    keyInput.Text = ""
    keyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyInput.TextScaled = false
    keyInput.TextSize = 16
    keyInput.Font = Enum.Font.Gotham
    keyInput.Parent = mainFrame
    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = keyInput
    local copyButton = Instance.new("TextButton")
    copyButton.Size = UDim2.new(1, -20, 0, 35)
    copyButton.Position = UDim2.new(0, 10, 0, 175)
    copyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    copyButton.BorderSizePixel = 0
    copyButton.Text = "COPY VERIFICATION LINK"
    copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    copyButton.TextScaled = false
    copyButton.TextSize = 14
    copyButton.Font = Enum.Font.GothamBold
    copyButton.Parent = mainFrame
    local copyCorner = Instance.new("UICorner")
    copyCorner.CornerRadius = UDim.new(0, 6)
    copyCorner.Parent = copyButton
    local verifyButton = Instance.new("TextButton")
    verifyButton.Size = UDim2.new(1, -20, 0, 35)
    verifyButton.Position = UDim2.new(0, 10, 0, 220)
    verifyButton.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
    verifyButton.BorderSizePixel = 0
    verifyButton.Text = "VERIFY & EXECUTE"
    verifyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    verifyButton.TextScaled = false
    verifyButton.TextSize = 14
    verifyButton.Font = Enum.Font.GothamBold
    verifyButton.Parent = mainFrame
    local verifyCorner = Instance.new("UICorner")
    verifyCorner.CornerRadius = UDim.new(0, 6)
    verifyCorner.Parent = verifyButton
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 30)
    statusLabel.Position = UDim2.new(0, 10, 0, 265)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Ready for verification"
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.TextScaled = false
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Parent = mainFrame
    local instructions = Instance.new("TextLabel")
    instructions.Size = UDim2.new(1, -20, 0, 50)
    instructions.Position = UDim2.new(0, 10, 0, 300)
    instructions.BackgroundTransparency = 1
    instructions.Text = "Visit website with token, wait 30s, get MOO key"
    instructions.TextColor3 = Color3.fromRGB(150, 150, 200)
    instructions.TextScaled = false
    instructions.TextSize = 12
    instructions.Font = Enum.Font.Gotham
    instructions.TextWrapped = true
    instructions.Parent = mainFrame
    copyButton.MouseButton1Click:Connect(function()
        local fullURL = self.WebsiteURL .. self:GetUserToken()
        self.Shared.setclipboard(fullURL)
        statusLabel.Text = "Link copied! Visit website"
        statusLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
    end)
    verifyButton.MouseButton1Click:Connect(function()
        local key = keyInput.Text:upper():gsub("%s+", "")
        if not self:ValidateMOOKeyFormat(key) then
            statusLabel.Text = "Invalid MOO key format"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        if self:IsKeyVerified(key) then
            statusLabel.Text = "Key verified! Loading..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
            self:LoadMainScript()
            return
        end
        statusLabel.Text = "Verifying key..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
        local success, message = self:ValidateKeyWithFlask(key)
        if success then
            statusLabel.Text = message
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
            wait(1)
            self:LoadMainScript()
        else
            statusLabel.Text = message
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
    end)
    keyInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = keyInput.Text:upper():gsub("[^A-Z0-9]", "")
        if string.sub(text, 1, 3) ~= "MOO" then
            text = "MOO" .. text
        end
        if #text > 15 then
            text = text:sub(1, 15)
        end
        if #text > 3 then
            text = text:sub(1, 3) .. "-" .. text:sub(4)
        end
        if #text > 8 then
            text = text:sub(1, 8) .. "-" .. text:sub(9)
        end
        if #text > 13 then
            text = text:sub(1, 13) .. "-" .. text:sub(14)
        end
        if keyInput.Text ~= text then
            keyInput.Text = text
        end
    end)
    return gui
end
function KeySystem:LoadMainScript()
    local gui = self.LocalPlayer.PlayerGui:FindFirstChild("MooHaxKeySystem")
    if gui then
        gui:Destroy()
    end
    self.Shared.createNotification("Key verified! Loading MooHax...", Color3.new(0, 1, 0))
    local success, err = pcall(function()
        local mainScript = game:HttpGet("https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua")
        loadstring(mainScript)()
    end)
    if not success then
        self.Shared.createNotification("Failed to load main script: " .. err, Color3.new(1, 0, 0))
        warn("Failed to load main script: " .. err)
    end
end
function KeySystem:Initialize()
    local userId = self.LocalPlayer.UserId
    if self.VerifiedKeys[userId] then
        self:LoadMainScript()
        return true
    else
        self:CreateVerificationGUI()
        return false
    end
end
return KeySystem
