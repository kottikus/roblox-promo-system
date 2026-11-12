local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")

local plr = Players.LocalPlayer
local rf = RS:WaitForChild("RedeemCodeRF")

local MAX_LEN = 32
local STATUS_HOLD = 4 -- sec
local SHAKE_STEP = 0.04
local SHAKE_OFFSETS = { -10, 9, -7, 5, -3, 0 }

local WHITE = Color3.new(1, 1, 1)
local COL = {
	bg = Color3.fromRGB(24, 26, 32),
	input = Color3.fromRGB(16, 18, 23),
	stroke = Color3.fromRGB(52, 56, 70),
	sub = Color3.fromRGB(140, 146, 162),
	hint = Color3.fromRGB(100, 106, 122),
	accent = Color3.fromRGB(124, 92, 255),
	ok = Color3.fromRGB(88, 230, 140),
	err = Color3.fromRGB(255, 99, 99),
	warn = Color3.fromRGB(255, 190, 80),
}
local ACCENT = ColorSequence.new(Color3.fromRGB(124, 92, 255), Color3.fromRGB(255, 84, 168))

local function new(class, props, parent)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end

local function round(o, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function stroke(o, col, th)
	return new("UIStroke", {
		Color = col, Thickness = th,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, -- contextual strokes the text too
	}, o)
end

local function tw(obj, t, props, style, dir)
	local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local gui = new("ScreenGui", {
	Name = "CodesGui", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10,
}, plr:WaitForChild("PlayerGui"))

-- swap ids if u got custom sfx
local function mkSound(id, vol, speed)
	return new("Sound", { SoundId = id, Volume = vol, PlaybackSpeed = speed }, gui)
end
local SND = {
	click = mkSound("rbxasset://sounds/button.wav", 0.4, 1),
	ok = mkSound("rbxasset://sounds/electronicpingshort.wav", 0.8, 1.25),
	err = mkSound("rbxasset://sounds/switch.wav", 0.8, 0.5),
}

local function juicy(btn, sc, hov)
	btn.MouseEnter:Connect(function() tw(sc, 0.15, { Scale = hov }) end)
	btn.MouseLeave:Connect(function() tw(sc, 0.15, { Scale = 1 }) end)
	btn.MouseButton1Down:Connect(function() tw(sc, 0.08, { Scale = 0.92 }) end)
	btn.MouseButton1Up:Connect(function()
		tw(sc, 0.15, { Scale = UIS.MouseEnabled and hov or 1 }, Enum.EasingStyle.Back)
	end)
end

local toggle = new("TextButton", {
	Name = "Toggle", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0),
	Size = UDim2.fromOffset(54, 54), BackgroundColor3 = COL.bg, AutoButtonColor = false,
	Text = "🎁", TextSize = 28, Font = Enum.Font.GothamBold, TextColor3 = WHITE, ZIndex = 1,
}, gui)
round(toggle, 16)
stroke(toggle, COL.stroke, 1.5)
local toggleScale = new("UIScale", {}, toggle)
juicy(toggle, toggleScale, 1.1)

local dim = new("TextButton", {
	Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 2,
}, gui)

local holder = new("Frame", {
	Name = "Holder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(0.92, 0, 0, 250), BackgroundTransparency = 1, Visible = false, ZIndex = 3,
}, gui)
new("UISizeConstraint", { MaxSize = Vector2.new(380, 250) }, holder)
local popScale = new("UIScale", { Scale = 0 }, holder)

for i = 1, 3 do -- poor mans soft shadow
	local sh = new("Frame", {
		Position = UDim2.new(0, -i * 5, 0, 6 - i * 2),
		Size = UDim2.new(1, i * 10, 1, i * 8),
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.82, ZIndex = 0,
	}, holder)
	round(sh, 14 + i * 4)
end

local win = new("Frame", {
	Name = "Window", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.bg, ZIndex = 1,
}, holder)
round(win, 16)
stroke(win, COL.stroke, 1.5)
new("UIGradient", {
	Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 205)), Rotation = 90,
}, win)

local accent = new("Frame", {
	Position = UDim2.new(0, 24, 0, 0), Size = UDim2.new(1, -48, 0, 3), BackgroundColor3 = WHITE,
}, win)
round(accent, 2)
new("UIGradient", { Color = ACCENT }, accent)

new("TextLabel", {
	Position = UDim2.fromOffset(22, 18), Size = UDim2.fromOffset(200, 26), BackgroundTransparency = 1,
	Text = "CODES", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = WHITE,
	TextXAlignment = Enum.TextXAlignment.Left,
}, win)
new("TextLabel", {
	Position = UDim2.fromOffset(22, 44), Size = UDim2.new(1, -90, 0, 18), BackgroundTransparency = 1,
	Text = "Redeem codes for free rewards", Font = Enum.Font.GothamMedium, TextSize = 13,
	TextColor3 = COL.sub, TextXAlignment = Enum.TextXAlignment.Left,
}, win)

local close = new("TextButton", {
	Name = "Close", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(32, 32), BackgroundColor3 = Color3.fromRGB(38, 41, 50),
	AutoButtonColor = false, Text = "X", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = COL.sub,
}, win)
round(close, 8)
local closeScale = new("UIScale", {}, close)
juicy(close, closeScale, 1.1)

