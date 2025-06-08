type table = {
	[any]: any
}

_G.Configuration = {
	["Enabled"] = true,
	["BotToken"] = "8196267326:AAFEsUde04dQ1lIIdMZbu98EiUzd5Lhe0Ec",
	["ChatID"] = "7729276844",
	["Weather Reporting"] = true,
	["Anti-AFK"] = true,
	["Auto-Reconnect"] = true,
	["Rendering Enabled"] = false,
	["AlertLayouts"] = {
		["Weather"] = {
			EmbedColor = Color3.fromRGB(42, 109, 255),
		},
		["SeedsAndGears"] = {
			EmbedColor = Color3.fromRGB(56, 238, 23),
			Layout = {
				["ROOT/SeedStock/Stocks"] = "SEEDS STOCK",
				["ROOT/GearStock/Stocks"] = "GEAR STOCK"
			}
		}
	}
}

local HttpService = game:GetService("HttpService")

local function GetConfigValue(Key: string)
	return _G.Configuration[Key]
end

local function ConvertColor3(Color: Color3): number
	local Hex = Color:ToHex()
	return tonumber(Hex, 16)
end

local function WebhookSend(Type: string, Fields: table)
	local Enabled = GetConfigValue("Enabled")
	local BotToken = GetConfigValue("BotToken")
	local ChatID = GetConfigValue("ChatID")

	if not Enabled then return end

	local Message = ""
	for _, Field in Fields do
		Message ..= `{Field.name}: {Field.value}\n`
	end

	local Url = `https://api.telegram.org/bot{BotToken}/sendMessage`
	local Body = {
		chat_id = ChatID,
		text = Message,
		parse_mode = "Markdown"
	}

	local RequestData = {
		Url = Url,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = HttpService:JSONEncode(Body)
	}

	task.spawn(request, RequestData)
end

local function ProcessPacket(Data, Type: string, Layout)
	local Fields = {}
	local FieldsLayout = Layout.Layout
	if not FieldsLayout then return end

	for Packet, Title in FieldsLayout do
		local Stock = Data[Packet]
		if not Stock then return end

		local StockString = ""
		for Name, Data in Stock do
			StockString ..= `{Name}: {Data.Stock}\n`
		end

		table.insert(Fields, { name = Title, value = StockString, inline = true })
	end

	WebhookSend(Type, Fields)
end

print("Bot Telegram Stock telah diaktifkan!")
