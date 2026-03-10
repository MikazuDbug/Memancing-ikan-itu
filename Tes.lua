--=============================================================================
-- // Mizukage Official Hub - FIXED VERSION
--=============================================================================

-- [PERBAIKAN 1]: Menggunakan pcall agar script tidak berhenti jika UI gagal dimuat
local WindUI = nil
local success, result = pcall(function()
    return loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
end)

if success and result then
    WindUI = result
else
    warn("Mizukage: Gagal memuat WindUI. Pastikan koneksi internet stabil.")
    return -- Berhenti jika UI tidak bisa dimuat
end

--================================================
--[2] ROBLOX SERVICES & PRELOADER
--================================================
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TextChatService = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer

--================================================
-- [3] SOUND SYSTEM (WITH ASSET PRELOADING)
--================================================
local Sounds = {
    StartupId = "rbxassetid://138614247392811",
    ClickId = "rbxassetid://127920805047354"
}

-- Preload suara agar tidak lag saat pertama kali diputar
local ContentProvider = game:GetService("ContentProvider")
ContentProvider:PreloadAsync({Sounds.StartupId, Sounds.ClickId})

function Sounds:Play(id, volume)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume or 1
    s.Parent = SoundService
    s:Play()
    -- Menggunakan task.delay agar lebih ringan daripada event ended
    task.delay(50, function() s:Destroy() end)
end

function Sounds:Startup() self:Play(Sounds.StartupId, 2) end
function Sounds:Click() self:Play(Sounds.ClickId, 1.5) end

Sounds:Startup()

--================================================
-- [4] GLOBAL VARIABLES (SAVED INPUTS)
--================================================
-- Variabel Player Stats
local savedWalkSpeed = 16
local savedJumpPower = 50
local godModeActive = false

-- Variabel Auto Fish (Safe Mode V12)
local isAutoFishing = false
local safeCatchDelay = 0.5
local safeThrowDelay = 0.5

-- Variabel Fast Farming (Kage Fishing - Pure Remote)
local isKageFishing = false
local kageSessionCaught = 0
local bobberDebounce = false
local throwCooldown = 0
local rDelays = {
    BobberToStart = 1.5,
    Reel = 1.5,
    Retract = 0.3,
    Throw = 0.5
}

local ESP_Settings = {
    Enabled = false,
    Chams = false,
    Boxes = false,
    Info = false,
    Health = false,
    Tracers = false,
    Color = Color3.fromRGB(255, 0, 0)
}
local ESP_Objects = {}

local mizukageUsers = {}
mizukageUsers[LocalPlayer.UserId] = true

--================================================
--[4.5] CLOUD DATABASE FETCHING (WHITELIST)
--================================================
local databaseUrl = "https://raw.githubusercontent.com/MikazuDbug/Memancing-ikan-itu/refs/heads/main/Database.json"

_G.devUsers = {}
_G.vipUsers = {}

-- SISTEM CADANGAN / FALLBACK (Jika GitHub error/Down)
_G.devUsers[9489021936] = true
_G.vipUsers[10399202551] = true
_G.vipUsers[8995226092] = true

-- Mengambil data dari GitHub secara instan sebelum UI dibuat
pcall(function()
    local result = game:HttpGet(databaseUrl)
    if result then
        local decoded = HttpService:JSONDecode(result)
        if decoded then
            if decoded.Developers then
                for _, id in ipairs(decoded.Developers) do _G.devUsers[tonumber(id)] = true end
            end
            if decoded.VIPs then
                for _, id in ipairs(decoded.VIPs) do _G.vipUsers[tonumber(id)] = true end
            end
            print("Mizukage: Cloud Database berhasil dimuat dari GitHub!")
        end
    end
end)

-- Identifikasi Status Pemain Saat Ini
local isDeveloper = _G.devUsers[LocalPlayer.UserId] or false
local isVIP = _G.vipUsers[LocalPlayer.UserId] or false
local hasPanelAccess = isDeveloper or isVIP
--================================================
--[5] CORE FUNCTIONS
--================================================
-- Fungsi Humanizer (Membuat jeda acak agar mirip manusia)
local function getHumanFloat(min, max)
    return min + (math.random() * (max - min))
end

-- Fungsi Bypass: Simulasi Hold & Release (Untuk Safe Farming)
local function holdAndReleaseButton(guiButton, holdDuration)
    if not guiButton or type(getconnections) ~= "function" then return end
    local mockTouch = { UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin, Position = Vector3.new(guiButton.AbsolutePosition.X, guiButton.AbsolutePosition.Y, 0) }
    
    for _, conn in ipairs(getconnections(guiButton.InputBegan)) do pcall(function() conn.Function(mockTouch) end) end
    for _, conn in ipairs(getconnections(guiButton.MouseButton1Down)) do pcall(function() conn.Function() end) end
    
    task.wait(holdDuration)
    
    mockTouch.UserInputState = Enum.UserInputState.End
    for _, conn in ipairs(getconnections(guiButton.InputEnded)) do pcall(function() conn.Function(mockTouch) end) end
    for _, conn in ipairs(getconnections(guiButton.MouseButton1Up)) do pcall(function() conn.Function() end) end
    for _, conn in ipairs(getconnections(guiButton.Activated)) do pcall(function() conn.Function() end) end
    for _, conn in ipairs(getconnections(guiButton.MouseButton1Click)) do pcall(function() conn.Function() end) end
end

-- Mesin Pembersih Sensor ESP
local function ClearESP(player)
    if ESP_Objects[player] then
        for _, obj in pairs(ESP_Objects[player]) do
            pcall(function() obj:Destroy() end)
        end
        if ESP_Objects[player].Tracer and type(ESP_Objects[player].Tracer.Remove) == "function" then
            pcall(function() ESP_Objects[player].Tracer:Remove() end)
        end
        ESP_Objects[player] = nil
    end
end

--================================================
-- [6] METATABLE BYPASS (DIOPTIMASI AGAR TIDAK MEMORY LEAK)
--================================================
local mt = getrawmetatable(game)
local oldNamecall = mt.__namecall
setreadonly(mt, false)

mt.__namecall = newcclosure(function(self, ...)
    local method = getnamecallmethod()
    
    -- Anti Kick ditempatkan paling atas agar dieksekusi cepat
    if method == "Kick" then
        print("Mizukage: Mencegah upaya KICK dari Server!")
        return nil
    end

    -- Pengecekan Type Instance untuk mencegah error
    if typeof(self) == "Instance" then
        local name = self.Name
        
        -- [HOOK 1] Fast Farming Trigger
        if isKageFishing and method == "InvokeServer" and name == "GetEquippedBobber" then
            if not bobberDebounce then
                bobberDebounce = true
                task.spawn(function()
                    task.wait(rDelays.BobberToStart + getHumanFloat(0.01, 0.15))
                    
                    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    local toolId = tool and tool:GetAttribute("ToolUniqueId")
                    if not toolId then bobberDebounce = false return end
                    
                    local fishingFolder = ReplicatedStorage:FindFirstChild("Fishing")
                    local toServerFolder = fishingFolder and fishingFolder:FindFirstChild("ToServer")
                    
                    local minigameStartRemote = toServerFolder and toServerFolder:FindFirstChild("MinigameStarted")
                    local reelFinishedRemote = toServerFolder and toServerFolder:FindFirstChild("ReelFinished")
                    local retractRemote = ReplicatedStorage:FindFirstChild("Fishing_RemoteRetract")
                    
                    if minigameStartRemote then minigameStartRemote:FireServer(toolId) end
                    
                    task.wait(rDelays.Reel + getHumanFloat(0.05, 0.15))
                    
                    if reelFinishedRemote then
                        reelFinishedRemote:FireServer({
                            duration = rDelays.Reel + getHumanFloat(1.5, 3.5),
                            result = "SUCCESS",
                            perfect = true,
                            insideRatio = getHumanFloat(0.85, 0.98)
                        }, toolId)
                        kageSessionCaught = kageSessionCaught + 1
                    end
                    
                    task.wait(rDelays.Retract + getHumanFloat(0.02, 0.1))
                    if retractRemote then retractRemote:FireServer(toolId) end
                    
                    throwCooldown = tick() + rDelays.Throw + getHumanFloat(0.1, 0.4)
                    bobberDebounce = false
                end)
            end
            local args = {...}
            return oldNamecall(self, unpack(args))
        end

        -- [HOOK 2] ReelFinished intercept
        if (isAutoFishing or isKageFishing) and method == "FireServer" and name == "ReelFinished" then
            local args = {...}
            if args[1] and type(args[1]) == "table" then
                args[1].result = "SUCCESS"
                if isKageFishing then
                    args[1].perfect = true
                    args[1].insideRatio = getHumanFloat(0.85, 0.98)
                else
                    args[1].insideRatio = math.random(95, 100) / 100.0
                    if args[1].duration and args[1].duration < 2 then 
                        args[1].duration = math.random(250, 450) / 100.0 
                    end
                end
            end
            return oldNamecall(self, unpack(args))
        end
    end

    return oldNamecall(self, ...)
end)
setreadonly(mt, true)

--================================================
-- [7] UI DASHBOARD & WINDOW SETUP (UPGRADED V15.8)
--================================================
local Window = WindUI:CreateWindow({
    Title = "Mizukage Official",
    -- Menggunakan rbxthumb agar Decal ID otomatis terbaca sebagai gambar
    Icon = "rbxthumb://type=Asset&id=9803470666&w=200&h=200", 
    Author = "By Mizukage",
    Folder = "MizukageHub",
    Size = UDim2.fromOffset(720, 520),
    Transparent = true,
    Theme = "Indigo",
    
    -- KODE BACKGROUND (Bypass Decal ID)
    Background = "rbxthumb://type=Asset&id=95187322906207&w=420&h=420",
    BackgroundImageTransparency = 0.8 -- 0.5 agar gambar terlihat tapi teks tetap terbaca
})

