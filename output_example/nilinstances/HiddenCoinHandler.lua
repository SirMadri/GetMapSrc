-- dumped by https://github.com/SirMadri/GetMapSrc
-- decompiled by https://lua.expert/

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectCoin = ReplicatedStorage:WaitForChild("CollectCoin")

CollectCoin.OnServerEvent:Connect(function(player, coin)
	if not coin or not coin.Parent then return end
	coin:Destroy()
	-- award coin to player
end)
