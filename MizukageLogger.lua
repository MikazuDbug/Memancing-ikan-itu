return function(SecureURL, PlayerData, Config)
    -- ==============================
    -- SERVICES
    -- ==============================
    local HttpService = game:GetService("HttpService")
    local Players = game:GetService("Players")
    local DataStoreService = game:GetService("DataStoreService")

    -- ==============================
    -- VALIDATION
    -- ==============================
    if type(SecureURL) ~= "string" or SecureURL == "" then return end
    if type(PlayerData) ~= "table" then return end
    Config = Config or {}

    -- ==============================
    -- CONFIG
    -- ==============================
    local CFG = {
        Silent      = Config.Silent == true,
        Verbose     = Config.Verbose == true,
        Mobile      = Config.Mobile == true,
        Leaderboard = Config.Leaderboard ~= false,
        Absolute    = true,
        Cloud       = true,
        ShardSize   = tonumber(Config.ShardSize) or 1000, -- userId shard window
        RateLimit   = tonumber(Config.RateLimit) or 1.0,
        ExportHeat  = Config.ExportHeat ~= false,
    }

    -- ==============================
    -- DATASTORES (SHARDED)
    -- ==============================
    local function shardFor(uid)
        return math.floor(uid / CFG.ShardSize)
    end

    local HeatStore = DataStoreService:GetDataStore("MIZU_HEATMAP_V1")
    local LBStore   = DataStoreService:GetDataStore("MIZU_LEADERBOARD_V1")

    -- ==============================
    -- GLOBAL STATE
    -- ==============================
    _G.MIZU = _G.MIZU or {
        Session = { Count = 0, Weight = 0, Start = os.time(), LastSend = 0 },
        Heatmap = {},
        Nonce   = 0,
        Salt    = HttpService:GenerateGUID(false),
    }

    -- ==============================
    -- HELPERS
    -- ==============================
    local function safe(v, d) return (v ~= nil and v ~= "") and tostring(v) or d end
    local function clamp(x,a,b) return math.max(a, math.min(b, x)) end

    -- ==============================
    -- EXTRACT
    -- ==============================
    local lp = Players.LocalPlayer
    local uid = lp and lp.UserId or 0
    local FishName = safe(PlayerData.FishName, "Unknown Fish")
    local Tier     = safe(PlayerData.FishTier, "Common")
    local Weight   = tonumber(PlayerData.FishWeight) or 0
    local Zone     = safe(PlayerData.Zone, "Unknown-Zone")

    -- ==============================
    -- RATE LIMIT
    -- ==============================
    local now = os.clock()
    if (now - _G.MIZU.Session.LastSend) < CFG.RateLimit then
        if CFG.Silent then return end
    end
    _G.MIZU.Session.LastSend = now

    -- ==============================
    -- SESSION UPDATE
    -- ==============================
    _G.MIZU.Session.Count += 1
    _G.MIZU.Session.Weight += Weight

    -- ==============================
    -- HEATMAP (LOCAL + CLOUD)
    -- ==============================
    _G.MIZU.Heatmap[Zone] = (_G.MIZU.Heatmap[Zone] or 0) + Weight

    if CFG.ExportHeat then
        pcall(function()
            HeatStore:UpdateAsync("zone:"..Zone, function(old)
                old = old or 0
                return old + Weight
            end)
        end)
    end

    -- ==============================
    -- LEADERBOARD (PERSISTENT)
    -- ==============================
    if CFG.Leaderboard then
        local shard = shardFor(uid)
        local key = "shard:"..shard
        pcall(function()
            LBStore:UpdateAsync(key, function(old)
                old = old or {}
                old[uid] = (old[uid] or 0) + Weight
                return old
            end)
        end)
    end

    -- ==============================
    -- AUTO RARITY COLOR
    -- ==============================
    local RARITY_COLOR = {
        Common=0x95A5A6, Uncommon=0x2ECC71, Rare=0x3498DB,
        Epic=0x9B59B6, Legendary=0xF1C40F, Mythic=0xE74C3C
    }
    local EmbedColor = RARITY_COLOR[Tier] or 0x1ABC9C

    -- ==============================
    -- ANTI-ROLLBACK SIGNATURE
    -- ==============================
    _G.MIZU.Nonce += 1
    local window = math.floor(os.time()/30)
    local sigBase = table.concat({uid, game.PlaceId, Zone, window, _G.MIZU.Nonce, _G.MIZU.Salt},"|")
    local Signature = HttpService:GenerateGUID(false).."-"..string.sub(HttpService:JSONEncode(sigBase),2,12)

    -- ==============================
    -- PAYLOAD
    -- ==============================
    local uptime = os.time() - _G.MIZU.Session.Start
    local fields = {
        {
            name="🐟 Catch",
            value=string.format("%s [%s]\n⚖️ %.2f kg\n📍 %s",FishName,Tier,Weight,Zone),
            inline=not CFG.Mobile
        },
        {
            name="☁️ Cloud Session",
            value=string.format("🎣 %d | ⚖️ %.2f kg | ⏱️ %ds",_G.MIZU.Session.Count,_G.MIZU.Session.Weight,uptime),
            inline=false
        }
    }
    if CFG.Verbose then
        table.insert(fields,{name="🔐 Signature",value="`"..Signature.."`",inline=false})
    end

    local Payload = {
        username="Mizukage Sentinel ☁️",
        embeds={{ title="CLOUD ASCENSION LOG", color=EmbedColor, fields=fields,
            footer={text="Mizukage • Cloud Ascension"}, timestamp=DateTime.now():ToIsoDate() }}
    }

    -- ==============================
    -- SEND
    -- ==============================
    if not CFG.Silent then
        local request = http_request or request or syn and syn.request
        if request then
            pcall(function()
                request({
                    Url=SecureURL, Method="POST",
                    Headers={["Content-Type"]="application/json"},
                    Body=HttpService:JSONEncode(Payload)
                })
            end)
        end
    end
end