-- Fungsi Helper untuk membuat Tab agar kode lebih bersih
local Home = Window:Tab({Title="Dashboard", Icon="layout-dashboard"})
local PlayerTab = Window:Tab({Title="Character", Icon="user"})
local TeleportTab = Window:Tab({Title="Teleport", Icon="map"})
local Farming = Window:Tab({Title="Farming", Icon="fish"})
local Visual = Window:Tab({Title="Visual", Icon="eye"})
local Settings = Window:Tab({Title="Settings", Icon="settings"})

-- [VIP & DEVELOPER PROTECTION] 
local DevTab = nil

if hasPanelAccess then
    -- Jika dia Dev, namanya "Dev Panel". Jika dia VIP, namanya "VIP Panel".
    local tabName = isDeveloper and "Dev Panel" or "VIP Panel"
    DevTab = Window:Tab({Title=tabName, Icon="crown"})
end

--[KEYBIND TOGGLE]
UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.RightShift then
        Window:Toggle()
    end
end)

-- [PREMIUM WELCOME]
task.spawn(function()
    task.wait(1)
    WindUI:Notify({
        Title = "Mizukage Hub", 
        Content = "Sistem telah dimuat. Tekan [RightShift] untuk sembunyikan UI.", 
        Duration = 1
    })
end)
--================================================
-- MENU: DASHBOARD (PREMIUM V15.8 - CLEAN & EXCLUSIVE)
--================================================
local executorName = identifyexecutor and identifyexecutor() or "Unknown Executor"
local accountAge = LocalPlayer.AccountAge
local placeId = game.PlaceId
local maxPlayers = Players.MaxPlayers
local osDate = os.date("%A, %d %B %Y")

Home:Section({Title = "🌟 STATUS SISTEM ENGINE"})

-- Kita definisikan UI objeknya terlebih dahulu
local statusPara = Home:Paragraph({
    Title = "⚙️ Engine Status: INITIALIZING...",
    Desc = "Menunggu Engine..."
})

-- Gunakan task.defer untuk memastikan UI sudah ter-render sebelum memulai loop
task.defer(function()
    while task.wait(1) do
        -- Pastikan WindUI masih aktif
        if not statusPara then break end
        
        local mode = "IDLE"
        if isKageFishing then
            mode = "FAST FARMING (KAGE)"
        elseif isAutoFishing then
            mode = "SAFE FARMING (SIMULATOR)"
        end
        
        -- Menggunakan pcall untuk menghindari crash jika UI ditutup/dihancurkan
        pcall(function()
            statusPara:Refresh({
                Title = "⚙️ Engine Status: " .. mode,
                Desc = "Status: " .. mode .. " | Koneksi: Stabil\nAnti-Kick: Aktif | Server: " .. game.JobId
            })
        end)
    end
end)

Home:Section({Title = "👤 INFORMASI PROFIL"})

-- Gambar Banner sesuai request
Home:Paragraph({
    Title = "🌊 Mizukage Hub (Premium Edition)", 
    Desc = "Selamat datang kembali, " .. LocalPlayer.Name .. "!\n\n" ..
           "Display Name: @" .. LocalPlayer.DisplayName .. "\n" ..
           "User ID: " .. LocalPlayer.UserId .. "\n" ..
           "Umur Akun: " .. accountAge .. " Hari\n" ..
           "Eksekutor: " .. executorName .. "\n" ..
           "Banner ID: 95187322906207"
})

Home:Section({Title = "🌍 INFORMASI SERVER"})

Home:Paragraph({
    Title = "📊 Statistik",
    Desc = "Tanggal: " .. osDate .. "\n" ..
           "Pemain: " .. #Players:GetPlayers() .. " / " .. maxPlayers .. " Pemain"
})

local targetJobId = ""

Home:Button({
    Title = "📋 Salin JobID (Server ID) Saya",
    Desc = "Salin ID Server ini untuk dikirim ke teman agar mereka bisa menyusul.",
    Callback = function()
        Sounds:Click()
        if setclipboard then
            setclipboard(game.JobId)
            WindUI:Notify({Title="Berhasil", Content="JobID disalin ke clipboard!", Duration=3})
        else
            WindUI:Notify({Title="Gagal", Content="Eksekutor kamu tidak mendukung fitur salin.", Duration=3})
        end
    end
})

Home:Input({
    Title = "🔗 Masukkan JobID Teman",
    Desc = "Paste (Tempel) JobID server teman kamu di sini.",
    Placeholder = "Paste JobID di sini...",
    Callback = function(text)
        targetJobId = text
    end
})

Home:Button({
    Title = "🚀 Gass Mabar (Teleport ke Teman)",
    Desc = "Klik ini untuk langsung terbang ke server teman sesuai JobID di atas.",
    Callback = function()
        Sounds:Click()
        
        -- Validasi sederhana (Pastikan tidak kosong dan panjang karakternya masuk akal)
        if targetJobId == "" or #targetJobId < 10 then
            WindUI:Notify({Title="Gagal", Content="Masukkan JobID yang valid terlebih dahulu!", Duration=3})
            return
        end
        
        if targetJobId == game.JobId then
            WindUI:Notify({Title="Info", Content="Kamu sudah berada di server ini!", Duration=3})
            return
        end
        
        WindUI:Notify({Title="🚀 Teleporting...", Content="Menyusul teman ke server baru. Mohon tunggu...", Duration=5})
        
        -- Proses Teleportasi ke server yang dituju
        local success, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, LocalPlayer)
        end)
        
        if not success then
            WindUI:Notify({Title="Error", Content="Gagal teleport. Pastikan JobID benar atau server belum penuh.", Duration=4})
            print("Teleport Error: " .. tostring(err))
        end
    end
})

Home:Section({Title = "📢 UPDATE LOG & PANDUAN"})

Home:Paragraph({
    Title = "🚀 Apa yang baru di versi V15.8?", 
    Desc = "- Optimasi Engine Farming (High Performance)\n- Sistem Auto-Optimize (Potato Mode Fixed)\n- Security & Reconnection terintegrasi\n- Memory Leak & Lag Fixed"
})

Home:Paragraph({
    Title = "📖 Panduan Penggunaan",
    Desc = "Pastikan semua input sudah di-Inject sebelum memulai. Gunakan Mode Safe untuk keamanan maksimal atau Mode Fast untuk kecepatan maksimal."
})

--================================================
-- MENU: CHARACTER MODIFIER (ULTRA UPDATE)
--================================================
PlayerTab:Section({Title="PENGATURAN STATUS DASAR"})

PlayerTab:Input({
    Title = "Set WalkSpeed (Kecepatan Lari)",
    Desc = "Ketik angka kecepatan (Default game adalah 16). Akan dikunci permanen oleh sistem.",
    Placeholder = tostring(savedWalkSpeed),
    Callback = function(text)
        local val = tonumber(text)
        if val then 
            savedWalkSpeed = val 
            Sounds:Click()
            WindUI:Notify({Title="Kecepatan Disiapkan", Content="WalkSpeed disiapkan ke: "..val.."\nSilakan tekan Inject.", Duration=2})
        end
    end
})

PlayerTab:Input({
    Title = "Set JumpPower (Tinggi Lompat)",
    Desc = "Ketik angka lompatan (Default game adalah 50). Akan dikunci permanen oleh sistem.",
    Placeholder = tostring(savedJumpPower),
    Callback = function(text)
        local val = tonumber(text)
        if val then 
            savedJumpPower = val 
            Sounds:Click()
            WindUI:Notify({Title="Lompatan Disiapkan", Content="JumpPower disiapkan ke: "..val.."\nSilakan tekan Inject.", Duration=2})
        end
    end
})

PlayerTab:Button({
    Title = "⚡ Inject / Terapkan Status",
    Desc = "WAJIB KLIK! Memasukkan nilai WalkSpeed dan JumpPower yang sudah kamu ketik ke dalam memori karakter secara paten.",
    Callback = function()
        Sounds:Click()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = savedWalkSpeed
            LocalPlayer.Character.Humanoid.JumpPower = savedJumpPower
            WindUI:Notify({Title="Inject Berhasil!", Content="Status Karakter telah diperbarui dan dikunci.", Duration=3})
        else
            WindUI:Notify({Title="Gagal", Content="Karakter tidak ditemukan, coba respawn.", Duration=3})
        end
    end
})

PlayerTab:Section({Title="🔥 KEMAMPUAN SUPER (SUPERPOWERS)"})

