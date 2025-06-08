--[[
    @author depso (depthso)
    @description Grow a Garden auto-farm script - IMPROVED UI VERSION
    https://www.roblox.com/games/126884695634066
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Leaderstats = LocalPlayer.leaderstats
local Backpack = LocalPlayer.Backpack
local PlayerGui = LocalPlayer.PlayerGui

local ShecklesCount = Leaderstats.Sheckles
local GameInfo = MarketplaceService:GetProductInfo(game.PlaceId)

--// ReGui
local ReGui = loadstring(game:HttpGet('https://raw.githubusercontent.com/depthso/Dear-ReGui/refs/heads/main/ReGui.lua'))()
local PrefabsId = "rbxassetid://" .. ReGui.PrefabsId

--// Folders
local GameEvents = ReplicatedStorage.GameEvents
local Farms = workspace.Farm

--// Improved Color Scheme
local Accent = {
    -- Primary Garden Colors
    DarkGreen = Color3.fromRGB(34, 139, 34),      -- Forest Green
    Green = Color3.fromRGB(50, 205, 50),          -- Lime Green
    LightGreen = Color3.fromRGB(144, 238, 144),   -- Light Green
    
    -- Earth Tones
    DarkBrown = Color3.fromRGB(101, 67, 33),      -- Saddle Brown
    Brown = Color3.fromRGB(139, 69, 19),          -- Saddle Brown
    LightBrown = Color3.fromRGB(205, 133, 63),    -- Peru
    
    -- Accent Colors
    Gold = Color3.fromRGB(255, 215, 0),           -- Gold
    Orange = Color3.fromRGB(255, 140, 0),         -- Dark Orange
    
    -- UI Colors
    Background = Color3.fromRGB(47, 79, 79),      -- Dark Slate Gray
    Surface = Color3.fromRGB(105, 105, 105),      -- Dim Gray
    Text = Color3.fromRGB(245, 245, 220),         -- Beige
}

--// Enhanced ReGui configuration
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})

ReGui:DefineTheme("ModernGardenTheme", {
	-- Window
	WindowBg = Accent.Background,
	WindowBgAlpha = 0.95,
	
	-- Title Bar
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
	TitleText = Accent.Text,
	
	-- Frame
	FrameBg = Accent.Surface,
	FrameBgHovered = Accent.LightGreen,
	FrameBgActive = Accent.Green,
	
	-- Headers
	CollapsingHeaderBg = Accent.DarkBrown,
	CollapsingHeaderBgHovered = Accent.Brown,
	CollapsingHeaderText = Accent.Text,
	
	-- Buttons
	ButtonsBg = Accent.Green,
	ButtonsBgHovered = Accent.LightGreen,
	ButtonsBgActive = Accent.DarkGreen,
	ButtonsText = Accent.Text,
	
	-- Checkboxes & Sliders
	CheckMark = Accent.Gold,
	CheckMarkBg = Accent.DarkBrown,
	SliderGrab = Accent.Orange,
	SliderGrabActive = Accent.Gold,
	
	-- Misc
	ResizeGrab = Accent.Brown,
	Separator = Accent.LightBrown,
	Text = Accent.Text,
	TextDisabled = Color3.fromRGB(128, 128, 128),
})

--// Dicts
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {
	Normal = false,
	Gold = false,
	Rainbow = false
}

--// Status tracking
local ScriptStatus = {
    AutoPlant = "Idle",
    AutoHarvest = "Idle",
    AutoBuy = "Idle",
    AutoSell = "Idle",
    AutoWalk = "Idle"
}

--// Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom
local SelectedSeedStock, AutoSell, AutoWalk, AutoWalkStatus, AutoWalkMaxWait
local StatusDisplay, MoneyDisplay, CropCountDisplay

local function CreateWindow()
	local Window = ReGui:Window({
		Title = `🌱 {GameInfo.Name} | Enhanced by Depso 🌱`,
        Theme = "ModernGardenTheme",
		Size = UDim2.fromOffset(380, 280),
        Flags = {"NoCollapse", "NoTitleBar"}
	})
	return Window
end

