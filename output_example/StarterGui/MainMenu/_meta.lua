return {
	name = "MainMenu",
	class_name = "ScreenGui",

	properties = {
		enabled = true,
		reset_on_spawn = false,
		z_index_behavior = "Global",
	},

	references = {
		parent = "StarterGui",
	},

	statistics = {
		descendants = 8,
		children = 2,
	},

	children = {
		"Background",
		"Title",
	},
}
