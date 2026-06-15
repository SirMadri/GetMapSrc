return {
	name = "PlayButton",
	class_name = "TextButton",

	properties = {
		background_color3 = {80, 200, 120},
		background_transparency = 0,
		border_size_pixel = 0,
		position = { x = { scale = 0.5, offset = -100 }, y = { scale = 0.6, offset = 0 } },
		size = { x = { scale = 0, offset = 200 }, y = { scale = 0, offset = 50 } },
		anchor_point = { x = 0.5, y = 0.5 },
		z_index = 2,
		text = "Play",
		text_color3 = {255, 255, 255},
		text_size = 24,
		font = "GothamBold",
	},

	references = {
		parent = "StarterGui.MainMenu.Background",
	},

	statistics = {
		descendants = 0,
		children = 0,
	},
}
