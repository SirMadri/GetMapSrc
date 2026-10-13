-- dumped by https://github.com/SirMadri/GetMapSrc
-- decompiled by https://lua.expert/
-- Name: CoinHUD
-- ClassName: LocalScript
-- Path: Players.SirMadri.PlayerScripts.CoinHUD

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnCoinCollected = ReplicatedStorage.Events.OnCoinCollected

OnCoinCollected.Event:Connect(function(amount)
	print("coins collected:", amount)
end)
