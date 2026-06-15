return {
	name = "SirMadri",
	class_name = "Model",

	properties = {
		archivable = true,
		primary_part = "HumanoidRootPart",
		world_pivot = { position = { x = 0, y = 5, z = 0 }, orientation = { x = 0, y = 90, z = 0 } },
	},

	attributes = {
		is_loaded = true,
		team = "Red",
	},

	tags = {
		"PlayerCharacter",
		"Entity",
	},

	references = {
		parent = "Workspace.Characters",
	},

	statistics = {
		descendants = 37,
		children = 8,
	},

	children = {
		"Humanoid",
		"HumanoidRootPart",
		"Head",
		"Torso",
		"Left Arm",
		"Right Arm",
		"Left Leg",
		"Right Leg",
	},
}