-- INFINITE JUMP
local infJumpConnection
PlayerTab:Toggle({
    Title = "🚀 Infinite Jump (Lompat Tanpa Batas)",
    Desc = "Tekan tombol lompat (Spasi) berkali-kali di udara untuk terbang ke atas tanpa batas.",
    Default = false,
    Callback = function(state)
        Sounds:Click()
        if state then
            infJumpConnection = UIS.JumpRequest:Connect(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
            WindUI:Notify({Title="Infinite Jump Aktif", Content="Kamu sekarang bisa melompat di udara!", Duration=3})
        else
            if infJumpConnection then infJumpConnection:Disconnect() end
            WindUI:Notify({Title="Infinite Jump Nonaktif", Content="Lompatan kembali normal.", Duration=3})
        end
    end
})

-- NOCLIP (TEMBUS TEMBOK)
local noclipConnection
PlayerTab:Toggle({
    Title = "👻 Noclip (Tembus Dinding & Objek)",
    Desc = "Membuat karaktermu tembus dari semua benda padat seperti batu, pohon, dan dinding.",
    Default = false,
    Callback = function(state)
        Sounds:Click()
        if state then
            noclipConnection = RunService.Stepped:Connect(function()
                if LocalPlayer.Character then
                    for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide == true then
                            part.CanCollide = false
                        end
                    end
                end
            end)
            WindUI:Notify({Title="Noclip Aktif", Content="Kamu sekarang bisa menembus dinding!", Duration=3})
        else
            if noclipConnection then noclipConnection:Disconnect() end
            WindUI:Notify({Title="Noclip Nonaktif", Content="Fisika karakter kembali normal.", Duration=3})
        end
    end
})

-- AIRWALK / JESUS MODE
local airWalkPart
local airWalkConnection
PlayerTab:Toggle({
    Title = "☁️ AirWalk (Pijakan Udara)",
    Desc = "Menciptakan lantai tak kasat mata di bawah kaki. Memungkinkanmu berjalan di atas air atau udara bebas.",
    Default = false,
    Callback = function(state)
        Sounds:Click()
        if state then
            airWalkPart = Instance.new("Part", workspace)
            airWalkPart.Size = Vector3.new(5, 1, 5)
            airWalkPart.Anchored = true
            airWalkPart.Transparency = 1
            airWalkConnection = RunService.RenderStepped:Connect(function()
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    airWalkPart.Position = LocalPlayer.Character.HumanoidRootPart.Position - Vector3.new(0, 3.5, 0)
                end
            end)
            WindUI:Notify({Title="AirWalk Aktif", Content="Pijakan udara telah dibuat di bawah kakimu.", Duration=3})
        else
            if airWalkConnection then airWalkConnection:Disconnect() end
            if airWalkPart then airWalkPart:Destroy() end
            WindUI:Notify({Title="AirWalk Nonaktif", Content="Pijakan udara telah dihapus.", Duration=3})
        end
    end
})

PlayerTab:Section({Title="🌍 DUNIA, KAMERA & VISUAL"})

-- GRAVITY MODIFIER
PlayerTab:Input({
    Title = "🌌 Set Gravitasi Dunia",
    Desc = "Ubah gravitasi game (Default: 196.2). Ubah ke 50 untuk melayang seperti di bulan, atau 0 untuk anti-gravitasi.",
    Placeholder = "196.2",
    Callback = function(text)
        local val = tonumber(text)
        if val then 
            workspace.Gravity = val
            Sounds:Click()
            WindUI:Notify({Title="Gravitasi Diubah", Content="Gravitasi dunia sekarang: "..val, Duration=3})
        end
    end
})

-- FOV MODIFIER
PlayerTab:Input({
    Title = "🎥 Set Field of View (FOV)",
    Desc = "Ubah luas pandangan kamera (Default: 70). Ubah ke 120 untuk pandangan mata elang (sangat luas).",
    Placeholder = "70",
    Callback = function(text)
        local val = tonumber(text)
        if val then
            workspace.CurrentCamera.FieldOfView = val
            Sounds:Click()
            WindUI:Notify({Title="Kamera Diubah", Content="FOV Kamera sekarang: "..val, Duration=3})
        end
    end
})

-- FULLBRIGHT LOOP
local fullBrightConnection
PlayerTab:Toggle({
    Title = "💡 FullBright (Mata Dewa)",
    Desc = "Mematikan semua kabut, bayangan, dan malam hari secara paksa. Map akan selalu terang benderang.",
    Default = false,
    Callback = function(state)
        Sounds:Click()
        if state then
            fullBrightConnection = RunService.RenderStepped:Connect(function()
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.FogEnd = 100000
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            end)
            WindUI:Notify({Title="FullBright Aktif", Content="Dunia sekarang terang benderang tanpa bayangan.", Duration=3})
        else
            if fullBrightConnection then fullBrightConnection:Disconnect() end
            WindUI:Notify({Title="FullBright Nonaktif", Content="Settingan cahaya dihentikan (akan kembali pelan-pelan).", Duration=3})
        end
    end
})

--================================================
-- MENU: TELEPORT MAP
--================================================
TeleportTab:Section({Title="LOKASI PULAU UTAMA"})

TeleportTab:Button({
    Title = "🏝️ Teleport ke Nusa",
    Desc = "Pindah secara instan ke area Nusa.",
    Callback = function()
        Sounds:Click()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(CFrame.new(Vector3.new(-319.748444, 1030.983154, 390.530701)))
            WindUI:Notify({Title="Teleport Sukses", Content="Berhasil pindah ke Nusa.", Duration=3})
        end
    end
})

TeleportTab:Button({
    Title = "🏝️ Teleport ke Pulau Kinyis",
    Desc = "Pindah secara instan ke area Pulau Kinyis.",
    Callback = function()
        Sounds:Click()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(CFrame.new(Vector3.new(123.539856, 1012.054321, -946.186951)))
            WindUI:Notify({Title="Teleport Sukses", Content="Berhasil pindah ke Pulau Kinyis.", Duration=3})
        end
    end
})

TeleportTab:Button({
    Title = "🏝️ Teleport ke Pulau Tropis",
    Desc = "Pindah secara instan ke area Pulau Tropis.",
    Callback = function()
        Sounds:Click()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(CFrame.new(Vector3.new(-1807.453857, 1005.002808, -1488.845459)))
            WindUI:Notify({Title="Teleport Sukses", Content="Berhasil pindah ke Pulau Tropis.", Duration=3})
        end
    end
})

TeleportTab:Button({
    Title = "🏝️ Teleport ke Wilayah Skylar",
    Desc = "Pindah secara instan ke area Wilayah Skylar.",
    Callback = function()
        Sounds:Click()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character:PivotTo(CFrame.new(Vector3.new(-1431.894043, 1021.170166, 1536.863159)))
            WindUI:Notify({Title="Teleport Sukses", Content="Berhasil pindah ke Wilayah Skylar.", Duration=3})
        end
    end
})

--================================================
-- MENU: FARMING LOGIC
--================================================
Farming:Section({Title="MODE 1: SAFE FARMING (UI SIMULATOR)"})
Farming:Toggle({
    Title = "🎣 Nyalakan Safe Farming",
    Desc = "Menggunakan sentuhan layar buatan (Hold & Release). 100% aman namun sedikit lambat. (Pastikan Fast Farming OFF)",
    Default = false,
    Callback = function(state) 
        Sounds:Click() 
        isAutoFishing = state 
        if isAutoFishing and isKageFishing then
            WindUI:Notify({Title="Peringatan!", Content="Fast Farming masih menyala! Matikan salah satu.", Duration=3})
        end
    end
})

Farming:Input({
    Title = "Set Catch Delay (Safe Mode)",
    Desc = "Jeda waktu sebelum menarik kail setelah ikan menggigit (Default: 0.5).",
    Placeholder = "0.5",
    Callback = function(text) local v = tonumber(text) if v then safeCatchDelay = v end end
})

Farming:Input({
    Title = "Set Throw Power (Safe Mode)",
    Desc = "Berapa detik tombol lempar ditahan agar kekuatan pas (Default: 1.6).",
    Placeholder = "1.6",
    Callback = function(text) local v = tonumber(text) if v then safeThrowDelay = v end end
})

Farming:Button({
    Title = "⚡ Inject Delay Safe Farming",
    Desc = "Verifikasi dan terapkan delay Safe Mode secara paten.",
    Callback = function()
        Sounds:Click()
        WindUI:Notify({Title="Inject Berhasil", Content="Catch: "..safeCatchDelay.."s | Throw: "..safeThrowDelay.."s", Duration=3})
    end
})

Farming:Section({Title="MODE 2: FAST FARMING (KAGE PURE REMOTE)"})
Farming:Toggle({
    Title = "⚡ Nyalakan Fast Farming (Kage Edition)",
    Desc = "Sangat Cepat! Menggunakan Remote Firing untuk bypass seluruh animasi UI pancing. (Pastikan Safe Farming OFF)",
    Default = false,
    Callback = function(state) 
        Sounds:Click() 
        isKageFishing = state 
        if isAutoFishing and isKageFishing then
            WindUI:Notify({Title="Peringatan!", Content="Safe Farming masih menyala! Matikan salah satu.", Duration=3})
        end
    end
})

Farming:Input({
    Title = "Bobber ke Minigame Delay",
    Desc = "Jeda pelampung ke awal minigame (Default: 1.5)",
    Placeholder = "1.5",
    Callback = function(text) local v = tonumber(text) if v then rDelays.BobberToStart = v end end
})

Farming:Input({
    Title = "Minigame ke Reel (Tarik) Delay",
    Desc = "Jeda sebelum game menganggap ikan ditarik sukses (Default: 1.5)",
    Placeholder = "1.5",
    Callback = function(text) local v = tonumber(text) if v then rDelays.Reel = v end end
})

Farming:Input({
    Title = "Reel ke Retract Delay",
    Desc = "Jeda dari hasil sukses ke kail masuk ke inventory (Default: 0.3)",
    Placeholder = "0.3",
    Callback = function(text) local v = tonumber(text) if v then rDelays.Retract = v end end
})

Farming:Input({
    Title = "Retract ke Lempar (Throw) Delay",
    Desc = "Jeda setelah menarik kail hingga dilempar kembali (Default: 0.5)",
    Placeholder = "0.5",
    Callback = function(text) local v = tonumber(text) if v then rDelays.Throw = v end end
})

Farming:Button({
    Title = "⚡ Inject Delay Fast Farming",
    Desc = "Verifikasi dan terapkan semua 4 tipe Delay Fast Farming secara paten.",
    Callback = function()
        Sounds:Click()
        WindUI:Notify({Title="Inject Berhasil", Content="Semua setelan kecepatan Fast Farming telah dikunci.", Duration=3})
    end
})

--================================================
-- UI TAB VISUAL
--================================================
Visual:Section({Title="⚙️ KONTROL SENSOR UTAMA"})

Visual:Toggle({
    Title = "👁️ Master ESP (Nyalakan Sensor)",
    Desc = "Tombol sakelar utama. Wajib diaktifkan agar fitur radar di bawah bisa bekerja.",
    Default = true,
    Callback = function(state)
        Sounds:Click()
        ESP_Settings.Enabled = state
        if state then
            WindUI:Notify({Title="Sensor Online", Content="Sistem radar utama telah diaktifkan.", Duration=2})
        else
            WindUI:Notify({Title="Sensor Offline", Content="Seluruh visual dihentikan.", Duration=2})
        end
    end
})

Visual:Section({Title="🎯 KUSTOMISASI VISUAL"})

Visual:Toggle({
    Title = "👤 Chams (Tembus Tembok)",
    Desc = "Mewarnai badan player agar menyala dan terlihat menembus batu/dinding.",
    Default = false,
    Callback = function(state) Sounds:Click() ESP_Settings.Chams = state end
})

Visual:Toggle({
    Title = "🔲 2D Boxes",
    Desc = "Membuat kotak presisi pembidik di sekitar karakter musuh.",
    Default = false,
    Callback = function(state) Sounds:Click() ESP_Settings.Boxes = state end
})

Visual:Toggle({
    Title = "📝 Info Target (Nama & Jarak)",
    Desc = "Menampilkan Username dan hitungan Jarak (Meter) dari posisimu ke musuh.",
    Default = false,
    Callback = function(state) Sounds:Click() ESP_Settings.Info = state end
})

Visual:Toggle({
    Title = "❤️ Health Bar (Status Darah)",
    Desc = "Menampilkan indikator bar HP musuh di sebelah kiri kotak target.",
    Default = false,
    Callback = function(state) Sounds:Click() ESP_Settings.Health = state end
})

Visual:Toggle({
    Title = "📍 Laser Tracers",
    Desc = "Menarik garis laser pembidik dari bawah layar langsung ke posisi musuh.",
    Default = false,
    Callback = function(state) Sounds:Click() ESP_Settings.Tracers = state end
})

Visual:Section({Title="🎨 PENGATURAN WARNA"})

Visual:Dropdown({
    Title="Pilih Warna Sensor (ESP Color)", 
    Desc="Ganti warna lampu radar sesuai seleramu.",
    Values={"Merah", "Biru", "Hijau", "Kuning", "Ungu", "Putih", "Cyan"}, 
    Default="Merah",
    Callback=function(v) 
        Sounds:Click()
        if v == "Merah" then ESP_Settings.Color = Color3.fromRGB(255, 0, 0)
        elseif v == "Biru" then ESP_Settings.Color = Color3.fromRGB(0, 100, 255)
        elseif v == "Hijau" then ESP_Settings.Color = Color3.fromRGB(0, 255, 0)
        elseif v == "Kuning" then ESP_Settings.Color = Color3.fromRGB(255, 255, 0)
        elseif v == "Ungu" then ESP_Settings.Color = Color3.fromRGB(150, 0, 255)
        elseif v == "Putih" then ESP_Settings.Color = Color3.fromRGB(255, 255, 255)
        elseif v == "Cyan" then ESP_Settings.Color = Color3.fromRGB(0, 255, 255)
        end
        WindUI:Notify({Title="Warna Diperbarui", Content="Warna Sensor diubah ke: " .. v, Duration=2})
    end
})
--================================================
--[TAMBAHAN] MENU: DEV PANEL (ULTIMATE ADMIN COMMANDS)
--================================================
local function createTargetMonitor(target)
    -- Menghapus monitor lama jika ada
    if CoreGui:FindFirstChild("Mizukage_TargetMonitor") then 
        CoreGui.Mizukage_TargetMonitor:Destroy() 
    end

    local ScreenGui = Instance.new("ScreenGui", CoreGui)
    ScreenGui.Name = "Mizukage_TargetMonitor"
    
    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 300, 0, 200)
    Frame.Position = UDim2.new(0.5, -150, 0.5, -100)
    Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    Frame.BorderSizePixel = 0
    Frame.Active = true
    Frame.Draggable = true

    local Title = Instance.new("TextLabel", Frame)
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.Text = "🔍 Memantau: " .. target.Name
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.BackgroundTransparency = 0.5
    Title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    
    local InfoText = Instance.new("TextLabel", Frame)
    InfoText.Size = UDim2.new(1, -20, 1, -40)
    InfoText.Position = UDim2.new(0, 10, 0, 40)
    InfoText.TextXAlignment = Enum.TextXAlignment.Left
    InfoText.TextYAlignment = Enum.TextYAlignment.Top
    InfoText.TextColor3 = Color3.new(1, 1, 1)
    InfoText.BackgroundTransparency = 1
    
    local CloseBtn = Instance.new("TextButton", Frame)
    CloseBtn.Size = UDim2.new(0, 20, 0, 20)
    CloseBtn.Position = UDim2.new(1, -25, 0, 5)
    CloseBtn.Text = "X"
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    task.spawn(function()
        while ScreenGui and ScreenGui.Parent do
            if target and target.Parent then
                local hum = target.Character and target.Character:FindFirstChild("Humanoid")
                local hp = hum and math.floor(hum.Health) or "Mati"
                local tools = {}
                for _, v in ipairs(target.Backpack:GetChildren()) do table.insert(tools, v.Name) end
                for _, v in ipairs(target.Character:GetChildren()) do if v:IsA("Tool") then table.insert(tools, v.Name .. " (Equipped)") end end
                
                InfoText.Text = string.format("Darah: %s\nUmur: %d Hari\nTas: %s", tostring(hp), target.AccountAge, table.concat(tools, ", "))
            else
                InfoText.Text = "Target telah keluar server."
            end
            task.wait(1)
        end
    end)
