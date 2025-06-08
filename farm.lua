--[[
    @author depso (depthso)
    @description Grow a Garden auto-farm script - FIXED VERSION
    https://www.roblox.com/games/126884695634066
]]

--// Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

local Accent = {
    DarkGreen = Color3.fromRGB(45, 95, 25),
    Green = Color3.fromRGB(69, 142, 40),
    Brown = Color3.fromRGB(26, 20, 8),
}

--// ReGui configuration (Ui library)
ReGui:Init({
	Prefabs = InsertService:LoadLocalAsset(PrefabsId)
})
ReGui:DefineTheme("GardenTheme", {
	WindowBg = Accent.Brown,
	TitleBarBg = Accent.DarkGreen,
	TitleBarBgActive = Accent.Green,
    ResizeGrab = Accent.DarkGreen,
    FrameBg = Accent.DarkGreen,
    FrameBgActive = Accent.Green,
	CollapsingHeaderBg = Accent.Green,
    ButtonsBg = Accent.Green,
    CheckMark = Accent.Green,
    SliderGrab = Accent.Green,
})

--// Dicts
local SeedStock = {}
local OwnedSeeds = {}
local HarvestIgnores = {
	Normal = false,
	Gold = false,
	Rainbow = false
}

--// Globals
local SelectedSeed, AutoPlantRandom, AutoPlant, AutoHarvest, AutoBuy, SellThreshold, NoClip, AutoWalkAllowRandom
local SelectedSeedStock, AutoSell, AutoWalk, AutoWalkStatus, AutoWalkMaxWait

local function CreateWindow()
	local Window = ReGui:Window({
		Title = `{GameInfo.Name} | Depso`,
        Theme = "GardenTheme",
		Size = UDim2.fromOffset(300, 200)
	})
	return Window
end

--// Interface functions - FIXED
local function Plant(Position: Vector3, Seed: string)
    if not Position or not Seed then return end
    
    -- Pastikan karakter ada
    local Character = LocalPlayer.Character
    if not Character then return end
    
    -- Fire server dengan error handling
    local success, error = pcall(function()
        GameEvents.Plant_RE:FireServer(Position, Seed)
    end)
    
    if not success then
        warn("Gagal menanam di posisi " .. tostring(Position) .. ": " .. tostring(error))
    end
    
    wait(0.3) -- Delay untuk mencegah spam
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

	--// Prevent conflict
	if IsSelling then return end
	IsSelling = true

	Character:PivotTo(CFrame.new(62, 4, -26))
	while wait() do
		if ShecklesCount.Value ~= PreviousSheckles then break end
		GameEvents.Sell_Inventory:FireServer()
	end
	Character:PivotTo(Previous)

	wait(0.2)
	IsSelling = false
end

local function BuySeed(Seed: string)
	GameEvents.BuySeedStock:FireServer(Seed)
end

local function BuyAllSelectedSeeds()
    if not SelectedSeedStock or not SelectedSeedStock.Selected then return end
    
    local Seed = SelectedSeedStock.Selected
    local Stock = SeedStock[Seed]

	if not Stock or Stock <= 0 then return end

    for i = 1, Stock do
        BuySeed(Seed)
        wait(0.1) -- Small delay between purchases
    end
end

local function GetSeedInfo(Seed: Tool): number?
	local PlantName = Seed:FindFirstChild("Plant_Name")
	local Count = Seed:FindFirstChild("Numbers")
	if not PlantName then return end

	return PlantName.Value, Count.Value
end

-- Fungsi helper untuk collect seeds (diperbaiki)
local function CollectSeedsFromParent(Parent, Seeds: table)
    if not Parent then return end
    
    for _, Tool in pairs(Parent:GetChildren()) do
        if not Tool:IsA("Tool") then continue end
        
        local Name, Count = GetSeedInfo(Tool)
        if Name and Count then
            -- Jika seed sudah ada, tambahkan count-nya
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

-- Fungsi untuk mendapatkan seeds yang dimiliki (diperbaiki)
local function GetOwnedSeeds(): table
    local Character = LocalPlayer.Character
    
    -- Clear data lama
    OwnedSeeds = {}
    
    -- Collect dari backpack
    if Backpack then
        CollectSeedsFromParent(Backpack, OwnedSeeds)
    end
    
    -- Collect dari character
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

	--// Bottom left
	local X1 = math.ceil(Center.X - (Size.X/2))
	local Z1 = math.ceil(Center.Z - (Size.Z/2))

	--// Top right
	local X2 = math.floor(Center.X + (Size.X/2))
	local Z2 = math.floor(Center.Z + (Size.Z/2))

	return X1, Z1, X2, Z2
