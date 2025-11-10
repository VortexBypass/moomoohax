local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

if game.PlaceId ~= 107833198839573 then
    Players.LocalPlayer:Kick("Script only works in Moo Moo Mystery Alpha")
    return
end

local localPlayer = Players.LocalPlayer

getgenv().MooAimlock = {
    Enabled = false,
    CurrentTarget = nil,
    LockedTarget = nil,
    Smoothness = 1
}

getgenv().MooSettings = {
    AimlockEnabled = false,
    ESPEnabled = false,
    CashESPEnabled = false,
    AutoFarmEnabled = false,
    FarmRange = 200,
    ESPFillColor = Color3.fromRGB(255, 0, 0),
    ESPFillTransparency = 0.5,
    NoclipEnabled = false,
    WalkSpeedEnabled = false,
    WalkSpeed = 16,
    JumpPowerEnabled = false,
    JumpPower = 50
}

local espFolders = {}
local cashEspFolders = {}
local currentNotification = nil
local crosshairGui = nil
local crosshairFrame = nil
local outerRingFrame = nil
local crosshairElements = {}
local noclipConnection = nil
local originalCollision = {}
local cashEspConnection = nil
local farmingConnection = nil
local airPlatform = nil
local originalWalkSpeed = 16
local originalJumpPower = 50

local function createNotification(message, color)
    color = color or Color3.new(1,1,1)
    if getgenv().Rayfield and type(getgenv().Rayfield.Notify) == "function" then
        pcall(function()
            getgenv().Rayfield:Notify({
                Title = "Moo Moo Hax",
                Content = message,
                Duration = 2,
                Image = "zap"
            })
        end)
        return
    end
    if currentNotification then
        pcall(function() currentNotification:Destroy() end)
    end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MooNotification"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,200,0,28)
    frame.Position = UDim2.new(1,-210,1,-50)
    frame.BackgroundColor3 = Color3.new(0,0,0)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1,-10,1,-10)
    label.Position = UDim2.new(0,5,0,3)
    label.BackgroundTransparency = 1
    label.Text = message
    label.TextColor3 = color
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.TextWrapped = true
    label.Parent = frame
    currentNotification = screenGui
    delay(2, function()
        if currentNotification then
            pcall(function() currentNotification:Destroy() end)
            currentNotification = nil
        end
    end)
end

local Rayfield
do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
    if ok and lib then
        Rayfield = lib
        getgenv().Rayfield = lib
    else
        createNotification("Rayfield failed to load", Color3.new(1,0.5,0))
        return
    end
end

pcall(function()
    local old = CoreGui:FindFirstChild("MooMooHaxGUI")
    if old then old:Destroy() end
end)
pcall(function()
    local old = Players.LocalPlayer:FindFirstChild("PlayerGui") and Players.LocalPlayer.PlayerGui:FindFirstChild("Crosshair")
    if old then old:Destroy() end
end)

local RayfieldWindow = Rayfield:CreateWindow({
    Name = "Moo Moo Hax",
    Icon = "zap",
    LoadingTitle = "Moo Moo Hax",
    LoadingSubtitle = "By afk.l0l",
    ShowText = "Moo",
    Theme = "Default",
    ToggleUIKeybind = "K",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "MooMooHax"
    },
    Discord = {
        Enabled = true,
        Invite = "vortex-x-sideload-bypass-1355388445509288047",
        RememberJoins = true
    },
    KeySystem = false
})

local function LoadTab(tabName, icon)
    local success, result = pcall(function()
        local url = "https://raw.githubusercontent.com/yourusername/moomoohax/main/tabs/" .. tabName .. ".lua"
        local script = loadstring(game:HttpGet(url))()
        return script(RayfieldWindow, {
            MooAimlock = getgenv().MooAimlock,
            MooSettings = getgenv().MooSettings,
            createNotification = createNotification,
            Players = Players,
            RunService = RunService,
            UserInputService = UserInputService,
            Workspace = Workspace,
            TweenService = TweenService,
            CoreGui = CoreGui,
            localPlayer = localPlayer,
            espFolders = espFolders,
            cashEspFolders = cashEspFolders,
            crosshairGui = crosshairGui,
            crosshairFrame = crosshairFrame,
            outerRingFrame = outerRingFrame,
            crosshairElements = crosshairElements,
            noclipConnection = noclipConnection,
            originalCollision = originalCollision,
            cashEspConnection = cashEspConnection,
            farmingConnection = farmingConnection,
            airPlatform = airPlatform,
            originalWalkSpeed = originalWalkSpeed,
            originalJumpPower = originalJumpPower
        })
    end)
    
    if success then
        return result
    else
        createNotification("Failed to load " .. tabName .. " tab", Color3.new(1,0,0))
        return RayfieldWindow:CreateTab(tabName, icon)
    end
end

LoadTab("aimlock", "target")
LoadTab("esp", "eye")
LoadTab("cashesp", "dollar-sign")
LoadTab("autofarm", "truck")
LoadTab("player", "user")
LoadTab("settings", "sliders")
LoadTab("info", "info")

createNotification("Moo Moo Hax Loaded", Color3.new(0,1,1))