--// Enhanced Status Display
local function UpdateStatusDisplay()
    if not StatusDisplay then return end
    
    local statusText = "🌱 Garden Bot Status 🌱\n"
    statusText = statusText .. "💰 Money: " .. (ShecklesCount.Value or 0) .. " Sheckles\n"
    statusText = statusText .. "🥕 Crops: " .. #GetInvCrops() .. " items\n\n"
    
    statusText = statusText .. "Status Overview:\n"
    for feature, status in pairs(ScriptStatus) do
        local icon = "⚪"
        if status == "Active" then icon = "🟢"
        elseif status == "Working" then icon = "🟡"
        elseif status == "Error" then icon = "🔴"
        end
        statusText = statusText .. icon .. " " .. feature .. ": " .. status .. "\n"
    end
    
    StatusDisplay.Text = statusText
end

--// Interface functions - ENHANCED
local function Plant(Position: Vector3, Seed: string)
    if not Position or not Seed then return end
    
    local Character = LocalPlayer.Character
    if not Character then return end
    
    ScriptStatus.AutoPlant = "Working"
    UpdateStatusDisplay()
    
    local success, error = pcall(function()
        GameEvents.Plant_RE:FireServer(Position, Seed)
    end)
    
    if not success then
        warn("🌱❌ Failed to plant at " .. tostring(Position) .. ": " .. tostring(error))
        ScriptStatus.AutoPlant = "Error"
    else
        ScriptStatus.AutoPlant = "Active"
    end
    
    UpdateStatusDisplay()
    wait(0.3)
end

local function GetFarms()
	return Farms:GetChildren()
end

local function GetFarmOwner(Farm: Folder): string
	local Important = Farm.Important
	local Data = Important.Data
	local Owner = Data.Owner
	return Owner.Value
end

local function GetFarm(PlayerName: string): Folder?
	local Farms = GetFarms()
	for _, Farm in next, Farms do
		local Owner = GetFarmOwner(Farm)
		if Owner == PlayerName then
			return Farm
		end
	end
    return
end

local IsSelling = false
local function SellInventory()
	local Character = LocalPlayer.Character
	local Previous = Character:GetPivot()
	local PreviousSheckles = ShecklesCount.Value

	if IsSelling then return end
	IsSelling = true
	
	ScriptStatus.AutoSell = "Working"
	UpdateStatusDisplay()

	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait() do
		if ShecklesCount.Value ~= PreviousSheckles then break end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)

	wait(0.2)
	IsSelling = false
	ScriptStatus.AutoSell = "Active"
	UpdateStatusDisplay()
	print("💰✅ Sold inventory for " .. (ShecklesCount.Value - PreviousSheckles) .. " Sheckles!")
end

local function BuySeed(Seed: string)
	GameEvents.BuySeedStock:FireServer(Seed)
end

local function BuyAllSelectedSeeds()
    if not SelectedSeedStock or not SelectedSeedStock.Selected then return end
    
    local Seed = SelectedSeedStock.Selected
    local Stock = SeedStock[Seed]

	if not Stock or Stock <= 0 then return end
	
	ScriptStatus.AutoBuy = "Working"
	UpdateStatusDisplay()

    for i = 1, Stock do
        BuySeed(Seed)
        wait(0.1)
    end
    
    ScriptStatus.AutoBuy = "Active"
    UpdateStatusDisplay()
    print("🛒✅ Bought " .. Stock .. "x " .. Seed)
end

local function GetSeedInfo(Seed: Tool): number?
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName then return end
	return PlantName.Value, Count.Value
end

local function CollectSeedsFromParent(Parent, Seeds: table)
    if not Parent then return end
    
    for _, Tool in pairs(Parent:GetChildren()) do
        if not Tool:IsA("Tool") then continue end
        
        local Name, Count = GetSeedInfo(Tool)
        if Name and Count then
            if Seeds[Name] then
                Seeds[Name].Count = Seeds[Name].Count + Count
            else
                Seeds[Name] = {
                    Count = Count,
                    Tool = Tool
                }
            end
        end
    end
end

local function CollectCropsFromParent(Parent, Crops: table)
	for _, Tool in next, Parent:GetChildren() do
		local Name = Tool:FindFirstChild("Item_String")
		if not Name then continue end
		table.insert(Crops, Tool)
	end
