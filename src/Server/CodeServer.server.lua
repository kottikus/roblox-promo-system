local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BadgeService = game:GetService("BadgeService")

local cfg = require(ServerStorage:WaitForChild("CodesConfig"))
local items = ServerStorage:FindFirstChild("Items")
local db = DataStoreService:GetDataStore("PromoCodes_v1")

local COOLDOWN = 1.5      -- sec between attempts
local MAX_LEN = 32
local MAX_RAW_LEN = 128   -- before trimming
local STRIKES_MAX = 5
local LOCKOUT = 30        -- sec
local TRIES = 3
local RETRY_BACKOFF = 2   -- sec, times attempt
local WRITE_GAP = 6.5     -- datastore per-key write throttle is ~6s
local SHUTDOWN_WAIT = 25  -- sec, engine kills us at 30

type Profile = { redeemed: { [string]: boolean }, dirty: boolean, saving: boolean }

local rf = ReplicatedStorage:FindFirstChild("RedeemCodeRF")
if not rf then
	rf = Instance.new("RemoteFunction")
	rf.Name = "RedeemCodeRF"
	rf.Parent = ReplicatedStorage
end

local profiles: { [Player]: Profile } = {}
local loading = {}
local lastAttempt, strikes, lockUntil = {}, {}, {}
local pending, closing = 0, false

for code in cfg.Codes do
	if code ~= code:upper() then
		warn("[codes] config key must be uppercase: " .. code)
	end
end

local function keyFor(userId: number)
	return "u_" .. userId
end

local function loadProfile(plr: Player): Profile?
	local key = keyFor(plr.UserId)
	for i = 1, TRIES do
		local ok, data = pcall(db.GetAsync, db, key)
		if ok then
			local redeemed = if type(data) == "table" and type(data.redeemed) == "table" then data.redeemed else {}
			return { redeemed = redeemed, dirty = false, saving = false }
		end
		warn("[codes] load failed for", plr.Name, data)
		task.wait(i * RETRY_BACKOFF)
	end
	return nil
end

local function save(userId: number, redeemed): boolean
	local key = keyFor(userId)
	for i = 1, TRIES do
		-- merge, dont overwrite. other servers might have redeems too
		local ok, err = pcall(db.UpdateAsync, db, key, function(old)
			old = if type(old) == "table" then old else {}
			old.redeemed = if type(old.redeemed) == "table" then old.redeemed else {}
			for c in redeemed do
				old.redeemed[c] = true
			end
			return old
		end)
		if ok then return true end
		warn("[codes] save failed", userId, err)
		task.wait(i * RETRY_BACKOFF)
	end
	return false
end

local function flush(plr: Player)
	local p = profiles[plr]
	if not p or p.saving then return end
	p.saving = true
	pending += 1
	while p.dirty do
		p.dirty = false
		if not save(plr.UserId, p.redeemed) then
			p.dirty = true -- try again next redeem / on leave
			break
		end
		if p.dirty and not closing then
			task.wait(WRITE_GAP)
		end
	end
	pending -= 1
	p.saving = false
end

local function onJoin(plr: Player)
	if loading[plr] then return end
	loading[plr] = true
	local p = loadProfile(plr)
	loading[plr] = nil
	if p and plr.Parent then
		profiles[plr] = p
	end
end

-- validate every reward BEFORE granting any, so a code is never half given
local checks = {}

function checks.Currency(_plr, r)
	return type(r.Currency) == "string" and type(r.Amount) == "number"
end

function checks.Item(plr, r)
	local tool = items and items:FindFirstChild(tostring(r.Item))
	return tool ~= nil and tool:IsA("Tool")
		and plr:FindFirstChildOfClass("Backpack") ~= nil
		and plr:FindFirstChild("StarterGear") ~= nil
end

function checks.Boost(_plr, r)
	return type(r.Boost) == "string" and type(r.Multiplier) == "number" and type(r.Duration) == "number"
end

function checks.Badge(_plr, r)
	return type(r.BadgeId) == "number" and r.BadgeId > 0
end

local rewards = {}

function rewards.Currency(plr, r)
	-- demo fallback, delete when your real data system owns leaderstats
	-- (coins/gems arent saved here, just the redeemed list)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = plr
	end
	local stat = ls:FindFirstChild(r.Currency)
	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = r.Currency
		stat.Parent = ls
	end
	stat.Value += r.Amount
end

