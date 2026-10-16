-- Never Give Up Mining : chaque joueur a son propre tunnel.
-- La profondeur du filon de diamants est secrète (elle reste côté serveur).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local S = Config.SlabDepth
local W = Config.TunnelWidth
local H = Config.TunnelHeight

-- Remotes ---------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function newRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local DigRemote = newRemote("Dig")
local UpgradeRemote = newRemote("Upgrade")
local GiveUpRemote = newRemote("GiveUp")
local NotifyRemote = newRemote("Notify")

-- Ambiance : grotte sombre
Lighting.ClockTime = 0
Lighting.Brightness = 0
Lighting.Ambient = Color3.fromRGB(12, 12, 18)
Lighting.OutdoorAmbient = Color3.fromRGB(12, 12, 18)

-- Données ---------------------------------------------------------------

local store = DataStoreService:GetDataStore("NeverGiveUpMining_v1")
local sessions = {} -- [Player] = session
local usedSlots = {}

local function randomDiamondDepth(rebirths)
	return math.random(Config.DiamondMin, Config.DiamondMax) + rebirths * Config.DiamondPerRebirth
end

local function setStat(player, name, value)
	player:SetAttribute(name, value)
end

local function notify(player, text, kind)
	NotifyRemote:FireClient(player, text, kind or "info")
end

-- Construction du tunnel ------------------------------------------------

local function makePart(parent, size, cf, color, material, name)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = name or "Part"
	p.Parent = parent
	return p
end

