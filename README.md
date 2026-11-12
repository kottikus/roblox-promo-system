# Roblox Promo Code System

A production-ready, highly secure, and modular promo code system for Roblox Studio, featuring robust DataStore handling, rate-limiting, and a modern UI.

> **⚠️ Important Note:** This system serves as an **example and a structural guideline** for writing clean game code. To integrate a promo code system into your own game, you must adapt it to match your specific game architecture, folder hierarchies, and data management systems.

---

## Features

- **Secure DataStore Management:** Utilizes `UpdateAsync` with smart merging to prevent data loss or overwrites across multiple game servers. Respects Roblox DataStore throttling limits (`WRITE_GAP`).
- **Anti-Exploit & Anti-Spam:** 
  - Server-side input sanitization and length validation.
  - Built-in strike system (`STRIKES_MAX`) that temporarily locks out spammers trying to brute-force codes.
  - Request cooldowns to prevent spamming.
- **Modular Reward Architecture:** Easily extensible reward types via config tables (`Currency`, `Item`, `Boost`, `Badge`):
  - **Currency:** Automatically integrates with leaderstats.
  - **Items:** Clones tools to Backpack and StarterGear with ownership checks.
  - **Boosts:** Stackable time-based player attributes with automatic expiration handling.
  - **Badges:** Asynchronous badge awarding to prevent lag on the redemption path.
- **Sleek Modern UI:** Fully code-generated user interface with smooth `TweenService` animations, custom scaling, sound effects, and error/success shaking feedback.

---

## Installation & Setup

1. Place **`CodeServer.lua`** inside `ServerScriptService`.
2. Place **`CodesConfig.lua`** inside `ServerStorage`.
3. Place **`CodeClient.lua`** (LocalScript) inside `StarterPlayerScripts` (or `StarterGui`).
4. Ensure you have an `Items` folder inside `ServerStorage` if you plan to use item-type rewards.

---

## Configuration (`CodesConfig.lua`)

Define your codes easily inside the configuration file:

```lua
cfg.Codes = {
	RELEASE2026 = {
		Active = true,
		SuccessMessage = "Welcome aboard! +2,500 Coins",
		Rewards = {
			{ Type = "Currency", Currency = "Coins", Amount = 2500 },
		},
	},
}