end

if hasPanelAccess and DevTab then
    DevTab:Section({Title="👑 PUSAT KENDALI EKSKLUSIF"})
    
    local roleName = isDeveloper and "Developer" or "VIP Member"
    DevTab:Paragraph({
        Title="Akses Terverifikasi: " .. roleName .. " Mizukage", 
        Desc="Tab ini dilindungi oleh Cloud Database. Seluruh fitur di sini memiliki otoritas penuh terhadap manipulasi Client-Side."
    })
    
    -- (Biarkan sisa kode Dev Panel di bawahnya tetap sama)
    local targetPlayerName = nil

    local function getPlayerList()
        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(list, p.Name) end
        end
        if #list == 0 then table.insert(list, "Kosong") end
        return list
    end

    local tpDropdown = DevTab:Dropdown({
        Title = "🎯 Kunci Target (Lock Player)",
        Desc = "Pilih player dari daftar ini untuk dijadikan target operasi (Teleport/Spectate/Troll).",
        Values = getPlayerList(),
        Default = "Pilih Player...",
        Callback = function(targetName)
            Sounds:Click()
            if targetName ~= "Kosong" and targetName ~= "Pilih Player..." then
                targetPlayerName = targetName
                WindUI:Notify({Title="Target Dikunci", Content="Sistem mengunci target: " .. targetName, Duration=2})
            else
                targetPlayerName = nil
            end
        end
    })

    DevTab:Button({
        Title = "🔄 Refresh Daftar Player",
        Desc = "Perbarui list player jika ada orang baru masuk/keluar server.",
        Callback = function()
            Sounds:Click()
            tpDropdown:Refresh(getPlayerList())
            WindUI:Notify({Title="Refresh Berhasil", Content="List dropdown player telah diperbarui.", Duration=2})
        end
    })

    DevTab:Section({Title="🛡️ KEKUATAN DEVELOPER (SELF)"})

    -- MODE HANTU
    local isGhost = false
    DevTab:Toggle({
        Title = "👻 Mode Hantu (Invisibility)",
        Desc = "Membuat karaktermu 100% transparan agar bisa mengintai tanpa ketahuan.",
        Default = false,
        Callback = function(state)
            Sounds:Click()
            isGhost = state
            if LocalPlayer.Character then
                for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                    if v:IsA("BasePart") or v:IsA("Decal") then
                        if v.Name ~= "HumanoidRootPart" then
                            v.Transparency = state and 1 or 0
                        end
                    end
                end
                if state then
                    WindUI:Notify({Title="Mode Hantu Aktif", Content="Kamu sekarang tidak terlihat!", Duration=3})
                else
                    WindUI:Notify({Title="Mode Hantu Nonaktif", Content="Karaktermu kembali terlihat.", Duration=3})
                end
            end
        end
    })

    -- GOD SHIELD (ANTI-FLING)
    local shieldConn
    DevTab:Toggle({
        Title = "🛡️ God Shield (Anti-Troll & Fling)",
        Desc = "Menonaktifkan tabrakan fisik dengan player lain. Kamu tidak akan bisa didorong atau di-fling siapapun.",
        Default = false,
        Callback = function(state)
            Sounds:Click()
            if state then
                shieldConn = RunService.Stepped:Connect(function()
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            for _, v in pairs(p.Character:GetDescendants()) do
                                if v:IsA("BasePart") then
                                    v.CanCollide = false
                                end
                            end
                        end
                    end
                end)
                WindUI:Notify({Title="God Shield Aktif", Content="Kamu kebal dari tabrakan player lain.", Duration=3})
            else
                if shieldConn then shieldConn:Disconnect() end
                WindUI:Notify({Title="God Shield Nonaktif", Content="Fisika tabrakan kembali normal.", Duration=3})
            end
        end
    })

    DevTab:Section({Title="⚔️ EKSEKUSI & SIKSA TARGET"})

    DevTab:Button({
        Title = "🚀 Teleport Instan ke Target",
        Desc = "Berpindah tepat ke belakang player yang sedang dikunci.",
        Callback = function()
            Sounds:Click()
            if not targetPlayerName then WindUI:Notify({Title="Error", Content="Kunci target terlebih dahulu di dropdown!", Duration=2}) return end
            
            local target = Players:FindFirstChild(targetPlayerName)
            if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                LocalPlayer.Character:PivotTo(target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
                WindUI:Notify({Title="Eksekusi Sukses", Content="Berhasil teleport ke " .. targetPlayerName, Duration=3})
            else
                WindUI:Notify({Title="Gagal", Content="Player tidak valid atau sedang mati.", Duration=3})
            end
        end
    })

    -- STALK MODE (LOOP TP)
    local stalkConn
    DevTab:Toggle({
        Title = "🧲 Stalking Mode (Nempel Target)",
        Desc = "Karaktermu akan terus-menerus teleport dan menempel ke punggung target ke manapun mereka pergi.",
        Default = false,
        Callback = function(state)
            Sounds:Click()
            if state then
                if not targetPlayerName then WindUI:Notify({Title="Error", Content="Kunci target terlebih dahulu!", Duration=2}) return end
                stalkConn = RunService.RenderStepped:Connect(function()
                    local target = Players:FindFirstChild(targetPlayerName)
                    if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
                    end
                end)
                WindUI:Notify({Title="Stalking Aktif", Content="Terus menempel pada " .. targetPlayerName, Duration=3})
            else
                if stalkConn then stalkConn:Disconnect() end
                WindUI:Notify({Title="Stalking Berhenti", Content="Berhenti menempel pada target.", Duration=3})
            end
        end
    })

    -- SPECTATE MODE (CCTV)
    local isSpectating = false
    DevTab:Toggle({
        Title = "👁️ Spectate Mode (CCTV Target)",
        Desc = "Kamera kamu akan menempel ke target. (Matikan untuk kembali ke karaktermu sendiri).",
        Default = false,
        Callback = function(state)
            Sounds:Click()
            isSpectating = state
            if state then
                if not targetPlayerName then WindUI:Notify({Title="Error", Content="Pilih target dulu!", Duration=2}) return end
                local target = Players:FindFirstChild(targetPlayerName)
                if target and target.Character and target.Character:FindFirstChild("Humanoid") then
                    workspace.CurrentCamera.CameraSubject = target.Character.Humanoid
                    WindUI:Notify({Title="Spectate Aktif", Content="Memantau layar " .. targetPlayerName, Duration=3})
                end
            else
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                    workspace.CurrentCamera.CameraSubject = LocalPlayer.Character.Humanoid
                    WindUI:Notify({Title="Spectate Mati", Content="Kamera kembali ke karaktermu.", Duration=3})
                end
            end
        end
    })

    DevTab:Button({
        Title = "🕵️ Cek Info & Tas Target",
        Desc = "Membuka monitor khusus untuk memantau status target.",
        Callback = function()
            Sounds:Click()
            if not targetPlayerName then WindUI:Notify({Title="Error", Content="Kunci target terlebih dahulu!", Duration=2}) return end
            
            local target = Players:FindFirstChild(targetPlayerName)
            if target then
                createTargetMonitor(target)
                WindUI:Notify({Title="Monitoring Aktif", Content="Memantau " .. target.Name, Duration=3})
            else
                WindUI:Notify({Title="Gagal", Content="Player tidak ditemukan.", Duration=3})
            end
        end
    })

    DevTab:Button({
        Title = "👥 Kloning Avatar Target",
        Desc = "Menyalin 100% baju, wajah, dan aksesoris target ke tubuh karaktermu secara instan.",
        Callback = function()
            Sounds:Click()
            if not targetPlayerName then WindUI:Notify({Title="Error", Content="Kunci target terlebih dahulu!", Duration=2}) return end
            local target = Players:FindFirstChild(targetPlayerName)
            if target and target.Character and target.Character:FindFirstChild("Humanoid") and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
                pcall(function()
                    local targetDesc = target.Character.Humanoid:GetAppliedDescription()
                    LocalPlayer.Character.Humanoid:ApplyDescription(targetDesc)
                    WindUI:Notify({Title="Kloning Sukses", Content="Kamu sekarang berpenampilan seperti " .. targetPlayerName, Duration=3})
                end)
            else
                WindUI:Notify({Title="Gagal", Content="Tidak bisa memuat data avatar target.", Duration=3})
            end
        end
    })

    DevTab:Section({Title="📡 SPY NETWORK & DATABASE (REMOTE)"})

    DevTab:Button({
        Title = "🔍 Scan & Kirim ke Discord (Pro)",
        Desc = "Scan pengguna script + Info Profil & Thumbnail Target.",
        Callback = function()
            Sounds:Click()
            local foundPlayers = {}
            
            for userId, _ in pairs(mizukageUsers) do
                local p = Players:GetPlayerByUserId(userId)
                if p then
                    local accountAge = p.AccountAge
                    local tag = (accountAge < 30) and "⚠️ (Akun Baru)" or "✅ (Senior)"
                    table.insert(foundPlayers, string.format("👤 **%s**\n🆔 ID: %d | %s\n🔗 [Lihat Profil](https://www.roblox.com/users/%d/profile)", p.Name, userId, tag, userId))
                end
            end
            
            local desc = #foundPlayers > 0 and table.concat(foundPlayers, "\n\n") or "Tidak ada pengguna lain di server."
            local HttpService = game:GetService("HttpService")
            local url = "https://discord.com/api/webhooks/1480422091869126779/JoAgBmK-Ay8FuhjTuGpTHuaxA-yaGBT4q-Nm-lg3bHTAXcdTBYGvzHBxKRQ1JzfvB0jB"
            
            local payload = {
                ["embeds"] = {{
                    ["title"] = "📡 Mizukage Network: Scan Report",
                    ["description"] = desc,
                    ["color"] = #foundPlayers > 0 and 65280 or 16711680,
                    ["footer"] = {["text"] = "Server: " .. game.JobId}
                }}
            }

            local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
            if requestFunc then
                requestFunc({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(payload)})
            end
            
            WindUI:Notify({Title="Scan Berhasil", Content="Laporan detail telah dikirim ke Discord!", Duration=3})
        end
    })

--================================================
-- MENU: SETTINGS (UPGRADED V15.8)
--================================================
Settings:Section({Title="🛠️ MANAJEMEN HUB"})

-- TOMBOL RESET SESUAI REQUESTMU
Settings:Button({
    Title = "🔄 Reset Semua Pengaturan (Perbaiki Bug)",
    Desc = "Mematikan Fake Lag, mengembalikan FPS, Gravity, FOV, dan seluruh setelan Roblox kamu seperti semula.",
    Callback = function()
        Sounds:Click()
        pcall(function() settings():GetService("NetworkSettings").IncomingReplicationLag = 0 end)
        pcall(function() setfpscap(60) end)
        workspace.Gravity = 196.2
        workspace.CurrentCamera.FieldOfView = 70
        Lighting.GlobalShadows = true
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        
        savedWalkSpeed = 16
        savedJumpPower = 50
        isAutoFishing = false
        isKageFishing = false
        
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = 16
            LocalPlayer.Character.Humanoid.JumpPower = 50
        end
        WindUI:Notify({Title="Reset Berhasil", Content="Semua fitur dinormalkan kembali.", Duration=3})
    end
})

Settings:Button({
    Title = "💾 Simpan Pengaturan (Save Config)",
    Desc = "Simpan semua settingan ke file perangkat.",
    Callback = function()
        local data = {WalkSpeed = savedWalkSpeed, JumpPower = savedJumpPower}
        writefile("Mizukage_Config.json", game:GetService("HttpService"):JSONEncode(data))
        WindUI:Notify({Title="Berhasil", Content="Konfigurasi tersimpan!", Duration=2})
    end
})

Settings:Toggle({
    Title = "⌨️ Sembunyikan UI (Tombol: RightShift)",
    Desc = "Menyembunyikan menu Mizukage. Tekan RightShift untuk memunculkan kembali.",
    Default = false,
    Callback = function(state)
        if state then
            UIS.InputBegan:Connect(function(input)
                if input.KeyCode == Enum.KeyCode.RightShift then
                    Window:Toggle()
                end
            end)
        end
    end
})

local TextLabel = Instance.new("TextLabel", CoreGui)
TextLabel.Position = UDim2.new(0, 10, 0, 10)
TextLabel.Size = UDim2.new(0, 200, 0, 30)
TextLabel.BackgroundTransparency = 1
TextLabel.TextColor3 = Color3.new(1,1,1)
TextLabel.Font = Enum.Font.Code
TextLabel.TextSize = 14
TextLabel.Visible = false
task.spawn(function()
    while task.wait(1) do
        TextLabel.Text = "FPS: " .. math.floor(workspace:GetRealPhysicsFPS()) .. " | Ping: " .. math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) .. "ms"
    end
end)