end

local function GetOwnedSeeds(): table
    local Character = LocalPlayer.Character
    OwnedSeeds = {}
    
    if Backpack then
        CollectSeedsFromParent(Backpack, OwnedSeeds)
    end
    
    if Character then
        CollectSeedsFromParent(Character, OwnedSeeds)
    end

    return OwnedSeeds
end

local function GetInvCrops(): table
	local Character = LocalPlayer.Character
	local Crops = {}
	CollectCropsFromParent(Backpack, Crops)
	CollectCropsFromParent(Character, Crops)
	return Crops
end

local function GetArea(Base: BasePart)
	local Center = Base:GetPivot()
	local Size = Base.Size
	local X1 = math.ceil(Center.X - (Size.X/2))
	local Z1 = math.ceil(Center.Z - (Size.Z/2))
	local X2 = math.floor(Center.X + (Size.X/2))
	local Z2 = math.floor(Center.Z + (Size.Z/2))
	return X1, Z1, X2, Z2
end

local function EquipCheck(Tool)
    if not Tool then return end
    local Character = LocalPlayer.Character
    if not Character then return end
    local Humanoid = Character:FindFirstChild("Humanoid")
    if not Humanoid then return end
    if Tool.Parent == Backpack then
        Humanoid:EquipTool(Tool)
    end
end

--// Auto farm functions
local MyFarm = GetFarm(LocalPlayer.Name)
local MyImportant = MyFarm.Important
local PlantLocations = MyImportant.Plant_Locations
local PlantsPhysical = MyImportant.Plants_Physical

local Dirt = PlantLocations:FindFirstChildOfClass("Part")
local X1, Z1, X2, Z2 = GetArea(Dirt)