end

-- Fungsi untuk cek dan equip tool yang diperbaiki
local function EquipCheck(Tool)
    if not Tool then return end
    
    local Character = LocalPlayer.Character
    if not Character then return end
    
    local Humanoid = Character:FindFirstChild("Humanoid")
    if not Humanoid then return end

    -- Hanya equip jika tool ada di backpack
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

-- Fungsi untuk mendapatkan posisi random di farm (diperbaiki)
local function GetRandomFarmPoint(): Vector3
    local FarmLands = PlantLocations:GetChildren()
    if #FarmLands == 0 then 
        return Vector3.new(0, 4, 0) -- fallback position
    end
    
    local FarmLand = FarmLands[math.random(1, #FarmLands)]
    local X1, Z1, X2, Z2 = GetArea(FarmLand)
    local X = math.random(X1, X2)
    local Z = math.random(Z1, Z2)

    return Vector3.new(X, 4, Z)
end

-- Fungsi utama auto plant yang diperbaiki
local function AutoPlantLoop()
    -- Cek apakah seed sudah dipilih
    if not SelectedSeed or not SelectedSeed.Selected or SelectedSeed.Selected == "" then 
        return 
    end
    
    local SeedName = SelectedSeed.Selected
    
    -- Update data seeds yang dimiliki
    GetOwnedSeeds()
    
    local SeedData = OwnedSeeds[SeedName]
    if not SeedData then 
        print("Seed tidak ditemukan: " .. SeedName)
        return 
    end

    local Count = SeedData.Count
    local Tool = SeedData.Tool

    -- Cek apakah masih ada stock
    if Count <= 0 then 
        print("Seed habis: " .. SeedName)
        return 
    end

    -- Equip tool jika diperlukan
    EquipCheck(Tool)
    wait(0.5) -- Tunggu sampai tool ter-equip

    local Planted = 0
    local MaxPlant = math.min(Count, 50) -- Batasi maksimal 50 tanaman per loop

    -- Plant di posisi random jika diaktifkan
    if AutoPlantRandom and AutoPlantRandom.Value then
        for i = 1, MaxPlant do
            local Point = GetRandomFarmPoint()
            Plant(Point, SeedName)
            Planted += 1
            
            -- Break jika sudah mencapai batas
            if Planted >= Count then break end
        end
        print("Berhasil menanam " .. Planted .. " " .. SeedName .. " (random)")
        return
    end
    
    -- Plant secara berurutan di area farm
    local Step = 1
    
    for X = X1, X2, Step do
        for Z = Z1, Z2, Step do
            if Planted >= MaxPlant or Planted >= Count then 
                break 
            end
            
            local Point = Vector3.new(X, 4, Z) -- Ubah Y ke 4 untuk konsistensi
            Plant(Point, SeedName)
            Planted += 1
        end
        
        if Planted >= MaxPlant or Planted >= Count then 
            break 
        end
    end
    
    print("Berhasil menanam " .. Planted .. " " .. SeedName)
end

local function HarvestPlant(Plant: Model)
	local Prompt = Plant:FindFirstChild("ProximityPrompt", true)

	--// Check if it can be harvested
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

		--// Seperate list
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
        --// Fruits
		local Fruits = Plant:FindFirstChild("Fruits")
		if Fruits then
			CollectHarvestable(Fruits, Plants, IgnoreDistance)
		end

		--// Distance check
		local PlantPosition = Plant:GetPivot().Position
		local Distance = (PlayerPosition-PlantPosition).Magnitude
		if not IgnoreDistance and Distance > 15 then continue end

		--// Ignore check
		local Variant = Plant:FindFirstChild("Variant")
		if Variant and HarvestIgnores[Variant.Value] then continue end

        --// Collect
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
    for _, Plant in next, Plants do
        HarvestPlant(Plant)
    end
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

    --// Random point
    if RandomAllowed and DoRandom then
        local Position = GetRandomFarmPoint()
        Humanoid:MoveTo(Position)
        if AutoWalkStatus then
            AutoWalkStatus.Text = "Random point"
        end
        return
    end
   
    --// Move to each plant
    for _, Plant in next, Plants do
        local Position = Plant:GetPivot().Position
        Humanoid:MoveTo(Position)
        if AutoWalkStatus then
            AutoWalkStatus.Text = Plant.Name
        end
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
			if not Toggle or not Toggle.Value then continue end
			pcall(Func) -- Add error handling
		end
	end)()
end

local function StartServices()
	--// Auto-Walk
	MakeLoop(AutoWalk, function()
		local MaxWait = AutoWalkMaxWait and AutoWalkMaxWait.Value or 10
		AutoWalkLoop()
		wait(math.random(1, MaxWait))
	end)

	--// Auto-Harvest
	MakeLoop(AutoHarvest, function()
		HarvestPlants(PlantsPhysical)
	end)

	--// Auto-Buy
	MakeLoop(AutoBuy, BuyAllSelectedSeeds)

	--// Auto-Plant
	MakeLoop(AutoPlant, AutoPlantLoop)

	--// Get stocks
	coroutine.wrap(function()
		while wait(.1) do
			pcall(GetSeedStock)
			pcall(GetOwnedSeeds)
		end
	end)()
end

local function CreateCheckboxes(Parent, Dict: table)
	for Key, Value in next, Dict do
		Parent:Checkbox({
			Value = Value,
			Label = Key,
			Callback = function(_, Value)
				Dict[Key] = Value
			end
		})
	end
end

--// Window
local Window = CreateWindow()

--// Auto-Plant
local PlantNode = Window:TreeNode({Title="Auto-Plant 🥕"})
SelectedSeed = PlantNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = function()
        GetOwnedSeeds() -- Update sebelum mengambil daftar
        local SeedList = {}
        for Name, Data in pairs(OwnedSeeds) do
            SeedList[Name] = Data.Count
        end
        return SeedList
    end,
})
AutoPlant = PlantNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
AutoPlantRandom = PlantNode:Checkbox({
	Value = false,
	Label = "Plant at random points"
})
PlantNode:Button({
	Text = "Plant all",
	Callback = AutoPlantLoop,
})

