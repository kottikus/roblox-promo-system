-- keys UPPERCASE, server uppercases input
-- Expiration = unix ts, nil = never
-- Active = false turns a code off w/o deleting it
-- Rewards is a list, one code can give several things

return {
	Codes = {
		RELEASE2026 = {
			Active = true,
			SuccessMessage = "Welcome aboard! +2,500 Coins",
			Rewards = {
				{ Type = "Currency", Currency = "Coins", Amount = 2500 },
			},
		},

		GEMSTORM = {
			Active = true,
			Expiration = 1798761600, -- 2027-01-01 UTC
			SuccessMessage = "Gem storm! +100 Gems",
			Rewards = {
				{ Type = "Currency", Currency = "Gems", Amount = 100 },
			},
		},

		DOUBLEXP = {
			Active = true,
			SuccessMessage = "2x XP for 30 minutes!",
			Rewards = {
				{ Type = "Boost", Boost = "XP", Multiplier = 2, Duration = 1800 }, -- sec
			},
		},

		STARTERBLADE = {
			Active = true,
			SuccessMessage = "Starter Blade added to your backpack!",
			Rewards = {
				{ Type = "Item", Item = "StarterBlade" }, -- Tool inside ServerStorage.Items
			},
		},

		FOUNDER = {
			Active = true,
			SuccessMessage = "Founder badge + goodies unlocked!",
			Rewards = {
				{ Type = "Badge", BadgeId = 0 }, -- todo real badge id
				{ Type = "Currency", Currency = "Coins", Amount = 500 },
				{ Type = "Currency", Currency = "Gems", Amount = 25 },
			},
		},

		LAUNCHDAY = { -- expired on purpose, for testing the Expired path
			Active = true,
			Expiration = 1735689600, -- 2025-01-01
			Rewards = {
				{ Type = "Currency", Currency = "Coins", Amount = 1000 },
			},
		},
	},
}