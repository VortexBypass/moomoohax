-- MooVerify KeySystem (robust, server/client friendly)
local KeySystem = {}
KeySystem.__index = KeySystem

KeySystem.WebsiteURL = "https://mooverify.vercel.app/generate?token="
KeySystem.APIBaseURL = "https://mooverify.vercel.app"
KeySystem.RequiredKeyLength = 19

local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

-- Environment detection
local isServer = RunService:IsServer()
local hasWriteFile = type(writefile) == "function" or (type(syn) == "table" and type(syn.write_file) == "function")
local hasReadFile = type(readfile) == "function" or (type(syn) == "table" and type(syn.read_file) == "function")

-- Helper: cross-environment write/read/remove file
local function clientSave(filename, tbl)
    pcall(function()
        local json = HttpService:JSONEncode(tbl)
        if type(writefile) == "function" then
            writefile(filename, json)
        elseif type(syn) == "table" and type(syn.write_file) == "function" then
            syn.write_file(filename, json)
        else
            -- last-resort: warn (can't persist)
            warn("No writefile available to persist key locally.")
        end
    end)
end

local function clientLoad(filename)
    local ok, data = pcall(function()
        local raw
        if type(readfile) == "function" then
            raw = readfile(filename)
        elseif type(syn) == "table" and type(syn.read_file) == "function" then
            raw = syn.read_file(filename)
        else
            return nil
        end
        if raw and #raw > 0 then
            return HttpService:JSONDecode(raw)
        end
        return nil
    end)
    if ok then return data end
    return nil
end

local function clientRemove(filename)
    pcall(function()
        if type(delfile) == "function" then
            delfile(filename)
        elseif type(writefile) == "function" then
            -- overwrite with empty JSON
            writefile(filename, "")
        elseif type(syn) == "table" and type(syn.write_file) == "function" then
            syn.write_file(filename, "")
        end
    end)
end

-- HTTP request wrapper with fallbacks (POST/GET)
local function SendHttpRequest(requestTable)
    -- requestTable: {Url=..., Method="POST", Headers={}, Body="..."}
    local ok, res = pcall(function()
        -- prefer syn.request
        if type(syn) == "table" and type(syn.request) == "function" then
            return syn.request(requestTable)
        end
        if type(http_request) == "function" then
            return http_request(requestTable)
        end
        if type(request) == "function" then
            return request(requestTable)
        end
        -- Server-side HttpService:RequestAsync (works on server)
        if HttpService and type(HttpService.RequestAsync) == "function" then
            return HttpService:RequestAsync(requestTable)
        end
        error("No HTTP request method available in this environment.")
    end)
    if not ok then
        return false, tostring(res)
    end
    return true, res
end

-- Construction
function KeySystem.new(shared)
    local self = setmetatable({}, KeySystem)
    self.Shared = shared or {}
    -- Expect shared.localPlayer for client; for server you'd pass a player object in shared.localPlayer
    self.LocalPlayer = self.Shared.localPlayer
    self.APIEnabled = true

    if isServer then
        self.DataStoreService = game:GetService("DataStoreService")
        self.VerifiedKeysStore = self.DataStoreService:GetDataStore("MooVerifyKeys")
    else
        -- client persistence filename
        local userId = (self.LocalPlayer and self.LocalPlayer.UserId) and tostring(self.LocalPlayer.UserId) or "local"
        self._clientStorageFilename = "MooVerifyKey_" .. userId .. ".json"
    end

    return self
end

function KeySystem:GetUserToken()
    if self.LocalPlayer and self.LocalPlayer.Name then
        return self.LocalPlayer.Name
    end
    return "unknown_user"
end

function KeySystem:ValidateMOOKeyFormat(key)
    if type(key) ~= "string" then return false end
    if #key ~= self.RequiredKeyLength then return false end
    if not string.match(key:upper(), "^MOO%-") then
        return false
    end
    local pattern = "^MOO%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9]$"
    return string.match(key:upper(), pattern) ~= nil
end

-- Storage: Load/Save/Remove: server uses DataStore, client uses file fallback
function KeySystem:LoadVerifiedKey()
    if isServer then
        local success, result = pcall(function()
            local id = tostring(self.LocalPlayer and self.LocalPlayer.UserId or "server")
            return self.VerifiedKeysStore:GetAsync(id)
        end)
        if success and result then
            if type(result) == "table" and result.key and result.verifiedAt then
                if tick() - result.verifiedAt < 21600 then
                    return result.key
                else
                    -- expired; remove
                    pcall(function() self.VerifiedKeysStore:RemoveAsync(tostring(self.LocalPlayer.UserId)) end)
                    return nil
                end
            end
        end
        return nil
    else
        local data = clientLoad(self._clientStorageFilename)
        if data and type(data) == "table" and data.key and data.verifiedAt then
            if tick() - data.verifiedAt < 21600 then
                return data.key
            else
                clientRemove(self._clientStorageFilename)
                return nil
            end
        end
        return nil
    end
end

function KeySystem:SaveVerifiedKey(key)
    if isServer then
        local success, err = pcall(function()
            local id = tostring(self.LocalPlayer and self.LocalPlayer.UserId or "server")
            local data = { key = key, verifiedAt = tick(), username = self.LocalPlayer and self.LocalPlayer.Name or "server" }
            self.VerifiedKeysStore:SetAsync(id, data)
        end)
        return success
    else
        local ok = pcall(function()
            local data = { key = key, verifiedAt = tick(), username = (self.LocalPlayer and self.LocalPlayer.Name) or "local" }
            clientSave(self._clientStorageFilename, data)
        end)
        return ok
    end
end

function KeySystem:RemoveVerifiedKey()
    if isServer then
        local success, err = pcall(function()
            self.VerifiedKeysStore:RemoveAsync(tostring(self.LocalPlayer.UserId))
        end)
        return success
    else
        local ok = pcall(function()
            clientRemove(self._clientStorageFilename)
        end)
        return ok
    end
end

function KeySystem:IsKeyVerified(key)
    local storedKey = self:LoadVerifiedKey()
    if storedKey and storedKey == key then
        return true
    end
    return false
end

-- Validate with Flask (POST) with fallback and clear error messages
function KeySystem:ValidateKeyWithFlask(key)
    if not self.APIEnabled then
        return false, "API disabled"
    end

    local payload = { key = key, username = self:GetUserToken() }
    local jsonPayload = HttpService:JSONEncode(payload)
    local url = self.APIBaseURL .. "/validate_key"

    local requestTable = {
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json",
            ["User-Agent"] = "Roblox/MooVerify"
        },
        Body = jsonPayload
    }

    local ok, res = SendHttpRequest(requestTable)
    if not ok then
        -- res is error message
        local errMsg = tostring(res)
        warn("HTTP request failed: " .. errMsg)
        if string.find(errMsg, "403", 1, true) then
            return false, "Access denied (403)"
        elseif string.find(errMsg, "404", 1, true) then
            return false, "Endpoint not found (404)"
        elseif string.find(errMsg, "500", 1, true) then
            return false, "Server error (500)"
        else
            return false, "Connection failed: " .. errMsg
        end
    end

    -- res handling: different runtimes return different fields
    local body = res.Body or res.body or res.responseBody or nil
    local status = res.StatusCode or res.statusCode or res.status or res.code

    if not body then
        return false, "No response body from validation server."
    end

    local decoded
    local decodeOk, decodeErr = pcall(function() decoded = HttpService:JSONDecode(body) end)
    if not decodeOk then
        warn("Failed to decode JSON: " .. tostring(decodeErr))
        return false, "Invalid response from server."
    end

    if type(decoded) == "table" and decoded.valid then
        -- Save verified key
        if self:SaveVerifiedKey(key) then
            return true, decoded.message or "Key validated"
        else
            return false, "Validated but failed to save key locally"
        end
    else
        return false, decoded.message or "Key validation failed"
    end
