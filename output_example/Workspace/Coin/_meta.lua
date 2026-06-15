return {
	name = "Coin",
	class_name = "Part",

	properties = {
		anchored = true,
		can_collide = false,
		can_touch = true,
		can_query = true,
		transparency = 0,
		reflectance = 0,
		material = "Neon",
		color = {255, 215, 0},
		shape = "Ball",
		cast_shadow = false,
		massless = true,
		locked = false,
		size = { x = 2, y = 2, z = 2 },
		position = { x = 150, y = 10, z = 320 },
		orientation = { x = 0, y = 0, z = 0 },
	},

	attributes = {
		coin_value = 50,
		respawn_time = 30,
	},

	tags = {
		"Collectible",
		"Coin",
	},

	references = {
		parent = "Workspace.Coins",
	},

	statistics = {
		descendants = 3,
		children = 3,
	},

	children = {
		"ProximityPrompt",
		"Highlight",
		"BillboardGui",
	},
}