-- Sol, plafond et murs pour les blocs [first, last) (indices de profondeur).
local function buildSegment(s, first, last)
	local len = (last - first) * S
	if len <= 0 then
		return
	end
	local zc = -(first + last) * S / 2
	local tier = Config.RockTiers[math.clamp(math.floor(math.max(first, 0) / Config.BlocksPerTier) + 1, 1, #Config.RockTiers)]
	local base = s.origin
	local parent = s.lane
	makePart(parent, Vector3.new(W + 4, 2, len), base * CFrame.new(0, -1, zc), tier.Color, tier.Material, "Floor")
	makePart(parent, Vector3.new(W + 4, 2, len), base * CFrame.new(0, H + 1, zc), tier.Color, tier.Material, "Ceiling")
	makePart(parent, Vector3.new(2, H + 4, len), base * CFrame.new(-(W / 2 + 1), H / 2, zc), tier.Color, tier.Material, "WallL")
	makePart(parent, Vector3.new(2, H + 4, len), base * CFrame.new(W / 2 + 1, H / 2, zc), tier.Color, tier.Material, "WallR")
end

local function buildSlab(s, i)
	local tier = Config.RockTiers[math.clamp(math.floor(i / Config.BlocksPerTier) + 1, 1, #Config.RockTiers)]
	local slab = makePart(
		s.lane,
		Vector3.new(W, H, S),
		s.origin * CFrame.new(0, H / 2, -(i * S + S / 2)),
		tier.Color,
		tier.Material,
		"Slab"
	)
	local hp = Config.slabHealth(i)
	slab:SetAttribute("Health", hp)
	slab:SetAttribute("MaxHealth", hp)
	slab:SetAttribute("BaseColor", tier.Color)
	if i == s.diamondDepth then
		-- Le dernier bloc laisse filtrer une très faible lueur bleue...
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(120, 220, 255)
		light.Range = 14
		light.Brightness = 0.4
		light.Parent = slab
	end
	s.slabs[i] = slab
end

local function ensureBuilt(s, upTo)
	upTo = math.min(upTo, s.diamondDepth)
	while s.built <= upTo do
		local i = s.built
		if i >= s.segmentEnd then
			local last = math.min(i + Config.Chunk, s.diamondDepth + 1)
			buildSegment(s, i, last)
			s.segmentEnd = last
		end
		buildSlab(s, i)
		s.built += 1
	end
end

local function spawnCFrame(s)
	return s.origin * CFrame.new(0, 4, -(s.depth * S) + 8)
end

local function buildLane(s)
	s.lane = Instance.new("Folder")
	s.lane.Name = "Lane_" .. s.player.UserId
	s.lane.Parent = Workspace
	s.slabs = {}
	s.cavern = false
	s.claimed = false

	-- entrée (z de +16 à 0) fermée par un mur
	buildSegment(s, -4, 0)
	makePart(
		s.lane,
		Vector3.new(W + 4, H + 4, 2),
		s.origin * CFrame.new(0, H / 2, S * 4 + 1),
		Color3.fromRGB(60, 60, 60),
		Enum.Material.Slate,
		"BackWall"
	)
	-- tunnel déjà creusé si on reprend une partie
	if s.depth > 0 then
		buildSegment(s, 0, s.depth)
	end
	s.built = s.depth
	s.segmentEnd = s.depth
	ensureBuilt(s, s.depth + Config.LoadAhead)
end

local function teleport(s)
	local char = s.player.Character
	if char then
		char:PivotTo(spawnCFrame(s))
	end
end

local function resetLane(s)
	if s.lane then
		s.lane:Destroy()
	end
	s.depth = 0
	setStat(s.player, "Depth", 0)
	buildLane(s)
	teleport(s)
end

-- Caverne de diamants ---------------------------------------------------

local function buildCavern(s)
	local zStart = -((s.diamondDepth + 1) * S)
	local roomW, roomH, roomL = 70, 36, 70
	local parent = s.lane
	local rock = Color3.fromRGB(40, 45, 60)
	local base = s.origin
	local zc = zStart - roomL / 2

	makePart(parent, Vector3.new(roomW, 2, roomL), base * CFrame.new(0, -1, zc), rock, Enum.Material.Slate, "CavernFloor")
	makePart(parent, Vector3.new(roomW, 2, roomL), base * CFrame.new(0, roomH, zc), rock, Enum.Material.Slate, "CavernCeiling")
	makePart(parent, Vector3.new(2, roomH, roomL), base * CFrame.new(-roomW / 2, roomH / 2, zc), rock, Enum.Material.Slate, "CavernWallL")
	makePart(parent, Vector3.new(2, roomH, roomL), base * CFrame.new(roomW / 2, roomH / 2, zc), rock, Enum.Material.Slate, "CavernWallR")
	makePart(parent, Vector3.new(roomW, roomH, 2), base * CFrame.new(0, roomH / 2, zStart - roomL), rock, Enum.Material.Slate, "CavernBack")

	local diamondColor = Color3.fromRGB(120, 220, 255)
	local function diamond(size, pos)
		local rot = CFrame.Angles(math.rad(math.random(0, 90)), math.rad(math.random(0, 90)), math.rad(math.random(0, 90)))
		local d = makePart(parent, Vector3.new(size, size, size), base * CFrame.new(pos) * rot, diamondColor, Enum.Material.Neon, "Diamond")
		return d
	end

	for _ = 1, 160 do
		local side = math.random(1, 4)
		local x, y
		local z = zStart - math.random(2, roomL - 2)
		if side == 1 then
			x, y = -roomW / 2 + 2, math.random(2, roomH - 2)
		elseif side == 2 then
			x, y = roomW / 2 - 2, math.random(2, roomH - 2)
		elseif side == 3 then
			x, y = math.random(-roomW / 2 + 3, roomW / 2 - 3), 1
		else
			x, y = math.random(-roomW / 2 + 3, roomW / 2 - 3), roomH - 2
		end
		diamond(math.random(3, 7), Vector3.new(x, y, z))
	end

	local giant = diamond(10, Vector3.new(0, 8, zStart - roomL / 2))
	giant.Name = "GiantDiamond"
	local light = Instance.new("PointLight")
	light.Color = diamondColor
	light.Range = 60
	light.Brightness = 3
	light.Parent = giant

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Prendre le diamant"
	prompt.ObjectText = "Le filon de diamants"
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 14
	prompt.Parent = giant
	prompt.Triggered:Connect(function(who)
		if who ~= s.player or s.claimed then
			return
		end
		s.claimed = true
		local reward = Config.diamondReward(s.rebirths)
		s.coins += reward
		s.rebirths += 1
		s.diamondDepth = randomDiamondDepth(s.rebirths)
		setStat(who, "Coins", s.coins)
		setStat(who, "Rebirths", s.rebirths)
		notify(who, ("💎 +%d pièces ! Renaissance %d : le prochain filon est encore plus profond..."):format(reward, s.rebirths), "win")
		task.wait(3)
		if s.player.Parent then
			resetLane(s)
		end
	end)
end

-- Sauvegarde ------------------------------------------------------------

local function save(s)
	local data = {
		coins = s.coins,
		pickLevel = s.pickLevel,
		depth = s.cavern and 0 or s.depth,
		diamondDepth = s.diamondDepth,
		rebirths = s.rebirths,
		quits = s.quits,
	}
	local ok, err = pcall(function()
		store:SetAsync(tostring(s.player.UserId), data)
	end)
	if not ok then
		warn("Sauvegarde impossible : " .. tostring(err))
	end
end

local function load(player)
	local ok, data = pcall(function()
		return store:GetAsync(tostring(player.UserId))
	end)
	if not ok or type(data) ~= "table" then
		data = {}
	end
	return data
end

-- Joueurs ---------------------------------------------------------------

local function onCharacter(s, char)
	local root = char:WaitForChild("HumanoidRootPart")
	local lamp = Instance.new("PointLight")
	lamp.Range = 28
	lamp.Brightness = 2
	lamp.Color = Color3.fromRGB(255, 235, 200)
	lamp.Parent = root
	task.defer(function()
		if s.lane then
			char:PivotTo(spawnCFrame(s))
		end
	end)
end

local function onPlayerAdded(player)
	if sessions[player] then
		return
	end
	local data = load(player)

	local slot = 0
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true

	local rebirths = data.rebirths or 0
	local s = {
		player = player,
		slot = slot,
		origin = CFrame.new(slot * Config.LaneSpacing, Config.LaneHeight, 0),
		coins = data.coins or 0,
		pickLevel = data.pickLevel or 1,
		depth = data.depth or 0,
		diamondDepth = data.diamondDepth or randomDiamondDepth(rebirths),
		rebirths = rebirths,
		quits = data.quits or 0,
		lastSwing = 0,
	}
	if s.depth >= s.diamondDepth then
		s.depth = 0
	end
	sessions[player] = s

	setStat(player, "Coins", s.coins)
	setStat(player, "PickLevel", s.pickLevel)
	setStat(player, "Depth", s.depth)
	setStat(player, "Rebirths", s.rebirths)
	setStat(player, "Quits", s.quits)

	buildLane(s)

	player.CharacterAdded:Connect(function(char)
		onCharacter(s, char)
	end)
	if player.Character then
		onCharacter(s, player.Character)
	end
end

local function onPlayerRemoving(player)
	local s = sessions[player]
	if not s then
		return
	end
	save(s)
	usedSlots[s.slot] = nil
	if s.lane then
		s.lane:Destroy()
	end
	sessions[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

task.spawn(function()
	while true do
		task.wait(60)
		for _, s in pairs(sessions) do
			save(s)
		end
	end
end)

game:BindToClose(function()
	for _, s in pairs(sessions) do
		save(s)
	end
end)

-- Actions ---------------------------------------------------------------

local MILESTONES = {
	[25] = "Les mineurs qui abandonnent ne le savent jamais...",
	[50] = "Encore un coup de pioche.",
	[100] = "Cent blocs ! Tu es plus têtu que la roche.",
	[150] = "Tu entends comme un scintillement ?",
	[200] = "Ne t'arrête surtout pas maintenant.",
}

DigRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.cavern then
		return
	end
	local now = os.clock()
	if now - s.lastSwing < Config.SwingDelay * 0.8 then
		return
	end
	s.lastSwing = now

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local slab = s.slabs[s.depth]
	if not root or not slab then
		return
	end
	if (root.Position - slab.Position).Magnitude > Config.DigRange then
		return
	end

	local hp = slab:GetAttribute("Health") - Config.pickDamage(s.pickLevel)
	if hp > 0 then
		slab:SetAttribute("Health", hp)
		local ratio = hp / slab:GetAttribute("MaxHealth")
		slab.Color = slab:GetAttribute("BaseColor"):Lerp(Color3.new(0, 0, 0), (1 - ratio) * 0.5)
		return
	end

	-- bloc cassé
	local depth = s.depth
	slab:Destroy()
	s.slabs[depth] = nil
	s.depth += 1
	s.coins += Config.coinsPerSlab(depth, s.rebirths)
	setStat(player, "Depth", s.depth)
	setStat(player, "Coins", s.coins)

	if depth == s.diamondDepth then
		s.cavern = true
		buildCavern(s)
		notify(player, "💎💎💎 TU N'AS JAMAIS ABANDONNÉ ! 💎💎💎", "win")
	else
		ensureBuilt(s, s.depth + Config.LoadAhead)
		if MILESTONES[s.depth] then
			notify(player, MILESTONES[s.depth], "info")
		end
	end
end)

UpgradeRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.pickLevel >= Config.MaxPickLevel then
		return
	end
	local cost = Config.upgradeCost(s.pickLevel)
	if s.coins < cost then
		notify(player, "Pas assez de pièces.", "error")
		return
	end
	s.coins -= cost
	s.pickLevel += 1
	setStat(player, "Coins", s.coins)
	setStat(player, "PickLevel", s.pickLevel)
end)

GiveUpRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.cavern then
		return
	end
	local remaining = s.diamondDepth - s.depth
	s.quits += 1
	setStat(player, "Quits", s.quits)
	local msg
	if remaining <= 5 then
		msg = ("😭 Tu as abandonné à seulement %d bloc(s) des diamants..."):format(remaining + 1)
	elseif remaining <= 30 then
		msg = ("Tu étais à %d blocs du filon. Il t'attend toujours."):format(remaining + 1)
	else
		msg = "Tu as abandonné. Les diamants étaient encore loin... ou pas ? Tu ne le sauras jamais."
	end
	notify(player, msg, "quit")
	resetLane(s)
end)