end

-- UI creation (same as original, with a small wait for PlayerGui if needed)
function KeySystem:CreateVerificationGUI()
    if not self.LocalPlayer then
        warn("KeySystem:CreateVerificationGUI called without LocalPlayer")
        return nil
    end

    local playerGui = self.LocalPlayer:FindFirstChild("PlayerGui") or self.LocalPlayer:WaitForChild("PlayerGui", 5)
    if not playerGui then
        warn("PlayerGui not found for player")
        return nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MooVerifyKeySystem"
    gui.ResetOnSpawn = false
    gui.Parent = playerGui

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

    -- Load stored key if available
    local storedKey = self:LoadVerifiedKey()
    if storedKey then
        keyInput.Text = storedKey
        statusLabel.Text = "Found stored key! Click verify to use it."
        statusLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    end

    copyButton.MouseButton1Click:Connect(function()
        local fullURL = self.WebsiteURL .. self:GetUserToken()
        if self.Shared and type(self.Shared.setclipboard) == "function" then
            pcall(function() self.Shared.setclipboard(fullURL) end)
        else
            -- common exploit clip functions
            if type(setclipboard) == "function" then
                pcall(function() setclipboard(fullURL) end)
            else
                print("Verification Link: " .. fullURL)
            end
        end
        statusLabel.Text = "Link copied to clipboard! Visit the website to generate your key."
        statusLabel.TextColor3 = Color3.fromRGB(56, 189, 248)
    end)

    verifyButton.MouseButton1Click:Connect(function()
        local key = (keyInput.Text or ""):upper():gsub("%s+", "")
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
            task.wait(1)
            self:LoadMainScript()
        else
            statusLabel.Text = "❌ " .. message
            statusLabel.TextColor3 = Color3.fromRGB(239, 68, 68)
            self:RemoveVerifiedKey()
        end
    end)

    -- sanitize input as user types (avoid infinite property signal recursion)
    local lastText = keyInput.Text
    keyInput:GetPropertyChangedSignal("Text"):Connect(function()
        local text = (keyInput.Text or ""):upper():gsub("[^A-Z0-9%-]", "")
        if #text > KeySystem.RequiredKeyLength then
            text = text:sub(1, KeySystem.RequiredKeyLength)
        end
        if keyInput.Text ~= text then
            lastText = text
            keyInput.Text = text
        end
    end)

    return gui
