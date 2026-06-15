-- dumped by https://github.com/SirMadri/GetMapSrc
-- decompiled by https://lua.expert/

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local CollectCoin = ReplicatedStorage:WaitForChild("CollectCoin")

local collecting = {}

local function on_coin_touched(coin, hit)
	if collecting[coin] then return end
	local character = player.Character
	if not character or hit.Parent ~= character then return end
	collecting[coin] = true
	CollectCoin:FireServer(coin)
	task.delay(30, function()
		collecting[coin] = nil
	end)
end

workspace.Coins.ChildAdded:Connect(function(coin)
	coin.Touched:Connect(function(hit)
		on_coin_touched(coin, hit)
	end)
end)

for _, coin in ipairs(workspace.Coins:GetChildren()) do
	coin.Touched:Connect(function(hit)
		on_coin_touched(coin, hit)
	end)
end