--// Auto-Harvest
local HarvestNode = Window:TreeNode({Title="Auto-Harvest 🚜"})
AutoHarvest = HarvestNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
HarvestNode:Separator({Text="Ignores:"})
CreateCheckboxes(HarvestNode, HarvestIgnores)

--// Auto-Buy
local BuyNode = Window:TreeNode({Title="Auto-Buy 🥕"})
local OnlyShowStock

SelectedSeedStock = BuyNode:Combo({
	Label = "Seed",
	Selected = "",
	GetItems = function()
		local OnlyStock = OnlyShowStock and OnlyShowStock.Value
		return GetSeedStock(OnlyStock)
	end,
})
AutoBuy = BuyNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
OnlyShowStock = BuyNode:Checkbox({
	Value = false,
	Label = "Only list stock"
})
BuyNode:Button({
	Text = "Buy all",
	Callback = BuyAllSelectedSeeds,
})

--// Auto-Sell
local SellNode = Window:TreeNode({Title="Auto-Sell 💰"})
SellNode:Button({
	Text = "Sell inventory",
	Callback = SellInventory, 
})
AutoSell = SellNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
SellThreshold = SellNode:SliderInt({
    Label = "Crops threshold",
    Value = 15,
    Minimum = 1,
    Maximum = 199,
})

--// Auto-Walk
local WalkNode = Window:TreeNode({Title="Auto-Walk 🚶"})
AutoWalkStatus = WalkNode:Label({
	Text = "None"
})
AutoWalk = WalkNode:Checkbox({
	Value = false,
	Label = "Enabled"
})
AutoWalkAllowRandom = WalkNode:Checkbox({
	Value = true,
	Label = "Allow random points"
})
NoClip = WalkNode:Checkbox({
	Value = false,
	Label = "NoClip"
})
AutoWalkMaxWait = WalkNode:SliderInt({
    Label = "Max delay",
    Value = 10,
    Minimum = 1,
    Maximum = 120,
})

--// Connections
RunService.Stepped:Connect(NoclipLoop)
Backpack.ChildAdded:Connect(AutoSellCheck)

--// Services
StartServices()
