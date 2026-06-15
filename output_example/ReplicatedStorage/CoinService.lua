-- dumped by https://github.com/SirMadri/GetMapSrc
-- decompiled by https://lua.expert/

local CoinService = {}

local player_coins = {}

function CoinService.add(player, amount)
	player_coins[player] = (player_coins[player] or 0) + amount
	return player_coins[player]
end

function CoinService.get(player)
	return player_coins[player] or 0
end

function CoinService.reset(player)
	player_coins[player] = 0
end

game.Players.PlayerRemoving:Connect(function(player)
	player_coins[player] = nil
end)

return CoinService
