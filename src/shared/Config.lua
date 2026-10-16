-- Réglages partagés client/serveur. Tout l'équilibrage du jeu est ici.
local Config = {}

-- Géométrie du tunnel (en studs)
Config.SlabDepth = 4 -- épaisseur d'un "bloc" de roche
Config.TunnelWidth = 12
Config.TunnelHeight = 8
Config.LaneSpacing = 100 -- distance entre les tunnels de deux joueurs
Config.LaneHeight = 500 -- altitude des tunnels (loin de la Baseplate)
Config.Chunk = 20 -- nombre de blocs générés d'un coup
Config.LoadAhead = 30 -- blocs générés devant le joueur

-- Progression
Config.DiamondMin = 150 -- profondeur mini du filon (en blocs)
Config.DiamondMax = 300
Config.DiamondPerRebirth = 50 -- le filon est plus profond à chaque renaissance
Config.SwingDelay = 0.25
Config.DigRange = 16
Config.MaxPickLevel = 100

Config.RockTiers = {
	{ Material = Enum.Material.Mud, Color = Color3.fromRGB(110, 80, 55) },
	{ Material = Enum.Material.Rock, Color = Color3.fromRGB(120, 105, 90) },
	{ Material = Enum.Material.Slate, Color = Color3.fromRGB(85, 85, 95) },
	{ Material = Enum.Material.Basalt, Color = Color3.fromRGB(55, 55, 62) },
	{ Material = Enum.Material.Granite, Color = Color3.fromRGB(100, 70, 75) },
}
Config.BlocksPerTier = 60

function Config.slabHealth(depth)
	return 10 + depth * 2
end

function Config.pickDamage(level)
	return math.floor(4 * level ^ 1.4)
end

function Config.upgradeCost(level)
	return math.floor(20 * 1.6 ^ (level - 1))
end

function Config.coinsPerSlab(depth, rebirths)
	return (1 + math.floor(depth / 10)) * (1 + rebirths)
end

function Config.diamondReward(rebirths)
	return 1000 * (1 + rebirths)
end

return Config