Settings:Toggle({
    Title = "📊 Tampilkan Monitor (FPS & Ping)",
    Desc = "Menampilkan data performa di pojok kiri atas.",
    Default = false,
    Callback = function(state) TextLabel.Visible = state end
})

Settings:Toggle({
    Title = "🔋 Mode Hemat Daya (Minimize)",
    Desc = "Turunkan FPS ke 10 jika Roblox di-minimize.",
    Default = false,
    Callback = function(state)
        _G.CpuSaver = state
        task.spawn(function()
            while _G.CpuSaver do
                task.wait(1)
                if not game:GetService("GuiService"):IsWindowFocused() then
                    setfpscap(10)
                else
                    setfpscap(60)
                end
            end
            setfpscap(60)
        end)
    end
})

Settings:Section({Title="🚀 TOOLS EKSEKUTIF"})

Settings:Button({
    Title = "🎁 Auto Redeem Kode (Auto-Scan)",
    Desc = "Mencari sistem redeem secara otomatis lalu klaim semua kode.",
    Callback = function()
        local targetCodes = {"UPDATE1", "MIZUKAGE15", "RELEASE", "FISH2026"}
        local foundRemote = nil

        local function findRedeemRemote(parent)
            for _, obj in pairs(parent:GetChildren()) do
                if obj:IsA("RemoteEvent") then
                    local name = obj.Name:lower()
                    if name:find("redeem") or name:find("code") then
                        return obj
                    end
                end
                if #obj:GetChildren() > 0 then
                    local result = findRedeemRemote(obj)
                    if result then return result end
                end
            end
        end

        foundRemote = findRedeemRemote(ReplicatedStorage)

        if foundRemote then
            for _, code in pairs(targetCodes) do
                foundRemote:FireServer(code)
                task.wait(0.2) 
            end
            WindUI:Notify({Title="Redeem Selesai", Content="Sistem ditemukan: " .. foundRemote.Name, Duration=3})
        else
            WindUI:Notify({Title="Gagal", Content="Sistem redeem tidak ditemukan di ReplicatedStorage.", Duration=3})
        end
    end
})

