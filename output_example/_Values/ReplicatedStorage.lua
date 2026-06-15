-- GetMapSrc | Value Objects
-- service: "ReplicatedStorage"
-- count: 5

return {
	["Config/MaxPlayers"] = { class_name = "IntValue", value = 20 },
	["Config/GameVersion"] = { class_name = "StringValue", value = "1.4.2" },
	["Config/RespawnTime"] = { class_name = "NumberValue", value = 5.5 },
	["Flags/EnableNewMap"] = { class_name = "BoolValue", value = true },
	["Flags/MaintenanceMode"] = { class_name = "BoolValue", value = false },
}