local BOX_POS = UDim2.new(0, 20, 0, 84)
local box = new("TextBox", {
	Name = "Input", Position = BOX_POS, Size = UDim2.new(1, -40, 0, 48), BackgroundColor3 = COL.input,
	Text = "", PlaceholderText = "Enter code here...", PlaceholderColor3 = COL.hint,
	TextColor3 = WHITE, Font = Enum.Font.GothamBold, TextSize = 17, ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Center,
}, win)
round(box, 10)
local boxStroke = stroke(box, COL.stroke, 1.5)

local status = new("TextLabel", {
	Name = "Status", Position = UDim2.new(0, 20, 0, 140), Size = UDim2.new(1, -40, 0, 24),
	BackgroundTransparency = 1, Text = "", TextTransparency = 1, Font = Enum.Font.GothamBold,
	TextSize = 14, TextWrapped = true, TextColor3 = WHITE,
}, win)
local statusScale = new("UIScale", {}, status)

-- gradient on the button, label is a child so the text isnt tinted
local redeem = new("TextButton", {
	Name = "Redeem", Position = UDim2.new(0, 20, 0, 176), Size = UDim2.new(1, -40, 0, 50),
	BackgroundColor3 = WHITE, AutoButtonColor = false, Text = "",
}, win)
round(redeem, 12)
new("UIGradient", { Color = ACCENT }, redeem)
local redeemLabel = new("TextLabel", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "REDEEM",
	Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = WHITE,
}, redeem)
local redeemScale = new("UIScale", {}, redeem)
juicy(redeem, redeemScale, 1.03)

local statusTick, shakeTick = 0, 0

local function showStatus(text, col, bounce)
	statusTick += 1
	local mine = statusTick
	status.Text = text
	status.TextColor3 = col
	status.TextTransparency = 1
	statusScale.Scale = bounce and 0.4 or 0.9
	tw(status, 0.2, { TextTransparency = 0 })
	tw(statusScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(STATUS_HOLD, function()
		if mine == statusTick then
			tw(status, 0.4, { TextTransparency = 1 })
		end
	end)
end

local function shake()
	shakeTick += 1
	local mine = shakeTick
	task.spawn(function()
		for _, off in SHAKE_OFFSETS do
			if mine ~= shakeTick then return end
			tw(box, SHAKE_STEP, { Position = BOX_POS + UDim2.fromOffset(off, 0) })
			task.wait(SHAKE_STEP)
		end
	end)
end

local function flash(col)
	boxStroke.Color = col
	tw(boxStroke, 0.7, { Color = COL.stroke })
end

local busy = false

local function setLoading(on)
	redeemLabel.Text = on and "..." or "REDEEM"
	tw(redeem, 0.15, { BackgroundTransparency = on and 0.45 or 0 })
	redeem.Active = not on
end

local STYLE = {
	Success = { col = COL.ok, bounce = true },
	Invalid = { col = COL.err, shake = true },
	["Already Redeemed"] = { col = COL.err, shake = true },
	Expired = { col = COL.err, shake = true },
	Cooldown = { col = COL.warn },
	Error = { col = COL.warn },
}

local isOpen, moving = false, false

local function submit()
	if busy then return end
	local code = box.Text:match("^%s*(.-)%s*$")
	if code == "" then
		showStatus("Type a code first!", COL.warn)
		return
	end

	busy = true
	setLoading(true)
	local ok, res, msg = pcall(rf.InvokeServer, rf, code)
	setLoading(false)
	busy = false

	if not ok then
		SND.err:Play()
		showStatus("Something went wrong, try again.", COL.warn)
		return
	end

	local st = STYLE[res] or STYLE.Error
	showStatus(msg or res, st.col, st.bounce)

	if res == "Success" then
		SND.ok:Play()
		box.Text = ""
		flash(COL.ok)
		task.spawn(function()
			tw(popScale, 0.1, { Scale = 1.04 }).Completed:Wait()
			if not isOpen then return end -- closed during the pop
			tw(popScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	elseif st.shake then
		SND.err:Play()
		flash(COL.err)
		shake()
	else
		SND.err:Play()
	end
end

local function setOpen(state)
	if moving or state == isOpen then return end
	moving = true
	isOpen = state
	if state then
		holder.Visible = true
		dim.Visible = true
		tw(dim, 0.25, { BackgroundTransparency = 0.55 })
		tw(popScale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out).Completed:Wait()
	else
		box:ReleaseFocus()
		tw(dim, 0.25, { BackgroundTransparency = 1 })
		tw(popScale, 0.28, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		holder.Visible = false
		dim.Visible = false
		status.TextTransparency = 1
	end
	moving = false
end

box:GetPropertyChangedSignal("Text"):Connect(function()
	if #box.Text > MAX_LEN then
		box.Text = box.Text:sub(1, MAX_LEN)
	end
end)
box.Focused:Connect(function() tw(boxStroke, 0.15, { Color = COL.accent }) end)
box.FocusLost:Connect(function(enter)
	tw(boxStroke, 0.15, { Color = COL.stroke })
	if enter then submit() end
end)

redeem.Activated:Connect(function()
	SND.click:Play()
	submit()
end)
toggle.Activated:Connect(function()
	SND.click:Play()
	setOpen(not isOpen)
end)
close.Activated:Connect(function()
	SND.click:Play()
	setOpen(false)
end)
dim.Activated:Connect(function() setOpen(false) end)