local function GetRandomFarmPoint(): Vector3
    local FarmLands = PlantLocations:GetChildren()
    if #FarmLands == 0 then 
        return Vector3.new(0, 4, 0)
    end
    
    local FarmLand = FarmLands[math.random(1, #FarmLands)]
    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    local X = math.random(X1, X2)
    local Z = math.random(Z1, Z2)
    return Vector3.new(X, 4, Z)
end

local function AutoPlantLoop()
    if not SelectedSeed or not SelectedSeed.Selected or SelectedSeed.Selected == "" then 
        ScriptStatus.AutoPlant = "No seed selected"
        UpdateStatusDisplay()
        return 
    end
    
    local SeedName = SelectedSeed.Selected
    GetOwnedSeeds()
    
    local SeedData = OwnedSeeds[SeedName]
    if not SeedData then 
        ScriptStatus.AutoPlant = "Seed not found"
        UpdateStatusDisplay()
        return 
    end

    local Count = SeedData.Count
    local Tool = SeedData.Tool

    if Count <= 0 then 
        ScriptStatus.AutoPlant = "Out of seeds"
        UpdateStatusDisplay()
        return 
    end

    EquipCheck(Tool)
    wait(0.5)

    local Planted = 0
    local MaxPlant = math.min(Count, 50)

    if AutoPlantRandom and AutoPlantRandom.Value then
        for i = 1, MaxPlant do
            local Point = GetRandomFarmPoint()
            Plant(Point, SeedName)
            Planted += 1
            if Planted >= Count then break end
        end
        print("🌱✅ Planted " .. Planted .. " " .. SeedName .. " (random)")
        return
    end
    
    local Step = 1
    for X = X1, X2, Step do
        for Z = Z1, Z2, Step do
            if Planted >= MaxPlant or Planted >= Count then break end
            local Point = Vector3.new(X, 4, Z)
            Plant(Point, SeedName)
            Planted += 1
        end
        if Planted >= MaxPlant or Planted >= Count then break end
    end
    
    print("🌱✅ Planted " .. Planted .. " " .. SeedName)
end

local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
	fireproximityprompt(Prompt)
end

local function GetSeedStock(IgnoreNoStock: boolean?): table
	local SeedShop = PlayerGui.Seed_Shop
	local Items = SeedShop:FindFirstChild("Blueberry", true).Parent
	local NewList = {}

	for _, Item in next, Items:GetChildren() do
		local MainFrame = Item:FindFirstChild("Main_Frame")
		if not MainFrame then continue end
		local StockText = MainFrame.Stock_Text.Text
		local StockCount = tonumber(StockText:match("%d+"))

		if IgnoreNoStock then
			if StockCount <= 0 then continue end
			NewList[Item.Name] = StockCount
			continue
		end
		SeedStock[Item.Name] = StockCount
	end
	return IgnoreNoStock and NewList or SeedStock
end

local function CanHarvest(Plant): boolean?
    local Prompt = Plant:FindFirstChild("ProximityPrompt", true)
	if not Prompt then return end
    if not Prompt.Enabled then return end
    return true
end

local function CollectHarvestable(Parent, Plants, IgnoreDistance: boolean?)
	local Character = LocalPlayer.Character
	local PlayerPosition = Character:GetPivot().Position

    for _, Plant in next, Parent:GetChildren() do
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants, IgnoreDistance)
		end

		local PlantPosition = Plant:GetPivot().Position
		local Distance = (PlayerPosition-PlantPosition).Magnitude
		if not IgnoreDistance and Distance > 15 then continue end

		local Variant = Plant:FindFirstChild("Variant")
		if Variant and HarvestIgnores[Variant.Value] then continue end

        if CanHarvest(Plant) then
            table.insert(Plants, Plant)
        end
	end
    return Plants
end

local function GetHarvestablePlants(IgnoreDistance: boolean?)
    local Plants = {}
    CollectHarvestable(PlantsPhysical, Plants, IgnoreDistance)
    return Plants
end

local function HarvestPlants(Parent: Model)
	local Plants = GetHarvestablePlants()
	ScriptStatus.AutoHarvest = "Working (" .. #Plants .. " plants)"
	UpdateStatusDisplay()
	
    for _, Plant in next, Plants do
        HarvestPlant(Plant)
    end
    
    if #Plants > 0 then
        ScriptStatus.AutoHarvest = "Active"
        print("🚜✅ Harvested " .. #Plants .. " plants")
    else
        ScriptStatus.AutoHarvest = "No plants ready"
    end
    UpdateStatusDisplay()
end

local function AutoSellCheck()
    local CropCount = #GetInvCrops()
    if not AutoSell or not AutoSell.Value then return end
    if not SellThreshold or CropCount < SellThreshold.Value then return end
    SellInventory()
end

local function AutoWalkLoop()
	if IsSelling then return end
    local Character = LocalPlayer.Character
    if not Character then return end
    local Humanoid = Character.Humanoid

    local Plants = GetHarvestablePlants(true)
	local RandomAllowed = AutoWalkAllowRandom and AutoWalkAllowRandom.Value
	local DoRandom = #Plants == 0 or math.random(1, 3) == 2

    if RandomAllowed and DoRandom then
        local Position = GetRandomFarmPoint()
        Humanoid:MoveTo(Position)
        ScriptStatus.AutoWalk = "Moving to random point"
        if AutoWalkStatus then
            AutoWalkStatus.Text = "🎯 Random point"
        end
        UpdateStatusDisplay()
        return
    end
   
    for _, Plant in next, Plants do
        local Position = Plant:GetPivot().Position
        Humanoid:MoveTo(Position)
        ScriptStatus.AutoWalk = "Moving to " .. Plant.Name
        if AutoWalkStatus then
            AutoWalkStatus.Text = "🎯 " .. Plant.Name
        end
        UpdateStatusDisplay()
    end
end

local function NoclipLoop()
    local Character = LocalPlayer.Character
    if not NoClip or not NoClip.Value then return end
    if not Character then return end
    for _, Part in Character:GetDescendants() do
        if Part:IsA("BasePart") then
            Part.CanCollide = false
        end
    end
end

local function MakeLoop(Toggle, Func)
	coroutine.wrap(function()
		while wait(.01) do
			if not Toggle or not Toggle.Value then 
                continue 
            end
			pcall(Func)
		end
	end)()
end

local function StartServices()
	MakeLoop(AutoWalk, function()
		local MaxWait = AutoWalkMaxWait and AutoWalkMaxWait.Value or 10
		AutoWalkLoop()
		wait(math.random(1, MaxWait))
	end)

	MakeLoop(AutoHarvest, function()
		HarvestPlants(PlantsPhysical)
		wait(1)
	end)

	MakeLoop(AutoBuy, function()
        BuyAllSelectedSeeds()
        wait(2)
    end)

	MakeLoop(AutoPlant, function()
        AutoPlantLoop()
        wait(3)
    end)

	coroutine.wrap(function()
		while wait(1) do
			pcall(GetSeedStock)
			pcall(GetOwnedSeeds)
			pcall(UpdateStatusDisplay)
		end
	end)()
end

local function CreateCheckboxes(Parent, Dict: table)
	for Key, Value in next, Dict do
		Parent:Checkbox({
			Value = Value,
			Label = "🚫 " .. Key,
			Callback = function(_, Value)
				Dict[Key] = Value
			end
		})
	end
end

--// Enhanced Window Creation
local Window = CreateWindow()

--// Status Dashboard
local StatusNode = Window:TreeNode({Title="📊 Status Dashboard", DefaultOpen=true})
StatusDisplay = StatusNode:Label({
	Text = "🌱 Loading Garden Bot...",
    Multiline = true
})

--// Enhanced Auto-Plant Section
local PlantNode = Window:TreeNode({Title="🌱 Auto-Plant System"})
SelectedSeed = PlantNode:Combo({
	Label = "🥕 Select Seed",
	Selected = "",
	GetItems = function()
        GetOwnedSeeds()
        local SeedList = {}
        for Name, Data in pairs(OwnedSeeds) do
            SeedList[Name] = Name .. " (" .. Data.Count .. "x)"
        end
        return SeedList
    end,
})
AutoPlant = PlantNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Plant"
})
AutoPlantRandom = PlantNode:Checkbox({
	Value = false,
	Label = "🎲 Random Placement"
})
PlantNode:Button({
	Text = "🌱 Plant All Now",
	Callback = AutoPlantLoop,
})

