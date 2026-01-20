--[[
    MIZUKAGE FISH DATABASE (UPDATED V5.1)
    Based on Game Source: Jan 20, 2026
]]

local FishDatabase = {
    Secret = {
        -- [ EXISTING ]
        {name = "Whale Shark", min = 550, max = 800},
        {name = "Paus Corda", min = 500, max = 750},
        {name = "King Monster", min = 500, max = 750},
        {name = "Hammer Shark", min = 500, max = 750},
        {name = "Jellyfish core", min = 500, max = 750},
        {name = "Voyage", min = 500, max = 750},
        {name = "Amber", min = 500, max = 750},
        {name = "Megalodon Core", min = 500, max = 750},
        {name = "Ciyup Carber", min = 500, max = 750},
        {name = "Cindera Fish", min = 700, max = 850},
        {name = "Kuzjuy Shark", min = 650, max = 750},
        {name = "Moster Kelelawar", min = 520, max = 700},
        {name = "Suytu Care", min = 510, max = 660},
        {name = "Leviathan Core", min = 520, max = 690},
        {name = "Joar Cusyu", min = 780, max = 870},
        {name = "Cype Darcogreen", min = 580, max = 690},
        {name = "Cype Darcopink", min = 580, max = 690},
        {name = "Cype Darcoyellow", min = 580, max = 690},
        {name = "Doplin Pink", min = 350, max = 450},
        {name = "Doplin Blue", min = 350, max = 450},
        
        -- [ NEW FROM LOGS - JAN 2026 ]
        {name = "Nagasa Putra", min = 720, max = 860},     -- NEW
        {name = "While Bloodmon", min = 520, max = 690},   -- NEW
        {name = "While BloodShack", min = 520, max = 690}, -- NEW
    },
    Mitos = {
        {name = "Amberjack", min = 30, max = 60},
        {name = "Granit", min = 50, max = 80},
        {name = "Magma", min = 50, max = 80},
        {name = "Angler Piranha", min = 50, max = 100},
        {name = "Sea Crocodile", min = 50, max = 100},
        {name = "Sand Tiger Shark", min = 70, max = 100},
        {name = "White Shark ", min = 70, max = 100}, -- Spasi di akhir sesuai game
    },
    Legendary = {
        {name = "Coelocanth", min = 30, max = 50},
        {name = "Opah", min = 30, max = 50},
        {name = "Reef Shark", min = 30, max = 50},
        {name = "Atol", min = 30, max = 50},
        {name = "Pijar", min = 30, max = 50},
        {name = "Empu", min = 30, max = 50},
        {name = "Blenny", min = 30, max = 50},
        {name = "Tontatta", min = 30, max = 50},
        {name = "Ulater Kadut", min = 30, max = 50},
        {name = "Wadas", min = 30, max = 50},
        {name = "Yellowtail Barracuda", min = 30, max = 50},
        {name = "Roster Fishs", min = 30, max = 50},
        {name = "Longbill Spearfish", min = 30, max = 50},
        {name = "Sting Ray", min = 30, max = 50},
        {name = "Isopod", min = 30, max = 50},
        {name = "Kurami", min = 60, max = 70},
        {name = "Kudasay", min = 60, max = 70},
        {name = "Gumi", min = 60, max = 70},
    },
    Rare = {
        {name = "Snapper", min = 20, max = 30},
        {name = "Tanjung", min = 12, max = 19},
        {name = "Ubun Ubun", min = 20, max = 30},
        {name = "Tephra", min = 20, max = 30},
        {name = "Ciup Cobat", min = 20, max = 30},
        {name = "Octopus", min = 20, max = 30},
        {name = "Grouper", min = 20, max = 30},
        {name = "Cadas", min = 20, max = 30},
        {name = "Selo", min = 20, max = 30},
        {name = "Wicca", min = 20, max = 30},
        {name = "Cobias", min = 20, max = 30},
        {name = "Salmon Fish", min = 30, max = 35},
        {name = "Cucup Cipung", min = 30, max = 35},
        {name = "Angle Fish", min = 30, max = 35},
        {name = "Red Snapper", min = 30, max = 35},
    },
    Common = {
        {name = "Kerapi", min = 5, max = 12},
        {name = "Tiger Muskellunge", min = 5, max = 12},
        {name = "Basalt", min = 5, max = 12},
        {name = "Mercu", min = 5, max = 12},
        {name = "Xuzuy Care", min = 5, max = 12},
        {name = "Kawah", min = 5, max = 12},
        {name = "Dumbo Octopus", min = 5, max = 12},
        {name = "Pompano", min = 5, max = 12},
        {name = "Saupe Fish", min = 5, max = 12},
        {name = "BlueFish", min = 5, max = 12},
        {name = "Bloom", min = 20, max = 25},
        {name = "Crab", min = 20, max = 25},
        {name = "Mas Fish", min = 20, max = 25},
        {name = "Mujaer", min = 20, max = 25},
        {name = "Salmon", min = 20, max = 25},
        {name = "Empa Fish", min = 20, max = 25},
    },
    -- [ BONUS: LIMITED FISH ]
    Limited = {
        {name = "Ston Luck", min = 60, max = 70}
    }
}

return FishDatabase