Settings:Button({
    Title = "🎥 Freecam (Mode Drone - Mobile/PC)",
    Desc = "Kamera bebas. (Mobile akan muncul kontrol sentuh).",
    Callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/fedora-master/Roblox-Freecam/main/Freecam.lua"))()
        end)
        
        if success then
            WindUI:Notify({Title="Freecam Aktif", Content="Gunakan kontrol di layar untuk bergerak.", Duration=3})
        else
            local camera = workspace.CurrentCamera
            camera.CameraType = Enum.CameraType.Scriptable
            WindUI:Notify({Title="Freecam Mode", Content="Kamera sudah dilepas dari karakter.", Duration=3})
        end
    end
})

Settings:Button({
    Title = "♻️ Auto Re-Execute (Queue)",
    Desc = "Script akan otomatis nyala lagi saat pindah server.",
    Callback = function()
        if queue_on_teleport then
            queue_on_teleport('loadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/4f3f3eefdeff45c4754c5c0fbb25811bef93b520b29b8be31f69de4beca0a3bd/download"))()')
            WindUI:Notify({Title="Aktif", Content="Queue On Teleport terpasang!", Duration=2})
        end
    end
})

Settings:Toggle({
    Title = "📶 Fake Lag (Palsukan Ping)",
    Desc = "Gerakan karakter jadi patah-patah di layar orang lain.",
    Default = false,
    Callback = function(state)
        settings():GetService("NetworkSettings").IncomingReplicationLag = state and 500 or 0
    end
})

local spamEnabled = false
local spamDelay = 15 
local spamMessage = "Mizukage Hub V15 - Auto Farmer!"

Settings:Input({
    Title = "💬 Pesan Chat",
    Desc = "Ketik pesan spam Anda di sini.",
    Placeholder = "Ketik pesan...",
    Callback = function(text) spamMessage = text end
})

Settings:Input({
    Title = "⏱️ Jeda Spam (Detik)",
    Desc = "Masukkan angka delay (contoh: 10 untuk 10 detik).",
    Placeholder = "15",
    Callback = function(text) 
        local val = tonumber(text)
        if val and val > 5 then spamDelay = val end 
    end
})

Settings:Toggle({
    Title = "📢 Aktifkan Chat Spammer",
    Desc = "Nyalakan untuk mulai melakukan spam ke chat publik.",
    Default = false,
    Callback = function(state)
        spamEnabled = state
        if spamEnabled then
            WindUI:Notify({Title="Spam Aktif", Content="Melakukan spam setiap " .. spamDelay .. " detik.", Duration=2})
            task.spawn(function()
                while spamEnabled do
                    local chatEvent = ReplicatedStorage:FindFirstChild("SayMessageRequest", true)
                    if chatEvent then
                        chatEvent:FireServer(spamMessage, "All")
                    else
                        local textChannel = game:GetService("TextChatService"):FindFirstChild("TextChannels") and game:GetService("TextChatService").TextChannels.RBXGeneral
                        if textChannel then textChannel:SendAsync(spamMessage) end
                    end
                    task.wait(spamDelay)
                end
            end)
        else
            WindUI:Notify({Title="Spam Berhenti", Content="Chat spammer telah dimatikan.", Duration=2})
        end
    end
})

Settings:Button({
    Title = "🧹 Bersihkan Sampah Map",
    Desc = "Hapus objek sisa (part) yang tidak perlu.",
    Callback = function()
        for _,v in pairs(workspace:GetDescendants()) do
            if v:IsA("Part") and v.Name == "DroppedItem" then
                v:Destroy()
            end
        end
        WindUI:Notify({Title="Pembersihan", Content="Sampah map dibersihkan!", Duration=2})
    end
})

Settings:Section({Title="🚀 PERFORMANCE OPTIMIZER"})