--// Enhanced Auto-Harvest Section
local HarvestNode = Window:TreeNode({Title="🚜 Auto-Harvest System"})
AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Harvest"
})
HarvestNode:Separator({Text="🔧 Harvest Settings"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

--// Enhanced Auto-Buy Section
local BuyNode = Window:TreeNode({Title="🛒 Auto-Buy System"})
local OnlyShowStock

SelectedSeedStock = BuyNode:Combo({
	Label = "🛒 Select Seed to Buy",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowStock and OnlyShowStock.Value
		return GetSeedStock(OnlyStock)
	end,
})
AutoBuy = BuyNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Buy"
})
OnlyShowStock = BuyNode:Checkbox({
	Value = false,
	Label = "📦 Show Only In-Stock"
})
BuyNode:Button({
	Text = "🛒 Buy All Now",
	Callback = BuyAllSelectedSeeds,
})

--// Enhanced Auto-Sell Section
local SellNode = Window:TreeNode({Title="💰 Auto-Sell System"})
SellNode:Button({
	Text = "💰 Sell Inventory Now",
	Callback = SellInventory, 
})
AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Sell"
})
SellThreshold = SellNode:SliderInt({
    Label = "📦 Crop Threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
})

--// Enhanced Auto-Walk Section
local WalkNode = Window:TreeNode({Title="🚶 Auto-Walk System"})
AutoWalkStatus = WalkNode:Label({
	Text = "🎯 None"
})
AutoWalk = WalkNode:Checkbox({
	Value = false,
	Label = "🤖 Enable Auto-Walk"
})
AutoWalkAllowRandom = WalkNode:Checkbox({
	Value = true,
	Label = "🎲 Allow Random Movement"
})
NoClip = WalkNode:Checkbox({
	Value = false,
	Label = "👻 NoClip Mode"
})
AutoWalkMaxWait = WalkNode:SliderInt({
    Label = "⏱️ Max Delay (seconds)",
    Value = 10,
    Minimum = 1,
    Maximum = 120,
})

--// Initialize all status
for key, _ in pairs(ScriptStatus) do
    ScriptStatus[key] = "Idle"
end

--// Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

--// Start Services
StartServices()
UpdateStatusDisplay()

print("🌱✅ Enhanced Garden Bot loaded successfully!")
print("🎮 Created by Depso - Enjoy farming!")
