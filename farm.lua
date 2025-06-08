local ReGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/Upbolt/Hydroxide/master/GuiLibrary.lua"))()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Garden = require(game.ReplicatedStorage.Modules.Garden)
local Crops = require(game.ReplicatedStorage.Modules.Crops)
local GameInfo = require(game.ReplicatedStorage.Modules.GameInfo)
local Network = require(game.ReplicatedStorage.Modules.Network)

local GardenPlots = Garden.GetPlots()
local Backpack = LocalPlayer.Backpack
local ShecklesCount = LocalPlayer:WaitForChild("Data"):WaitForChild("Sheckles")

-- Helper functions
local function GetInvCrops()
	local crops = {}
	for _, v in pairs(Backpack:GetChildren()) do
		if Crops[v.Name] then
			table.insert(crops, v)
		end
	end
	return crops
end

local function GetOwnedSeeds()
	local seeds = {}
	for _, v in pairs(LocalPlayer.Data:GetChildren()) do
		if string.find(v.Name, "Seed") and v.Value > 0 then
			seeds[v.Name] = v.Value
		end
	end
	return seeds
end

-- Auto Walk Logic
local AutoWalk = false
task.spawn(function()
	while true do
		task.wait(2.5)
		if AutoWalk then
			for _, plot in pairs(GardenPlots) do
				if plot.PlotOwner.Value == LocalPlayer then
					LocalPlayer.Character:PivotTo(plot:WaitForChild("Hitbox").CFrame)
					break
				end
			end
		end
	end
end)

-- Auto Plant Logic
local function AutoPlantLoop()
	for seedName, amount in pairs(GetOwnedSeeds()) do
		for _, plot in pairs(GardenPlots) do
			if plot.PlotOwner.Value == LocalPlayer and not plot:FindFirstChild("Crop") then
				Network:Invoke("Garden", "PlantSeed", seedName, plot)
			end
		end
	end
end

-- Auto Harvest Logic
local function AutoHarvestLoop()
	for _, plot in pairs(GardenPlots) do
		if plot.PlotOwner.Value == LocalPlayer and plot:FindFirstChild("Crop") then
			if plot.Crop:FindFirstChild("ReadyToHarvest") then
				Network:Invoke("Garden", "Harvest", plot)
			end
		end
	end
end

-- Auto Sell Logic
local function AutoSellLoop()
	for _, crop in pairs(GetInvCrops()) do
		Network:Invoke("Garden", "SellCrop", crop.Name, crop)
	end
end

-- UI Setup
local function CreateWindow()
	local Window = ReGui:Window({
		Title = `🌱 {GameInfo.Name} | 👤 {LocalPlayer.DisplayName or LocalPlayer.Name}`,
		Theme = "GardenTheme",
		Size = UDim2.fromOffset(360, 260)
	})
	return Window
end

local Window = CreateWindow()

-- Info Panel
local InfoNode = Window:TreeNode({Title = "📊 Info Pemain"})
InfoNode:Label({Text = `🪙 Sheckles: {ShecklesCount.Value}`})
InfoNode:Label({Text = `👤 Player: {LocalPlayer.DisplayName or LocalPlayer.Name}`})
InfoNode:Label({Text = `🎒 Crop: {#GetInvCrops()} item`})
InfoNode:Label({Text = `🌾 Benih: {table.getn(GetOwnedSeeds())} jenis`})
Window:Separator()

-- Auto-Walk Panel
local WallNode = Window:TreeNode({Title = "🚶 Auto Jalan ke Plot"})
local AutoWalkStatusLabel = WallNode:Label({Text = "Status: 🚫 Tidak aktif"})
WallNode:Checkbox({
	Value = false,
	Label = "✅ Aktifkan Auto-Walk",
	Callback = function(_, val)
		AutoWalk = val
		AutoWalkStatusLabel:SetText("Status: " .. (val and "✅ Aktif" or "🚫 Tidak aktif"))
	end
})
Window:Separator()

-- Plant Panel
local PlantNode = Window:TreeNode({Title = "🌱 Auto Tanam"})
PlantNode:Button({
	Text = "🌾 Tanam semua benih sekarang",
	Callback = AutoPlantLoop,
})
Window:Separator()

-- Harvest Panel
local HarvestNode = Window:TreeNode({Title = "🌾 Auto Panen"})
HarvestNode:Button({
	Text = "✂️ Panen semua yang siap",
	Callback = AutoHarvestLoop,
})
Window:Separator()

-- Sell Panel
local SellNode = Window:TreeNode({Title = "💰 Auto Jual"})
SellNode:Button({
	Text = "🧺 Jual semua hasil panen",
	Callback = AutoSellLoop,
})
