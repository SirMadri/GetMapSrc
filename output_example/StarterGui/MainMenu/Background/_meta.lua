return {
	name = "Background",
	class_name = "Frame",

	properties = {
		background_color3 = {15, 15, 25},
		background_transparency = 0.2,
		border_size_pixel = 0,
		position = { x = { scale = 0, offset = 0 }, y = { scale = 0, offset = 0 } },
		size = { x = { scale = 1, offset = 0 }, y = { scale = 1, offset = 0 } },
		z_index = 1,
		clips_descendants = true,
	},

	references = {
		parent = "StarterGui.MainMenu",
	},

	statistics = {
		descendants = 4,
		children = 2,
	},

	children = {
		"PlayButton",
		"QuitButton",
	},
}
