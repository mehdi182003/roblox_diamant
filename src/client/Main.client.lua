local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local DigRemote = remotes:WaitForChild("Dig")
local UpgradeRemote = remotes:WaitForChild("Upgrade")
local GiveUpRemote = remotes:WaitForChild("GiveUp")
local NotifyRemote = remotes:WaitForChild("Notify")

-- Interface -------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "MiningGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, text, size, pos)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos or UDim2.new()
	l.Text = text
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0.5
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 230, 0, 130)
panel.Position = UDim2.new(0, 12, 0, 12)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
panel.BackgroundTransparency = 0.3
panel.Parent = gui
Instance.new("UICorner", panel)

local coinsL = label(panel, "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 6))
local depthL = label(panel, "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 38))
local pickL = label(panel, "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 70))
local rebirthL = label(panel, "", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 98))

local function button(text, color, size, pos)
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.Parent = gui
	Instance.new("UICorner", b)
	return b
end

local upgradeB = button("", Color3.fromRGB(60, 140, 70), UDim2.new(0, 300, 0, 50), UDim2.new(0.5, -150, 1, -70))
local giveUpB = button("Abandonner 😔", Color3.fromRGB(150, 50, 50), UDim2.new(0, 170, 0, 40), UDim2.new(1, -182, 1, -52))

local toast = label(gui, "", UDim2.new(0.8, 0, 0, 60), UDim2.new(0.1, 0, 0.12, 0))
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextTransparency = 1
toast.TextStrokeTransparency = 1

local function refresh()
	local level = player:GetAttribute("PickLevel") or 1
	coinsL.Text = "🪙 Pièces : " .. (player:GetAttribute("Coins") or 0)
	depthL.Text = "⛏ Profondeur : " .. (player:GetAttribute("Depth") or 0) .. " blocs"
	pickL.Text = "Pioche niv. " .. level .. " (" .. Config.pickDamage(level) .. " dégâts)"
	rebirthL.Text = "💎 Renaissances : " .. (player:GetAttribute("Rebirths") or 0)
	if level >= Config.MaxPickLevel then
		upgradeB.Text = "Pioche au maximum !"
	else
		upgradeB.Text = ("Améliorer la pioche — %d 🪙"):format(Config.upgradeCost(level))
	end
end

for _, name in ipairs({ "Coins", "Depth", "PickLevel", "Rebirths" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

local toastId = 0
local COLORS = {
	info = Color3.new(1, 1, 1),
	error = Color3.fromRGB(255, 120, 120),
	quit = Color3.fromRGB(255, 180, 120),
	win = Color3.fromRGB(120, 220, 255),
}

NotifyRemote.OnClientEvent:Connect(function(text, kind)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = COLORS[kind] or COLORS.info
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.5
	task.delay(4, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end)

upgradeB.Activated:Connect(function()
	UpgradeRemote:FireServer()
end)
giveUpB.Activated:Connect(function()
	GiveUpRemote:FireServer()
end)

-- Minage : maintenir le clic (ou le doigt) pour creuser -------------------

local holding = false

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = false
	end
end)

task.spawn(function()
	while true do
		if holding then
			DigRemote:FireServer()
		end
		task.wait(Config.SwingDelay)
	end
end)