end

function KeySystem:LoadMainScript()
    if self.LocalPlayer and self.LocalPlayer.PlayerGui then
        local gui = self.LocalPlayer.PlayerGui:FindFirstChild("MooVerifyKeySystem")
        if gui then gui:Destroy() end
    end

    if self.Shared and type(self.Shared.createNotification) == "function" then
        pcall(function() self.Shared.createNotification("Key verified! Loading MooVerify...", Color3.fromRGB(34, 197, 94)) end)
    end

    local ok, err = pcall(function()
        local mainScript
        -- prefer HttpGet via available functions
        if type(syn) == "table" and type(syn.request) == "function" then
            -- syn.request GET
            local r = syn.request({Url = "https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua", Method = "GET"})
            if r and r.Body then mainScript = r.Body end
        elseif type(http_request) == "function" then
            local r = http_request({Url = "https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua", Method = "GET"})
            if r and r.body then mainScript = r.body end
        else
            mainScript = game:HttpGet("https://raw.githubusercontent.com/VortexBypass/moomoohax/refs/heads/main/main.lua")
        end

        if not mainScript or #mainScript < 10 then
            error("Failed to fetch main.lua or returned empty script.")
        end

        local func, loadErr = loadstring(mainScript)
        if not func then error("Loadstring error: " .. tostring(loadErr)) end
        func()
    end)

    if not ok then
        if self.Shared and type(self.Shared.createNotification) == "function" then
            pcall(function() self.Shared.createNotification("Failed to load main script: " .. tostring(err), Color3.fromRGB(239, 68, 68)) end)
        end
        warn("MooVerify Key System: Failed to load main script - " .. tostring(err))
        -- create a small error GUI (keeps behavior)
        if self.LocalPlayer and self.LocalPlayer.PlayerGui then
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
end

function KeySystem:Initialize()
    local storedKey = self:LoadVerifiedKey()
    if storedKey then
        -- call protected
        local ok, err = pcall(function() self:LoadMainScript() end)
        if not ok then warn("Initialize LoadMainScript failed: " .. tostring(err)) end
        return true
    else
        self:CreateVerificationGUI()
        return false
    end
end

return KeySystem