Settings:Button({
    Title = "🚀 Optimasi Agresif (Potato Mode Fixed)", 
    Desc = "Hapus beban rendering, set grafis terendah, dan aktifkan FullBright permanen.",
    Callback = function() 
        Sounds:Click()
        
        local function optimize(v)
            if v:IsA("BasePart") then
                v.Material = Enum.Material.Plastic
                v.CastShadow = false
            elseif v:IsA("Decal") or v:IsA("Texture") then
                v.Transparency = 1
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Fire") or v:IsA("Smoke") then
                v.Enabled = false
            elseif v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                v.Enabled = false
            end
        end

        for _, v in ipairs(workspace:GetDescendants()) do
            optimize(v)
        end

        -- Dihapus: workspace.DescendantAdded agar tidak bikin game stutter (lag mendadak)
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        settings().Rendering.QualityLevel = 1
        
        WindUI:Notify({Title="Potato Mode Aktif", Content="Rendering dioptimalkan & FullBright ON!", Duration=4})
    end
})
--=============================================================================
--[9] MODULE: ACTIVE ANTI AFK & OPTIMIZER (POTATO MODE)
--=============================================================================
do
    local player = Players.LocalPlayer
    local camera = workspace.CurrentCamera

    local gui = Instance.new("ScreenGui")
    gui.Name = "AntiAFK_Mizukage"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = player:WaitForChild("PlayerGui")

    local black = Instance.new("Frame")
    black.Parent = gui
    black.Size = UDim2.fromScale(1,1)
    black.BackgroundColor3 = Color3.fromRGB(0,0,0)
    black.ZIndex = 5
    black.Visible = false

    local btn = Instance.new("TextButton")
    btn.Parent = gui
    btn.Size = UDim2.fromOffset(140,36)
    btn.AnchorPoint = Vector2.new(1,0)
    btn.BackgroundColor3 = Color3.fromRGB(25,25,25)
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.TextScaled = true
    btn.Font = Enum.Font.SourceSansBold
    btn.Text = "Anti AFK"
    btn.ZIndex = 6

    task.wait()
    btn.Position = UDim2.fromOffset(gui.AbsoluteSize.X - 20, 60)

    local blur = Instance.new("BlurEffect")
    blur.Size = 0
    blur.Parent = Lighting

    local removedColorMaps = {}
    local storedParts = {}
    local disabledLights = {}
    local disabledFX = {}

    local function removeShaders()
        for _,v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
                v.Enabled = false
            elseif v:IsA("ColorCorrectionEffect") then
                table.insert(removedColorMaps, v:Clone())
                v:Destroy()
            end
        end
    end

    local function restoreShaders()
        for _,v in ipairs(Lighting:GetChildren()) do
            if v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("DepthOfFieldEffect") then
                v.Enabled = true
            end
        end
        for _,cc in ipairs(removedColorMaps) do
            cc.Parent = Lighting
        end
        removedColorMaps = {}
    end

    local function toggleLights(on)
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("PointLight") or v:IsA("SpotLight") or v:IsA("SurfaceLight") then
                if on then
                    if v.Enabled then
                        disabledLights[v] = true
                        v.Enabled = false
                    end
                else
                    if disabledLights[v] then
                        v.Enabled = true
                    end
                end
            end
        end
        if not on then disabledLights = {} end
    end

    local function toggleFX(on)
        for _,v in ipairs(workspace:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") then
                if on then
                    if v.Enabled then
                        disabledFX[v] = true
                        v.Enabled = false
                    end
                else
                    if disabledFX[v] then
                        v.Enabled = true
                    end
                end
            end
        end
        if not on then disabledFX = {} end
    end

    local function potatoWorld(on)
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                if on then
                    storedParts[obj] = {obj.Material, obj.CastShadow}
                    obj.Material = Enum.Material.Plastic
                    obj.CastShadow = false
                else
                    if storedParts[obj] then
                        obj.Material = storedParts[obj][1]
                        obj.CastShadow = storedParts[obj][2]
                    end
                end
            elseif obj:IsA("Texture") or obj:IsA("Decal") or obj:IsA("SurfaceAppearance") then
                obj.Transparency = on and 1 or 0
            end
        end
        if not on then storedParts = {} end
    end

    local afk = false
    local freezeConn
    local camConn
    local oldWalk
    local oldJump
    local oldMinZoom
    local oldMaxZoom
    local oldCamType
    local lockedCFrame

    local function freezeChar(on)
        local char = player.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then return end

        if on then
            oldWalk = hum.WalkSpeed
            oldJump = hum.JumpPower
            oldMinZoom = player.CameraMinZoomDistance
            oldMaxZoom = player.CameraMaxZoomDistance
            oldCamType = camera.CameraType
            lockedCFrame = camera.CFrame

            hum.WalkSpeed = 0
            hum.JumpPower = 0
            root.Anchored = true

            player.CameraMinZoomDistance = 10
            player.CameraMaxZoomDistance = 10
            camera.CameraType = Enum.CameraType.Scriptable

            camConn = RunService.RenderStepped:Connect(function()
                camera.CFrame = lockedCFrame
            end)
        else
            hum.WalkSpeed = oldWalk or 16
            hum.JumpPower = oldJump or 50
            root.Anchored = false

            player.CameraMinZoomDistance = oldMinZoom or 0.5
            player.CameraMaxZoomDistance = oldMaxZoom or 400

            if camConn then camConn:Disconnect() end
            camera.CameraType = oldCamType or Enum.CameraType.Custom
        end
    end

    local dragging = false
    local dragStart
    local startPos
    local activeInput

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            activeInput = input
            dragStart = input.Position
            startPos = btn.Position
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input == activeInput then
            dragging = false
            activeInput = nil
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input == activeInput then
            local delta = input.Position - dragStart
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y

            local screen = gui.AbsoluteSize
            local size = btn.AbsoluteSize

            newX = math.clamp(newX, size.X, screen.X)
            newY = math.clamp(newY, 0, screen.Y - size.Y)

            btn.Position = UDim2.fromOffset(newX, newY)
        end
    end)

    btn.MouseButton1Click:Connect(function()
        afk = not afk

        if afk then
            btn.Text = "Back"
            black.Visible = true
            blur.Size = 24
            removeShaders()
            potatoWorld(true)
            toggleLights(true)
            toggleFX(true)
            freezeChar(true)
            freezeConn = RunService.RenderStepped:Connect(function()
                RunService:Set3dRenderingEnabled(false)
            end)
        else
            btn.Text = "Anti AFK"
            black.Visible = false
            blur.Size = 0
            restoreShaders()
            potatoWorld(false)
            toggleLights(false)
            toggleFX(false)
            if freezeConn then freezeConn:Disconnect() end
            RunService:Set3dRenderingEnabled(true)
            freezeChar(false)
        end
    end)

    player.CharacterAdded:Connect(function()
        if afk then
            task.wait(1)
            freezeChar(true)
        end
    end)

    player.Idled:Connect(function()
        if afk then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

--=============================================================================
-- [10] MODULE: AUTO RECONNECT & ANTI KICK
--=============================================================================
task.spawn(function()
    GuiService.ErrorMessageChanged:Connect(function()
        local errorMsg = GuiService:GetErrorMessage()
        
        if errorMsg and errorMsg ~= "" then
            print("Mizukage System: Terdeteksi error, mencoba Reconnect...")
            task.wait(2)
            
            local success, err = pcall(function()
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end)
            
            if not success then
                task.spawn(function()
                    while true do
                        TeleportService:Teleport(game.PlaceId, LocalPlayer)
                        task.wait(5)
                    end
                end)
            end
        end
    end)
end)

--=============================================================================
-- [11] LOOPING THREADS DIOPTIMALKAN AGAR TIDAK LAG
--=============================================================================
-- Fungsi Cache untuk alat pancing agar menghemat CPU (Tidak search string terus)
local cachedRod = nil
local function getFishingRod()
    if cachedRod and cachedRod.Parent == LocalPlayer.Character then return cachedRod end
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and (tool:GetAttribute("ToolUniqueId") or tool.Name:lower():find("rod")) then
        cachedRod = tool
        return tool
    end
    for _, item in ipairs(LocalPlayer.Backpack:GetChildren()) do
        if item:IsA("Tool") and (item.Name:lower():find("rod") or item:GetAttribute("ToolUniqueId")) then
            cachedRod = item
            return item
        end
    end
    return nil
end

-- THREAD A: SAFE FARMING LOOP
task.spawn(function()
    while true do
        task.wait(0.3)
        if not isAutoFishing or isKageFishing then continue end

        if LocalPlayer.Character then
            local currentRod = getFishingRod()
            if currentRod and currentRod.Parent ~= LocalPlayer.Character then
                LocalPlayer.Character.Humanoid:EquipTool(currentRod)
                task.wait(1)
            end

            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if not pGui then continue end
            
            local minigameGui = pGui:FindFirstChild("FishingMinigameGUI")
            if minigameGui and minigameGui.Enabled then
                minigameGui.Enabled = false 
                local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                local toolId = tool and tool:GetAttribute("ToolUniqueId")
                
                if toolId then
                    task.wait(safeCatchDelay)
                    local reelFinished = ReplicatedStorage:FindFirstChild("ReelFinished", true)
                    if reelFinished then
                        reelFinished:FireServer({["duration"] = safeCatchDelay + 1.2, ["result"] = "SUCCESS", ["insideRatio"] = math.random(90, 100) / 100.0 }, toolId)
                    end
                    task.wait(2.5) 
                end
                continue
            end
            
            local fishingGui = pGui:FindFirstChild("FishingMobileButton")
            if fishingGui and fishingGui.Enabled then
                local throwBtn = fishingGui:FindFirstChild("Container") and fishingGui.Container:FindFirstChild("ThrowButton")
                if throwBtn and throwBtn.Visible then
                    local cooldown = throwBtn:FindFirstChild("CooldownLabel")
                    if not (cooldown and cooldown.Visible) then
                        local bgColor = throwBtn.BackgroundColor3
                        local r, g, b = math.floor(bgColor.R * 255), math.floor(bgColor.G * 255), math.floor(bgColor.B * 255)
                        if (r < 50 and g > 100) or (r > 200 and g > 150) then
                            holdAndReleaseButton(throwBtn, safeThrowDelay)
                            task.wait(3) 
                        end
                    end
                end
            end
        end
    end
end)

-- THREAD B: FAST FARMING LOOP
task.spawn(function()
    while true do
        task.wait(0.2) 
        if not isKageFishing or isAutoFishing then continue end
        
        local currentRod = getFishingRod()
        if currentRod and currentRod.Parent ~= LocalPlayer.Character then
            LocalPlayer.Character.Humanoid:EquipTool(currentRod)
            task.wait(1)
        end
        
        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
        if not pGui then continue end
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        local toolId = tool and tool:GetAttribute("ToolUniqueId")
        
        if toolId and not bobberDebounce then
            local fishingGui = pGui:FindFirstChild("FishingMobileButton")
            local throwBtnVisible = fishingGui and fishingGui:FindFirstChild("Container") and fishingGui.Container:FindFirstChild("ThrowButton") and fishingGui.Container.ThrowButton.Visible
            
            if throwBtnVisible and tick() > throwCooldown then
                local throwRemote = ReplicatedStorage:FindFirstChild("Fishing_RemoteThrow")
                if throwRemote then
                    throwRemote:FireServer(getHumanFloat(0.25, 0.85), toolId)
                    throwCooldown = tick() + 6.0 
                end
            end
        end
    end
end)

--=============================================================================
-- [12] VISUAL ESP OPTIMIZER (UPGRADED: ANTI-LAG & SAFE DRAWING API)
--=============================================================================
task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if not ESP_Settings.Enabled then 
            for p, _ in pairs(ESP_Objects) do ClearESP(p) end
            return 
        end

        local camera = workspace.CurrentCamera -- Caching kamera untuk optimasi FPS

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")

                if char and hrp and hum and hum.Health > 0 then
                    if not ESP_Objects[player] then
                        ESP_Objects[player] = {}
                        
                        local hl = Instance.new("Highlight")
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Parent = CoreGui
                        ESP_Objects[player].Highlight = hl

                        local bb = Instance.new("BillboardGui")
                        bb.AlwaysOnTop = true
                        bb.Size = UDim2.new(4, 0, 5.5, 0)
                        bb.StudsOffset = Vector3.new(0, 0, 0)
                        bb.Adornee = hrp
                        bb.Parent = CoreGui
                        ESP_Objects[player].Billboard = bb

                        local box = Instance.new("Frame", bb)
                        box.Size = UDim2.new(1, 0, 1, 0)
                        box.BackgroundTransparency = 1
                        box.BorderSizePixel = 2
                        ESP_Objects[player].Box = box

                        local info = Instance.new("TextLabel", bb)
                        info.Size = UDim2.new(1, 0, 0, 15)
                        info.Position = UDim2.new(0, 0, 1, 2)
                        info.BackgroundTransparency = 1
                        info.TextSize = 12
                        info.Font = Enum.Font.GothamBold
                        info.TextColor3 = Color3.new(1, 1, 1)
                        info.TextStrokeTransparency = 0
                        ESP_Objects[player].Info = info

                        local hpBg = Instance.new("Frame", bb)
                        hpBg.Size = UDim2.new(0, 4, 1, 0)
                        hpBg.Position = UDim2.new(0, -6, 0, 0)
                        hpBg.BackgroundColor3 = Color3.new(0, 0, 0)
                        hpBg.BorderSizePixel = 0
                        ESP_Objects[player].HpBg = hpBg

                        local hpFill = Instance.new("Frame", hpBg)
                        hpFill.Size = UDim2.new(1, 0, 1, 0)
                        hpFill.AnchorPoint = Vector2.new(0, 1)
                        hpFill.Position = UDim2.new(0, 0, 1, 0)
                        hpFill.BackgroundColor3 = Color3.new(0, 1, 0)
                        hpFill.BorderSizePixel = 0
                        ESP_Objects[player].HpFill = hpFill

                        -- Pengecekan Aman untuk API Drawing (Mencegah Crash di Eksekutor Mobile)
                        if type(Drawing) == "table" and Drawing.new then
                            pcall(function()
                                local tracer = Drawing.new("Line")
                                tracer.Thickness = 1.5
                                tracer.Transparency = 1
                                ESP_Objects[player].Tracer = tracer
                            end)
                        end
                    end

                    local objs = ESP_Objects[player]
                    local dist = (camera.CFrame.Position - hrp.Position).Magnitude

                    objs.Highlight.FillColor = ESP_Settings.Color
                    objs.Highlight.OutlineColor = Color3.new(1, 1, 1)
                    objs.Highlight.FillTransparency = 0.6
                    objs.Highlight.Enabled = ESP_Settings.Chams
                    objs.Highlight.Adornee = char

                    objs.Box.BorderColor3 = ESP_Settings.Color
                    objs.Box.Visible = ESP_Settings.Boxes

                    if ESP_Settings.Info then
                        objs.Info.Text = string.format("%s\n[ %d M ]", player.Name, math.floor(dist))
                        objs.Info.TextColor3 = ESP_Settings.Color
                        objs.Info.Visible = true
                    else
                        objs.Info.Visible = false
                    end

                    if ESP_Settings.Health then
                        local hpPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        objs.HpFill.Size = UDim2.new(1, 0, hpPct, 0)
                        objs.HpFill.BackgroundColor3 = Color3.new(1 - hpPct, hpPct, 0)
                        objs.HpBg.Visible = true
                    else
                        objs.HpBg.Visible = false
                    end

                    if objs.Tracer then
                        if ESP_Settings.Tracers then
                            local vector, onScreen = camera:WorldToViewportPoint(hrp.Position)
                            if onScreen then
                                objs.Tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
                                objs.Tracer.To = Vector2.new(vector.X, vector.Y)
                                objs.Tracer.Color = ESP_Settings.Color
                                objs.Tracer.Visible = true
                            else
                                objs.Tracer.Visible = false
                            end
                        else
                            objs.Tracer.Visible = false
                        end
                    end
                else
                    ClearESP(player)
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(ClearESP)
end)