function rewards.Item(plr, r)
	local tool = items[r.Item]
	local bp = plr:FindFirstChildOfClass("Backpack")
	local gear = plr:FindFirstChild("StarterGear")
	local has = bp:FindFirstChild(tool.Name) or (plr.Character and plr.Character:FindFirstChild(tool.Name))
	if not has then
		tool:Clone().Parent = bp
	end
	if not gear:FindFirstChild(tool.Name) then
		tool:Clone().Parent = gear
	end
end

function rewards.Boost(plr, r)
	local key = r.Boost .. "Boost" -- XPBoost, CoinsBoost...
	local now = os.time()
	local endsAt = math.max(plr:GetAttribute(key .. "Ends") or 0, now) + r.Duration -- time stacks
	plr:SetAttribute(key, math.max(plr:GetAttribute(key) or 1, r.Multiplier))
	plr:SetAttribute(key .. "Ends", endsAt)
	task.delay(endsAt - now, function()
		-- only clear if nobody extended it meanwhile
		if plr.Parent and plr:GetAttribute(key .. "Ends") == endsAt then
			plr:SetAttribute(key, nil)
			plr:SetAttribute(key .. "Ends", nil)
		end
	end)
end

function rewards.Badge(plr, r)
	task.spawn(function() -- yields, keep it out of the redeem path
		local ok, err = pcall(BadgeService.AwardBadge, BadgeService, plr.UserId, r.BadgeId)
		if not ok then warn("[codes] badge failed", err) end
	end)
end

local function canGrant(plr: Player, code: string, entry): boolean
	if type(entry.Rewards) ~= "table" or #entry.Rewards == 0 then
		warn("[codes] no rewards on " .. code)
		return false
	end
	for _, r in entry.Rewards do
		local chk = checks[r.Type]
		if not chk or not chk(plr, r) then
			warn(("[codes] %s has a busted reward (%s)"):format(code, tostring(r.Type)))
			return false
		end
	end
	return true
end

local function bad(plr: Player)
	local n = (strikes[plr] or 0) + 1
	strikes[plr] = n
	if n >= STRIKES_MAX then
		strikes[plr] = nil
		lockUntil[plr] = os.clock() + LOCKOUT
	end
	return "Invalid", "That code isn't valid."
end

rf.OnServerInvoke = function(plr, raw)
	local now = os.clock()

	if (lockUntil[plr] or 0) > now then
		return "Cooldown", ("Too many bad tries. Wait %ds."):format(math.ceil(lockUntil[plr] - now))
	end
	if now - (lastAttempt[plr] or -math.huge) < COOLDOWN then
		return "Cooldown", "Slow down a sec..."
	end
	lastAttempt[plr] = now

	if type(raw) ~= "string" or #raw > MAX_RAW_LEN then return bad(plr) end
	local code = raw:match("^%s*(.-)%s*$"):upper()
	if #code == 0 or #code > MAX_LEN or code:find("[^%w_%-]") then return bad(plr) end

	local p = profiles[plr]
	if not p then
		task.spawn(onJoin, plr) -- first load may have failed, retry
		return "Error", "Still loading your data, try again."
	end

	local entry = cfg.Codes[code]
	if not entry or entry.Active == false then return bad(plr) end
	if entry.Expiration and os.time() >= entry.Expiration then
		return "Expired", "This code has expired."
	end
	if p.redeemed[code] then
		return "Already Redeemed", "You already used this code."
	end
	if not canGrant(plr, code, entry) then
		return "Error", "Couldn't apply this code right now."
	end

	-- no yields from here down, so no double redeem race
	p.redeemed[code] = true
	for _, r in entry.Rewards do
		rewards[r.Type](plr, r)
	end
	strikes[plr] = nil
	p.dirty = true
	task.spawn(flush, plr)

	return "Success", entry.SuccessMessage or "Code redeemed!"
end

Players.PlayerAdded:Connect(onJoin)
for _, plr in Players:GetPlayers() do
	task.spawn(onJoin, plr)
end

Players.PlayerRemoving:Connect(function(plr)
	local p = profiles[plr]
	if p and p.dirty then
		flush(plr)
	end
	profiles[plr] = nil
	lastAttempt[plr], strikes[plr], lockUntil[plr], loading[plr] = nil, nil, nil, nil
end)

game:BindToClose(function()
	closing = true
	for plr, p in profiles do
		if p.dirty then
			task.spawn(flush, plr)
		end
	end
	local t = os.clock()
	while pending > 0 and os.clock() - t < SHUTDOWN_WAIT do
		task.wait(0.1)
	end
end)