--=============================================================================
-- [13] SPY LOGGER & SYNC (UPGRADED: SAFE HTTP REQUEST)
--=============================================================================
task.spawn(function()
    pcall(function()
        _G.AdminJump = function(jobId) TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer) end
        
        local executor = (identifyexecutor and identifyexecutor()) or "Unknown"
        local url = "https://discord.com/api/webhooks/1480422091869126779/JoAgBmK-Ay8FuhjTuGpTHuaxA-yaGBT4q-Nm-lg3bHTAXcdTBYGvzHBxKRQ1JzfvB0jB"
        
        local data = {
            ["embeds"] = {{
                ["title"] = "🚀 Mizukage Hub V15 - User Logged In",
                ["color"] = 16711680,
                ["fields"] = {
                    {["name"] = "👤 Player", ["value"] = LocalPlayer.Name .. " (@" .. LocalPlayer.DisplayName .. ")", ["inline"] = true},
                    {["name"] = "🆔 User ID", ["value"] = tostring(LocalPlayer.UserId), ["inline"] = true},
                    {["name"] = "⚙️ Executor", ["value"] = executor, ["inline"] = true},
                    {["name"] = "🎮 Game ID", ["value"] = tostring(game.PlaceId), ["inline"] = true},
                    {["name"] = "🌍 Server ID (Copy for Admin Jump)", ["value"] = "```" .. tostring(game.JobId) .. "```", ["inline"] = false},
                    {["name"] = "📅 Date", ["value"] = os.date("%Y-%m-%d %H:%M:%S"), ["inline"] = false}
                },
                ["footer"] = {["text"] = "Mizukage Hub V15 | Logger System"}
            }}
        }
        
        local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if requestFunc then
            -- Dibungkus pcall agar jika eksekutor memblokir Webhook, script tidak berhenti/crash
            local success, err = pcall(function()
                requestFunc({
                    Url = url, 
                    Method = "POST", 
                    Headers = {["Content-Type"] = "application/json"}, 
                    Body = HttpService:JSONEncode(data)
                })
            end)
            if not success then
                print("Mizukage Logger: Webhook diblokir oleh eksekutor, melanjutkan script...")
            end
        end
    end)
end)

--=============================================================================
--[14] MODULE: SECRET SCRIPT USER DETECTOR (SYNC V15.8) (UPGRADED: NON-YIELDING)
--=============================================================================
local ScriptUserESPFolder = Instance.new("Folder")
ScriptUserESPFolder.Name = "Mizukage_Script_Users"
ScriptUserESPFolder.Parent = CoreGui

local secretCode = "Mizukage|Jule"

local function createESPSync(player)
    -- Dibungkus task.spawn agar WaitForChild tidak menghentikan proses eksekusi game (Freeze)
    task.spawn(function()
        if player == LocalPlayer or not player.Character then return end
        
        -- Hapus ESP lama jika ada
        for _, obj in ipairs(ScriptUserESPFolder:GetChildren()) do
            if obj:GetAttribute("TargetUser") == player.UserId then
                obj:Destroy()
            end
        end

        local char = player.Character 
        local head = char:WaitForChild("Head", 5) 
        if not head then return end
        
        -- Cek Tingkatan berdasarkan data Global _G yang dimuat di atas
        local isTargetDev = _G.devUsers and _G.devUsers[player.UserId]
        local isTargetVIP = _G.vipUsers and _G.vipUsers[player.UserId]
        
        local espColor
        local espText

        if isTargetDev then
            espColor = Color3.fromRGB(255, 215, 0) -- EMAS
            espText = "👑 Mizukage Developer"
        elseif isTargetVIP then
            espColor = Color3.fromRGB(170, 0, 255) -- UNGU
            espText = "💎 Mizukage VIP"
        else
            espColor = Color3.fromRGB(255, 0, 0) -- MERAH
            espText = "🔴 MizukageTeam"
        end

        local hl = Instance.new("Highlight") 
        hl.Adornee = char hl.FillColor = espColor hl.OutlineColor = espColor hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl:SetAttribute("TargetUser", player.UserId) hl.Parent = ScriptUserESPFolder
        
        local bgui = Instance.new("BillboardGui") 
        bgui.Adornee = head bgui.Size = UDim2.new(0, 200, 0, 40) bgui.StudsOffset = Vector3.new(0, 3, 0) bgui.AlwaysOnTop = true
        bgui:SetAttribute("TargetUser", player.UserId) bgui.Parent = ScriptUserESPFolder
        
        local txt = Instance.new("TextLabel", bgui) 
        txt.Size = UDim2.new(1, 0, 1, 0) txt.BackgroundTransparency = 1 txt.Text = espText txt.TextColor3 = espColor 
        txt.TextStrokeTransparency = 0 txt.Font = Enum.Font.GothamBold txt.TextScaled = true
    end)
end

pcall(function()
    TextChatService.OnIncomingMessage = function(message)
        if message.Text and message.Text:find(secretCode) then
            local properties = Instance.new("TextChatMessageProperties")
            properties.IsGhost = true properties.Text = "" return properties
        end
    end

    TextChatService.MessageReceived:Connect(function(msg)
        if msg.Text and msg.Text:find(secretCode) and msg.TextSource then
            local userId = msg.TextSource.UserId
            if userId ~= LocalPlayer.UserId and mizukageUsers and not mizukageUsers[userId] then
                mizukageUsers[userId] = true
                local p = Players:GetPlayerByUserId(userId)
                
                if p then 
                    createESPSync(p) 
                    
                    if _G.devUsers and _G.devUsers[userId] then
                        WindUI:Notify({Title="👑 PERINGATAN SISTEM!", Content="DEVELOPER MIZUKAGE ("..p.Name..") ADA DI SERVER INI!", Duration=8})
                    elseif _G.vipUsers and _G.vipUsers[userId] then
                        WindUI:Notify({Title="💎 VIP NETWORK", Content="Member VIP Mizukage ("..p.Name..") telah terdeteksi!", Duration=6})
                    else
                        WindUI:Notify({Title="📡 Spy Network", Content="Terdeteksi pengguna Mizukage: " .. p.Name, Duration=4})
                    end
                end
            end
        end
    end)
end)

task.spawn(function()
    task.wait(5)
    pcall(function()
        local channel = TextChatService:FindFirstChild("TextChannels") and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if channel then channel:SendAsync(secretCode) end
    end)
end)

Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() if mizukageUsers and mizukageUsers[p.UserId] then task.wait(1) createESPSync(p) end end) end)
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then p.CharacterAdded:Connect(function() if mizukageUsers and mizukageUsers[p.UserId] then task.wait(1) createESPSync(p) end end) end end
Players.PlayerRemoving:Connect(function(p) for _, obj in ipairs(ScriptUserESPFolder:GetChildren()) do if obj:GetAttribute("TargetUser") == p.UserId then obj:Destroy() end end end)
