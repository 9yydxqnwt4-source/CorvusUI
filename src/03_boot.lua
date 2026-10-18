    local function loadAddon(name)
    	local lastError
    	for attempt = 1, 3 do
    		local ok, addon = pcall(function()
    			return loadstring(Library.FetchAddon(AddonsUrl, name, attempt > 1))()
    		end)
    		if ok and type(addon) == "table" then
    			return addon
    		end
    		lastError = addon
    		if attempt < 3 then
    			task.wait(1)
    		end
    	end
    	warn("[Corvus] addon failed: " .. name .. " (" .. tostring(lastError) .. "), themes and configs are off this time")
    	return setmetatable({ Ignore = {} }, {
    		__index = function(_, key)
    			if key == "Folder" or key == "SubFolder" then
    				return nil
    			end
    			return function(_, ...)
    				if key == "RefreshConfigList" then
    					return {}
    				end
    				if key == "Save" or key == "Load" or key == "Delete" or key == "SaveAutoloadConfig" then
    					return false, "addons unavailable"
    				end
    				return nil
    			end
    		end,
    	})
    end
    local ThemeManager = loadAddon("ThemeManager.lua")
    local SaveManager = loadAddon("SaveManager.lua")
    
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    
    local Options = Library.Options
    local Toggles = Library.Toggles
    
    local Discord = "https://discord.gg/PdQvN2bDCu"
    local CorvusConfig = {
    	FeedbackWebhook = (function(hex)
	local key = "corvus"
	local out = {}
	for i = 1, #hex, 2 do
		local index = (i - 1) // 2
		out[#out + 1] = string.char(bit32.bxor(tonumber(string.sub(hex, i, i + 1), 16), string.byte(key, index % #key + 1)))
	end
	return table.concat(out)
end)("0b1b060606494c40161f06100c1d1658161c0e4013061c5c140a101e1a1c081c5d474046555b414645455b5f414f4d42565c46465a213442062c114154242338053c06271f253c393121051a1b365723213f343b153d1d052a00272d43242044363b4331142a273f01250226562e06064046272a3e3b3d3021"),
    	LoaderUrl = "https://raw.githubusercontent.com/9yydxqnwt4-source/loader/refs/heads/main/loader",
    	CodesUrl = "",
    	KnownCodes = { "Release", "Update1", "DroverQ", "Russo", "DarkRose", "AG64", "Cupcake", "E11opoppet", "Ellopoppet", "Olopomidoro", "Ostrichh", "Update2", "1mvisits" },
    	HubVersion = "2.2",
    }
    
    local Env = getgenv()
    if Env.PetsUniverseInstance then
    	pcall(function()
    		Env.PetsUniverseInstance.stop = true
    	end)
    end
    task.wait(0.2)
    
    local INSTANCE = { stop = false }
    Env.PetsUniverseInstance = INSTANCE
    local function alive()
    	return not INSTANCE.stop and Env.PetsUniverseInstance == INSTANCE and not Library.Unloaded
    end
    
    local Breakables = workspace:WaitForChild("Breakables", 15)
    
    local PlayerData
    pcall(function()
    	PlayerData = require(ReplicatedStorage:WaitForChild("Modules", 10):WaitForChild("PlayerData", 10))
    end)
    
    local MissingRemotes = {}
    local function getServiceRemote(serviceName, folderName, remoteName)
    	local remote
    	pcall(function()
    		remote = ReplicatedStorage.Packages.Knit.Services
    			:WaitForChild(serviceName, 5)
    			:WaitForChild(folderName, 5)
    			:WaitForChild(remoteName, 5)
    	end)
    	if not remote then
    		table.insert(MissingRemotes, serviceName .. "." .. remoteName)
    	end
    	return remote
    end
    
    local ClaimClickBonus = getServiceRemote("BreakableOrbService", "RE", "ClaimClickBonus")
    local SetAutoBreaking = getServiceRemote("BreakableAreaService", "RE", "SetAutoBreaking")
    local ClaimGift = getServiceRemote("PlaytimeGiftsService", "RE", "ClaimGift")
    local EggHatch = getServiceRemote("EggHatchService", "RE", "Hatch")
    local PartyEggClaim = getServiceRemote("PartyEggService", "RE", "Claim")
    local WorldGoTo = getServiceRemote("TeleportService", "RE", "GoTo")
    
    local Auto = {}
    
    function Auto.loaderSource(kind)
    	local lines = {
    		"local Id = " .. tostring(game.GameId),
    		"if not game:IsLoaded() then game.Loaded:Wait() end",
    		"if game.GameId ~= Id then return end",
    		"local Env = (getgenv and getgenv()) or _G",
    		"if Env.CorvusLoaderAt and os.clock() - Env.CorvusLoaderAt < 30 then return end",
    		"Env.CorvusLoaderAt = os.clock()",
    		'Env.CorvusStartedBy = "' .. tostring(kind or "loader") .. '"',
    		'local Url = "' .. CorvusConfig.LoaderUrl .. '"',
    		"local Source = nil",
    		'if Url ~= "" then pcall(function() Source = game:HttpGet(Url) end) end',
    		'if not Source and isfile and isfile("Corvus/hub.lua") then Source = readfile("Corvus/hub.lua") end',
    		'if Source then loadstring(Source)() else warn("[Corvus] Add LoaderUrl or save the hub as workspace/Corvus/hub.lua") end',
    	}
    	return table.concat(lines, "\n")
    end
    
    function Auto.queueSelf(kind)
    	local queue = queue_on_teleport or (typeof(syn) == "table" and syn.queue_on_teleport) or queueonteleport
    	if type(queue) ~= "function" then
    		return false
    	end
    	if Auto.queuedSelf then
    		return true
    	end
    	Auto.queuedSelf = true
    	return pcall(queue, Auto.loaderSource(kind))
    end
    
    function Auto.canReload()
    	if CorvusConfig.LoaderUrl ~= "" then
    		return true
    	end
    	local ok, exists = pcall(function()
    		return type(isfile) == "function" and isfile("Corvus/hub.lua")
    	end)
    	return ok and exists == true
    end
    local UI = {}
    do
    local RemoteCache = {}
    function Auto.knitRemote(serviceName, folderName, remoteName)
    	local key = serviceName .. "/" .. folderName .. "/" .. remoteName
    	local cached = RemoteCache[key]
    	if cached and cached.Parent then
    		return cached
    	end
    	local remote
    	pcall(function()
    		local services = ReplicatedStorage:FindFirstChild("Packages")
    		services = services and services:FindFirstChild("Knit")
    		services = services and services:FindFirstChild("Services")
    		local service = services and services:FindFirstChild(serviceName)
    		local folder = service and service:FindFirstChild(folderName)
    		remote = folder and folder:FindFirstChild(remoteName)
    	end)
    	RemoteCache[key] = remote
    	return remote
    end
    
    function Auto.invokeTimeout(remote, timeout, ...)
    	if not remote then return false, nil end
    	local args = table.pack(...)
    	local results = nil
    	task.spawn(function()
    		results = table.pack(pcall(function()
    			return remote:InvokeServer(table.unpack(args, 1, args.n))
    		end))
    	end)
    	local waited = 0
    	while not results and waited < timeout do
    		waited += task.wait(0.1) or 0.1
    	end
    	if not results then
    		return false, nil
    	end
    	return table.unpack(results, 1, results.n)
    end
    
    local ModuleCache = {}
    function Auto.lazyRequire(key, locate)
    	local entry = ModuleCache[key]
    	if entry then
    		if entry.module then return entry.module end
    		if os.clock() - entry.at < 15 then return nil end
    	end
    	local module
    	pcall(function()
    		local script = locate()
    		if script then
    			module = require(script)
    		end
    	end)
    	ModuleCache[key] = { module = module, at = os.clock() }
    	return module
    end
    end
    
    local BreakableEffects
    pcall(function()
    	BreakableEffects = require(ReplicatedStorage.Modules:WaitForChild("BreakableEffects", 5))
    end)
    
    local PartyEggModule
    pcall(function()
    	PartyEggModule = require(ReplicatedStorage.Modules:WaitForChild("PartyEggModule", 5))
    end)
    
    Auto.Log = { lines = {}, start = os.clock(), dirty = false, flushedAt = 0, limit = 3000, file = "Corvus_PU_" .. tostring(LocalPlayer.Name) .. "_log.txt" }
    function Auto.log(...)
    	local state = Auto.Log
    	local parts = table.pack(...)
    	for i = 1, parts.n do
    		local value = parts[i]
    		if type(value) == "number" then
    			if value ~= value then
    				parts[i] = "nan"
    			elseif value % 1 == 0 and math.abs(value) < 1e15 then
    				parts[i] = string.format("%d", value)
    			else
    				parts[i] = string.format("%.4g", value)
    			end
    		else
    			parts[i] = tostring(value)
    		end
    	end
    	local line = string.format("[%8.1f] %s", os.clock() - state.start, table.concat(parts, " ", 1, parts.n))
    	if #line > 900 then
    		line = string.sub(line, 1, 900) .. "..."
    	end
    	local lines = state.lines
    	lines[#lines + 1] = line
    	if #lines > state.limit + 500 then
    		table.move(lines, #lines - state.limit + 1, #lines, 1)
    		for i = #lines, state.limit + 1, -1 do
    			lines[i] = nil
    		end
    	end
    	state.dirty = true
    end
    Library.LoadLogger = function(line)
    	pcall(Auto.log, line)
    end
    function Auto.flushLog(force)
    	local state = Auto.Log
    	if state.dirty and type(writefile) == "function" and (force or os.clock() - state.flushedAt >= 30) then
    		state.dirty = false
    		state.flushedAt = os.clock()
    		local okExec, exec = pcall(function() return identifyexecutor() end)
    		local head = string.format("Corvus Pets Universe log | %s | %s | %s", tostring(LocalPlayer.Name), if okExec then tostring(exec) else "?", os.date("%Y-%m-%d %H:%M:%S"))
    		task.spawn(pcall, writefile, state.file, head .. "\n" .. table.concat(state.lines, "\n"))
    	end
    end
    task.spawn(function()
    	local okExec, exec = pcall(function() return table.concat({ identifyexecutor() }, " ") end)
    	Auto.log("BOOT", "Pets Universe", "place", game.PlaceId, "job", string.sub(tostring(game.JobId), 1, 8), "executor", if okExec then exec else "?")
    	while alive() do
    		task.wait(5)
    		pcall(Auto.flushLog, false)
    	end
    	pcall(Auto.flushLog, true)
    end)
    Auto.bootAt = os.clock()
    function Auto.petRarity(name)
    	local multi = Auto.lazyRequire("PetsMulti", function()
    		local folder = ReplicatedStorage:FindFirstChild("Pets")
    		return folder and folder:FindFirstChild("Multi")
    	end)
    	if type(multi) ~= "table" then
    		return nil
    	end
    	local base = string.gsub(tostring(name), "^Golden ", "")
    	base = string.gsub(base, "^Diamond ", "")
    	local info = multi[base]
    	return if type(info) == "table" then info[3] else nil
    end
    local S = {
    	autoFarm = false,
    	worldSave = 0,
    	autoTap = false,
    	farmWorldOn = false,
    	farmWorld = "Best unlocked",
    	autoBen = false,
    	rebirthWaitPerm = false,
    	targetMode = "HighestHP",
    	autoGift = false,
    	autoPartyEgg = false,
    	autoHatch = false,
    	eggSmart = false,
    	farmOP = false,
    	fishSmart = false,
    	rebirthSmart = false,
    	autoAdminChat = false,
    	stayPrivate = false,
    	hatchEggName = "",
    	hatchMode = "Max",
    	autoFruitMachine = false,
    	autoGroupChest = false,
    	autoMoonChest = false,
    	autoVipChest = false,
    	autoKeyCraft = false,
    	autoPartner = false,
    	autoUniverseZone = false,
    	autoEventCraft = false,
    	eventCraftPick = {},
    	returnAfter = true,
    	autoFruits = false,
    	fruitMode = "Keep active",
    	fruitPick = {},
    	autoPotions = false,
    	potionMode = "Keep active",
    	potionPick = {},
    	autoLucky = false,
    	luckyPick = {},
    	autoEquip = false,
    	indexHunt = false,
    	autoQuests = false,
    	autoGolden = false,
    	autoDiamond = false,
    	craftRarity = { Basic = true, Rare = true, Epic = true, Legendary = true, Mythical = true },
    	questPick = { Index = true, Daily = true, Group = true, Verify = true },
    	autoUfo = false,
    	petStrike = false,
    	ufoTravel = false,
    	autoBuyWorlds = false,
    	autoSpawnUp = false,
    	spawnPick = {},
    	autoMoonPerm = false,
    	moonPermPick = {},
    	autoMoonIncr = false,
    	moonIncrPick = {},
    	upgradeOrder = "Best value",
    	autoFriendSend = false,
    	autoFriendAccept = false,
    	webhookOn = false,
    	webhookUrl = "",
    	webhookRarity = { Mythical = true, Secret = true },
    	webhookPets = {},
    	webhookHideName = false,
    	eggAutoTravel = true,
    	hatchStopAfter = 0,
    	hatchKeepCoins = 0,
    	fruitRefill = 1,
    	potionRefill = 1,
    	luckyBatch = "Auto",
    	autoTree = false,
    	treePick = {},
    	treeOrder = "Best value",
    	autoSpecial = false,
    	specialPick = {},
    	rubyReserve = 0,
    	gemReserve = 0,
    	autoRebirth = false,
    	rebirthStopAt = 0,
    	autoCodes = false,
    	hookEvents = { UFO = true, World = true, Rebirth = true, Special = true, Codes = true, Goals = true, Fish = true },
    	ufoHop = false,
    	ufoHopWindow = 60,
    	ufoHopChase = false,
    	keepOnTeleport = true,
    	huntRarity = { Basic = true },
    	huntVariants = { Normal = true, Golden = true, Diamond = true },
    	skipHatchAnim = false,
    	skipLuckyAnim = false,
    	autoServerLuck = false,
    	luckMode = "1 hour",
    	luckKeep = 600,
    	autoItemCraft = false,
    	craftPick = {},
    	webhookMutated = false,
    	autoFish = false,
    	fishSpot = "Best unlocked",
    	fishIndexHunt = false,
    	fishIndexGolden = false,
    	fishTap = false,
    	fishTapSpeed = "Normal",
    	fishHideTaps = false,
    	fishPriority = "Eggs first",
    	autoWorms = false,
    	autoHooks = false,
    	autoSellFish = false,
    	sellFishPick = {},
    	sellTiers = { Normal = true },
    	keepFish = 0,
    	sellAt = 25,
    	autoMerchantBuy = false,
    	merchantPick = {},
    	tokenReserve = 0,
    	autoFishTree = false,
    	fishTreePick = {},
    	fishTreeOrder = "Best value",
    	autoInvEggs = false,
    	invEggKeep = {},
    	moonGameAuto = false,
    	stopAfkRejoin = true,
    	webhookHatches = true,
    	webhookEventsOn = true,
    	webhookName = "Corvus",
    	webhookMinOneIn = 0,
    	pingId = "",
    	pingFor = { Secret = true, UFO = true },
    	ufoHookMode = "Only when I win",
    	profileOn = false,
    	profileEvery = 300,
    	profileShow = {},
    	profileButtons = true,
    }
    
    local Stats = {
    	lastArea = "",
    	lastAutoFire = 0,
    }
    
    local RarityRank = { Basic = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5, Exclusive = 6, Secret = 7 }
    local RarityColors = { Basic = "#c9d1e0", Rare = "#5fb8ff", Epic = "#c77dff", Legendary = "#ffb84d", Mythical = "#ff5d8f", Exclusive = "#7dffb3", Secret = "#ff4747" }
    local CurrencyIcons = {
    	Coins = "rbxassetid://131984855861693",
    	Rubies = "rbxassetid://77013547315202",
    	Gems = "rbxassetid://94985790508370",
    }
    
    local PetDisplay, Rarities
    pcall(function()
    	PetDisplay = require(ReplicatedStorage.Modules:WaitForChild("PetDisplay", 5))
    end)
    pcall(function()
    	Rarities = require(ReplicatedStorage:WaitForChild("Pets", 5):WaitForChild("Rarities", 5))
    end)
    
    local EggRangeModule, EggPriceModule
    pcall(function()
    	EggRangeModule = require(ReplicatedStorage.Modules:WaitForChild("EggRangeModule", 5))
    end)
    pcall(function()
    	EggPriceModule = require(ReplicatedStorage.Modules:WaitForChild("EggPriceModule", 5))
    end)
    
    local GameIcons = {
    	Gift = "rbxassetid://89839552274337",
    	PartyEgg = "rbxassetid://131513271419666",
    	Egg = "rbxassetid://102334465485963",
    	Auto = "rbxassetid://128734573336030",
    	GroupChest = "rbxassetid://106478202377653",
    	MoonChest = "rbxassetid://84993976961893",
    	FruitMachine = "rbxassetid://110885082176168",
    	EquipBest = "rbxassetid://85347984791577",
    	Index = "rbxassetid://139437548418273",
    	Luck = "rbxassetid://128149304765691",
    	Alien = "rbxassetid://100086952632290",
    	AlienWorld = "rbxassetid://87236160288270",
    	Friend = "rbxassetid://119241439260453",
    	GoldenMachine = "rbxassetid://89755227786755",
    	DiamondMachine = "rbxassetid://104055285862160",
    	Locked = "rbxassetid://84295863471775",
    }
    
    
    local Items = {}
    Items.UpgradeIcons = {
    	CoinsUpgrades = "rbxassetid://95927549665227",
    	RubiesUpgrades = "rbxassetid://138865171141488",
    	LuckUpgrades = "rbxassetid://132488468387434",
    	HatchSpeedUpgrades = "rbxassetid://133053768789192",
    	CriticalUpgrades = "rbxassetid://82662945203714",
    	PetSpeedUpgrades = "rbxassetid://100363742710549",
    }
    Items.Icons = {
    	Apple = "rbxassetid://70708194006171",
    	Banana = "rbxassetid://97535372787407",
    	Blueberry = "rbxassetid://138254320661444",
    	Kiwi = "rbxassetid://117371466813201",
    	Mango = "rbxassetid://107115747681754",
    	Taco = "rbxassetid://127963655925153",
    	BasicLuckyblock = "rbxassetid://106015528786903",
    	RareLuckyblock = "rbxassetid://109896699605258",
    	CoinsPotion = "rbxassetid://74073388370838",
    	CriticalPotion = "rbxassetid://78981300946160",
    	HatchSpeedPotion = "rbxassetid://85307373584032",
    	LuckPotion = "rbxassetid://125294717108446",
    	RubiesPotion = "rbxassetid://74007921496995",
    	CoinsPotion2 = "rbxassetid://110856240912578",
    	CriticalPotion2 = "rbxassetid://137741464191957",
    	HatchSpeedPotion2 = "rbxassetid://96741767929090",
    	LuckPotion2 = "rbxassetid://84068759314461",
    	RubiesPotion2 = "rbxassetid://131621503426322",
    	CoinsPotion3 = "rbxassetid://89714157203824",
    	CriticalPotion3 = "rbxassetid://110966098282737",
    	HatchSpeedPotion3 = "rbxassetid://135086975055534",
    	LuckPotion3 = "rbxassetid://124475972008789",
    	RubiesPotion3 = "rbxassetid://93679648843782",
    	HackerLuckyblock = "rbxassetid://109896699605258",
    	CoinsCharm1 = "rbxassetid://95495350862854",
    	CoinsCharm2 = "rbxassetid://88238390070969",
    	CoinsCharm3 = "rbxassetid://138196072341139",
    	CoinsCharm4 = "rbxassetid://115186559802367",
    	CriticalCharm1 = "rbxassetid://103961231099924",
    	CriticalCharm2 = "rbxassetid://110272908383217",
    	CriticalCharm3 = "rbxassetid://82111029988349",
    	CriticalCharm4 = "rbxassetid://74872062148038",
    	LuckCharm1 = "rbxassetid://86489964542801",
    	LuckCharm2 = "rbxassetid://115940569640651",
    	LuckCharm3 = "rbxassetid://114179494103516",
    	LuckCharm4 = "rbxassetid://74842884052361",
    	HatchCharm1 = "rbxassetid://114647924469682",
    	HatchCharm2 = "rbxassetid://74608750730021",
    	HatchCharm3 = "rbxassetid://109517927048154",
    	HatchCharm4 = "rbxassetid://113546906203990",
    	RubiesCharm1 = "rbxassetid://114480367033159",
    	RubiesCharm2 = "rbxassetid://109404243120231",
    	RubiesCharm3 = "rbxassetid://70699652537956",
    	RubiesCharm4 = "rbxassetid://90045909460113",
    }
    
    Items.Fruits = { "Apple", "Banana", "Blueberry", "Kiwi", "Mango", "Taco" }
    Items.FruitSeconds = { Apple = 180, Banana = 180, Blueberry = 180, Kiwi = 180, Mango = 180, Taco = 60 }
    Items.Potions = {
    	"LuckPotion3", "CoinsPotion3", "RubiesPotion3", "HatchSpeedPotion3", "CriticalPotion3",
    	"LuckPotion2", "CoinsPotion2", "RubiesPotion2", "HatchSpeedPotion2", "CriticalPotion2",
    	"LuckPotion", "CoinsPotion", "RubiesPotion", "HatchSpeedPotion", "CriticalPotion",
    }
    Items.Lucky = { "BasicLuckyblock", "RareLuckyblock", "HackerLuckyblock" }
    Items.HuntRarities = { "Basic", "Rare", "Epic", "Legendary", "Mythical" }
    Items.Rarities = { "Basic", "Rare", "Epic", "Legendary", "Mythical", "Exclusive", "Secret" }
    Items.PotionSeconds = { LuckPotion3 = 600, CoinsPotion3 = 600, RubiesPotion3 = 600, HatchSpeedPotion3 = 600, CriticalPotion3 = 600 }
    
    function Auto.itemDisplayName(name)
    	name = tostring(name)
    	local kind = string.match(name, "^(%a+)Luckyblock$")
    	if kind then
    		return kind .. " Lucky Block"
    	end
    	local base, digit = string.match(name, "^(.-)(%d)$")
    	local roman = if base and base ~= "" then ({ "I", "II", "III", "IV", "V" })[tonumber(digit)] else nil
    	if not roman then
    		base = name
    	end
    	base = string.gsub(base, "(%l)(%u)", "%1 %2")
    	return if roman then base .. " " .. roman else base
    end
    
    function Auto.potionTier(name)
    	local base, digit = string.match(tostring(name), "^(.-)([23])$")
    	if base and base ~= "" then
    		return base, tonumber(digit)
    	end
    	return tostring(name), 1
    end
    
    function Auto.higherPotions(name)
    	local base, tier = Auto.potionTier(name)
    	local list = {}
    	for level = tier + 1, 3 do
    		table.insert(list, base .. tostring(level))
    	end
    	return list
    end
    
    function Auto.buildRecipes()
    	local kinds = { "Coins", "Rubies", "Luck", "Critical", "Hatch" }
    	local fruits = { Rubies = "Apple", Coins = "Banana", Hatch = "Blueberry", Luck = "Kiwi", Critical = "Mango" }
    	local potions = { Coins = "CoinsPotion", Rubies = "RubiesPotion", Luck = "LuckPotion", Critical = "CriticalPotion", Hatch = "HatchSpeedPotion" }
    	local list = {}
    	local function add(id, result, category, kind, item, amount, fruit, fruitAmount, rubies)
    		table.insert(list, {
    			Id = id,
    			Result = result,
    			Category = category,
    			Order = #list + 1,
    			Costs = {
    				{ Kind = kind, Item = item, Amount = amount },
    				{ Kind = "Fruit", Item = fruit, Amount = fruitAmount },
    				{ Kind = "Currency", Item = "Rubies", Amount = rubies },
    			},
    		})
    	end
    	for _, kind in ipairs(kinds) do
    		local potion, fruit = potions[kind], fruits[kind]
    		add("Potion_" .. kind, potion .. "2", "Potions", "Potion", potion, 5, fruit, 5, 25000)
    		add("Potion_" .. kind .. "_3", potion .. "3", "Potions", "Potion", potion .. "2", 3, fruit, 25, 250000)
    	end
    	for _, kind in ipairs(kinds) do
    		local fruit = fruits[kind]
    		add("Charm_" .. kind .. "_2", kind .. "Charm2", "Charms", "Charm", kind .. "Charm1", 5, fruit, 25, 500000)
    		add("Charm_" .. kind .. "_3", kind .. "Charm3", "Charms", "Charm", kind .. "Charm2", 3, fruit, 100, 5000000)
    		add("Charm_" .. kind .. "_4", kind .. "Charm4", "Charms", "Charm", kind .. "Charm3", 3, fruit, 1000, 50000000)
    	end
    	return list
    end
    
    Auto.Mutations = {
    	UpsideDown = { "Upside Down", "#c77dff" },
    	Taco = { "Taco", "#ffb84d" },
    	Wet = { "Wet", "#5fb8ff" },
    	UFO = { "UFO", "#7dffb3" },
    	Hacker = { "Hacker", "#39ff14" },
    	Rainbow = { "Rainbow", "#ff8de1" },
    }
    
    function Auto.mutationInfo(text)
    	if type(text) ~= "string" or text == "" then return nil end
    	local names, first = {}, nil
    	for id in string.gmatch(text, "[^+|]+") do
    		local def = Auto.Mutations[id]
    		first = first or def
    		table.insert(names, if def then def[1] else (string.gsub(id, "(%l)(%u)", "%1 %2")))
    	end
    	if #names == 0 then return nil end
    	return table.concat(names, " "), if first then first[2] else "#b692ff", names[1]
    end
    
    Items.DisplayToItem = {}
    function Auto.displayList(names)
    	local list, images = {}, {}
    	for _, name in ipairs(names) do
    		local display = Auto.itemDisplayName(name)
    		Items.DisplayToItem[display] = name
    		table.insert(list, display)
    		images[display] = Items.Icons[name]
    	end
    	return list, images
    end
    
    function Auto.pickFromMulti(value)
    	local pick = {}
    	if type(value) == "table" then
    		for display, on in pairs(value) do
    			if on then
    				pick[Items.DisplayToItem[display] or display] = true
    			end
    		end
    	end
    	return pick
    end
    local EggImages = {
    	["Party Egg"] = "rbxassetid://131513271419666",
    	["Alien Egg"] = "rbxassetid://123226572543807",
    	["Galaxy Egg"] = "rbxassetid://136821806756670",
    }
    
    local EggVisualCache = {}
    local function getEggVisual(name)
    	if type(name) ~= "string" or name == "" then return nil end
    	if EggImages[name] then return EggImages[name] end
    	local cached = EggVisualCache[name]
    	if cached and cached.Parent then return cached end
    	local found
    	pcall(function()
    		local map = workspace:FindFirstChild("Map")
    		local eggs = map and map:FindFirstChild("Eggs")
    		local model = eggs and eggs:FindFirstChild(name)
    		if not model then return end
    		local eggModel = model:FindFirstChild("EggModel")
    		local mesh = eggModel and (eggModel:FindFirstChild("Mesh") or eggModel:FindFirstChildWhichIsA("MeshPart"))
    		if mesh and mesh:IsA("BasePart") then
    			found = mesh
    			return
    		end
    		for _, d in ipairs(model:GetDescendants()) do
    			if d:IsA("MeshPart") and d.TextureID ~= "" and not d:FindFirstAncestor("Pad") then
    				found = d
    				return
    			end
    		end
    	end)
    	EggVisualCache[name] = found
    	return found
    end
    
    local function getEggVisuals(names)
    	local map = {}
    	for _, name in ipairs(names) do
    		local visual = getEggVisual(name)
    		if visual then
    			map[name] = visual
    		end
    	end
    	return map
    end
    
    local Session = {
    	started = os.clock(),
    	earned = { Coins = 0, Rubies = 0, Gems = 0 },
    	eggs = 0,
    }
    
    local HttpService = game:GetService("HttpService")
    local SaveFolder = "Corvus"
    local SaveFile = SaveFolder .. "/PetsUniverse_stats.json"
    
    local function newEarnings()
    	return { Coins = 0, Rubies = 0, Gems = 0 }
    end
    
    local Saved = {
    	earnings = newEarnings(),
    	earningsSince = os.time(),
    	eggs = 0,
    	partyEggs = 0,
    	gifts = 0,
    	rewardsSince = os.time(),
    	farmTime = 0,
    	broken = 0,
    	eggsSince = os.time(),
    	rarity = {},
    	hatched = {},
    	fruitBuys = 0,
    	fruitsBought = 0,
    	groupChests = 0,
    	moonChests = 0,
    	fruitsUsed = 0,
    	potionsUsed = 0,
    	luckyOpened = 0,
    	goldenCrafts = 0,
    	diamondCrafts = 0,
    	questsClaimed = 0,
    	upgradesBought = 0,
    	ufoHits = 0,
    	ufoBroken = 0,
    	worldsBought = 0,
    	webhooksSent = 0,
    	treeBought = 0,
    	specialBought = 0,
    	rebirthsDone = 0,
    	bensFound = 0,
    	codesRedeemed = 0,
    	codes = {},
    	lastTierAt = {},
    	luckStart = -1,
    	itemsSince = os.time(),
    	goals = {},
    	setupDone = false,
    	feedbackDay = "",
    	feedbackCount = 0,
    	feedbackAt = 0,
    	serverLuckBuys = 0,
    	itemsCrafted = 0,
    	mutated = 0,
    	fishCaught = 0,
    	fishRare = 0,
    	fishSold = 0,
    	tokensEarned = 0,
    	merchantBought = 0,
    	fishTreeBought = 0,
    	invEggsOpened = 0,
    	fishSince = os.time(),
    	ufoWon = 0,
    	ufoTop3 = 0,
    	ufoPetFarm = -1,
    	ufoPetWon = 0,
    	ufoBeforeRate = -1,
    	petStrikeKicked = 0,
    }
    
    pcall(function()
    	if type(isfile) == "function" and type(readfile) == "function" and isfile(SaveFile) then
    		local data = HttpService:JSONDecode(readfile(SaveFile))
    		if type(data) == "table" then
    			for key, value in pairs(data) do
    				if Saved[key] ~= nil and type(value) == type(Saved[key]) then
    					Saved[key] = value
    				end
    			end
    		end
    	end
    end)
    for _, name in ipairs({ "Coins", "Rubies", "Gems" }) do
    	Saved.earnings[name] = tonumber(Saved.earnings[name]) or 0
    end
    if (tonumber(Saved.luckStart) or -1) < 0 then
    	Saved.luckStart = tonumber(Saved.eggs) or 0
    end
    if (tonumber(Saved.ufoPetFarm) or -1) < 0 then
    	local farm = tonumber(Saved.farmTime) or 0
    	Saved.ufoPetFarm = farm
    	Saved.ufoPetWon = tonumber(Saved.ufoWon) or 0
    	Saved.ufoBeforeRate = if farm >= 1800 then (tonumber(Saved.ufoWon) or 0) / (farm / 3600) else -1
    end
    
    local Clock = 0
    local SaveDirty = false
    local LastSave = 0
    local function saveStats(force)
    	if not force and (not SaveDirty or Clock - LastSave < 10) then return end
    	SaveDirty = false
    	LastSave = Clock
    	pcall(function()
    		if type(writefile) ~= "function" then return end
    		if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(SaveFolder) then
    			makefolder(SaveFolder)
    		end
    		writefile(SaveFile, HttpService:JSONEncode(Saved))
    	end)
    end
    
    local function notify(Title, Text, Time)
    	Library:Notify({
    		Title = Title,
    		Description = Text,
    		Time = Time or 3,
    	})
    end
    
    local function formatTime(sec)
    	sec = math.max(0, math.floor(sec))
    	local m = math.floor(sec / 60)
    	local s = sec % 60
    	if m > 0 then
    		return string.format("%dm %02ds", m, s)
    	end
    	return string.format("%ds", s)
    end
    
    local function getCurrency(model)
    	if BreakableEffects and BreakableEffects.GetCurrency then
    		local ok, cur = pcall(BreakableEffects.GetCurrency, model)
    		if ok and type(cur) == "string" then return cur end
    	end
    	local pn = model.Parent and model.Parent.Name or ""
    	local mn = model.Name or ""
    	if pn:lower():find("ruby") or mn:lower():find("ruby") then return "Rubies" end
    	if pn:lower():find("fruit") or mn:lower():find("fruit") then return "Fruits" end
    	return "Coins"
    end
    
    local currencyCache = setmetatable({}, { __mode = "k" })
    local function getCurrencySafe(model)
    	local c = currencyCache[model]
    	if c then return c end
    	local ok, cur = pcall(getCurrency, model)
    	if ok and type(cur) == "string" then
    		currencyCache[model] = cur
    		return cur
    	end
    	return "Coins"
    end
    
    local function isPriorityCurrency(cur)
    	return not cur:lower():find("coin")
    end
    
    local function getZoneBreakables(zone)
    	local list = {}
    	if not Breakables then return list end
    	local folder = zone ~= "" and Breakables:FindFirstChild(zone)
    	if folder then
    		for _, m in ipairs(folder:GetChildren()) do
    			if m:IsA("Model") then table.insert(list, m) end
    		end
    	else
    		for _, f in ipairs(Breakables:GetChildren()) do
    			if f:IsA("Folder") then
    				for _, m in ipairs(f:GetChildren()) do
    					if m:IsA("Model") then table.insert(list, m) end
    				end
    			end
    		end
    	end
    	return list
    end
    
    local posCache = setmetatable({}, { __mode = "k" })
    local function getModelPosition(model)
    	local c = posCache[model]
    	local now = os.clock()
    	if c and (now - c.at) < 0.25 then return c.pos end
    	local pp = model.PrimaryPart
    		or model:FindFirstChild("Primary")
    		or model:FindFirstChildWhichIsA("BasePart", true)
    	local pos = nil
    	if pp then
    		pos = pp.Position
    	else
    		local ok, pivot = pcall(model.GetPivot, model)
    		if ok and pivot then pos = pivot.Position end
    	end
    	if pos then posCache[model] = { pos = pos, at = now } end
    	return pos
    end
    
    local function parseHPFromText(text)
    	if type(text) ~= "string" then return nil end
    	local clean = text:gsub("[,%s]", "")
    	local num = tonumber(clean:match("^(%d+)") or clean:match("(%d+)"))
    	if num and num >= 0 and num == num then return num end
    	return nil
    end
    
    local function readBreakableHP(model)
    	local damageUI = model:FindFirstChild("DamageUI")
    	if damageUI then
    		local frame = damageUI:FindFirstChild("Frame")
    		if frame then
    			local hp = frame:FindFirstChild("Hp")
    			if hp then
    				local v = hp.Value
    				if typeof(v) == "number" and v == v and v >= 0 then
    					return v
    				end
    			end
    		end
    	end
    
    	for _, attr in ipairs({ "Hp", "HP", "Health" }) do
    		local v = model:GetAttribute(attr)
    		if typeof(v) == "number" and v == v and v >= 0 then
    			return v
    		end
    	end
    
    	for _, d in ipairs(model:GetDescendants()) do
    		if d:IsA("NumberValue") or d:IsA("IntValue") then
    			local n = d.Name:lower()
    			if n == "hp" or n == "health" then
    				local v = d.Value
    				if typeof(v) == "number" and v == v and v >= 0 then
    					return v
    				end
    			end
    		end
    	end
    
    	if damageUI then
    		local tl = damageUI:FindFirstChildWhichIsA("TextLabel", true)
    		if tl then
    			local n = parseHPFromText(tl.Text)
    			if n then return n end
    		end
    	end
    
    	return nil
    end
    
    local hpCache = setmetatable({}, { __mode = "k" })
    local function getBreakableHP(model)
    	local c = hpCache[model]
    	local now = os.clock()
    	if c and (now - c.at) < 0.1 then return c.hp end
    	local hp = readBreakableHP(model)
    	hpCache[model] = { hp = hp, at = now }
    	return hp
    end
    
    local function getCharPos()
    	local char = LocalPlayer.Character
    	if char then
    		local hrp = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
    		if hrp then return hrp.Position end
    		local ok, pivot = pcall(char.GetPivot, char)
    		if ok and pivot then return pivot.Position end
    	end
    	return Vector3.new()
    end
    
    local BURST = 12
    
    local claimTimes = setmetatable({}, { __mode = "k" })
    local function tryClaimBonus(model)
    	if not ClaimClickBonus then return end
    	local coinId = model:GetAttribute("CoinId")
    	if typeof(coinId) ~= "string" or coinId == "" then return end
    	local now = os.clock()
    	local t = claimTimes[model]
    	if t and (now - t) < 0.2 then return end
    	claimTimes[model] = now
    	pcall(function() ClaimClickBonus:FireServer(coinId) end)
    end
    
    local function clickTarget(model)
    	local cd = model:FindFirstChild("ClickDetector")
    	if not cd then return end
    	for _ = 1, BURST do
    		pcall(function() fireclickdetector(cd) end)
    	end
    	tryClaimBonus(model)
    end
    
    local zoneCache = { zone = nil, list = nil, at = 0 }
    local function getCachedBreakables(zone)
    	local now = os.clock()
    	if zoneCache.list and zoneCache.zone == zone and (now - zoneCache.at) < 0.1 then
    		return zoneCache.list
    	end
    	local list = getZoneBreakables(zone)
    	zoneCache.zone = zone
    	zoneCache.list = list
    	zoneCache.at = now
    	return list
    end
    
    local function getSortedTargets(list)
    	local origin = getCharPos()
    
    	local entries = {}
    	for _, m in ipairs(list) do
    		if m.Parent then
    			local pos = getModelPosition(m)
    			if pos then
    				entries[#entries + 1] = {
    					target = m,
    					dist = (pos - origin).Magnitude,
    					hp = getBreakableHP(m),
    				}
    			end
    		end
    	end
    
    	local prio, coins = {}, {}
    	for _, e in ipairs(entries) do
    		if isPriorityCurrency(getCurrencySafe(e.target)) then
    			prio[#prio + 1] = e
    		else
    			coins[#coins + 1] = e
    		end
    	end
    	entries = (#prio > 0) and prio or coins
    
    	local mode = S.targetMode
    	local useLowHP = (mode == "LowestHP")
    	local useHighHP = (mode == "HighestHP")
    
    	if useLowHP or useHighHP then
    		local withHP = {}
    		for _, e in ipairs(entries) do
    			if e.hp ~= nil then
    				withHP[#withHP + 1] = e
    			end
    		end
    		if #withHP > 0 then
    			entries = withHP
    		else
    			useLowHP = false
    			useHighHP = false
    		end
    	end
    
    	if useHighHP then
    		table.sort(entries, function(a, b) return a.hp > b.hp end)
    	elseif useLowHP then
    		table.sort(entries, function(a, b) return a.hp < b.hp end)
    	else
    		table.sort(entries, function(a, b) return a.dist < b.dist end)
    	end
    
    	return entries
    end
    
    local lockedTarget = nil
    local lastPickMode = nil
    
    local function isLockValid(m)
    	if not m or not m.Parent then return false end
    	local hp = getBreakableHP(m)
    	if hp ~= nil and hp <= 0 then return false end
    	return true
    end
    
    local function doClickPass()
    	if not alive() or not S.autoFarm then return end
    	if not PlayerData then return end
    
    	local bd
    	local ok = pcall(function() bd = PlayerData.Folder(LocalPlayer, "BreakableData") end)
    	if not ok or not bd then return end
    
    	local inArea = bd:FindFirstChild("InArea")
    	local autoBreak = bd:FindFirstChild("AutoBreaking")
    	local areaVal = bd:FindFirstChild("Area")
    	if not areaVal then return end
    
    	local zone = areaVal.Value
    	if zone ~= "" then
    		Stats.lastArea = zone
    	else
    		zone = Stats.lastArea
    	end
    
    	if autoBreak and not autoBreak.Value and SetAutoBreaking then
    		local now = os.clock()
    		if now - Stats.lastAutoFire > 3 then
    			Stats.lastAutoFire = now
    			pcall(function() SetAutoBreaking:FireServer(true) end)
    		end
    	end
    
    	if S.autoTap == false then
    		lockedTarget = nil
    		return
    	end
    
    	if zone == "" then return end
    
    	local list = getCachedBreakables(zone)
    
    	if lastPickMode ~= S.targetMode then
    		lastPickMode = S.targetMode
    		lockedTarget = nil
    	end
    
    	if lockedTarget and not isLockValid(lockedTarget) then
    		lockedTarget = nil
    		Auto.farmBroken = (Auto.farmBroken or 0) + 1
    	end
    
    	if not lockedTarget then
    		local entries = getSortedTargets(list)
    		if #entries > 0 then
    			lockedTarget = entries[1].target
    		end
    	end
    
    	if lockedTarget then
    		clickTarget(lockedTarget)
    	end
    end
    
    task.spawn(function()
    	while alive() do
    		RunService.Heartbeat:Wait()
    		pcall(doClickPass)
    	end
    end)
    
    for _, ev in ipairs({
    	RunService.PreSimulation,
    	RunService.PreAnimation,
    	RunService.PreRender,
    }) do
    	Library:GiveSignal(ev:Connect(function()
    		pcall(doClickPass)
    	end))
    end
    
    local function collectEggNames()
    	local names, seen = {}, {}
    	local map = workspace:FindFirstChild("Map")
    	local eggsFolder = map and map:FindFirstChild("Eggs")
    	if eggsFolder then
    		for _, child in ipairs(eggsFolder:GetChildren()) do
    			if child:IsA("Model") and not seen[child.Name] then
    				seen[child.Name] = true
    				table.insert(names, child.Name)
    			end
    		end
    	end
    	local eggsView = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("EggsView")
    	if eggsView then
    		for _, child in ipairs(eggsView:GetChildren()) do
    			if child:IsA("BillboardGui") and not seen[child.Name] then
    				seen[child.Name] = true
    				table.insert(names, child.Name)
    			end
    		end
    	end
    	table.sort(names)
    	return names
    end
    
    local partyElapsedRef
    
    local function locatePartyElapsed()
    	if not (PartyEggModule and PlayerData) then return nil end
    
    	if partyElapsedRef and partyElapsedRef.Parent then
    		return partyElapsedRef
    	end
    	partyElapsedRef = nil
    
    	local folderName = PartyEggModule.DataFolderName
    	local valueName = PartyEggModule.ElapsedValueName
    	if not folderName or not valueName then return nil end
    
    	local folder
    	pcall(function() folder = PlayerData.Folder(LocalPlayer, folderName) end)
    	if not folder then
    		pcall(function() folder = PlayerData.WaitForFolder(LocalPlayer, folderName, 1) end)
    	end
    	if not folder then
    		folder = LocalPlayer:FindFirstChild(folderName)
    	end
    	if not folder then return nil end
    
    	local value = folder:FindFirstChild(valueName)
    	if not value then return nil end
    
    	partyElapsedRef = value
    	return value
    end
    
    local DataFolderCache = {}
    local function getDataFolder(name)
    	local cached = DataFolderCache[name]
    	if cached and cached.Parent then
    		return cached
    	end
    	local folder
    	if PlayerData then
    		pcall(function() folder = PlayerData.Folder(LocalPlayer, name) end)
    	end
    	if not folder then
    		pcall(function()
    			local mirror = game:GetService("ReplicatedFirst"):FindFirstChild("PlayerDataMirror")
    			folder = mirror and mirror:FindFirstChild(name)
    		end)
    	end
    	if not folder then
    		folder = LocalPlayer:FindFirstChild(name)
    	end
    	DataFolderCache[name] = folder
    	return folder
    end
    
    function Auto.setGameSetting(key, value)
    	value = value == true
    	local folder = getDataFolder("Settings")
    	local current = folder and folder:FindFirstChild(key)
    	if current then
    		local ok, now = pcall(function() return current.Value end)
    		if ok and now == value then return true end
    	elseif ({ SkipLuckyBlockAnimation = false })[key] == value then
    		return true
    	end
    	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    	local settings = remotes and remotes:FindFirstChild("Settings")
    	local remote = settings and settings:FindFirstChild("ToggleSetting")
    	if not remote then return false end
    	return (pcall(function() remote:FireServer(key, value) end))
    end
    
    local function getPartyStatus()
    	if not PartyEggModule then return nil end
    
    	local required = tonumber(PartyEggModule.RequiredSeconds) or 0
    	if required <= 0 then
    		required = (tonumber(PartyEggModule.RequiredMinutes) or 0) * 60
    	end
    	if required <= 0 then return nil end
    
    	local elapsed = 0
    	local folder = getDataFolder(PartyEggModule.DataFolderName or "PartyEggData")
    	local ref = folder and folder:FindFirstChild(PartyEggModule.ElapsedValueName or "ElapsedSeconds")
    	if ref then
    		pcall(function() elapsed = tonumber(ref.Value) or 0 end)
    	end
    
    	return {
    		elapsed = elapsed,
    		required = required,
    		ready = elapsed >= required,
    		timeLeft = math.max(0, required - elapsed),
    	}
    end
    
    local GiftMinutes = { 5, 10, 20, 30, 45, 60, 75, 90, 120 }
    pcall(function()
    	local timers = require(ReplicatedStorage.Modules:WaitForChild("GiftsTimersModule", 5))
    	for i = 1, 9 do
    		local cfg = timers["Gift" .. i]
    		if type(cfg) == "table" and tonumber(cfg.Time) then
    			GiftMinutes[i] = tonumber(cfg.Time)
    		end
    	end
    end)
    local GiftState = { elapsed = 0, at = os.clock(), ready = {}, received = false }
    
    pcall(function()
    	local Tick = ReplicatedStorage.Packages.Knit.Services.PlaytimeGiftsService.RE:WaitForChild("Tick", 5)
    	Library:GiveSignal(Tick.OnClientEvent:Connect(function(elapsed, ready)
    		GiftState.received = true
    		GiftState.elapsed = tonumber(elapsed) or GiftState.elapsed
    		GiftState.at = os.clock()
    		if type(ready) == "table" then
    			GiftState.ready = ready
    		end
    	end))
    end)
    
    local function isGiftClaimed(folder, i)
    	local name = "Gift" .. i
    	if folder then
    		local v = folder:FindFirstChild(name)
    		if v then
    			local ok, val = pcall(function() return v.Value end)
    			if ok then return val == true end
    		end
    	end
    	return GiftState.ready[name] ~= nil and GiftState.ready[name] ~= false
    end
    
    local function getGiftStatus()
    	local folder = getDataFolder("PlaytimeGiftsData")
    	if not (folder or GiftState.received) then return nil end
    	local elapsed = GiftState.elapsed + (if GiftState.received then os.clock() - GiftState.at else 0)
    	local nextName, nextLeft = nil, math.huge
    	local claimable, claimed = 0, 0
    	for i = 1, 9 do
    		if isGiftClaimed(folder, i) then
    			claimed += 1
    		else
    			local left = GiftMinutes[i] * 60 - elapsed
    			if left <= 0 then
    				claimable += 1
    			elseif left < nextLeft then
    				nextLeft = left
    				nextName = i
    			end
    		end
    	end
    	return {
    		claimed = claimed,
    		claimable = claimable,
    		nextIndex = if GiftState.received then nextName else nil,
    		nextLeft = nextLeft,
    	}
    end
    
    local function getStat(name)
    	local folder = getDataFolder("Stats")
    	local value = folder and folder:FindFirstChild(name)
    	if not value then return nil end
    	local ok, v = pcall(function() return tonumber(value.Value) end)
    	return ok and v or nil
    end
    
    local Suffixes = { "", "k", "m", "b", "t", "Qd", "Qn", "sx", "Sp", "Oc", "No" }
    local function formatNumber(n)
    	n = tonumber(n) or 0
    	if n < 0 then return "-" .. formatNumber(-n) end
    	for i = 1, #Suffixes do
    		if n < 10 ^ (i * 3) then
    			return tostring(math.floor(n / (10 ^ ((i - 1) * 3) / 10)) / 10) .. Suffixes[i]
    		end
    	end
    	return string.format("%.1e", n)
    end
    
    local function getEggsOpenedTotal()
    	local folder = getDataFolder("EggsHatchedData")
    	if not folder then return nil end
    	local total = 0
    	for _, v in ipairs(folder:GetChildren()) do
    		local ok, n = pcall(function() return tonumber(v.Value) end)
    		if ok and n then
    			total += n
    		end
    	end
    	return total
    end
    
    local LastCurrency = {}
    local function trackCurrency(name, value)
    	local last = LastCurrency[name]
    	LastCurrency[name] = value
    	if last and value > last then
    		local gained = value - last
    		Saved.earnings[name] = (Saved.earnings[name] or 0) + gained
    		Session.earned[name] = (Session.earned[name] or 0) + gained
    		if Auto.Metrics then
    			Auto.Metrics.cum[name] = (Auto.Metrics.cum[name] or 0) + gained
    		end
    		SaveDirty = true
    	end
    end
    
    local LastEggTotal
    local function trackEggs(total)
    	if LastEggTotal and total > LastEggTotal and total - LastEggTotal < 5000 then
    		local opened = total - LastEggTotal
    		Saved.eggs += opened
    		Session.eggs += opened
    		if Auto.Metrics then
    			Auto.Metrics.cum.Eggs = (Auto.Metrics.cum.Eggs or 0) + opened
    		end
    		SaveDirty = true
    	end
    	LastEggTotal = total
    end
    
    local BestDirty = true
    local BestList = {}
    local function getBest()
    	if BestDirty then
    		BestDirty = false
    		BestList = {}
    		for name, entry in pairs(Saved.hatched) do
    			if type(entry) == "table" then
    				table.insert(BestList, {
    					name = name,
    					rarity = entry.rarity or "Basic",
    					rank = tonumber(entry.rank) or 0,
    					count = tonumber(entry.count) or 1,
    					at = tonumber(entry.at) or 0,
    				})
    			end
    		end
    		table.sort(BestList, function(x, y)
    			if x.rank ~= y.rank then return x.rank > y.rank end
    			return x.at > y.at
    		end)
    	end
    	return BestList
    end
    
    local HatchState = { waiting = false, lastFire = -1, status = "Off" }
    local NotifyQueue = {}
    
    local function recordHatch(list, egg)
    	if type(list) ~= "table" then return end
    	HatchState.waiting = false
    	HatchState.noAnswer = 0
    	HatchState.results = (HatchState.results or 0) + 1
    	if HatchState.results <= 3 then
    		Auto.log("HATCH", "ok", "egg=" .. tostring(egg or HatchState.lastEgg), "pets=" .. #list, "eggs=" .. tostring(Saved.eggs))
    	elseif Auto.logEvery then
    		Auto.logEvery("hatchok", 300, "HATCH", "ok", "egg=" .. tostring(egg or HatchState.lastEgg), "pets=" .. #list, "results=" .. HatchState.results, "eggs=" .. tostring(Saved.eggs))
    	end
    	local batch = {}
    	for _, pet in ipairs(list) do
    		local name = type(pet) == "table" and pet.Name or (type(pet) == "string" and pet) or nil
    		local mutation = type(pet) == "table" and type(pet.Mutations) == "string" and pet.Mutations ~= "" and pet.Mutations or nil
    		if type(name) == "string" and string.find(name, "|", 1, true) then
    			local base, extra = string.match(name, "^(.-)|(.*)$")
    			name = base
    			mutation = mutation or (if extra ~= "" then extra else nil)
    		end
    		if name then
    			local rarity = type(pet) == "table" and pet.Rarity or nil
    			if not rarity and PetDisplay and PetDisplay.GetRarity then
    				local ok, r = pcall(PetDisplay.GetRarity, name)
    				if ok then rarity = r end
    			end
    			rarity = tostring(rarity or "Basic")
    			local known = Auto.IndexSnap
    			local fresh = if known and known[name] ~= nil then known[name] == false else Saved.hatched[name] == nil
    			if known and known[name] ~= nil then
    				known[name] = true
    			end
    			table.insert(batch, { name = name, rarity = rarity, fresh = fresh, mutation = mutation })
    			if mutation then
    				Saved.mutated = (tonumber(Saved.mutated) or 0) + 1
    			end
    			Saved.rarity[rarity] = (tonumber(Saved.rarity[rarity]) or 0) + 1
    			Session.rarity = Session.rarity or {}
    			Session.rarity[rarity] = (Session.rarity[rarity] or 0) + 1
    			local rank = RarityRank[rarity] or 0
    			for tier, tierRank in pairs({ Legendary = 4, Mythical = 5, Secret = 7 }) do
    				if rank >= tierRank then
    					Saved.lastTierAt[tier] = Saved.eggs
    				end
    			end
    			if rank >= 5 and Auto.Metrics then
    				Auto.Metrics.event("Hatch", name .. "  \u{00B7}  " .. rarity, RarityColors[rarity])
    			end
    			local entry = Saved.hatched[name]
    			if type(entry) == "table" then
    				entry.count = (tonumber(entry.count) or 0) + 1
    				entry.at = os.time() + (os.clock() % 1)
    			else
    				Saved.hatched[name] = { rarity = rarity, rank = rank, count = 1, at = os.time() + (os.clock() % 1) }
    			end
    			BestDirty = true
    			SaveDirty = true
    			if Auto.onHatch then
    				pcall(Auto.onHatch, name, rarity, mutation)
    			end
    			if rank >= 5 then
    				table.insert(NotifyQueue, { "Hatched", string.format("%s%s  \u{00B7}  %s", if mutation then ((Auto.mutationInfo(mutation)) or "") .. " " else "", name, rarity) })
    			end
    		end
    	end
    	if #batch > 0 then
    		Auto.FeedRaw = Auto.FeedRaw or {}
    		table.insert(Auto.FeedRaw, { at = os.clock(), egg = egg, names = batch })
    		if #Auto.FeedRaw > 20 then
    			table.remove(Auto.FeedRaw, 1)
    		end
    	end
    end
    
    pcall(function()
    	local RE = ReplicatedStorage.Packages.Knit.Services.EggHatchService.RE
    	local Result = RE:WaitForChild("Result", 5)
    	Auto.hatchResult = Result
    	Auto.hatchHandler = function(list, _, egg)
    		recordHatch(list, if type(egg) == "string" and egg ~= "" then egg else nil)
    	end
    	Library:GiveSignal(Result.OnClientEvent:Connect(Auto.hatchHandler))
    end)
    pcall(function()
    	local RE = ReplicatedStorage.Packages.Knit.Services.ExclusiveEggsService.RE
    	local Result = RE:WaitForChild("HatchResult", 5)
    	Library:GiveSignal(Result.OnClientEvent:Connect(function(player, list)
    		if player == LocalPlayer then
    			recordHatch(list)
    			if Auto.onInvEggResult then
    				pcall(Auto.onInvEggResult, list)
    			end
    		end
    	end))
    end)
    
    local function getEggModel(name)
    	local map = workspace:FindFirstChild("Map")
    	local eggs = map and map:FindFirstChild("Eggs")
    	return eggs and eggs:FindFirstChild(name)
    end
    
    local function getEggDistance(model)
    	if EggRangeModule and EggRangeModule.GetDistance then
    		local ok, dist, valid = pcall(EggRangeModule.GetDistance, LocalPlayer, model)
    		if ok and valid and type(dist) == "number" then
    			return dist
    		end
    	end
    	local pos = getCharPos()
    	if not pos then return nil end
    	local ok, pivot = pcall(function() return model:GetPivot().Position end)
    	if not ok then return nil end
    	return (pos - pivot).Magnitude
    end
    
    local function getEggPrice(name)
    	if not EggPriceModule then return nil, false end
    	local free = false
    	if EggPriceModule.IsFreeEggsDisplay then
    		local ok, r = pcall(EggPriceModule.IsFreeEggsDisplay)
    		free = ok and r == true
    	end
    	local ok, price = pcall(EggPriceModule.GetPrice, LocalPlayer, name)
    	return (if ok and type(price) == "number" then price else nil), free
    end
    
    function Auto.eventEggConfig()
    	return Auto.lazyRequire("EventEggConfig", function()
    		local modules = ReplicatedStorage:FindFirstChild("Modules")
    		return modules and modules:FindFirstChild("EventEggConfig")
    	end)
    end
    
    function Auto.eggCurrency(name)
    	local config = Auto.eventEggConfig()
    	if type(config) == "table" and type(config.GetCurrency) == "function" then
    		local ok, currency = pcall(config.GetCurrency, name)
    		if ok and (currency == "Rubies" or currency == "Coins") then
    			return currency
    		end
    	end
    	return "Coins"
    end
    
    function Auto.eggEvent(name)
    	local config = Auto.eventEggConfig()
    	if type(config) ~= "table" or type(config.IsEventEgg) ~= "function" then
    		return nil
    	end
    	local okEvent, isEvent = pcall(config.IsEventEgg, name)
    	if not (okEvent and isEvent) then
    		return nil
    	end
    	local info = {}
    	local okAvailable, available = pcall(config.IsAvailable, name)
    	info.ended = okAvailable and available == false
    	local okLeft, left = pcall(config.GetRemaining, name)
    	info.left = if okLeft and type(left) == "number" then left else nil
    	local okWorld, world, display = pcall(config.GetRequiredWorld, name)
    	if okWorld and type(world) == "string" then
    		info.world = tostring(display or world)
    		local folder = getDataFolder("WorldsData")
    		local flag = folder and folder:FindFirstChild(if world == "Haunted" then "HauntedHouse" else world)
    		local okMet, met = pcall(function() return flag and flag.Value end)
    		info.locked = okMet and met == false
    	end
    	return info
    end
    
    function Auto.eggCombo()
    	local config = Auto.lazyRequire("EggLuckComboConfig", function()
    		local modules = ReplicatedStorage:FindFirstChild("Modules")
    		return modules and modules:FindFirstChild("EggLuckComboConfig")
    	end)
    	if type(config) ~= "table" or type(config.GetLevel) ~= "function" then
    		return nil
    	end
    	local okOwned, owned = pcall(config.HasUpgrade, LocalPlayer)
    	local okLevel, level = pcall(config.GetLevel, LocalPlayer)
    	level = if okLevel then tonumber(level) or 0 else 0
    	local okBonus, bonus = pcall(config.BonusForLevel, level)
    	return {
    		owned = okOwned and owned == true,
    		level = level,
    		max = math.max(1, tonumber(config.MAX_LEVEL) or 200),
    		bonus = if okBonus then tonumber(bonus) or 0 else 0,
    		maxBonus = tonumber(config.MAX_BONUS) or 0.1,
    	}
    end
    
    local EggRange = 34
    local function checkHatch(name)
    	if name == "" then
    		return false, "Select an egg"
    	end
    	local event = Auto.eggEvent(name)
    	if event and event.ended then
    		return false, "This event egg has left"
    	end
    	if event and event.locked then
    		return false, "Unlock " .. tostring(event.world) .. " first"
    	end
    	local model = getEggModel(name)
    	if not model then
    		return false, "Egg not in this world"
    	end
    	local dist = getEggDistance(model)
    	local limit = EggRange
    	if EggRangeModule and tonumber(EggRangeModule.SERVER_RANGE) then
    		limit = tonumber(EggRangeModule.SERVER_RANGE) - 2
    	end
    	if dist and dist > limit then
    		return false, string.format("Too far  \u{00B7}  %d studs", math.floor(dist))
    	end
    	local price, free = getEggPrice(name)
    	if price and not free then
    		local currency = Auto.eggCurrency(name)
    		local balance = getStat(currency)
    		if balance and balance < price then
    			return false, "Need " .. formatNumber(price) .. " " .. string.lower(currency)
    		end
    	end
    	return true, "Hatching"
    end
    
    function Auto.hatchPlan(name, mode, remaining)
    	local price, free = getEggPrice(name)
    	local folder = getDataFolder("TrustedStats")
    	local maxValue = folder and folder:FindFirstChild("MaxEggOpen")
    	local okMax, maxOpen = pcall(function() return maxValue and maxValue.Value end)
    	maxOpen = math.max(1, math.floor(tonumber(okMax and maxOpen or nil) or 1))
    	local paid = price ~= nil and price > 0 and not free
    	local currency = Auto.eggCurrency(name)
    	local balance = getStat(currency) or 0
    	local keep = if currency == "Rubies" then Auto.reserve("Rubies") else math.max(S.hatchKeepCoins or 0, S.worldSave or 0)
    	local canBuy = if paid then math.min(maxOpen, math.floor(balance / price)) else maxOpen
    	local budget = math.huge
    	if paid and keep > 0 then
    		budget = math.floor((balance - keep) / price)
    	end
    	local limit = math.min(budget, remaining or math.huge)
    	if limit < 1 then
    		return nil, if budget < 1 then "Keeping " .. formatNumber(keep) .. " " .. string.lower(currency) else "Done"
    	end
    	local counts = { Max = math.max(1, canBuy), Half = math.max(1, math.ceil(canBuy / 2)), Single = 1 }
    	local order = { "Max", "Half", "Single" }
    	local first = if mode == "Single" then 3 elseif mode == "Half" then 2 else 1
    	for i = first, 3 do
    		if counts[order[i]] <= limit then
    			return order[i], counts[order[i]]
    		end
    	end
    	return "Single", 1
    end
    
    function Auto.parseAmount(text)
    	text = string.lower(string.gsub(tostring(text or ""), "[%s,_]", ""))
    	local number, suffix = string.match(text, "^([%d%.]+)(%a*)$")
    	number = tonumber(number)
    	if not number then return nil end
    	local scale = { [""] = 1, k = 1e3, m = 1e6, b = 1e9, t = 1e12, qd = 1e15, qn = 1e18 }
    	if not scale[suffix] then return nil end
    	return math.floor(number * scale[suffix])
    end
    
    
    do
    	local M = {
    		fine = {},
    		coarse = {},
    		cum = { Coins = 0, Rubies = 0, Gems = 0, Eggs = 0 },
    		events = {},
    		lastFine = -1e9,
    		lastCoarse = -1e9,
    		lastSave = 0,
    		file = SaveFolder .. "/PetsUniverse_metrics.json",
    		T0 = os.time(),
    		C0 = os.clock(),
    	}
    	Auto.Metrics = M
    	local Columns = { Coins = 2, Rubies = 3, Gems = 4, Eggs = 5 }
    
    	function M.now()
    		return M.T0 + (os.clock() - M.C0)
    	end
    
    	pcall(function()
    		if type(isfile) == "function" and type(readfile) == "function" and isfile(M.file) then
    			local data = HttpService:JSONDecode(readfile(M.file))
    			if type(data) == "table" then
    				local cutoff = M.now() - 86400
    				local function restore(list, target)
    					if type(list) ~= "table" then return end
    					for _, row in ipairs(list) do
    						if type(row) == "table" and tonumber(row[1]) and row[1] >= cutoff then
    							table.insert(target, { tonumber(row[1]), tonumber(row[2]) or 0, tonumber(row[3]) or 0, tonumber(row[4]) or 0, tonumber(row[5]) or 0 })
    						end
    					end
    				end
    				restore(data.coarse, M.coarse)
    				restore(data.fine, M.fine)
    				if type(data.cum) == "table" then
    					for key in pairs(Columns) do
    						M.cum[key] = tonumber(data.cum[key]) or 0
    					end
    				end
    				if type(data.events) == "table" then
    					for _, event in ipairs(data.events) do
    						if type(event) == "table" and tonumber(event.t) and event.t >= cutoff then
    							table.insert(M.events, event)
    						end
    					end
    				end
    			end
    		end
    	end)
    
    	function M.save()
    		pcall(function()
    			if type(writefile) ~= "function" then return end
    			if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(SaveFolder) then
    				makefolder(SaveFolder)
    			end
    			writefile(M.file, HttpService:JSONEncode({ v = 1, cum = M.cum, fine = M.fine, coarse = M.coarse, events = M.events }))
    		end)
    	end
    
    	function M.sample(force)
    		local t = M.now()
    		local row = { t, M.cum.Coins, M.cum.Rubies, M.cum.Gems, M.cum.Eggs }
    		if force == true or t - M.lastFine >= 10 then
    			M.lastFine = t
    			table.insert(M.fine, row)
    			while #M.fine > 0 and M.fine[1][1] < t - 7200 do
    				table.remove(M.fine, 1)
    			end
    		end
    		if force == true or t - M.lastCoarse >= 60 then
    			M.lastCoarse = t
    			table.insert(M.coarse, row)
    			while #M.coarse > 0 and M.coarse[1][1] < t - 86400 do
    				table.remove(M.coarse, 1)
    			end
    		end
    		if t - M.lastSave >= 60 then
    			M.lastSave = t
    			M.save()
    		end
    	end
    
    	function M.valueAt(key, t)
    		local column = Columns[key]
    		if not column then return nil end
    		local now = M.now()
    		if t >= now - 0.5 then
    			return M.cum[key]
    		end
    		local list, step = M.fine, 10
    		if #list == 0 or t < list[1][1] then
    			list, step = M.coarse, 60
    		end
    		local count = #list
    		if count == 0 or t < list[1][1] then
    			return nil
    		end
    		local last = list[count]
    		if t >= last[1] then
    			if now - last[1] > step * 3 then
    				return nil
    			end
    			local span = now - last[1]
    			if span <= 0 then
    				return last[column]
    			end
    			return last[column] + (M.cum[key] - last[column]) * (t - last[1]) / span
    		end
    		local low, high = 1, count
    		while high - low > 1 do
    			local middle = (low + high) // 2
    			if list[middle][1] <= t then
    				low = middle
    			else
    				high = middle
    			end
    		end
    		local a, b = list[low], list[high]
    		if b[1] - a[1] > step * 3 then
    			return nil
    		end
    		if b[1] == a[1] then
    			return a[column]
    		end
    		return a[column] + (b[column] - a[column]) * (t - a[1]) / (b[1] - a[1])
    	end
    
    	function M.rate(key, t, window)
    		local a, b = M.valueAt(key, t - window), M.valueAt(key, t)
    		if a == nil or b == nil then
    			return nil
    		end
    		return math.max(0, (b - a) / window * 3600)
    	end
    
    	function M.series(key, range, count)
    		local now = M.now()
    		local window = math.max(range / count * 2, 60)
    		local values = {}
    		for i = 1, count do
    			local t = now - range + range * (i - 1) / math.max(count - 1, 1)
    			values[i] = M.rate(key, t, window) or false
    		end
    		return values
    	end
    
    	function M.current(key)
    		local window = math.clamp(M.now() - M.sessionStart, 30, 300)
    		if M.now() - M.sessionStart < 30 then
    			return nil
    		end
    		return M.rate(key, M.now(), window)
    	end
    
    	function M.mean(values)
    		local sum, count = 0, 0
    		for i = 1, #values do
    			local value = values[i]
    			if type(value) == "number" then
    				sum += value
    				count += 1
    			end
    		end
    		return if count > 0 then sum / count else nil
    	end
    
    	function M.event(kind, text, color)
    		table.insert(M.events, { t = M.now(), k = kind, x = tostring(text), c = color })
    		while #M.events > 200 do
    			table.remove(M.events, 1)
    		end
    	end
    
    	M.sessionStart = M.now()
    	M.sample(true)
    end
    
    Auto.GameData = { ready = false }
    task.spawn(function()
    	local data = Auto.GameData
    	local function load(parent, name)
    		local target = parent and parent:FindFirstChild(name)
    		if not target then return nil end
    		local ok, result = pcall(require, target)
    		if ok and type(result) == "table" then
    			return result
    		end
    		return nil
    	end
    	local modules = ReplicatedStorage:FindFirstChild("Modules")
    	pcall(function()
    		local icons = load(modules, "ItemsIcons")
    		if icons then
    			for key, value in pairs(icons) do
    				if type(key) == "string" and type(value) == "string" then
    					Items.Icons[key] = value
    				end
    			end
    		end
    	end)
    	pcall(function()
    		local fruits = load(modules, "FruitsModule")
    		if fruits then
    			local names = {}
    			for name, cfg in pairs(fruits) do
    				if type(name) == "string" and type(cfg) == "table" and tonumber(cfg.Time) then
    					table.insert(names, name)
    					Items.FruitSeconds[name] = tonumber(cfg.Time)
    				end
    			end
    			if #names > 0 then
    				table.sort(names)
    				Items.Fruits = names
    			end
    		end
    	end)
    	pcall(function()
    		local potions = load(modules, "PotionsModule")
    		if potions and type(potions.Tier1Names) == "table" then
    			local names = {}
    			for _, name in ipairs(potions.Tier3Names or {}) do
    				table.insert(names, name)
    			end
    			for _, name in ipairs(potions.Tier2Names or {}) do
    				table.insert(names, name)
    			end
    			for _, name in ipairs(potions.Tier1Names) do
    				table.insert(names, name)
    			end
    			for _, name in ipairs(names) do
    				local cfg = potions[name]
    				if type(cfg) == "table" and tonumber(cfg.Time) then
    					Items.PotionSeconds[name] = tonumber(cfg.Time)
    				end
    			end
    			if #names > 0 then
    				Items.Potions = names
    			end
    		end
    	end)
    	pcall(function()
    		local models = ReplicatedStorage:FindFirstChild("LuckyBlockModels")
    		if models then
    			local names = {}
    			for _, child in ipairs(models:GetChildren()) do
    				if string.find(string.lower(child.Name), "luckyblock", 1, true) then
    					table.insert(names, child.Name)
    				end
    			end
    			if #names > 0 then
    				table.sort(names)
    				Items.Lucky = names
    			end
    		end
    	end)
    	pcall(function()
    		local petsFolder = ReplicatedStorage:FindFirstChild("Pets")
    		local rarities = load(petsFolder, "Rarities")
    		if rarities then
    			local list = {}
    			for name, info in pairs(rarities) do
    				if type(name) == "string" and type(info) == "table" and tonumber(info[1]) then
    					table.insert(list, { name = name, rank = tonumber(info[1]) })
    					RarityRank[name] = tonumber(info[1])
    				end
    			end
    			table.sort(list, function(a, b) return a.rank < b.rank end)
    			if #list > 0 then
    				local all, hunt = {}, {}
    				for _, entry in ipairs(list) do
    					table.insert(all, entry.name)
    					if entry.name ~= "Exclusive" then
    						table.insert(hunt, entry.name)
    					end
    				end
    				Items.Rarities = all
    				Items.HuntRarities = hunt
    			end
    		end
    	end)
    	pcall(function()
    		local zones = load(modules, "WorldZones")
    		if zones and type(zones.Bounds) == "table" then
    			local bounds = {}
    			for name, b in pairs(zones.Bounds) do
    				if type(b) == "table" and tonumber(b.minX) then
    					bounds[name] = { tonumber(b.minX), tonumber(b.maxX), tonumber(b.minZ), tonumber(b.maxZ) }
    				end
    			end
    			data.bounds = bounds
    			data.worldOrder = if type(zones.Order) == "table" then table.clone(zones.Order) else nil
    			data.worldFolder = if type(zones.WorldFolder) == "table" then zones.WorldFolder else nil
    		end
    	end)
    	pcall(function()
    		data.worldCost = load(modules, "WorldCostConfig")
    	end)
    	pcall(function()
    		local mapWorld = load(modules, "MapWorldModule")
    		data.machineWorlds = mapWorld and mapWorld.MachineWorlds or nil
    	end)
    	pcall(function()
    		local group = load(modules, "GroupRewardsModule")
    		data.groupId = group and tonumber(group.GroupId) or nil
    	end)
    	pcall(function()
    		data.spawnUpgrades = load(ReplicatedStorage:FindFirstChild("UpgradesModule"), "UpgradesModule")
    	end)
    	pcall(function()
    		data.moonConfig = load(modules, "MoonUpgradesConfig")
    	end)
    	pcall(function()
    		local treeFolder = ReplicatedStorage:FindFirstChild("UpgradeTree")
    		local tree = load(treeFolder, "UpgradeTreeData")
    		if tree and type(tree.Groups) == "table" then
    			data.tree = tree
    			local boosts = load(treeFolder, "UpgradeTreeBoosts")
    			data.treeFolder = boosts and type(boosts.FOLDER_NAME) == "string" and boosts.FOLDER_NAME or "TreeData"
    			data.treeFlag = boosts and type(boosts.UNLOCK_SP_FLAG) == "string" and boosts.UNLOCK_SP_FLAG or "SP13"
    		end
    	end)
    	pcall(function()
    		local special = load(modules, "SpecialUpgradesModule")
    		if special then
    			local list = {}
    			for name, info in pairs(special) do
    				local index = type(name) == "string" and tonumber(string.match(name, "^Upgrade(%d+)$"))
    				if index and type(info) == "table" and tonumber(info.Price) then
    					table.insert(list, { name = name, index = index, price = tonumber(info.Price), title = tostring(info.Description or name), icon = info.IconID })
    				end
    			end
    			table.sort(list, function(a, b) return a.index < b.index end)
    			data.special = list
    		end
    		local mapWorld = load(modules, "MapWorldModule")
    		data.specialWorlds = mapWorld and mapWorld.SpecialUpgradeWorlds or nil
    	end)
    	pcall(function()
    		data.codes = load(modules, "CodesModule")
    	end)
    	pcall(function()
    		local multi = load(ReplicatedStorage:FindFirstChild("Pets"), "Multi")
    		if multi then
    			local names = {}
    			for name, info in pairs(multi) do
    				if type(name) == "string" and type(info) == "table" then
    					table.insert(names, name)
    				end
    			end
    			table.sort(names)
    			data.petNames = names
    			local icons = {}
    			for name, info in pairs(multi) do
    				if type(name) == "string" and type(info) == "table" and type(info[4]) == "string" then
    					icons[name] = info[4]
    				end
    			end
    			data.petIcons = icons
    		end
    	end)
    	pcall(function()
    		local fishing = ReplicatedStorage:FindFirstChild("Fishing")
    		local tree = load(fishing, "FishingTreeData")
    		if tree and type(tree.Groups) == "table" then
    			data.fishTree = tree
    		end
    		data.merchant = load(fishing, "MerchantConfig")
    	end)
    	data.ready = true
    end)
    do
    	local waited = 0
    	while not Auto.GameData.ready and waited < 6 do
    		waited += task.wait(0.1) or 0.1
    	end
    end
    
    local Window = Library:CreateWindow({
    	Title = "Corvus",
    	Author = "Cinek",
    	Theme = "Corvus Silver",
    	Icon = "corvus",
    	Footer = "",
    	FooterGame = true,
    	FooterLink = Discord,
    	NotifySide = "Right",
    	ShowCustomCursor = false,
    	ToggleKeybind = Enum.KeyCode.Z,
    })
    
    Library.ShareIgnore = { WebhookUrl = true, WebhookPingId = true, FeedbackText = true, CodeInput = true, GoalKind = true, GoalTarget = true, HatchEgg = true }
    
    local Tabs = {}
    
    Tabs.Info = Window:AddInfoTab({
    	Discord = Discord,
    	DiscordAvatar = "corvus-square",
    	DiscordBanner = "corvus-banner",
    	DiscordTitle = "Corvus",
    	DiscordDescription = "Keyless scripts, updates and support",
    	Feedback = function(Box)
    		Tabs.FeedbackBox = Box
    	end,
    })
    
    Tabs.Main = Window:AddTab({ Name = "Main", Icon = "house", Description = "Quick start, farm, UFO, worlds and status" })
    Tabs.Farm = Tabs.Main
    Tabs.Eggs = Window:AddTab({ Name = "Eggs", Icon = "egg", Description = "Auto buy eggs and index hunter" })
    Tabs.Fishing = Window:AddTab({ Name = "Fishing", Icon = "fish", Description = "Auto fish, bait, merchant and tokens" })
    Tabs.Ufo = Tabs.Main
    Tabs.Upgrades = Window:AddTab({ Name = "Upgrades", Icon = "trending-up", Description = "Spawn machine, trees, worlds and Moon shops" })
    Tabs.Rewards = Window:AddTab({ Name = "Rewards", Icon = "gift", Description = "Gifts, chests and the fruit machine" })
    Tabs.Items = Window:AddTab({ Name = "Items", Icon = "backpack", Description = "Fruits, potions, lucky blocks" })
    Tabs.Player = Tabs.Main
    Tabs.Stats = Window:AddTab({ Name = "Stats", Icon = "chart-column", Description = "Earnings, rewards, items and live analytics" })
    Tabs.Analytics = Tabs.Stats
    Tabs.Webhook = Window:AddTab({ Name = "Webhook", Icon = "webhook", Description = "Discord posts, pings and a live profile card" })
    Tabs.Misc = Window:AddMiscTab({
    	Description = "Performance, AFK, friends and webhook",
    	RejoinScript = Auto.loaderSource("reconnect"),
    })
    
    local StatCache = {}
    local function setStat(row, text, value, icon)
    	local cache = StatCache[row]
    	if not cache then
    		cache = {}
    		StatCache[row] = cache
    	end
    	if text ~= nil and cache.text ~= text then
    		if pcall(row.SetText, row, text) then cache.text = text end
    	end
    	if value ~= nil and cache.value ~= value then
    		if pcall(row.SetValue, row, value) then cache.value = value end
    	end
    	if icon ~= nil and cache.icon ~= icon then
    		if pcall(row.SetIcon, row, icon) then cache.icon = icon end
    	end
    end
    
    local function setVisible(element, visible)
    	if element.Visible ~= visible then
    		pcall(element.SetVisible, element, visible)
    	end
    end
    
    local LabelCache = {}
    local function setLabel(label, text)
    	if LabelCache[label] == text then return end
    	if pcall(label.SetText, label, text) then
    		LabelCache[label] = text
    	end
    end
    
    local DiagText = nil
    local DiagShown = {}
    local function diag(where, err)
    	if DiagShown[where] then return end
    	DiagShown[where] = true
    	Auto.log("PROBLEM", where, tostring(err))
    	DiagText = string.format('<font color="#ff6e8a">%s:</font> %s', where, tostring(err))
    end
    
    local EarnBox = Tabs.Stats:AddLeftGroupbox("Earnings", "coins")
    local EarnSinceLabel = EarnBox:AddLabel({ Text = "Counting since reset", DoesWrap = true })
    local DiagLabel = EarnBox:AddLabel({ Text = "", DoesWrap = true })
    pcall(DiagLabel.SetVisible, DiagLabel, false)
    local CurrencyRows = {}
    for _, name in ipairs({ "Coins", "Rubies", "Gems" }) do
    	CurrencyRows[name] = EarnBox:AddStat({ Icon = CurrencyIcons[name], Text = name, Value = "+0", Size = 28 })
    end
    EarnBox:AddDivider()
    local FarmTimeRow = EarnBox:AddStat({ Icon = GameIcons.Auto, Text = "Time farming", Value = "0m 00s", Size = 22, ValueColor = "FontColor" })
    local BrokenRow = EarnBox:AddStat({ Icon = CurrencyIcons.Coins, Text = "Targets broken", Value = "0", Size = 22 })
    EarnBox:AddButton({
    	Text = "Reset Earnings",
    	DoubleClick = true,
    	Tooltip = "Starts earnings, farm time and broken targets from zero",
    	Func = function()
    		Saved.earnings = newEarnings()
    		Saved.farmTime = 0
    		Saved.broken = 0
    		Saved.ufoPetFarm = 0
    		Saved.ufoPetWon = tonumber(Saved.ufoWon) or 0
    		Saved.earningsSince = os.time()
    		SaveDirty = true
    		saveStats(true)
    		notify("Stats", "Earnings reset", 3)
    	end,
    })
    
    local HatchStatsBox = Tabs.Stats:AddLeftGroupbox("Eggs", "egg")
    local EggsSinceLabel = HatchStatsBox:AddLabel({ Text = "Counting since reset", DoesWrap = true })
    local EggsOpenedRow = HatchStatsBox:AddStat({ Icon = GameIcons.Egg, Text = "Eggs opened", Value = "0", Size = 28 })
    local EggsSessionRow = HatchStatsBox:AddStat({ Icon = GameIcons.Egg, Text = "This session", Value = "0", Size = 22, ValueColor = "FontColor" })
    UI.GoldenStatRow = HatchStatsBox:AddStat({ Icon = GameIcons.Index, Text = "Golden crafted", Value = "0", Size = 22 })
    UI.DiamondStatRow = HatchStatsBox:AddStat({ Icon = GameIcons.Index, Text = "Diamond crafted", Value = "0", Size = 22 })
    UI.MutatedStatRow = HatchStatsBox:AddStat({ Icon = "sparkles", Text = "Mutated pets", Value = "0", Size = 22 })
    local RarityRows = {}
    for _, rarity in ipairs({ "Secret", "Exclusive", "Mythical", "Legendary", "Epic", "Rare", "Basic" }) do
    	local icon = Rarities and Rarities[rarity] and Rarities[rarity][2] or nil
    	RarityRows[rarity] = HatchStatsBox:AddStat({ Icon = icon, Text = rarity, Value = "0", Size = 22 })
    	pcall(RarityRows[rarity].SetVisible, RarityRows[rarity], false)
    end
    HatchStatsBox:AddButton({
    	Text = "Reset Eggs and Hatches",
    	DoubleClick = true,
    	Tooltip = "Starts eggs, rarities and best hatches from zero",
    	Func = function()
    		local progress = Saved.eggs - (HatchState.startEggs or Saved.eggs)
    		Saved.eggs = 0
    		HatchState.startEggs = -progress
    		Saved.lastTierAt = {}
    		Saved.luckStart = 0
    		Saved.rarity = {}
    		Saved.goldenCrafts = 0
    		Saved.diamondCrafts = 0
    		Saved.mutated = 0
    		Saved.hatched = {}
    		Saved.eggsSince = os.time()
    		BestDirty = true
    		SaveDirty = true
    		saveStats(true)
    		notify("Stats", "Eggs and best hatches reset", 3)
    	end,
    })
    
    local RewardsStatsBox = Tabs.Stats:AddRightGroupbox("Rewards", "gift")
    local RewardsSinceLabel = RewardsStatsBox:AddLabel({ Text = "Counting since reset", DoesWrap = true })
    local GiftStatRow = RewardsStatsBox:AddStat({ Icon = GameIcons.Gift, Text = "Gifts claimed", Value = "0", Size = 28 })
    local GiftSessionRow = RewardsStatsBox:AddStat({ Icon = GameIcons.Gift, Text = "This session", Value = "0", Size = 22, ValueColor = "FontColor" })
    local PartyStatRow = RewardsStatsBox:AddStat({ Icon = GameIcons.PartyEgg, Text = "Party eggs claimed", Value = "0", Size = 28 })
    UI.FruitBuyStatRow = RewardsStatsBox:AddStat({ Icon = GameIcons.FruitMachine, Text = "Fruit machine buys", Value = "0", Size = 28 })
    UI.FruitGotStatRow = RewardsStatsBox:AddStat({ Icon = Items.Icons.Apple, Text = "Fruits from machine", Value = "0", Size = 22, ValueColor = "FontColor" })
    UI.GroupStatRow = RewardsStatsBox:AddStat({ Icon = GameIcons.GroupChest, Text = "Group chests", Value = "0", Size = 28 })
    UI.MoonStatRow = RewardsStatsBox:AddStat({ Icon = GameIcons.MoonChest, Text = "Moon chests", Value = "0", Size = 28 })
    UI.UfoStatRow = RewardsStatsBox:AddStat({ Icon = GameIcons.Alien, Text = "UFOs helped", Value = "0", Size = 28 })
    UI.UfoWonStatRow = RewardsStatsBox:AddStat({ Icon = "trophy", Text = "UFOs won  /  top 3", Value = "0 / 0", Size = 22 })
    UI.UfoRateStatRow = RewardsStatsBox:AddStat({ Icon = GameIcons.Alien, Text = "Alien Eggs / h  before  /  with pet hits", Value = "- / -", Size = 22 })
    UI.UpgradeStatRow = RewardsStatsBox:AddStat({ Icon = "trending-up", Text = "Upgrades bought", Value = "0", Size = 22 })
    UI.WorldStatRow = RewardsStatsBox:AddStat({ Icon = "globe", Text = "Worlds bought", Value = "0", Size = 22 })
    UI.TreeStatRow = RewardsStatsBox:AddStat({ Icon = "git-branch", Text = "Tree nodes bought", Value = "0", Size = 22 })
    UI.SpecialStatRow = RewardsStatsBox:AddStat({ Icon = "sparkle", Text = "Special upgrades", Value = "0", Size = 22 })
    UI.RebirthStatRow = RewardsStatsBox:AddStat({ Icon = "orbit", Text = "Moon rebirths done", Value = "0", Size = 22 })
    UI.CodeStatRow = RewardsStatsBox:AddStat({ Icon = "ticket", Text = "Codes redeemed", Value = "0", Size = 22 })
    RewardsStatsBox:AddButton({
    	Text = "Reset Rewards",
    	DoubleClick = true,
    	Tooltip = "Starts gifts, party eggs, chests and fruit machine from zero",
    	Func = function()
    		Saved.gifts = 0
    		Saved.partyEggs = 0
    		Saved.fruitBuys = 0
    		Saved.fruitsBought = 0
    		Saved.groupChests = 0
    		Saved.moonChests = 0
    		Saved.ufoBroken = 0
    		Saved.ufoHits = 0
    		Saved.ufoWon = 0
    		Saved.ufoTop3 = 0
    		Saved.ufoPetWon = 0
    		Saved.ufoPetFarm = tonumber(Saved.farmTime) or 0
    		Saved.upgradesBought = 0
    		Saved.worldsBought = 0
    		Saved.treeBought = 0
    		Saved.specialBought = 0
    		Saved.rebirthsDone = 0
    		Saved.rewardsSince = os.time()
    		SaveDirty = true
    		saveStats(true)
    		notify("Stats", "Rewards reset", 3)
    	end,
    })
    
    UI.ItemsStatsBox = Tabs.Stats:AddLeftGroupbox("Items", "backpack")
    UI.ItemsSinceLabel = UI.ItemsStatsBox:AddLabel({ Text = "Counting since reset", DoesWrap = true })
    UI.FruitsUsedRow = UI.ItemsStatsBox:AddStat({ Icon = Items.Icons.Mango, Text = "Fruits used", Value = "0", Size = 28 })
    UI.PotionsUsedRow = UI.ItemsStatsBox:AddStat({ Icon = Items.Icons.LuckPotion, Text = "Potions used", Value = "0", Size = 28 })
    UI.LuckyOpenedRow = UI.ItemsStatsBox:AddStat({ Icon = Items.Icons.RareLuckyblock, Text = "Lucky blocks opened", Value = "0", Size = 28 })
    UI.ItemsStatsBox:AddButton({
    	Text = "Reset Items",
    	DoubleClick = true,
    	Tooltip = "Starts fruits, potions and lucky blocks from zero",
    	Func = function()
    		Saved.fruitsUsed = 0
    		Saved.potionsUsed = 0
    		Saved.luckyOpened = 0
    		Saved.itemsSince = os.time()
    		SaveDirty = true
    		saveStats(true)
    		notify("Stats", "Items reset", 3)
    	end,
    })
    
    local BestBox = Tabs.Stats:AddRightGroupbox("Best Hatches", "sparkles")
    local BestEmpty = BestBox:AddLabel({ Text = "Hatch an egg to see your best pets here.", DoesWrap = true })
    local BestRows = {}
    for i = 1, 8 do
    	local row = BestBox:AddStat({ Text = "", Value = "", Size = 34 })
    	pcall(row.SetVisible, row, false)
    	BestRows[i] = row
    end
    
    UI.FishStatsBox = Tabs.Stats:AddRightGroupbox("Fishing", "fish")
    UI.FishSinceLabel = UI.FishStatsBox:AddLabel({ Text = "Counting since reset", DoesWrap = true })
    UI.FishCaughtStatRow = UI.FishStatsBox:AddStat({ Icon = "fish", Text = "Catches", Value = "0", Size = 28 })
    UI.FishRareStatRow = UI.FishStatsBox:AddStat({ Icon = "sparkles", Text = "Rare and golden catches", Value = "0", Size = 22 })
    UI.FishSoldStatRow = UI.FishStatsBox:AddStat({ Icon = "store", Text = "Pets sold", Value = "0", Size = 22 })
    UI.TokensStatRow = UI.FishStatsBox:AddStat({ Icon = "rbxassetid://125389046620562", Text = "Tokens from selling", Value = "0", Size = 22 })
    UI.MerchantStatRow = UI.FishStatsBox:AddStat({ Icon = "shopping-cart", Text = "Merchant buys", Value = "0", Size = 22 })
    UI.FishTreeStatRow = UI.FishStatsBox:AddStat({ Icon = "git-branch", Text = "Fishing tree nodes", Value = "0", Size = 22 })
    UI.InvEggStatRow = UI.FishStatsBox:AddStat({ Icon = GameIcons.PartyEgg, Text = "Inventory eggs opened", Value = "0", Size = 22 })
    UI.FishStatsBox:AddButton({
    	Text = "Reset Fishing",
    	DoubleClick = true,
    	Tooltip = "Starts catches, sales, merchant buys and inventory eggs from zero",
    	Func = function()
    		for _, key in ipairs({ "fishCaught", "fishRare", "fishSold", "tokensEarned", "merchantBought", "fishTreeBought", "invEggsOpened" }) do
    			Saved[key] = 0
    		end
    		Saved.fishSince = os.time()
    		SaveDirty = true
    		saveStats(true)
    		notify("Stats", "Fishing stats reset", 3)
    	end,
    })
    
    -- every automatic toggle (Stop Everything switches these off); no master switch and no global planner
    Auto.farmNames = {
    	"AutoFarm", "AutoTap", "PetStrike", "FarmWorldOn", "AutoUfo", "UfoTravel", "UfoHop", "AutoBuyWorlds",
    	"AutoGift", "AutoPartyEgg", "AutoFruitMachine", "AutoGroupChest", "AutoMoonChest", "AutoKeyCraft",
    	"AutoVipChest", "AutoPartner", "AutoUniverseZone", "AutoQuests", "AutoBen", "AutoCodes", "AutoFriend",
    	"AutoFriendSend", "AutoFriendAccept", "AutoHatch", "EggSmart", "AutoInvEggs", "IndexHunter",
    	"AutoFruits", "AutoPotions", "AutoLucky", "AutoEquipBest", "AutoGolden", "AutoDiamond", "AutoFish", "FishSmart",
    	"FishIndexHunt", "FishIndexGolden", "FishTap", "AutoWorms", "AutoHooks", "AutoSellFish", "AutoMerchantBuy",
    	"AutoSpawnUpgrades", "AutoTree", "AutoSpecial", "AutoFishTree", "AutoMoonPerm", "AutoMoonIncr",
    	"MoonGameAuto", "AutoRebirth", "RebirthSmart", "SmartPlan", "AutoServerLuck", "AutoAdminChat", "AutoItemCraft", "AutoEventCraft",
    }
    -- the budget reserve of a currency (Rubies / Gems reserve inputs)
    function Auto.reserve(currency)
    	if currency == "Rubies" then
    		return tonumber(S.rubyReserve) or 0
    	elseif currency == "Gems" then
    		return tonumber(S.gemReserve) or 0
    	end
    	return 0
    end
    function Auto.stopEverything()
    	Auto.log("STOP", "everything")
    	for _, name in ipairs(Auto.farmNames) do
    		local toggle = Toggles[name]
    		if toggle and toggle.Value then
    			pcall(function() toggle:SetValue(false) end)
    		end
    	end
    	notify("Auto Farm", "Everything stopped", 4)
    end
    UI.AllBox = Tabs.Farm:AddLeftGroupbox("Quick Start", "rocket")
    -- one planner for the whole game: it decides and spends by payback on its own, it never switches other toggles
    UI.AllBox:AddToggle("SmartPlan", {
    	Text = "Smart Planner",
    	Description = "Plans and buys everything by payback",
    	Tooltip = "Runs the profit engine on the whole game with real odds and prices: picks and hatches the egg that adds the most income per coin, walks to it, equips the best team, farms in the best world, buys worlds (The Moon too), spawn, tree, special and Moon upgrades only when they pay back within 24 hours, times Moon rebirths, pauses fishing when farming pays more and uses admin events (luck, free eggs). Your upgrade picks and the ruby / gem reserves are respected. It farms and opens eggs by itself, even with every other switch off. Fishing, fusing, selling and items stay on their own switches.",
    	Default = false,
    	Callback = function(v)
    		S.farmOP = v == true
    		if not S.farmOP then
    			S.worldSave = 0
    		end
    		if Auto.drive then
    			pcall(Auto.drive)
    		end
    	end,
    })
    -- log a line at most once per gap seconds for the same key (refusal reasons, travel failures)
    function Auto.logEvery(key, gap, ...)
    	Auto.logAt = Auto.logAt or {}
    	local now = os.clock()
    	if now - (Auto.logAt[key] or -1e9) < gap then
    		return
    	end
    	Auto.logAt[key] = now
    	Auto.log(...)
    end
    -- Smart switches own their loop (the switches themselves never flip): Smart Planner farms and hatches,
    -- Smart Egg Pick hatches, Smart Fishing fishes and farms, Rebirth By Payback rebirths
    function Auto.drive()
    	local plan = S.farmOP == true
    	local rows = {
    		{ "AutoFarm", "autoFarm", plan or S.fishSmart == true },
    		{ "AutoTap", "autoTap", plan },
    		{ "AutoHatch", "autoHatch", plan or S.eggSmart == true },
    		{ "AutoFish", "autoFish", S.fishSmart == true },
    		{ "AutoRebirth", "autoRebirth", S.rebirthSmart == true },
    	}
    	for _, row in ipairs(rows) do
    		local toggle = Toggles[row[1]]
    		local user = toggle ~= nil and toggle.Value == true
    		local value = user or row[3]
    		if S[row[2]] ~= value then
    			S[row[2]] = value
    			Auto.log("DRIVE", row[2] .. "=" .. tostring(value), "by=" .. (if user then "switch" elseif value then "smart" else "off"))
    			if row[1] == "AutoFarm" then
    				if SetAutoBreaking then
    					pcall(function() SetAutoBreaking:FireServer(value) end)
    				end
    				if not value then
    					lockedTarget = nil
    				end
    			elseif row[1] == "AutoHatch" then
    				HatchState.waiting = false
    			end
    		end
    	end
    end
    task.spawn(function()
    	while alive() do
    		task.wait(1)
    		pcall(Auto.drive)
    		if Auto.farmPresence then
    			local ok, err = pcall(Auto.farmPresence)
    			if not ok then
    				Auto.logEvery("farmpresence", 300, "PROBLEM", "farm presence", tostring(err))
    			end
    		end
    	end
    end)
    -- what changed a toggle is always in the log: the saved config at start (AUTOLOAD) or the player (CLICK)
    Library.OnAutoload = function()
    	local names = {}
    	for name, toggle in pairs(Toggles) do
    		if toggle.Value == true then
    			table.insert(names, name)
    		end
    	end
    	table.sort(names)
    	Auto.log("AUTOLOAD", "toggles=" .. table.concat(names, ","))
    end
    Library.OnUserToggle = function(name, value)
    	Auto.log("CLICK", name .. "=" .. tostring(value))
    end

    local FarmBox = Tabs.Farm:AddLeftGroupbox("Farming", "swords")
    FarmBox:AddToggle("AutoFarm", {
    	Text = "Auto Farm",
    	Description = "Breaks everything at full speed",
    	Tooltip = "Rubies and fruits first, locks the target until it breaks, unlimited range",
    	Default = false,
    	Callback = function(v)
    		S.autoFarm = v
    		if SetAutoBreaking then
    			pcall(function() SetAutoBreaking:FireServer(v) end)
    		end
    		if not v then
    			lockedTarget = nil
    		end
    	end,
    })
    FarmBox:AddDropdown("TargetMode", {
    	Text = "Target Mode",
    	Tooltip = "How the next target is picked once the current one breaks",
    	Values = { "Closest", "Lowest HP", "Highest HP" },
    	Default = "Highest HP",
    	Callback = function(choice)
    		local map = {
    			["Closest"] = "Closest",
    			["Lowest HP"] = "LowestHP",
    			["Highest HP"] = "HighestHP",
    		}
    		S.targetMode = map[tostring(choice)] or "HighestHP"
    		lockedTarget = nil
    	end,
    })
    FarmBox:AddToggle("AutoTap", {
    	Text = "Auto Tap",
    	Description = "Taps the target so every pet hits it",
    	Tooltip = "On is the fastest: all your pets focus one breakable, rubies and fruits first. Off lets the game's auto mode send each pet to its own breakable.",
    	Default = false,
    	Callback = function(v)
    		S.autoTap = v
    		if not v then
    			lockedTarget = nil
    		end
    	end,
    })
    FarmBox:AddToggle("PetStrike", {
    	Text = "Pet Strikes Without Walking",
    	Description = "Test: walking pets hit at once. Try it on an alt first",
    	Tooltip = "Sends the game's own pet hit for pets that are still walking to their target, at each pet's attack speed. Needs Auto Farm. It checks itself every 60 seconds: if your coins and rubies per second do not rise, or the server rejects the hits, it switches off for this session. Test it on an alt account first.",
    	Default = false,
    	Callback = function(v)
    		S.petStrike = v == true
    	end,
    })
    FarmBox:AddDivider()
    FarmBox:AddToggle("FarmWorldOn", {
    	Text = "Farm In Best World",
    	Description = "Travels to your farm world and stays there",
    	Tooltip = "Goes back after egg trips, chests and other errands. Waits while Auto Hatch or the Index Hunter needs another world.",
    	Default = false,
    	Callback = function(v)
    		S.farmWorldOn = v
    	end,
    })
    UI.FarmWorldList = { "Best unlocked" }
    for _, key in ipairs(Auto.GameData.worldOrder or { "Spawn", "BirchForest", "TreasureDunes", "FrozenAlley", "HauntedHouse", "PetKingdom", "EnchantedGrove", "VolcanoHollow", "TheMoon" }) do
    	local cost = Auto.GameData.worldCost
    	table.insert(UI.FarmWorldList, cost and type(cost.DisplayNames) == "table" and cost.DisplayNames[key] or (string.gsub(key, "(%l)(%u)", "%1 %2")))
    end
    FarmBox:AddDropdown("FarmWorld", {
    	Text = "Farm World",
    	Values = UI.FarmWorldList,
    	Default = "Best unlocked",
    	Tooltip = "Best unlocked is your newest world except The Moon, which drops gems instead of coins. Pick The Moon by name to farm gems.",
    	Callback = function(v)
    		S.farmWorld = tostring(v or "Best unlocked")
    	end,
    })
    
    local StatusBox = Tabs.Farm:AddRightGroupbox("Status", "activity")
    local FarmStateRow = StatusBox:AddStat({ Icon = GameIcons.Auto, Text = "Auto Farm", Value = "Idle", Size = 26, ValueColor = "FontColor" })
    local TargetRow = StatusBox:AddStat({ Icon = CurrencyIcons.Coins, Text = "No target", Value = "", Size = 26 })
    local AreaRow = StatusBox:AddStat({ Icon = "map-pin", Text = "Area", Value = "unknown", Size = 22, ValueColor = "FontColor" })
    UI.FarmWorldRow = StatusBox:AddStat({ Icon = "globe", Text = "Farm world", Value = "Off", Size = 22, ValueColor = "FontColor" })
    UI.UpNextBox = Tabs.Farm:AddRightGroupbox("Up next", "list-checks")
    UI.UpNextLabel = UI.UpNextBox:AddLabel({ Text = "Switch on Smart Planner (or Smart Egg Pick, Auto Upgrade, Auto Buy Worlds) and the next steps show here.", DoesWrap = true })
    UI.UfoBox = Tabs.Ufo:AddRightGroupbox("UFO Event", "rocket")
    UI.UfoBox:AddToggle("AutoUfo", {
    	Text = "Auto Break UFO",
    	Description = "Hits the Alien Egg as fast as the game allows",
    	Tooltip = "The UFO egg has far more HP than normal breakables. This clicks it at the game's click speed while it is alive.",
    	Default = false,
    	Callback = function(v)
    		S.autoUfo = v
    	end,
    })
    UI.UfoBox:AddToggle("UfoTravel", {
    	Text = "Travel to the UFO",
    	Description = "Flies to its world when it lands",
    	Default = false,
    	Callback = function(v)
    		S.ufoTravel = v
    	end,
    })
    UI.UfoStateRow = UI.UfoBox:AddStat({ Icon = GameIcons.Alien, Text = "UFO", Value = "...", Size = 30 })
    UI.UfoHpRow = UI.UfoBox:AddStat({ Icon = GameIcons.AlienWorld, Text = "Health", Value = "-", Size = 22, Progress = 0 })
    UI.UfoRankRow = UI.UfoBox:AddStat({ Icon = "trophy", Text = "Your damage", Value = "-", Size = 22, ValueColor = "FontColor" })
    UI.UfoHitsRow = UI.UfoBox:AddStat({ Icon = GameIcons.Auto, Text = "Helped  /  won", Value = "0 / 0", Size = 22 })
    UI.UfoNextRow = UI.UfoBox:AddStat({ Icon = "clock", Text = "Next UFO", Value = "...", Size = 22, ValueColor = "FontColor" })
    UI.UfoBox:AddDivider()
    UI.UfoBox:AddToggle("UfoHop", {
    	Text = "UFO Server Hop",
    	Description = "Hops until a server has the UFO",
    	Tooltip = "Joins other servers until one has the UFO now or soon. If every server shares the same timer, it notices and waits instead of hopping for nothing.",
    	Default = false,
    	Callback = function(v)
    		S.ufoHop = v
    		if Auto.onUfoHop then
    			Auto.onUfoHop(v)
    		end
    	end,
    })
    UI.HopWindows = { ["UFO active now"] = 0, ["UFO within 1 min"] = 60, ["UFO within 3 min"] = 180, ["UFO within 5 min"] = 300 }
    UI.UfoBox:AddDropdown("UfoHopWindow", {
    	Text = "Hop until",
    	Values = { "UFO active now", "UFO within 1 min", "UFO within 3 min", "UFO within 5 min" },
    	Default = "UFO within 1 min",
    	Callback = function(v)
    		S.ufoHopWindow = UI.HopWindows[v] or 60
    	end,
    })
    UI.UfoBox:AddToggle("StayPrivate", {
    	Text = "Stay On Private Server",
    	Description = "Never hops away from a private server",
    	Tooltip = "After a hop you cannot come back to a private server, so every automatic hop is skipped while you are on one.",
    	Default = false,
    	Callback = function(v)
    		S.stayPrivate = v
    	end,
    })
    UI.UfoBox:AddToggle("UfoHopChase", {
    	Text = "Keep chasing",
    	Description = "Hops again after each UFO is down",
    	Default = false,
    	Callback = function(v)
    		S.ufoHopChase = v
    	end,
    })
    UI.UfoHopRow = UI.UfoBox:AddStat({ Icon = "radar", Text = "Hop", Value = "Off", Size = 22, ValueColor = "FontColor" })
    UI.UfoTimerRow = UI.UfoBox:AddStat({ Icon = "globe", Text = "Timer", Value = "checking...", Size = 22, ValueColor = "FontColor" })
    
    UI.WorldBox = Tabs.Player:AddLeftGroupbox("Worlds & Travel", "globe")
    UI.WorldList = {}
    UI.WorldKeys = {}
    UI.WorldOrder = {}
    for _, key in ipairs(Auto.GameData.worldOrder or { "Spawn", "BirchForest", "TreasureDunes", "FrozenAlley", "HauntedHouse", "PetKingdom", "EnchantedGrove", "VolcanoHollow", "TheMoon" }) do
    	local cost = Auto.GameData.worldCost
    	local display = cost and type(cost.DisplayNames) == "table" and cost.DisplayNames[key] or (string.gsub(key, "(%l)(%u)", "%1 %2"))
    	table.insert(UI.WorldList, display)
    	table.insert(UI.WorldOrder, key)
    	UI.WorldKeys[display] = key
    end
    UI.WorldBox:AddDropdown("TeleportWorld", {
    	Text = "World",
    	Values = UI.WorldList,
    	Default = UI.WorldList[1],
    	Callback = function() end,
    })
    UI.WorldBox:AddButton({
    	Text = "Teleport",
    	Tooltip = "Travels to the selected world if you own it",
    	Func = function()
    		local display = Options.TeleportWorld and Options.TeleportWorld.Value
    		local key = display and UI.WorldKeys[display]
    		if key and Auto.teleportTo then
    			Auto.teleportTo(key)
    		end
    	end,
    })
    UI.Places = {
    	{ label = "Upgrade Machine", machine = "Upgrades", fallback = "Spawn" },
    	{ label = "Group Chest", machine = "RewardChest", fallback = "Spawn" },
    	{ label = "Golden Machine", machine = "GoldenMachine", fallback = "BirchForest" },
    	{ label = "Fruit Machine", machine = "FruitMachine", fallback = "FrozenAlley" },
    	{ label = "Diamond Machine", machine = "DiamondMachine", fallback = "HauntedHouse" },
    	{ label = "Moon Chest", machine = "MoonChest", moon = true },
    	{ label = "Moon Rebirth", machine = "RebirthMoon", moon = true },
    	{ label = "Moon Permanent Shop", shop = "Permanent" },
    	{ label = "Moon Incremental Shop", shop = "Incremental" },
    }
    UI.PlaceList = {}
    for _, place in ipairs(UI.Places) do
    	table.insert(UI.PlaceList, place.label)
    end
    UI.WorldBox:AddDropdown("TeleportPlace", {
    	Text = "Place",
    	Values = UI.PlaceList,
    	Default = UI.PlaceList[1],
    	Callback = function() end,
    })
    UI.WorldBox:AddButton({
    	Text = "Go to place",
    	Tooltip = "Travels to the machine or shop and stands next to it",
    	Func = function()
    		local label = Options.TeleportPlace and Options.TeleportPlace.Value
    		if label and Auto.goToPlace then
    			Auto.goToPlace(label)
    		end
    	end,
    })
    UI.WorldHereRow = UI.WorldBox:AddStat({ Icon = "map-pin", Text = "You are in", Value = "...", Size = 22, ValueColor = "FontColor" })
    
    if #MissingRemotes > 0 then
    	StatusBox:AddDivider()
    	StatusBox:AddLabel({
    		Text = '<font color="#ff6e8a">Some game features did not load</font>  \u{00B7}  rejoin the game',
    		DoesWrap = true,
    	})
    end
    
    local GiftBox = Tabs.Rewards:AddLeftGroupbox("Playtime Gifts", "gift")
    GiftBox:AddToggle("AutoGift", {
    	Text = "Auto Claim Gifts",
    	Description = "Claims every gift the moment it unlocks",
    	Default = false,
    	Callback = function(v)
    		S.autoGift = v
    	end,
    })
    local GiftNextRow = GiftBox:AddStat({ Icon = GameIcons.Gift, Text = "Next gift", Value = "...", Size = 28 })
    local GiftClaimRow = GiftBox:AddStat({ Icon = GameIcons.Gift, Text = "Claimed", Value = "0 / 9", Size = 22, ValueColor = "FontColor" })
    
    local PartyBox = Tabs.Rewards:AddRightGroupbox("Party Egg", "party-popper")
    PartyBox:AddToggle("AutoPartyEgg", {
    	Text = "Auto Claim Party Egg",
    	Description = "Claims it as soon as it is ready",
    	Default = false,
    	Callback = function(v)
    		S.autoPartyEgg = v
    	end,
    })
    local PartyRow = PartyBox:AddStat({ Icon = GameIcons.PartyEgg, Text = "Party Egg", Value = "...", Size = 28 })
    local PartyClaimedRow = PartyBox:AddStat({ Icon = GameIcons.PartyEgg, Text = "Claimed", Value = "0", Size = 22, ValueColor = "FontColor" })
    
    UI.FruitMachineBox = Tabs.Rewards:AddLeftGroupbox("Fruit Machine", "cherry")
    UI.FruitMachineBox:AddToggle("AutoFruitMachine", {
    	Text = "Auto Buy Fruits",
    	Description = "Flies to Frozen Alley on every restock",
    	Tooltip = "Buys the whole stock with rubies as soon as the machine restocks, then brings you back. If you own the Auto Buy Fruit Machine special upgrade, it switches the game's own Auto Buy on once and stops flying there.",
    	Default = false,
    	Callback = function(v)
    		S.autoFruitMachine = v
    	end,
    })
    UI.FMStateRow = UI.FruitMachineBox:AddStat({ Icon = GameIcons.FruitMachine, Text = "Restock", Value = "...", Size = 30, Progress = 0 })
    UI.FMPriceRow = UI.FruitMachineBox:AddStat({ Icon = CurrencyIcons.Rubies, Text = "Price", Value = "?", Size = 22, ValueColor = "FontColor" })
    UI.FMBoughtRow = UI.FruitMachineBox:AddStat({ Icon = Items.Icons.Apple, Text = "Bought", Value = "0", Size = 22 })
    UI.FMLastLabel = UI.FruitMachineBox:AddLabel({ Text = "", DoesWrap = true })
    pcall(UI.FMLastLabel.SetVisible, UI.FMLastLabel, false)
    UI.FMAutoRow = UI.FruitMachineBox:AddStat({ Icon = GameIcons.FruitMachine, Text = "Game Auto Buy", Value = "...", Size = 22, ValueColor = "FontColor" })
    pcall(UI.FMAutoRow.SetVisible, UI.FMAutoRow, false)
    
    UI.GroupChestBox = Tabs.Rewards:AddRightGroupbox("Group Chest", "box")
    UI.GroupChestBox:AddToggle("AutoGroupChest", {
    	Text = "Auto Claim Group Chest",
    	Description = "Claims it at spawn whenever it is ready",
    	Tooltip = "Only works while you are in the game's group",
    	Default = false,
    	Callback = function(v)
    		S.autoGroupChest = v
    	end,
    })
    UI.GCStateRow = UI.GroupChestBox:AddStat({ Icon = GameIcons.GroupChest, Text = "Group Chest", Value = "...", Size = 30, Progress = 0 })
    UI.GCMemberRow = UI.GroupChestBox:AddStat({ Icon = "users", Text = "Group", Value = "checking...", Size = 22, ValueColor = "FontColor" })
    UI.GCClaimedRow = UI.GroupChestBox:AddStat({ Icon = GameIcons.GroupChest, Text = "Claimed", Value = "0", Size = 22 })
    UI.GroupChestBox:AddButton({
    	Text = "Copy group link",
    	Tooltip = "Join the group to unlock the chest",
    	Func = function()
    		local link = "https://www.roblox.com/communities/35939768"
    		local ok = pcall(function()
    			(setclipboard or toclipboard)(link)
    		end)
    		notify("Group Chest", if ok then "Group link copied" else link, 4)
    	end,
    })
    
    UI.MoonChestBox = Tabs.Rewards:AddLeftGroupbox("Moon Chest", "moon")
    UI.MoonChestBox:AddToggle("AutoMoonChest", {
    	Text = "Auto Claim Moon Chest",
    	Description = "Opens it on The Moon the moment it is ready",
    	Default = false,
    	Callback = function(v)
    		S.autoMoonChest = v
    	end,
    })
    UI.MCStateRow = UI.MoonChestBox:AddStat({ Icon = GameIcons.MoonChest, Text = "Moon Chest", Value = "...", Size = 30, Progress = 0 })
    UI.MCLuckRow = UI.MoonChestBox:AddStat({ Icon = GameIcons.Luck, Text = "Item luck", Value = "?", Size = 22, ValueColor = "FontColor" })
    UI.MCClaimedRow = UI.MoonChestBox:AddStat({ Icon = GameIcons.MoonChest, Text = "Claimed", Value = "0", Size = 22 })

    UI.VipChestBox = Tabs.Rewards:AddLeftGroupbox("VIP Chest", "crown")
    UI.VipChestBox:AddToggle("AutoKeyCraft", {
    	Text = "Auto Craft VIP Keys",
    	Description = "Joins upper and lower halves into keys",
    	Default = false,
    	Callback = function(v)
    		S.autoKeyCraft = v
    	end,
    })
    UI.VipChestBox:AddToggle("AutoVipChest", {
    	Text = "Auto Open VIP Chest",
    	Description = "Uses your VIP keys at the chest in Pet Kingdom, needs the VIP gamepass",
    	Default = false,
    	Callback = function(v)
    		S.autoVipChest = v
    	end,
    })
    UI.ExtrasBox = Tabs.Rewards:AddRightGroupbox("Extras", "sparkles")
    UI.ExtrasBox:AddToggle("AutoAdminChat", {
    	Text = "Auto Type Admin Phrases",
    	Description = "Types the word an admin asks for in chat",
    	Tooltip = "When a global admin message says something like \"type WORD for 100x eggs\", the hub writes that word in chat once.",
    	Default = false,
    	Callback = function(v)
    		S.autoAdminChat = v
    	end,
    })
    UI.ExtrasBox:AddToggle("AutoPartner", {
    	Text = "Auto Claim Partner Rewards",
    	Description = "Only for players with a partner rank",
    	Default = false,
    	Callback = function(v)
    		S.autoPartner = v
    	end,
    })
    UI.ExtrasBox:AddToggle("AutoUniverseZone", {
    	Text = "Auto Unlock Universe Zone",
    	Description = "Uses your Universe Key on the zone at spawn",
    	Default = false,
    	Callback = function(v)
    		S.autoUniverseZone = v
    	end,
    })
    UI.ExtrasBox:AddDivider()
    UI.ExtrasBox:AddToggle("AutoEventCraft", {
    	Text = "Auto Event Craft",
    	Description = "Turns the picked event pets into 1M Lucky Blocks",
    	Tooltip = "This uses up the pets you pick below. Nothing is crafted until you pick a recipe.",
    	Default = false,
    	Callback = function(v)
    		S.autoEventCraft = v
    	end,
    })
    UI.ExtrasBox:AddDropdown("EventCraftPick", {
    	Text = "Craft From",
    	Values = { "Ruby Hedgehog", "Golden Ruby Hedgehog", "Diamond Ruby Hedgehog", "Ruby Majesty", "Golden Ruby Majesty", "Diamond Ruby Majesty", "Ruby Chest", "Golden Ruby Chest", "Diamond Ruby Chest" },
    	Default = {},
    	Multi = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for name, on in pairs(value) do
    				if on then
    					pick[name] = true
    				end
    			end
    		end
    		S.eventCraftPick = pick
    	end,
    })


do
local FPlayers = game:GetService("Players")
local FTeleport = game:GetService("TeleportService")
local F = { on = false, asked = {}, friend = {}, sent = 0, lastSend = -1e9, lastLog = "", lastLogAt = -1e9 }
local function friendBoost()
local folder = getDataFolder("VariousBoosts")
local v = folder and folder:FindFirstChild("FriendBoostCoins")
if v and v:IsA("ValueBase") and type(v.Value) == "number" then
return "+" .. math.floor(math.max(0, (v.Value - 1) * 100) + 0.5) .. "%"
end
local label
pcall(function() label = LocalPlayer.PlayerGui.BoostUI.LeftHolder.FriendBoost.Countdown end)
if label and label:IsA("TextLabel") and string.find(label.Text, "%%") then
return label.Text
end
-- the game adds FriendBoostCoins only once a boost exists
return if folder then "+0%" else "nofolder"
end
local function isFriend(p)
if F.friend[p.UserId] then return true end
local ok, res = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
if ok and res then F.friend[p.UserId] = true end
return ok and res, ok
end
local function friendPump()
if not F.on then return end
for _, p in ipairs(FPlayers:GetPlayers()) do
if p ~= LocalPlayer and not F.asked[p.UserId] and not F.friend[p.UserId] then
local yes, ok = isFriend(p)
if ok and not yes then
if os.clock() - F.lastSend < 10 then return end
F.asked[p.UserId] = true
F.lastSend = os.clock()
if pcall(function() LocalPlayer:RequestFriendship(p) end) then F.sent += 1 end
return
end
end
end
end
local function friendLog()
local n = 0
for _, p in ipairs(FPlayers:GetPlayers()) do
if p ~= LocalPlayer and isFriend(p) then n += 1 end
end
local boost = friendBoost()
local key = F.sent .. "/" .. n .. "/" .. tostring(boost)
if key ~= F.lastLog and os.clock() - F.lastLogAt >= 60 then
F.lastLog = key
F.lastLogAt = os.clock()
Auto.log("FRIEND sent=" .. F.sent .. " friends=" .. n .. " boost=" .. tostring(boost))
end
end
Library:GiveSignal(FPlayers.PlayerAdded:Connect(function()
task.delay(2, function() pcall(friendPump) end)
end))
task.spawn(function()
local beat = 0
while true do
task.wait(10)
beat += 1
pcall(friendPump)
if beat % 6 == 0 then pcall(friendLog) end
end
end)
local function joinFriend()
local ok, list = pcall(function() return LocalPlayer:GetFriendsOnline(200) end)
if not ok or type(list) ~= "table" then
Auto.log("FRIEND join unsupported")
notify("Friends", "Joining a friend is not supported by this executor", 4)
return
end
for _, f in ipairs(list) do
local place, job = f.PlaceId, f.GameId
if place and job and job ~= game.JobId and (place == game.PlaceId or f.UniverseId == game.GameId) then
Auto.log("FRIEND join " .. tostring(f.UserName or f.DisplayName or f.VisitorId))
notify("Friends", "Joining " .. tostring(f.UserName or "a friend"), 4)
if not pcall(function() FTeleport:TeleportToPlaceInstance(place, job, LocalPlayer) end) then
Auto.log("FRIEND join unsupported")
end
return
end
end
Auto.log("FRIEND join none")
notify("Friends", "No friend is online in this game's other servers", 4)
end
UI.FriendBox = Tabs.Rewards:AddRightGroupbox("Friends", "users")
UI.FriendBox:AddToggle("AutoFriend", {
Text = "Auto Friend",
Description = "Sends friend requests to everyone in the server, once each",
Tooltip = "Every friend in the server gives a boost. Sends one request per 10 s (and accepts requests sent to you).",
Default = false,
Callback = function(v)
F.on = v == true
end,
})
UI.FriendBox:AddButton({
Text = "Join friend's server",
Func = function()
task.spawn(joinFriend)
end,
})
end
    UI.VipKeysRow = UI.VipChestBox:AddStat({ Icon = "key-round", Text = "VIP keys", Value = "0", Size = 26 })
    UI.VipOpenedRow = UI.VipChestBox:AddStat({ Icon = "crown", Text = "Opened / crafted", Value = "0 / 0", Size = 22, ValueColor = "FontColor" })
    
    UI.QuestBox = Tabs.Rewards:AddLeftGroupbox("Quests", "list-checks")
    UI.QuestBox:AddToggle("AutoQuests", {
    	Text = "Auto Claim Quests",
    	Description = "Index, daily, group and verify rewards",
    	Tooltip = "Claims every index milestone, the daily login reward, the group reward and the Like / Group / Favorite tasks as soon as they are ready",
    	Default = false,
    	Callback = function(v)
    		S.autoQuests = v
    	end,
    })
    UI.QuestBox:AddDropdown("QuestPick", {
    	Text = "Claim",
    	Values = { "Index rewards", "Daily reward", "Group reward", "Like, group, favorite" },
    	Default = { "Index rewards", "Daily reward", "Group reward", "Like, group, favorite" },
    	Multi = true,
    	Callback = function(value)
    		local map = { ["Index rewards"] = "Index", ["Daily reward"] = "Daily", ["Group reward"] = "Group", ["Like, group, favorite"] = "Verify" }
    		local pick = {}
    		if type(value) == "table" then
    			for display, on in pairs(value) do
    				if on and map[display] then pick[map[display]] = true end
    			end
    		end
    		S.questPick = pick
    	end,
    })
    UI.QuestIndexRow = UI.QuestBox:AddStat({ Icon = GameIcons.Index, Text = "Index", Value = "...", Size = 28, Progress = 0 })
    UI.QuestDailyRow = UI.QuestBox:AddStat({ Icon = GameIcons.Gift, Text = "Daily reward", Value = "...", Size = 28, Progress = 0 })
    UI.QuestGroupRow = UI.QuestBox:AddStat({ Icon = GameIcons.GroupChest, Text = "Group reward", Value = "...", Size = 22, ValueColor = "FontColor" })
    UI.QuestVerifyRow = UI.QuestBox:AddStat({ Icon = "badge-check", Text = "Like, group, favorite", Value = "...", Size = 22, ValueColor = "FontColor" })
    UI.QuestClaimedRow = UI.QuestBox:AddStat({ Icon = GameIcons.Auto, Text = "Claimed", Value = "0", Size = 22 })
    
    UI.TravelBox = Tabs.Rewards:AddRightGroupbox("Travel", "route")
    UI.TravelBox:AddToggle("ReturnAfterErrand", {
    	Text = "Return after collecting",
    	Description = "Brings you back to where you were",
    	Default = true,
    	Callback = function(v)
    		S.returnAfter = v
    	end,
    })
    UI.ErrandRow = UI.TravelBox:AddStat({ Icon = "navigation", Text = "Now", Value = "Idle", Size = 24, ValueColor = "FontColor" })
    UI.ErrandNextRow = UI.TravelBox:AddStat({ Icon = "clock", Text = "Next stop", Value = "-", Size = 22, ValueColor = "FontColor" })
    
    UI.BenBox = Tabs.Rewards:AddLeftGroupbox("Ben Hunt", "search")
    UI.BenBox:AddToggle("AutoBen", {
    	Text = "Auto Find Bens",
    	Description = "Grabs every hidden Ben for extra luck",
    	Tooltip = "Each Ben gives permanent luck, finding them all adds golden chance too. New Bens from updates are picked up on their own. Only worlds you own.",
    	Default = false,
    	Callback = function(v)
    		S.autoBen = v
    	end,
    })
    UI.BenFoundRow = UI.BenBox:AddStat({ Icon = "search", Text = "Found", Value = "...", Size = 26, Progress = 0 })
    UI.BenLuckRow = UI.BenBox:AddStat({ Icon = GameIcons.Luck, Text = "Luck bonus", Value = "...", Size = 22 })
    UI.BenNextRow = UI.BenBox:AddStat({ Icon = "map-pin", Text = "Next Ben", Value = "-", Size = 22, ValueColor = "FontColor" })
    UI.BenStateRow = UI.BenBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    UI.CodesBox = Tabs.Rewards:AddRightGroupbox("Codes", "ticket")
    UI.CodesBox:AddToggle("AutoCodes", {
    	Text = "Auto redeem known codes",
    	Description = "Redeems the known codes, once per account",
    	Tooltip = "Fetches the code list from the Corvus repo at start and every 6 hours, plus the codes the game shows in its update log. Each code is redeemed once with a 2 second pause and remembered, invalid ones are never retried.",
    	Default = false,
    	Callback = function(v)
    		S.autoCodes = v
    	end,
    })
    UI.CodesBox:AddInput("CodeInput", {
    	Text = "Code",
    	Placeholder = "Type a code...",
    	Finished = true,
    	Default = "",
    	Callback = function() end,
    })
    UI.CodesBox:AddButton({
    	Text = "Redeem",
    	Func = function()
    		if Auto.redeemCode then
    			Auto.redeemCode(Options.CodeInput and Options.CodeInput.Value or "")
    			pcall(Options.CodeInput.SetValue, Options.CodeInput, "")
    		end
    	end,
    })
    UI.CodesFoundRow = UI.CodesBox:AddStat({ Icon = "ticket", Text = "Codes found", Value = "0", Size = 24 })
    UI.CodesDoneRow = UI.CodesBox:AddStat({ Icon = GameIcons.Gift, Text = "Codes redeemed", Value = "0 / invalid 0", Size = 22 })
    UI.CodesLastRow = UI.CodesBox:AddStat({ Icon = "clock", Text = "Last", Value = "-", Size = 22, ValueColor = "FontColor" })
    UI.CodesStateRow = UI.CodesBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    local EggBox = Tabs.Eggs:AddLeftGroupbox("Auto Buy", "egg")
    local initialEggs = collectEggNames()
    
    local EggDropdown = EggBox:AddDropdown("HatchEgg", {
    	Text = "Egg",
    	Values = initialEggs,
    	ValueImages = getEggVisuals(initialEggs),
    	Default = initialEggs[1],
    	AllowNull = true,
    	Searchable = true,
    	Callback = function(choice)
    		S.hatchEggName = if type(choice) == "string" then choice else ""
    	end,
    })
    Auto.defaultEgg = initialEggs[1]
    S.hatchEggName = if type(Options.HatchEgg.Value) == "string" then Options.HatchEgg.Value else ""
    EggBox:AddDropdown("HatchMode", {
    	Text = "Hatch Count",
    	Values = { "Single", "Half", "Max" },
    	Default = "Max",
    	Callback = function(choice)
    		if choice == "Single" or choice == "Half" or choice == "Max" then
    			S.hatchMode = choice
    		end
    	end,
    })
    EggBox:AddToggle("AutoHatch", {
    	Text = "Auto Buy Egg",
    	Description = "Goes to the egg and opens it when affordable",
    	Default = false,
    	Callback = function(v)
    		S.autoHatch = v
    		HatchState.waiting = false
    		HatchState.startEggs = Saved.eggs
    		if v and S.hatchEggName == "" then
    			notify("Eggs", "Select an egg first", 4)
    		end
    	end,
    })
    EggBox:AddToggle("EggSmart", {
    	Text = "Smart Egg Pick",
    	Description = "Picks the egg that pays back best",
    	Tooltip = "Uses real egg odds, your luck and your team to pick the coin egg that adds the most income per coin within 24 hours. Your egg pick is ignored while this is on. It opens the eggs and goes to them by itself, Auto Buy Egg does not need to be on.",
    	Default = false,
    	Callback = function(v)
    		S.eggSmart = v
    		if Auto.drive then
    			pcall(Auto.drive)
    		end
    	end,
    })
    EggBox:AddToggle("EggStayPut", {
    	Text = "Stay where I am",
    	Description = "Only opens the egg when you stand next to it",
    	Tooltip = "Off: Auto Buy Egg teleports to the egg's world and walks up to it when it is too far. On: it waits until you are in range. Smart Planner always goes to its egg.",
    	Default = false,
    	Callback = function(v)
    		S.eggAutoTravel = not v
    	end,
    })
    EggBox:AddToggle("SkipHatchAnim", {
    	Text = "Skip hatch animation",
    	Description = "No egg cutscene, your camera stays free",
    	Tooltip = "The server decides how fast eggs open (your Hatch Speed upgrades). Corvus already opens the next egg the moment the server answers, so this will not open eggs faster. It removes the camera lock, the screen shake and the lag from the cutscene.",
    	Default = false,
    	Callback = function(v)
    		S.skipHatchAnim = v
    		if Auto.setSkipAnim then
    			local ok, reason = Auto.setSkipAnim(v)
    			if v and not ok then
    				notify("Eggs", reason or "Your executor can not skip the animation", 5)
    			end
    		end
    	end,
    })
    EggBox:AddInput("HatchStopAfter", {
    	ClearTextOnFocus = false,
    	Text = "Stop after (eggs)",
    	Placeholder = "0 = never",
    	Numeric = true,
    	Finished = true,
    	Default = "0",
    	Tooltip = "Turns Auto Buy off after this many eggs. 0 keeps going forever.",
    	Callback = function(value)
    		local n = math.floor(tonumber(value) or 0)
    		S.hatchStopAfter = math.clamp(n, 0, 10000000)
    		HatchState.startEggs = Saved.eggs
    	end,
    })
    EggBox:AddInput("HatchKeepCoins", {
    	ClearTextOnFocus = false,
    	Text = "Keep at least (coins)",
    	Placeholder = "0, 250k, 1.5m, 2b...",
    	Finished = true,
    	Default = "0",
    	Tooltip = "Auto Buy never spends below this. The hatch count drops from Max to Half to Single so you stay above it. Ruby event eggs keep the ruby reserve from Upgrades > Budget instead.",
    	Callback = function(value)
    		local amount = Auto.parseAmount(value)
    		if amount == nil and tostring(value or "") ~= "" then
    			notify("Eggs", "Use a number like 500000, 250k or 1.5m", 4)
    		end
    		S.hatchKeepCoins = math.max(0, amount or 0)
    	end,
    })
    
    local function refreshEggs(silent)
    	local names = collectEggNames()
    	if #names == 0 then
    		if not silent then
    			notify("Eggs", "No eggs found in this area", 4)
    		end
    		return
    	end
    	pcall(EggDropdown.SetValueImages, EggDropdown, getEggVisuals(names))
    	EggDropdown:SetValues(names)
    	if not table.find(names, S.hatchEggName) then
    		EggDropdown:SetValue(names[1])
    	end
    	if not silent then
    		notify("Eggs", "Found " .. #names .. " eggs")
    	end
    end
    
    local EggWorlds = {
    	["Basic Egg"] = "Spawn",
    	["Sprout Egg"] = "Spawn",
    	["Universe Egg"] = "Spawn",
    	["Grassy Egg"] = "BirchForest",
    	["Dried Egg"] = "TreasureDunes",
    	["Frost Egg"] = "FrozenAlley",
    	["Zombie Egg"] = "HauntedHouse",
    	["Castle Egg"] = "PetKingdom",
    	["Mushroom Egg"] = "EnchantedGrove",
    	["Volcano Egg"] = "VolcanoHollow",
    	["Ruby Egg"] = "Spawn",
    	["Ruby Egg x2Luck"] = "VolcanoHollow",
    	["Ruby Egg x5Luck"] = "VolcanoHollow",
    }
    pcall(function()
    	local worlds = require(ReplicatedStorage.Modules:WaitForChild("EggWorldModule", 3))
    	if type(worlds) == "table" and type(worlds.EggWorlds) == "table" then
    		for egg, world in pairs(worlds.EggWorlds) do
    			if type(egg) == "string" and type(world) == "string" then
    				EggWorlds[egg] = if world == "Haunted" then "HauntedHouse" else world
    			end
    		end
    	end
    end)
    
    local WorldBounds = {
    	Spawn = { -366.65, 38.029, -213.322, 482.127 },
    	BirchForest = { -448.295, 71.216, -1907.425, -1404.951 },
    	TreasureDunes = { 800.629, 1419.395, -2003.417, -1337.548 },
    	FrozenAlley = { 2214.693, 2716.751, -1879.991, -1407.649 },
    	HauntedHouse = { 2216.941, 2802.141, -3250.918, -2516.318 },
    	PetKingdom = { 1282.367, 1882.367, -3131.53, -2531.53 },
    	EnchantedGrove = { -290, 10, -2810, -2500 },
    	VolcanoHollow = { -1670, -665, -3160, -2228 },
    	TheMoon = { 455, 1055, -3139, -2539 },
    }
    
    if Auto.GameData.bounds and next(Auto.GameData.bounds) then
    	table.clear(WorldBounds)
    	for name, b in pairs(Auto.GameData.bounds) do
    		WorldBounds[name] = b
    	end
    end
    
    local function worldKey(name)
    	if type(name) ~= "string" then return nil end
    	if WorldBounds[name] then return name end
    	for key in pairs(WorldBounds) do
    		if string.sub(key, 1, #name) == name then
    			return key
    		end
    	end
    	return name
    end
    Auto.worldKey = worldKey
    
    for egg, world in pairs(EggWorlds) do
    	EggWorlds[egg] = worldKey(world)
    end
    
    local function getWorldAt(pos)
    	for name, b in pairs(WorldBounds) do
    		if pos.X >= b[1] - 40 and pos.X <= b[2] + 40 and pos.Z >= b[3] - 40 and pos.Z <= b[4] + 40 then
    			return name
    		end
    	end
    	return nil
    end
    
    function Auto.eggWorld(name)
    	if EggWorlds[name] then
    		return EggWorlds[name]
    	end
    	local config = Auto.eventEggConfig()
    	local entry = type(config) == "table" and type(config.Eggs) == "table" and config.Eggs[name] or nil
    	if type(entry) == "table" and type(entry.RequiredWorld) == "string" then
    		return entry.RequiredWorld
    	end
    	local model = getEggModel(name)
    	local ok, world = pcall(function() return model and getWorldAt(model:GetPivot().Position) end)
    	return ok and world or "Spawn"
    end
    
    local function prettyWorld(key)
    	local cost = Auto.GameData.worldCost
    	if cost and type(cost.DisplayNames) == "table" and cost.DisplayNames[key] then
    		return cost.DisplayNames[key]
    	end
    	return (string.gsub(tostring(key), "(%l)(%u)", "%1 %2"))
    end
    
    local function getRoot()
    	local char = LocalPlayer.Character
    	return char and char:FindFirstChild("HumanoidRootPart")
    end

    -- the breakable area folders of a world (Breakables.<Area>.<model>)
    function Auto.areaFolderIn(world)
    	if not (Breakables and world) then return nil end
    	local direct = Breakables:FindFirstChild(world)
    	local best, bestCount = nil, 0
    	for _, folder in ipairs(Breakables:GetChildren()) do
    		local count, inWorld = 0, false
    		for _, model in ipairs(folder:GetChildren()) do
    			if model:IsA("Model") then
    				count += 1
    				if not inWorld then
    					local pos = getModelPosition(model)
    					inWorld = pos ~= nil and getWorldAt(pos) == world
    				end
    			end
    		end
    		if inWorld and (folder == direct or count > bestCount) then
    			best, bestCount = folder, if folder == direct then math.huge else count
    		end
    	end
    	return best
    end

    -- Smart Planner owns farming: keep the character's pets on the farm world's breakables, log what farming earns
    function Auto.farmPresence()
    	if not S.autoFarm then return end
    	local now = os.clock()
    	local F = Auto.FarmPresence
    	if not F then
    		F = { logAt = now, brokenAt = Auto.farmBroken or 0, coins = nil, moveAt = -1e9, fails = 0 }
    		Auto.FarmPresence = F
    	end
    	local bd = getDataFolder("BreakableData")
    	local areaVal = bd and bd:FindFirstChild("Area")
    	local inVal = bd and bd:FindFirstChild("InArea")
    	local autoVal = bd and bd:FindFirstChild("AutoBreaking")
    	local area = if areaVal then tostring(areaVal.Value) else ""
    	local inside = inVal ~= nil and inVal.Value == true
    	local cum = Auto.Metrics and Auto.Metrics.cum
    	local coins = cum and tonumber(cum.Coins) or nil
    	if F.coins == nil then
    		F.coins = coins
    	end
    	if now - F.logAt >= 60 then
    		local broken = (Auto.farmBroken or 0) - F.brokenAt
    		Auto.log("FARM", "breaking=" .. broken .. "/min", "coins+=" .. (if coins and F.coins then string.format("%.0f", coins - F.coins) else "?"), "area=" .. area, "inArea=" .. tostring(inside), "autoBreak=" .. tostring(autoVal ~= nil and autoVal.Value == true), "tap=" .. tostring(S.autoTap == true), "by=" .. (if S.farmOP then "planner" else "switch"))
    		F.logAt, F.brokenAt, F.coins = now, Auto.farmBroken or 0, coins
    	end
    	if autoVal and autoVal.Value ~= true and SetAutoBreaking and now - (F.autoAt or -1e9) > 5 then
    		F.autoAt = now
    		pcall(function() SetAutoBreaking:FireServer(true) end)
    	end
    	if not S.farmOP then return end
    	local mover = Auto.Mover
    	if (mover and mover.busy) or (Auto.Fish and Auto.Fish.active) or now - F.moveAt < 15 then return end
    	local root = getRoot()
    	if not root then return end
    	local world = getWorldAt(root.Position)
    	if not world or inside then return end
    	local current = if area ~= "" and Breakables then Breakables:FindFirstChild(area) else nil
    	local currentOk = false
    	if current then
    		for _, model in ipairs(current:GetChildren()) do
    			local pos = model:IsA("Model") and getModelPosition(model) or nil
    			if pos then
    				currentOk = getWorldAt(pos) == world
    				break
    			end
    		end
    	end
    	local hatching = os.clock() - (HatchState.activeAt or -1e9) < 6
    	-- pets already work this world's area from where we stand, and the egg needs us here
    	if currentOk and hatching then return end
    	if currentOk and now - F.moveAt < 120 then return end
    	local folder = Auto.areaFolderIn(world)
    	if not folder then
    		Auto.logEvery("farmnoarea:" .. world, 300, "PLAN", "idle", "reason=no breakable area loaded in " .. world)
    		return
    	end
    	local sum, n, models = Vector3.zero, 0, {}
    	for _, model in ipairs(folder:GetChildren()) do
    		local pos = model:IsA("Model") and getModelPosition(model) or nil
    		if pos then
    			sum += pos
    			n += 1
    			table.insert(models, pos)
    		end
    	end
    	if n == 0 then return end
    	local center = sum / n
    	local spot, best = nil, math.huge
    	for _, pos in ipairs(models) do
    		local d = (pos - center).Magnitude
    		if d < best then
    			spot, best = pos, d
    		end
    	end
    	F.moveAt = now
    	if mover then
    		mover.busy = true
    		mover.task = "Going into " .. folder.Name .. " to farm"
    	end
    	pcall(function()
    		root.AssemblyLinearVelocity = Vector3.zero
    		root.CFrame = CFrame.new(spot + Vector3.new(4, 4, 4))
    	end)
    	local waited = 0
    	while waited < 3 and not (inVal and inVal.Value == true) do
    		waited += task.wait(0.25) or 0.25
    	end
    	if mover then
    		mover.busy = false
    		mover.task = ""
    	end
    	local entered = inVal ~= nil and inVal.Value == true
    	Auto.log("FARM", "move", "area=" .. folder.Name, "world=" .. world, "was=" .. (if area ~= "" then area else "none"), "entered=" .. tostring(entered), "areaNow=" .. (if areaVal then tostring(areaVal.Value) else "?"))
    	if entered then
    		F.fails = 0
    		if SetAutoBreaking then
    			pcall(function() SetAutoBreaking:FireServer(true) end)
    		end
    	else
    		F.fails += 1
    		if F.fails >= 3 then
    			F.moveAt = now + 300
    			F.fails = 0
    			Auto.log("PLAN", "idle", "reason=could not enter the breakable area of " .. world .. ", retry in 5 min")
    		end
    	end
    end
    
    EggBox:AddButton({
    	Text = "Go to egg",
    	Tooltip = "Travels to the egg's world first, then stands you next to it",
    	Func = function()
    		Auto.goToEgg(S.hatchEggName)
    	end,
    }):AddButton({
    	Text = "Refresh list",
    	Func = function()
    		refreshEggs(false)
    	end,
    })
    
    local EggStatsBox = Tabs.Eggs:AddRightGroupbox("Status", "activity")
    local SelectedEggRow = EggStatsBox:AddStat({ Icon = GameIcons.Egg, Text = "No egg selected", Value = "", Size = 30 })
    local EggPriceRow = EggStatsBox:AddStat({ Icon = CurrencyIcons.Coins, Text = "Price", Value = "?", Size = 22, ValueColor = "FontColor" })
    local HatchStateRow = EggStatsBox:AddStat({ Icon = GameIcons.Auto, Text = "Auto Buy", Value = "Off", Size = 22, ValueColor = "FontColor" })
    local EggsTabOpenedRow = EggStatsBox:AddStat({ Icon = GameIcons.Egg, Text = "Eggs opened", Value = "0", Size = 22 })
    UI.EggComboRow = EggStatsBox:AddStat({ Icon = GameIcons.Luck, Text = "Egg Luck Combo", Value = "...", Size = 22, Progress = 0 })
    
    UI.InvEggBox = Tabs.Eggs:AddRightGroupbox("Inventory Eggs", "package")
    UI.InvEggNames = { "Alien Egg", "Party Egg" }
    UI.InvEggBox:AddToggle("AutoInvEggs", {
    	Text = "Auto Open Inventory Eggs",
    	Description = "Opens Party, Alien and other owned eggs",
    	Tooltip = "Opens the eggs in your inventory 8, 3 or 1 at a time, from anywhere. The game blocks eggs while you fish, so this follows the With eggs setting in the Fishing tab.",
    	Default = false,
    	Callback = function(v)
    		S.autoInvEggs = v
    	end,
    })
    UI.InvEggBox:AddDropdown("InvEggKeep", {
    	Text = "Never open",
    	Values = UI.InvEggNames,
    	ValueImages = { ["Party Egg"] = GameIcons.PartyEgg, ["Alien Egg"] = "rbxassetid://123226572543807" },
    	Default = {},
    	Multi = true,
    	AllowNull = true,
    	Callback = function(value)
    		local keep = {}
    		if type(value) == "table" then
    			for name, on in pairs(value) do
    				if on then keep[name] = true end
    			end
    		end
    		S.invEggKeep = keep
    	end,
    })
    UI.InvEggOwnedRow = UI.InvEggBox:AddStat({ Icon = GameIcons.PartyEgg, Text = "Eggs in inventory", Value = "...", Size = 26 })
    UI.InvEggStateRow = UI.InvEggBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    UI.HuntBox = Tabs.Eggs:AddLeftGroupbox("Index Hunter", "book-open")
    UI.HuntBox:AddToggle("IndexHunter", {
    	Text = "Index Hunter",
    	Description = "Hatch, craft Golden and Diamond",
    	Tooltip = "Finds pets missing from your index, hatches their egg, crafts Golden and Diamond at the machines and stops when everything is done",
    	Default = false,
    	Callback = function(v)
    		S.indexHunt = v
    		HatchState.waiting = false
    	end,
    })
    UI.RarityImages = {}
    for _, rarity in ipairs(Items.HuntRarities) do
    	UI.RarityImages[rarity] = Rarities and Rarities[rarity] and Rarities[rarity][2] or nil
    end
    UI.HuntBox:AddDropdown("HuntRarity", {
    	Text = "Rarities",
    	Values = Items.HuntRarities,
    	ValueImages = UI.RarityImages,
    	Default = { "Basic", "Rare", "Epic" },
    	Multi = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for rarity, on in pairs(value) do
    				if on then pick[rarity] = true end
    			end
    		end
    		S.huntRarity = pick
    	end,
    })
    UI.HuntBox:AddDropdown("HuntVariants", {
    	Text = "Complete",
    	Values = { "Normal", "Golden", "Diamond" },
    	Default = { "Normal", "Golden", "Diamond" },
    	Multi = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for variant, on in pairs(value) do
    				if on then pick[variant] = true end
    			end
    		end
    		S.huntVariants = pick
    	end,
    })
    UI.HuntBox:AddLabel({ Text = '<font transparency="0.45">Golden is crafted at the Golden Machine (Birch Forest), Diamond at the Diamond Machine (Haunted House). Equipped and locked pets are never used.</font>', DoesWrap = true })
    UI.HuntBox:AddDivider()
    UI.HuntGrid = UI.HuntBox:AddIconGrid("HuntGallery", {
    	Filters = { "Normal", "Golden", "Diamond" },
    	Rows = 3,
    	TileSize = 54,
    	EmptyText = "Nothing missing here. Pick more rarities above or another variant.",
    	DetailText = '<font transparency="0.35">Tap a pet to hunt it first. Glowing pets can drop from the egg the hunter is opening right now.</font>',
    	Changed = function()
    		UI.galleryKey = nil
    		if Auto.drawLive then
    			pcall(Auto.drawLive, true)
    		end
    	end,
    	Clicked = function(item)
    		if Auto.pinPet then
    			Auto.pinPet(item)
    		end
    	end,
    })
    
    UI.HuntStatusBox = Tabs.Eggs:AddRightGroupbox("Index Progress", "book-open")
    UI.HuntEggRow = UI.HuntStatusBox:AddStat({ Icon = GameIcons.Egg, Text = "No target yet", Value = "", Size = 30 })
    UI.HuntPetRow = UI.HuntStatusBox:AddStat({ Icon = GameIcons.Index, Text = "Pet", Value = "-", Size = 30, Progress = 0 })
    UI.HuntVariantRow = UI.HuntStatusBox:AddStat({ Icon = GameIcons.Index, Text = "Index", Value = "-", Size = 22 })
    UI.HuntLeftRow = UI.HuntStatusBox:AddStat({ Icon = GameIcons.Index, Text = "Index done", Value = "-", Size = 22, Progress = 0 })
    UI.HuntStateRow = UI.HuntStatusBox:AddStat({ Icon = GameIcons.Auto, Text = "Index Hunter", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    UI.FeedBox = Tabs.Eggs:AddRightGroupbox("Live Hatches", "radio")
    UI.Feed = UI.FeedBox:AddFeed("HatchFeed", {
    	MaxRows = 7,
    	EmptyText = "Open an egg and your pets show up here live.",
    })
    UI.FeedBox:AddLabel({ Text = '<font transparency="0.45">1 in X is the base chance from that egg, before luck boosts. NEW means the pet was missing from your index.</font>', DoesWrap = true })
    
    UI.ModeValues = { "Keep active", "Use all at once" }
    
    UI.FruitBox = Tabs.Items:AddLeftGroupbox("Fruits", "apple")
    UI.FruitDisplay, UI.FruitImages = Auto.displayList(Items.Fruits)
    UI.FruitBox:AddDropdown("FruitPick", {
    	Text = "Fruits",
    	Values = UI.FruitDisplay,
    	ValueImages = UI.FruitImages,
    	Default = UI.FruitDisplay,
    	Multi = true,
    	Callback = function(value)
    		S.fruitPick = Auto.pickFromMulti(value)
    	end,
    })
    UI.FruitBox:AddDropdown("FruitMode", {
    	Text = "Mode",
    	Values = UI.ModeValues,
    	Default = "Keep active",
    	Tooltip = "Keep active uses one when the boost runs out. Use all at once stacks every fruit you own.",
    	Callback = function(value)
    		S.fruitMode = if value == "Use all at once" then "Use all" else "Keep active"
    	end,
    })
    UI.FruitBox:AddSlider("FruitRefill", {
    	Text = "Use per refill",
    	Min = 1,
    	Max = 25,
    	Default = 1,
    	Rounding = 0,
    	HideMax = true,
    	Tooltip = "How many fruits to use each time a boost runs out. Never more than you own.",
    	Callback = function(v)
    		S.fruitRefill = math.clamp(math.floor(tonumber(v) or 1), 1, 25)
    	end,
    })
    UI.FruitBox:AddToggle("AutoFruits", {
    	Text = "Auto Use Fruits",
    	Description = "Keeps your fruit boosts running",
    	Default = false,
    	Callback = function(v)
    		S.autoFruits = v
    	end,
    })
    UI.FruitBox:AddDivider()
    UI.FruitRows = {}
    for _, name in ipairs(Items.Fruits) do
    	UI.FruitRows[name] = UI.FruitBox:AddStat({ Icon = Items.Icons[name], Text = name, Value = "-", Size = 24, ValueColor = "FontColor", Progress = 0 })
    end
    
    UI.PotionBox = Tabs.Items:AddLeftGroupbox("Potions", "flask-conical")
    UI.PotionDisplay, UI.PotionImages = Auto.displayList(Items.Potions)
    UI.PotionBox:AddDropdown("PotionPick", {
    	Text = "Potions",
    	Values = UI.PotionDisplay,
    	ValueImages = UI.PotionImages,
    	Default = { "Luck Potion", "Coins Potion" },
    	Multi = true,
    	Searchable = true,
    	Callback = function(value)
    		S.potionPick = Auto.pickFromMulti(value)
    	end,
    })
    UI.PotionBox:AddDropdown("PotionMode", {
    	Text = "Mode",
    	Values = UI.ModeValues,
    	Default = "Keep active",
    	Tooltip = "Keep active drinks one when the boost runs out. Use all at once stacks every potion you own.",
    	Callback = function(value)
    		S.potionMode = if value == "Use all at once" then "Use all" else "Keep active"
    	end,
    })
    UI.PotionBox:AddSlider("PotionRefill", {
    	Text = "Use per refill",
    	Min = 1,
    	Max = 25,
    	Default = 1,
    	Rounding = 0,
    	HideMax = true,
    	Tooltip = "How many potions to drink each time a boost runs out. Never more than you own.",
    	Callback = function(v)
    		S.potionRefill = math.clamp(math.floor(tonumber(v) or 1), 1, 25)
    	end,
    })
    UI.PotionBox:AddToggle("AutoPotions", {
    	Text = "Auto Use Potions",
    	Description = "Higher tiers are used first when you own them",
    	Default = false,
    	Callback = function(v)
    		S.autoPotions = v
    	end,
    })
    UI.PotionBox:AddDivider()
    UI.PotionEmpty = UI.PotionBox:AddLabel({ Text = '<font transparency="0.45">No potions in your inventory.</font>', DoesWrap = true })
    UI.PotionRows = {}
    for _, name in ipairs(Items.Potions) do
    	UI.PotionRows[name] = UI.PotionBox:AddStat({ Icon = Items.Icons[name], Text = Auto.itemDisplayName(name), Value = "-", Size = 24, ValueColor = "FontColor", Progress = 0 })
    	pcall(UI.PotionRows[name].SetVisible, UI.PotionRows[name], false)
    end
    
    UI.LuckyBox = Tabs.Items:AddRightGroupbox("Lucky Blocks", "package-open")
    UI.LuckyDisplay, UI.LuckyImages = Auto.displayList(Items.Lucky)
    UI.LuckyBox:AddDropdown("LuckyPick", {
    	Text = "Lucky blocks",
    	Values = UI.LuckyDisplay,
    	ValueImages = UI.LuckyImages,
    	Default = UI.LuckyDisplay,
    	Multi = true,
    	Callback = function(value)
    		S.luckyPick = Auto.pickFromMulti(value)
    	end,
    })
    UI.LuckyBox:AddDropdown("LuckyBatch", {
    	Text = "Open per batch",
    	Values = { "Auto", "8", "3", "1" },
    	Default = "Auto",
    	Tooltip = "Auto opens 8, then 3, then 1. A fixed size is only used when you own enough.",
    	Callback = function(value)
    		S.luckyBatch = tostring(value or "Auto")
    	end,
    })
    UI.LuckyBox:AddToggle("AutoLucky", {
    	Text = "Auto Open Lucky Blocks",
    	Description = "Opens 8 at a time whenever it can",
    	Default = false,
    	Callback = function(v)
    		S.autoLucky = v
    	end,
    })
    UI.LuckyBox:AddToggle("SkipLuckyAnim", {
    	Text = "Skip opening animation",
    	Description = "Lucky blocks open instantly",
    	Tooltip = "Uses the game's own Skip Lucky Animation setting from Update 2.",
    	Default = false,
    	Callback = function(v)
    		S.skipLuckyAnim = v
    		if v or UI.skipLuckySet then
    			UI.skipLuckySet = true
    			task.spawn(pcall, Auto.setGameSetting, "SkipLuckyBlockAnimation", v)
    		end
    	end,
    })
    UI.LuckyRows = {}
    for _, name in ipairs(Items.Lucky) do
    	UI.LuckyRows[name] = UI.LuckyBox:AddStat({ Icon = Items.Icons[name], Text = Auto.itemDisplayName(name), Value = "0", Size = 28 })
    end
    UI.LuckyOpenedTabRow = UI.LuckyBox:AddStat({ Icon = GameIcons.Auto, Text = "Opened", Value = "0", Size = 22 })
    UI.LuckyStateRow = UI.LuckyBox:AddStat({ Icon = Items.Icons.RareLuckyblock, Text = "Status", Value = "Idle", Size = 22, ValueColor = "FontColor" })
    
    UI.PetsBox = Tabs.Items:AddRightGroupbox("Pets", "paw-print")
    UI.PetsBox:AddToggle("AutoEquipBest", {
    	Text = "Auto Equip Best",
    	Description = "Re-equips your strongest pets after hatches",
    	Default = false,
    	Callback = function(v)
    		S.autoEquip = v
    	end,
    })
    UI.EquipRow = UI.PetsBox:AddStat({ Icon = GameIcons.EquipBest, Text = "Equipped", Value = "-", Size = 28 })
    UI.EquipLastRow = UI.PetsBox:AddStat({ Icon = GameIcons.Auto, Text = "Last equip", Value = "never", Size = 22, ValueColor = "FontColor" })
    UI.PetsBox:AddButton({
    	Text = "Equip best now",
    	Func = function()
    		if Auto.equipBestNow then
    			Auto.equipBestNow(true)
    		end
    	end,
    })
    
    UI.CraftBox = Tabs.Items:AddRightGroupbox("Crafting", "sparkles")
    UI.CraftBox:AddToggle("AutoGolden", {
    	Text = "Auto Golden Everything",
    	Description = "Crafts Golden from every full stack",
    	Tooltip = "Flies to the Golden Machine in Birch Forest and crafts every normal pet you have enough of. Equipped and locked pets are skipped.",
    	Default = false,
    	Callback = function(v)
    		S.autoGolden = v
    	end,
    })
    UI.CraftBox:AddToggle("AutoDiamond", {
    	Text = "Auto Diamond Everything",
    	Description = "Crafts Diamond from every full Golden stack",
    	Tooltip = "Flies to the Diamond Machine in Haunted House and crafts every Golden pet you have enough of.",
    	Default = false,
    	Callback = function(v)
    		S.autoDiamond = v
    	end,
    })
    UI.CraftRarities = { "Basic", "Rare", "Epic", "Legendary", "Mythical", "Exclusive", "Secret" }
    UI.CraftRarityImages = {}
    for _, rarity in ipairs(UI.CraftRarities) do
    	UI.CraftRarityImages[rarity] = Rarities and Rarities[rarity] and Rarities[rarity][2] or nil
    end
    UI.CraftBox:AddDropdown("CraftRarity", {
    	Text = "Rarities",
    	Values = UI.CraftRarities,
    	ValueImages = UI.CraftRarityImages,
    	Default = { "Basic", "Rare", "Epic", "Legendary", "Mythical" },
    	Multi = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for rarity, on in pairs(value) do
    				if on then pick[rarity] = true end
    			end
    		end
    		S.craftRarity = pick
    	end,
    })
    UI.CraftGoldenRow = UI.CraftBox:AddStat({ Icon = GameIcons.Index, Text = "Golden ready", Value = "0", Size = 26 })
    UI.CraftDiamondRow = UI.CraftBox:AddStat({ Icon = GameIcons.Index, Text = "Diamond ready", Value = "0", Size = 26 })
    UI.CraftDoneRow = UI.CraftBox:AddStat({ Icon = GameIcons.Auto, Text = "Golden / Diamond", Value = "0 / 0", Size = 22 })
    UI.CraftStateRow = UI.CraftBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Idle", Size = 22, ValueColor = "FontColor" })
    
    UI.ItemCraftBox = Tabs.Items:AddLeftGroupbox("Potion & Charm Crafting", "hammer")
    UI.RecipeList = Auto.buildRecipes()
    UI.RecipeDisplay, UI.RecipeImages, UI.RecipeKeys = {}, {}, {}
    for _, recipe in ipairs(UI.RecipeList) do
    	local display = Auto.itemDisplayName(recipe.Result)
    	table.insert(UI.RecipeDisplay, display)
    	UI.RecipeImages[display] = Items.Icons[recipe.Result]
    	UI.RecipeKeys[display] = recipe.Id
    end
    UI.ItemCraftBox:AddDropdown("ItemCraftPick", {
    	Text = "Craft",
    	Values = UI.RecipeDisplay,
    	ValueImages = UI.RecipeImages,
    	Default = {},
    	Multi = true,
    	Searchable = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for display, on in pairs(value) do
    				if on and UI.RecipeKeys[display] then
    					pick[UI.RecipeKeys[display]] = true
    				end
    			end
    		end
    		S.craftPick = pick
    	end,
    })
    UI.ItemCraftBox:AddToggle("AutoItemCraft", {
    	Text = "Auto Craft Items",
    	Description = "Upgrades your potions and charms",
    	Tooltip = "Flies to the Crafting table in Enchanted Grove and crafts the picked recipes once you own the items, fruits and rubies. Equipped charms are never used and your ruby reserve is kept.",
    	Default = false,
    	Callback = function(v)
    		S.autoItemCraft = v
    	end,
    })
    UI.ItemCraftReadyRow = UI.ItemCraftBox:AddStat({ Icon = "hammer", Text = "Ready", Value = "...", Size = 26 })
    UI.ItemCraftStateRow = UI.ItemCraftBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    UI.ItemCraftDoneRow = UI.ItemCraftBox:AddStat({ Icon = Items.Icons.LuckPotion3, Text = "Crafted", Value = "0", Size = 22 })
    UI.ItemCraftBox:AddLabel({ Text = '<font transparency="0.45">Potions III last 10 minutes and beat tier I and II. Charms need 3 to 5 of the tier below plus fruits and rubies.</font>', DoesWrap = true })
    
    UI.TokenIcon = "rbxassetid://125389046620562"
    UI.FishSpotKeys = { ["Best unlocked"] = "Best unlocked", ["Where I stand"] = "Here" }
    UI.FishSpotList = { "Best unlocked" }
    for _, key in ipairs({ "HauntedHouse", "TreasureDunes", "Spawn" }) do
    	local label = prettyWorld(Auto.worldKey(key) or key)
    	table.insert(UI.FishSpotList, label)
    	UI.FishSpotKeys[label] = key
    end
    table.insert(UI.FishSpotList, "Where I stand")
    
    UI.FishBox = Tabs.Fishing:AddLeftGroupbox("Auto Fish", "fish")
    UI.FishBox:AddToggle("AutoFish", {
    	Text = "Auto Fish",
    	Description = "Casts, taps and catches on its own",
    	Tooltip = "Goes to the water, casts the rod and keeps fishing. Errands and the UFO still run, fishing starts again when you are back.",
    	Default = false,
    	Callback = function(v)
    		S.autoFish = v
    	end,
    })
    UI.FishBox:AddToggle("FishSmart", {
    	Text = "Smart Fishing",
    	Description = "Pauses fishing while farming pays more",
    	Tooltip = "Measures what fishing and farming earn per second (fish tokens count as 0) and fishes only while it pays more. Fishing events always fish. It fishes and farms by itself, Auto Fish and Auto Farm do not need to be on.",
    	Default = false,
    	Callback = function(v)
    		S.fishSmart = v
    		if Auto.drive then
    			pcall(Auto.drive)
    		end
    	end,
    })
    UI.FishBox:AddDropdown("FishSpot", {
    	Text = "Fishing spot",
    	Values = UI.FishSpotList,
    	Default = "Best unlocked",
    	Tooltip = "Best unlocked fishes in your best fishing world: Haunted House, then Treasure Dunes, then Spawn. Where I stand never moves you.",
    	Callback = function(v)
    		S.fishSpot = UI.FishSpotKeys[v] or "Best unlocked"
    	end,
    })
    UI.FishBox:AddToggle("FishIndexHunt", {
    	Text = "Fish Index Hunter",
    	Description = "Fishes where your missing fish are",
    	Tooltip = "Checks your index against the fish of every world and fishes in the unlocked world with the best chance of a fish you do not have yet. Overrides Fishing spot until your fish index is done.",
    	Default = false,
    	Callback = function(v)
    		S.fishIndexHunt = v
    	end,
    })
    UI.FishBox:AddToggle("FishIndexGolden", {
    	Text = "Count golden fish",
    	Description = "Golden fish also count as missing",
    	Tooltip = "Golden fish only come from Golden Catch in the Fishing Tree or the Golden Machine, so they are rare. Same as Golden in Complete below.",
    	Default = false,
    	Callback = function(v)
    		S.fishIndexGolden = v
    		local option = Options.FishHuntVariants
    		if option and type(option.Value) == "table" and (option.Value.Golden == true) ~= (v == true) then
    			local value = table.clone(option.Value)
    			value.Golden = v == true
    			pcall(option.SetValue, option, value)
    		end
    	end,
    })
    function Auto.pickSet(value)
    	local pick = {}
    	if type(value) == "table" then
    		for key, on in pairs(value) do
    			if on then
    				pick[key] = true
    			end
    		end
    	end
    	return pick
    end
    UI.FishBox:AddDropdown("FishHuntRarity", {
    	Text = "Hunt rarities",
    	Values = Items.HuntRarities,
    	ValueImages = UI.RarityImages,
    	Default = table.clone(Items.HuntRarities),
    	Multi = true,
    	Tooltip = "Fish Index Hunter only counts missing fish of these rarities.",
    	Callback = function(value)
    		S.fishHuntRarity = Auto.pickSet(value)
    	end,
    })
    UI.FishBox:AddDropdown("FishHuntVariants", {
    	Text = "Complete",
    	Values = { "Normal", "Golden", "Diamond" },
    	Default = { "Normal" },
    	Multi = true,
    	Tooltip = "Which fish variants the hunter completes. Normal is caught, Golden is caught or crafted from normal ones, Diamond is crafted from golden ones at the Diamond Machine.",
    	Callback = function(value)
    		S.fishHuntVariants = Auto.pickSet(value)
    		local toggle = Toggles.FishIndexGolden
    		local golden = S.fishHuntVariants.Golden == true
    		if toggle and toggle.Value ~= golden then
    			pcall(toggle.SetValue, toggle, golden)
    		end
    	end,
    })
    S.fishHuntRarity = Auto.pickSet(Options.FishHuntRarity and Options.FishHuntRarity.Value)
    S.fishHuntVariants = Auto.pickSet(Options.FishHuntVariants and Options.FishHuntVariants.Value)
    -- the variants the fish hunter completes (Count golden fish = Golden)
    function Auto.fishVariantOn(variant)
    	local pick = S.fishHuntVariants or { Normal = true }
    	if variant == "Golden" then
    		return pick.Golden == true or S.fishIndexGolden == true
    	end
    	return pick[variant] == true
    end
    function Auto.fishRarityOn(rarity)
    	local pick = S.fishHuntRarity
    	if type(pick) ~= "table" or next(pick) == nil then
    		return pick == nil
    	end
    	if rarity == nil or not table.find(Items.HuntRarities, rarity) then
    		return true
    	end
    	return pick[rarity] == true
    end
    UI.FishBox:AddToggle("FishTap", {
    	Text = "Auto Tap",
    	Description = "Hits every speed-up for faster catches",
    	Tooltip = "Taps each speed-up at a human pace. Every tap shortens the catch and grows the streak, which adds fishing luck.",
    	Default = false,
    	Callback = function(v)
    		S.fishTap = v
    	end,
    })
    UI.FishBox:AddDropdown("FishTapSpeed", {
    	Text = "Tap Speed",
    	Values = { "Slow", "Normal", "Fast", "Blatant (kick risk)" },
    	Default = "Normal",
    	Tooltip = "How quickly each speed-up is tapped after it shows up. Slow 0.55-0.85s, Normal 0.35-0.55s, Fast 0.24-0.34s. Blatant taps on the next frame, the game warns twice, then kicks, and can ban for near instant taps.",
    	Callback = function(v)
    		S.fishTapSpeed = v
    	end,
    })
    UI.FishBox:AddToggle("FishHideTaps", {
    	Text = "Hide Tap Circles",
    	Default = false,
    	Tooltip = "Hides the speed-up circles from your screen while fishing, taps keep going in the background",
    	Callback = function(v)
    		S.fishHideTaps = v
    		pcall(function()
    			local gui = LocalPlayer:FindFirstChild("PlayerGui")
    			local frame = gui and gui:FindFirstChild("FishingGui") and gui.FishingGui:FindFirstChild("Fishing")
    			for _, child in ipairs(frame and frame:GetChildren() or {}) do
    				if child.Name == "ClickSpeedUpActive" or child.Name == "TapHalo" or child.Name == "TapTimer" then
    					child.Visible = not v
    				end
    			end
    		end)
    	end,
    })
    UI.FishBox:AddDropdown("FishPriority", {
    	Text = "With eggs",
    	Values = { "Eggs first", "Fishing first" },
    	Default = "Eggs first",
    	Tooltip = "The game blocks eggs while you fish. Eggs first stops fishing whenever an egg can be opened. Fishing first pauses Auto Buy Egg, the Index Hunter and inventory eggs while Auto Fish is on.",
    	Callback = function(v)
    		S.fishPriority = tostring(v or "Eggs first")
    	end,
    })
    UI.FishBox:AddLabel({ Text = '<font transparency="0.45">You can fish in Spawn, Treasure Dunes and Haunted House. Every world has its own fish.</font>', DoesWrap = true })
    
    UI.FishStatusBox = Tabs.Fishing:AddRightGroupbox("Fishing Status", "activity")
    UI.FishStateRow = UI.FishStatusBox:AddStat({ Icon = "fish", Text = "Auto Fish", Value = "Off", Size = 26, ValueColor = "FontColor" })
    UI.FishSpotRow = UI.FishStatusBox:AddStat({ Icon = "map-pin", Text = "Spot", Value = "-", Size = 22, ValueColor = "FontColor" })
    UI.FishIndexRow = UI.FishStatusBox:AddStat({ Icon = "book-open", Text = "Fish index", Value = "...", Size = 24, Progress = 0 })
    UI.FishMissingRow = UI.FishStatusBox:AddStat({ Icon = "search", Text = "Hunting", Value = "-", Size = 22, ValueColor = "FontColor" })
    UI.FishFilterRow = UI.FishStatusBox:AddStat({ Icon = GameIcons.Index, Text = "Missing", Value = "-", Size = 22, ValueColor = "FontColor" })
    UI.FishTimerRow = UI.FishStatusBox:AddStat({ Icon = "clock", Text = "Next catch", Value = "-", Size = 22, Progress = 0 })
    UI.FishCatchRow = UI.FishStatusBox:AddStat({ Icon = GameIcons.Auto, Text = "Catches", Value = "0", Size = 22 })
    UI.FishLastRow = UI.FishStatusBox:AddStat({ Icon = "fish", Text = "Last catch", Value = "-", Size = 26 })
    UI.FishStreakRow = UI.FishStatusBox:AddStat({ Icon = "flame", Text = "Tap streak", Value = "0", Size = 22 })
    UI.FishBoostRow = UI.FishStatusBox:AddStat({ Icon = GameIcons.Luck, Text = "Luck  /  speed", Value = "-", Size = 22 })
    UI.FishRodRow = UI.FishStatusBox:AddStat({ Icon = "rbxassetid://87369163614866", Text = "Rod", Value = "-", Size = 22, ValueColor = "FontColor" })
    
    UI.BaitBox = Tabs.Fishing:AddLeftGroupbox("Bait & Hooks", "anchor")
    UI.BaitBox:AddToggle("AutoWorms", {
    	Text = "Auto Use Worms",
    	Description = "Keeps your best worm active while fishing",
    	Tooltip = "Uses the best worm you own when none is active or a better one is in your bag. Worms add fishing luck and egg luck.",
    	Default = false,
    	Callback = function(v)
    		S.autoWorms = v
    	end,
    })
    UI.BaitBox:AddToggle("AutoHooks", {
    	Text = "Auto Use Fishhooks",
    	Description = "Adds hook charges when they run out",
    	Tooltip = "Golden Fishhooks first. Each hook adds fishing luck for its next catches.",
    	Default = false,
    	Callback = function(v)
    		S.autoHooks = v
    	end,
    })
    UI.WormRow = UI.BaitBox:AddStat({ Icon = "rbxassetid://107068290205953", Text = "Worm", Value = "-", Size = 24 })
    UI.HookRow = UI.BaitBox:AddStat({ Icon = "rbxassetid://117784683977288", Text = "Fishhook", Value = "-", Size = 24 })
    
    UI.SellFishNames, UI.SellFishImages = {}, {}
    do
    	local merchant = Auto.GameData.merchant
    	local prices = type(merchant) == "table" and type(merchant.SellPrices) == "table" and merchant.SellPrices or nil
    	if prices then
    		for name in pairs(prices) do
    			table.insert(UI.SellFishNames, name)
    		end
    		table.sort(UI.SellFishNames, function(a, b)
    			if prices[a] ~= prices[b] then
    				return (prices[a] or 0) < (prices[b] or 0)
    			end
    			return a < b
    		end)
    	else
    		UI.SellFishNames = { "Fish", "Tadpole", "Turtle", "Duck", "Shadow Fish", "Octopus", "Ghost Axolotl", "Axolotl", "Jellyfish", "Skeleton Fish", "Shark", "Seaweed Monster", "Blobfish", "Sunken Eel" }
    	end
    	for _, name in ipairs(UI.SellFishNames) do
    		UI.SellFishImages[name] = Auto.GameData.petIcons and Auto.GameData.petIcons[name] or nil
    	end
    	UI.MerchantDisplay, UI.MerchantImages, UI.MerchantKeys, UI.MerchantDefault = {}, {}, {}, {}
    	UI.MerchantNames = { Worm1 = "Juicy Worm", Worm2 = "Golden Worm", UniverseWorm = "Universe Worm", ["1MLuckyblock"] = "1M Lucky Block", GlobalCoins = "Global Coins", GlobalLuck = "Global Luck", GlobalEgg = "Global Egg", VIPKey = "VIP Key", VIPUpper = "VIP Key Top", VIPLower = "VIP Key Bottom" }
    	for _, entry in ipairs(type(merchant) == "table" and type(merchant.Pool) == "table" and merchant.Pool or {}) do
    		local item = tostring(entry.Item)
    		local label = UI.MerchantNames[item] or Auto.itemDisplayName(item)
    		if (tonumber(entry.Amount) or 1) > 1 then
    			label = label .. " x" .. tostring(entry.Amount)
    		end
    		if UI.MerchantKeys[label] then
    			label = label .. "  (" .. tostring(entry.Id) .. ")"
    		end
    		table.insert(UI.MerchantDisplay, label)
    		UI.MerchantKeys[label] = entry.Id
    		UI.MerchantImages[label] = Items.Icons[item] or (type(merchant.ICONS) == "table" and merchant.ICONS[item]) or nil
    		if entry.Rare or item == "Worm1" or item == "Worm2" or item == "Golden Fishhook" then
    			table.insert(UI.MerchantDefault, label)
    		end
    	end
    end
    
    UI.MerchantBox = Tabs.Fishing:AddRightGroupbox("Fishing Merchant", "store")
    UI.MerchantBox:AddToggle("AutoSellFish", {
    	Text = "Auto Sell Fish",
    	Description = "Sells picked fish to the Merchant for tokens",
    	Tooltip = "Flies to the Merchant in Treasure Dunes once enough fish are ready, sells them and flies back. Equipped, locked and mutated pets are never sold.",
    	Default = false,
    	Callback = function(v)
    		S.autoSellFish = v
    	end,
    })
    UI.MerchantBox:AddDropdown("SellFishPick", {
    	Text = "Sell",
    	Values = UI.SellFishNames,
    	ValueImages = UI.SellFishImages,
    	Default = { "Fish", "Turtle", "Tadpole", "Duck", "Shadow Fish" },
    	Multi = true,
    	Searchable = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for name, on in pairs(value) do
    				if on then pick[name] = true end
    			end
    		end
    		S.sellFishPick = pick
    	end,
    })
    UI.MerchantBox:AddDropdown("SellTiers", {
    	Text = "Tiers",
    	Values = { "Normal", "Golden", "Diamond" },
    	Default = { "Normal" },
    	Multi = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for tier, on in pairs(value) do
    				if on then pick[tier] = true end
    			end
    		end
    		S.sellTiers = pick
    	end,
    })
    UI.MerchantBox:AddSlider("KeepFish", {
    	Text = "Keep of each",
    	Min = 0,
    	Max = 25,
    	Default = 0,
    	Rounding = 0,
    	HideMax = true,
    	Tooltip = "How many of every picked fish stay in your inventory",
    	Callback = function(v)
    		S.keepFish = math.clamp(math.floor(tonumber(v) or 0), 0, 25)
    	end,
    })
    UI.MerchantBox:AddSlider("SellAt", {
    	Text = "Sell when ready",
    	Min = 1,
    	Max = 200,
    	Default = 25,
    	Rounding = 0,
    	HideMax = true,
    	Tooltip = "Goes to the Merchant once this many picked fish are ready to sell",
    	Callback = function(v)
    		S.sellAt = math.clamp(math.floor(tonumber(v) or 25), 1, 200)
    	end,
    })
    UI.MerchantBox:AddDivider()
    UI.MerchantBox:AddToggle("AutoMerchantBuy", {
    	Text = "Auto Buy Offers",
    	Description = "Buys picked items when they are in stock",
    	Tooltip = "Checks the Merchant stock every restock and buys the picked offers you can afford with tokens.",
    	Default = false,
    	Callback = function(v)
    		S.autoMerchantBuy = v
    	end,
    })
    UI.MerchantBox:AddDropdown("MerchantPick", {
    	Text = "Buy",
    	Values = UI.MerchantDisplay,
    	ValueImages = UI.MerchantImages,
    	Default = UI.MerchantDefault,
    	Multi = true,
    	Searchable = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on and UI.MerchantKeys[label] then pick[UI.MerchantKeys[label]] = true end
    			end
    		end
    		S.merchantPick = pick
    	end,
    })
    UI.MerchantBox:AddInput("TokenReserve", {
    	Text = "Keep at least (tokens)",
    	Placeholder = "0, 500, 2k...",
    	Finished = true,
    	ClearTextOnFocus = false,
    	Default = "0",
    	Tooltip = "Merchant offers and the Fishing Tree never spend below this.",
    	Callback = function(value)
    		local amount = Auto.parseAmount(value)
    		if amount == nil and tostring(value or "") ~= "" then
    			notify("Fishing", "Use a number like 500 or 2k", 4)
    		end
    		S.tokenReserve = math.max(0, amount or 0)
    	end,
    })
    UI.TokensRow = UI.MerchantBox:AddStat({ Icon = UI.TokenIcon, Text = "Tokens", Value = "...", Size = 28 })
    UI.SellReadyRow = UI.MerchantBox:AddStat({ Icon = "store", Text = "Ready to sell", Value = "-", Size = 22 })
    UI.RestockRow = UI.MerchantBox:AddStat({ Icon = "clock", Text = "Restock", Value = "...", Size = 22, Progress = 0, ValueColor = "FontColor" })
    UI.MerchantStateRow = UI.MerchantBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    
    function Auto.prettyUpgrade(name)
    	local base = string.gsub(name, "Upgrades$", "")
    	return (string.gsub(base, "(%l)(%u)", "%1 %2"))
    end
    
    UI.SpawnUpgradeNames = {}
    do
    	local spawn = Auto.GameData.spawnUpgrades
    	local preferred = { "CoinsUpgrades", "RubiesUpgrades", "LuckUpgrades", "HatchSpeedUpgrades", "CriticalUpgrades", "PetSpeedUpgrades" }
    	local seen = {}
    	local maxLevels = spawn and type(spawn.MaxLevels) == "table" and spawn.MaxLevels or nil
    	for _, name in ipairs(preferred) do
    		if not maxLevels or maxLevels[name] then
    			table.insert(UI.SpawnUpgradeNames, name)
    			seen[name] = true
    		end
    	end
    	if maxLevels then
    		local extra = {}
    		for name in pairs(maxLevels) do
    			if not seen[name] then table.insert(extra, name) end
    		end
    		table.sort(extra)
    		for _, name in ipairs(extra) do table.insert(UI.SpawnUpgradeNames, name) end
    	end
    end
    
    UI.SpawnDisplay, UI.SpawnImages, UI.SpawnKeys, UI.SpawnLabels = {}, {}, {}, {}
    for _, name in ipairs(UI.SpawnUpgradeNames) do
    	local display = Auto.prettyUpgrade(name)
    	UI.SpawnLabels[name] = display
    	table.insert(UI.SpawnDisplay, display)
    	UI.SpawnImages[display] = Items.UpgradeIcons[name]
    	UI.SpawnKeys[display] = name
    end
    
    UI.BudgetBox = Tabs.Upgrades:AddLeftGroupbox("Budget", "wallet")
    UI.BudgetBox:AddDropdown("UpgradeOrder", {
    	Text = "Buy order",
    	Values = { "Best value", "Cheapest first", "Top to bottom" },
    	Default = "Best value",
    	Tooltip = "Best value buys the upgrade that adds the most income per ruby or gem over the next 24 hours. Cheapest first spreads your gems and rubies evenly. Top to bottom maxes one upgrade before the next.",
    	Callback = function(v)
    		S.upgradeOrder = tostring(v or "Cheapest first")
    	end,
    })
    UI.BudgetBox:AddInput("RubyReserve", {
    	ClearTextOnFocus = false,
    	Text = "Keep at least (rubies)",
    	Placeholder = "0, 5k, 2.5m...",
    	Finished = true,
    	Default = "0",
    	Tooltip = "Spawn upgrades, the upgrade tree and special upgrades never spend below this.",
    	Callback = function(value)
    		local amount = Auto.parseAmount(value)
    		if amount == nil and tostring(value or "") ~= "" then
    			notify("Upgrades", "Use a number like 5000, 5k or 2.5m", 4)
    		end
    		S.rubyReserve = math.max(0, amount or 0)
    	end,
    })
    UI.BudgetBox:AddInput("GemReserve", {
    	ClearTextOnFocus = false,
    	Text = "Keep at least (gems)",
    	Placeholder = "0, 100, 1k...",
    	Finished = true,
    	Default = "0",
    	Tooltip = "Moon shops never spend below this.",
    	Callback = function(value)
    		local amount = Auto.parseAmount(value)
    		if amount == nil and tostring(value or "") ~= "" then
    			notify("Upgrades", "Use a number like 500 or 1.5k", 4)
    		end
    		S.gemReserve = math.max(0, amount or 0)
    	end,
    })
    UI.RubiesRow = UI.BudgetBox:AddStat({ Icon = CurrencyIcons.Rubies, Text = "Rubies", Value = "...", Size = 26 })
    UI.MoonGemsRow = UI.BudgetBox:AddStat({ Icon = CurrencyIcons.Gems, Text = "Gems", Value = "...", Size = 26 })
    UI.WorldBuyBox = Tabs.Upgrades:AddRightGroupbox("Worlds", "globe")
    UI.WorldBuyBox:AddToggle("AutoBuyWorlds", {
    	Text = "Auto Buy Worlds",
    	Description = "Unlocks the next world once you can afford it",
    	Tooltip = "Also buys The Moon with rubies. When the next world pays more than any egg, Auto Buy Egg keeps the coins for it.",
    	Default = false,
    	Callback = function(v)
    		S.autoBuyWorlds = v
    	end,
    })
    UI.WorldNextRow = UI.WorldBuyBox:AddStat({ Icon = CurrencyIcons.Coins, Text = "Next world", Value = "...", Size = 28, Progress = 0 })
    UI.WorldOwnedRow = UI.WorldBuyBox:AddStat({ Icon = "globe", Text = "Unlocked", Value = "...", Size = 22 })
        
    UI.SpawnBox = Tabs.Upgrades:AddLeftGroupbox("Spawn Upgrades", "circle-arrow-up")
    UI.SpawnBox:AddToggle("AutoSpawnUpgrades", {
    	Text = "Auto Upgrade",
    	Description = "Buys at the spawn machine with rubies",
    	Default = false,
    	Callback = function(v)
    		S.autoSpawnUp = v
    	end,
    })
    UI.SpawnBox:AddDropdown("SpawnUpgradePick", {
    	Text = "Upgrades",
    	Values = UI.SpawnDisplay,
    	ValueImages = UI.SpawnImages,
    	Default = UI.SpawnDisplay,
    	Multi = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for display, on in pairs(value) do
    				if on and UI.SpawnKeys[display] then pick[UI.SpawnKeys[display]] = true end
    			end
    		end
    		S.spawnPick = pick
    	end,
    })
    UI.SpawnBox:AddDivider()
    UI.SpawnRows = {}
    for _, name in ipairs(UI.SpawnUpgradeNames) do
    	UI.SpawnRows[name] = UI.SpawnBox:AddStat({ Icon = Items.UpgradeIcons[name] or CurrencyIcons.Rubies, Text = Auto.prettyUpgrade(name), Value = "...", Size = 24, Progress = 0 })
    end
    UI.SpawnStateRow = UI.SpawnBox:AddStat({ Icon = CurrencyIcons.Rubies, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    function Auto.moonShopUi(shopKey, title, icon, toggleId, pickId, description)
    	local config = Auto.GameData.moonConfig
    	local shop = config and config[shopKey]
    	local order = shop and type(shop.Order) == "table" and shop.Order or {}
    	local display, images, keys = {}, {}, {}
    	for _, name in ipairs(order) do
    		local label = shop.DisplayNames and shop.DisplayNames[name] or Auto.prettyUpgrade(name)
    		table.insert(display, label)
    		images[label] = shop.Icons and shop.Icons[name] or CurrencyIcons.Gems
    		keys[label] = name
    	end
    	local box = Tabs.Upgrades:AddRightGroupbox(title, icon)
    	box:AddToggle(toggleId, {
    		Text = "Auto Buy",
    		Description = description,
    		Default = false,
    		Callback = function(v)
    			if shopKey == "Permanent" then
    				S.autoMoonPerm = v
    			else
    				S.autoMoonIncr = v
    			end
    		end,
    	})
    	box:AddDropdown(pickId, {
    		Text = "Upgrades",
    		Values = display,
    		ValueImages = images,
    		Default = display,
    		Multi = true,
    		Searchable = #display > 6,
    		Callback = function(value)
    			local pick = {}
    			if type(value) == "table" then
    				for label, on in pairs(value) do
    					if on and keys[label] then pick[keys[label]] = true end
    				end
    			end
    			if shopKey == "Permanent" then
    				S.moonPermPick = pick
    			else
    				S.moonIncrPick = pick
    			end
    		end,
    	})
    	box:AddDivider()
    	local rows, labels = {}, {}
    	for _, name in ipairs(order) do
    		local label = shop.DisplayNames and shop.DisplayNames[name] or Auto.prettyUpgrade(name)
    		labels[name] = label
    		rows[name] = box:AddStat({ Icon = images[label], Text = label, Value = "...", Size = 24, Progress = 0 })
    	end
    	local state = box:AddStat({ Icon = CurrencyIcons.Gems, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    	return { box = box, rows = rows, state = state, order = order, keys = keys, labels = labels }
    end
    
    UI.TreeList, UI.TreeImages, UI.TreeKeys = {}, {}, {}
    do
    	local tree = Auto.GameData.tree
    	local used = {}
    	for _, group in ipairs(tree and tree.Groups or {}) do
    		if group.parent then
    			local label = tostring(group.title or group.id)
    			if used[label] then
    				label = label .. "  (" .. tostring(group.id) .. ")"
    			end
    			used[label] = true
    			table.insert(UI.TreeList, label)
    			UI.TreeImages[label] = group.image
    			UI.TreeKeys[label] = group.id
    		end
    	end
    end
    UI.TreeBox = Tabs.Upgrades:AddLeftGroupbox("Upgrade Tree", "git-branch")
    UI.TreeBox:AddToggle("AutoTree", {
    	Text = "Auto Upgrade Tree",
    	Description = "Buys tree nodes with rubies",
    	Tooltip = "Follows the tree rules: a node opens once the one before it is maxed. Needs the Upgrade Tree special upgrade.",
    	Default = false,
    	Callback = function(v)
    		S.autoTree = v
    	end,
    })
    UI.TreeBox:AddDropdown("TreePick", {
    	Text = "Nodes",
    	Values = UI.TreeList,
    	ValueImages = UI.TreeImages,
    	Default = UI.TreeList,
    	Multi = true,
    	Searchable = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on and UI.TreeKeys[label] then pick[UI.TreeKeys[label]] = true end
    			end
    		end
    		S.treePick = pick
    	end,
    })
    UI.TreeBox:AddDropdown("TreeOrder", {
    	Text = "Order",
    	Values = { "Best value", "Cheapest first", "Tree order" },
    	Default = "Best value",
    	Tooltip = "Best value buys the node that adds the most income per ruby over the next 24 hours, counting the branches it opens. Cheapest first grabs the most nodes for your rubies. Tree order follows the branches as they are drawn.",
    	Callback = function(v)
    		S.treeOrder = tostring(v or "Cheapest first")
    	end,
    })
    UI.TreeOwnedRow = UI.TreeBox:AddStat({ Icon = "git-branch", Text = "Nodes owned", Value = "...", Size = 24, Progress = 0 })
    UI.TreeNextRow = UI.TreeBox:AddStat({ Icon = CurrencyIcons.Rubies, Text = "Next", Value = "-", Size = 26 })
    UI.TreeStateRow = UI.TreeBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    UI.SpecialList, UI.SpecialKeys = {}, {}
    do
    	local counts = {}
    	for _, entry in ipairs(Auto.GameData.special or {}) do
    		counts[entry.title] = (counts[entry.title] or 0) + 1
    	end
    	for _, entry in ipairs(Auto.GameData.special or {}) do
    		local label = if counts[entry.title] > 1 then string.format("%s  #%d", entry.title, entry.index) else entry.title
    		table.insert(UI.SpecialList, label)
    		UI.SpecialKeys[label] = entry.name
    	end
    end
    UI.SpecialBox = Tabs.Upgrades:AddLeftGroupbox("Special Upgrades", "sparkle")
    UI.SpecialBox:AddToggle("AutoSpecial", {
    	Text = "Auto Special Upgrades",
    	Description = "Travels to each one and buys it",
    	Tooltip = "The one time upgrades spread across the worlds, like +1 Egg Open, Fast Travel and the Upgrade Tree. Cheapest first, only in worlds you own.",
    	Default = false,
    	Callback = function(v)
    		S.autoSpecial = v
    	end,
    })
    UI.SpecialBox:AddDropdown("SpecialPick", {
    	Text = "Upgrades",
    	Values = UI.SpecialList,
    	Default = UI.SpecialList,
    	Multi = true,
    	Searchable = #UI.SpecialList > 6,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on and UI.SpecialKeys[label] then pick[UI.SpecialKeys[label]] = true end
    			end
    		end
    		S.specialPick = pick
    	end,
    })
    UI.SpecialOwnedRow = UI.SpecialBox:AddStat({ Icon = "sparkle", Text = "Owned", Value = "...", Size = 24, Progress = 0 })
    UI.SpecialNextRow = UI.SpecialBox:AddStat({ Icon = CurrencyIcons.Rubies, Text = "Next", Value = "-", Size = 26 })
    UI.SpecialStateRow = UI.SpecialBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    UI.FishTreeList, UI.FishTreeImages, UI.FishTreeKeys = {}, {}, {}
    do
    	local tree = Auto.GameData.fishTree
    	local used = {}
    	for _, group in ipairs(tree and tree.Groups or {}) do
    		if group.parent then
    			local label = tostring(group.title or group.id)
    			if used[label] then
    				label = label .. "  (" .. tostring(group.id) .. ")"
    			end
    			used[label] = true
    			table.insert(UI.FishTreeList, label)
    			UI.FishTreeImages[label] = group.image
    			UI.FishTreeKeys[label] = group.id
    		end
    	end
    end
    UI.FishTreeBox = Tabs.Upgrades:AddLeftGroupbox("Fishing Tree", "fish")
    UI.FishTreeBox:AddToggle("AutoFishTree", {
    	Text = "Auto Fishing Tree",
    	Description = "Buys fishing nodes with tokens",
    	Tooltip = "Visits the Merchant in Treasure Dunes and buys the picked nodes as soon as you have the tokens. A node opens once the one before it is bought. Keeps the token reserve from the Fishing tab.",
    	Default = false,
    	Callback = function(v)
    		S.autoFishTree = v
    	end,
    })
    UI.FishTreeBox:AddDropdown("FishTreePick", {
    	Text = "Nodes",
    	Values = UI.FishTreeList,
    	ValueImages = UI.FishTreeImages,
    	Default = UI.FishTreeList,
    	Multi = true,
    	Searchable = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on and UI.FishTreeKeys[label] then pick[UI.FishTreeKeys[label]] = true end
    			end
    		end
    		S.fishTreePick = pick
    	end,
    })
    UI.FishTreeBox:AddDropdown("FishTreeOrder", {
    	Text = "Order",
    	Values = { "Best value", "Cheapest first", "Tree order" },
    	Default = "Best value",
    	Tooltip = "Best value: buys what gives the most boost per token you can afford right now, and counts the branches a node opens.\nCheapest first: always the cheapest open node.\nTree order: follows the tree from top to bottom.",
    	Callback = function(v)
    		S.fishTreeOrder = tostring(v or "Best value")
    	end,
    })
    UI.FishTreeOwnedRow = UI.FishTreeBox:AddStat({ Icon = "git-branch", Text = "Nodes owned", Value = "...", Size = 24, Progress = 0 })
    UI.FishTreeNextRow = UI.FishTreeBox:AddStat({ Icon = "rbxassetid://125389046620562", Text = "Next", Value = "-", Size = 26 })
    UI.FishTreeStateRow = UI.FishTreeBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    UI.MoonPerm = Auto.moonShopUi("Permanent", "Moon Permanent", "moon", "AutoMoonPerm", "MoonPermPick", "Kept forever, paid with purple gems")
    UI.MoonIncr = Auto.moonShopUi("Incremental", "Moon Incremental", "sparkles", "AutoMoonIncr", "MoonIncrPick", "Resets on rebirth, paid with gems")
    UI.MoonIncr.box:AddToggle("MoonGameAuto", {
    	Text = "Use the game's Auto Buy",
    	Description = "No more Moon trips for incremental upgrades",
    	Tooltip = "Needs the Auto Buy Upgrades special upgrade. Corvus flies to the Moon once and switches the game's own Auto Buy on, then it buys every incremental upgrade without trips.",
    	Default = false,
    	Callback = function(v)
    		S.moonGameAuto = v
    	end,
    })
    UI.MoonAutoRow = UI.MoonIncr.box:AddStat({ Icon = "moon", Text = "Game Auto Buy", Value = "...", Size = 22, ValueColor = "FontColor" })
    
    UI.RebirthBox = Tabs.Upgrades:AddRightGroupbox("Moon Rebirth", "orbit")
    UI.RebirthBox:AddToggle("AutoRebirth", {
    	Text = "Auto Moon Rebirth",
    	Description = "Rebirths when the moon shop is maxed",
    	Tooltip = "Pairs with Auto Buy on Moon Incremental: it buys everything, rebirths, and starts again with more upgrades.",
    	Default = false,
    	Callback = function(v)
    		S.autoRebirth = v
    	end,
    })
    UI.RebirthBox:AddToggle("RebirthWaitPerm", {
    	Text = "Wait For Permanent Max",
    	Description = "Rebirths only once Moon Permanent is maxed",
    	Tooltip = "Maxed means every Moon Permanent upgrade is as high as your current rebirth allows. Pair it with Auto Buy on Moon Permanent.",
    	Default = false,
    	Callback = function(v)
    		S.rebirthWaitPerm = v
    	end,
    })
    UI.RebirthBox:AddToggle("RebirthSmart", {
    	Text = "Rebirth By Payback",
    	Description = "Rebirths when the gem gain beats the rebuild",
    	Tooltip = "Rebirths only when the extra gems over 24 hours are worth more than the income lost while the Moon Incremental shop is bought again. Replaces Wait For Permanent Max while on and rebirths by itself, Auto Rebirth does not need to be on.",
    	Default = false,
    	Callback = function(v)
    		S.rebirthSmart = v
    		if Auto.drive then
    			pcall(Auto.drive)
    		end
    	end,
    })
    UI.RebirthBox:AddInput("RebirthStopAt", {
    	ClearTextOnFocus = false,
    	Text = "Stop at rebirth",
    	Placeholder = "0 = never",
    	Numeric = true,
    	Finished = true,
    	Default = "0",
    	Callback = function(value)
    		S.rebirthStopAt = math.max(0, math.floor(tonumber(value) or 0))
    	end,
    })
    UI.RebirthProgressRow = UI.RebirthBox:AddStat({ Icon = "orbit", Text = "Progress", Value = "...", Size = 24, Progress = 0 })
    UI.MoonRebirthRow = UI.RebirthBox:AddStat({ Icon = GameIcons.MoonChest, Text = "Moon rebirths", Value = "...", Size = 22, ValueColor = "FontColor" })
    UI.PermMaxRow = UI.RebirthBox:AddStat({ Icon = "moon", Text = "Permanent shop", Value = "...", Size = 22, Progress = 0 })
    UI.RebirthStateRow = UI.RebirthBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    
    UI.ServerLuckBox = Tabs.Upgrades:AddRightGroupbox("Server Luck", "clover")
    UI.ServerLuckBox:AddToggle("AutoServerLuck", {
    	Text = "Auto Server Luck",
    	Description = "Keeps the server luck boost topped up",
    	Tooltip = "Flies to the Server Luck machine in Volcano Hollow and buys more time with rubies when it runs low. It boosts everyone on the server, up to x2 at 5 hours. Your ruby reserve from Budget is kept.",
    	Default = false,
    	Callback = function(v)
    		S.autoServerLuck = v
    	end,
    })
    UI.ServerLuckBox:AddDropdown("ServerLuckMode", {
    	Text = "Buy",
    	Values = { "10 minutes", "1 hour", "Max" },
    	Default = "1 hour",
    	Tooltip = "10 minutes costs 750k rubies, 1 hour costs 4.5M. Max fills the timer up to 5 hours.",
    	Callback = function(v)
    		S.luckMode = tostring(v or "1 hour")
    	end,
    })
    UI.LuckKeepValues = { ["Under 10 minutes"] = 600, ["Under 30 minutes"] = 1800, ["Under 1 hour"] = 3600, ["Under 2 hours"] = 7200, ["Under 4 hours"] = 14400 }
    UI.ServerLuckBox:AddDropdown("ServerLuckKeep", {
    	Text = "Buy when",
    	Values = { "Under 10 minutes", "Under 30 minutes", "Under 1 hour", "Under 2 hours", "Under 4 hours" },
    	Default = "Under 10 minutes",
    	Callback = function(v)
    		S.luckKeep = UI.LuckKeepValues[v] or 600
    	end,
    })
    UI.ServerLuckNowRow = UI.ServerLuckBox:AddStat({ Icon = GameIcons.Luck, Text = "Server luck", Value = "...", Size = 28, Progress = 0 })
    UI.ServerLuckPriceRow = UI.ServerLuckBox:AddStat({ Icon = CurrencyIcons.Rubies, Text = "Price", Value = "...", Size = 22, ValueColor = "FontColor" })
    UI.ServerLuckStateRow = UI.ServerLuckBox:AddStat({ Icon = GameIcons.Auto, Text = "Status", Value = "Off", Size = 22, ValueColor = "FontColor" })
    UI.ServerLuckBoughtRow = UI.ServerLuckBox:AddStat({ Icon = "shopping-cart", Text = "Bought", Value = "0", Size = 22 })
    
    UI.TeamBox = Tabs.Items:AddRightGroupbox("Team", "users-round")
    UI.TeamPowerRow = UI.TeamBox:AddStat({ Icon = GameIcons.EquipBest, Text = "Team power", Value = "...", Size = 30 })
    UI.TeamRows = {}
    for i = 1, 16 do
    	local row = UI.TeamBox:AddStat({ Text = "", Value = "", Size = 26 })
    	pcall(row.SetVisible, row, false)
    	UI.TeamRows[i] = row
    end
    UI.TeamMoreLabel = UI.TeamBox:AddLabel({ Text = "", DoesWrap = true })
    pcall(UI.TeamMoreLabel.SetVisible, UI.TeamMoreLabel, false)
    
    UI.FriendBox = Tabs.Misc:AddRightGroupbox("Friends", "user-plus")
    UI.FriendBox:AddToggle("AutoFriendSend", {
    	Text = "Auto send requests",
    	Description = "One request to everyone in the server",
    	Tooltip = "Friends in the same server give a coin and luck boost. Each player gets at most one request per session.",
    	Default = false,
    	Callback = function(v)
    		S.autoFriendSend = v
    	end,
    })
    UI.FriendBox:AddToggle("AutoFriendAccept", {
    	Text = "Auto accept requests",
    	Description = "Accepts incoming friend requests",
    	Default = false,
    	Callback = function(v)
    		S.autoFriendAccept = v
    	end,
    })
    UI.FriendBoostRow = UI.FriendBox:AddStat({ Icon = GameIcons.Friend, Text = "Boost", Value = "+0%", Size = 30 })
    UI.FriendCountRow = UI.FriendBox:AddStat({ Icon = "users-round", Text = "Friends in server", Value = "...", Size = 22 })
    UI.FriendSentRow = UI.FriendBox:AddStat({ Icon = "send", Text = "Requests sent", Value = "0", Size = 22 })
    
    do
    	local afkBox = Tabs.Misc and Tabs.Misc.Groupboxes and Tabs.Misc.Groupboxes["Anti AFK"]
    	UI.AfkPings = 0
    	if afkBox then
    		afkBox:AddToggle("StopAfkRejoin", {
    			Text = "Stop AFK rejoin",
    			Description = "The game no longer moves you when you go AFK",
    			Tooltip = "Pets Universe sends idle players through a rejoin. This keeps your session active, so you stay in your server while Corvus farms.",
    			Default = true,
    			Callback = function(v)
    				S.stopAfkRejoin = v
    			end,
    		})
    		UI.AfkPingRow = afkBox:AddStat({ Icon = "radio", Text = "Activity sent", Value = "0", Size = 22 })
    	end
    	task.spawn(function()
    		local nextPing, nextNudge = 0, 0
    		while alive() do
    			task.wait(5)
    			local now = os.clock()
    			if S.stopAfkRejoin and now >= nextNudge then
    				nextNudge = now + 50 + math.random() * 20
    				pcall(function()
    					local virtualUser = game:GetService("VirtualUser")
    					virtualUser:CaptureController()
    					virtualUser:ClickButton2(Vector2.new())
    				end)
    			end
    			if S.stopAfkRejoin and now >= nextPing then
    				local remote = Auto.knitRemote("AutoRejoinService", "RE", "ReportActivity")
    				nextPing = now + (if remote then 35 + math.random() * 15 else 30)
    				if remote and pcall(function() remote:FireServer() end) then
    					UI.AfkPings += 1
    					if UI.AfkPingRow then
    						setStat(UI.AfkPingRow, nil, formatNumber(UI.AfkPings))
    					end
    				end
    			end
    		end
    	end)
    end
    
    UI.HookBox = Tabs.Webhook:AddLeftGroupbox("Discord", "webhook")
    UI.HookBox:AddToggle("WebhookOn", {
    	Text = "Discord posts",
    	Description = "Master switch for everything on this tab",
    	Default = false,
    	Callback = function(v)
    		S.webhookOn = v
    	end,
    })
    UI.HookBox:AddInput("WebhookUrl", {
    	ClearTextOnFocus = false,
    	Text = "Webhook URL",
    	Placeholder = "https://discord.com/api/webhooks/...",
    	Finished = true,
    	Default = "",
    	Callback = function(value)
    		S.webhookUrl = tostring(value or "")
    	end,
    })
    UI.HookBox:AddInput("WebhookName", {
    	ClearTextOnFocus = false,
    	Text = "Bot name",
    	Placeholder = "Corvus",
    	Finished = true,
    	Default = "Corvus",
    	Tooltip = "The name the posts show in Discord. Names with Discord or Clyde in them are not allowed by Discord.",
    	Callback = function(value)
    		S.webhookName = tostring(value or "")
    	end,
    })
    UI.HookBox:AddToggle("WebhookHideName", {
    	Text = "Hide my username",
    	Description = "Posts and the profile card stay anonymous",
    	Default = false,
    	Callback = function(v)
    		S.webhookHideName = v
    	end,
    })
    UI.HookBox:AddInput("WebhookPingId", {
    	ClearTextOnFocus = false,
    	Text = "Ping user ID",
    	Placeholder = "Your Discord user ID",
    	Finished = true,
    	Default = "",
    	Tooltip = "In Discord turn on Settings > Advanced > Developer Mode, then right click your name and pick Copy User ID.",
    	Callback = function(value)
    		S.pingId = tostring(value or "")
    		if S.pingId ~= "" and not string.match(S.pingId, "^%s*%d+%s*$") then
    			notify("Webhook", "A user ID is only numbers, like 123456789012345678", 4)
    		end
    	end,
    })
    UI.PingMap = { ["Secret hatch"] = "Secret", ["Mythical or better"] = "Mythical", ["Picked pets"] = "Picked", ["Mutated hatch"] = "Mutated", ["UFO win"] = "UFO", ["Rare catch"] = "Fish", ["Goal reached"] = "Goals", ["World unlocked"] = "World", ["Moon rebirth"] = "Rebirth" }
    UI.HookBox:AddDropdown("WebhookPingFor", {
    	Text = "Ping me for",
    	Values = { "Secret hatch", "Mythical or better", "Picked pets", "Mutated hatch", "UFO win", "Rare catch", "Goal reached", "World unlocked", "Moon rebirth" },
    	Default = { "Secret hatch", "UFO win" },
    	Multi = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on and UI.PingMap[label] then pick[UI.PingMap[label]] = true end
    			end
    		end
    		S.pingFor = pick
    	end,
    })
    UI.HookBox:AddButton({
    	Text = "Send test",
    	Func = function()
    		if Auto.sendTestWebhook then
    			Auto.sendTestWebhook()
    		end
    	end,
    })
    UI.HookSentRow = UI.HookBox:AddStat({ Icon = "send", Text = "Sent", Value = "0", Size = 22 })
    UI.HookLastRow = UI.HookBox:AddStat({ Icon = "radio", Text = "Last post", Value = "-", Size = 22, ValueColor = "FontColor" })
    
    UI.HatchHookBox = Tabs.Webhook:AddRightGroupbox("Hatch Posts", "egg")
    UI.HatchHookBox:AddToggle("WebhookHatches", {
    	Text = "Hatch posts",
    	Description = "Rare pets the moment they hatch",
    	Default = true,
    	Callback = function(v)
    		S.webhookHatches = v
    	end,
    })
    UI.HatchHookBox:AddDropdown("WebhookRarity", {
    	Text = "Rarities",
    	Values = Items.Rarities,
    	ValueImages = UI.CraftRarityImages,
    	Default = { "Mythical", "Secret" },
    	Multi = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for rarity, on in pairs(value) do
    				if on then pick[rarity] = true end
    			end
    		end
    		S.webhookRarity = pick
    	end,
    })
    UI.HatchHookBox:AddDropdown("WebhookPets", {
    	Text = "Picked pets",
    	Values = Auto.GameData.petNames or {},
    	Default = {},
    	Multi = true,
    	Searchable = true,
    	AllowNull = true,
    	Tooltip = "These pets always post, whatever their rarity or chance",
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for name, on in pairs(value) do
    				if on then pick[name] = true end
    			end
    		end
    		S.webhookPets = pick
    	end,
    })
    UI.HatchHookBox:AddToggle("WebhookMutated", {
    	Text = "Post mutated hatches",
    	Description = "Wet, UFO, Hacker, Rainbow and other mutations, any rarity",
    	Default = false,
    	Callback = function(v)
    		S.webhookMutated = v
    	end,
    })
    UI.HatchHookBox:AddInput("WebhookMinOneIn", {
    	ClearTextOnFocus = false,
    	Text = "Only 1 in X or rarer",
    	Placeholder = "0 = any chance",
    	Finished = true,
    	Default = "0",
    	Tooltip = "Skips rarity posts that are more common than 1 in X from that egg, before luck. Picked pets always post. Use 10k, 1m and so on.",
    	Callback = function(value)
    		local amount = Auto.parseAmount(value)
    		if amount == nil and tostring(value or "") ~= "" then
    			notify("Webhook", "Use a number like 1000, 10k or 1m", 4)
    		end
    		S.webhookMinOneIn = math.max(0, amount or 0)
    	end,
    })
    
    UI.EventHookBox = Tabs.Webhook:AddLeftGroupbox("Event Posts", "bell")
    UI.EventHookBox:AddToggle("WebhookEventsOn", {
    	Text = "Event posts",
    	Description = "UFO, worlds, rebirths, codes, goals and rare catches",
    	Default = true,
    	Callback = function(v)
    		S.webhookEventsOn = v
    	end,
    })
    UI.HookEventMap = { ["UFO broken"] = "UFO", ["World unlocked"] = "World", ["Moon rebirth"] = "Rebirth", ["Special upgrade"] = "Special", ["Code redeemed"] = "Codes", ["Goal reached"] = "Goals", ["Rare catch"] = "Fish" }
    UI.EventHookBox:AddDropdown("WebhookEvents", {
    	Text = "Post",
    	Values = { "UFO broken", "World unlocked", "Moon rebirth", "Special upgrade", "Code redeemed", "Goal reached", "Rare catch" },
    	Default = { "UFO broken", "World unlocked", "Moon rebirth", "Special upgrade", "Code redeemed", "Goal reached", "Rare catch" },
    	Multi = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on and UI.HookEventMap[label] then pick[UI.HookEventMap[label]] = true end
    			end
    		end
    		S.hookEvents = pick
    	end,
    })
    UI.EventHookBox:AddDropdown("WebhookUfoMode", {
    	Text = "UFO posts",
    	Values = { "Only when I win", "When I'm top 3", "Every UFO I helped" },
    	Default = "Only when I win",
    	Tooltip = "The winner is the player who gets the Alien Egg. Top 3 comes from the damage board above the UFO.",
    	Callback = function(v)
    		S.ufoHookMode = tostring(v or "Only when I win")
    	end,
    })
    
    UI.CardBox = Tabs.Webhook:AddRightGroupbox("Profile Card", "id-card")
    UI.CardBox:AddToggle("WebhookProfile", {
    	Text = "Live profile card",
    	Description = "One Discord message that keeps itself updated",
    	Tooltip = "Posts your profile once and then edits that same message: currencies, rates, eggs, index, best pets, fishing and more. It keeps editing the same card after a rejoin.",
    	Default = false,
    	Callback = function(v)
    		S.profileOn = v
    		if v and Auto.Card then
    			Auto.Card.nextAt = 0
    		end
    	end,
    })
    UI.CardEvery = { ["1 minute"] = 60, ["2 minutes"] = 120, ["5 minutes"] = 300, ["10 minutes"] = 600, ["15 minutes"] = 900, ["30 minutes"] = 1800 }
    UI.CardBox:AddDropdown("WebhookProfileEvery", {
    	Text = "Update every",
    	Values = { "1 minute", "2 minutes", "5 minutes", "10 minutes", "15 minutes", "30 minutes" },
    	Default = "5 minutes",
    	Callback = function(v)
    		S.profileEvery = UI.CardEvery[v] or 300
    		if Auto.Card then
    			Auto.Card.nextAt = math.min(Auto.Card.nextAt, os.clock() + S.profileEvery)
    		end
    	end,
    })
    UI.CardSections = { "Activity", "Currencies", "Rates per hour", "Eggs", "Index", "Best pets", "Team", "Worlds and rebirths", "Fishing", "UFO", "Boosts" }
    UI.CardBox:AddDropdown("WebhookProfileShow", {
    	Text = "Show",
    	Values = UI.CardSections,
    	Default = UI.CardSections,
    	Multi = true,
    	AllowNull = true,
    	Callback = function(value)
    		local pick = {}
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on then pick[label] = true end
    			end
    		end
    		S.profileShow = pick
    	end,
    })
    UI.CardBox:AddToggle("WebhookProfileButtons", {
    	Text = "Link buttons",
    	Description = "Play and Corvus Discord buttons under the card",
    	Default = true,
    	Callback = function(v)
    		S.profileButtons = v
    	end,
    })
    UI.CardBox:AddButton({
    	Text = "Refresh now",
    	Func = function()
    		if Auto.refreshCard then
    			Auto.refreshCard(false)
    		end
    	end,
    }):AddButton({
    	Text = "New card",
    	DoubleClick = true,
    	Tooltip = "Posts a fresh card and stops editing the old one",
    	Func = function()
    		if Auto.refreshCard then
    			Auto.refreshCard(true)
    		end
    	end,
    })
    UI.CardStateRow = UI.CardBox:AddStat({ Icon = "id-card", Text = "Card", Value = "Off", Size = 24, ValueColor = "FontColor" })
    UI.CardNextRow = UI.CardBox:AddStat({ Icon = "clock", Text = "Next update", Value = "-", Size = 22, ValueColor = "FontColor" })
    UI.CardBox:AddLabel({ Text = '<font transparency="0.45">Discord lets webhooks add link buttons only, so the card refreshes itself on the timer above and with Refresh now. A refresh button you click inside Discord needs a Discord bot.</font>', DoesWrap = true })
    
    UI.StartBox = Tabs.Info:AddLeftGroupbox("Quick Start", "wand-sparkles")
    UI.StartBox:AddLabel({ Text = '<font transparency="0.4">Tell Corvus what to do in three taps: what to automate, which egg and how your game runs. Everything can be changed later.</font>', DoesWrap = true })
    UI.StartBox:AddButton({
    	Text = "Open quick setup",
    	Func = function()
    		if Auto.openWizard then
    			Auto.openWizard()
    		end
    	end,
    })
    
    UI.FeedbackBox = Tabs.FeedbackBox or Tabs.Info:AddLeftGroupbox("Feedback", "message-square")
    UI.FeedbackBox:AddDropdown("FeedbackType", {
    	Text = "Type",
    	Values = { "Idea", "Bug", "Question", "Other" },
    	Default = "Idea",
    	Callback = function() end,
    })
    UI.FeedbackBox:AddInput("FeedbackText", {
    	Text = "Message",
    	Placeholder = "Tell Cinek what to add or fix...",
    	Finished = false,
    	Default = "",
    	Callback = function() end,
    })
    UI.FeedbackBox:AddToggle("FeedbackAnon", {
    	Text = "Send anonymously",
    	Default = false,
    	Callback = function() end,
    })
    UI.FeedbackBox:AddButton({
    	Text = "Send feedback",
    	Func = function()
    		if Auto.sendFeedback then
    			Auto.sendFeedback()
    		end
    	end,
    })
    
    S.fruitPick = Auto.pickFromMulti(Options.FruitPick.Value)
    S.potionPick = Auto.pickFromMulti(Options.PotionPick.Value)
    S.luckyPick = Auto.pickFromMulti(Options.LuckyPick.Value)
    do
    	local pick = {}
    	for rarity, on in pairs(Options.HuntRarity.Value or {}) do
    		if on then pick[rarity] = true end
    	end
    	S.huntRarity = pick
    	local variants = {}
    	for variant, on in pairs(Options.HuntVariants.Value or {}) do
    		if on then variants[variant] = true end
    	end
    	S.huntVariants = variants
    	local craftPick = {}
    	for rarity, on in pairs(Options.CraftRarity.Value or {}) do
    		if on then craftPick[rarity] = true end
    	end
    	S.craftRarity = craftPick
    	local function pickKeys(option, keys)
    		local pick = {}
    		local value = option and option.Value
    		if type(value) == "table" then
    			for label, on in pairs(value) do
    				if on and (keys == nil or keys[label]) then
    					pick[if keys then keys[label] else label] = true
    				end
    			end
    		end
    		return pick
    	end
    	S.spawnPick = pickKeys(Options.SpawnUpgradePick, UI.SpawnKeys)
    	S.moonPermPick = pickKeys(Options.MoonPermPick, UI.MoonPerm.keys)
    	S.moonIncrPick = pickKeys(Options.MoonIncrPick, UI.MoonIncr.keys)
    	S.webhookRarity = pickKeys(Options.WebhookRarity, nil)
    	S.treePick = pickKeys(Options.TreePick, UI.TreeKeys)
    	S.specialPick = pickKeys(Options.SpecialPick, UI.SpecialKeys)
    	S.hookEvents = pickKeys(Options.WebhookEvents, UI.HookEventMap)
    	S.sellFishPick = pickKeys(Options.SellFishPick, nil)
    	S.sellTiers = pickKeys(Options.SellTiers, nil)
    	S.merchantPick = pickKeys(Options.MerchantPick, UI.MerchantKeys)
    	S.fishTreePick = pickKeys(Options.FishTreePick, UI.FishTreeKeys)
    	S.invEggKeep = pickKeys(Options.InvEggKeep, nil)
    	S.pingFor = pickKeys(Options.WebhookPingFor, UI.PingMap)
    	S.profileShow = pickKeys(Options.WebhookProfileShow, nil)
    	S.questPick = {}
    	local questMap = { ["Index rewards"] = "Index", ["Daily reward"] = "Daily", ["Group reward"] = "Group", ["Like, group, favorite"] = "Verify" }
    	for display, on in pairs(Options.QuestPick and Options.QuestPick.Value or {}) do
    		if on and questMap[display] then S.questPick[questMap[display]] = true end
    	end
    end
    
    task.spawn(function()
    	while alive() do
    		task.wait(1)
    		if S.autoGift and ClaimGift then
    			for i = 1, 9 do
    				if not alive() then return end
    				pcall(function() ClaimGift:FireServer("Gift" .. i) end)
    			end
    		end
    	end
    end)
    
    task.spawn(function()
    	while alive() do
    		task.wait(1)
    		if S.autoPartyEgg and PartyEggClaim then
    			local data = getPartyStatus()
    			if data and data.ready then
    				pcall(function() PartyEggClaim:FireServer() end)
    			end
    		end
    	end
    end)
    
    local Snap = {
    	farm = { state = "idle", area = "", suffix = "" },
    	best = {},
    }
    
    do
    	local function setupAutomation()
    		local function queueToast(title, text)
    			table.insert(NotifyQueue, { title, text })
    		end
    
    		local function shortError(err)
    			local text = tostring(err)
    			text = string.gsub(text, "^.-:%d+: ", "")
    			if #text > 80 then
    				text = string.sub(text, 1, 77) .. "..."
    			end
    			return text
    		end
    
    		local function readData(folderName, childName)
    			local folder = getDataFolder(folderName)
    			local child = folder and folder:FindFirstChild(childName)
    			if not child then return nil end
    			local ok, value = pcall(function() return child.Value end)
    			if ok then return value end
    			return nil
    		end
    
    		local function isWorldUnlocked(world)
    			if world == "Spawn" then return true end
    			local value = readData("WorldsData", world)
    			if value == nil then return nil end
    			return value == true
    		end
    
    		local function currentWorld()
    			local hrp = getRoot()
    			return hrp and getWorldAt(hrp.Position) or nil
    		end
    
    		local Mover = { busy = false, task = "" }
    
    		local function travelTo(world)
    			local hrp = getRoot()
    			if not hrp then return false, "Character is not loaded" end
    			if getWorldAt(hrp.Position) == world then return true end
    			if isWorldUnlocked(world) == false then
    				Auto.logEvery("tplocked:" .. tostring(world), 300, "TP", "fail", "world=" .. tostring(world), "reason=locked")
    				return false, prettyWorld(world) .. " is locked"
    			end
    			if not WorldGoTo then
    				Auto.logEvery("tpnone", 600, "TP", "fail", "world=" .. tostring(world), "reason=no GoTo remote")
    				return false, "Teleport is unavailable"
    			end
    			local previous = Mover.task
    			Mover.task = "Travelling to " .. prettyWorld(world)
    			pcall(function() WorldGoTo:FireServer(world) end)
    			local waited = 0
    			repeat
    				waited += task.wait(0.2) or 0.2
    				hrp = getRoot()
    			until waited >= 10 or not alive() or (hrp and getWorldAt(hrp.Position) == world)
    			Mover.task = previous
    			if not (hrp and getWorldAt(hrp.Position) == world) then
    				Auto.logEvery("tpfail:" .. tostring(world), 120, "TP", "fail", "world=" .. tostring(world), "reason=not there after " .. string.format("%.1f", waited) .. "s", "at=" .. tostring(hrp and getWorldAt(hrp.Position)))
    				return false, "Could not reach " .. prettyWorld(world)
    			end
    			Auto.log("TP", "ok", "world=" .. tostring(world), "t=" .. string.format("%.1f", waited))
    			task.wait(0.8)
    			return true
    		end
    
    		local function getMachine(name)
    			local map = workspace:FindFirstChild("Map")
    			local machines = map and map:FindFirstChild("Machines")
    			local machine = machines and machines:FindFirstChild(name)
    			return machine, machine and machine:FindFirstChild("rewardTouch")
    		end
    
    		local function machineWorld(machineName, fallback)
    			local _, touch = getMachine(machineName)
    			if touch then
    				local ok, world = pcall(getWorldAt, touch.Position)
    				if ok and world then
    					return world
    				end
    			end
    			local worlds = Auto.GameData.machineWorlds
    			local mapped = worlds and worlds[machineName]
    			if mapped then
    				return Auto.worldKey(mapped)
    			end
    			return fallback
    		end
    
    		local function moonWorld()
    			local cost = Auto.GameData.worldCost
    			return Auto.worldKey(cost and cost.MoonWorld or "TheMoon") or "TheMoon"
    		end
    
    		local function standAt(part, gap)
    			local hrp = getRoot()
    			if not (hrp and part and part.Parent) then return false end
    			local center = part.Position
    			local radius = math.max(part.Size.X, part.Size.Z) / 2
    			local circle = part.Parent:FindFirstChild("EffectCircle")
    			local floorY = if circle and circle:IsA("BasePart") then circle.Position.Y + 3.4 else center.Y + 1
    			local spot
    			if gap <= 0 then
    				spot = Vector3.new(center.X, floorY, center.Z)
    			else
    				local away = hrp.Position - center
    				away = Vector3.new(away.X, 0, away.Z)
    				away = if away.Magnitude > 0.1 and away.Magnitude < 400 then away.Unit else Vector3.new(0, 0, 1)
    				spot = center + away * (radius + gap)
    				spot = Vector3.new(spot.X, floorY, spot.Z)
    			end
    			pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    			if gap <= 0 then
    				hrp.CFrame = CFrame.new(spot) * hrp.CFrame.Rotation
    			else
    				hrp.CFrame = CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
    			end
    			return true
    		end
    
    		local function touchPart(part)
    			local hrp = getRoot()
    			if not (hrp and part) then return end
    			if type(firetouchinterest) == "function" then
    				pcall(function()
    					firetouchinterest(hrp, part, 0)
    					task.wait(0.1)
    					firetouchinterest(hrp, part, 1)
    				end)
    			end
    		end
    
    		local function hideGameFrame(path)
    			pcall(function()
    				local node = LocalPlayer:FindFirstChild("PlayerGui")
    				for _, name in ipairs(path) do
    					node = node and node:FindFirstChild(name)
    				end
    				if node and node:IsA("GuiObject") then
    					node.Visible = false
    				end
    			end)
    		end
    
    		local function moveToEgg(name)
    			if name == "" then return false, "Select an egg first" end
    			local world = Auto.eggWorld(name)
    			local ok, err = travelTo(world)
    			if not ok then return false, err end
    			local model
    			local waited = 0
    			repeat
    				model = getEggModel(name)
    				if model then break end
    				waited += task.wait(0.25) or 0.25
    			until waited >= 4
    			local hrp = getRoot()
    			if not (model and hrp) then
    				Auto.logEvery("tpegg:" .. name, 120, "TP", "fail", "egg=" .. name, "reason=egg model not found in " .. tostring(world))
    				return false, "Could not find " .. name
    			end
    			local pivot = model:GetPivot().Position
    			local away = hrp.Position - pivot
    			away = Vector3.new(away.X, 0, away.Z)
    			away = if away.Magnitude > 0.1 and away.Magnitude < 200 then away.Unit else Vector3.new(0, 0, 1)
    			local spot = pivot + away * 9 + Vector3.new(0, 3, 0)
    			local flat = Vector3.new(spot.X - hrp.Position.X, 0, spot.Z - hrp.Position.Z).Magnitude
    			local character = LocalPlayer.Character
    			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    			if humanoid and flat <= 120 and flat > 6 then
    				local speed = math.max(tonumber(humanoid.WalkSpeed) or 16, 8)
    				local limit = math.min(flat / speed + 1.5, 9)
    				local walked = pcall(function() humanoid:MoveTo(Vector3.new(spot.X, hrp.Position.Y, spot.Z)) end)
    				if walked then
    					Mover.task = "Walking to " .. name
    					local waited, lastPos, stuck = 0, hrp.Position, 0
    					while waited < limit and alive() do
    						local step = task.wait(0.2) or 0.2
    						waited += step
    						hrp = getRoot()
    						if not hrp then break end
    						if Vector3.new(spot.X - hrp.Position.X, 0, spot.Z - hrp.Position.Z).Magnitude <= 5 then
    							return true
    						end
    						if (hrp.Position - lastPos).Magnitude < 0.6 then
    							stuck += step
    							if stuck >= 1.2 then break end
    						else
    							stuck = 0
    						end
    						lastPos = hrp.Position
    					end
    					hrp = getRoot()
    					if not hrp then
    						return false, "Character is not loaded"
    					end
    				end
    			end
    			pcall(function() hrp.AssemblyLinearVelocity = Vector3.zero end)
    			hrp.CFrame = CFrame.lookAt(spot, Vector3.new(pivot.X, spot.Y, pivot.Z))
    			Auto.logEvery("tpeggok:" .. name, 60, "TP", "ok", "egg=" .. name, "world=" .. tostring(world), "dist=" .. math.floor((hrp.Position - pivot).Magnitude))
    			return true
    		end
    
    		local function goToEgg(name)
    			if name == "" then
    				notify("Eggs", "Select an egg first", 4)
    				return
    			end
    			if Mover.busy then
    				notify("Eggs", "Busy: " .. (if Mover.task ~= "" then Mover.task else "travelling"), 4)
    				return
    			end
    			Mover.busy = true
    			Mover.task = "Going to " .. name
    			queueToast("Eggs", "Travelling to " .. name .. "...")
    			task.spawn(function()
    				local ok, result, err = pcall(moveToEgg, name)
    				if not ok then
    					queueToast("Eggs", "Travel failed: " .. shortError(result))
    				elseif result then
    					queueToast("Eggs", "Arrived at " .. name)
    				else
    					queueToast("Eggs", tostring(err))
    				end
    				Mover.busy = false
    				Mover.task = ""
    			end)
    		end
    
    		local GROUP_ID = Auto.GameData.groupId or 35939768
    		local FM = { left = nil, leftAt = 0, total = nil, lastTry = -1e9, rewardAt = -1e9, last = nil, status = "", pollNow = true }
    		local GC = { avail = nil, availAt = 0, member = nil, total = nil, lastTry = -1e9, dataAt = -1e9, data = nil, claimedAt = -1e9, last = nil, status = "", pollNow = true }
    		local MC = { readyAt = nil, luck = nil, total = nil, lastTry = -1e9, resultAt = -1e9, last = nil, status = "", pollNow = true }
    		local Hunter = { egg = nil, world = nil, focus = nil, status = "Off", blocked = {}, moveFails = 0, needMove = false, allDone = 0, allTotal = 0, completed = false, craftPending = false, lastCraftTry = -1e9, craftBlockedUntil = -1e9 }
    		local Craft = { reqG = 8, reqD = 6, reqAt = -1e9, resultAt = -1e9, lastName = nil, lastKind = nil }
    		local Quest = { nextDaily = 0, dailyLeft = nil, dailyAt = 0, dailyDay = nil, pollDaily = true, dailyClaimAt = -1e9, indexClaimAt = {}, groupClaimAt = -1e9, verifyTried = {}, verifyClaimAt = -1e9, lastIndexFlags = nil }
    		local AutoCraft = { lastTrip = -1e9, blockedUntil = -1e9, bulkAt = -1e9, bulkLast = 0, status = "Idle", goldenReady = 0, diamondReady = 0 }
    		local IndexThresholds = { 14, 35, 50, 85, 105, 135 }
    		local Lucky = { active = false, spawnAt = -1e9, maxClicks = 3, count = 0, clicks = 0, sent = 0, lastGrow = -1e9, claimedAt = -1e9, lastOpen = -1e9, waitingSpawn = false, status = "Idle", last = nil }
    		local Equip = { lastFire = 0, fired = false, lastSig = nil }
    		local ItemTrack = { lastUse = {}, lastCount = {} }
    
    		local function serverNow()
    			local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
    			return if ok and type(t) == "number" then t else os.time()
    		end
    
    		local function formatClock(sec)
    			sec = math.max(0, math.floor(tonumber(sec) or 0))
    			local h = sec // 3600
    			local m = (sec % 3600) // 60
    			local s = sec % 60
    			if h > 0 then
    				return string.format("%dh %02dm", h, m)
    			elseif m > 0 then
    				return string.format("%dm %02ds", m, s)
    			end
    			return string.format("%ds", s)
    		end
    
    		local function rewardSummary(list)
    			if type(list) ~= "table" then return nil, 0 end
    			local parts, total = {}, 0
    			for _, entry in pairs(list) do
    				if type(entry) == "table" then
    					local item = entry.Item or entry.Name or entry.Pet or entry.Reward
    					local amount = tonumber(entry.Value or entry.Amount or entry.Count) or 1
    					if item ~= nil then
    						total += amount
    						if #parts < 4 then
    							table.insert(parts, string.format("%s x%s", Auto.itemDisplayName(tostring(item)), formatNumber(amount)))
    						end
    					end
    				end
    			end
    			return table.concat(parts, ", "), total
    		end
    
    		local HookedEvents = {}
    		local function hookEvent(key, serviceName, remoteName, handler)
    			if HookedEvents[key] then return end
    			local remote = Auto.knitRemote(serviceName, "RE", remoteName)
    			if not remote then return end
    			HookedEvents[key] = true
    			Library:GiveSignal(remote.OnClientEvent:Connect(function(...)
    				local ok, err = pcall(handler, ...)
    				if not ok then
    					diag(key, err)
    				end
    			end))
    		end
    
    		local function hookEvents()
    			hookEvent("fruitReward", "FruitMachineService", "RewardGranted", function(list)
    				if type(list) ~= "table" then return end
    				local summary, total = rewardSummary(list)
    				FM.rewardAt = os.clock()
    				FM.last = if summary ~= "" then summary else nil
    				FM.left = nil
    				FM.total = nil
    				FM.pollNow = true
    				Saved.fruitBuys += 1
    				Saved.fruitsBought += total
    				SaveDirty = true
    			end)
    			hookEvent("groupData", "GroupChestService", "ChestData", function(data)
    				if type(data) == "table" then
    					GC.data = data
    					GC.dataAt = os.clock()
    				end
    			end)
    			hookEvent("groupClaimed", "GroupChestService", "ChestClaimed", function(seconds)
    				GC.claimedAt = os.clock()
    				local left = tonumber(seconds)
    				if left and left > 0 then
    					GC.avail = left
    					GC.availAt = os.clock()
    					GC.total = left
    				end
    				Saved.groupChests += 1
    				SaveDirty = true
    			end)
    			hookEvent("luckySpawn", "LuckyBlockService", "Spawn", function(data)
    			if type(data) ~= "table" or data.Type == nil then return end
    			Lucky.active = true
    			Lucky.waitingSpawn = false
    			Lucky.spawnAt = os.clock()
    			Lucky.maxClicks = math.max(1, tonumber(data.MaxClicks) or 3)
    			Lucky.count = math.max(1, tonumber(data.Count) or 1)
    			Lucky.clicks = 0
    			Lucky.sent = 0
    		end)
    		hookEvent("luckyState", "LuckyBlockService", "State", function(data)
    			if type(data) == "table" then
    				Lucky.clicks = math.max(Lucky.clicks, tonumber(data.Clicks) or 0)
    			end
    		end)
    		hookEvent("luckyClaimed", "LuckyBlockService", "Claimed", function(data)
    			local skipped = type(data) == "table" and data.Skipped == true
    			local opened = if Lucky.active and Lucky.count > 0 then Lucky.count elseif skipped then tonumber(Lucky.pendingAmount) or 0 else 0
    			if opened > 0 then
    				Saved.luckyOpened += opened
    				SaveDirty = true
    			end
    			Lucky.pendingAmount = 0
    			Lucky.active = false
    			Lucky.waitingSpawn = false
    			Lucky.claimedAt = os.clock()
    			local summary = rewardSummary(type(data) == "table" and data.Rewards or nil)
    			Lucky.last = if summary and summary ~= "" then summary else Lucky.last
    		end)
    		for _, kind in ipairs({ "Golden", "Diamond" }) do
    			hookEvent("craft" .. kind, "CraftMachinesService", "Craft" .. kind, function(count)
    				Craft.resultAt = os.clock()
    				local crafted = tonumber(count) or 0
    				if crafted > 0 then
    					if kind == "Golden" then
    						Saved.goldenCrafts += crafted
    					else
    						Saved.diamondCrafts += crafted
    					end
    					SaveDirty = true
    					if Craft.lastName then
    						queueToast("Index Hunter", string.format("Crafted %s %s x%d", kind, Craft.lastName, crafted))
    					end
    				end
    			end)
    		end
    		for _, kind in ipairs({ "Golden", "Diamond" }) do
    			hookEvent("bulk" .. kind, "CraftMachinesService", "CraftBulk" .. kind, function(total, _, status, reason)
    				local crafted = tonumber(total) or 0
    				AutoCraft.bulkAt = os.clock()
    				AutoCraft.bulkLast = crafted
    				AutoCraft.bulkStatus = status
    				AutoCraft.bulkReason = reason
    				if crafted > 0 then
    					if kind == "Golden" then
    						Saved.goldenCrafts += crafted
    					else
    						Saved.diamondCrafts += crafted
    					end
    					SaveDirty = true
    					queueToast("Crafting", string.format("Crafted %d %s pet%s", crafted, kind, if crafted == 1 then "" else "s"))
    				end
    			end)
    		end
    		hookEvent("dailyTick", "DailyRewardsService", "TimerTick", function(left, day)
    			if tonumber(left) then
    				Quest.dailyLeft = math.max(0, tonumber(left))
    				Quest.dailyAt = os.clock()
    				Quest.dailyDay = tonumber(day) or Quest.dailyDay
    			end
    		end)
    		hookEvent("dailyClaim", "DailyRewardsService", "ClaimResult", function(data)
    			if type(data) == "table" and tonumber(data.Day) then
    				Saved.questsClaimed += 1
    				SaveDirty = true
    				queueToast("Quests", "Daily reward day " .. tostring(data.Day) .. " claimed")
    				Quest.pollDaily = true
    			end
    		end)
    		hookEvent("groupReward", "GroupRewardsService", "ClaimResult", function(result)
    			if result == "Ok" then
    				Saved.questsClaimed += 1
    				SaveDirty = true
    				queueToast("Quests", "Group reward claimed")
    			end
    		end)
    		hookEvent("verifyResult", "VerifyRewardsService", "Result", function(result)
    			if result == "Ok" then
    				Saved.questsClaimed += 1
    				SaveDirty = true
    				queueToast("Quests", "Like, group and favorite reward claimed")
    			end
    		end)
    		hookEvent("moonResult", "MoonChestService", "Result", function(data)
    				if type(data) ~= "table" or type(data.Rewards) ~= "table" then return end
    				MC.resultAt = os.clock()
    				MC.readyAt = nil
    				MC.total = nil
    				MC.pollNow = true
    				local summary = rewardSummary(data.Rewards)
    				MC.last = if summary ~= "" then summary else nil
    				Saved.moonChests += 1
    				SaveDirty = true
    			end)
    		end
    		pcall(hookEvents)
    
    		local function fruitPrice(stock)
    			local config = Auto.lazyRequire("FruitMachineConfig", function()
    				local modules = ReplicatedStorage:FindFirstChild("Modules")
    				return modules and modules:FindFirstChild("FruitMachineConfig")
    			end)
    			if type(config) == "table" and type(config.GetPrice) == "function" then
    				local ok, price = pcall(config.GetPrice, stock)
    				if ok and tonumber(price) then
    					return tonumber(price)
    				end
    			end
    			return math.max(1, math.floor(tonumber(stock) or 1)) * 500
    		end
    
    		local function fruitMachineInfo()
    			local onCooldown = readData("FruitMachineData", "OnCooldown")
    			local stock = tonumber(readData("FruitMachineData", "Stock"))
    			local rubies = getStat("Rubies")
    			local price = if stock then fruitPrice(stock) else nil
    			local left = if FM.left then math.max(0, FM.left - (os.clock() - FM.leftAt)) else nil
    			local ready
    			if onCooldown ~= nil then
    				ready = onCooldown == false and (left == nil or left <= 0.5)
    			else
    				ready = left ~= nil and left <= 0.5
    			end
    			return {
    				left = left,
    				total = FM.total,
    				ready = ready,
    				stock = stock,
    				price = price,
    				rubies = rubies,
    				affordable = not (price and rubies and rubies < price),
    				status = FM.status,
    				last = FM.last,
    			}
    		end
    
    		local function groupChestInfo()
    			local left, ready = nil, false
    			if GC.avail == true then
    				ready, left = true, 0
    			elseif type(GC.avail) == "number" then
    				left = math.max(0, GC.avail - (os.clock() - GC.availAt))
    				if left <= 0 then
    					GC.pollNow = true
    				end
    			end
    			local member = GC.member
    			if GC.avail == true or type(GC.avail) == "number" then
    				member = true
    			elseif GC.avail == false then
    				member = false
    			end
    			return { ready = ready, left = left, total = GC.total, member = member, status = GC.status, last = GC.last }
    		end
    
    		local function moonChestInfo()
    			local left = nil
    			if MC.readyAt then
    				left = math.max(0, MC.readyAt - serverNow())
    			end
    			return {
    				unlocked = isWorldUnlocked(moonWorld()),
    				left = left,
    				total = MC.total,
    				ready = left ~= nil and left <= 0,
    				luck = MC.luck,
    				status = MC.status,
    				last = MC.last,
    			}
    		end
    
    		local function machineOrbs()
    			local orbs = workspace:FindFirstChild("Orbs")
    			return orbs and orbs:FindFirstChild("FruitMachine")
    		end
    
    		local function collectOrbs(maxWait)
    			local claim = Auto.knitRemote("BreakableOrbService", "RE", "ClaimOrb")
    			local seen = {}
    			local waited = 0
    			while waited < maxWait do
    				local folder = machineOrbs()
    				local pending = 0
    				if folder then
    					for _, orb in ipairs(folder:GetChildren()) do
    						if orb:IsA("BasePart") then
    							pending += 1
    							local first = seen[orb]
    							if not first then
    								seen[orb] = os.clock()
    							elseif first ~= math.huge and os.clock() - first > 1.6 then
    								seen[orb] = math.huge
    								if claim and orb:GetAttribute("VisualOnly") ~= true then
    									pcall(function()
    										local damage = orb:FindFirstChild("Damage")
    										claim:FireServer(folder.Name, orb.Name, if damage then damage.Value else 1, orb:GetAttribute("CoinId") or "")
    									end)
    								end
    								pcall(function() orb:Destroy() end)
    							end
    						end
    					end
    				end
    				if pending == 0 and waited >= 1 then
    					break
    				end
    				waited += task.wait(0.2) or 0.2
    			end
    		end
    
    		local function flatDistance(a, b)
    			local offset = a - b
    			return Vector3.new(offset.X, 0, offset.Z).Magnitude
    		end
    
    		local function walkOnto(part)
    			standAt(part, 6)
    			task.wait(0.3)
    			local radius = math.max(part.Size.X, part.Size.Z) / 2
    			local char = LocalPlayer.Character
    			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    			if humanoid then
    				pcall(function() humanoid:MoveTo(part.Position) end)
    				local waited = 0
    				while waited < 2.5 do
    					local hrp = getRoot()
    					if hrp and flatDistance(hrp.Position, part.Position) <= radius then
    						break
    					end
    					waited += task.wait(0.1) or 0.1
    				end
    			end
    			local hrp = getRoot()
    			if hrp and flatDistance(hrp.Position, part.Position) > radius then
    				standAt(part, 0)
    			end
    			touchPart(part)
    		end
    
    		local function gameFrame(path)
    			local node = LocalPlayer:FindFirstChild("PlayerGui")
    			for _, name in ipairs(path) do
    				node = node and node:FindFirstChild(name)
    			end
    			return node
    		end
    
    		local function doFruitMachine()
    			FM.lastTry = os.clock()
    			FM.status = ""
    			local roll = Auto.knitRemote("FruitMachineService", "RF", "Roll")
    			if not roll then
    				FM.status = "Unavailable"
    				return
    			end
    			local ok, err = travelTo(machineWorld("FruitMachine", "FrozenAlley"))
    			if not ok then
    				FM.status = "Travel failed"
    				queueToast("Fruit Machine", err)
    				return
    			end
    			local _, touch = getMachine("FruitMachine")
    			if not touch then
    				FM.status = "Not found"
    				return
    			end
    			Mover.task = "Walking to the machine"
    			walkOnto(touch)
    			local framePath = { "UI", "Base", "FrameInfo", "FruitMachineBuy" }
    			local waited = 0
    			while waited < 2 do
    				local frame = gameFrame(framePath)
    				if frame and frame:IsA("GuiObject") and frame.Visible then
    					break
    				end
    				waited += task.wait(0.1) or 0.1
    			end
    			Mover.task = "Buying fruits"
    			local started = os.clock()
    			local rubiesBefore = getStat("Rubies")
    			local bought = false
    			for attempt = 1, 2 do
    				Auto.invokeTimeout(roll, 6)
    				local w = 0
    				while w < 4 do
    					if FM.rewardAt >= started or readData("FruitMachineData", "OnCooldown") == true then
    						bought = true
    						break
    					end
    					local rubies = getStat("Rubies")
    					if rubiesBefore and rubies and rubies < rubiesBefore then
    						bought = true
    						break
    					end
    					w += task.wait(0.2) or 0.2
    				end
    				if bought or attempt == 2 then
    					break
    				end
    				standAt(touch, 0)
    				touchPart(touch)
    				task.wait(0.8)
    			end
    			if bought then
    				local w = 0
    				while w < 2 and FM.rewardAt < started do
    					w += task.wait(0.2) or 0.2
    				end
    				Mover.task = "Collecting fruits"
    				task.wait(0.5)
    				collectOrbs(8)
    				hideGameFrame(framePath)
    				FM.pollNow = true
    				queueToast("Fruit Machine", if FM.rewardAt >= started and FM.last then "Bought " .. FM.last else "Fruits bought")
    			else
    				hideGameFrame(framePath)
    				FM.status = "Retrying soon"
    				queueToast("Fruit Machine", "The machine did not sell, trying again in 30s")
    			end
    		end
    
    		local function doGroupChest()
    			GC.lastTry = os.clock()
    			GC.status = ""
    			local request = Auto.knitRemote("GroupChestService", "RE", "RequestChest")
    			local claim = Auto.knitRemote("GroupChestService", "RE", "ClaimChest")
    			if not (request and claim) then
    				GC.status = "Unavailable"
    				return
    			end
    			local ok, err = travelTo(machineWorld("RewardChest", "Spawn"))
    			if not ok then
    				GC.status = "Travel failed"
    				queueToast("Group Chest", err)
    				return
    			end
    			local _, touch = getMachine("RewardChest")
    			if not touch then
    				GC.status = "Not found"
    				return
    			end
    			local started = os.clock()
    			local claimed = false
    			for attempt = 1, 2 do
    				Mover.task = "Opening group chest"
    				standAt(touch, if attempt == 1 then 5 else 0)
    				task.wait(0.5)
    				local asked = -1e9
    				local waited = 0
    				while waited < 7 and GC.dataAt < started do
    					if os.clock() - asked >= 2 then
    						asked = os.clock()
    						pcall(function() request:FireServer() end)
    					end
    					waited += task.wait(0.2) or 0.2
    				end
    				if GC.dataAt >= started then
    					task.wait(0.4)
    					pcall(function() claim:FireServer() end)
    					waited = 0
    					while waited < 5 and GC.claimedAt < started do
    						waited += task.wait(0.2) or 0.2
    					end
    					if GC.claimedAt >= started then
    						claimed = true
    						break
    					end
    				end
    			end
    			hideGameFrame({ "UI", "Base", "Frames", "GroupChest" })
    			GC.pollNow = true
    			if claimed then
    				local summary = rewardSummary(GC.data)
    				GC.last = if summary and summary ~= "" then summary else nil
    				queueToast("Group Chest", if GC.last then "Claimed " .. GC.last else "Chest claimed")
    			else
    				GC.status = "Retrying soon"
    			end
    		end
    
    		local function doMoonChest()
    			MC.lastTry = os.clock()
    			MC.status = ""
    			if isWorldUnlocked(moonWorld()) == false then
    				MC.status = "Moon locked"
    				return
    			end
    			local ok, err = travelTo(machineWorld("MoonChest", moonWorld()))
    			if not ok then
    				MC.status = "Travel failed"
    				queueToast("Moon Chest", err)
    				return
    			end
    			local _, touch = getMachine("MoonChest")
    			if not touch then
    				MC.status = "Not found"
    				return
    			end
    			local started = os.clock()
    			for _ = 1, 3 do
    				Mover.task = "Opening moon chest"
    				standAt(touch, 0)
    				touchPart(touch)
    				local waited = 0
    				while waited < 3 and MC.resultAt < started do
    					waited += task.wait(0.2) or 0.2
    				end
    				if MC.resultAt >= started then
    					break
    				end
    				standAt(touch, 6)
    				task.wait(0.4)
    			end
    			MC.pollNow = true
    			if MC.resultAt >= started then
    				queueToast("Moon Chest", if MC.last then "Opened: " .. MC.last else "Chest opened")
    			else
    				MC.status = "Retrying soon"
    			end
    		end
    
    		local VC = { lastTry = -1e9, noVipUntil = 0, opened = 0, crafted = 0, keys = 0, halves = 0, status = "" }
    		Auto.VipChest = VC
    		local function vipKeys()
    			return tonumber(readData("MiscData", "VIPKey")) or 0
    		end
    		-- VIP Chest in Pet Kingdom: workspace.Map.Machines.VipChest, opened from within 30 studs with VIPChestService.Open(1/3/8 keys).
    		local function doVipChest()
    			VC.lastTry = os.clock()
    			VC.status = ""
    			local keys = vipKeys()
    			local open = Auto.knitRemote("VIPChestService", "RE", "Open")
    			if keys < 1 or not open then
    				VC.status = if open then "No VIP keys" else "Unavailable"
    				return
    			end
    			local okVip, hasVip = Auto.invokeTimeout(Auto.knitRemote("VIPChestService", "RF", "HasVIP"), 6)
    			if okVip and hasVip == false then
    				VC.status = "Needs the VIP gamepass"
    				VC.noVipUntil = os.clock() + 1800
    				return
    			end
    			local map = workspace:FindFirstChild("Map")
    			local machines = map and map:FindFirstChild("Machines")
    			local chest = machines and machines:FindFirstChild("VipChest")
    			local ui = chest and chest:FindFirstChild("UI")
    			if not (ui and ui:IsA("BasePart")) then
    				VC.status = "Chest not found"
    				return
    			end
    			local okWorld, world = pcall(getWorldAt, ui.Position)
    			if okWorld and world then
    				local ok, err = travelTo(world)
    				if not ok then
    					VC.status = "Travel failed"
    					queueToast("VIP Chest", err)
    					return
    				end
    			end
    			Mover.task = "Opening VIP chest"
    			standAt(ui, 8)
    			task.wait(0.5)
    			local amount = if keys >= 8 then 8 elseif keys >= 3 then 3 else 1
    			pcall(function()
    				open:FireServer(amount)
    			end)
    			local waited = 0
    			while waited < 6 and vipKeys() >= keys do
    				waited += task.wait(0.2) or 0.2
    			end
    			local used = keys - vipKeys()
    			if used > 0 then
    				VC.opened += used
    				queueToast("VIP Chest", "Opened with " .. used .. " key" .. (if used == 1 then "" else "s"))
    				task.wait(1.5)
    				hideGameFrame({ "OtherView", "VIPInfo" })
    			else
    				VC.status = "Needs the VIP gamepass, retry in 10 min"
    				VC.noVipUntil = os.clock() + 600
    			end
    		end
    		Auto.vipChestDue = function(now)
    			return S.autoVipChest and now - VC.lastTry > 30 and now > VC.noVipUntil and vipKeys() >= 1
    		end
    		Auto.doVipChest = doVipChest

    		local function runErrand(label, fn)
    			Mover.busy = true
    			Mover.task = label
    			local back = nil
    			local hrp = getRoot()
    			if hrp and S.returnAfter and not (S.indexHunt and Hunter.egg) then
    				back = { cframe = hrp.CFrame, world = getWorldAt(hrp.Position) }
    			end
    			local ok, err = pcall(fn)
    			if not ok then
    				queueToast(label, "Failed: " .. shortError(err))
    			end
    			if back and back.world and alive() then
    				Mover.task = "Returning"
    				local okTravel, reached = pcall(travelTo, back.world)
    				local root = getRoot()
    				if okTravel and reached and root and getWorldAt(root.Position) == back.world then
    					pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
    					root.CFrame = back.cframe
    				end
    			end
    			Mover.busy = false
    			Mover.task = ""
    		end
    
    		local EggPets = nil
    		local function loadEggPets()
    			if EggPets then return EggPets end
    			local handler = Auto.lazyRequire("EggHandlerModule", function()
    				local folder = ReplicatedStorage:FindFirstChild("NormalEggs")
    				return folder and folder:FindFirstChild("EggHandlerModule")
    			end)
    			if type(handler) ~= "table" then return nil end
    			local map = {}
    			for egg, list in pairs(handler) do
    				if type(egg) == "string" and type(list) == "table" and egg ~= "Universe Egg" then
    					local pets, total = {}, 0
    					for _, entry in ipairs(list) do
    						if type(entry) == "table" and type(entry.Name) == "string" then
    							local chance = tonumber(entry.Chance) or 0
    							total += chance
    							table.insert(pets, { name = entry.Name, rarity = tostring(entry.Rarity or "Basic"), chance = chance })
    						end
    					end
    					if #pets > 0 and total > 0 then
    						for _, pet in ipairs(pets) do
    							pet.percent = pet.chance / total * 100
    						end
    						map[egg] = pets
    					end
    				end
    			end
    			if next(map) then
    				EggPets = map
    			end
    			return EggPets
    		end
    
    		local PetIconCache = {}
    		local function petIcon(name)
    			local cached = PetIconCache[name]
    			if cached ~= nil then
    				return cached or nil
    			end
    			local icon = false
    			local multi = Auto.lazyRequire("PetsMulti", function()
    				local folder = ReplicatedStorage:FindFirstChild("Pets")
    				return folder and folder:FindFirstChild("Multi")
    			end)
    			if type(multi) == "table" and type(multi[name]) == "table" and type(multi[name][4]) == "string" then
    				icon = multi[name][4]
    			elseif PetDisplay and PetDisplay.GetIcon then
    				local ok, result = pcall(PetDisplay.GetIcon, name)
    				if ok and type(result) == "string" and result ~= "" then
    					icon = result
    				end
    			end
    			if icon or type(multi) == "table" then
    				PetIconCache[name] = icon
    			end
    			return icon or nil
    		end
    
    		local function formatChance(percent)
    			percent = tonumber(percent) or 0
    			if percent <= 0 then return "?" end
    			if percent >= 10 then return string.format("%d%%", math.floor(percent + 0.5)) end
    			if percent >= 1 then return string.format("%.1f%%", percent) end
    			if percent >= 0.01 then return string.format("%.2f%%", percent) end
    			return "1 in " .. formatNumber(math.floor(100 / percent + 0.5))
    		end
    
    		local function craftRequirements()
    			if os.clock() - Craft.reqAt < 30 then
    				return Craft.reqG, Craft.reqD
    			end
    			Craft.reqAt = os.clock()
    			if PetDisplay and type(PetDisplay.GetRequired) == "function" then
    				local okG, golden = pcall(PetDisplay.GetRequired, "Golden", LocalPlayer)
    				if okG and tonumber(golden) and tonumber(golden) >= 1 then
    					Craft.reqG = tonumber(golden)
    				end
    				local okD, diamond = pcall(PetDisplay.GetRequired, "Diamond", LocalPlayer)
    				if okD and tonumber(diamond) and tonumber(diamond) >= 1 then
    					Craft.reqD = tonumber(diamond)
    				end
    			end
    			return Craft.reqG, Craft.reqD
    		end
    
    		local function petStock(folderName, name)
    			local pets = getDataFolder("PetsData")
    			local folder = pets and pets:FindFirstChild(folderName)
    			local entry = folder and folder:FindFirstChild(name)
    			if not entry then return 0, 0 end
    			local function num(childName)
    				local child = entry:FindFirstChild(childName)
    				if not child then return 0 end
    				local ok, value = pcall(function() return child.Value end)
    				if not ok then return 0 end
    				if type(value) == "boolean" then
    					return if value then 1 else 0
    				end
    				return tonumber(value) or 0
    			end
    			local amount = num("Amount")
    			if num("Locked") > 0 then
    				return 0, amount
    			end
    			return math.max(0, math.floor(amount - num("Equipped"))), amount
    		end
    
    		local function indexed(name)
    			local value = readData("IndexData", name)
    			return value == true or (type(value) == "number" and value > 0)
    		end
    
    		local PetCatalog = nil
    		local function petCatalog()
    			if PetCatalog then return PetCatalog end
    			local pets = loadEggPets()
    			if not pets then return nil end
    			local catalog = {}
    			for egg, list in pairs(pets) do
    				for _, pet in ipairs(list) do
    					local entry = catalog[pet.name]
    					if not entry then
    						entry = { name = pet.name, rarity = pet.rarity, eggs = {} }
    						catalog[pet.name] = entry
    					end
    					entry.eggs[egg] = pet.percent
    				end
    			end
    			PetCatalog = catalog
    			return catalog
    		end
    
    		local function petPlan(name, reqG, reqD)
    			local wantN = S.huntVariants.Normal == true and not indexed(name)
    			local wantG = S.huntVariants.Golden == true and not indexed("Golden " .. name)
    			local wantD = S.huntVariants.Diamond == true and not indexed("Diamond " .. name)
    			local availN = petStock("NormalPetsData", name)
    			local availG = petStock("GoldenPetsData", "Golden " .. name)
    			local goldNeeded = if wantD then reqD elseif wantG then 1 else 0
    			local goldToCraft = math.max(0, goldNeeded - availG)
    			local normNeeded = math.max(goldToCraft * reqG, if wantN then 1 else 0)
    			return {
    				name = name,
    				wantN = wantN,
    				wantG = wantG,
    				wantD = wantD,
    				availN = availN,
    				availG = availG,
    				goldToCraft = goldToCraft,
    				normNeeded = normNeeded,
    				normShort = math.max(0, normNeeded - availN),
    				canGolden = goldToCraft > 0 and availN >= reqG,
    				canDiamond = wantD and availG >= reqD,
    				needs = wantN or wantG or wantD,
    			}
    		end
    
    		local function updateHunter()
    			if not S.indexHunt then
    				Hunter.egg = nil
    				Hunter.focus = nil
    				Hunter.status = "Off"
    				Hunter.completed = false
    				Hunter.craftPending = false
    				return
    			end
    			local catalog = petCatalog()
    			if not catalog then
    				Hunter.egg = nil
    				Hunter.status = "Egg data unavailable"
    				return
    			end
    			local reqG, reqD = craftRequirements()
    			Hunter.reqG, Hunter.reqD = reqG, reqD
    			local here = currentWorld()
    			local variantCount = (if S.huntVariants.Normal then 1 else 0) + (if S.huntVariants.Golden then 1 else 0) + (if S.huntVariants.Diamond then 1 else 0)
    			local done, total = 0, 0
    			local plans = {}
    			local eggNeeds = {}
    			local goldenFull, goldenAny, diamondReady = 0, 0, false
    			local lockedMissing = false
    			for name, entry in pairs(catalog) do
    				if S.huntRarity[entry.rarity] then
    					local plan = petPlan(name, reqG, reqD)
    					plan.rarity = entry.rarity
    					total += variantCount
    					done += variantCount - ((if plan.wantN then 1 else 0) + (if plan.wantG then 1 else 0) + (if plan.wantD then 1 else 0))
    					if plan.needs then
    						table.insert(plans, plan)
    						if plan.canDiamond then
    							diamondReady = true
    						end
    						if plan.canGolden then
    							goldenAny += 1
    							if plan.normShort == 0 then
    								goldenFull += 1
    							end
    						end
    						if plan.normShort > 0 then
    							for egg, percent in pairs(entry.eggs) do
    								local world = EggWorlds[egg] or "Spawn"
    								local blockedUntil = Hunter.blocked[egg]
    								if isWorldUnlocked(world) == false then
    									lockedMissing = true
    								elseif not (blockedUntil and os.clock() < blockedUntil) then
    									local need = eggNeeds[egg]
    									if not need then
    										need = { egg = egg, world = world, count = 0 }
    										eggNeeds[egg] = need
    									end
    									need.count += 1
    									if name == S.huntPin then
    										need.pinned = percent
    										need.focus = { name = name, rarity = entry.rarity, percent = percent, pinned = true }
    									elseif not (need.focus and need.focus.pinned) and (not need.focus or percent < need.focus.percent) then
    										need.focus = { name = name, rarity = entry.rarity, percent = percent }
    									end
    								end
    							end
    						end
    					end
    				end
    			end
    			Hunter.allDone, Hunter.allTotal = done, total
    			if #plans == 0 then
    				Hunter.egg = nil
    				Hunter.focus = nil
    				Hunter.craftPending = false
    				if total == 0 then
    					Hunter.status = "Pick a rarity"
    				else
    					Hunter.status = "Complete"
    					if not Hunter.completed then
    						Hunter.completed = true
    						queueToast("Index Hunter", string.format("Index complete: %d / %d done, hunter stopped", done, total))
    						Auto.stopHunter = true
    					end
    				end
    				return
    			end
    			Hunter.completed = false
    			local best, bestRank, bestCount, bestPrice = nil, nil, nil, nil
    			for egg, need in pairs(eggNeeds) do
    				local rank = if need.pinned then -1 elseif egg == Hunter.egg then 0 elseif need.world == here then 1 else 2
    				local price = getEggPrice(egg) or math.huge
    				local pinA, pinB = need.pinned or 0, best and best.pinned or 0
    				if not best or rank < bestRank or (rank == bestRank and (pinA > pinB or (pinA == pinB and (need.count > bestCount or (need.count == bestCount and price < bestPrice))))) then
    					best, bestRank, bestCount, bestPrice = need, rank, need.count, price
    				end
    			end
    			local craftBlocked = os.clock() < Hunter.craftBlockedUntil
    			local currentShort = Hunter.egg ~= nil and eggNeeds[Hunter.egg] ~= nil
    			local wantCraft = not craftBlocked and (diamondReady or goldenFull >= 3 or (goldenFull >= 1 and not currentShort) or (goldenAny > 0 and best == nil))
    			if wantCraft then
    				Hunter.craftPending = true
    				Hunter.egg = nil
    				Hunter.status = "Crafting"
    				for _, plan in ipairs(plans) do
    					if plan.canDiamond or plan.canGolden then
    						Hunter.focus = { name = plan.name, rarity = plan.rarity }
    						break
    					end
    				end
    				return
    			end
    			Hunter.craftPending = false
    			if best then
    				if Hunter.egg ~= best.egg then
    					Hunter.egg = best.egg
    					Hunter.moveFails = 0
    					HatchState.waiting = false
    				end
    				Hunter.world = best.world
    				Hunter.focus = best.focus
    				Hunter.status = "Hunting"
    			else
    				Hunter.egg = nil
    				Hunter.focus = nil
    				Hunter.status = if lockedMissing then "Unlock more worlds" else "Waiting"
    			end
    		end
    
    		local function craftAt(kind)
    			local reqG, reqD = craftRequirements()
    			local catalog = petCatalog() or {}
    			local todo = {}
    			for name, entry in pairs(catalog) do
    				if S.huntRarity[entry.rarity] then
    					local plan = petPlan(name, reqG, reqD)
    					if (kind == "Golden" and plan.canGolden) or (kind == "Diamond" and plan.canDiamond) then
    						table.insert(todo, name)
    					end
    				end
    			end
    			if #todo == 0 then return 0 end
    			table.sort(todo)
    			local remote = Auto.knitRemote("CraftMachinesService", "RE", "Craft" .. kind)
    			if not remote then return 0 end
    			local ok, err = travelTo(machineWorld(kind .. "Machine", if kind == "Golden" then "BirchForest" else "HauntedHouse"))
    			if not ok then
    				queueToast("Index Hunter", err)
    				return 0
    			end
    			local _, touch = getMachine(kind .. "Machine")
    			if not touch then
    				queueToast("Index Hunter", kind .. " Machine not found")
    				return 0
    			end
    			Mover.task = "Crafting " .. kind
    			standAt(touch, 4)
    			task.wait(0.7)
    			local crafted = 0
    			for _, name in ipairs(todo) do
    				for _ = 1, 8 do
    					local plan = petPlan(name, reqG, reqD)
    					if not ((kind == "Golden" and plan.canGolden) or (kind == "Diamond" and plan.canDiamond)) or not alive() then
    						break
    					end
    					Mover.task = "Crafting " .. kind .. " " .. name
    					Hunter.focus = { name = name, rarity = catalog[name] and catalog[name].rarity or "Basic" }
    					local before = Craft.resultAt
    					Craft.lastName, Craft.lastKind = name, kind
    					pcall(function()
    						remote:FireServer(if kind == "Golden" then name else "Golden " .. name)
    					end)
    					local waited = 0
    					while waited < 3 and Craft.resultAt <= before do
    						waited += task.wait(0.2) or 0.2
    					end
    					if Craft.resultAt <= before then
    						break
    					end
    					crafted += 1
    					task.wait(0.5)
    				end
    			end
    			return crafted
    		end
    
    		local function doCraftTrip()
    			Hunter.lastCraftTry = os.clock()
    			local golden = craftAt("Golden")
    			local diamond = craftAt("Diamond")
    			if golden + diamond == 0 then
    				Hunter.craftBlockedUntil = os.clock() + 90
    				queueToast("Index Hunter", "Crafting did not go through, hatching for now")
    			end
    			Hunter.craftPending = false
    		end
    
    		local function petsMulti()
    			return Auto.lazyRequire("PetsMulti", function()
    				local folder = ReplicatedStorage:FindFirstChild("Pets")
    				return folder and folder:FindFirstChild("Multi")
    			end)
    		end
    		Auto.petsMulti = petsMulti
    
    		local function craftableList(kind)
    			local reqG, reqD = craftRequirements()
    			local need = if kind == "Golden" then reqG else reqD
    			local folderName = if kind == "Golden" then "NormalPetsData" else "GoldenPetsData"
    			local pets = getDataFolder("PetsData")
    			local folder = pets and pets:FindFirstChild(folderName)
    			local list = {}
    			if not folder then return list end
    			local multi = petsMulti()
    			for _, entry in ipairs(folder:GetChildren()) do
    				local name = entry.Name
    				local plain = string.match(name, "^[^|]+") or name
    				local base = if kind == "Golden" then plain else (string.gsub(plain, "^Golden ", ""))
    				local info = if type(multi) == "table" then multi[base] else nil
    				local rarity = if type(info) == "table" then info[3] else nil
    				local targetExists = type(multi) ~= "table" or multi[kind .. " " .. base] ~= nil
    				local special = rarity == "Exclusive" or rarity == "Secret"
    				if targetExists and not special and (rarity == nil or S.craftRarity[rarity]) and petStock(folderName, name) >= need then
    					table.insert(list, name)
    				end
    			end
    			table.sort(list)
    			return list
    		end
    
    		local function craftBulk(kind, list)
    			local bulk = Auto.knitRemote("CraftMachinesService", "RE", "CraftBulk" .. kind)
    			local single = Auto.knitRemote("CraftMachinesService", "RE", "Craft" .. kind)
    			if not (bulk or single) then
    				AutoCraft.status = "Unavailable"
    				return 0
    			end
    			local ok, err = travelTo(machineWorld(kind .. "Machine", if kind == "Golden" then "BirchForest" else "HauntedHouse"))
    			if not ok then
    				AutoCraft.status = "Travel failed"
    				queueToast("Crafting", err)
    				return 0
    			end
    			local _, touch = getMachine(kind .. "Machine")
    			if not touch then
    				AutoCraft.status = "Machine not found"
    				return 0
    			end
    			Mover.task = "Crafting " .. kind
    			standAt(touch, 4)
    			task.wait(0.7)
    			local done = 0
    			local rejected = false
    			if bulk then
    				for start = 1, #list, 120 do
    					local batch = table.move(list, start, math.min(start + 119, #list), 1, {})
    					local before = AutoCraft.bulkAt
    					pcall(function() bulk:FireServer(batch) end)
    					local waited = 0
    					while waited < 5 and AutoCraft.bulkAt <= before do
    						waited += task.wait(0.2) or 0.2
    					end
    					if AutoCraft.bulkAt <= before then
    						break
    					end
    					if AutoCraft.bulkStatus == "rejected" and AutoCraft.bulkLast <= 0 then
    						rejected = true
    						AutoCraft.rejectedAt = os.clock()
    						AutoCraft.status = "Waiting for game data"
    						if AutoCraft.bulkReason == "empty" or AutoCraft.bulkReason == "invalid" then
    							pcall(function()
    								local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    								local data = remotes and remotes:FindFirstChild("Data")
    								local sync = data and data:FindFirstChild("PlayerDataSync")
    								if sync then
    									sync:FireServer()
    								end
    							end)
    						end
    						break
    					end
    					done += AutoCraft.bulkLast
    					task.wait(0.5)
    				end
    			end
    			if done == 0 and single and not rejected then
    				for _, name in ipairs(list) do
    					if not alive() then break end
    					local before = Craft.resultAt
    					Craft.lastName = if kind == "Golden" then name else (string.gsub(name, "^Golden ", ""))
    					Craft.lastKind = kind
    					Mover.task = "Crafting " .. kind .. " " .. Craft.lastName
    					pcall(function() single:FireServer(name) end)
    					local waited = 0
    					while waited < 3 and Craft.resultAt <= before do
    						waited += task.wait(0.2) or 0.2
    					end
    					if Craft.resultAt > before then
    						done += 1
    					end
    					task.wait(0.4)
    				end
    			end
    			return done
    		end
    
    		local function doAutoCraft()
    			AutoCraft.lastTrip = os.clock()
    			AutoCraft.status = "Crafting"
    			local total = 0
    			if S.autoGolden then
    				local list = craftableList("Golden")
    				if #list > 0 then
    					total += craftBulk("Golden", list)
    				end
    			end
    			if S.autoDiamond then
    				local list = craftableList("Diamond")
    				if #list > 0 then
    					total += craftBulk("Diamond", list)
    				end
    			end
    			if total == 0 then
    				AutoCraft.blockedUntil = os.clock() + (if os.clock() - (AutoCraft.rejectedAt or -1e9) < 30 then 20 else 120)
    				if AutoCraft.status == "Crafting" then
    					AutoCraft.status = "Nothing crafted"
    				end
    			else
    				AutoCraft.status = "Idle"
    			end
    		end
    
    		local function wantsAutoCraft(now)
    			if not (S.autoGolden or S.autoDiamond) then return false end
    			if now - AutoCraft.lastTrip < 45 or now < AutoCraft.blockedUntil then return false end
    			return (S.autoGolden and #craftableList("Golden") > 0) or (S.autoDiamond and #craftableList("Diamond") > 0)
    		end

    		-- Fishing Index Hunter: golden fish missing from the index are crafted once enough normal ones are caught.
    		Auto.FishCraft = { lastTrip = -1e9, blockedUntil = -1e9 }
    		Auto.fishCraftList = function(kind)
    			kind = kind or "Golden"
    			local fish = Auto.Fish
    			local plan = fish and fish.plan
    			local list = {}
    			if not (S.fishIndexHunt and Auto.fishVariantOn(kind) and plan and type(plan.missing) == "table") then
    				return list
    			end
    			local reqG, reqD = craftRequirements()
    			local multi = petsMulti()
    			for _, name in ipairs(plan.missing) do
    				local base = string.match(name, "^" .. kind .. " (.+)$")
    				if base then
    					local info = if type(multi) == "table" then multi[base] else nil
    					local rarity = if type(info) == "table" then info[3] else nil
    					local exists = type(multi) ~= "table" or multi[kind .. " " .. base] ~= nil
    					if exists and rarity ~= "Exclusive" and rarity ~= "Secret" then
    						if kind == "Golden" then
    							if petStock("NormalPetsData", base) >= reqG then
    								table.insert(list, base)
    							end
    						elseif petStock("GoldenPetsData", "Golden " .. base) >= reqD then
    							table.insert(list, "Golden " .. base)
    						elseif petStock("GoldenPetsData", base) >= reqD then
    							table.insert(list, base)
    						end
    					end
    				end
    			end
    			table.sort(list)
    			return list
    		end
    		Auto.fishCraftDue = function(now)
    			local state = Auto.FishCraft
    			if not S.fishIndexHunt or now - state.lastTrip < 45 or now < state.blockedUntil then
    				return false
    			end
    			return #Auto.fishCraftList("Golden") > 0 or #Auto.fishCraftList("Diamond") > 0
    		end
    		Auto.doFishCraft = function()
    			local state = Auto.FishCraft
    			state.lastTrip = os.clock()
    			local total = 0
    			for _, kind in ipairs({ "Golden", "Diamond" }) do
    				local list = Auto.fishCraftList(kind)
    				local done = if #list > 0 then craftBulk(kind, list) else 0
    				if #list > 0 then
    					Auto.log("FISHCRAFT", kind, "wanted=" .. #list, "done=" .. done)
    				end
    				total += done
    				if done > 0 then
    					queueToast("Fishing Index", string.format("Crafted %d %s fish", done, string.lower(kind)))
    				end
    			end
    			if total == 0 then
    				state.blockedUntil = os.clock() + 120
    			end
    		end
    
    		local function indexedCount()
    			local folder = getDataFolder("IndexData")
    			if not folder then return nil end
    			local multi = petsMulti()
    			local count = 0
    			for _, child in ipairs(folder:GetChildren()) do
    				if child:IsA("BoolValue") and child.Value == true and (type(multi) ~= "table" or multi[child.Name] ~= nil) then
    					count += 1
    				end
    			end
    			return count
    		end
    
    		local function favoriteState()
    			local ok, result = pcall(function()
    				return game:GetService("AvatarEditorService"):GetFavoriteAsync(74629631798007, Enum.AvatarItemType.Asset)
    			end)
    			if ok and type(result) == "boolean" then
    				return result
    			end
    			return nil
    		end
    
    		local function questStep()
    			local now = os.clock()
    			local flags = {}
    			for i = 1, #IndexThresholds do
    				flags[i] = readData("IndexRewardsData", "Reward" .. i)
    			end
    			if Quest.lastIndexFlags then
    				for i = 1, #IndexThresholds do
    					if flags[i] == true and Quest.lastIndexFlags[i] == false then
    						Saved.questsClaimed += 1
    						SaveDirty = true
    						queueToast("Quests", "Index reward " .. i .. " claimed")
    					end
    				end
    			end
    			Quest.lastIndexFlags = flags
    			if not S.autoQuests then return end
    
    			local pick = S.questPick or {}
    			local count = indexedCount()
    			local claimIndex = Auto.knitRemote("IndexService", "RE", "ClaimReward")
    			if pick.Index and count and claimIndex then
    				for i, need in ipairs(IndexThresholds) do
    					if flags[i] == false and count >= need and now - (Quest.indexClaimAt[i] or -1e9) > 15 then
    						Quest.indexClaimAt[i] = now
    						pcall(function() claimIndex:FireServer("Reward" .. i) end)
    					end
    				end
    			end
    
    			local left = if Quest.dailyLeft then Quest.dailyLeft - (now - Quest.dailyAt) else nil
    			local day = tonumber(readData("DailyRewardsData", "NextDay")) or Quest.dailyDay
    			local claimDay = Auto.knitRemote("DailyRewardsService", "RE", "ClaimDay")
    			if pick.Daily and left and left <= 0 and day and claimDay and readData("DailyRewardsData", "Day" .. day) ~= true and now - Quest.dailyClaimAt > 20 then
    				Quest.dailyClaimAt = now
    				pcall(function() claimDay:FireServer("Day" .. day) end)
    				task.delay(2, function()
    					Quest.pollDaily = true
    				end)
    			end
    
    			local groupClaim = Auto.knitRemote("GroupRewardsService", "RE", "ClaimRequest")
    			if pick.Group and readData("GroupRewardsData", "Claimed") == false and GC.member == true and groupClaim and now - Quest.groupClaimAt > 120 then
    				Quest.groupClaimAt = now
    				pcall(function() groupClaim:FireServer() end)
    			end
    
    			if pick.Verify and readData("VerifyRewardsData", "Claimed") == false then
    				local verify = Auto.knitRemote("VerifyRewardsService", "RE", "VerifyRequest")
    				local claim = Auto.knitRemote("VerifyRewardsService", "RE", "ClaimRequest")
    				local all = true
    				for _, taskName in ipairs({ "Like", "Group", "Favorite" }) do
    					if readData("VerifyRewardsData", taskName) ~= true then
    						all = false
    						local canTry = verify and not Quest.verifyTried[taskName] and (taskName ~= "Group" or GC.member == true)
    						if canTry then
    							Quest.verifyTried[taskName] = now
    							if taskName == "Favorite" then
    								local favorited = favoriteState()
    								if favorited == true then
    									pcall(function() verify:FireServer("Favorite", true) end)
    								end
    							else
    								pcall(function() verify:FireServer(taskName) end)
    							end
    							break
    						end
    					end
    				end
    				if all and claim and now - Quest.verifyClaimAt > 60 then
    					Quest.verifyClaimAt = now
    					pcall(function() claim:FireServer() end)
    				end
    			end
    		end
    
    		local function collectQuests()
    			local quests = {}
    			quests.indexCount = indexedCount()
    			local claimed = 0
    			for i, need in ipairs(IndexThresholds) do
    				if readData("IndexRewardsData", "Reward" .. i) == true then
    					claimed += 1
    				elseif not quests.indexNext then
    					quests.indexNext = need
    				end
    			end
    			quests.indexClaimed = claimed
    			quests.indexTotal = #IndexThresholds
    			quests.dailyLeft = if Quest.dailyLeft then math.max(0, Quest.dailyLeft - (os.clock() - Quest.dailyAt)) else nil
    			quests.dailyDay = tonumber(readData("DailyRewardsData", "NextDay")) or Quest.dailyDay
    			quests.groupClaimed = readData("GroupRewardsData", "Claimed")
    			quests.member = GC.member
    			local verified = 0
    			for _, taskName in ipairs({ "Like", "Group", "Favorite" }) do
    				if readData("VerifyRewardsData", taskName) == true then
    					verified += 1
    				end
    			end
    			quests.verified = verified
    			quests.verifyClaimed = readData("VerifyRewardsData", "Claimed")
    			Snap.quests = quests
    		end
    
    		local Ufo = { hits = 0, hitThisEgg = false, lastEgg = nil, needTravel = nil, travelTry = -1e9, status = "No UFO right now", engaged = false, back = nil, returnNow = false, round = 0, roundEgg = nil, finalized = false, myRank = nil, myDmg = nil, topDmg = nil }
    		local Worlds = { lastBuy = -1e9, fails = 0, padTry = -1e9, status = "" }
    		local ShopState = {}
    		local Friends = { sent = {}, count = 0, here = 0, total = 0, lastScan = -1e9, acceptOk = nil }
    		local Hook = { queue = {}, thumbs = {}, gameIcon = nil, sent = 0, lastSend = -1e9 }
    		local EggTravel = { need = nil, lastTry = -1e9, fails = 0, blockedUntil = -1e9 }
    
    		local function httpRequest(options)
    			local fn = (typeof(syn) == "table" and syn.request) or (typeof(http) == "table" and http.request) or http_request or request
    			if type(fn) ~= "function" then
    				return nil
    			end
    			local ok, response = pcall(fn, options)
    			if ok then
    				return response
    			end
    			return nil
    		end
    
    		local function worldUnlocked(key)
    			if key == "Spawn" then return true end
    			return isWorldUnlocked(key) == true
    		end
    
    		local function ufoInfo()
    			local egg = workspace:FindFirstChild("AlienEventEgg")
    			local eligible = LocalPlayer:GetAttribute("AlienEggEligible") == true
    			if not egg then
    				return { active = false, eligible = eligible }
    			end
    			local zone = egg:GetAttribute("Zone")
    			local world = if type(zone) == "string" then Auto.worldKey(zone) else nil
    			if world and not WorldBounds[world] then
    				world = nil
    			end
    			return {
    				active = true,
    				eligible = eligible,
    				world = world,
    				hp = tonumber(egg:GetAttribute("HP")),
    				maxHp = tonumber(egg:GetAttribute("MaxHP")),
    			}
    		end
    
    		local function readUfoBoard(egg)
    			local rank, mine, best = nil, nil, 0
    			for i = 1, 3 do
    				local id = tonumber(egg:GetAttribute("Top" .. i .. "Id"))
    				local dmg = tonumber(egg:GetAttribute("Top" .. i .. "Dmg")) or 0
    				if id and id > 0 then
    					best = math.max(best, dmg)
    					if id == LocalPlayer.UserId then
    						rank, mine = i, dmg
    					end
    				end
    			end
    			return rank, mine, best
    		end
    
    		-- the client's pets: workspace.PlayerPets[name] models filtered like the game's getPets (dump 98722-98757)
    		local PetHit = { ufoLast = setmetatable({}, { __mode = "k" }), strikeLast = setmetatable({}, { __mode = "k" }), mod = nil, modTry = -1e9, ufo = {} }
    		function PetHit.pets()
    			local folder = workspace:FindFirstChild("PlayerPets")
    			folder = folder and folder:FindFirstChild(LocalPlayer.Name)
    			if not folder then
    				return {}
    			end
    			local list = {}
    			for _, child in ipairs(folder:GetChildren()) do
    				if child:IsA("Model") and child.PrimaryPart then
    					table.insert(list, child)
    				end
    			end
    			if PetHit.mod == nil and os.clock() - PetHit.modTry > 30 then
    				PetHit.modTry = os.clock()
    				pcall(function()
    					PetHit.mod = require(ReplicatedStorage.Modules:WaitForChild("EquippedPetsModule", 5))
    				end)
    			end
    			local mod = PetHit.mod
    			if type(mod) == "table" and type(mod.FilterRealPetModels) == "function" then
    				local ok, real = pcall(mod.FilterRealPetModels, LocalPlayer, list)
    				if ok and type(real) == "table" then
    					return real
    				end
    			end
    			return list
    		end
    		-- per-pet attack cooldown v563 of the client (dump 102583-102607)
    		function PetHit.cooldown(onMoon)
    			local tree = tonumber(readData("VariousBoosts", "TreeAttackSpeedMult"))
    			local mult = if tree and tree == tree and tree >= 1 then math.min(tree, 10) else 1
    			local pet = tonumber(readData("TrustedStats", "PetAttackSpeedMultiplier"))
    			pet = if pet and pet == pet and pet >= 0 and pet < math.huge then math.min(pet, 2) else 1
    			if pet > 1 then
    				mult *= pet
    			end
    			if onMoon then
    				local moon = tonumber(readData("TrustedStats", "MoonPetAttackSpeedMultiplier"))
    				if moon and moon == moon and moon >= 0 and moon < math.huge then
    					mult *= moon
    				end
    			end
    			if mult > 1 then
    				return math.max(1 / mult, 0.15)
    			end
    			return 1
    		end
    		function PetHit.ready(last, pet, cd, now)
    			local t = last[pet]
    			if t and now - t < cd then
    				return false
    			end
    			last[pet] = now
    			return true
    		end
    		-- UFO: every pet attack on AlienEventEgg fires Hit(pet.Name, ToyInstanceId) (dump 99743-99746); pets the game already
    		-- has on the UFO orbit (17.6 studs, dump 98705) are left to the game, the ones still walking are added here
    		function PetHit.ufoPets(hit, egg)
    			local U = PetHit.ufo
    			local now = os.clock()
    			if U.egg ~= egg then
    				U.egg, U.startAt, U.off, U.compared = egg, now, false, false
    				U.baseDmg, U.baseAt, U.baseRate, U.petDmg, U.petAt = nil, nil, nil, nil, nil
    				U.winAt, U.winDmg, U.winPets, U.winHits = now, Ufo.myDmg, {}, 0
    			end
    			-- first 5 s clicks only: the damage baseline for the check below
    			if now - U.startAt < 5 then
    				if U.baseDmg == nil and Ufo.myDmg then
    					U.baseDmg, U.baseAt = Ufo.myDmg, now
    				end
    				return
    			end
    			if U.baseRate == nil then
    				U.baseRate = if U.baseDmg and Ufo.myDmg and now - U.baseAt > 1 then (Ufo.myDmg - U.baseDmg) / (now - U.baseAt) else false
    				U.petDmg, U.petAt = Ufo.myDmg, now
    			end
    			if U.off then
    				return
    			end
    			local zone = egg:GetAttribute("Zone")
    			if zone ~= nil and zone ~= readData("BreakableData", "Area") then
    				return
    			end
    			local primary = egg:FindFirstChild("Primary") or egg.PrimaryPart
    			if not (primary and primary:IsA("BasePart")) then
    				return
    			end
    			local center = primary.Position
    			if (getCharPos() - center).Magnitude > 60 then
    				return
    			end
    			local cd = PetHit.cooldown(false)
    			for _, pet in ipairs(PetHit.pets()) do
    				local pp = pet.PrimaryPart
    				if pp then
    					local off = pp.Position - center
    					if Vector3.new(off.X, 0, off.Z).Magnitude > 25.6 and PetHit.ready(PetHit.ufoLast, pet, cd, now) then
    						hit:FireServer(pet.Name, pet:GetAttribute("ToyInstanceId"))
    						U.winPets[pet] = true
    						U.winHits += 1
    					end
    				end
    			end
    			if now - U.winAt >= 10 then
    				local pets = 0
    				for _ in pairs(U.winPets) do
    					pets += 1
    				end
    				local dmg = if Ufo.myDmg and U.winDmg then formatNumber(Ufo.myDmg - U.winDmg) else "?"
    				Auto.log("UFO", string.format("hit pets=%d dmg=%s hits=%d cd=%.2f", pets, dmg, U.winHits, cd))
    				U.winAt, U.winDmg, U.winPets, U.winHits = now, Ufo.myDmg, {}, 0
    			end
    			if not U.compared and now - U.startAt >= 20 then
    				U.compared = true
    				if type(U.baseRate) == "number" and U.petDmg and Ufo.myDmg and now - U.petAt > 1 then
    					local rate = (Ufo.myDmg - U.petDmg) / (now - U.petAt)
    					Auto.log("UFO", string.format("pethit dmg/s=%s->%s", formatNumber(U.baseRate), formatNumber(rate)))
    					if rate <= U.baseRate then
    						U.off = true
    						Auto.log("UFO", "pethit no effect, clicks only for this UFO")
    					end
    				else
    					Auto.log("UFO", "pethit dmg/s=? (not in the top 3, kept on)")
    				end
    			end
    		end

    		local function finalizeUfo(result)
    			if Ufo.finalized then
    				return
    			end
    			Ufo.finalized = true
    			if result and result.despawned then
    				queueToast("UFO Event", "The UFO left before anyone broke it")
    				return
    			end
    			local won = result ~= nil and result.winner == LocalPlayer.Name
    			local rank, dmg = Ufo.myRank, Ufo.myDmg
    			Saved.ufoBroken += 1
    			if won then
    				Saved.ufoWon = (tonumber(Saved.ufoWon) or 0) + 1
    			end
    			if rank then
    				Saved.ufoTop3 = (tonumber(Saved.ufoTop3) or 0) + 1
    			end
    			SaveDirty = true
    			local damage = if dmg then formatNumber(dmg) .. " damage" else "outside the top 3 on damage"
    			local title, text, toast
    			if won then
    				title = "UFO won"
    				text = "Got the **Alien Egg**  \u{00B7}  " .. damage
    				toast = "You won the UFO and got the Alien Egg"
    			elseif rank then
    				title = "UFO  \u{00B7}  #" .. rank .. " on damage"
    				text = string.format("Finished **#%d** with %s, another player got the Alien Egg", rank, damage)
    				toast = string.format("UFO down, you were #%d on damage", rank)
    			else
    				title = "UFO helped"
    				text = "Helped break the UFO, " .. damage
    				toast = "UFO down" .. (if result and result.winner then ", " .. tostring(result.winner) .. " got the Alien Egg" else "")
    			end
    			queueToast("UFO Event", toast)
    			if won or rank then
    				pcall(Auto.Metrics.event, "UFO", title, if won then "#60d696" else "#7dd3fc")
    			end
    			local mode = tostring(S.ufoHookMode or "Only when I win")
    			local post = won or (mode == "When I'm top 3" and rank ~= nil) or mode == "Every UFO I helped"
    			if post and Auto.postEvent then
    				Auto.postEvent("UFO", title, text .. "  \u{00B7}  " .. formatNumber(tonumber(Saved.ufoWon) or 0) .. " won in total", if won then 5814783 else 8190976, won and S.pingFor.UFO == true)
    			end
    		end
    
    		task.spawn(function()
    			local hookAt = -1e9
    			while alive() do
    				task.wait(0.12)
    				local ok, err = pcall(function()
    					if os.clock() - hookAt > 5 then
    						hookAt = os.clock()
    						hookEvent("ufoAnnounce", "AlienEventService", "Announce", function(kind, who, value)
    							if kind == "Destroyed" and Ufo.hitThisEgg then
    								finalizeUfo({ winner = tostring(who), dmg = tonumber(value) })
    							elseif kind == "Despawned" and Ufo.hitThisEgg then
    								finalizeUfo({ despawned = true })
    							end
    						end)
    					end
    					local egg = workspace:FindFirstChild("AlienEventEgg")
    					if egg and egg ~= Ufo.roundEgg then
    						Ufo.roundEgg = egg
    						Ufo.round += 1
    						Ufo.hitThisEgg = false
    						Ufo.finalized = false
    						Ufo.myRank, Ufo.myDmg, Ufo.topDmg = nil, nil, nil
    					end
    					if egg then
    						Ufo.myRank, Ufo.myDmg, Ufo.topDmg = readUfoBoard(egg)
    					end
    					if Ufo.lastEgg and Ufo.lastEgg ~= egg and Ufo.hitThisEgg and not Ufo.finalized then
    						local round = Ufo.round
    						task.delay(4, function()
    							if Ufo.round == round and Ufo.hitThisEgg and not Ufo.finalized then
    								finalizeUfo(nil)
    							end
    						end)
    					end
    					Ufo.lastEgg = egg
    					Ufo.engaged = false
    					if not egg then
    						Ufo.needTravel = nil
    						Ufo.status = "No UFO right now"
    						if Ufo.back then
    							Ufo.returnNow = true
    						end
    						return
    					end
    					if LocalPlayer:GetAttribute("AlienEggEligible") ~= true then
    						Ufo.needTravel = nil
    						Ufo.status = "Not eligible yet"
    						return
    					end
    					local info = ufoInfo()
    					local here = currentWorld()
    					if info.world and here ~= info.world then
    						Ufo.status = "In another world"
    						Ufo.needTravel = nil
    						if not worldUnlocked(info.world) then
    							Ufo.status = "World locked"
    						elseif S.autoUfo and S.ufoTravel then
    							Ufo.status = "Flying there"
    							Ufo.needTravel = info.world
    							Ufo.engaged = true
    						end
    						return
    					end
    					Ufo.needTravel = nil
    					if not S.autoUfo then
    						Ufo.status = "Active here"
    						return
    					end
    					Ufo.engaged = true
    					if S.ufoTravel and not Mover.busy then
    						local hrp = getRoot()
    						local okPivot, pivot = pcall(function() return egg:GetPivot().Position end)
    						if hrp and okPivot and pivot and (hrp.Position - pivot).Magnitude > 90 then
    							Ufo.needTravel = here or info.world
    						end
    					end
    					local hit = Auto.knitRemote("AlienEventService", "RE", "Hit")
    					if hit then
    						pcall(function() hit:FireServer() end)
    						Ufo.hits += 1
    						Ufo.hitThisEgg = true
    						Saved.ufoHits += 1
    						SaveDirty = true
    						Ufo.status = "Hitting"
    						local okPet, errPet = pcall(PetHit.ufoPets, hit, egg)
    						if not okPet then
    							diag("ufopet", errPet)
    						end
    					end
    				end)
    				if not ok then
    					diag("ufo", err)
    				end
    			end
    		end)
    
    		-- Pet Strikes Without Walking (opt-in test, blatant.md finding 1): StrikeService.Submit {CoinId, 1, petName, splash?}
    		-- exactly like StrikeClient.Strike (dump 104129-104190) for pets that are still walking; measures itself every 60 s
    		local Probe = { state = nil, dead = false, sent = 0, res = 0, flag = 0, nogain = 0, pets = {} }
    		function Probe.gameSent()
    			local ok, value = pcall(function()
    				return LocalPlayer.PlayerScripts["Breakables Breaking Handler"].StrikeClient:GetAttribute("Sent")
    			end)
    			return if ok then tonumber(value) or 0 else 0
    		end
    		function Probe.snap()
    			local now = os.clock()
    			return { at = now, coins = Session.earned.Coins or 0, rubies = Session.earned.Rubies or 0, sent = Probe.sent, res = Probe.res, flag = Probe.flag, game = Probe.gameSent() }
    		end
    		function Probe.kill(result, extra)
    			Probe.dead = true
    			Probe.state = nil
    			Auto.log("PROBE", "petstrike result=" .. result .. (if extra then " " .. extra else "") .. " off for this session")
    			if Toggles.PetStrike and Toggles.PetStrike.Value then
    				pcall(Toggles.PetStrike.SetValue, Toggles.PetStrike, false)
    			end
    		end
    		-- a breakable the pets are on: within its orbit radius + 2 (dump 98705-98720, 102548)
    		function Probe.busy(pet, list)
    			local pp = pet.PrimaryPart
    			if not pp then
    				return true
    			end
    			for _, b in ipairs(list) do
    				local part = b.Parent and (b.PrimaryPart or b:FindFirstChild("Primary"))
    				if part and part:IsA("BasePart") then
    					local r = math.max(math.sqrt((part.Size.X / 2) ^ 2 + (part.Size.Z / 2) ^ 2) + 4, 6) + 2
    					local off = part.Position - pp.Position
    					if Vector3.new(off.X, 0, off.Z).Magnitude <= r then
    						return true
    					end
    				end
    			end
    			return false
    		end
    		-- collectSplash of the client: up to 12 CoinIds within 30 studs, nearest first, only with the Lightning charm (dump 104038-104107)
    		function Probe.splash(target, part)
    			local boost = tonumber(readData("VariousBoosts", "CharmsLightningBoost"))
    			if not (boost and boost == boost and boost > 0) then
    				return nil
    			end
    			local near = {}
    			for _, child in ipairs(target.Parent:GetChildren()) do
    				if child ~= target and child:IsA("Model") and child.Name ~= "AlienEventEgg" then
    					local id = child:GetAttribute("CoinId")
    					local p = typeof(id) == "string" and id ~= "" and (child.PrimaryPart or child:FindFirstChild("Primary"))
    					if p then
    						local dist = (p.Position - part.Position).Magnitude
    						if dist <= 30 then
    							table.insert(near, { id = id, dist = dist })
    						end
    					end
    				end
    			end
    			if #near == 0 then
    				return nil
    			end
    			table.sort(near, function(a, b) return a.dist < b.dist end)
    			local ids = {}
    			for i = 1, math.min(#near, 12) do
    				ids[i] = near[i].id
    			end
    			return ids
    		end
    		function Probe.fire(now)
    			local submit = Auto.knitRemote("StrikeService", "RE", "Submit")
    			if not submit then
    				return
    			end
    			local zone = readData("BreakableData", "Area")
    			if type(zone) ~= "string" or zone == "" then
    				zone = Stats.lastArea
    			end
    			if type(zone) ~= "string" or zone == "" then
    				return
    			end
    			local list = getCachedBreakables(zone)
    			local target = nil
    			local root = getCharPos()
    			if lockedTarget and isLockValid(lockedTarget) then
    				local pos = getModelPosition(lockedTarget)
    				if pos and (pos - root).Magnitude <= 40 then
    					target = lockedTarget
    				end
    			end
    			if not target then
    				for _, e in ipairs(getSortedTargets(list)) do
    					if e.dist <= 40 and isLockValid(e.target) then
    						target = e.target
    						break
    					end
    				end
    			end
    			if not (target and target.Name ~= "AlienEventEgg") then
    				return
    			end
    			local coinId = target:GetAttribute("CoinId")
    			local part = target.PrimaryPart or target:FindFirstChild("Primary")
    			if typeof(coinId) ~= "string" or coinId == "" or not part then
    				return
    			end
    			local cd = PetHit.cooldown(target.Parent ~= nil and target.Parent.Name == "TheMoon")
    			local splash = Probe.splash(target, part)
    			local packet = {}
    			for _, pet in ipairs(PetHit.pets()) do
    				if #packet >= 96 then
    					break
    				end
    				if not Probe.busy(pet, list) and PetHit.ready(PetHit.strikeLast, pet, cd, now) then
    					local entry = { coinId, 1, pet.Name }
    					if splash then
    						entry[4] = splash
    					end
    					table.insert(packet, entry)
    					Probe.pets[pet] = true
    				end
    			end
    			if #packet > 0 then
    				submit:FireServer(packet)
    				Probe.sent += #packet
    			end
    		end
    		function Probe.window()
    			local a, b = Probe.base, Probe.snap()
    			local w = Probe.win
    			local secs = math.max(b.at - w.at, 1)
    			local coins, rubies = (b.coins - w.coins) / secs, (b.rubies - w.rubies) / secs
    			local sent = b.sent - w.sent
    			local expect = sent + (b.game - w.game)
    			local res = b.res - w.res
    			local flag = b.flag - w.flag
    			local recv = if expect > 0 then res / expect else 1
    			local flagRate = if res > 0 then flag / res else 0
    			local pets = 0
    			for _ in pairs(Probe.pets) do
    				pets += 1
    			end
    			Probe.pets = {}
    			local gain = (a.coins > 0 and coins >= a.coins * 1.05) or (a.rubies > 0 and rubies >= a.rubies * 1.05)
    			local stats = string.format("sent=%d pets=%d recv=%.2f flag32=%.2f coins/s=%s->%s rubies/s=%s->%s", sent, pets, recv, flagRate, formatNumber(a.coins), formatNumber(coins), formatNumber(a.rubies), formatNumber(rubies))
    			Probe.win = b
    			if sent >= 50 and (recv < 0.9 or flagRate > a.flagRate + 0.1) then
    				Probe.kill("rejected", stats)
    				return
    			end
    			if gain then
    				Probe.nogain = 0
    				Auto.log("PROBE", "petstrike result=gain " .. stats)
    			else
    				Probe.nogain += 1
    				Auto.log("PROBE", "petstrike result=nogain " .. stats)
    				if Probe.nogain >= 3 then
    					Probe.kill("nogain")
    				end
    			end
    		end
    		task.spawn(function()
    			pcall(function()
    				Library:GiveSignal(game:GetService("GuiService").ErrorMessageChanged:Connect(function(message)
    					if Probe.state == "test" then
    						Saved.petStrikeKicked = os.time()
    						SaveDirty = true
    						pcall(saveStats, true)
    						Probe.kill("kicked", "msg=" .. tostring(message))
    					end
    				end))
    			end)
    			while alive() do
    				task.wait(0.1)
    				local ok, err = pcall(function()
    					if not S.petStrike or Probe.dead or not S.autoFarm or (S.autoUfo and Ufo.engaged) then
    						if Probe.state then
    							Auto.log("PROBE", "petstrike paused")
    						end
    						Probe.state = nil
    						return
    					end
    					local now = os.clock()
    					if Probe.state == nil then
    						if (tonumber(Saved.petStrikeKicked) or 0) > 0 then
    							Probe.kill("blocked", "(kicked on " .. os.date("%Y-%m-%d %H:%M", Saved.petStrikeKicked) .. ")")
    							return
    						end
    						if ReplicatedStorage:GetAttribute("ServerStrikeAuthority") ~= true then
    							Probe.kill("inactive", "(ServerStrikeAuthority off)")
    							return
    						end
    						hookEvent("petStrikeResults", "StrikeService", "Results", function(list)
    							if type(list) ~= "table" then
    								return
    							end
    							for _, v in ipairs(list) do
    								if type(v) == "table" then
    									Probe.res += 1
    									if typeof(v[4]) == "number" and bit32.band(v[4], 32) ~= 0 then
    										Probe.flag += 1
    									end
    								end
    							end
    						end)
    						Probe.state = "base"
    						Probe.win = Probe.snap()
    						Auto.log("PROBE", "petstrike start, 60 s baseline without strikes")
    						return
    					end
    					if Probe.state == "base" then
    						if now - Probe.win.at >= 60 then
    							local b, w = Probe.snap(), Probe.win
    							local secs = math.max(b.at - w.at, 1)
    							local res = b.res - w.res
    							Probe.base = { coins = (b.coins - w.coins) / secs, rubies = (b.rubies - w.rubies) / secs, flagRate = if res > 0 then (b.flag - w.flag) / res else 0 }
    							Probe.win = b
    							Probe.state = "test"
    							Auto.log("PROBE", string.format("petstrike baseline coins/s=%s rubies/s=%s flag32=%.2f, strikes on", formatNumber(Probe.base.coins), formatNumber(Probe.base.rubies), Probe.base.flagRate))
    						end
    						return
    					end
    					Probe.fire(now)
    					if now - Probe.win.at >= 60 then
    						Probe.window()
    					end
    				end)
    				if not ok then
    					diag("petstrike", err)
    				end
    			end
    		end)

    		local function ufoTrip()
    			local world = Ufo.needTravel
    			if not world then return end
    			Ufo.travelTry = os.clock()
    			local hrp = getRoot()
    			if hrp and not Ufo.back and S.returnAfter and not (S.indexHunt and Hunter.egg) then
    				Ufo.back = { cframe = hrp.CFrame, world = getWorldAt(hrp.Position) }
    			end
    			Mover.busy = true
    			Mover.task = "Flying to the UFO"
    			local ok, reached = pcall(travelTo, world)
    			if ok and reached then
    				local egg = workspace:FindFirstChild("AlienEventEgg")
    				local primary = egg and (egg:FindFirstChild("Primary") or egg.PrimaryPart)
    				if primary and primary:IsA("BasePart") then
    					pcall(standAt, primary, 14)
    				end
    			end
    			Mover.busy = false
    			Mover.task = ""
    		end
    
    		local function worldInfo()
    			local cost = Auto.GameData.worldCost
    			local order = if cost and type(cost.Order) == "table" then cost.Order else { "BirchForest", "TreasureDunes", "FrozenAlley", "HauntedHouse", "PetKingdom", "EnchantedGrove", "VolcanoHollow" }
    			local all = Auto.GameData.worldOrder or UI.WorldOrder or {}
    			local owned, total = 0, 0
    			for _, key in ipairs(all) do
    				total += 1
    				if worldUnlocked(key) then
    					owned += 1
    				end
    			end
    			local info = { owned = owned, total = total }
    			local last = "Spawn"
    			for _, key in ipairs(order) do
    				if not worldUnlocked(key) then
    					info.next = key
    					info.price = cost and cost.Cost and tonumber(cost.Cost[key]) or nil
    					info.currency = "Coins"
    					info.from = last
    					break
    				end
    				last = key
    			end
    			if not info.next and cost and cost.MoonWorld then
    				local moon = Auto.worldKey(cost.MoonWorld)
    				if not worldUnlocked(moon) then
    					info.next = moon
    					info.price = tonumber(cost.MoonRubiesCost)
    					info.currency = "Rubies"
    					info.moon = true
    					info.needs = cost.MoonRequires and Auto.worldKey(cost.MoonRequires) or nil
    					info.from = info.needs
    				end
    			end
    			if info.next then
    				info.balance = getStat(info.currency) or 0
    				info.affordable = info.price ~= nil and info.balance >= info.price and (not info.needs or worldUnlocked(info.needs))
    			end
    			return info
    		end
    
    		local function worldPad(fromWorld)
    			local map = workspace:FindFirstChild("Map")
    			local worlds = map and map:FindFirstChild("Worlds")
    			local folderName = Auto.GameData.worldFolder and Auto.GameData.worldFolder[fromWorld] or fromWorld
    			local folder = worlds and worlds:FindFirstChild(folderName)
    			local pad = folder and (folder:FindFirstChild("TeleportNext") or folder:FindFirstChild("Teleport"))
    			return pad and pad:FindFirstChild("rewardTouch")
    		end
    
    		local function buyWorld(info, nearPad)
    			local purchase = Auto.knitRemote("TeleportService", "RE", "Purchase")
    			if not purchase then return false end
    			if nearPad then
    				local ok = travelTo(info.from or "Spawn")
    				local pad = worldPad(info.from or "Spawn")
    				if ok and pad then
    					standAt(pad, 3)
    					task.wait(0.6)
    				end
    			end
    			Worlds.lastBuy = os.clock()
    			pcall(function() purchase:FireServer(if info.moon then "BoughtMoon" else "Bought") end)
    			local waited = 0
    			while waited < 4 do
    				if worldUnlocked(info.next) then
    					Auto.log("BUY", "world", info.next, "for", info.price, info.currency)
    					Saved.worldsBought += 1
    					SaveDirty = true
    					Worlds.fails = 0
    					queueToast("Worlds", prettyWorld(info.next) .. " unlocked")
    					Auto.Metrics.event("World", prettyWorld(info.next) .. " unlocked", "#60d696")
    					if Auto.postEvent then
    						Auto.postEvent("World", "New world", "**" .. prettyWorld(info.next) .. "** unlocked", 5814783)
    					end
    					return true
    				end
    				waited += task.wait(0.25) or 0.25
    			end
    			Worlds.fails += 1
    			return false
    		end
    
    		local function readLevel(folderName, name)
    			local value = tonumber(readData(folderName, name))
    			return if value then math.floor(value) else 0
    		end
    
    		local function spawnShop()
    			local module = Auto.GameData.spawnUpgrades
    			if not module then return nil end
    			return {
    				id = "spawn",
    				title = "Spawn upgrades",
    				currency = "Rubies",
    				folder = "UpgradesData",
    				service = "UpgradesService",
    				names = UI.SpawnUpgradeNames,
    				enabled = S.autoSpawnUp or S.farmOP,
    				pick = S.spawnPick,
    				maxLevel = function(name)
    					return tonumber(module.MaxLevels and module.MaxLevels[name]) or 0
    				end,
    				cap = function(name)
    					return tonumber(module.MaxLevels and module.MaxLevels[name]) or 0
    				end,
    				price = function(name, level)
    					local list = module[name]
    					local entry = type(list) == "table" and list[level + 1] or nil
    					return type(entry) == "table" and tonumber(entry.Price) or nil
    				end,
    				anchor = function()
    					local machine, touch = getMachine("Upgrades")
    					local part = touch
    					if not part and machine then
    						part = if machine:IsA("BasePart") then machine else machine.PrimaryPart
    						if not part then
    							for _, child in ipairs(machine:GetDescendants()) do
    								if child:IsA("BasePart") then
    									part = child
    									break
    								end
    							end
    						end
    					end
    					return part, machineWorld("Upgrades", "Spawn")
    				end,
    			}
    		end
    
    		local function moonShop(shopKey)
    			local config = Auto.GameData.moonConfig
    			local shop = config and config[shopKey]
    			if not shop then return nil end
    			local folder = config.DataFolders and config.DataFolders[shopKey] or (if shopKey == "Permanent" then "MoonPermUpgradesData" else "MoonUpgradesData")
    			return {
    				id = shopKey,
    				title = if shopKey == "Permanent" then "Moon permanent upgrades" else "Moon incremental upgrades",
    				currency = "Gems",
    				folder = folder,
    				service = if shopKey == "Permanent" then "MoonPermUpgradesService" else "MoonUpgradesService",
    				names = shop.Order or {},
    				enabled = S.farmOP or (if shopKey == "Permanent" then S.autoMoonPerm else S.autoMoonIncr),
    				pick = if shopKey == "Permanent" then S.moonPermPick else S.moonIncrPick,
    				maxLevel = function(name)
    					return tonumber(shop.MaxLevels and shop.MaxLevels[name]) or 0
    				end,
    				cap = function(name)
    					if type(config.GetLevelCap) == "function" then
    						local ok, cap = pcall(config.GetLevelCap, LocalPlayer, shopKey, name)
    						if ok and tonumber(cap) then
    							return tonumber(cap)
    						end
    					end
    					return tonumber(shop.MaxLevels and shop.MaxLevels[name]) or 0
    				end,
    				price = function(name, level)
    					local list = shop[name]
    					local entry = type(list) == "table" and list[level + 1] or nil
    					return type(entry) == "table" and tonumber(entry.Price) or nil
    				end,
    				anchor = function()
    					local map = workspace:FindFirstChild("Map")
    					local worlds = map and map:FindFirstChild("Worlds")
    					local moonKey = moonWorld()
    					local folderName = Auto.GameData.worldFolder and Auto.GameData.worldFolder[moonKey] or "The Moon"
    					local moonFolder = worlds and worlds:FindFirstChild(folderName)
    					local kiosk
    					if moonFolder then
    						if shopKey == "Permanent" then
    							kiosk = moonFolder:FindFirstChild("PermIncrUpgrades1")
    							kiosk = kiosk and kiosk:FindFirstChild("PermUpgrades1")
    						else
    							kiosk = moonFolder:FindFirstChild("IncrementalUpgrades1")
    							kiosk = kiosk and kiosk:FindFirstChild("IncrUpgrades1")
    						end
    					end
    					return kiosk and kiosk:FindFirstChild("UI"), moonKey
    				end,
    			}
    		end
    
    		local function shopSnapshot(shop)
    			local rows = {}
    			local best, bestPrice, bestIndex = nil, nil, nil
    			local allMaxed, anyPicked, capped = true, false, false
    			local balance = getStat(shop.currency) or 0
    			local reserve = Auto.reserve(shop.currency)
    			local plan = Auto.Plan
    			local planOn = plan ~= nil and plan.ready and (S.farmOP or S.upgradeOrder == "Best value")
    			local bestValue = -math.huge
    			for index, name in ipairs(shop.names) do
    				local level = readLevel(shop.folder, name)
    				local maxLevel = shop.maxLevel(name)
    				local cap = math.min(shop.cap(name), maxLevel)
    				local price = if level < cap then shop.price(name, level) else nil
    				local picked = shop.pick[name] == true
    				rows[name] = { level = level, max = maxLevel, cap = cap, price = price, picked = picked }
    				if picked then
    					anyPicked = true
    					if level < maxLevel then
    						allMaxed = false
    						if level >= cap then
    							capped = true
    						end
    					end
    					if price then
    						local better
    						if planOn then
    							local value = plan.score("shop:" .. shop.id .. ":" .. name)
    							better = best == nil or value > bestValue
    							if better then
    								bestValue = value
    							end
    						elseif S.upgradeOrder == "Top to bottom" then
    							better = best == nil or index < bestIndex
    						else
    							better = best == nil or price < bestPrice
    						end
    						if better then
    							best, bestPrice, bestIndex = name, price, index
    						end
    					end
    				end
    			end
    			return {
    				rows = rows,
    				best = best,
    				bestPrice = bestPrice,
    				balance = balance,
    				reserve = reserve,
    				currency = shop.currency,
    				affordable = best ~= nil and bestPrice ~= nil and balance - (tonumber(reserve) or 0) >= bestPrice and (not planOn or plan.allows("shop:" .. shop.id .. ":" .. best, bestPrice, rows[best].level)),
    				allMaxed = anyPicked and allMaxed,
    				capped = capped,
    				anyPicked = anyPicked,
    			}
    		end
    
    		local function shopStateOf(shop)
    			local state = ShopState[shop.id]
    			if not state then
    				state = { needsTravel = nil, blockedUntil = -1e9, lastTrip = -1e9, bought = 0, maxToast = false, status = "Off" }
    				ShopState[shop.id] = state
    			end
    			return state
    		end
    
    		local function buyFromShop(shop, limit)
    			local remote = Auto.knitRemote(shop.service, "RE", "BuyUpgrade")
    			if not remote then return 0 end
    			local state = shopStateOf(shop)
    			local bought = 0
    			for _ = 1, limit do
    				if not alive() then break end
    				local snap = shopSnapshot(shop)
    				if not snap.affordable then break end
    				local before = readLevel(shop.folder, snap.best)
    				pcall(function() remote:FireServer(snap.best) end)
    				local waited = 0
    				while waited < 1.5 and readLevel(shop.folder, snap.best) == before do
    					waited += task.wait(0.1) or 0.1
    				end
    				if readLevel(shop.folder, snap.best) == before then
    					break
    				end
    				bought += 1
    				Auto.log("BUY", shop.id, snap.best, "level", before + 1, "for", snap.bestPrice, shop.currency, "score", if Auto.Plan then Auto.Plan.score("shop:" .. shop.id .. ":" .. snap.best) else -1)
    				state.bought += 1
    				Saved.upgradesBought += 1
    				SaveDirty = true
    				task.wait(0.15)
    			end
    			return bought
    		end
    
    		local function shopTrip(shop)
    			local state = shopStateOf(shop)
    			state.lastTrip = os.clock()
    			local anchor, world = shop.anchor()
    			if world then
    				local ok = travelTo(world)
    				if not ok then
    					state.blockedUntil = os.clock() + 120
    					return
    				end
    				anchor = shop.anchor()
    			end
    			if anchor and anchor:IsA("BasePart") then
    				Mover.task = "Buying " .. shop.title
    				pcall(standAt, anchor, 7)
    				task.wait(0.6)
    			end
    			local bought = buyFromShop(shop, 60)
    			if bought == 0 then
    				state.blockedUntil = os.clock() + 120
    			end
    		end
    
    		local function allShops()
    			local list = {}
    			local spawn = spawnShop()
    			if spawn then table.insert(list, spawn) end
    			local perm = moonShop("Permanent")
    			if perm then table.insert(list, perm) end
    			local incr = moonShop("Incremental")
    			if incr then table.insert(list, incr) end
    			return list
    		end
    
    		local function shopNeedsTrip(now)
    			for _, shop in ipairs(allShops()) do
    				local state = shopStateOf(shop)
    				local gameBuys = shop.id == "Incremental" and S.moonGameAuto and Auto.moonGameAutoOn ~= nil and Auto.moonGameAutoOn()
    				if shop.enabled and not gameBuys and state.needsTravel == true and now >= state.blockedUntil and now - state.lastTrip > 30 then
    					local snap = shopSnapshot(shop)
    					if snap.affordable then
    						return shop
    					end
    				end
    			end
    			return nil
    		end
    
    		task.spawn(function()
    			while alive() do
    				task.wait(1)
    				local ok, err = pcall(function()
    					for _, shop in ipairs(allShops()) do
    						local state = shopStateOf(shop)
    						local snap = shopSnapshot(shop)
    						if not shop.enabled then
    							state.status = "Off"
    						elseif snap.allMaxed then
    							state.status = "All maxed"
    							if not state.maxToast then
    								state.maxToast = true
    								queueToast("Upgrades", shop.title .. " are fully maxed")
    							end
    						elseif not snap.anyPicked then
    							state.status = "Pick an upgrade"
    						elseif not snap.best and snap.capped then
    							state.status = "Needs rebirth"
    						elseif not snap.affordable then
    							state.status = "Saving up"
    						elseif state.needsTravel == true then
    							state.status = if os.clock() < state.blockedUntil then "Retrying soon" else "Going to buy"
    						else
    							state.status = "Buying"
    							if not Mover.busy and os.clock() >= state.blockedUntil then
    								local bought = buyFromShop(shop, 10)
    								if bought > 0 then
    									state.needsTravel = false
    								elseif state.needsTravel == nil then
    									state.needsTravel = true
    								end
    							end
    						end
    						if shop.enabled and not snap.allMaxed then
    							state.maxToast = false
    						end
    					end
    				end)
    				if not ok then
    					diag("upgrades", err)
    				end
    			end
    		end)
    
    		task.spawn(function()
    			while alive() do
    				task.wait(2)
    				local ok, err = pcall(function()
    					local info = worldInfo()
    					S.worldSave = 0
    					if (S.autoBuyWorlds or S.farmOP) and info.next and info.currency == "Coins" and info.price and Auto.Plan and Auto.Plan.ready then
    						S.worldSave = Auto.Plan.keep.Coins or 0
    					end
    					if not (S.autoBuyWorlds or S.farmOP) then
    						Worlds.status = ""
    						return
    					end
    					if not info.next then
    						Worlds.status = "Every world unlocked"
    						return
    					end
    					if info.needs and not worldUnlocked(info.needs) then
    						Worlds.status = "Unlock " .. prettyWorld(info.needs) .. " first"
    					elseif not info.price then
    						Worlds.status = "Price unknown"
    					elseif not info.affordable then
    						Worlds.status = "Saving up"
    					else
    						Worlds.status = if Worlds.fails >= 2 then "Going to the portal" else "Buying"
    					end
    					if info.affordable and not Mover.busy and os.clock() - Worlds.lastBuy > 8 then
    						if Worlds.fails < 2 then
    							buyWorld(info, false)
    						elseif os.clock() - Worlds.padTry > 60 then
    							Worlds.padTry = os.clock()
    							Worlds.needPad = info
    						end
    					end
    				end)
    				if not ok then
    					diag("worlds", err)
    				end
    			end
    		end)
    
    		Auto.teleportTo = function(key)
    			if Mover.busy then
    				queueToast("Worlds", "Busy: " .. (if Mover.task ~= "" then Mover.task else "travelling"))
    				return
    			end
    			if not worldUnlocked(key) then
    				queueToast("Worlds", prettyWorld(key) .. " is locked")
    				return
    			end
    			Mover.busy = true
    			Mover.task = "Travelling to " .. prettyWorld(key)
    			task.spawn(function()
    				local ok, reached, err = pcall(travelTo, key)
    				if ok and reached then
    					queueToast("Worlds", "Welcome to " .. prettyWorld(key))
    				else
    					queueToast("Worlds", if ok then tostring(err) else shortError(reached))
    				end
    				Mover.busy = false
    				Mover.task = ""
    			end)
    		end
    
    		pcall(function()
    			Library:GiveSignal(LocalPlayer.FriendRequestEvent:Connect(function(from, to, event)
    				if not S.autoFriendAccept then return end
    				if to == LocalPlayer and from ~= LocalPlayer and event == Enum.FriendRequestEvent.Issue then
    					pcall(function() LocalPlayer:RequestFriendship(from) end)
    					queueToast("Friends", "Accepted " .. tostring(from.DisplayName or from.Name))
    				end
    			end))
    			Friends.acceptOk = true
    		end)
    
    		task.spawn(function()
    			while alive() do
    				task.wait(2)
    				pcall(function()
    					local now = os.clock()
    					if now - Friends.lastScan > 20 then
    						Friends.lastScan = now
    						local here, total = 0, 0
    						for _, player in ipairs(Players:GetPlayers()) do
    							if player ~= LocalPlayer then
    								total += 1
    								local ok, isFriend = pcall(function()
    									return LocalPlayer:IsFriendsWith(player.UserId)
    								end)
    								if ok and isFriend then
    									here += 1
    									Friends.sent[player.UserId] = true
    								end
    							end
    						end
    						Friends.here, Friends.total = here, total
    					end
    					if S.autoFriendSend then
    						for _, player in ipairs(Players:GetPlayers()) do
    							if player ~= LocalPlayer and not Friends.sent[player.UserId] then
    								Friends.sent[player.UserId] = true
    								local okFriend, already = pcall(function()
    									return LocalPlayer:IsFriendsWith(player.UserId)
    								end)
    								if not (okFriend and already) then
    									local ok = pcall(function()
    										LocalPlayer:RequestFriendship(player)
    									end)
    									if ok then
    										Friends.count += 1
    									end
    									task.wait(3)
    									break
    								end
    							end
    						end
    					end
    				end)
    			end
    		end)
    
    		local RarityInts = {}
    		for rarity, hex in pairs(RarityColors) do
    			local ok, color = pcall(Color3.fromHex, hex)
    			if ok then
    				RarityInts[rarity] = math.floor(color.R * 255) * 65536 + math.floor(color.G * 255) * 256 + math.floor(color.B * 255)
    			end
    		end
    
    		local function assetThumb(assetId)
    			if not assetId then return nil end
    			if Hook.thumbs[assetId] ~= nil then
    				return Hook.thumbs[assetId] or nil
    			end
    			local response = httpRequest({
    				Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. assetId .. "&returnPolicy=PlaceHolder&size=420x420&format=Png&isCircular=false",
    				Method = "GET",
    			})
    			local url = false
    			if response and response.Body then
    				pcall(function()
    					local decoded = game:GetService("HttpService"):JSONDecode(response.Body)
    					local entry = decoded and decoded.data and decoded.data[1]
    					if entry and type(entry.imageUrl) == "string" then
    						url = entry.imageUrl
    					end
    				end)
    			end
    			Hook.thumbs[assetId] = url
    			return url or nil
    		end
    
    		local function gameIcon()
    			if Hook.gameIcon ~= nil then
    				return Hook.gameIcon or nil
    			end
    			Hook.gameIcon = false
    			local response = httpRequest({
    				Url = "https://thumbnails.roblox.com/v1/games/icons?universeIds=" .. tostring(game.GameId) .. "&returnPolicy=PlaceHolder&size=150x150&format=Png&isCircular=false",
    				Method = "GET",
    			})
    			if response and response.Body then
    				pcall(function()
    					local decoded = game:GetService("HttpService"):JSONDecode(response.Body)
    					local entry = decoded and decoded.data and decoded.data[1]
    					if entry and type(entry.imageUrl) == "string" then
    						Hook.gameIcon = entry.imageUrl
    					end
    				end)
    			end
    			return Hook.gameIcon or nil
    		end
    
    		local function validWebhook(url)
    			return type(url) == "string" and (string.find(url, "^https://discord%.com/api/webhooks/") ~= nil or string.find(url, "^https://discordapp%.com/api/webhooks/") ~= nil or string.find(url, "^https://canary%.discord%.com/api/webhooks/") ~= nil or string.find(url, "^https://ptb%.discord%.com/api/webhooks/") ~= nil)
    		end
    
    		local function postWebhook(url, payload)
    			local body = game:GetService("HttpService"):JSONEncode(payload)
    			local response = httpRequest({
    				Url = url,
    				Method = "POST",
    				Headers = { ["Content-Type"] = "application/json" },
    				Body = body,
    			})
    			local code = response and tonumber(response.StatusCode) or 0
    			Hook.lastCode, Hook.lastAt = code, os.clock()
    			return code >= 200 and code < 300, code
    		end
    
    		local function hookName()
    			local name = string.gsub(string.gsub(tostring(S.webhookName or ""), "^%s+", ""), "%s+$", "")
    			local lower = string.lower(name)
    			if name == "" or string.find(lower, "discord", 1, true) or string.find(lower, "clyde", 1, true) then
    				return "Corvus"
    			end
    			return string.sub(name, 1, 80)
    		end
    		Auto.hookName = hookName
    
    		local function withPing(payload, ping)
    			local id = string.match(tostring(S.pingId or ""), "^%s*(%d+)%s*$")
    			if ping and id and #id >= 15 then
    				payload.content = "<@" .. id .. ">"
    				payload.allowed_mentions = { users = { id } }
    			else
    				payload.allowed_mentions = { parse = {} }
    			end
    			return payload
    		end
    		Auto.withPing = withPing
    
    		local function petAssetId(name)
    			local icon = petIcon(name)
    			return icon and string.match(icon, "%d+") or nil
    		end
    
    		local function hatchEmbed(entry)
    			local chanceText = "?"
    			local catalog = petCatalog()
    			local info = catalog and catalog[entry.name]
    			local percent = info and entry.egg and info.eggs[entry.egg]
    			if percent then
    				chanceText = formatChance(percent)
    			end
    			local fields = {
    				{ name = "Rarity", value = entry.rarity, inline = true },
    				{ name = "Chance", value = chanceText, inline = true },
    				{ name = "Egg", value = entry.egg or "Unknown", inline = true },
    				{ name = "Eggs opened", value = formatNumber(Saved.eggs), inline = true },
    				{ name = "Session", value = Library:FormatDuration(os.clock() - Session.started), inline = true },
    				{ name = "Player", value = if S.webhookHideName then "Hidden" else "||" .. LocalPlayer.Name .. "||", inline = true },
    			}
    			local mutationLabel = if entry.mutation then (Auto.mutationInfo(entry.mutation)) or entry.mutation else nil
    			if mutationLabel then
    				table.insert(fields, 2, { name = "Mutation", value = mutationLabel, inline = true })
    			end
    			local thumb = assetThumb(petAssetId(entry.name))
    			return {
    				title = "\u{2726}  " .. (if mutationLabel then mutationLabel .. " " else "") .. entry.rarity .. " hatch",
    				description = "**" .. entry.name .. "** just joined your team.",
    				color = RarityInts[entry.rarity] or 14146792,
    				thumbnail = if thumb then { url = thumb } else nil,
    				fields = fields,
    				author = { name = "Pets Universe", icon_url = gameIcon() },
    				footer = { text = "Corvus  \u{00B7}  made by Cinek" },
    				timestamp = DateTime.now():ToIsoDate(),
    			}
    		end
    
    		Auto.onHatch = function(name, rarity, mutation)
    			if not (S.webhookOn and S.webhookHatches and validWebhook(S.webhookUrl)) then return end
    			local picked = S.webhookPets[name] == true
    			if not (S.webhookRarity[rarity] or picked or (mutation and S.webhookMutated)) then return end
    			local egg = if S.indexHunt and Hunter.egg then Hunter.egg else S.hatchEggName
    			if not picked and not (mutation and S.webhookMutated) and (S.webhookMinOneIn or 0) > 0 then
    				local catalog = petCatalog()
    				local info = catalog and catalog[name]
    				local percent = info and egg and info.eggs[egg]
    				if percent and percent > 0 and 100 / percent < S.webhookMinOneIn then return end
    			end
    			if #Hook.queue >= 40 then return end
    			local ping = (S.pingFor.Secret and rarity == "Secret") or (S.pingFor.Mythical and (RarityRank[rarity] or 0) >= (RarityRank.Mythical or 5)) or (S.pingFor.Picked and picked) or (S.pingFor.Mutated and mutation ~= nil)
    			table.insert(Hook.queue, { name = name, rarity = rarity, mutation = mutation, egg = egg, ping = ping == true })
    		end
    
    		Auto.sendTestWebhook = function()
    			if not validWebhook(S.webhookUrl) then
    				queueToast("Webhook", "Paste a Discord webhook URL first")
    				return
    			end
    			task.spawn(function()
    				local sample = { name = "Cat", rarity = "Mythical", egg = "Basic Egg" }
    				local catalog = petCatalog()
    				if catalog then
    					for name, info in pairs(catalog) do
    						if RarityRank[info.rarity] and RarityRank[info.rarity] >= 4 then
    							local egg = next(info.eggs)
    							sample = { name = name, rarity = info.rarity, egg = egg }
    							break
    						end
    					end
    				end
    				local embed = hatchEmbed(sample)
    				embed.title = "\u{2726}  Test message"
    				embed.description = "Corvus is connected. This is how a **" .. sample.rarity .. "** hatch will look."
    				local ok, code = postWebhook(S.webhookUrl, withPing({ username = hookName(), embeds = { embed } }, true))
    				queueToast("Webhook", if ok then "Test message sent" else "Discord refused it (" .. tostring(code) .. ")")
    			end)
    		end
    
    		task.spawn(function()
    			while alive() do
    				task.wait(2)
    				if #Hook.queue > 0 and S.webhookOn and validWebhook(S.webhookUrl) and os.clock() - Hook.lastSend > 2.5 then
    					local batch = {}
    					while #Hook.queue > 0 and #batch < 10 do
    						table.insert(batch, table.remove(Hook.queue, 1))
    					end
    					local ok, err = pcall(function()
    						local embeds = {}
    						local ping = false
    						for _, entry in ipairs(batch) do
    							ping = ping or entry.ping == true
    							if entry.embed then
    								entry.embed.author = { name = "Pets Universe", icon_url = gameIcon() }
    								table.insert(embeds, entry.embed)
    							else
    								table.insert(embeds, hatchEmbed(entry))
    							end
    						end
    						local sent = postWebhook(S.webhookUrl, withPing({ username = hookName(), embeds = embeds }, ping))
    						Hook.lastSend = os.clock()
    						if sent then
    							Hook.sent += #batch
    							Saved.webhooksSent += #batch
    							SaveDirty = true
    						end
    					end)
    					if not ok then
    						diag("webhook", err)
    					end
    				end
    			end
    		end)
    
    		Auto.sendFeedback = function()
    			local url = CorvusConfig.FeedbackWebhook
    			if not validWebhook(url) then
    				notify("Feedback", "Feedback is not set up in this build yet", 4)
    				return
    			end
    			if Auto.lastFeedback and os.clock() - Auto.lastFeedback < 90 then
    				notify("Feedback", "Please wait " .. math.ceil(90 - (os.clock() - Auto.lastFeedback)) .. "s before sending again", 4)
    				return
    			end
    			local since = os.time() - (tonumber(Saved.feedbackAt) or 0)
    			if since >= 0 and since < 90 then
    				notify("Feedback", "Please wait " .. (90 - since) .. "s before sending again", 4)
    				return
    			end
    			local today = os.date("!%Y-%m-%d")
    			if Saved.feedbackDay ~= today then
    				Saved.feedbackDay = today
    				Saved.feedbackCount = 0
    			end
    			if (tonumber(Saved.feedbackCount) or 0) >= 6 then
    				notify("Feedback", "You sent 6 messages today, thanks! Try again tomorrow or use our Discord", 5)
    				return
    			end
    			local text = tostring(Options.FeedbackText and Options.FeedbackText.Value or "")
    			text = string.gsub(text, "^%s+", "")
    			text = string.gsub(text, "%s+$", "")
    			if #text < 8 then
    				notify("Feedback", "Write at least a few words", 4)
    				return
    			end
    			if #text > 1000 then
    				text = string.sub(text, 1, 1000)
    			end
    			text = string.gsub(text, "@", "@\u{200B}")
    			local kind = tostring(Options.FeedbackType and Options.FeedbackType.Value or "Other")
    			local anonymous = Toggles.FeedbackAnon and Toggles.FeedbackAnon.Value == true
    			Auto.lastFeedback = os.clock()
    			Saved.feedbackAt = os.time()
    			Saved.feedbackCount = (tonumber(Saved.feedbackCount) or 0) + 1
    			SaveDirty = true
    			pcall(Options.FeedbackText.SetValue, Options.FeedbackText, "")
    			notify("Feedback", "Sending...", 2)
    			task.spawn(function()
    				local executor = "Unknown"
    				pcall(function()
    					if type(identifyexecutor) == "function" then
    						executor = table.concat({ identifyexecutor() }, " ")
    					end
    				end)
    				pcall(Library.PostFeedback, kind, text, anonymous, executor)
    				local kindColors = { Idea = 7995310, Bug = 16739978, Question = 6275327, Other = 14146792 }
    				local ok = postWebhook(url, {
    					username = "Corvus Feedback",
    					allowed_mentions = { parse = {} },
    					embeds = {
    						{
    							title = "\u{2726}  " .. kind .. "  \u{00B7}  Pets Universe",
    							description = text,
    							color = kindColors[kind] or 14146792,
    							fields = {
    								{ name = "From", value = if anonymous then "Anonymous" else string.format("%s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name), inline = true },
    								{ name = "Game", value = "[Pets Universe](https://www.roblox.com/games/" .. tostring(game.PlaceId) .. ")", inline = true },
    								{ name = "Executor", value = executor, inline = true },
    								{ name = "Hub", value = "Corvus " .. tostring(CorvusConfig.HubVersion), inline = true },
    							},
    							author = { name = "Pets Universe", url = "https://www.roblox.com/games/" .. tostring(game.PlaceId), icon_url = gameIcon() },
    							footer = { text = "Corvus feedback  \u{00B7}  Pets Universe" },
    							timestamp = DateTime.now():ToIsoDate(),
    						},
    					},
    				})
    				queueToast("Feedback", if ok then "Thanks! Cinek got your message." else "Could not send, try again later")
    			end)
    		end
    
    		local function teamSnapshot()
    			local pets = getDataFolder("PetsData")
    			local multi = petsMulti()
    			local list, power, count = {}, 0, 0
    			if pets then
    				for _, folderName in ipairs({ "DiamondPetsData", "GoldenPetsData", "NormalPetsData" }) do
    					local folder = pets:FindFirstChild(folderName)
    					if folder then
    						for _, entry in ipairs(folder:GetChildren()) do
    							local eq = entry:FindFirstChild("Equipped")
    							local amount = entry:FindFirstChild("Amount")
    							local okE, e = pcall(function() return eq and eq.Value end)
    							local okA, a = pcall(function() return amount and amount.Value end)
    							local rawEq = if okE then e else nil
    							local eqCount = if type(rawEq) == "boolean" then (if rawEq then 1 else 0) else tonumber(rawEq) or 0
    							local equipped = math.min(eqCount, tonumber(okA and a or nil) or eqCount)
    							if equipped > 0 then
    								local info = nil
    								if type(multi) == "table" then
    									pcall(function() info = multi[entry.Name] end)
    								end
    								local each = 0
    								if type(info) == "table" then
    									if info[1] == false or info[1] == nil then
    										each = tonumber(info[2]) or 0
    									else
    										local okBest, best = pcall(function() return multi.GetBestFlatPetDamage(LocalPlayer) end)
    										each = (tonumber(info[2]) or 0) / 100 * (if okBest then tonumber(best) or 0 else 0)
    									end
    								end
    								table.insert(list, {
    									name = entry.Name,
    									count = equipped,
    									power = each * equipped,
    									rarity = if type(info) == "table" then tostring(info[3] or "Basic") else "Basic",
    									icon = if type(info) == "table" and type(info[4]) == "string" then info[4] else nil,
    								})
    								power += each * equipped
    								count += equipped
    							end
    						end
    					end
    				end
    			end
    			table.sort(list, function(a, b) return a.power > b.power end)
    			return { list = list, power = power, count = count }
    		end
    
    		local Extra = {}
    		local function setupExtras()
    			local Tree = { status = "Off", result = nil, blocked = {}, doneToast = false, last = nil }
    			local Special = { status = "Off", lastTry = -1e9, blocked = {}, doneToast = false }
    			local Rebirth = { status = "Off", lastTry = -1e9, needsTravel = nil, fails = 0, blockedUntil = -1e9 }
    			local Codes = { status = "Off", found = {}, order = {}, manual = {}, nextTry = {}, lastScan = -1e9, lastFetch = -1e9, lastHub = -1e9, result = nil, last = nil }
    
    			local function spendable(currency)
    				local balance = getStat(currency) or 0
    				local reserve = Auto.reserve(currency)
    				return balance - (tonumber(reserve) or 0), balance
    			end
    			Extra.spendable = spendable
    
    			local function postEvent(kind, title, description, color, ping)
    				if not (S.webhookOn and S.webhookEventsOn and validWebhook(S.webhookUrl) and S.hookEvents[kind]) then return end
    				if #Hook.queue >= 40 then return end
    				if ping == nil then
    					ping = S.pingFor[kind] == true
    				end
    				table.insert(Hook.queue, {
    					ping = ping == true,
    					embed = {
    						title = "\u{2726}  " .. title,
    						description = description,
    						color = color or 14146792,
    						fields = {
    							{ name = "Player", value = if S.webhookHideName then "Hidden" else "||" .. LocalPlayer.Name .. "||", inline = true },
    							{ name = "Session", value = Library:FormatDuration(os.clock() - Session.started), inline = true },
    						},
    						footer = { text = "Corvus  \u{00B7}  made by Cinek" },
    						timestamp = DateTime.now():ToIsoDate(),
    					},
    				})
    			end
    			Auto.postEvent = postEvent
    
    			local function flag(name)
    				if type(name) ~= "string" or name == "" then return false end
    				return readData("SPdata", name) == true
    			end
    
    			local function machineAnchor(name)
    				local machine, touch = getMachine(name)
    				if touch then return touch end
    				if not machine then return nil end
    				if machine:IsA("BasePart") then return machine end
    				if machine.PrimaryPart then return machine.PrimaryPart end
    				for _, child in ipairs(machine:GetDescendants()) do
    					if child:IsA("BasePart") then return child end
    				end
    				return nil
    			end
    
    			local function treeOwned(folder, id)
    				local node = folder and folder:FindFirstChild(id)
    				if not node then return false end
    				local ok, value = pcall(function() return node.Value end)
    				return ok and value == true
    			end
    
    			local function treeInfo()
    				local tree = Auto.GameData.tree
    				local info = { available = tree ~= nil, owned = 0, total = 0, unlocked = false, anyPicked = false, allDone = true }
    				if not tree then return info end
    				local folder = getDataFolder(Auto.GameData.treeFolder or "TreeData")
    				info.unlocked = flag(Auto.GameData.treeFlag or "SP13")
    				local levels = {}
    				for _, group in ipairs(tree.Groups) do
    					local level = 0
    					if not group.parent then
    						level = #group.levels
    					else
    						for _, node in ipairs(group.levels) do
    							if not treeOwned(folder, node.id) then break end
    							level += 1
    						end
    					end
    					levels[group.id] = level
    				end
    				local spend, balance = spendable("Rubies")
    				info.balance = balance
    				local best, bestCost, bestIndex
    				local now = os.clock()
    				local plan = Auto.Plan
    				local planOn = plan ~= nil and plan.ready and (S.farmOP or S.treeOrder == "Best value")
    				local bestValue = -math.huge
    				for index, group in ipairs(tree.Groups) do
    					if group.parent then
    						local level = levels[group.id] or 0
    						local maxLevel = #group.levels
    						info.owned += level
    						info.total += maxLevel
    						if S.treePick[group.id] then
    							info.anyPicked = true
    							if level < maxLevel then
    								info.allDone = false
    								local parent = tree.GroupById and tree.GroupById[group.parent]
    								local parentDone = parent == nil or (levels[parent.id] or 0) >= (tonumber(group.parentLevel) or #parent.levels)
    								local node = group.levels[level + 1]
    								if group.requires ~= nil and not flag(group.requires) then
    									info.needsFlag = info.needsFlag or group.requires
    								elseif (parentDone or level > 0) and node and (Tree.blocked[group.id] or 0) < now then
    									local cost = tonumber(node.cost) or 0
    									local better
    									if planOn then
    										local value = plan.score("tree:" .. group.id)
    										better = best == nil or value > bestValue
    										if better then
    											bestValue = value
    										end
    									elseif S.treeOrder == "Tree order" then
    										better = best == nil or index < bestIndex
    									else
    										better = best == nil or cost < bestCost
    									end
    									if better then
    										best, bestCost, bestIndex = { group = group, node = node, level = level }, cost, index
    									end
    								end
    							end
    						end
    					end
    				end
    				if best then
    					info.next = best
    					info.cost = bestCost
    					info.title = tostring(best.node.title or best.group.title or best.node.id)
    					info.image = best.node.image or best.group.image
    					info.affordable = spend >= bestCost and (not planOn or plan.allows("tree:" .. best.group.id, bestCost, best.node.id))
    				end
    				return info
    			end
    
    			local function specialModel(name)
    				local map = workspace:FindFirstChild("Map")
    				local folder = map and map:FindFirstChild("SpecialUpgrades")
    				return folder and folder:FindFirstChild(name)
    			end
    
    			local function specialAnchor(model)
    				if not model then return nil end
    				local circle = model:FindFirstChild("EffectCircle")
    				if circle and circle:IsA("BasePart") then return circle end
    				for _, child in ipairs(model:GetDescendants()) do
    					if child:IsA("BasePart") then return child end
    				end
    				return nil
    			end
    
    			local function specialInfo()
    				local list = Auto.GameData.special or {}
    				local info = { rows = {}, owned = 0, total = #list, anyPicked = false, allDone = true }
    				local spend, balance = spendable("Rubies")
    				info.balance = balance
    				local now = os.clock()
    				for _, entry in ipairs(list) do
    					local anchor = specialAnchor(specialModel(entry.name))
    					local world
    					if anchor then
    						local ok, found = pcall(getWorldAt, anchor.Position)
    						world = if ok then found else nil
    					end
    					if not world then
    						local mapped = Auto.GameData.specialWorlds and Auto.GameData.specialWorlds[entry.name]
    						world = if mapped then Auto.worldKey(mapped) else nil
    					end
    					local row = {
    						name = entry.name,
    						title = entry.title,
    						price = entry.price,
    						owned = flag("SP" .. entry.index),
    						world = world,
    						picked = S.specialPick[entry.name] == true,
    						anchor = anchor,
    					}
    					row.locked = world ~= nil and not worldUnlocked(world)
    					table.insert(info.rows, row)
    					if row.owned then
    						info.owned += 1
    					elseif row.picked then
    						info.anyPicked = true
    						info.allDone = false
    						if row.locked then
    							info.anyLocked = true
    						elseif anchor and (Special.blocked[entry.name] or 0) < now and (info.next == nil or entry.price < info.next.price) and not (Auto.Plan and Auto.Plan.on() and (S.farmOP or S.upgradeOrder == "Best value") and not Auto.Plan.allows("special:" .. entry.name, entry.price)) then
    							info.next = row
    						end
    					end
    					if row.picked then
    						info.anyPicked = true
    					end
    				end
    				info.affordable = info.next ~= nil and spend >= info.next.price
    				return info
    			end
    
    			local function specialTrip(row)
    				Special.lastTry = os.clock()
    				local remote = Auto.knitRemote("SpecialUpgradesService", "RE", "BuySpecialUpgrade")
    				if not remote then
    					Special.blocked[row.name] = os.clock() + 300
    					return
    				end
    				if row.world then
    					local ok = travelTo(row.world)
    					if not ok then
    						Special.blocked[row.name] = os.clock() + 120
    						return
    					end
    				end
    				local anchor = specialAnchor(specialModel(row.name))
    				if anchor then
    					Mover.task = "Buying " .. row.title
    					pcall(standAt, anchor, 3)
    					task.wait(0.5)
    				end
    				local index = string.match(row.name, "%d+")
    				pcall(function() remote:FireServer(row.name) end)
    				local waited = 0
    				while waited < 4 and not flag("SP" .. tostring(index)) do
    					waited += task.wait(0.15) or 0.15
    				end
    				if flag("SP" .. tostring(index)) then
    					Saved.specialBought += 1
    					SaveDirty = true
    					Auto.log("BUY", "special", row.name, row.title, "for", row.price, "rubies")
    					queueToast("Special Upgrades", "Unlocked " .. row.title)
    					postEvent("Special", "Special upgrade", "**" .. row.title .. "** unlocked", 12759680)
    				else
    					Special.blocked[row.name] = os.clock() + 120
    				end
    			end
    
    			local function rebirthInfo()
    				local config = Auto.GameData.moonConfig
    				local info = { available = type(config) == "table" and type(config.GetRebirthProgress) == "function", rebirths = 0, owned = 0, cap = 0, progress = 0 }
    				if not info.available then return info end
    				local ok, owned, cap, progress, ready = pcall(config.GetRebirthProgress, LocalPlayer)
    				if ok then
    					info.owned = tonumber(owned) or 0
    					info.cap = tonumber(cap) or 0
    					info.progress = tonumber(progress) or 0
    					info.ready = ready == true
    				end
    				info.rebirths = tonumber(readData(config.REBIRTH_DATA_FOLDER or "MoonRebirthData", "Rebirths")) or 0
    				info.nextNumber = info.rebirths + 1
    				if type(config.GetNextRebirthNumber) == "function" then
    					local okNext, nextNumber = pcall(config.GetNextRebirthNumber, LocalPlayer)
    					if okNext then
    						info.nextNumber = tonumber(nextNumber)
    					end
    				end
    				info.stopped = (S.rebirthStopAt or 0) > 0 and info.rebirths >= S.rebirthStopAt
    				info.moonUnlocked = worldUnlocked(moonWorld())
    				return info
    			end
    
    			local function rebirthTrip(travel)
    				Rebirth.lastTry = os.clock()
    				local remote = Auto.knitRemote("MoonRebirthService", "RE", "DoRebirth")
    				if not remote then return false end
    				local before = rebirthInfo().rebirths
    				local gemsBefore = getStat("Gems")
    				if travel then
    					local ok = travelTo(moonWorld())
    					if not ok then return false end
    					local touch = machineAnchor("RebirthMoon")
    					if touch then
    						Mover.task = "Moon rebirth"
    						pcall(standAt, touch, 4)
    						task.wait(0.5)
    					end
    				end
    				pcall(function() remote:FireServer() end)
    				local waited = 0
    				while waited < 5 and rebirthInfo().rebirths <= before do
    					waited += task.wait(0.2) or 0.2
    				end
    				local after = rebirthInfo().rebirths
    				Auto.log("REBIRTH", if after > before then "done" else "failed", before, "->", after, "gems", gemsBefore, "->", getStat("Gems"), "damage level", readData("MoonUpgradesData", "Damage"))
    				if after > before then
    					Saved.rebirthsDone += 1
    					SaveDirty = true
    					queueToast("Moon Rebirth", "Rebirth " .. after .. " done")
    					Auto.Metrics.event("Rebirth", "Moon rebirth " .. after, "#b692ff")
    					postEvent("Rebirth", "Moon rebirth", "Reached **rebirth " .. after .. "**", 11962107)
    					return true
    				end
    				return false
    			end
    
    			do
    				-- Profit engine v2: every spend and time option on one dV/C scale (CLAUDE.md.txt 8.00, notes.md)
    				local P = { ready = false, H = 86400, w = { Coins = 1, Rubies = 0, Gems = 0 }, byId = {}, best = {}, keep = { Coins = 0, Rubies = 0, Gems = 0 }, egg = nil, eggWhy = "", fishOff = false, act = {}, last = nil, lastLog = {}, rebirthNow = false, rebirthPath = false, moonTry = -1e9, I = { Coins = 0, Rubies = 0, Gems = 0 }, Ib = { Coins = 0, Rubies = 0, Gems = 0 }, evt = { Luck = 1, Coins = 1, Rubies = 1, Gems = 1, HatchSpeed = 1, EggOpen = 0, active = {} }, frozen = nil }
    				Auto.Plan = P
    				local plMods = {}
    				local plLog = function(...)
    					if Auto.log then
    						Auto.log(...)
    					end
    				end
    
    				local function plReq(key, parentName, childName)
    					if plMods[key] then
    						return plMods[key]
    					end
    					pcall(function()
    						local parent = ReplicatedStorage:FindFirstChild(parentName)
    						local child = parent and parent:FindFirstChild(childName)
    						if child then
    							local value = require(child)
    							if type(value) == "table" then
    								plMods[key] = value
    							end
    						end
    					end)
    					return plMods[key]
    				end
    
    				local function plNum(value, default)
    					value = tonumber(value)
    					if value == nil or value ~= value or value == math.huge or value == -math.huge then
    						return default
    					end
    					return value
    				end
    
    				local function plCall(module, fname, ...)
    					if type(module) ~= "table" or type(module[fname]) ~= "function" then
    						return nil
    					end
    					local ok, result = pcall(module[fname], ...)
    					if ok then
    						return result
    					end
    					return nil
    				end
    
    				local function plRate(key)
    					local metrics = Auto.Metrics
    					if not (metrics and metrics.current) then
    						return 0
    					end
    					local ok, value = pcall(metrics.current, key)
    					return math.max(0, plNum(if ok then value else nil, 0)) / 3600
    				end
    
    				local function plPower(multi, petName)
    					local entry = multi and multi[petName]
    					if type(entry) ~= "table" or entry[1] then
    						return 0
    					end
    					return plNum(entry[2], 0)
    				end
    
    				local function plBoostAt(list, lvl, base)
    					if lvl <= 0 or type(list) ~= "table" then
    						return base
    					end
    					local entry = list[lvl]
    					return if type(entry) == "table" then plNum(entry.Boost, base) else base
    				end
    
    				-- expected team power gain per hatched egg (real egg odds with the player's luck)
    				local function plEggGain(egg, luck, goldPct)
    					local handler = plReq("egg", "NormalEggs", "EggHandlerModule")
    					local multi = plReq("multi", "Pets", "Multi")
    					local list = handler and handler[egg]
    					if type(list) ~= "table" or not multi then
    						return nil
    					end
    					local chances = nil
    					if type(handler.GetNormalizedChances) == "function" then
    						local ok, result = pcall(handler.GetNormalizedChances, handler, list, luck, P.secretLuck or 1, P.charmSecret or 0)
    						if ok and type(result) == "table" then
    							chances = result
    						end
    					end
    					chances = chances or list
    					local total = 0
    					for _, entry in ipairs(chances) do
    						if type(entry) == "table" then
    							total += math.max(0, plNum(entry.Chance, 0))
    						end
    					end
    					if total <= 0 then
    						return nil
    					end
    					local golden = math.clamp((goldPct or 0) / 100, 0, 1)
    					local weakest = P.team.weakest
    					local gain = 0
    					for _, entry in ipairs(chances) do
    						if type(entry) == "table" and type(entry.Name) == "string" then
    							local share = math.max(0, plNum(entry.Chance, 0)) / total
    							local normal = math.max(0, plPower(multi, entry.Name) - weakest)
    							local gold = math.max(0, plPower(multi, "Golden " .. entry.Name) - weakest)
    							gain += share * ((1 - golden) * normal + golden * gold)
    						end
    					end
    					return gain
    				end
    
    				-- coins (and rubies) paid per point of damage in a world, from BreakablesConfig tiers
    				local function plWorldEff(world)
    					local cfg = plReq("brk", "Modules", "BreakablesConfig")
    					local worlds = cfg and cfg.Worlds
    					if type(worlds) ~= "table" or not world then
    						return nil
    					end
    					local entry = worlds[world]
    					if not entry then
    						for key, value in pairs(worlds) do
    							if Auto.worldKey(key) == world then
    								entry = value
    								break
    							end
    						end
    					end
    					local tiers = type(entry) == "table" and entry.Tiers
    					if type(tiers) ~= "table" then
    						return nil
    					end
    					local hp, pay = 0, {}
    					for _, tier in pairs(tiers) do
    						if type(tier) == "table" and type(tier.Currency) == "string" and tier.Group ~= "Fruits" then
    							local weight = plNum(tier.HP, 0) * plNum(tier.SpawnChance, 0)
    							hp += weight
    							pay[tier.Currency] = (pay[tier.Currency] or 0) + weight * plNum(tier.Multiplier, 0)
    						end
    					end
    					if hp <= 0 then
    						return nil
    					end
    					for key, value in pairs(pay) do
    						pay[key] = value / hp
    					end
    					return pay
    				end
    
    				-- admin events (ReplicatedStorage.AdminEventsState): <Kind> = end time, <Kind>Value = multiplier/bonus
    				local plKinds = { "Luck", "HatchSpeed", "Coins", "EggOpen", "Rubies", "Gems", "FreeEggs", "RubyRush", "FishingLuck", "FishingSpeed", "TapPower", "WeatherSunny", "WeatherRainy", "WeatherStorm", "WeatherRainbow", "WeatherBloodMoon", "WeatherAlienInvasion", "WeatherGolden", "WeatherSunrise", "WeatherSunset" }
    				local plEvtWas = {}
    				local function plEvents()
    					local evt = { Luck = 1, Coins = 1, Rubies = 1, Gems = 1, HatchSpeed = 1, EggOpen = 0, active = {}, fishBoost = false }
    					local folder = ReplicatedStorage:FindFirstChild("AdminEventsState")
    					if not folder then
    						return evt
    					end
    					local okNow, now = pcall(workspace.GetServerTimeNow, workspace)
    					now = if okNow and type(now) == "number" and now > 0 then now else os.time()
    					for _, kind in ipairs(plKinds) do
    						local stamp = folder:FindFirstChild(kind)
    						local valueObj = folder:FindFirstChild(kind .. "Value")
    						local okS, ends = pcall(function() return stamp and stamp.Value end)
    						local left = math.max(0, math.floor(plNum(okS and ends or nil, 0) - now))
    						if left > 0 then
    							local okV, value = pcall(function() return valueObj and valueObj.Value end)
    							value = plNum(okV and value or nil, 1)
    							evt.active[kind] = left
    							if kind == "Luck" or kind == "Coins" or kind == "Rubies" or kind == "Gems" or kind == "HatchSpeed" then
    								evt[kind] = math.max(1, value)
    							elseif kind == "EggOpen" then
    								evt.EggOpen = math.max(0, value)
    							elseif kind == "FreeEggs" then
    								evt.FreeEggs = true
    							elseif kind == "RubyRush" then
    								evt.RubyRush = true
    							elseif kind == "WeatherSunny" then
    								evt.coinsBonus = (evt.coinsBonus or 0) + 0.25
    							elseif kind == "WeatherBloodMoon" then
    								evt.rubiesBonus = (evt.rubiesBonus or 0) + 0.5
    							elseif kind == "WeatherRainbow" then
    								evt.luckBonus = 0.25
    							elseif kind == "FishingLuck" or kind == "FishingSpeed" or kind == "WeatherGolden" or kind == "WeatherSunrise" or kind == "WeatherSunset" then
    								evt.fishBoost = true
    							end
    							if not plEvtWas[kind] then
    								plEvtWas[kind] = true
    								plLog("EVENT", kind, "value=" .. string.format("%.3g", value), "until=" .. left)
    							end
    						elseif plEvtWas[kind] then
    							plEvtWas[kind] = nil
    							plLog("EVENT", kind, "over")
    						end
    					end
    					return evt
    				end

    				-- dV in coin-equivalent per second for each kind of effect
    				local V = {}
    				function V.dmg(rel)
    					return P.V * rel
    				end
    				function V.coinAdd(delta)
    					return P.I.Coins * delta / P.Mc
    				end
    				function V.rubyAdd(delta)
    					return P.w.Rubies * P.I.Rubies * delta / P.Mr
    				end
    				function V.gemsMul(rel)
    					return P.w.Gems * P.Ib.Gems * rel
    				end
    				function V.gemsAdd(delta)
    					return P.w.Gems * P.Ib.Gems * delta / P.gemsAdd
    				end
    				function V.luck(delta)
    					local h = P.hatch
    					if not h or h.rate <= 0 or delta <= 0 then
    						return 0
    					end
    					local after = plEggGain(h.egg, P.luck + delta, P.gold) or h.gain
    					return h.rate * math.max(0, after - h.gain) / P.team.power * P.V
    				end
    				function V.golden(deltaPct)
    					local h = P.hatch
    					if not h or h.rate <= 0 then
    						return 0
    					end
    					local after = plEggGain(h.egg, P.luck, P.gold + deltaPct) or h.gain
    					return h.rate * math.max(0, after - h.gain) / P.team.power * P.V
    				end
    				function V.hatchSpeed(delta)
    					local h = P.hatch
    					if not h or not h.bound or h.rate <= 0 then
    						return 0
    					end
    					return h.rate * delta / P.hatchSpeed * h.gain / P.team.power * P.V
    				end
    				function V.eggOpen()
    					local h = P.hatch
    					if not h or not h.bound or h.rate <= 0 then
    						return 0
    					end
    					return h.rate / math.max(1, h.maxOpen) * h.gain / P.team.power * P.V
    				end
    				function V.equip()
    					return P.V * P.team.weakest / P.team.power
    				end
    				function V.crit(delta)
    					return P.V * delta * (P.critDmg - 1) / (1 + P.crit * (P.critDmg - 1))
    				end
    				function V.critDmg(rel)
    					return P.V * P.crit * P.critDmg * rel / (1 + P.crit * (P.critDmg - 1))
    				end
    				function V.tap(rel)
    					return P.V * (if S.autoTap then 0.05 else 0) * rel
    				end
    				function V.walk(rel)
    					return P.V * 0.1 * rel
    				end
    				function V.bonus(cur, extra)
    					if cur == "Coins" then
    						return P.Ib.Coins * extra
    					elseif cur == "Rubies" then
    						return P.w.Rubies * P.Ib.Rubies * extra
    					end
    					return P.w.Gems * P.Ib.Gems * extra
    				end
    
    				local plTreeValue = {
    					CoinsMult = function(v) return V.coinAdd(v) end,
    					WorldBoostAdd = function(v) return V.coinAdd(v) end,
    					RubiesMult = function(v) return V.rubyAdd(v) end,
    					GemsMult = function(v) return V.gemsAdd(v) end,
    					LuckMult = function(v) return V.luck(v) end,
    					HatchSpeedMult = function(v) return V.hatchSpeed(v) end,
    					PetDamageMult = function(v) return V.dmg(v / P.treeDmg) end,
    					AttackSpeedMult = function(v) return V.dmg(v / P.treeAtk) end,
    					CritChanceAdd = function(v) return V.crit(v) end,
    					CritDamageMult = function(v) return V.critDmg(v) end,
    					CoinBonusX2Chance = function(v) return V.bonus("Coins", v) end,
    					CoinBonusX3Chance = function(v) return V.bonus("Coins", 2 * v) end,
    					RubyBonusX2Chance = function(v) return V.bonus("Rubies", v) end,
    					RubyBonusX3Chance = function(v) return V.bonus("Rubies", 2 * v) end,
    					GemBonusX2Chance = function(v) return V.bonus("Gems", v) end,
    					GoldenPetChanceAdd = function(v) return V.golden(v) end,
    					MaxEggOpenAdd = function() return V.eggOpen() end,
    					MaxEquipAdd = function() return V.equip() end,
    					TapPowerMult = function(v) return V.tap(v) end,
    					BreakableDamageMult = function(v) return V.tap(v) end,
    					PetSpeedMult = function(v) return V.walk(v) end,
    				}
    
    				local function plSpawnBoost(track, lvl)
    					local folder = ReplicatedStorage:FindFirstChild("UpgradesModule")
    					if not folder then
    						return nil
    					end
    					for _, child in ipairs(folder:GetChildren()) do
    						if child.Name ~= "UpgradesModule" then
    							local module = plReq("up:" .. child.Name, "UpgradesModule", child.Name)
    							local list = module and module[track]
    							if type(list) == "table" then
    								local entry = list[lvl]
    								return if type(entry) == "table" then plNum(entry.Boost, nil) else nil
    							end
    						end
    					end
    					return nil
    				end
    
    				local function plSpawnValue(track, lvl)
    					local now, nxt = plSpawnBoost(track, lvl), plSpawnBoost(track, lvl + 1)
    					if not (now and nxt) then
    						return 0
    					end
    					if track == "CoinsUpgrades" then
    						return V.coinAdd(math.max(0, math.min(nxt, 3) - math.min(now, 3)))
    					elseif track == "RubiesUpgrades" then
    						return V.rubyAdd(math.max(0, math.min(nxt, 3) - math.min(now, 3)))
    					elseif track == "LuckUpgrades" then
    						return V.luck(math.max(0, math.min(nxt, 2) - math.min(now, 2)))
    					elseif track == "HatchSpeedUpgrades" then
    						return V.hatchSpeed(nxt - now)
    					elseif track == "CriticalUpgrades" then
    						return V.crit(0.01 * (nxt - now))
    					elseif track == "PetSpeedUpgrades" then
    						return V.walk((nxt - now) / math.max(now, 1))
    					end
    					return 0
    				end
    
    				local plMoonKind = {
    					Incremental = {
    						Damage = function(b, n) return V.dmg(n / b - 1) end,
    						PetAttackSpeed = function(b, n) return V.dmg(n / b - 1) end,
    						MoreGems = function(b, n) return V.gemsAdd(n - b) end,
    						TapPower = function(b, n) return V.tap(n / b - 1) end,
    						CritDmg = function(b, n) return V.critDmg(n / b - 1) end,
    					},
    					Permanent = {
    						CoinMultiplier = function(b, n) return V.coinAdd(n - b) end,
    						RubiesMultiplier = function(b, n) return V.rubyAdd(n - b) end,
    						GemsMultiplier = function(b, n) return V.gemsMul(n / b - 1) end,
    						LuckMultiplier = function(b, n) return V.luck(n - b) end,
    						HatchSpeedMultiplier = function(b, n) return V.hatchSpeed(n - b) end,
    						CritChance = function(b, n) return V.crit(n - b) end,
    						EggHatch = function() return V.eggOpen() end,
    						PetEquip = function() return V.equip() end,
    					},
    				}
    
    				local function plSpecialValue(title)
    					title = string.lower(tostring(title or ""))
    					if string.find(title, "pet equip", 1, true) then
    						return V.equip(), false
    					elseif string.find(title, "egg open", 1, true) then
    						return V.eggOpen(), false
    					elseif string.find(title, "hatch speed", 1, true) then
    						return V.hatchSpeed(0.1), false
    					elseif string.find(title, "crit chance", 1, true) then
    						return V.crit(0.001), false
    					elseif string.find(title, "golden chance", 1, true) then
    						return V.golden(0.2), false
    					end
    					return 0, true
    				end
    
    				local function plAdd(list, option)
    					if option.cost and option.cost > 0 then
    						option.dV = math.max(0, option.dV or 0)
    						option.ratio = option.dV / option.cost
    						table.insert(list, option)
    					end
    				end
    
    				local function plReserve(cur)
    					if cur == "Rubies" then
    						return Auto.reserve("Rubies")
    					elseif cur == "Gems" then
    						return Auto.reserve("Gems")
    					end
    					return 0
    				end
    
    				-- every money option of the account, one list
    				local function plOptions()
    					local list = {}
    					-- eggs (coins): expected power gain per egg, minus the farm income lost while standing at the egg
    					local pets = loadEggPets() or {}
    					local bestEff = P.farmEff or 0
    					for egg in pairs(pets) do
    						local price, free = getEggPrice(egg)
    						local event = Auto.eggEvent(egg)
    						local world = Auto.eggWorld(egg)
    						if price and (Auto.eggCurrency(egg) == "Coins" or free) and not (event and (event.ended or event.locked)) and worldUnlocked(world) then
    							local gain = plEggGain(egg, P.luck, P.gold) or 0
    							local perEgg = gain / P.team.power * P.V
    							local eff = plWorldEff(world)
    							local lost = if bestEff > 0 and eff and eff.Coins then math.max(0, 1 - eff.Coins / bestEff) else 0
    							local timeCost = lost * P.V * P.eggSeconds
    							local cost = (if free then 0 else price) + timeCost
    							plAdd(list, { id = "egg:" .. egg, cur = "Coins", kind = "Egg", name = egg, cost = math.max(cost, 1), price = if free then 0 else price, dV = perEgg, perEgg = perEgg, gain = gain })
    						end
    					end
    					-- next world (coins): pay per damage of the new world vs the best one now
    					local info = worldInfo()
    					if info.next and info.price and info.currency == "Coins" then
    						local eff = plWorldEff(info.next)
    						local rel = if eff and eff.Coins and bestEff > 0 then eff.Coins / bestEff - 1 else 0
    						local rubyRel = if eff and eff.Rubies and (P.farmRubyEff or 0) > 0 then eff.Rubies / P.farmRubyEff - 1 else 0
    						plAdd(list, { id = "world:" .. info.next, cur = "Coins", kind = "World", name = info.next, cost = info.price, dV = P.Ib.Coins * math.max(0, rel) + P.w.Rubies * P.Ib.Rubies * math.max(0, rubyRel) })
    					end
    					-- Moon world (rubies): progress, bought when affordable
    					local cost = Auto.GameData.worldCost
    					if cost and cost.MoonWorld and tonumber(cost.MoonRubiesCost) then
    						local moon = Auto.worldKey(cost.MoonWorld)
    						local needs = cost.MoonRequires and Auto.worldKey(cost.MoonRequires) or nil
    						if not worldUnlocked(moon) and (not needs or worldUnlocked(needs)) then
    							plAdd(list, { id = "moonworld", cur = "Rubies", kind = "World", name = moon, from = needs, cost = tonumber(cost.MoonRubiesCost), dV = 0, progress = true })
    						end
    					end
    					-- spawn machine (rubies)
    					local spawn = Auto.GameData.spawnUpgrades
    					if spawn and (S.autoSpawnUp or S.farmOP) then
    						for _, track in ipairs(UI.SpawnUpgradeNames or {}) do
    							if S.spawnPick[track] then
    								local lvl = readLevel("UpgradesData", track)
    								local maxLevel = tonumber(spawn.MaxLevels and spawn.MaxLevels[track]) or 0
    								local entry = type(spawn[track]) == "table" and spawn[track][lvl + 1] or nil
    								if lvl < maxLevel and type(entry) == "table" then
    									plAdd(list, { id = "shop:spawn:" .. track, cur = "Rubies", kind = "Spawn", name = track, level = lvl, cost = plNum(entry.Price, 0), dV = plSpawnValue(track, lvl) })
    								end
    							end
    						end
    					end
    					-- Moon shops (gems)
    					local moonCfg = Auto.GameData.moonConfig
    					if moonCfg then
    						for _, shopKey in ipairs({ "Permanent", "Incremental" }) do
    							local shop = moonCfg[shopKey]
    							local on = S.farmOP or (if shopKey == "Permanent" then S.autoMoonPerm else S.autoMoonIncr)
    							local pick = if shopKey == "Permanent" then S.moonPermPick else S.moonIncrPick
    							local folder = moonCfg.DataFolders and moonCfg.DataFolders[shopKey] or (if shopKey == "Permanent" then "MoonPermUpgradesData" else "MoonUpgradesData")
    							if shop and on then
    								for _, uname in ipairs(shop.Order or {}) do
    									local levels = shop[uname]
    									local lvl = readLevel(folder, uname)
    									local cap = plNum(plCall(moonCfg, "GetLevelCap", LocalPlayer, shopKey, uname), 0)
    									cap = math.min(cap, plNum(shop.MaxLevels and shop.MaxLevels[uname], cap))
    									local entry = type(levels) == "table" and levels[lvl + 1] or nil
    									if pick[uname] and lvl < cap and type(entry) == "table" then
    										local additive = shop.AdditiveUpgrades and shop.AdditiveUpgrades[uname]
    										local base = if additive then 0 else 1
    										local b = plBoostAt(levels, lvl, base)
    										local n = plNum(entry.Boost, b)
    										local fn = plMoonKind[shopKey][uname]
    										local dV = if fn then fn(if b > 0 or additive then b else 1, n) else 0
    										plAdd(list, { id = "shop:" .. shopKey .. ":" .. uname, cur = "Gems", kind = "Moon " .. shopKey, name = uname, level = lvl, cost = plNum(entry.Price, 0), dV = dV, incremental = shopKey == "Incremental" })
    									end
    								end
    							end
    						end
    					end
    					-- Upgrade Tree (rubies), one level of lookahead through nodes that only open branches
    					local tree = Auto.GameData.tree
    					if tree and (S.autoTree or S.farmOP) and flag(Auto.GameData.treeFlag or "SP13") then
    						local folder = getDataFolder(Auto.GameData.treeFolder or "TreeData")
    						local levels = {}
    						for _, group in ipairs(tree.Groups) do
    							local lvl = 0
    							if not group.parent then
    								lvl = #group.levels
    							else
    								for _, node in ipairs(group.levels) do
    									if not treeOwned(folder, node.id) then break end
    									lvl += 1
    								end
    							end
    							levels[group.id] = lvl
    						end
    						local function nodeValue(node)
    							local effect = node and node.effect
    							local fn = effect and plTreeValue[effect.Type]
    							return if fn then fn(plNum(effect.Value, 0)) else 0
    						end
    						for _, group in ipairs(tree.Groups) do
    							local lvl = levels[group.id] or 0
    							local node = group.parent and group.levels[lvl + 1]
    							if node and S.treePick[group.id] and (group.requires == nil or flag(group.requires)) then
    								local parent = tree.GroupById and tree.GroupById[group.parent]
    								local parentDone = parent == nil or (levels[parent.id] or 0) >= (tonumber(group.parentLevel) or #parent.levels)
    								if parentDone or lvl > 0 then
    									local nodeCost = plNum(node.cost, 0)
    									local dV = nodeValue(node)
    									if dV <= 0 then
    										-- value of the best branch this node opens: its gain over both prices
    										for _, child in ipairs(tree.Groups) do
    											if child.parent == group.id and (tonumber(child.parentLevel) or #group.levels) == lvl + 1 and child.levels[1] and S.treePick[child.id] then
    												local childCost = plNum(child.levels[1].cost, 0)
    												local childValue = nodeValue(child.levels[1])
    												if nodeCost + childCost > 0 then
    													dV = math.max(dV, childValue * nodeCost / (nodeCost + childCost))
    												end
    											end
    										end
    									end
    									plAdd(list, { id = "tree:" .. group.id, cur = "Rubies", kind = "Tree", name = tostring(node.title or group.title or node.id), level = node.id, cost = nodeCost, dV = dV })
    								end
    							end
    						end
    					end
    					-- Special upgrades (rubies)
    					if S.autoSpecial or S.farmOP then
    						local special = specialInfo()
    						for _, row in ipairs(special.rows) do
    							if row.picked and not row.owned and not row.locked then
    								local dV, progress = plSpecialValue(row.title)
    								plAdd(list, { id = "special:" .. row.name, cur = "Rubies", kind = "Special", name = row.title, cost = row.price, dV = dV, progress = progress })
    							end
    						end
    					end
    					return list
    				end
    
    				-- rebirth: x1.1 gems for good, but the Incremental shop resets
    				local function plRebirth()
    					local moonCfg = Auto.GameData.moonConfig
    					local rb = rebirthInfo()
    					if not (moonCfg and rb.available and rb.moonUnlocked and rb.nextNumber and moonCfg.Incremental) then
    						return nil
    					end
    					local shop = moonCfg.Incremental
    					local folder = moonCfg.DataFolders and moonCfg.DataFolders.Incremental or "MoonUpgradesData"
    					local remain, rebuild, dmgB, gemsB = 0, 0, 1, 1
    					for _, uname in ipairs(shop.Order or {}) do
    						local levels = shop[uname]
    						if type(levels) == "table" then
    							local lvl = readLevel(folder, uname)
    							local cap = plNum(plCall(moonCfg, "GetLevelCap", LocalPlayer, "Incremental", uname), lvl)
    							for k = 1, lvl do
    								rebuild += plNum(type(levels[k]) == "table" and levels[k].Price, 0)
    							end
    							for k = lvl + 1, cap do
    								remain += plNum(type(levels[k]) == "table" and levels[k].Price, 0)
    							end
    							if uname == "Damage" or uname == "PetAttackSpeed" then
    								dmgB *= math.max(1, plBoostAt(levels, lvl, 1))
    							elseif uname == "MoreGems" then
    								gemsB = math.max(1, plBoostAt(levels, lvl, 1))
    							end
    						end
    					end
    					local gems = P.Ib.Gems
    					local after = gems * 1.1 / (dmgB * gemsB)
    					local T = if gems > 0 then rebuild / math.max((after + gems * 1.1) / 2, 1e-9) else math.huge
    					local drop = P.V * (1 - 1 / dmgB) + P.w.Gems * gems / dmgB * (1 - 1 / gemsB)
    					local loss = drop * math.min(T, P.H) / 2
    					local wRebuild = if rebuild > 0 then P.V * (1 - 1 / dmgB) * P.H / rebuild else 0
    					local gainRate = 0.1 * gems * math.max(P.w.Gems, wRebuild)
    					local gain = gainRate * math.max(0, P.H - T)
    					return { ready = rb.ready, remain = remain, rebuild = rebuild, T = T, gain = gain, loss = loss, net = gain - loss, gainRate = gainRate, rebirths = rb.rebirths }
    				end
    
    				local function plLabel(option)
    					if not option then
    						return "none"
    					end
    					return option.kind .. ":" .. tostring(option.name)
    				end
    
    				local function plFmt(value)
    					value = plNum(value, 0)
    					if value == math.huge then
    						return "inf"
    					end
    					return string.format("%.3g", value)
    				end
    
    				-- one pass: rates, weights, options, best per currency and what may be bought
    				function P.compute()
    					local I = P.I
    					I.Coins, I.Rubies, I.Gems = plRate("Coins"), plRate("Rubies"), plRate("Gems")
    					P.eggRate = plRate("Eggs")
    					if I.Coins <= 0 then
    						P.ready = false
    						return
    					end
    					local eff = plReq("eff", "Modules", "EffectiveBoostsModule")
    					P.Mc = math.max(1, plNum(plCall(eff, "GetCoinsMultiplier", LocalPlayer), 1))
    					P.Mr = math.max(1, plNum(plCall(eff, "GetRubiesMultiplier", LocalPlayer), 1))
    					P.crit = math.clamp(plNum(plCall(eff, "GetCritChance", LocalPlayer), 0.01), 0, 1)
    					P.critDmg = math.max(1, plNum(plCall(eff, "GetCritDamage", LocalPlayer), 4))
    					P.hatchSpeed = math.max(0.1, plNum(plCall(eff, "GetHatchSpeed", LocalPlayer), 1))
    					P.treeDmg = math.max(1, plNum(plCall(eff, "GetTreePetDamageMultiplier", LocalPlayer), 1))
    					P.treeAtk = math.max(1, plNum(plCall(eff, "GetTreeAttackSpeedMultiplier", LocalPlayer), 1))
    					-- admin events: the measured income includes them, the 24 h value of a buy must not (additive coin/ruby stack, gems multiplicative)
    					local evt = plEvents()
    					P.evt = evt
    					local Ib = P.Ib
    					local bc = (evt.Coins - 1) + (evt.coinsBonus or 0)
    					local br = (evt.Rubies - 1) + (evt.rubiesBonus or 0)
    					Ib.Coins = I.Coins * math.max(0.05, P.Mc - bc) / P.Mc
    					Ib.Rubies = I.Rubies * math.max(0.05, P.Mr - br) / P.Mr
    					Ib.Gems = I.Gems / math.max(1, evt.Gems)
    					if evt.RubyRush and P.frozen then
    						-- only ruby breakables spawn: the coin rate measured now is not the normal one
    						Ib.Coins, Ib.Rubies, Ib.Gems = P.frozen.Coins, P.frozen.Rubies, P.frozen.Gems
    					elseif not evt.RubyRush then
    						P.frozen = { Coins = Ib.Coins, Rubies = Ib.Rubies, Gems = Ib.Gems }
    					end
    					local moonCfg = Auto.GameData.moonConfig
    					local more = moonCfg and moonCfg.Incremental and moonCfg.Incremental.MoreGems
    					P.gemsAdd = math.max(1, plBoostAt(more, readLevel("MoonUpgradesData", "MoreGems"), 1))
    					P.luck = math.max(0.01, plNum(readData("TrustedStats", "LuckMultiplier"), 1))
    					P.secretLuck = plNum(readData("TrustedStats", "SecretLuckMultiplier"), 1)
    					P.charmSecret = plNum(readData("VariousBoosts", "CharmsSecretBoost"), 0)
    					P.gold = plNum(plCall(plReq("gold", "Modules", "GoldenChanceModule"), "GetGoldenChance", "Basic", LocalPlayer), 0.1)
    					local team = teamSnapshot()
    					local slots = plNum(plCall(plReq("equip", "Modules", "EquippedPetsModule"), "GetMaxEquip", LocalPlayer), team.count)
    					local weakest = math.huge
    					for _, entry in ipairs(team.list) do
    						weakest = math.min(weakest, entry.power / math.max(1, entry.count))
    					end
    					if team.count < slots or weakest == math.huge then
    						weakest = 0
    					end
    					P.team = { power = math.max(1, team.power), weakest = weakest, count = team.count, slots = slots }
    					local maxOpen = math.max(1, plNum(readData("TrustedStats", "MaxEggOpen"), 1))
    					P.eggSeconds = if P.eggRate > 0 then 1 / P.eggRate else 0
    					-- farm world efficiency: the best unlocked coin world
    					local bestEff, bestRuby, moon = 0, 0, moonWorld()
    					for _, key in ipairs(Auto.GameData.worldOrder or UI.WorldOrder or {}) do
    						if key ~= moon and worldUnlocked(key) then
    							local e = plWorldEff(key)
    							if e and (e.Coins or 0) > bestEff then
    								bestEff = e.Coins
    								bestRuby = e.Rubies or 0
    							end
    						end
    					end
    					P.farmEff, P.farmRubyEff = bestEff, bestRuby
    					local options
    					-- shadow prices start from zero on every compute (two passes: coins first, then the cross terms)
    					P.w = { Coins = 1, Rubies = 0, Gems = 0 }
    					for _ = 1, 2 do
    						P.V = Ib.Coins + P.w.Rubies * Ib.Rubies + P.w.Gems * Ib.Gems
    						-- the egg to hatch: best gain per coin (needed first, luck and hatch speed are valued through it)
    						P.hatch = nil
    						options = plOptions()
    						local bestEgg = nil
    						for _, option in ipairs(options) do
    							if option.kind == "Egg" and option.gain > 0 and (not bestEgg or option.perEgg / option.cost > bestEgg.perEgg / bestEgg.cost) then
    								bestEgg = option
    							end
    						end
    						if bestEgg then
    							local rate = if P.eggRate > 0 then P.eggRate else maxOpen
    							P.hatch = { egg = bestEgg.name, gain = bestEgg.gain, rate = rate, maxOpen = maxOpen, bound = I.Coins > rate * bestEgg.price }
    							options = plOptions()
    						end
    						-- shadow price of rubies and gems: best gain over the horizon per unit, valued without the currency's own
    						-- growth (a ruby multiplier bought with rubies fed w_r into itself every pass: V=1e210 in the RATE line)
    						local nextW = { Coins = 1, Rubies = 0, Gems = 0 }
    						for _, cur in ipairs({ "Rubies", "Gems" }) do
    							local own = P.w[cur]
    							P.w[cur] = 0
    							P.V = Ib.Coins + P.w.Rubies * Ib.Rubies + P.w.Gems * Ib.Gems
    							local curOptions = plOptions()
    							P.w[cur] = own
    							for _, option in ipairs(curOptions) do
    								if option.cur == cur and not option.progress and (option.cost or 0) > 0 then
    									local income = math.max(I[option.cur], 1e-9)
    									local balance = (getStat(option.cur) or 0) - plReserve(option.cur)
    									local eta = math.max(0, option.cost - balance) / income
    									local value = option.dV * math.max(0, P.H - eta) / option.cost
    									if value == value and value < math.huge then
    										nextW[cur] = math.max(nextW[cur], value)
    									end
    								end
    							end
    						end
    						P.w = nextW
    					end
    					P.V = Ib.Coins + P.w.Rubies * Ib.Rubies + P.w.Gems * Ib.Gems
    					options = plOptions()
    					-- best per currency: largest gain over the 24 h horizon per unit, cheaper buys only when they beat the delay they cause
    					local byId, best = {}, {}
    					for _, option in ipairs(options) do
    						byId[option.id] = option
    						local income = math.max(I[option.cur], 1e-9)
    						local balance = (getStat(option.cur) or 0) - plReserve(option.cur)
    						option.balance = balance
    						option.eta = math.max(0, option.cost - balance) / income
    						option.score = option.dV * math.max(0, P.H - option.eta) / option.cost
    						local worth = if option.cur == "Coins" then option.score > 1 else option.score > 0
    						if worth and not option.progress then
    							local current = best[option.cur]
    							if not current or option.score > current.score then
    								best[option.cur] = option
    							end
    						end
    					end
    					for _, option in ipairs(options) do
    						local target = best[option.cur]
    						if option.progress then
    							option.allowed = true
    						elseif option == target then
    							option.allowed = true
    						elseif target and target.eta > 0 and option.eta <= 0 and option.score > (if option.cur == "Coins" then 1 else 0) then
    							local income = math.max(I[option.cur], 1e-9)
    							local net = option.dV * P.H - (if option.cur == "Coins" then option.cost else 0)
    							option.allowed = net > target.dV * option.cost / income
    						else
    							option.allowed = false
    						end
    					end
    					-- Luck / Free Eggs event: coins go into eggs while the window lasts (pets keep the luck-boosted value for good)
    					if evt.Luck > 1 or evt.FreeEggs then
    						for _, option in ipairs(options) do
    							if option.kind == "Egg" and option.score > 1 then
    								option.allowed = true
    							end
    						end
    					end
    					-- rebirth path: finishing the Incremental shop is one option, the rebirth decides the rest
    					local rb = plRebirth()
    					P.rebirth = rb
    					P.rebirthPath = false
    					P.rebirthNow = false
    					if rb then
    						local pathScore = if rb.remain > 0 then rb.gainRate * math.max(0, P.H - rb.remain / math.max(I.Gems, 1e-9)) / rb.remain else math.huge
    						local gemBest = best.Gems
    						P.rebirthPath = rb.net > 0 and (gemBest == nil or gemBest.incremental or pathScore >= gemBest.score)
    						if P.rebirthPath then
    							for _, option in ipairs(options) do
    								if option.incremental then
    									option.allowed = true
    								end
    							end
    						end
    						if rb.ready and rb.net > 0 then
    							local permFirst = false
    							for _, option in ipairs(options) do
    								if option.cur == "Gems" and not option.incremental and option.allowed and option.eta <= 0 then
    									permFirst = true
    								end
    							end
    							P.rebirthNow = not permFirst
    							P.rebirthWhy = if permFirst then "buying Permanent first" else "net gain"
    						else
    							P.rebirthWhy = if rb.ready then "reset not paid back in 24 h" else "Incremental not maxed"
    						end
    					end
    					P.byId, P.best, P.options = byId, best, options
    					-- coins: egg to hatch and how much to keep for the world
    					local coinBest = best.Coins
    					local eggPick, world = nil, nil
    					for _, option in ipairs(options) do
    						if option.kind == "Egg" and option.allowed and (not eggPick or option.score > eggPick.score) then
    							eggPick = option
    						end
    						if option.kind == "World" and option.cur == "Coins" then
    							world = option
    						end
    					end
    					P.egg = eggPick and eggPick.name or nil
    					P.eggWhy = if eggPick then "" elseif coinBest and coinBest.kind == "World" then "saving for " .. prettyWorld(coinBest.name) else "no egg pays back in 24 h"
    					P.keep.Coins = if coinBest and coinBest == world and world.eta > 0 and not eggPick then world.cost else 0
    					P.ready = true
    				end
    
    				function P.allows(id, price, stamp)
    					if not P.ready then
    						return true
    					end
    					local option = P.byId[id]
    					if not option or not option.allowed then
    						return false
    					end
    					if stamp ~= nil and option.level ~= nil and option.level ~= stamp then
    						return false
    					end
    					local balance = (getStat(option.cur) or 0) - plReserve(option.cur)
    					return balance >= (price or option.cost)
    				end
    
    				function P.score(id)
    					local option = P.byId[id]
    					return if option then option.score else -1
    				end
    
    				local function plWhen(sec)
    					sec = tonumber(sec) or math.huge
    					if sec <= 2 then
    						return "now"
    					elseif sec < 90 then
    						return "in ~" .. math.ceil(sec) .. " s"
    					elseif sec < 5400 then
    						return "in ~" .. math.ceil(sec / 60) .. " min"
    					elseif sec < 172800 then
    						return "in ~" .. string.format("%.1f", sec / 3600) .. " h"
    					end
    					return "later"
    				end
    				local function plPlain(option)
    					local kind, name = option.kind, tostring(option.name)
    					if kind == "World" then
    						return "Unlock " .. prettyWorld(option.name)
    					elseif kind == "Spawn" then
    						return "Buy spawn upgrade: " .. Auto.prettyUpgrade(name)
    					elseif kind == "Tree" then
    						return "Buy tree upgrade: " .. name
    					elseif kind == "Special" then
    						return "Buy special upgrade: " .. name
    					elseif string.sub(kind, 1, 4) == "Moon" then
    						return "Buy Moon upgrade: " .. Auto.prettyUpgrade(name)
    					end
    					return "Buy " .. name
    				end
    				-- plain words for the UI; the raw numbers stay in the log (PLAN lines)
    				function Auto.upNextText()
    					if not P.ready and not P.wanted() then
						return "Switch on Smart Planner (or Smart Egg Pick, Auto Upgrade, Auto Buy Worlds) and the next steps show here."
					end
    					if not P.ready then
    						return "Measuring your income, the plan shows up in a minute."
    					end
    					local lines = {}
    					if P.egg then
    						table.insert(lines, "Hatch " .. P.egg .. " x" .. tostring(if P.hatch then P.hatch.maxOpen else 1))
    					elseif P.eggWhy and P.eggWhy ~= "" then
    						table.insert(lines, "Eggs: " .. P.eggWhy)
    					end
    					for _, cur in ipairs({ "Coins", "Rubies", "Gems" }) do
    						local best = P.best and P.best[cur]
    						if best and best.kind ~= "Egg" then
    							table.insert(lines, plPlain(best) .. " " .. plWhen(best.eta))
    						end
    					end
    					local rb = P.rebirth
    					if rb then
    						if P.rebirthNow then
    							table.insert(lines, "Moon rebirth right now")
    						elseif rb.ready then
    							table.insert(lines, "Moon rebirth once it pays back")
    						elseif rb.remain > 0 then
    							table.insert(lines, "Moon rebirth when gems reach " .. plFmt(rb.remain))
    						end
    					end
    					if P.fishOff then
    						table.insert(lines, "Fishing paused: farming pays more now")
    					end
    					if #lines == 0 then
    						return "Farming. Nothing worth buying yet."
    					end
    					while #lines > 5 do
    						table.remove(lines)
    					end
    					return table.concat(lines, "\n")
    				end
    				
    				function P.on()
    					return P.ready
    				end
    
    				-- time: value earned per second in each activity (coin-equivalent), half-life 30 min
    				local function plActivity()
    					if Mover.busy then
    						return nil
    					end
    					local fish = Auto.Fish
    					if fish and fish.active then
    						return "Fish"
    					end
    					if Ufo.engaged then
    						return "UFO"
    					end
    					if S.indexHunt and Hunter.egg then
    						return "Index"
    					end
    					return "Farm"
    				end
    
    				local function plTrack(now)
    					local metrics = Auto.Metrics
    					if not metrics then
    						return
    					end
    					local cum = metrics.cum
    					local value = cum.Coins + P.w.Rubies * cum.Rubies + P.w.Gems * cum.Gems
    					local last = P.last
    					local activity = plActivity()
    					if last and last.activity and last.c then
    						local dt = now - last.t
    						value = last.value + math.max(0, cum.Coins - last.c) + P.w.Rubies * math.max(0, cum.Rubies - last.r) + P.w.Gems * math.max(0, cum.Gems - last.g)
    						if dt > 0 and dt < 60 then
    							local decay = 0.5 ^ (dt / 1800)
    							for _, a in pairs(P.act) do
    								a.v *= decay
    								a.t *= decay
    							end
    							local a = P.act[last.activity] or { v = 0, t = 0 }
    							P.act[last.activity] = a
    							a.v += math.max(0, value - last.value)
    							a.t += dt
    						end
    					end
    					P.last = { t = now, value = value, activity = activity, c = cum.Coins, r = cum.Rubies, g = cum.Gems }
    					-- fishing vs farming: measure both, keep the better one (tokens from fish are not counted as money)
    					local farm, fishAct = P.act.Farm, P.act.Fish
    					if not ((S.fishSmart or S.farmOP) and S.autoFish) then
    						P.fishOff = false
    					elseif P.evt and P.evt.fishBoost then
    						P.fishOff = false
    					elseif not fishAct or fishAct.t < 180 then
    						P.fishOff = false
    					elseif not farm or farm.t < 180 then
    						P.fishOff = true
    					else
    						P.fishOff = farm.v / farm.t > fishAct.v / fishAct.t
    					end
    				end
    
    				local function plEvtText()
    					local parts = {}
    					for kind, left in pairs(P.evt and P.evt.active or {}) do
    						table.insert(parts, kind .. "(" .. left .. "s)")
    					end
    					table.sort(parts)
    					return if #parts > 0 then table.concat(parts, ",") else "none"
    				end

    				local function plReport(now)
    					local I = P.I
    					if now - (P.lastLog.rate or -1e9) >= 60 then
    						P.lastLog.rate = now
    						plLog("RATE", "coins/s=" .. plFmt(I.Coins), "rubies/s=" .. plFmt(I.Rubies), "gems/s=" .. plFmt(I.Gems), "eggs/s=" .. plFmt(P.eggRate), "V=" .. plFmt(P.V), "Mc=" .. plFmt(P.Mc), "Mr=" .. plFmt(P.Mr), "luck=" .. plFmt(P.luck), "team=" .. plFmt(P.team.power), "weakest=" .. plFmt(P.team.weakest), "slots=" .. tostring(P.team.count) .. "/" .. tostring(P.team.slots), "w_r=" .. plFmt(P.w.Rubies), "w_g=" .. plFmt(P.w.Gems), "H=" .. P.H, "base=" .. plFmt(P.Ib.Coins) .. "/" .. plFmt(P.Ib.Rubies) .. "/" .. plFmt(P.Ib.Gems), "evt=" .. plEvtText())
    						local parts = {}
    						for name, a in pairs(P.act) do
    							table.insert(parts, name .. "=" .. plFmt(if a.t > 0 then a.v / a.t else 0) .. "/s(" .. math.floor(a.t) .. "s)")
    						end
    						table.sort(parts)
    						plLog("TIME", table.concat(parts, " "), "fishOff=" .. tostring(P.fishOff))
    						local rb = P.rebirth
    						local rbKey = if rb then tostring(rb.ready) .. "|" .. tostring(P.rebirthNow) .. "|" .. tostring(P.rebirthWhy) .. "|" .. tostring(P.rebirthPath) else ""
    						if rb and (S.autoRebirth or S.rebirthSmart or S.farmOP) and (rbKey ~= P.lastLog.rbKey or now - (P.lastLog.rbAt or -1e9) >= 900) then
    							P.lastLog.rbKey = rbKey
    							P.lastLog.rbAt = now
    							plLog("REBIRTH", "ready=" .. tostring(rb.ready), "now=" .. tostring(P.rebirthNow), "why=" .. tostring(P.rebirthWhy), "net=" .. plFmt(rb.net), "gain=" .. plFmt(rb.gain), "loss=" .. plFmt(rb.loss), "rebuildT=" .. plFmt(rb.T), "remain=" .. plFmt(rb.remain), "path=" .. tostring(P.rebirthPath))
    						end
    					end
    					for _, cur in ipairs({ "Coins", "Rubies", "Gems" }) do
    						local sorted = {}
    						for _, option in ipairs(P.options or {}) do
    							if option.cur == cur then
    								table.insert(sorted, option)
    							end
    						end
    						table.sort(sorted, function(a, b)
    							return a.score > b.score
    						end)
    						local best = P.best[cur]
    						local key = plLabel(best) .. "|" .. tostring(P.egg)
    						if #sorted > 0 and (P.lastLog[cur] ~= key or now - (P.lastLog[cur .. "t"] or -1e9) >= 300) then
    							P.lastLog[cur] = key
    							P.lastLog[cur .. "t"] = now
    							local alt = {}
    							for i = 1, math.min(#sorted, 4) do
    								local option = sorted[i]
    								if option ~= best then
    									table.insert(alt, plLabel(option) .. " " .. plFmt(option.ratio) .. (if option.allowed then "+" else ""))
    								end
    							end
    							plLog("PLAN", "best=" .. cur .. "/" .. plLabel(best), "gain/$=" .. plFmt(best and best.ratio), "score=" .. plFmt(best and best.score), "eta=" .. plFmt(best and best.eta), "alt=" .. table.concat(alt, ", "), if cur == "Coins" then "egg=" .. tostring(P.egg) .. " keep=" .. plFmt(P.keep.Coins) .. " " .. P.eggWhy else "")
    						end
    					end
    				end
    
    				-- the planner runs only while a switch that uses it is on
    				function P.wanted()
    					for _, name in ipairs({ "SmartPlan", "EggSmart", "FishSmart", "RebirthSmart", "AutoSpawnUpgrades", "AutoTree", "AutoSpecial", "AutoFishTree", "AutoBuyWorlds", "AutoHatch", "AutoRebirth", "AutoMoonPerm", "AutoMoonIncr", "AutoGolden", "AutoDiamond", "AutoInvEggs", "IndexHunter" }) do
    						local toggle = Toggles[name]
    						if toggle and toggle.Value then
    							return true
    						end
    					end
    					return false
    				end

    				task.spawn(function()
    					while alive() do
    						task.wait(5)
    						local ok, err = pcall(function()
    							local now = os.clock()
    							if not P.wanted() then
    								-- idle hub: no planner maths, no PLAN/RATE log lines
    								P.ready = false
    								if UI.UpNextLabel then
    									setLabel(UI.UpNextLabel, Auto.upNextText())
    								end
    								return
    							end
    							P.compute()
    							plTrack(now)
    							local upNext = Auto.upNextText()
    							if UI.UpNextLabel then
    								setLabel(UI.UpNextLabel, upNext)
    							end
    							if S.farmOP and P.ready and (upNext ~= P.lastLog.doText or now - (P.lastLog.doAt or -1e9) >= 600) then
    								P.lastLog.doText = upNext
    								P.lastLog.doAt = now
    								plLog("PLAN", "do: " .. string.gsub(upNext, "\n", "; "))
    							end
    							if P.ready then
    								plReport(now)
    								-- Moon world: progress, bought with rubies as soon as it is affordable
    								local moonOpt = P.byId.moonworld
    								if (S.autoBuyWorlds or S.farmOP) and moonOpt and moonOpt.eta <= 0 and not Mover.busy and now - P.moonTry > 30 then
    									P.moonTry = now
    									plLog("BUY", "moon world for", moonOpt.cost, "rubies")
    									buyWorld({ next = moonOpt.name, moon = true, from = moonOpt.from, price = moonOpt.cost, currency = "Rubies" }, Worlds.fails >= 2)
    								end
    							end
    						end)
    						if not ok then
    							plLog("PROBLEM", "plan", tostring(err))
    						end
    					end
    				end)
    
    				-- Normal: the player's egg stays unless it is empty or still the list default
    				function P.eggAuto()
    					if not (P.ready and (S.eggSmart or S.farmOP)) then
    						return false
    					end
    					return true
    				end

    				function Auto.effectiveEgg()
    					if S.farmOP or S.eggSmart then
    						return if P.ready then P.egg or "" else ""
    					end
    					return S.hatchEggName
    				end
    			end

    			Extra.nextErrand = function(now)
    				if (S.autoRebirth or S.farmOP) and now - Rebirth.lastTry > 12 and now >= Rebirth.blockedUntil then
    					local info = rebirthInfo()
    					local planWait = if (S.rebirthSmart or S.farmOP) and Auto.Plan and Auto.Plan.on() then not Auto.Plan.rebirthNow else (S.rebirthWaitPerm and Auto.permMaxed and not Auto.permMaxed())
    					if info.available and info.ready and info.moonUnlocked and info.nextNumber and not info.stopped and not planWait then
    						return "Moon rebirth", function()
    							local travel = Rebirth.needsTravel == true
    							if rebirthTrip(travel) then
    								Rebirth.fails = 0
    								Rebirth.needsTravel = travel
    								task.wait(2)
    							elseif not travel then
    								Rebirth.needsTravel = true
    							else
    								Rebirth.fails += 1
    								if Rebirth.fails >= 3 then
    									Rebirth.fails = 0
    									Rebirth.blockedUntil = os.clock() + 300
    									queueToast("Moon Rebirth", "Rebirth did not go through, trying again in 5 minutes")
    								end
    							end
    						end
    					end
    				end
    				if (S.autoSpecial or S.farmOP) and now - Special.lastTry > 8 then
    					local info = specialInfo()
    					if info.next and info.affordable then
    						local row = info.next
    						return "Special upgrade", function()
    							specialTrip(row)
    						end
    					end
    				end
    				if Auto.nextUpdateErrand then
    					return Auto.nextUpdateErrand(now)
    				end
    				return nil
    			end
    
    			local function normalizeCode(code)
    				local module = Auto.GameData.codes
    				if module and type(module.Normalize) == "function" then
    					local ok, result = pcall(module.Normalize, code)
    					if ok then
    						return if type(result) == "string" and result ~= "" then result else nil
    					end
    				end
    				local text = string.lower((string.gsub(tostring(code or ""), "[^%w]", "")))
    				return if text ~= "" and #text <= 32 then text else nil
    			end
    
    			local FinalCodes = { Redeemed = true, Invalid = true, ["Already used"] = true, Expired = true, Empty = true }
    			local function resultName(value)
    				local module = Auto.GameData.codes
    				local pretty = { Ok = "Redeemed", AlreadyUsed = "Already used", NotLoaded = "Not loaded", SaveFailed = "Save failed" }
    				if module and type(module.Result) == "table" then
    					for name, id in pairs(module.Result) do
    						if id == value then
    							return pretty[name] or name
    						end
    					end
    				end
    				return ({ "Redeemed", "Invalid", "Already used", "Cooldown", "Not loaded", "Save failed", "Empty", "Expired" })[tonumber(value) or 0] or tostring(value)
    			end
    
    			local function addCode(raw, source)
    				local code = normalizeCode(raw)
    				if not code then return nil end
    				if not Codes.found[code] then
    					Codes.found[code] = { raw = tostring(raw), source = source }
    					table.insert(Codes.order, code)
    				end
    				return code
    			end
    
    			local function scanCodes()
    				for _, code in ipairs(CorvusConfig.KnownCodes or {}) do
    					addCode(code, "built in")
    				end
    				local gui = LocalPlayer:FindFirstChild("PlayerGui")
    				local ui = gui and gui:FindFirstChild("UI")
    				if not ui then return end
    				local base = ui:FindFirstChild("Base")
    				local frames = base and base:FindFirstChild("Frames")
    				local root = frames and frames:FindFirstChild("Changelog") or ui
    				for _, obj in ipairs(root:GetDescendants()) do
    					if obj:IsA("TextLabel") or obj:IsA("TextButton") then
    						local okText, text = pcall(function() return obj.Text end)
    						if okText and type(text) == "string" and string.find(string.lower(text), "code", 1, true) then
    							text = string.gsub(text, "\u{201C}", "\"")
    							text = string.gsub(text, "\u{201D}", "\"")
    							text = string.gsub(text, "&quot;", "\"")
    							for code in string.gmatch(text, "[Cc][Oo][Dd][Ee][Ss]?:?%s*\"([%w_%-]+)\"") do
    								addCode(code, "in game")
    							end
    						end
    					end
    				end
    			end
    
    			local function fetchCodes()
    				local url = CorvusConfig.CodesUrl
    				if type(url) ~= "string" or url == "" then return end
    				local ok, body = pcall(function() return game:HttpGet(url) end)
    				if ok and type(body) == "string" then
    					for token in string.gmatch(body, "[%w_%-]+") do
    						if #token >= 3 and #token <= 32 then
    							addCode(token, "online list")
    						end
    					end
    				end
    			end
    
    			local function fetchHubCodes()
    				local repo = getgenv().CorvusHubRepo
    				if type(repo) ~= "string" or repo == "" then
    					Auto.log("CODES", "hub list skipped, no HubRepo at runtime")
    					return
    				end
    				local okGet, body = pcall(function() return game:HttpGet(repo .. "Codes?t=" .. tostring(os.time())) end)
    				if not (okGet and type(body) == "string") then
    					Auto.log("CODES", "hub list fetch failed")
    					return
    				end
    				local okJson, data = pcall(function() return HttpService:JSONDecode(body) end)
    				local list = okJson and type(data) == "table" and data["Pets Universe"] or nil
    				if type(list) ~= "table" then
    					Auto.log("CODES", "hub list has no Pets Universe entry")
    					return
    				end
    				local fresh = 0
    				for _, raw in ipairs(list) do
    					if type(raw) == "string" then
    						local code = normalizeCode(raw)
    						if code and not Codes.found[code] then
    							fresh += 1
    						end
    						addCode(raw, "hub list")
    					end
    				end
    				Auto.log("CODES", "hub list", #list, "codes,", fresh, "new")
    			end
    			
    			local function redeem(code)
    				local remote = Auto.knitRemote("CodesService", "RE", "Redeem")
    				if not remote then return nil end
    				Codes.result = nil
    				pcall(function() remote:FireServer(code) end)
    				local waited = 0
    				while waited < 6 and Codes.result == nil do
    					waited += task.wait(0.1) or 0.1
    				end
    				if Codes.result == nil then return nil end
    				return resultName(Codes.result)
    			end
    
    			Auto.redeemCode = function(text)
    				local code = addCode(text, "manual")
    				if not code then
    					queueToast("Codes", "Type a code first")
    					return
    				end
    				Saved.codes[code] = nil
    				Codes.nextTry[code] = nil
    				table.insert(Codes.manual, code)
    				queueToast("Codes", "Redeeming " .. code .. "...")
    			end
    
    			task.spawn(function()
    				while alive() do
    					task.wait(1)
    					pcall(hookEvent, "treeResult", "UpgradeTreeService", "PurchaseResult", function(nodeId, ok, reason)
    						Tree.result = if ok then "ok" else tostring(reason or "failed")
    					end)
    					pcall(hookEvent, "codesResult", "CodesService", "Result", function(value)
    						Codes.result = value
    					end)
    					local ok, err = pcall(function()
    						if not (S.autoTree or S.farmOP) then
    							Tree.status = "Off"
    							return
    						end
    						local info = treeInfo()
    						if not info.available then
    							Tree.status = "Not in this game"
    						elseif not info.unlocked then
    							Tree.status = "Unlock the tree first"
    						elseif not info.anyPicked then
    							Tree.status = "Pick upgrades"
    						elseif info.allDone then
    							Tree.status = "All done"
    							if not Tree.doneToast then
    								Tree.doneToast = true
    								queueToast("Upgrade Tree", "Every picked upgrade is maxed")
    							end
    						elseif not info.next then
    							Tree.status = if info.needsFlag == "SP7" then "Needs Mastery" else "Waiting"
    						elseif not info.affordable then
    							Tree.status = "Saving up"
    						else
    							local remote = Auto.knitRemote("UpgradeTreeService", "RE", "BuyNode")
    							if not remote then
    								Tree.status = "Unavailable"
    								return
    							end
    							Tree.status = "Buying"
    							local node = info.next.node
    							Tree.result = nil
    							pcall(function() remote:FireServer(node.id) end)
    							local waited = 0
    							while waited < 2.5 and Tree.result == nil and not treeOwned(getDataFolder(Auto.GameData.treeFolder or "TreeData"), node.id) do
    								waited += task.wait(0.1) or 0.1
    							end
    							task.wait(0.15)
    							if treeOwned(getDataFolder(Auto.GameData.treeFolder or "TreeData"), node.id) then
    								Saved.treeBought += 1
    								SaveDirty = true
    								Tree.last = info.title
    								Auto.log("BUY", "tree", node.id, info.title, "for", info.cost, "rubies")
    							else
    								Tree.blocked[info.next.group.id] = os.clock() + 30
    							end
    						end
    						if info.anyPicked and not info.allDone then
    							Tree.doneToast = false
    						end
    					end)
    					if not ok then
    						diag("tree", err)
    					end
    				end
    			end)
    
    			task.spawn(function()
    				while alive() do
    					task.wait(1)
    					local ok, err = pcall(function()
    						if not (S.autoSpecial or S.farmOP) then
    							Special.status = "Off"
    						else
    							local info = specialInfo()
    							if not info.anyPicked then
    								Special.status = "Pick upgrades"
    							elseif info.allDone then
    								Special.status = "All owned"
    								if not Special.doneToast then
    									Special.doneToast = true
    									queueToast("Special Upgrades", "Every picked upgrade is owned")
    								end
    							elseif not info.next then
    								Special.status = if info.anyLocked then "Unlock more worlds" else "Waiting"
    							elseif not info.affordable then
    								Special.status = "Saving up"
    							else
    								Special.status = if Mover.busy and string.find(Mover.task, "Buying", 1, true) then "Buying" else "Going to buy"
    							end
    							if not info.allDone then
    								Special.doneToast = false
    							end
    						end
    						if not (S.autoRebirth or S.farmOP) then
    							Rebirth.status = "Off"
    						else
    							local info = rebirthInfo()
    							if not info.available then
    								Rebirth.status = "Not in this game"
    							elseif not info.moonUnlocked then
    								Rebirth.status = "Moon locked"
    							elseif not info.nextNumber then
    								Rebirth.status = "Max rebirths"
    							elseif info.stopped then
    								Rebirth.status = "Stopped at " .. tostring(S.rebirthStopAt)
    							elseif info.ready and (S.rebirthSmart or S.farmOP) and Auto.Plan and Auto.Plan.on() and not Auto.Plan.rebirthNow then
    								Rebirth.status = "Waiting: " .. tostring(Auto.Plan.rebirthWhy or "waiting")
    							elseif info.ready and S.rebirthWaitPerm and Auto.permMaxed and not Auto.permMaxed() then
    								local _, owned, cap = Auto.permMaxed()
    								Rebirth.status = string.format("Waiting for Permanent %d/%d", owned or 0, cap or 0)
    							elseif info.ready then
    								Rebirth.status = if os.clock() < Rebirth.blockedUntil then "Retrying soon" else "Rebirthing"
    							else
    								Rebirth.status = "Buying upgrades"
    							end
    						end
    					end)
    					if not ok then
    						diag("extras", err)
    					end
    				end
    			end)
    
    			task.spawn(function()
    				while alive() do
    					task.wait(1)
    					local ok, err = pcall(function()
    						local now = os.clock()
    						if now - Codes.lastScan > 300 then
    							Codes.lastScan = now
    							scanCodes()
    						end
    						if now - Codes.lastFetch > 600 then
    							Codes.lastFetch = now
    							fetchCodes()
    							end
    							if now - Codes.lastHub > 21600 then
    								Codes.lastHub = now
    								fetchHubCodes()
    							end
    						local code = table.remove(Codes.manual, 1)
    						local manual = code ~= nil
    						if not code and S.autoCodes then
    							for _, candidate in ipairs(Codes.order) do
    								if not FinalCodes[Saved.codes[candidate]] and now >= (Codes.nextTry[candidate] or 0) then
    									code = candidate
    									break
    								end
    							end
    						end
    						if not code then
    							Codes.status = if S.autoCodes then "Up to date" else "Off"
    							return
    						end
    						Codes.status = "Redeeming " .. code
    						local result = redeem(code)
    						Codes.last = { code = code, result = result or "No answer" }
    						Auto.log("CODES", "redeem", code, tostring(result))
    						if result and FinalCodes[result] then
    							Saved.codes[code] = result
    							SaveDirty = true
    						else
    							Codes.nextTry[code] = os.clock() + 60
    						end
    						if result == "Redeemed" then
    							Saved.codesRedeemed += 1
    							SaveDirty = true
    							queueToast("Codes", "Redeemed " .. ((Codes.found[code] and Codes.found[code].raw) or code))
    							postEvent("Codes", "Code redeemed", "**" .. ((Codes.found[code] and Codes.found[code].raw) or code) .. "** worked", 6283215)
    						elseif manual then
    							queueToast("Codes", code .. ": " .. (result or "no answer"))
    						end
    						task.wait(1)
    					end)
    					if not ok then
    						diag("codes", err)
    					end
    				end
    			end)
    
    			Auto.goToPlace = function(label)
    				local place
    				for _, entry in ipairs(UI.Places or {}) do
    					if entry.label == label then
    						place = entry
    					end
    				end
    				if not place then return end
    				if Mover.busy then
    					queueToast("Places", "Busy: " .. (if Mover.task ~= "" then Mover.task else "travelling"))
    					return
    				end
    				Mover.busy = true
    				Mover.task = "Going to " .. label
    				task.spawn(function()
    					local ok, err = pcall(function()
    						local world
    						if place.shop then
    							local shop = moonShop(place.shop)
    							if not shop then error("Not found in this game") end
    							local _, shopWorld = shop.anchor()
    							world = shopWorld
    						else
    							world = machineWorld(place.machine, if place.moon then moonWorld() else place.fallback)
    						end
    						if not world then error("Not found in this game") end
    						if not worldUnlocked(world) then error(prettyWorld(world) .. " is locked") end
    						local reached, why = travelTo(world)
    						if not reached then error(why or "Could not get there") end
    						local anchor
    						if place.shop then
    							anchor = moonShop(place.shop).anchor()
    						else
    							anchor = machineAnchor(place.machine)
    						end
    						if anchor and anchor:IsA("BasePart") then
    							standAt(anchor, 5)
    						end
    					end)
    					queueToast("Places", if ok then "Arrived at " .. label else shortError(err))
    					Mover.busy = false
    					Mover.task = ""
    				end)
    			end
    
    
    			local HopFile = SaveFolder .. "/PetsUniverse_ufohop.json"
    			local Hop = { status = "Off", state = nil, stamp = nil, lastQuery = -1e9, arrivedAt = os.clock(), hops = 0, visited = {}, seen = {}, global = nil, lastHop = -1e9, found = false, ineligibleSince = nil, teleporting = false, warned = false }
    
    			local function hopSave(active)
    				pcall(function()
    					if type(writefile) ~= "function" then return end
    					if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(SaveFolder) then
    						makefolder(SaveFolder)
    					end
    					writefile(HopFile, HttpService:JSONEncode({
    						active = active,
    						at = os.time(),
    						hops = Hop.hops,
    						visited = Hop.visited,
    						seen = Hop.seen,
    						global = Hop.global,
    						window = S.ufoHopWindow,
    						chase = S.ufoHopChase,
    					}))
    				end)
    			end
    
    			pcall(function()
    				if type(isfile) == "function" and type(readfile) == "function" and isfile(HopFile) then
    					local data = HttpService:JSONDecode(readfile(HopFile))
    					if type(data) == "table" then
    						Hop.visited = type(data.visited) == "table" and data.visited or {}
    						Hop.seen = type(data.seen) == "table" and data.seen or {}
    						if type(data.global) == "boolean" then
    							Hop.global = data.global
    						end
    						if data.active == true and tonumber(data.at) and os.time() - data.at < 1800 then
    							Hop.hops = tonumber(data.hops) or 0
    							Auto.resumeUfoHop = { window = tonumber(data.window), chase = data.chase == true }
    							Hop.warned = true
    						end
    					end
    				end
    			end)
    
    			local function queueReload()
    				return Auto.queueSelf("hop")
    			end
    
    			Auto.onUfoHop = function(on)
    				if on then
    					Hop.arrivedAt = math.min(Hop.arrivedAt, os.clock() - 6)
    					if not Hop.warned and not Auto.canReload() then
    						Hop.warned = true
    						queueToast("UFO Hop", "After a hop the hub starts again only if it is in your executor's auto execute folder")
    					end
    					hopSave(true)
    				else
    					Hop.hops = 0
    					Hop.found = false
    					Hop.status = "Off"
    					hopSave(false)
    				end
    			end
    
    			local function ufoState()
    				if os.clock() - Hop.lastQuery >= 8 or not Hop.state then
    					Hop.lastQuery = os.clock()
    					local ok, state, stamp = Auto.invokeTimeout(Auto.knitRemote("AlienEventService", "RF", "GetState"), 6)
    					if state == true then
    						state = "Active"
    					elseif ok and state ~= true and type(state) ~= "string" and tonumber(stamp) then
    						state = "Idle"
    					end
    					if ok and type(state) == "string" and tonumber(stamp) then
    						Hop.state, Hop.stamp = state, tonumber(stamp)
    					end
    				end
    				return Hop.state, Hop.stamp
    			end
    
    			local function hopNow(reason)
    				if Hop.teleporting then return end
    				if S.stayPrivate and tostring(game.PrivateServerId or "") ~= "" then
    					Hop.status = "Private server, staying"
    					if os.clock() - (Hop.privateWarn or -1e9) > 300 then
    						Hop.privateWarn = os.clock()
    						queueToast("UFO Hop", "Hop skipped: you are on a private server (Stay On Private Server)")
    						if Auto.log then
    							Auto.log("HOP", "skipped private server", tostring(reason))
    						end
    					end
    					return
    				end
    				Hop.lastHop = os.clock()
    				local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true", game.PlaceId)
    				local body = nil
    				local response = httpRequest({ Url = url, Method = "GET" })
    				if response and type(response.Body) == "string" and response.Body ~= "" then
    					body = response.Body
    				else
    					local ok, result = pcall(function() return game:HttpGet(url) end)
    					body = if ok then result else nil
    				end
    				local candidates = {}
    				pcall(function()
    					local data = HttpService:JSONDecode(body)
    					for _, server in ipairs(data.data or {}) do
    						local playing, max = tonumber(server.playing), tonumber(server.maxPlayers)
    						if type(server.id) == "string" and server.id ~= game.JobId and playing and max and playing < max and not table.find(Hop.visited, server.id) then
    							table.insert(candidates, server.id)
    						end
    					end
    				end)
    				if #candidates == 0 then
    					Hop.status = "No new servers, trying again"
    					if #Hop.visited > 10 then
    						Hop.visited = { table.unpack(Hop.visited, #Hop.visited - 9) }
    					end
    					return
    				end
    				local target = candidates[math.random(1, #candidates)]
    				table.insert(Hop.visited, game.JobId)
    				while #Hop.visited > 60 do
    					table.remove(Hop.visited, 1)
    				end
    				Hop.hops += 1
    				hopSave(true)
    				queueReload()
    				Hop.teleporting = true
    				Hop.status = "Hopping"
    				queueToast("UFO Hop", string.format("Hop %d: %s", Hop.hops, reason))
    				local ok = pcall(function()
    					game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, target, LocalPlayer)
    				end)
    				if ok then
    					task.delay(15, function()
    						Hop.teleporting = false
    						Hop.status = "Teleport did not go through, trying again"
    					end)
    				else
    					Hop.teleporting = false
    					table.insert(Hop.visited, target)
    				end
    			end
    
    			pcall(function()
    				Library:GiveSignal(game:GetService("TeleportService").TeleportInitFailed:Connect(function(player)
    					if player == LocalPlayer then
    						Hop.teleporting = false
    					end
    				end))
    			end)
    
    			task.spawn(function()
    				while alive() do
    					task.wait(2)
    					pcall(hookEvent, "ufoState", "AlienEventService", "UI", function(state, stamp)
    						if state == true then
    							state = "Active"
    						elseif state == false then
    							state = "Idle"
    						end
    						if type(state) == "string" and tonumber(stamp) then
    							Hop.state, Hop.stamp = state, tonumber(stamp)
    							Hop.lastQuery = os.clock()
    						end
    					end)
    					local ok, err = pcall(function()
    						local state, stamp = ufoState()
    						local now = serverNow()
    						Hop.left = if stamp then math.max(0, stamp - now) else nil
    						local egg = workspace:FindFirstChild("AlienEventEgg")
    						local active = egg ~= nil or (state == "Active" and Hop.left ~= nil and Hop.left > 0)
    						Hop.active = active
    						if state == "Idle" and stamp and not active then
    							local mine = nil
    							for _, entry in ipairs(Hop.seen) do
    								if entry.job == game.JobId then
    									mine = entry
    								end
    							end
    							if not mine then
    								for _, entry in ipairs(Hop.seen) do
    									if tonumber(entry.stamp) then
    										local gap = math.abs(entry.stamp - stamp)
    										if gap <= 5 then
    											Hop.global = true
    										elseif gap > 30 and Hop.global == nil then
    											Hop.global = false
    										end
    									end
    								end
    								table.insert(Hop.seen, { job = game.JobId, stamp = stamp })
    								while #Hop.seen > 10 do
    									table.remove(Hop.seen, 1)
    								end
    							else
    								mine.stamp = stamp
    							end
    						end
    						if not S.ufoHop then
    							Hop.status = "Off"
    							return
    						end
    						if Hop.teleporting then
    							return
    						end
    						if os.clock() - Hop.arrivedAt < 6 then
    							Hop.status = "Checking this server"
    							return
    						end
    						if active then
    							local eligible = LocalPlayer:GetAttribute("AlienEggEligible") == true
    							if eligible or egg == nil then
    								Hop.ineligibleSince = nil
    								if not Hop.found then
    									Hop.found = true
    									queueToast("UFO Hop", if Hop.hops > 0 then string.format("Found the UFO after %d hop%s", Hop.hops, if Hop.hops == 1 then "" else "s") else "The UFO is on this server")
    									if not S.autoUfo then
    										Auto.enableUfo = true
    									end
    								end
    								Hop.status = "Breaking the UFO"
    								return
    							end
    							Hop.ineligibleSince = Hop.ineligibleSince or os.clock()
    							if os.clock() - Hop.ineligibleSince < 12 then
    								Hop.status = "Waiting to be eligible"
    								return
    							end
    							if os.clock() - Hop.lastHop >= 8 then
    								hopNow("not eligible for this UFO")
    							end
    							return
    						end
    						Hop.ineligibleSince = nil
    						if Hop.found then
    							Hop.found = false
    							if not S.ufoHopChase then
    								Auto.stopUfoHop = "The UFO is down, hop finished"
    								return
    							end
    							Hop.hops = 0
    						end
    						if state == "Incoming" and Hop.left and Hop.left > 0 then
    							Hop.status = "UFO landing in " .. formatClock(Hop.left) .. ", staying"
    							return
    						end
    						local window = tonumber(S.ufoHopWindow) or 60
    						if Hop.left and state == "Idle" and Hop.left <= window then
    							Hop.status = "UFO in " .. formatClock(Hop.left) .. ", staying"
    							return
    						end
    						if Hop.global == true and state == "Idle" then
    							Hop.status = "Same timer everywhere, waiting here"
    							return
    						end
    						if Hop.hops >= 40 then
    							Auto.stopUfoHop = "Stopped after 40 hops"
    							return
    						end
    						if os.clock() - Hop.lastHop < 8 then
    							return
    						end
    						hopNow(if Hop.left then "next UFO in " .. formatClock(Hop.left) else "no UFO here")
    					end)
    					if not ok then
    						diag("ufohop", err)
    					end
    				end
    			end)
    
    			Auto.luckInfo = function()
    				local pets = loadEggPets()
    				local egg = if S.indexHunt and Hunter.egg then Hunter.egg else S.hatchEggName
    				local list = pets and egg and pets[egg] or nil
    				local info = { egg = egg, tiers = {} }
    				for tier, tierRank in pairs({ Legendary = 4, Mythical = 5, Secret = 7 }) do
    					local percent = 0
    					if list then
    						for _, pet in ipairs(list) do
    							if (RarityRank[pet.rarity] or 0) >= tierRank then
    								percent += pet.percent
    							end
    						end
    					end
    					local last = tonumber(Saved.lastTierAt[tier]) or tonumber(Saved.luckStart) or 0
    					info.tiers[tier] = {
    						expected = if percent > 0 then 100 / percent else nil,
    						since = math.max(0, Saved.eggs - last),
    					}
    				end
    				return info
    			end
    			Extra.collect = function()
    				local tree = treeInfo()
    				tree.status = Tree.status
    				tree.last = Tree.last
    				Snap.tree = tree
    				local special = specialInfo()
    				special.status = Special.status
    				Snap.special = special
    				local rebirth = rebirthInfo()
    				rebirth.status = Rebirth.status
    				Snap.rebirth = rebirth
    				local done = 0
    				for _, code in ipairs(Codes.order) do
    					if FinalCodes[Saved.codes[code]] then
    						done += 1
    					end
    				end
    				Snap.codes = { found = #Codes.order, done = done, status = Codes.status, last = Codes.last }
    				Snap.hop = { status = Hop.status, left = Hop.left, state = Hop.state, active = Hop.active, hops = Hop.hops, global = Hop.global }
    				local okLuck, luck = pcall(Auto.luckInfo)
    				if okLuck then
    					Snap.luck = luck
    				end
    				Snap.rubies = getStat("Rubies")
    			end
    		end
    		setupExtras()
    
    		local function returnTo(back)
    			if not (back and back.world and alive()) then return end
    			Mover.task = "Returning"
    			local okTravel, reached = pcall(travelTo, back.world)
    			local root = getRoot()
    			if okTravel and reached and root and getWorldAt(root.Position) == back.world then
    				pcall(function() root.AssemblyLinearVelocity = Vector3.zero end)
    				root.CFrame = back.cframe
    			end
    		end
    
    		local function eggTravelWanted(now)
    			if not (((S.autoHatch and S.eggAutoTravel) or S.farmOP) and EggTravel.need) then return false end
    			if S.autoFish and S.fishPriority == "Fishing first" then return false end
    			if S.indexHunt and Hunter.egg then return false end
    			if EggTravel.need ~= (if Auto.effectiveEgg then Auto.effectiveEgg() else S.hatchEggName) then
    				EggTravel.need = nil
    				return false
    			end
    			return now - EggTravel.lastTry > 6 and now >= EggTravel.blockedUntil
    		end
    
    		local function eggTravel()
    			local name = EggTravel.need
    			EggTravel.need = nil
    			EggTravel.lastTry = os.clock()
    			if not name or name == "" then return end
    			Mover.busy = true
    			Mover.task = "Going to " .. name
    			local ok, result, err = pcall(moveToEgg, name)
    			if ok and result then
    				EggTravel.fails = 0
    			else
    				EggTravel.fails += 1
    				if EggTravel.fails >= 3 then
    					EggTravel.fails = 0
    					EggTravel.blockedUntil = os.clock() + 60
    					queueToast("Eggs", "Could not reach " .. name .. ": " .. (if ok then tostring(err) else shortError(result)))
    				end
    			end
    			Mover.busy = false
    			Mover.task = ""
    		end
    
    		local function roundTrips(now, ufoBusy)
    			if S.autoUfo and S.ufoTravel and Ufo.needTravel and now - Ufo.travelTry > 20 then
    				ufoTrip()
    				return true
    			end
    			if Ufo.returnNow then
    				Ufo.returnNow = false
    				local back = Ufo.back
    				Ufo.back = nil
    				if back and not Mover.busy then
    					Mover.busy = true
    					pcall(returnTo, back)
    					Mover.busy = false
    					Mover.task = ""
    				end
    				return true
    			end
    			return false
    		end
    
    		local function lateTrips(now, ufoBusy)
    			if ufoBusy then return false end
    			local shop = shopNeedsTrip(now)
    			if shop then
    				runErrand("Upgrades", function() shopTrip(shop) end)
    				return true
    			end
    			if Worlds.needPad then
    				local info = Worlds.needPad
    				Worlds.needPad = nil
    				runErrand("Buying " .. prettyWorld(info.next), function() buyWorld(info, true) end)
    				return true
    			end
    			local label, errand = Extra.nextErrand(now)
    			if label then
    				runErrand(label, errand)
    				return true
    			end
    			return false
    		end
    
    		local function collectRound()
    			local ufo = ufoInfo()
    			ufo.status = Ufo.status
    			ufo.engaged = Ufo.engaged
    			ufo.rank, ufo.myDmg, ufo.topDmg, ufo.helped = Ufo.myRank, Ufo.myDmg, Ufo.topDmg, Ufo.hitThisEgg
    			Snap.ufo = ufo
    			local worlds = worldInfo()
    			worlds.here = currentWorld()
    			worlds.status = Worlds.status
    			Snap.worlds = worlds
    			local shops = {}
    			for _, shop in ipairs(allShops()) do
    				local snap = shopSnapshot(shop)
    				snap.status = shopStateOf(shop).status
    				shops[shop.id] = snap
    			end
    			Snap.shops = shops
    			Snap.gems = getStat("Gems")
    			Snap.rubies = getStat("Rubies")
    			Snap.moonRebirths = tonumber(readData("MoonRebirthData", "Rebirths"))
    			Snap.team = teamSnapshot()
    			local boost = tonumber(readData("VariousBoosts", "FriendBoostCoins"))
    			Snap.friends = {
    				percent = if boost then math.max(0, (boost - 1) * 100) else nil,
    				here = Friends.here,
    				total = Friends.total,
    				sent = Friends.count,
    				acceptOk = Friends.acceptOk,
    			}
    			Extra.collect()
    		end
    
    		Auto.Ufo = Ufo
    		Auto.EggTravel = EggTravel
    		Auto.collectRound = collectRound
    
    		local function hunterMove()
    			local egg = Hunter.egg
    			if not egg then return end
    			Mover.busy = true
    			Mover.task = "Going to " .. egg
    			local ok, result, err = pcall(moveToEgg, egg)
    			if ok and result then
    				Hunter.moveFails = 0
    			else
    				Hunter.moveFails += 1
    				local message = if ok then tostring(err) else shortError(result)
    				if Hunter.moveFails >= 3 then
    					Hunter.blocked[egg] = os.clock() + 120
    					Hunter.egg = nil
    					queueToast("Index Hunter", "Skipping " .. egg .. " for now: " .. message)
    				end
    			end
    			Hunter.needMove = false
    			Mover.busy = false
    			Mover.task = ""
    		end
    
    		local function petSignature()
    			local pets = getDataFolder("PetsData")
    			if not pets then return nil, nil end
    			local total, equipped = 0, 0
    			for _, folderName in ipairs({ "NormalPetsData", "GoldenPetsData", "DiamondPetsData" }) do
    				local folder = pets:FindFirstChild(folderName)
    				if folder then
    					for _, entry in ipairs(folder:GetChildren()) do
    						local amount = entry:FindFirstChild("Amount")
    						local eq = entry:FindFirstChild("Equipped")
    						local okA, a = pcall(function() return amount and amount.Value end)
    						local okE, e = pcall(function() return eq and eq.Value end)
    						total += if okA then tonumber(a) or 0 else 0
    						if okE then
    							if type(e) == "boolean" then
    								equipped += if e then 1 else 0
    							else
    								equipped += tonumber(e) or 0
    							end
    						end
    					end
    				end
    			end
    			return total, equipped
    		end
    
    		Auto.equipBestNow = function(manual)
    			local remote = Auto.knitRemote("PetsService", "RE", "Action")
    			if not remote then
    				if manual then
    					queueToast("Pets", "Equip remote not found")
    				end
    				return false
    			end
    			if Equip.fired and os.clock() - Equip.lastFire < 1.2 then
    				return false
    			end
    			Equip.lastFire = os.clock()
    			Equip.fired = true
    			pcall(function() remote:FireServer("EquipBest") end)
    			if manual then
    				queueToast("Pets", "Equipped your best pets")
    			end
    			return true
    		end
    
    		local function luckyStep()
    			local now = os.clock()
    			local grow = Auto.knitRemote("LuckyBlockService", "RE", "Grow")
    			if not S.autoLucky then
    				Lucky.status = if Lucky.active then "Opening" else "Idle"
    				return
    			end
    			if Lucky.active then
    				if now - Lucky.spawnAt > 15 then
    					Lucky.active = false
    					Lucky.claimedAt = now
    					return
    				end
    				if grow and now - Lucky.spawnAt >= 0.8 and now - Lucky.lastGrow >= 0.22 and Lucky.sent < Lucky.maxClicks + 3 then
    					Lucky.lastGrow = now
    					Lucky.sent += 1
    					pcall(function() grow:FireServer() end)
    				end
    				Lucky.status = string.format("Clicking %d / %d", math.min(math.max(Lucky.clicks, Lucky.sent), Lucky.maxClicks), Lucky.maxClicks)
    				return
    			end
    			if Lucky.waitingSpawn then
    				if now - Lucky.lastOpen < 2.5 then
    					Lucky.status = "Opening"
    					return
    				end
    				Lucky.waitingSpawn = false
    				if grow then
    					Lucky.active = true
    					Lucky.spawnAt = now - 0.8
    					Lucky.sent = 0
    					Lucky.clicks = 0
    					Lucky.maxClicks = 3
    					Lucky.count = 0
    				end
    				return
    			end
    			if now - Lucky.claimedAt < 1.7 then
    				Lucky.status = "Collecting"
    				return
    			end
    			local open = Auto.knitRemote("LuckyBlockService", "RE", "Open")
    			if not open then
    				Lucky.status = "Unavailable"
    				return
    			end
    			for _, name in ipairs(Items.Lucky) do
    				local count = tonumber(readData("MiscData", name)) or 0
    				if S.luckyPick[name] and count > 0 then
    					local cap = tonumber(S.luckyBatch) or 8
    					local usable = math.min(cap, count)
    					local amount = if usable >= 8 then 8 elseif usable >= 3 then 3 else 1
    					Lucky.lastOpen = now
    					Lucky.waitingSpawn = true
    					Lucky.status = string.format("Opening %dx", amount)
    					Lucky.pendingAmount = amount
    					pcall(function() open:FireServer(name, amount) end)
    					return
    				end
    			end
    			Lucky.status = "Nothing to open"
    		end
    
    		task.spawn(function()
    			while alive() do
    				task.wait(0.2)
    				local ok, err = pcall(luckyStep)
    				if not ok then
    					diag("lucky", err)
    				end
    			end
    		end)
    
    		local function useSplit(remote, name, total)
    		local left = math.max(0, math.floor(total))
    		local fired = 0
    		for _, n in ipairs({ 25, 10, 5, 1 }) do
    			while left >= n and fired < 8 do
    				local amount = n
    				pcall(function() remote:FireServer(name, amount) end)
    				left -= n
    				fired += 1
    				if left > 0 then
    					task.wait(0.2)
    				end
    			end
    		end
    	end
    
    	local function chunkFor(count)
    			for _, n in ipairs({ 25, 10, 5, 1 }) do
    				if count >= n then
    					return n
    				end
    			end
    			return 0
    		end
    
    		local function trackCount(folderName, name, savedKey)
    			local count = tonumber(readData(folderName, name)) or 0
    			local key = folderName .. "/" .. name
    			local last = ItemTrack.lastCount[key]
    			ItemTrack.lastCount[key] = count
    			if last and count < last and os.clock() - (ItemTrack.lastUse[name] or -1e9) < 8 then
    				Saved[savedKey] = (tonumber(Saved[savedKey]) or 0) + (last - count)
    				SaveDirty = true
    			end
    			return count
    		end
    
    		local function itemsStep()
    			local now = os.clock()
    			local useRemote = Auto.knitRemote("ConsumablesService", "RE", "UseItem")
    			for _, name in ipairs(Items.Fruits) do
    				local count = trackCount("FruitsData", name, "fruitsUsed")
    				if S.autoFruits and useRemote and S.fruitPick[name] and count > 0 and now - (ItemTrack.lastUse[name] or -1e9) >= 2.5 then
    					local left = tonumber(readData("FruitsTimeData", name)) or 0
    					local amount = if S.fruitMode == "Use all" then chunkFor(count) elseif left <= 1 then math.min(S.fruitRefill or 1, count) else 0
    					if amount > 0 then
    						ItemTrack.lastUse[name] = now
    						useSplit(useRemote, name, amount)
    					end
    				end
    			end
    			for _, name in ipairs(Items.Potions) do
    				local count = trackCount("PotionsData", name, "potionsUsed")
    				if S.autoPotions and useRemote and S.potionPick[name] and count > 0 and now - (ItemTrack.lastUse[name] or -1e9) >= 2.5 then
    					local amount = 0
    					if S.potionMode == "Use all" then
    						amount = chunkFor(count)
    					else
    						local left = tonumber(readData("PotionsTimeData", name)) or 0
    						local blocked = left > 1
    						for _, higher in ipairs(Auto.higherPotions(name)) do
    							local higherLeft = tonumber(readData("PotionsTimeData", higher)) or 0
    							local higherReady = S.potionPick[higher] and (tonumber(readData("PotionsData", higher)) or 0) > 0
    							if higherLeft > 1 or higherReady then
    								blocked = true
    							end
    						end
    						amount = if blocked then 0 else math.min(S.potionRefill or 1, count)
    					end
    					if amount > 0 then
    						ItemTrack.lastUse[name] = now
    						useSplit(useRemote, name, amount)
    					end
    				end
    			end
    			do
    				local VC = Auto.VipChest
    				local upper = tonumber(readData("MiscData", "VIPUpper")) or 0
    				local lower = tonumber(readData("MiscData", "VIPLower")) or 0
    				if VC then
    					VC.keys = tonumber(readData("MiscData", "VIPKey")) or 0
    					VC.halves = math.min(upper, lower)
    				end
    				-- KeyCraftService:Craft("VIPKey", amount) joins an upper and a lower half into one key, max 500 per call.
    				if S.autoKeyCraft and VC and math.min(upper, lower) >= 1 and now - (VC.craftAt or -1e9) > 5 then
    					VC.craftAt = now
    					local amount = math.min(upper, lower, 500)
    					local ok = Auto.invokeTimeout(Auto.knitRemote("KeyCraftService", "RF", "Craft"), 8, "VIPKey", amount)
    					if ok then
    						VC.crafted += amount
    					end
    				end
    			end
    			do
    				Auto.Extras = Auto.Extras or { partnerAt = -1e9, zoneAt = -1e9, craftAt = -1e9, crafted = 0 }
    				local X = Auto.Extras
    				-- PartnerRewardsService: ClaimRequest works only for partner ranks, the server answers NotPartner otherwise.
    				if S.autoPartner and now - X.partnerAt > 600 then
    					X.partnerAt = now
    					local claim = Auto.knitRemote("PartnerRewardsService", "RE", "ClaimRequest")
    					if claim then
    						pcall(function()
    							claim:FireServer()
    						end)
    					end
    				end
    				-- UniverseZoneService.Purchase: one time unlock with a Universe Key (UniverseData).
    				if S.autoUniverseZone and now - X.zoneAt > 30 and readData("UniverseData", "UniverseZoneUnlocked") ~= true and (tonumber(readData("UniverseData", "UniverseKey")) or 0) >= 1 then
    					X.zoneAt = now
    					local buy = Auto.knitRemote("UniverseZoneService", "RE", "Purchase")
    					if buy then
    						pcall(function()
    							buy:FireServer()
    						end)
    						queueToast("Universe Zone", "Unlocking with your Universe Key")
    					end
    				end
    				-- EventCraftService:Craft(id, amount): turns event pets into 1M Lucky Blocks, max 100 per call.
    				if S.autoEventCraft and now - X.craftAt > 10 then
    					X.craftAt = now
    					local config = Auto.lazyRequire("EventCraftConfig", function()
    						local modules = ReplicatedStorage:FindFirstChild("Modules")
    						return modules and modules:FindFirstChild("EventCraftConfig")
    					end)
    					local craft = Auto.knitRemote("EventCraftService", "RF", "Craft")
    					if type(config) == "table" and type(config.Recipes) == "table" and type(config.Owned) == "function" and craft then
    						for _, recipe in ipairs(config.Recipes) do
    							if S.eventCraftPick[tostring(recipe.Pet)] then
    								local okOwned, owned = pcall(config.Owned, LocalPlayer, recipe)
    								local cost = math.max(tonumber(recipe.Cost) or 1, 1)
    								local amount = if okOwned then math.min(math.floor((tonumber(owned) or 0) / cost), tonumber(config.MAX_CRAFT_PER_REQUEST) or 100) else 0
    								if amount >= 1 then
    									local ok = Auto.invokeTimeout(craft, 8, recipe.Id, amount)
    									if ok then
    										X.crafted += amount
    										queueToast("Event Craft", string.format("Crafted %d x %s", amount, tostring(config.RESULT_TITLE or "Lucky Block")))
    									end
    									break
    								end
    							end
    						end
    					end
    				end
    			end
    			if S.autoEquip or S.farmOP then
    				local total = petSignature()
    				if total and ((Equip.lastSig ~= total and (not Equip.fired or now - Equip.lastFire >= 6)) or now - Equip.lastFire >= 90) then
    					if Auto.equipBestNow(false) then
    						Equip.lastSig = total
    					end
    				end
    			end
    		end
    
    		task.spawn(function()
    			local nextFruit, nextGroup, nextMoon, nextMember = 0, 0, 0, 0
    			while alive() do
    				pcall(hookEvents)
    				local now = os.clock()
    				if now >= nextMember then
    					local ok, inGroup = pcall(function()
    						return LocalPlayer:IsInGroup(GROUP_ID)
    					end)
    					if ok and type(inGroup) == "boolean" then
    						GC.member = inGroup
    					end
    					nextMember = os.clock() + (if GC.member then 600 else 90)
    				end
    				if FM.pollNow or now >= nextFruit then
    					FM.pollNow = false
    					local ok, left = Auto.invokeTimeout(Auto.knitRemote("FruitMachineService", "RF", "GetCooldownRemaining"), 8)
    					left = if ok then tonumber(left) else nil
    					if left then
    						left = math.max(0, left)
    						FM.left, FM.leftAt = left, os.clock()
    						if left <= 0 then
    							FM.total = nil
    						elseif left > (FM.total or 0) then
    							FM.total = left
    						end
    					end
    					nextFruit = os.clock() + (if S.autoFruitMachine then 5 else 20)
    				end
    				if GC.pollNow or now >= nextGroup then
    					GC.pollNow = false
    					local ok, result = Auto.invokeTimeout(Auto.knitRemote("GroupChestService", "RF", "IsAvailable"), 8)
    					if ok then
    						if result == true then
    							GC.avail = true
    						elseif tonumber(result) then
    							local left = math.max(0, tonumber(result))
    							GC.avail = if left <= 0 then true else left
    							GC.availAt = os.clock()
    							if left > (GC.total or 0) then
    								GC.total = left
    							end
    						elseif result == false then
    							GC.avail = false
    						end
    					end
    					nextGroup = os.clock() + (if S.autoGroupChest then 20 else 60)
    				end
    				if Quest.pollDaily or now >= Quest.nextDaily then
    			Quest.pollDaily = false
    			local ok, left, day = Auto.invokeTimeout(Auto.knitRemote("DailyRewardsService", "RF", "GetState"), 8)
    			if ok and tonumber(left) then
    				Quest.dailyLeft = math.max(0, tonumber(left))
    				Quest.dailyAt = os.clock()
    				Quest.dailyDay = tonumber(day) or Quest.dailyDay
    			end
    			Quest.nextDaily = os.clock() + 60
    		end
    		if MC.pollNow or now >= nextMoon then
    					MC.pollNow = false
    					local ok, status = Auto.invokeTimeout(Auto.knitRemote("MoonChestService", "RF", "GetStatus"), 8)
    					if ok and type(status) == "table" then
    						local readyAt = tonumber(status.ReadyAt)
    						if readyAt then
    							MC.readyAt = readyAt
    							local left = readyAt - serverNow()
    							if left <= 0 then
    								MC.total = nil
    							elseif left > (MC.total or 0) then
    								MC.total = left
    							end
    						end
    						MC.luck = tonumber(status.LuckPercent) or MC.luck
    					end
    					nextMoon = os.clock() + (if S.autoMoonChest then 15 else 45)
    				end
    				task.wait(0.5)
    			end
    		end)
    
    		task.spawn(function()
    			while alive() do
    				task.wait(1)
    				if not Mover.busy and alive() then
    					local now = os.clock()
    					local ok, err = pcall(function()
    						local fruit = fruitMachineInfo()
    						local moon = moonChestInfo()
    						local ufoBusy = S.autoUfo and Ufo.engaged
    						if roundTrips(now, ufoBusy) then
    							return
    						elseif ufoBusy then
    							return
    						elseif S.autoFruitMachine and fruit.ready and fruit.affordable and now - FM.lastTry > 30 and not (Auto.fruitGameAuto and Auto.fruitGameAuto()) then
    							runErrand("Fruit Machine", doFruitMachine)
    						elseif S.autoGroupChest and GC.avail == true and now - GC.lastTry > 45 then
    							runErrand("Group Chest", doGroupChest)
    						elseif S.autoMoonChest and moon.unlocked ~= false and moon.ready and now - MC.lastTry > 45 then
    							runErrand("Moon Chest", doMoonChest)
    						elseif Auto.vipChestDue(now) then
    							runErrand("VIP Chest", Auto.doVipChest)
    						elseif S.indexHunt and Hunter.craftPending and now - Hunter.lastCraftTry > 10 then
    							runErrand("Index Hunter", doCraftTrip)
    						elseif wantsAutoCraft(now) then
    							runErrand("Crafting", doAutoCraft)
    						elseif Auto.fishCraftDue(now) then
    							runErrand("Fishing Index crafting", Auto.doFishCraft)
    						elseif lateTrips(now, ufoBusy) then
    							return
    						elseif S.indexHunt and Hunter.egg and Hunter.needMove then
    							hunterMove()
    						elseif eggTravelWanted(now) then
    							eggTravel()
    						elseif Auto.fishStep and Auto.fishStep(now) then
    							return
    						elseif Auto.farmWorldStep then
    							Auto.farmWorldStep(now)
    						end
    					end)
    					if not ok then
    						Mover.busy = false
    						Mover.task = ""
    						diag("errand", err)
    					end
    				end
    			end
    		end)
    
    		task.spawn(function()
    			while alive() do
    				task.wait(1)
    				local ok, err = pcall(itemsStep)
    				if not ok then
    					diag("items", err)
    				end
    				local okQuest, errQuest = pcall(questStep)
    				if not okQuest then
    					diag("quests", errQuest)
    				end
    			end
    		end)
    
    		local function collectMachines()
    			Snap.fm = fruitMachineInfo()
    			Snap.gc = groupChestInfo()
    			Snap.mc = moonChestInfo()
    			Snap.errand = if Mover.busy then Mover.task else ""
    			local nextName, nextLeft = nil, math.huge
    			local function consider(on, name, left, ready)
    				if not on then return end
    				local value = if ready then 0 else left
    				if value and value < nextLeft then
    					nextName, nextLeft = name, value
    				end
    			end
    			consider(S.autoFruitMachine and not (Auto.fruitGameAuto and Auto.fruitGameAuto()), "Fruit Machine", Snap.fm.left, Snap.fm.ready and Snap.fm.affordable)
    			consider(S.autoGroupChest and Snap.gc.member ~= false, "Group Chest", Snap.gc.left, Snap.gc.ready)
    			consider(S.autoMoonChest and Snap.mc.unlocked ~= false, "Moon Chest", Snap.mc.left, Snap.mc.ready)
    			Snap.nextStop = if nextName then { name = nextName, left = nextLeft } else nil
    		end
    
    		local function collectItems()
    			local items = { fruits = {}, potions = {}, lucky = {} }
    			for _, name in ipairs(Items.Fruits) do
    				items.fruits[name] = {
    					count = tonumber(readData("FruitsData", name)) or 0,
    					left = tonumber(readData("FruitsTimeData", name)) or 0,
    				}
    			end
    			for _, name in ipairs(Items.Potions) do
    				local left = tonumber(readData("PotionsTimeData", name)) or 0
    				local paused = false
    				if left > 0 then
    					for _, higher in ipairs(Auto.higherPotions(name)) do
    						if (tonumber(readData("PotionsTimeData", higher)) or 0) > 0 then
    							paused = true
    						end
    					end
    				end
    				items.potions[name] = {
    					count = tonumber(readData("PotionsData", name)) or 0,
    					left = left,
    					paused = paused,
    				}
    			end
    			for _, name in ipairs(Items.Lucky) do
    				items.lucky[name] = tonumber(readData("MiscData", name)) or 0
    			end
    			local equipped, maxEquip
    			local equipModule = Auto.lazyRequire("EquippedPetsModule", function()
    				local modules = ReplicatedStorage:FindFirstChild("Modules")
    				return modules and modules:FindFirstChild("EquippedPetsModule")
    			end)
    			if type(equipModule) == "table" then
    				local okTotal, total = pcall(equipModule.GetTotal, LocalPlayer)
    				local okMax, max = pcall(equipModule.GetMaxEquip, LocalPlayer)
    				if okTotal then equipped = tonumber(total) end
    				if okMax then maxEquip = tonumber(max) end
    			end
    			if not equipped then
    				local _, counted = petSignature()
    				equipped = counted
    			end
    			items.equipped = equipped
    			items.maxEquip = maxEquip or tonumber(readData("PetsDataData", "MaxEquip"))
    			items.goldenReady = #craftableList("Golden")
    			items.diamondReady = #craftableList("Diamond")
    			items.craftStatus = if Mover.busy and string.find(Mover.task, "Crafting", 1, true) then Mover.task else AutoCraft.status
    			items.lastEquip = if Equip.fired then os.clock() - Equip.lastFire else nil
    			items.luckyStatus = Lucky.status
    			items.luckyLast = Lucky.last
    			Snap.items = items
    		end
    
    		local function collectHunt()
    			local hunt = { on = S.indexHunt, allDone = Hunter.allDone, allTotal = Hunter.allTotal, crafting = Hunter.craftPending }
    			if S.indexHunt then
    				hunt.egg = Hunter.egg
    				hunt.world = Hunter.world
    				if Mover.busy and Mover.task ~= "" then
    					hunt.status = Mover.task
    				elseif Hunter.egg then
    					hunt.status = HatchState.status
    				else
    					hunt.status = Hunter.status
    				end
    				if Hunter.egg then
    					hunt.visual = getEggVisual(Hunter.egg)
    				end
    				local focus = Hunter.focus
    				if focus then
    					local plan = petPlan(focus.name, Hunter.reqG or 8, Hunter.reqD or 6)
    					hunt.pet = focus.name
    					hunt.rarity = focus.rarity
    					hunt.percent = focus.percent
    					hunt.icon = petIcon(focus.name)
    					hunt.availN = plan.availN
    					hunt.availG = plan.availG
    					hunt.normNeeded = plan.normNeeded
    					hunt.goldNeeded = if plan.wantD then Hunter.reqD or 6 else 0
    					local function state(selected, want)
    						if not selected then return "skip" end
    						return if want then "missing" else "done"
    					end
    					hunt.variants = {
    						state(S.huntVariants.Normal, plan.wantN),
    						state(S.huntVariants.Golden, plan.wantG),
    						state(S.huntVariants.Diamond, plan.wantD),
    					}
    				end
    			end
    			Snap.hunt = hunt
    		end
    
    		Auto.setupLive = function()
    			local Live = { feed = {}, seq = 0, disabled = {}, galleryAt = -1e9, goalsAt = -1e9, skipAt = -1e9, indexCount = nil, indexTotal = nil }
    			Auto.Live = Live
    			local Prefixes = { Normal = "", Golden = "Golden ", Diamond = "Diamond " }
    
    			local function baseName(name)
    				return string.match(name, "^Golden (.+)$") or string.match(name, "^Diamond (.+)$") or name
    			end
    
    			local function eggPercent(egg, name)
    				local pets = loadEggPets()
    				local list = pets and egg and pets[egg]
    				if not list then return nil end
    				local base = baseName(name)
    				for _, pet in ipairs(list) do
    					if pet.name == base then
    						return pet.percent
    					end
    				end
    				return nil
    			end
    
    			local function oneIn(percent)
    				percent = tonumber(percent)
    				if not percent or percent <= 0 then return nil end
    				local n = 100 / percent
    				if n < 1.05 then return "every egg" end
    				if n < 10 then
    					return "1 in " .. (string.gsub(string.format("%.1f", n), "%.0$", ""))
    				end
    				return "1 in " .. (string.gsub(formatNumber(math.floor(n + 0.5)), "[kmbt]$", string.upper))
    			end
    			Auto.oneIn = oneIn
    
    			local function takeFeed()
    				local raw = Auto.FeedRaw
    				if not raw or #raw == 0 then return false end
    				Auto.FeedRaw = {}
    				for _, batch in ipairs(raw) do
    					local egg = batch.egg
    					if not egg or egg == "" then
    						egg = if S.indexHunt and Hunter.egg then Hunter.egg else S.hatchEggName
    					end
    					local groups, order = {}, {}
    					for _, pet in ipairs(batch.names) do
    						local key = pet.name .. "|" .. tostring(pet.mutation or "")
    						local group = groups[key]
    						if not group then
    							group = { name = pet.name, rarity = pet.rarity, count = 0, fresh = false, mutation = pet.mutation }
    							groups[key] = group
    							table.insert(order, group)
    						end
    						group.count += 1
    						group.fresh = group.fresh or pet.fresh == true
    					end
    					table.sort(order, function(a, b)
    						local ra, rb = RarityRank[a.rarity] or 0, RarityRank[b.rarity] or 0
    						if ra ~= rb then return ra > rb end
    						if (a.mutation ~= nil) ~= (b.mutation ~= nil) then return a.mutation ~= nil end
    						return a.name < b.name
    					end)
    					for i = #order, 1, -1 do
    						local group = order[i]
    						Live.seq += 1
    						local variant = if string.sub(group.name, 1, 7) == "Golden " then "Golden" elseif string.sub(group.name, 1, 8) == "Diamond " then "Diamond" else nil
    						local sub = {}
    						local mutationLabel, mutationColor, mutationFirst = Auto.mutationInfo(group.mutation)
    						local chance = oneIn(eggPercent(egg, group.name))
    						if chance then
    							table.insert(sub, chance)
    						end
    						if egg and egg ~= "" then
    							table.insert(sub, egg)
    						end
    						table.insert(Live.feed, 1, {
    							Id = Live.seq,
    							Title = if mutationLabel then mutationLabel .. " " .. group.name else group.name,
    							Count = group.count,
    							Image = petIcon(group.name) or petIcon(baseName(group.name)) or GameIcons.Egg,
    							Color = RarityColors[group.rarity] or RarityColors.Basic,
    							Right = group.rarity,
    							Sub = table.concat(sub, "  \u{00B7}  "),
    							At = batch.at,
    							Badge = if group.fresh then "NEW" elseif mutationFirst then string.upper(mutationFirst) elseif variant == "Golden" then "GOLD" elseif variant == "Diamond" then "DIAMOND" else nil,
    							BadgeColor = if group.fresh then "#7dffb3" elseif mutationFirst then mutationColor elseif variant == "Golden" then "#ffcf4d" else "#8fe9ff",
    						})
    					end
    				end
    				while #Live.feed > 30 do
    					table.remove(Live.feed)
    				end
    				return true
    			end
    
    			local function buildGallery()
    				local catalog = petCatalog()
    				if not catalog then
    					Snap.gallery = nil
    					return
    				end
    				local pick = S.huntRarity or {}
    				local anyPick = next(pick) ~= nil
    				local known = {}
    				local lists = { Normal = {}, Golden = {}, Diamond = {} }
    				local totals = { Normal = 0, Golden = 0, Diamond = 0 }
    				local count, total = 0, 0
    				local huntEgg = if S.indexHunt then Hunter.egg else nil
    				local focus = if S.indexHunt and Hunter.focus then Hunter.focus.name else nil
    				local unlocked = {}
    				for name, entry in pairs(catalog) do
    					local best, bestEgg, locked = nil, nil, true
    					for egg, percent in pairs(entry.eggs) do
    						local world = EggWorlds[egg] or "Spawn"
    						local open = unlocked[world]
    						if open == nil then
    							open = isWorldUnlocked(world) ~= false
    							unlocked[world] = open
    						end
    						if open then
    							locked = false
    							if not best or percent > best then
    								best, bestEgg = percent, egg
    							end
    						end
    					end
    					if not best then
    						for egg, percent in pairs(entry.eggs) do
    							if not best or percent > best then
    								best, bestEgg = percent, egg
    							end
    						end
    					end
    					for variant, prefix in pairs(Prefixes) do
    						local full = prefix .. name
    						local have = indexed(full)
    						known[full] = have
    						total += 1
    						if have then
    							count += 1
    						end
    						if not anyPick or pick[entry.rarity] then
    							totals[variant] += 1
    							if not have then
    								table.insert(lists[variant], {
    									id = name,
    									name = name,
    									rarity = entry.rarity,
    									rank = RarityRank[entry.rarity] or 0,
    									percent = best,
    									egg = bestEgg,
    									locked = locked,
    									icon = petIcon(full) or petIcon(name),
    									target = if variant == "Normal" then huntEgg ~= nil and entry.eggs[huntEgg] ~= nil else Hunter.craftPending == true and focus == name,
    									focus = focus == name,
    								})
    							end
    						end
    					end
    				end
    				for _, list in pairs(lists) do
    					table.sort(list, function(a, b)
    						if a.target ~= b.target then return a.target end
    						if a.rank ~= b.rank then return a.rank < b.rank end
    						if (a.percent or 0) ~= (b.percent or 0) then return (a.percent or 0) > (b.percent or 0) end
    						return a.name < b.name
    					end)
    				end
    				Auto.IndexSnap = known
    				Live.indexCount, Live.indexTotal = count, total
    				Snap.gallery = { lists = lists, totals = totals, egg = huntEgg, focus = focus }
    				if S.huntPin and known[S.huntPin] then
    					queueToast("Index Hunter", S.huntPin .. " is in your index now, pin cleared")
    					S.huntPin = nil
    				end
    			end
    
    			local GoalMeta = {
    				Coins = { label = "Coins", icon = CurrencyIcons.Coins, color = "#e0a526", metric = "Coins" },
    				Rubies = { label = "Rubies", icon = CurrencyIcons.Rubies, color = "#e66767", metric = "Rubies" },
    				Gems = { label = "Gems", icon = CurrencyIcons.Gems, color = "#9085e9", metric = "Gems" },
    				Eggs = { label = "Eggs opened", icon = GameIcons.Egg, color = "#3ccf91", metric = "Eggs" },
    				Index = { label = "Index entries", icon = GameIcons.Index, color = "#5fb8ff" },
    			}
    			Auto.GoalMeta = GoalMeta
    
    			local function goalCurrent(kind)
    				if kind == "Eggs" then
    					return tonumber(Saved.eggs) or 0
    				elseif kind == "Index" then
    					return Live.indexCount
    				end
    				return getStat(kind)
    			end
    
    			Auto.goalSnapshot = function(check)
    				local list = {}
    				for _, goal in ipairs(Saved.goals) do
    					local meta = type(goal) == "table" and GoalMeta[goal.kind] or nil
    					local target = type(goal) == "table" and tonumber(goal.target) or nil
    					if meta and target and target > 0 then
    						local current = goalCurrent(goal.kind)
    						if check and not goal.done and type(current) == "number" and current >= target then
    							goal.done = true
    							goal.doneAt = os.time()
    							SaveDirty = true
    							local text = formatNumber(target) .. " " .. meta.label
    							queueToast("Goal reached", text)
    							pcall(Auto.postEvent, "Goals", "Goal reached", "**" .. text .. "**", 3985554)
    							if Auto.Metrics then
    								pcall(Auto.Metrics.event, "Goal", text, meta.color)
    							end
    						end
    						local entry = { id = goal.id, kind = goal.kind, meta = meta, target = target, current = current, done = goal.done == true, doneAt = tonumber(goal.doneAt) }
    						if not entry.done and type(current) == "number" and meta.metric and Auto.eta then
    							local ok, eta = pcall(Auto.eta, meta.metric, target - current)
    							entry.eta = if ok then eta else nil
    						end
    						table.insert(list, entry)
    					end
    				end
    				return list
    			end
    
    			Auto.addGoal = function(label, text)
    				local kind = nil
    				for key, meta in pairs(GoalMeta) do
    					if meta.label == label then
    						kind = key
    					end
    				end
    				if not kind then
    					notify("Goals", "Pick what you want to collect first", 4)
    					return false
    				end
    				if #Saved.goals >= 4 then
    					notify("Goals", "You can track 4 goals at once, remove one first", 4)
    					return false
    				end
    				local target = Auto.parseAmount(text)
    				if kind == "Index" and (target == nil or target <= 0) then
    					target = Live.indexTotal
    				end
    				if not target or target <= 0 then
    					notify("Goals", "Type a target like 10b, 500k or 1.5t", 4)
    					return false
    				end
    				local current = goalCurrent(kind)
    				if type(current) == "number" and current >= target then
    					notify("Goals", "You already have " .. formatNumber(current) .. ", pick a higher target", 5)
    					return false
    				end
    				table.insert(Saved.goals, { id = string.format("%d-%d", os.time(), math.random(1, 999999)), kind = kind, target = target, created = os.time() })
    				SaveDirty = true
    				notify("Goals", "Tracking " .. formatNumber(target) .. " " .. GoalMeta[kind].label, 3)
    				if Auto.drawLive then
    					pcall(Auto.drawLive, true)
    				end
    				return true
    			end
    
    			Auto.removeGoal = function(id)
    				for i = #Saved.goals, 1, -1 do
    					local goal = Saved.goals[i]
    					if type(goal) ~= "table" or goal.id == id then
    						table.remove(Saved.goals, i)
    					end
    				end
    				SaveDirty = true
    				if Auto.drawLive then
    					pcall(Auto.drawLive, true)
    				end
    			end
    
    			Auto.clearGoals = function()
    				local removed = 0
    				for i = #Saved.goals, 1, -1 do
    					local goal = Saved.goals[i]
    					if type(goal) ~= "table" or goal.done then
    						table.remove(Saved.goals, i)
    						removed += 1
    					end
    				end
    				SaveDirty = true
    				notify("Goals", if removed > 0 then "Removed " .. removed .. " reached goal" .. (if removed == 1 then "" else "s") else "No reached goals to clear", 3)
    				if Auto.drawLive then
    					pcall(Auto.drawLive, true)
    				end
    			end
    
    			Auto.setSkipAnim = function(on)
    				local remote = Auto.hatchResult
    				if not remote then
    					return false, "The egg system is not loaded yet"
    				end
    				if type(getconnections) ~= "function" then
    					return false, "Your executor can not skip the animation (no getconnections)"
    				end
    				local ok, list = pcall(getconnections, remote.OnClientEvent)
    				if not ok or type(list) ~= "table" then
    					return false, "Your executor can not skip the animation"
    				end
    				local mine = false
    				for _, conn in ipairs(list) do
    					local okFn, fn = pcall(function() return conn.Function end)
    					if okFn and fn == Auto.hatchHandler then
    						mine = true
    					end
    				end
    				if not mine then
    					return false, "Could not find Corvus' own hatch listener, nothing was changed"
    				end
    				local changed = 0
    				for _, conn in ipairs(list) do
    					local okFn, fn = pcall(function() return conn.Function end)
    					if okFn and type(fn) == "function" and fn ~= Auto.hatchHandler then
    						if on then
    							if pcall(function() conn:Disable() end) then
    								if not Live.disabled[fn] then
    									changed += 1
    								end
    								Live.disabled[fn] = true
    							end
    						elseif Live.disabled[fn] then
    							pcall(function() conn:Enable() end)
    							changed += 1
    						end
    					end
    				end
    				if not on then
    					table.clear(Live.disabled)
    				end
    				return true, changed
    			end
    			Library:OnUnload(function()
    				pcall(Auto.setSkipAnim, false)
    			end)
    
    			Auto.pinPet = function(item)
    				local grid = UI.HuntGrid
    				local filter = grid and grid.Filter or "Normal"
    				if filter == "Normal" and item and item.Id and not item.Dim then
    					S.huntPin = if S.huntPin == item.Id then nil else item.Id
    					HatchState.waiting = false
    				end
    				UI.galleryKey = nil
    				if Auto.drawLive then
    					pcall(Auto.drawLive, true)
    				end
    				if grid and Auto.galleryDetail and item then
    					pcall(grid.SetDetail, grid, Auto.galleryDetail(item.Pet, filter))
    				end
    			end
    
    			Auto.collectLive = function()
    				local now = os.clock()
    				if takeFeed() then
    					Snap.feed = table.move(Live.feed, 1, math.min(#Live.feed, 8), 1, {})
    				end
    				local visible = Library.Toggled ~= false and Library.ActiveTab == Tabs.Eggs
    				if now - Live.galleryAt >= (if visible then 2.5 else 10) then
    					Live.galleryAt = now
    					buildGallery()
    				end
    				if now - Live.goalsAt >= 1 then
    					Live.goalsAt = now
    					Auto.goalSnapshot(true)
    				end
    				if now - (Live.priceAt or -1e9) >= 5 then
    					Live.priceAt = now
    					local prices = {}
    					for index, name in ipairs(collectEggNames()) do
    						if index > 8 then break end
    						local price, free = getEggPrice(name)
    						prices[name] = { price = price, free = free, currency = Auto.eggCurrency(name) }
    					end
    					Snap.eggPrices = prices
    				end
    				if S.skipHatchAnim and now - Live.skipAt >= 10 then
    					Live.skipAt = now
    					Auto.setSkipAnim(true)
    				end
    			end
    		end
    		Auto.setupLive()
    
    		Auto.setupUpdate2 = function()
    			local U = { luckTry = -1e9, luckBlocked = -1e9, luckStatus = "Off", resultAt = 0, craftTry = -1e9, craftBlocked = -1e9, craftStatus = "Off", fruitTry = -1e9, fruitStatus = nil, collectAt = -1e9 }
    			Auto.U2 = U
    			local LuckCfg = { WORLD = "VolcanoHollow", MACHINE_NAME = "SeverLuck", UNIT_SECONDS = 600, UNIT_PRICE = 750000, HOUR_UNITS = 6, TIER_SECONDS = 3600, MAX_SECONDS = 18000, TIERS = { 1.2, 1.4, 1.6, 1.8, 2 } }
    			local luckLoaded = false
    
    			local function luckConfig()
    				if not luckLoaded then
    					luckLoaded = true
    					local cfg = Auto.lazyRequire("ServerLuckConfig", function()
    						local modules = ReplicatedStorage:FindFirstChild("Modules")
    						return modules and modules:FindFirstChild("ServerLuckConfig")
    					end)
    					if type(cfg) == "table" then
    						for key, fallback in pairs(LuckCfg) do
    							if type(cfg[key]) == type(fallback) then
    								LuckCfg[key] = cfg[key]
    							end
    						end
    					end
    				end
    				return LuckCfg
    			end
    
    			local function luckWorld()
    				return Auto.worldKey(luckConfig().WORLD) or "VolcanoHollow"
    			end
    
    			local function serverLuck()
    				local cfg = luckConfig()
    				local state = ReplicatedStorage:FindFirstChild("ServerLuckState")
    				local endsAt = 0
    				if state then
    					local ok, value = pcall(function() return state.Value end)
    					endsAt = if ok then tonumber(value) or 0 else 0
    				end
    				local left = math.clamp(endsAt - serverNow(), 0, cfg.MAX_SECONDS)
    				local tier = if left > 0 then math.clamp(math.ceil(left / cfg.TIER_SECONDS), 1, #cfg.TIERS) else 0
    				local fit = math.max(0, math.floor((cfg.MAX_SECONDS - left) / cfg.UNIT_SECONDS))
    				return { left = left, mult = if tier > 0 then cfg.TIERS[tier] else 1, fit = fit, max = cfg.MAX_SECONDS, price = cfg.UNIT_PRICE, unit = cfg.UNIT_SECONDS, hourUnits = cfg.HOUR_UNITS }
    			end
    			Auto.serverLuck = serverLuck
    
    			local LuckModes = { ["10 minutes"] = "One", ["1 hour"] = "Hour", Max = "Max" }
    			local function luckPlan(info)
    				local cfg = luckConfig()
    				local mode = LuckModes[S.luckMode] or "Hour"
    				local units = if mode == "One" then 1 elseif mode == "Hour" then cfg.HOUR_UNITS else info.fit
    				if units > info.fit then
    					mode, units = "One", 1
    				end
    				if info.fit < 1 or units < 1 then
    					return nil, "Server luck is full"
    				end
    				local cost = units * cfg.UNIT_PRICE
    				local spendable = Extra.spendable("Rubies")
    				if (tonumber(spendable) or 0) < cost then
    					return nil, "Saving up " .. formatNumber(cost) .. " rubies"
    				end
    				return mode, units, cost
    			end
    
    			hookEvent("serverLuckResult", "ServerLuckService", "Result", function(success, reason)
    				U.resultAt = os.clock()
    				U.lastOk = success == true
    				U.lastReason = reason
    			end)
    
    			local function luckTrip(mode, units, cost)
    				U.luckTry = os.clock()
    				local buy = Auto.knitRemote("ServerLuckService", "RE", "Buy")
    				if not buy then
    					U.luckStatus = "Unavailable"
    					U.luckBlocked = os.clock() + 120
    					return
    				end
    				local ok, err = travelTo(luckWorld())
    				if not ok then
    					U.luckStatus = "Travel failed"
    					U.luckBlocked = os.clock() + 60
    					queueToast("Server Luck", err)
    					return
    				end
    				local _, touch = getMachine(luckConfig().MACHINE_NAME)
    				if not touch then
    					_, touch = getMachine("ServerLuck")
    				end
    				if not touch then
    					U.luckStatus = "Machine not found"
    					U.luckBlocked = os.clock() + 300
    					return
    				end
    				Mover.task = "Buying server luck"
    				standAt(touch, 0)
    				task.wait(0.7)
    				local before = U.resultAt
    				U.lastOk, U.lastReason = nil, nil
    				pcall(function() buy:FireServer(mode) end)
    				local waited = 0
    				while waited < 4 and U.resultAt <= before do
    					waited += task.wait(0.2) or 0.2
    				end
    				if U.lastOk == true then
    					U.luckStatus = "Bought"
    					Saved.serverLuckBuys = (tonumber(Saved.serverLuckBuys) or 0) + 1
    					SaveDirty = true
    					local added = Library:FormatDuration(units * luckConfig().UNIT_SECONDS)
    					queueToast("Server Luck", string.format("Added %s of server luck for %s rubies", added, formatNumber(cost)))
    					if Auto.Metrics then
    						pcall(Auto.Metrics.event, "Luck", "Server luck +" .. added, "#ffcf4d")
    					end
    				elseif U.lastOk == false then
    					local reason = tostring(U.lastReason or "")
    					U.luckStatus = ({ rubies = "Not enough rubies", max = "Server luck is full", world = "Unlock Volcano Hollow first", distance = "Too far from the machine", cooldown = "Cooldown" })[reason] or ("Failed: " .. reason)
    					U.luckBlocked = os.clock() + (if reason == "world" then 600 elseif reason == "cooldown" or reason == "distance" then 15 else 90)
    				else
    					U.luckStatus = "No answer"
    					U.luckBlocked = os.clock() + 30
    				end
    			end
    
    			local RecipeList = Auto.buildRecipes()
    			local function itemCount(kind, item)
    				if kind == "Potion" then
    					return tonumber(readData("PotionsData", item)) or 0
    				elseif kind == "Fruit" then
    					return tonumber(readData("FruitsData", item)) or 0
    				elseif kind == "Charm" then
    					local folder = getDataFolder("CharmsData")
    					local entry = folder and folder:FindFirstChild(item)
    					if not entry then return 0 end
    					local function num(childName)
    						local child = entry:FindFirstChild(childName)
    						local ok, value = pcall(function() return child and child.Value end)
    						return if ok then tonumber(value) or 0 else 0
    					end
    					return math.max(0, num("Amount") - num("Equipped"))
    				elseif kind == "Currency" then
    					local spend = Extra.spendable(item)
    					return math.max(0, tonumber(spend) or 0)
    				end
    				return 0
    			end
    
    			local function craftable(recipe)
    				local count = 100
    				for _, cost in ipairs(recipe.Costs or {}) do
    					local amount = tonumber(cost.Amount) or 0
    					if amount > 0 then
    						count = math.min(count, math.floor(itemCount(cost.Kind, cost.Item) / amount))
    					end
    				end
    				return math.max(0, count)
    			end
    			Auto.craftable = craftable
    
    			local function craftTrip(list)
    				U.craftTry = os.clock()
    				local remote = Auto.knitRemote("ItemCraftService", "RF", "Craft")
    				if not remote then
    					U.craftStatus = "Unavailable"
    					U.craftBlocked = os.clock() + 300
    					return
    				end
    				local ok, err = travelTo(machineWorld("Crafting", "EnchantedGrove"))
    				if not ok then
    					U.craftStatus = "Travel failed"
    					U.craftBlocked = os.clock() + 60
    					queueToast("Item Crafting", err)
    					return
    				end
    				local _, touch = getMachine("Crafting")
    				if not touch then
    					U.craftStatus = "Machine not found"
    					U.craftBlocked = os.clock() + 300
    					return
    				end
    				Mover.task = "Crafting items"
    				standAt(touch, 2)
    				task.wait(0.7)
    				local made = {}
    				for _, recipe in ipairs(list) do
    					local count = craftable(recipe)
    					if count > 0 and alive() then
    						local label = Auto.itemDisplayName(recipe.Result)
    						Mover.task = "Crafting " .. label
    						local okCall, result = Auto.invokeTimeout(remote, 8, recipe.Id, count)
    						if okCall and result == true then
    							table.insert(made, string.format("%s x%d", label, count))
    							Saved.itemsCrafted = (tonumber(Saved.itemsCrafted) or 0) + count
    							SaveDirty = true
    						end
    						task.wait(0.6)
    					end
    				end
    				if #made > 0 then
    					U.craftStatus = "Crafted"
    					queueToast("Item Crafting", "Crafted " .. table.concat(made, ", "))
    				else
    					U.craftStatus = "Nothing crafted"
    					U.craftBlocked = os.clock() + 120
    				end
    			end
    
    			local function fruitAutoOn()
    				return readData("FruitMachineData", "AutoBuy") == true
    			end
    			Auto.fruitGameAuto = fruitAutoOn
    
    			local function fruitAutoTrip()
    				U.fruitTry = os.clock()
    				local remote = Auto.knitRemote("FruitMachineService", "RE", "SetAutoBuy")
    				if not remote then
    					U.fruitStatus = "Unavailable"
    					return
    				end
    				local ok, err = travelTo(machineWorld("FruitMachine", "FrozenAlley"))
    				if not ok then
    					queueToast("Fruit Machine", err)
    					return
    				end
    				local _, touch = getMachine("FruitMachine")
    				if touch then
    					Mover.task = "Turning on Auto Buy"
    					standAt(touch, 2)
    					task.wait(0.6)
    				end
    				pcall(function() remote:FireServer(true) end)
    				local waited = 0
    				while waited < 3 and not fruitAutoOn() do
    					waited += task.wait(0.25) or 0.25
    				end
    				if fruitAutoOn() then
    					U.fruitStatus = nil
    					queueToast("Fruit Machine", "The game's Auto Buy is on, no more trips needed")
    				else
    					U.fruitStatus = "Did not turn on"
    					U.fruitTry = os.clock() + 510
    				end
    			end
    
    			Auto.nextUpdateErrand = function(now)
    				if S.autoFruitMachine and now - U.fruitTry > 90 and readData("SPdata", "SP17") == true and not fruitAutoOn() then
    					return "Fruit Auto Buy", fruitAutoTrip
    				end
    				if S.autoServerLuck and now - U.luckTry > 10 and now >= U.luckBlocked then
    					if isWorldUnlocked(luckWorld()) == false then
    						U.luckStatus = "Unlock Volcano Hollow first"
    					else
    						local info = serverLuck()
    						if info.left < (tonumber(S.luckKeep) or 600) then
    							local mode, units, cost = luckPlan(info)
    							if mode then
    								return "Server Luck", function()
    									luckTrip(mode, units, cost)
    								end
    							end
    							U.luckStatus = tostring(units or "Waiting")
    						else
    							U.luckStatus = "Topped up"
    						end
    					end
    				end
    				if S.autoItemCraft and now - U.craftTry > 30 and now >= U.craftBlocked then
    					local list = {}
    					for _, recipe in ipairs(RecipeList) do
    						if S.craftPick[recipe.Id] and craftable(recipe) > 0 then
    							table.insert(list, recipe)
    						end
    					end
    					if #list > 0 then
    						return "Item Crafting", function()
    							craftTrip(list)
    						end
    					end
    					U.craftStatus = "Waiting for items"
    				end
    				return nil
    			end
    
    			Auto.collectUpdate2 = function()
    				local now = os.clock()
    				if now - U.collectAt < 1 then return end
    				U.collectAt = now
    				hookEvent("serverLuckResult", "ServerLuckService", "Result", function(success, reason)
    					U.resultAt = os.clock()
    					U.lastOk = success == true
    					U.lastReason = reason
    				end)
    				local luck = serverLuck()
    				local fruitAuto = fruitAutoOn()
    				local sp17 = readData("SPdata", "SP17") == true
    				local ready, readyText = 0, {}
    				for _, recipe in ipairs(RecipeList) do
    					if S.craftPick[recipe.Id] then
    						local count = craftable(recipe)
    						if count > 0 then
    							ready += 1
    							if #readyText < 2 then
    								table.insert(readyText, Auto.itemDisplayName(recipe.Result) .. " x" .. count)
    							end
    						end
    					end
    				end
    				Snap.u2 = {
    					luck = luck,
    					luckStatus = if S.autoServerLuck then U.luckStatus else "Off",
    					fruitAuto = fruitAuto,
    					sp17 = sp17,
    					fruitStatus = U.fruitStatus,
    					craftReady = ready,
    					craftText = readyText[1] or "",
    					rubies = tonumber((Extra.spendable("Rubies"))) or 0,
    					craftStatus = if S.autoItemCraft then U.craftStatus else "Off",
    				}
    			end
    		end
    		Auto.setupUpdate2()
    		Auto.setupUpdate3 = function()
    			local B = { status = "Off", lastTry = -1e9, blocked = {}, found = 0, total = 0, luck = 0.5, loaded = false }
    			Auto.Ben = B
    			local BenAlias = { Haunted = "HauntedHouse", Grove = "EnchantedGrove", Volcano = "VolcanoHollow", Moon = "TheMoon" }
    			local GREEN, ORANGE = "#60d696", "#ffb84d"
    			local function tint(color, text)
    				return string.format('<font color="%s">%s</font>', color, text)
    			end
    			local function faded(text)
    				return '<font transparency="0.5">' .. text .. "</font>"
    			end
    			local function pct(value)
    				return (string.gsub(string.format("%.2f", tonumber(value) or 0), "%.?0+$", ""))
    			end
    			local ProgressShown = {}
    			local function progress(row, value)
    				local key = math.floor(math.clamp(tonumber(value) or 0, 0, 1) * 400 + 0.5)
    				if ProgressShown[row] ~= key and pcall(row.SetProgress, row, key / 400) then
    					ProgressShown[row] = key
    				end
    			end
    
    			local function benConfig()
    				if not B.loaded then
    					B.loaded = true
    					local cfg = Auto.lazyRequire("BenFindConfig", function()
    						local modules = ReplicatedStorage:FindFirstChild("Modules")
    						return modules and modules:FindFirstChild("BenFindConfig")
    					end)
    					if type(cfg) == "table" and tonumber(cfg.PER_BEN_LUCK) then
    						B.luck = tonumber(cfg.PER_BEN_LUCK)
    					end
    				end
    			end
    
    			local function worldIndex(key)
    				for index, name in ipairs(Auto.GameData.worldOrder or UI.WorldOrder or {}) do
    					if name == key then
    						return index
    					end
    				end
    				return 99
    			end
    
    			local function benList()
    				local list = {}
    				local folder = ReplicatedStorage:FindFirstChild("BenFind")
    				for _, model in ipairs(folder and folder:GetChildren() or {}) do
    					local id = model:GetAttribute("BenId")
    					if model:IsA("Model") and type(id) == "string" and id ~= "" then
    						local world = model:GetAttribute("BenWorld")
    						if type(world) ~= "string" or world == "" then
    							local suffix = string.match(model.Name, "^Ben(.+)$")
    							world = suffix
    						end
    						if type(world) == "string" then
    							world = Auto.worldKey(BenAlias[world] or world) or world
    							local ok, pivot = pcall(model.GetPivot, model)
    							table.insert(list, { id = id, world = world, pos = if ok and pivot then pivot.Position else nil })
    						end
    					end
    				end
    				return list
    			end
    
    			local function benCollected(id)
    				local folder = getDataFolder("BenFindData")
    				local flag = folder and folder:FindFirstChild(id)
    				if not flag then
    					return false
    				end
    				local ok, value = pcall(function()
    					return flag.Value
    				end)
    				return ok and value == true
    			end
    
    			local function benState()
    				local list = benList()
    				local here = currentWorld()
    				local state = { total = #list, found = 0, locked = 0, pending = {} }
    				for _, ben in ipairs(list) do
    					if benCollected(ben.id) then
    						state.found += 1
    					elseif not worldUnlocked(ben.world) then
    						state.locked += 1
    					elseif ben.pos and (B.blocked[ben.id] or 0) <= os.clock() then
    						ben.rank = (if ben.world == here then 0 else 1000) + worldIndex(ben.world)
    						table.insert(state.pending, ben)
    					end
    				end
    				table.sort(state.pending, function(a, b)
    					if a.rank ~= b.rank then
    						return a.rank < b.rank
    					end
    					return a.id < b.id
    				end)
    				return state
    			end
    
    			local function claimRemote()
    				local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    				local folder = remotes and remotes:FindFirstChild("BenFind")
    				return folder and folder:FindFirstChild("ClaimBen")
    			end
    
    			local function benTrip(ben)
    				B.lastTry = os.clock()
    				local remote = claimRemote()
    				if not remote then
    					B.blocked[ben.id] = os.clock() + 600
    					return false
    				end
    				local ok, err = travelTo(ben.world)
    				if not ok then
    					B.blocked[ben.id] = os.clock() + 120
    					queueToast("Ben Hunt", tostring(err or ("Could not reach " .. prettyWorld(ben.world))))
    					return false
    				end
    				Mover.task = "Finding Ben"
    				local spots = { ben.pos + Vector3.new(0, 3, 0), ben.pos + Vector3.new(0, 9, 0), ben.pos + Vector3.new(5, 4, 5) }
    				for _, spot in ipairs(spots) do
    					if not alive() then
    						return false
    					end
    					local hrp = getRoot()
    					if not hrp then
    						return false
    					end
    					pcall(function()
    						hrp.AssemblyLinearVelocity = Vector3.zero
    					end)
    					hrp.CFrame = CFrame.new(spot) * hrp.CFrame.Rotation
    					task.wait(0.4)
    					pcall(function()
    						remote:FireServer(ben.id)
    					end)
    					local waited = 0
    					while waited < 2.5 and not benCollected(ben.id) do
    						waited += task.wait(0.2) or 0.2
    					end
    					if benCollected(ben.id) then
    						Saved.bensFound = (tonumber(Saved.bensFound) or 0) + 1
    						SaveDirty = true
    						queueToast("Ben Hunt", "Found a Ben in " .. prettyWorld(ben.world) .. "  (+" .. pct(B.luck) .. "% luck)")
    						pcall(function()
    							Auto.Metrics.event("Ben", "Found a Ben in " .. prettyWorld(ben.world), "#7dffb3")
    						end)
    						return true
    					end
    				end
    				B.blocked[ben.id] = os.clock() + 300
    				queueToast("Ben Hunt", "The Ben in " .. prettyWorld(ben.world) .. " did not count, trying again in 5 minutes")
    				return false
    			end
    
    			local previousErrand = Auto.nextUpdateErrand
    			Auto.nextUpdateErrand = function(now)
    				if S.autoBen and now - B.lastTry > 4 and claimRemote() then
    					benConfig()
    					local ben = benState().pending[1]
    					if ben then
    						return "Finding Ben", function()
    							benTrip(ben)
    						end
    					end
    				end
    				if previousErrand then
    					return previousErrand(now)
    				end
    				return nil
    			end
    
    			Auto.permMaxed = function()
    				local config = Auto.GameData.moonConfig
    				if type(config) ~= "table" then
    					return true, 0, 0
    				end
    				if type(config.GetShopOwned) == "function" and type(config.GetShopCapTotal) == "function" then
    					local okOwned, owned = pcall(config.GetShopOwned, LocalPlayer, "Permanent")
    					local okCap, cap = pcall(config.GetShopCapTotal, LocalPlayer, "Permanent")
    					if okOwned and okCap and tonumber(owned) and tonumber(cap) then
    						return tonumber(owned) >= tonumber(cap), tonumber(owned), tonumber(cap)
    					end
    				end
    				local shop = config.Permanent
    				local folderName = config.DataFolders and config.DataFolders.Permanent or "MoonPermUpgradesData"
    				local owned, cap = 0, 0
    				for _, name in ipairs(shop and shop.Order or {}) do
    					local level = tonumber(readLevel(folderName, name)) or 0
    					local limit = tonumber(shop.MaxLevels and shop.MaxLevels[name]) or 0
    					if type(config.GetLevelCap) == "function" then
    						local ok, levelCap = pcall(config.GetLevelCap, LocalPlayer, "Permanent", name)
    						if ok and tonumber(levelCap) then
    							limit = math.min(limit, tonumber(levelCap))
    						end
    					end
    					owned += math.min(level, limit)
    					cap += limit
    				end
    				return owned >= cap, owned, cap
    			end
    
    			local FW = { lastTry = -1e9, fails = 0 }
    			Auto.FarmWorld = FW
    			local function farmTarget()
    				local pick = tostring(S.farmWorld or "Best unlocked")
    				if pick ~= "Best unlocked" then
    					for key, display in pairs(Auto.GameData.worldCost and Auto.GameData.worldCost.DisplayNames or {}) do
    						if display == pick then
    							return Auto.worldKey(key) or key
    						end
    					end
    					return Auto.worldKey((string.gsub(pick, "%s", ""))) or pick
    				end
    				local best, moon = "Spawn", moonWorld()
    				for _, key in ipairs(Auto.GameData.worldOrder or UI.WorldOrder or {}) do
    					if key ~= moon and worldUnlocked(key) then
    						best = key
    					end
    				end
    				return best
    			end
    			local function farmWorldWait(target)
    				if S.autoFish and not (Auto.Plan and Auto.Plan.on() and Auto.Plan.fishOff) then
    					return "Fishing"
    				end
    				if S.indexHunt and Hunter.egg then
    					return "Index Hunter"
    				end
    				local hatchEgg = if Auto.effectiveEgg then Auto.effectiveEgg() else S.hatchEggName
    				if ((S.autoHatch and S.eggAutoTravel) or S.farmOP) and hatchEgg ~= "" then
    					local eggWorld = Auto.eggWorld(hatchEgg)
    					if eggWorld ~= target then
    						return "Hatching in " .. prettyWorld(eggWorld)
    					end
    				end
    				if S.autoUfo and Ufo.engaged then
    					return "UFO"
    				end
    				return nil
    			end
    			Auto.farmWorldStep = function(now)
    				if not (S.autoFarm and (S.farmWorldOn or S.farmOP)) then
    					return false
    				end
    				local target = farmTarget()
    				if not target or not worldUnlocked(target) or farmWorldWait(target) or currentWorld() == target then
    					if currentWorld() == target then
    						FW.fails = 0
    					end
    					return false
    				end
    				if now - FW.lastTry < (if FW.fails >= 3 then 60 else 10) then
    					return false
    				end
    				FW.lastTry = now
    				Mover.busy = true
    				Mover.task = "Going to " .. prettyWorld(target) .. " to farm"
    				local ok, reached = pcall(travelTo, target)
    				Mover.busy = false
    				Mover.task = ""
    				if ok and reached then
    					FW.fails = 0
    					queueToast("Farm", "Farming in " .. prettyWorld(target))
    				else
    					FW.fails += 1
    				end
    				return true
    			end
    
    			task.spawn(function()
    				local drawn = nil
    				while alive() do
    					task.wait(0.5)
    					local view = B.view
    					if view and view ~= drawn then
    						drawn = view
    						for _, item in ipairs(view) do
    							if item.value ~= nil then
    								setStat(item.row, nil, item.value)
    							end
    							if item.progress ~= nil then
    								progress(item.row, item.progress)
    							end
    						end
    					end
    				end
    			end)
    			task.spawn(function()
    				while alive() do
    					task.wait(1)
    					local view = {}
    					local function show(row, _, value)
    						table.insert(view, { row = row, value = value })
    					end
    					local function bar(row, value)
    						table.insert(view, { row = row, progress = value })
    					end
    					local ok, err = pcall(function()
    						benConfig()
    						local state = benState()
    						B.found, B.total = state.found, state.total
    						local nextBen = state.pending[1]
    						if state.total == 0 then
    							show(UI.BenFoundRow, nil, faded("none yet"))
    							bar(UI.BenFoundRow, 0)
    						else
    							show(UI.BenFoundRow, nil, string.format("%d / %d", state.found, state.total))
    							bar(UI.BenFoundRow, state.found / state.total)
    						end
    						local bonus = state.found * B.luck
    						show(UI.BenLuckRow, nil, (if bonus > 0 then tint(GREEN, "+" .. pct(bonus) .. "%") else faded("+0%")) .. faded("  of +" .. pct(state.total * B.luck) .. "%"))
    						if nextBen then
    							show(UI.BenNextRow, nil, prettyWorld(nextBen.world))
    						elseif state.total > 0 and state.found >= state.total then
    							show(UI.BenNextRow, nil, tint(GREEN, "All found"))
    						elseif state.locked > 0 then
    							show(UI.BenNextRow, nil, faded(state.locked .. " in locked worlds"))
    						else
    							show(UI.BenNextRow, nil, faded("-"))
    						end
    						local status
    						if not S.autoBen then
    							status = faded("Off")
    						elseif Mover.busy and Mover.task == "Finding Ben" then
    							status = tint(GREEN, "Finding Ben")
    						elseif state.total > 0 and state.found >= state.total then
    							status = tint(GREEN, "All found")
    						elseif not claimRemote() then
    							status = tint(ORANGE, "Ben Hunt is not in this server")
    						elseif nextBen then
    							status = tint(GREEN, "Going soon")
    						elseif state.locked > 0 then
    							status = tint(ORANGE, "Unlock more worlds")
    						elseif state.total == 0 then
    							status = tint(ORANGE, "No Bens found")
    						else
    							status = tint(ORANGE, "Retrying soon")
    						end
    						show(UI.BenStateRow, nil, status)
    
    						local maxed, owned, cap = Auto.permMaxed()
    						if cap and cap > 0 then
    							show(UI.PermMaxRow, nil, if maxed then tint(GREEN, "Maxed") else string.format("%d / %d", owned, cap))
    							bar(UI.PermMaxRow, owned / cap)
    						else
    							show(UI.PermMaxRow, nil, faded("-"))
    						end
    
    						local farmValue
    						if not S.farmWorldOn then
    							farmValue = faded("Off")
    						else
    							local target = farmTarget()
    							local wait = target and farmWorldWait(target)
    							if not target then
    								farmValue = faded("-")
    							elseif not worldUnlocked(target) then
    								farmValue = tint(ORANGE, prettyWorld(target) .. " is locked")
    							elseif wait then
    								farmValue = tint(ORANGE, prettyWorld(target)) .. faded("  after " .. wait)
    							elseif currentWorld() == target then
    								farmValue = tint(GREEN, prettyWorld(target))
    							elseif not S.autoFarm then
    								farmValue = prettyWorld(target) .. faded("  when Auto Farm is on")
    							else
    								farmValue = tint(ORANGE, "Going to " .. prettyWorld(target))
    							end
    						end
    						show(UI.FarmWorldRow, nil, farmValue)
    					end)
    					B.view = view
    					if not ok then
    						diag("update3", err)
    					end
    				end
    			end)
    		end
    		Auto.setupUpdate3()
    		Auto.setupUpdate4 = function()
    			local CollectionService = game:GetService("CollectionService")
    			local Fish = { active = false, own = false, stopFor = nil, status = "Off", seq = nil, tapIndex = 1, nextTapAt = 0, tapBusy = false, taps = 0, streak = 0, catches = 0, last = nil, startTry = -1e9, startFails = 0, needTravel = false, travelTry = -1e9, travelFails = 0, spots = {}, error = nil, endsAt = nil, duration = nil, baitAt = -1e9, invAt = -1e9 }
    			Auto.Fish = Fish
    			local Merchant = { lastTrip = -1e9, blockedUntil = -1e9, status = "Off", wantAt = -1e9, want = false, sellAt = -1e9, sell = nil }
    			local FishTree = { status = "Off", blocked = {}, last = nil }
    			FishTree.weights = { FishSpeed = 100, FishLuck = 100, TapPower = 30, TapMaxFraction = 60, GoldenCatch = 400, DoubleCatch = 150, TripleCatch = 300, ExtraItem = 25, TokenCatch = 250, TokenPouch = 3, FishRubies = 20, HookSave = 30, HookLuck = 25, WormLuck = 25, MaxEggOpenAdd = 600, MaxEquipAdd = 700 }
    			FishTree.value = function(node)
    				local total = 0
    				for _, effect in ipairs(if type(node.effects) == "table" then node.effects else { node.effect }) do
    					if type(effect) == "table" then
    						local kind, amount = tostring(effect.Type), tonumber(effect.Value) or 0
    						if FishTree.weights[kind] then
    							total += FishTree.weights[kind] * amount
    						elseif string.sub(kind, 1, 6) == "Unlock" then
    							total += if string.find(kind, "Pizza", 1, true) then 60 else 25
    						end
    					end
    				end
    				return if total > 0 then total else 5
    			end
    			local Inv = { lastFire = -1e9, status = "Off", waiting = false }
    			local MoonAuto = { lastTry = -1e9, status = nil }
    			local WormRank = { Worm = 1, Worm1 = 2, Worm2 = 3, UniverseWorm = 4 }
    			local WormOrder = { "UniverseWorm", "Worm2", "Worm1", "Worm" }
    			local HookOrder = { "Golden Fishhook", "Fishhook" }
    
    			local function fishModule(name)
    				return Auto.lazyRequire("Fishing/" .. name, function()
    					local folder = ReplicatedStorage:FindFirstChild("Fishing")
    					return folder and folder:FindFirstChild(name)
    				end)
    			end
    
    			local function fishRemote(name)
    				return Auto.knitRemote("FishingService", "RF", name)
    			end
    
    			local function resolveWorld(...)
    				local first = nil
    				for _, name in ipairs({ ... }) do
    					local key = Auto.worldKey(name)
    					first = first or key
    					if key and WorldBounds[key] then
    						return key
    					end
    				end
    				return first
    			end
    
    			local FishWorlds = {
    				{ key = resolveWorld("HauntedHouse", "Haunted"), frame = "HauntedHouse" },
    				{ key = resolveWorld("TreasureDunes"), frame = "TreasureDunes" },
    				{ key = resolveWorld("Spawn"), frame = "Spawn" },
    			}
    
    			Fish.indexPlan = function()
    				local cfg = fishModule("FishingConfig")
    				local loot = type(cfg) == "table" and type(cfg.Loot) == "table" and cfg.Loot or nil
    				if not loot then
    					return nil
    				end
    				local plan = { have = 0, total = 0, missing = {}, chance = 0, groups = {}, rarity = {}, craftOnly = 0 }
    				local seen = {}
    				local multi = if Auto.petsMulti then Auto.petsMulti() else nil
    				for _, entry in ipairs(FishWorlds) do
    					local list = loot[if entry.frame == "Spawn" then "Default" else entry.frame]
    					local total, want, names = 0, 0, {}
    					for _, item in ipairs(type(list) == "table" and list or {}) do
    						local weight = tonumber(item.Weight) or 0
    						if item.Gate == nil then
    							total += weight
    						end
    						local info = if type(multi) == "table" and type(item.Name) == "string" then multi[item.Name] else nil
    						local rarity = if type(info) == "table" and type(info[3]) == "string" then info[3] else nil
    						if item.Kind == "Pet" and type(item.Name) == "string" and Auto.fishRarityOn(rarity) then
    							local variants = {}
    							if Auto.fishVariantOn("Normal") then
    								table.insert(variants, { item.Name, weight, "Normal" })
    							end
    							if Auto.fishVariantOn("Golden") then
    								table.insert(variants, { tostring(item.Golden or ("Golden " .. item.Name)), weight * 0.01, "Golden" })
    							end
    							if Auto.fishVariantOn("Diamond") and (type(multi) ~= "table" or multi["Diamond " .. item.Name] ~= nil) then
    								table.insert(variants, { "Diamond " .. item.Name, 0, "Diamond" })
    							end
    							for _, variant in ipairs(variants) do
    								local value = readData("IndexData", variant[1])
    								local got = value == true or (type(value) == "number" and value > 0)
    								if not seen[variant[1]] then
    									seen[variant[1]] = true
    									plan.total += 1
    									local group = plan.groups[variant[3]] or { have = 0, total = 0 }
    									plan.groups[variant[3]] = group
    									group.total += 1
    									if got then
    										plan.have += 1
    										group.have += 1
    									else
    										table.insert(plan.missing, variant[1])
    										local key = rarity or "Other"
    										plan.rarity[key] = (plan.rarity[key] or 0) + 1
    										if variant[2] <= 0 then
    											plan.craftOnly += 1
    										end
    									end
    								end
    								if not got and variant[2] > 0 then
    									want += variant[2]
    									table.insert(names, variant[1])
    								end
    							end
    						end
    					end
    					if worldUnlocked(entry.key) and total > 0 and want / total > plan.chance then
    						plan.chance = want / total
    						plan.key, plan.frame, plan.names = entry.key, entry.frame, names
    					end
    				end
    				return plan
    			end
    
    			local function fishTarget()
    				if S.fishIndexHunt and Fish.plan and Fish.plan.key then
    					return Fish.plan.key, Fish.plan.frame
    				end
    				local pick = tostring(S.fishSpot or "Best unlocked")
    				if pick == "Here" then
    					return nil, nil
    				end
    				for _, entry in ipairs(FishWorlds) do
    					if entry.frame == pick then
    						return entry.key, entry.frame
    					end
    				end
    				for _, entry in ipairs(FishWorlds) do
    					if worldUnlocked(entry.key) then
    						return entry.key, entry.frame
    					end
    				end
    				return FishWorlds[#FishWorlds].key, FishWorlds[#FishWorlds].frame
    			end
    
    			local function waterSpotFrom(position, look)
    				local water = fishModule("FishingWater")
    				if type(water) ~= "table" or type(water.FindSpot) ~= "function" then
    					return nil
    				end
    				local ok, spot = pcall(water.FindSpot, position, look, water.BuildExclude())
    				return if ok then spot else nil
    			end
    
    			local function atFishingSpot()
    				local hrp = getRoot()
    				if not hrp then
    					return false
    				end
    				local target = fishTarget()
    				if target and currentWorld() ~= target then
    					return false
    				end
    				return waterSpotFrom(hrp.Position, hrp.CFrame.LookVector) ~= nil
    			end
    
    			local function groundBelow(point, params)
    				for _ = 1, 5 do
    					local hit = workspace:Raycast(point, Vector3.new(0, -90, 0), params)
    					if not hit then
    						return nil
    					end
    					local part = hit.Instance
    					if CollectionService:HasTag(part, "FishingWater") then
    						return nil
    					end
    					if part.CanCollide and part.Transparency < 0.95 then
    						return hit.Position
    					end
    					params:AddToFilter(part)
    				end
    				return nil
    			end
    
    			local function findSpot(world)
    				local water = fishModule("FishingWater")
    				local hrp = getRoot()
    				if type(water) ~= "table" or not hrp then
    					return nil
    				end
    				local exclude = water.BuildExclude()
    				local origin = hrp.Position
    				local parts = {}
    				for _, part in ipairs(CollectionService:GetTagged("FishingWater")) do
    					if part:IsA("BasePart") and part:IsDescendantOf(workspace) and getWorldAt(part.Position) == world then
    						table.insert(parts, part)
    					end
    				end
    				table.sort(parts, function(a, b)
    					return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
    				end)
    				local faces = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
    				local checks = 0
    				for _, part in ipairs(parts) do
    					local size, frame = part.Size, part.CFrame
    					local surface = tonumber(part:GetAttribute("FishingSurfaceY")) or (part.Position.Y + size.Y / 2)
    					for _, gap in ipairs({ 3, 6, 9 }) do
    						for _, face in ipairs(faces) do
    							for _, along in ipairs({ 0, 0.3, -0.3 }) do
    								local offset = if face.X ~= 0 then Vector3.new(face.X * (size.X / 2 + gap), 0, along * size.Z) else Vector3.new(along * size.X, 0, face.Z * (size.Z / 2 + gap))
    								local point = frame:PointToWorldSpace(offset)
    								local params = RaycastParams.new()
    								params.FilterType = Enum.RaycastFilterType.Exclude
    								params.FilterDescendantsInstances = exclude
    								params.IgnoreWater = true
    								local ground = groundBelow(Vector3.new(point.X, surface + 30, point.Z), params)
    								if ground and ground.Y > surface - 3 and ground.Y < surface + 15 then
    									local stand = ground + Vector3.new(0, 3, 0)
    									local towards = Vector3.new(part.Position.X - stand.X, 0, part.Position.Z - stand.Z)
    									local look = if towards.Magnitude > 0.1 then towards.Unit else Vector3.new(0, 0, -1)
    									if waterSpotFrom(stand, look) then
    										return { pos = stand, look = look }
    									end
    								end
    								checks += 1
    								if checks % 12 == 0 then
    									task.wait()
    								end
    							end
    						end
    					end
    				end
    				return nil
    			end
    
    			local function fastTravelReady()
    				return readData("SPdata", "SP15") == true and worldUnlocked(resolveWorld("EnchantedGrove"))
    			end
    
    			local function goToSpot(world, frame)
    				if not worldUnlocked(world) then
    					Fish.error = prettyWorld(world) .. " is locked"
    					return false
    				end
    				local goMachine = Auto.knitRemote("TeleportService", "RE", "GoToMachine")
    				if goMachine and frame and not Fish.spots[world] and fastTravelReady() then
    					Mover.task = "Fast travel to the water"
    					pcall(function()
    						goMachine:FireServer(frame .. "/Fishing")
    					end)
    					local waited = 0
    					repeat
    						waited += task.wait(0.25) or 0.25
    					until waited >= 5 or not alive() or atFishingSpot()
    					if atFishingSpot() then
    						local hrp = getRoot()
    						if hrp then
    							Fish.spots[world] = { pos = hrp.Position, look = hrp.CFrame.LookVector }
    						end
    						return true
    					end
    				end
    				local ok, err = travelTo(world)
    				if not ok then
    					Fish.error = tostring(err)
    					return false
    				end
    				local spot = Fish.spots[world]
    				if not spot then
    					Mover.task = "Looking for water"
    					spot = findSpot(world)
    					Fish.spots[world] = spot
    				end
    				if not spot then
    					Fish.error = "No water found in " .. prettyWorld(world)
    					return false
    				end
    				local hrp = getRoot()
    				if not hrp then
    					return false
    				end
    				pcall(function()
    					hrp.AssemblyLinearVelocity = Vector3.zero
    				end)
    				hrp.CFrame = CFrame.lookAt(spot.pos, spot.pos + spot.look)
    				task.wait(0.6)
    				if atFishingSpot() then
    					return true
    				end
    				Fish.spots[world] = nil
    				Fish.error = "That spot did not work, looking again"
    				return false
    			end
    
    			function Fish.tapTiming()
    				local cfg = fishModule("FishingConfig")
    				cfg = if type(cfg) == "table" then cfg else {}
    				return {
    					first = tonumber(cfg.SPEEDUP_FIRST_DELAY) or 0.8,
    					spawn = 0.05,
    					minGap = tonumber(cfg.SPEEDUP_MIN_INTERVAL) or 0.2,
    					window = tonumber(cfg.SPEEDUP_CLICK_WINDOW) or 2,
    				}
    			end

    			function Fish.reaction()
    				local range = ({ Slow = { 0.55, 0.85 }, Fast = { 0.24, 0.34 }, ["Blatant (kick risk)"] = { 0.02, 0.04 } })[S.fishTapSpeed] or { 0.35, 0.55 }
    				return range[1] + math.random() * (range[2] - range[1])
    			end

    			function Fish.pickSlot(index)
    				local taps = fishModule("FishingTaps")
    				local list = if Fish.seq and type(Fish.seq.Candidates) == "function" then Fish.seq:Candidates(index) else nil
    				if type(list) ~= "table" or #list == 0 then
    					return nil
    				end
    				local jumpX = type(taps) == "table" and tonumber(taps.MIN_JUMP_X) or 0.15
    				local jumpY = type(taps) == "table" and tonumber(taps.MIN_JUMP_Y) or 0.2
    				local good = {}
    				for slot, spot in ipairs(list) do
    					if not Fish.lastX or math.abs(spot[1] - Fish.lastX) >= jumpX or math.abs(spot[2] - Fish.lastY) >= jumpY then
    						table.insert(good, slot)
    					end
    				end
    				local slot = if #good > 0 then good[math.random(1, #good)] else math.random(1, #list)
    				local spot = list[slot]
    				local hitX = type(taps) == "table" and tonumber(taps.HIT_X) or 0.065
    				local hitY = type(taps) == "table" and tonumber(taps.HIT_Y) or 0.13
    				local x = spot[1] + (math.random() - 0.5) * hitX
    				local y = spot[2] + (math.random() - 0.5) * hitY
    				return slot, x, y, spot
    			end

    			local function beginSession(data, own)
    				Fish.active = true
    				Fish.own = own == true
    				Fish.stopFor = nil
    				Fish.startFails = 0
    				Fish.error = nil
    				Fish.endsAt = tonumber(data.EndsAt)
    				Fish.duration = tonumber(data.Duration)
    				Fish.streak = tonumber(data.Streak) or 0
    				Fish.seq = nil
    				local taps = fishModule("FishingTaps")
    				if type(taps) == "table" and type(taps.NewSequence) == "function" then
    					local ok, seq = pcall(taps.NewSequence, tonumber(data.TapSeed) or 0)
    					Fish.seq = if ok then seq else nil
    				end
    				Fish.tapIndex = math.max(1, math.floor(tonumber(data.TapIndex) or 1))
    				Fish.lastX, Fish.lastY = nil, nil
    				Fish.nextTapAt = os.clock() + Fish.tapTiming().first + Fish.reaction()
    				Fish.tapBusy = false
    			end
    
    			local function stopFishing(reason)
    				local remote = fishRemote("StopFishing")
    				Fish.active = false
    				Fish.own = false
    				Fish.status = reason or "Off"
    				if remote then
    					task.spawn(Auto.invokeTimeout, remote, 5)
    				end
    			end
    
    			-- After an errand (Merchant, crafting, ...) the fishing state can be stale: ask the server and cast again if needed.
    			function Fish.resync()
    				Fish.wasBusy = false
    				local remote = fishRemote("GetSession")
    				if remote then
    					local ok, data = Auto.invokeTimeout(remote, 6)
    					if ok and type(data) == "table" then
    						if data.Ok == true then
    							beginSession(data, Fish.own)
    						else
    							Fish.active = false
    							Fish.own = false
    						end
    					end
    				end
    				if Fish.active and not atFishingSpot() then
    					stopFishing("Moved away")
    				end
    				Fish.startTry = -1e9
    				Fish.startFails = 0
    			end


    			local function resultError(ok, result)
    				if ok and type(result) == "table" then
    					return tostring(result.Error or result.Reason or "Refused")
    				end
    				return if ok then "Refused" else "No answer"
    			end
    
    			local function onCatch(loot)
    				Fish.catches += 1
    				Saved.fishCaught = (tonumber(Saved.fishCaught) or 0) + 1
    				SaveDirty = true
    				local raw = tostring(loot.Name)
    				local name = string.match(raw, "^[^|]+") or raw
    				local mutation = string.match(raw, "|(.+)$")
    				local last = { name = name, kind = tostring(loot.Kind or ""), amount = math.max(1, math.floor(tonumber(loot.Amount) or 1)), deleted = loot.Deleted == true, mutation = mutation }
    				if last.kind == "Pet" then
    					local rarity = "Basic"
    					if PetDisplay and PetDisplay.GetRarity then
    						local ok, result = pcall(PetDisplay.GetRarity, name)
    						if ok and type(result) == "string" then
    							rarity = result
    						end
    					end
    					last.rarity = rarity
    					last.icon = petIcon(name) or petIcon((string.gsub(name, "^Golden ", "")))
    					Auto.FeedRaw = Auto.FeedRaw or {}
    					table.insert(Auto.FeedRaw, { at = os.clock(), egg = "Fishing", names = { { name = name, rarity = rarity, fresh = false, mutation = mutation } } })
    					while #Auto.FeedRaw > 20 do
    						table.remove(Auto.FeedRaw, 1)
    					end
    					if (RarityRank[rarity] or 0) >= 4 or string.sub(name, 1, 7) == "Golden " then
    						Saved.fishRare = (tonumber(Saved.fishRare) or 0) + 1
    						local label = (if mutation then ((Auto.mutationInfo(mutation)) or mutation) .. " " else "") .. name
    						queueToast("Fishing", "Caught " .. label .. "  \u{00B7}  " .. rarity)
    						if Auto.Metrics then
    							pcall(Auto.Metrics.event, "Fish", label .. "  \u{00B7}  " .. rarity, RarityColors[rarity])
    						end
    						if Auto.postEvent then
    							Auto.postEvent("Fish", "Rare catch", "Caught **" .. label .. "** (" .. rarity .. ") while fishing", 6275327)
    						end
    					end
    				end
    				Fish.last = last
    			end
    
    			local function hookFishing()
    				hookEvent("fishStopped", "FishingService", "Stopped", function()
    					Fish.active = false
    					Fish.own = false
    				end)
    				hookEvent("fishResumed", "FishingService", "Resumed", function(data)
    					if type(data) == "table" and data.Ok == true then
    						beginSession(data, Fish.own)
    					end
    				end)
    				hookEvent("fishCaught", "FishingService", "Caught", function(loot, endsAt, duration)
    					if tonumber(endsAt) then
    						Fish.endsAt = tonumber(endsAt)
    					end
    					if tonumber(duration) and tonumber(duration) > 0 then
    						Fish.duration = tonumber(duration)
    					end
    					if type(loot) == "table" and type(loot.Name) == "string" then
    						onCatch(loot)
    					end
    				end)
    			end
    
    			function Fish.canPressButtons()
    				return type(firesignal) == "function" or type(getconnections) == "function"
    			end

    			function Fish.pressButton(button)
    				if type(firesignal) == "function" then
    					return (pcall(firesignal, button.Activated))
    				end
    				local ok, list = pcall(getconnections, button.Activated)
    				if not ok or type(list) ~= "table" or #list == 0 then
    					return false
    				end
    				for _, connection in ipairs(list) do
    					pcall(function()
    						connection:Fire()
    					end)
    				end
    				return true
    			end

    			function Fish.hookTapButtons()
    				local gui = LocalPlayer:FindFirstChild("PlayerGui")
    				local fishingGui = gui and gui:FindFirstChild("FishingGui")
    				local frame = fishingGui and fishingGui:FindFirstChild("Fishing")
    				if not frame or Fish.tapFrame == frame then
    					return
    				end
    				Fish.tapFrame = frame
    				Library:GiveSignal(frame.ChildAdded:Connect(function(child)
    					if S.fishHideTaps and (child.Name == "ClickSpeedUpActive" or child.Name == "TapHalo" or child.Name == "TapTimer") then
    						pcall(function()
    							child.Visible = false
    						end)
    					end
    					if child.Name ~= "ClickSpeedUpActive" then
    						return
    					end
    					-- The game's own tap loop is running, so presses go through its button (they show on screen).
    					Fish.lastButtonAt = os.clock()
    					if not (S.autoFish and S.fishTap and Fish.active and Fish.canPressButtons()) then
    						return
    					end
    					task.wait(Fish.reaction())
    					if child.Parent and Fish.active and S.fishTap and Fish.pressButton(child) then
    						Fish.taps += 1
    						Fish.streak = (tonumber(Fish.streak) or 0) + 1
    					end
    				end))
    			end

    			local function tapStep(now)
    				if S.fishTap and Fish.canPressButtons() then
    					Fish.hookTapButtons()
    					-- Only lean on the game's button while it is really spawning them. When the hub started the cast
    					-- or the fishing GUI is closed, no buttons come and the taps go straight to the server instead.
    					if Fish.tapFrame and Fish.tapFrame.Parent and os.clock() - (Fish.lastButtonAt or -1e9) < 3 then
    						return
    					end
    				end
    				if not (S.fishTap and Fish.active and Fish.seq) or Fish.tapBusy or now < Fish.nextTapAt then
    					return
    				end
    				local remote = fishRemote("SpeedUp")
    				if not remote then
    					return
    				end
    				local index = Fish.tapIndex
    				local okPick, slot, x, y, spot = pcall(Fish.pickSlot, index)
    				if not okPick or not slot then
    					return
    				end
    				Fish.lastX, Fish.lastY = spot[1], spot[2]
    				Fish.tapBusy = true
    				local timing = Fish.tapTiming()
    				local margin = if S.fishTapSpeed == "Blatant (kick risk)" then 0.005 else 0.04
    				Fish.nextTapAt = now + math.max(timing.spawn + Fish.reaction(), timing.minGap + margin)
    				task.spawn(function()
    					local ok, result = Auto.invokeTimeout(remote, 5, index, x, y, slot)
    					Fish.tapBusy = false
    					Fish.tapIndex = math.max(Fish.tapIndex, index + 1)
    					if ok and type(result) == "table" then
    						local tapIndex = tonumber(result.TapIndex)
    						if tapIndex and tapIndex > Fish.tapIndex then
    							Fish.tapIndex = math.floor(tapIndex)
    						end
    						if tonumber(result.EndsAt) then
    							Fish.endsAt = tonumber(result.EndsAt)
    						end
    						if tonumber(result.Streak) then
    							Fish.streak = tonumber(result.Streak)
    						end
    						if result.Accepted == true then
    							Fish.taps += 1
    						else
    							Fish.rejected = (Fish.rejected or 0) + 1
    							Fish.nextTapAt = math.max(Fish.nextTapAt, os.clock() + 1)
    						end
    					end
    				end)
    			end
    
    			local function activeWorm()
    				local potions = Auto.lazyRequire("PotionsModule", function()
    					local modules = ReplicatedStorage:FindFirstChild("Modules")
    					return modules and modules:FindFirstChild("PotionsModule")
    				end)
    				if type(potions) == "table" and type(potions.GetActiveWorm) == "function" then
    					local ok, worm = pcall(potions.GetActiveWorm, LocalPlayer)
    					if ok and type(worm) == "string" then
    						local okLeft, left = pcall(potions.GetTimeLeft, LocalPlayer, worm)
    						return worm, if okLeft then tonumber(left) else nil
    					end
    				end
    				return nil, nil
    			end
    
    			local function hookCharges()
    				return tonumber(readData("FishingItemsData", "GoldenFishhookCharges")) or 0, tonumber(readData("FishingItemsData", "FishhookCharges")) or 0
    			end
    
    			local function baitStep(now)
    				if now - Fish.baitAt < 2 or not Fish.active then
    					return
    				end
    				Fish.baitAt = now
    				local use = Auto.knitRemote("ConsumablesService", "RE", "UseItem")
    				if not use then
    					return
    				end
    				if S.autoWorms then
    					local worm = activeWorm()
    					for _, name in ipairs(WormOrder) do
    						if (tonumber(readData("FishingItemsData", name)) or 0) > 0 then
    							if worm == nil or (WormRank[name] or 0) > (WormRank[worm] or 0) then
    								pcall(function()
    									use:FireServer(name, 1)
    								end)
    							end
    							break
    						end
    					end
    				end
    				if S.autoHooks then
    					local golden, normal = hookCharges()
    					if golden + normal <= 0 then
    						for _, name in ipairs(HookOrder) do
    							if (tonumber(readData("FishingItemsData", name)) or 0) > 0 then
    								pcall(function()
    									use:FireServer(name, 1)
    								end)
    								break
    							end
    						end
    					end
    				end
    			end
    
    			local function merchantCfg()
    				return fishModule("MerchantConfig")
    			end
    
    			local function merchantWorld()
    				return machineWorld("MerchantFishing", resolveWorld("TreasureDunes"))
    			end
    
    			local function tokenBalance()
    				return math.max(0, math.floor(tonumber(readData("FishingMerchantData", "Tokens")) or 0))
    			end
    
    			local function sellSummary(force)
    				local now = os.clock()
    				if not force and Merchant.sell and now - Merchant.sellAt < 5 then
    					return Merchant.sell
    				end
    				Merchant.sellAt = now
    				local summary = { list = {}, count = 0, value = 0 }
    				Merchant.sell = summary
    				local cfg = merchantCfg()
    				if type(cfg) ~= "table" or type(cfg.GetSellValue) ~= "function" or not (PetDisplay and PetDisplay.GetAvailable) then
    					return summary
    				end
    				local pets = getDataFolder("PetsData")
    				local goldenWanted = {}
    				if S.fishIndexHunt and Auto.fishVariantOn("Golden") and Fish.plan and type(Fish.plan.missing) == "table" then
    					for _, missing in ipairs(Fish.plan.missing) do
    						local wanted = string.match(missing, "^Golden (.+)$")
    						if wanted then
    							goldenWanted[wanted] = true
    						end
    					end
    				end
    				local reqG = craftRequirements()
    				for _, tier in ipairs({ "Normal", "Golden", "Diamond" }) do
    					local folder = if pets and S.sellTiers[tier] then pets:FindFirstChild(tier .. "PetsData") else nil
    					for _, entry in ipairs(folder and folder:GetChildren() or {}) do
    						local name = entry.Name
    						if not string.find(name, "|", 1, true) then
    							local base = string.gsub(string.gsub(name, "^Golden ", ""), "^Diamond ", "")
    							if S.sellFishPick[base] then
    								local okValue, price = pcall(cfg.GetSellValue, name, PetDisplay)
    								if okValue and type(price) == "number" and price > 0 then
    									local okAvailable, available = pcall(PetDisplay.GetAvailable, LocalPlayer, name)
    									local reserve = S.keepFish or 0
    									if tier == "Normal" and goldenWanted[base] then
    										reserve = math.max(reserve, reqG)
    									end
    									local amount = math.floor((if okAvailable then tonumber(available) or 0 else 0) - reserve)
    									if amount > 0 then
    										summary.list[name] = amount
    										summary.count += amount
    										summary.value += price * amount
    									end
    								end
    							end
    						end
    					end
    				end
    				return summary
    			end
    
    			local function merchantOffers()
    				local cfg = merchantCfg()
    				local fishing = ReplicatedStorage:FindFirstChild("Fishing")
    				if type(cfg) ~= "table" or not fishing or type(cfg.DecodeStock) ~= "function" then
    					return nil
    				end
    				local ok, stock = pcall(cfg.DecodeStock, fishing:GetAttribute(cfg.STOCK_ATTRIBUTE or "FishingMerchantStock"), HttpService)
    				if not (ok and type(stock) == "table" and type(stock.Offers) == "table") then
    					return nil
    				end
    				local restock = math.floor(tonumber(readData("FishingMerchantData", "RestockId")) or -1)
    				local purchases = tonumber(readData("FishingMerchantData", "Purchases")) or 0
    				for _, offer in ipairs(stock.Offers) do
    					local bought = 0
    					if restock == stock.RestockId then
    						bought = tonumber(readData("FishingMerchantData", "Bought_" .. tostring(offer.Id))) or 0
    					end
    					offer.Left = math.max(0, (tonumber(offer.Stock) or 0) - bought)
    					local okOpen, open = pcall(cfg.IsUnlocked, offer, purchases)
    					offer.Open = okOpen and open == true
    				end
    				return stock
    			end
    
    			local function nextOffer(stock)
    				if not stock then
    					return nil
    				end
    				local spend = tokenBalance() - (S.tokenReserve or 0)
    				for _, offer in ipairs(stock.Offers) do
    					if S.merchantPick[offer.PoolId] and offer.Open and offer.Left > 0 and spend >= (tonumber(offer.Price) or math.huge) then
    						return offer
    					end
    				end
    				return nil
    			end
    
    			local function fishTreeInfo()
    				local tree = fishModule("FishingTreeData")
    				local info = { available = type(tree) == "table" and type(tree.Groups) == "table", owned = 0, total = 0, anyPicked = false, allDone = true }
    				if not info.available then
    					return info
    				end
    				local folder = getDataFolder(tree.FOLDER_NAME or "FishingTreeData")
    				local function owned(id)
    					local node = folder and folder:FindFirstChild(id)
    					if not node then
    						return false
    					end
    					local ok, value = pcall(function()
    						return node.Value
    					end)
    					return ok and value == true
    				end
    				local levels = {}
    				for _, group in ipairs(tree.Groups) do
    					local level = 0
    					if not group.parent then
    						level = #group.levels
    					else
    						for _, node in ipairs(group.levels) do
    							if not owned(node.id) then
    								break
    							end
    							level += 1
    						end
    					end
    					levels[group.id] = level
    				end
    				local balance = tokenBalance()
    				local spend = balance - (S.tokenReserve or 0)
    				info.balance = balance
    				local best, bestCost, bestIndex, bestKey, bestCan = nil, nil, nil, nil, nil
    				local smart = S.fishTreeOrder == "Best value"
    				local now = os.clock()
    				for index, group in ipairs(tree.Groups) do
    					if group.parent then
    						local level = levels[group.id] or 0
    						local maxLevel = #group.levels
    						info.owned += level
    						info.total += maxLevel
    						if S.fishTreePick[group.id] and level < maxLevel then
    							info.anyPicked = true
    							info.allDone = false
    							local parent = tree.GroupById and tree.GroupById[group.parent]
    							local parentDone = parent == nil or (levels[parent.id] or 0) >= (tonumber(group.parentLevel) or #parent.levels)
    							local node = group.levels[level + 1]
    							if (parentDone or level > 0) and node and (FishTree.blocked[group.id] or 0) < now then
    								local cost = tonumber(node.cost) or 0
    								local better, key, can = nil, cost, spend >= cost
    								if S.fishTreeOrder == "Tree order" then
    									better = best == nil or index < bestIndex
    								elseif smart then
    									local value = FishTree.value(node)
    									if level + 1 == maxLevel then
    										for _, child in ipairs(tree.Groups) do
    											if child.parent == group.id and S.fishTreePick[child.id] and child.levels[1] and (levels[child.id] or 0) == 0 then
    												value += 0.5 * FishTree.value(child.levels[1])
    											end
    										end
    									end
    									key = -value / math.max(cost, 1)
    									better = best == nil or (can and not bestCan) or (can == bestCan and key < bestKey)
    								else
    									better = best == nil or cost < bestCost
    								end
    								if better then
    									best, bestCost, bestIndex, bestKey, bestCan = { group = group, node = node }, cost, index, key, can
    								end
    							end
    						elseif S.fishTreePick[group.id] then
    							info.anyPicked = true
    						end
    					end
    				end
    				if best then
    					info.next = best
    					info.cost = bestCost
    					info.title = tostring(best.node.title or best.group.title or best.node.id)
    					info.image = best.node.image or best.group.image
    					info.affordable = spend >= bestCost
    				end
    				return info
    			end
    
    			local function merchantAnchor()
    				local machine, touch = getMachine("MerchantFishing")
    				if touch then
    					return touch
    				end
    				if not machine then
    					return nil
    				end
    				if machine:IsA("BasePart") then
    					return machine
    				end
    				if machine:IsA("Model") and machine.PrimaryPart then
    					return machine.PrimaryPart
    				end
    				for _, child in ipairs(machine:GetDescendants()) do
    					if child:IsA("BasePart") then
    						return child
    					end
    				end
    				return nil
    			end
    
    			local function merchantWanted(now)
    				if not (S.autoSellFish or S.autoMerchantBuy or S.autoFishTree) then
    					Merchant.status = "Off"
    					return false
    				end
    				if now - Merchant.wantAt < 3 then
    					return Merchant.want
    				end
    				Merchant.wantAt = now
    				Merchant.want = false
    				local world = merchantWorld()
    				if not worldUnlocked(world) then
    					Merchant.status = "Unlock " .. prettyWorld(world) .. " first"
    					return false
    				end
    				local reasons = 0
    				if S.autoSellFish and sellSummary().count >= (S.sellAt or 25) then
    					reasons += 1
    				end
    				if S.autoFishTree then
    					local info = fishTreeInfo()
    					if info.next and info.affordable then
    						reasons += 1
    					end
    				end
    				if S.autoMerchantBuy and nextOffer(merchantOffers()) then
    					reasons += 1
    				end
    				if reasons == 0 then
    					Merchant.status = "Waiting"
    					return false
    				end
    				if now - Merchant.lastTrip < 45 or now < Merchant.blockedUntil then
    					Merchant.status = "Going soon"
    					return false
    				end
    				Merchant.status = "Going to the Merchant"
    				Merchant.want = true
    				return true
    			end
    
    			local function merchantTrip()
    				Merchant.lastTrip = os.clock()
    				Merchant.want = false
    				Merchant.wantAt = os.clock()
    				local ok, err = travelTo(merchantWorld())
    				if not ok then
    					Merchant.status = "Travel failed"
    					Merchant.blockedUntil = os.clock() + 90
    					queueToast("Fishing Merchant", tostring(err))
    					return
    				end
    				local anchor = merchantAnchor()
    				if anchor then
    					Mover.task = "Visiting the Merchant"
    					pcall(standAt, anchor, 4)
    					-- The server checks the distance on its own copy of your position, which lags a moment after a fast trip.
    					task.wait(1.4)
    				end
    				local done = {}
    				local tooFar = false
    				local sell = Auto.knitRemote("FishingMerchantService", "RF", "SellPets")
    				if S.autoSellFish and sell then
    					local summary = sellSummary(true)
    					if summary.count > 0 then
    						Mover.task = "Selling fish"
    						local okCall, result = Auto.invokeTimeout(sell, 10, summary.list)
    						-- "TooFar" right after arriving: stand at the Merchant again, let the server catch up and retry,
    						-- like the game's own merchant code does.
    						for _ = 1, 3 do
    							if not (okCall and type(result) == "table" and result.Error == "TooFar") or not anchor then
    								break
    							end
    							Mover.task = "Getting closer to the Merchant"
    							pcall(standAt, anchor, 2.5)
    							task.wait(1.2)
    							okCall, result = Auto.invokeTimeout(sell, 10, summary.list)
    						end
    						if okCall and type(result) == "table" and result.Ok == true then
    							Saved.fishSold = (tonumber(Saved.fishSold) or 0) + summary.count
    							Saved.tokensEarned = (tonumber(Saved.tokensEarned) or 0) + summary.value
    							SaveDirty = true
    							table.insert(done, string.format("sold %d pets for %s tokens", summary.count, formatNumber(summary.value)))
    						else
    							local reason = resultError(okCall, result)
    							tooFar = reason == "TooFar"
    							table.insert(done, "selling failed (" .. reason .. ")")
    						end
    						Merchant.sell = nil
    						task.wait(0.5)
    					end
    				end
    				local buyNode = Auto.knitRemote("FishingMerchantService", "RF", "BuyTreeNode")
    				if S.autoFishTree and buyNode and not tooFar then
    					local bought = 0
    					for _ = 1, 40 do
    						if not alive() then
    							break
    						end
    						local info = fishTreeInfo()
    						if not (info.next and info.affordable) then
    							break
    						end
    						Mover.task = "Buying " .. info.title
    						local okCall, result = Auto.invokeTimeout(buyNode, 6, info.next.node.id)
    						if okCall and type(result) == "table" and result.Ok == true then
    							bought += 1
    							Saved.fishTreeBought = (tonumber(Saved.fishTreeBought) or 0) + 1
    							SaveDirty = true
    							FishTree.last = info.title
    							task.wait(0.4)
    						else
    							local reason = resultError(okCall, result)
    							if reason == "TooFast" then
    								task.wait(0.8)
    							else
    								FishTree.blocked[info.next.group.id] = os.clock() + 120
    								if reason == "TooFar" then
    									tooFar = true
    									break
    								end
    							end
    						end
    					end
    					if bought > 0 then
    						table.insert(done, string.format("bought %d tree node%s", bought, if bought == 1 then "" else "s"))
    					end
    				end
    				local buy = Auto.knitRemote("FishingMerchantService", "RF", "Buy")
    				if S.autoMerchantBuy and buy and not tooFar then
    					local bought = 0
    					for _ = 1, 40 do
    						if not alive() then
    							break
    						end
    						local offer = nextOffer(merchantOffers())
    						if not offer then
    							break
    						end
    						Mover.task = "Buying " .. Auto.itemDisplayName(offer.Item)
    						local okCall, result = Auto.invokeTimeout(buy, 6, offer.Id, false, offer.PoolId)
    						if okCall and type(result) == "table" and result.Ok == true then
    							bought += 1
    							Saved.merchantBought = (tonumber(Saved.merchantBought) or 0) + 1
    							SaveDirty = true
    							task.wait(0.45)
    						else
    							local reason = resultError(okCall, result)
    							if reason ~= "TooFast" then
    								tooFar = reason == "TooFar"
    								break
    							end
    							task.wait(0.8)
    						end
    					end
    					if bought > 0 then
    						table.insert(done, string.format("bought %d item%s", bought, if bought == 1 then "" else "s"))
    					end
    				end
    				if tooFar then
    					Merchant.blockedUntil = os.clock() + 120
    				end
    				Merchant.status = if #done > 0 then "Done" else "Nothing to do"
    				if #done > 0 then
    					queueToast("Fishing Merchant", (string.gsub(table.concat(done, ", "), "^%l", string.upper)))
    				end
    			end
    
    			local function invEggNames()
    				local folder = getDataFolder("Eggs")
    				local names = {}
    				for _, child in ipairs(folder and folder:GetChildren() or {}) do
    					if child:IsA("ValueBase") then
    						table.insert(names, child.Name)
    					end
    				end
    				table.sort(names)
    				return names
    			end
    
    			local function invEggStep(now)
    				if not S.autoInvEggs then
    					Inv.status = "Off"
    					return
    				end
    				local hatch = Auto.knitRemote("ExclusiveEggsService", "RE", "Hatch")
    				if not hatch then
    					Inv.status = "Unavailable"
    					return
    				end
    				local name, count = nil, 0
    				for _, egg in ipairs(invEggNames()) do
    					local owned = math.floor(tonumber(readData("Eggs", egg)) or 0)
    					if not S.invEggKeep[egg] and owned > 0 then
    						name, count = egg, owned
    						break
    					end
    				end
    				if not name then
    					Inv.status = "Nothing to open"
    					return
    				end
    				if S.autoFish and S.fishPriority == "Fishing first" then
    					Inv.status = "Paused for fishing"
    					return
    				end
    				HatchState.activeAt = os.clock()
    				if Fish.active then
    					if S.autoFish then
    						Fish.stopFor = "Eggs"
    					end
    					Inv.status = "Waiting for fishing to stop"
    					return
    				end
    				if HatchState.waiting or now - Inv.lastFire < 3 or (Inv.waiting and now - Inv.lastFire < 10) then
    					Inv.status = "Opening"
    					return
    				end
    				local amount = if count >= 8 then 8 elseif count >= 3 then 3 else 1
    				Inv.lastFire = now
    				Inv.waiting = true
    				Inv.status = string.format("Opening %s x%d", name, amount)
    				pcall(function()
    					hatch:FireServer(name, amount)
    				end)
    			end
    
    			Auto.onInvEggResult = function(list)
    				Inv.waiting = false
    				local opened = if type(list) == "table" then #list else 0
    				if opened > 0 then
    					Saved.invEggsOpened = (tonumber(Saved.invEggsOpened) or 0) + opened
    					SaveDirty = true
    				end
    			end
    
    			local function moonAutoOn()
    				return readData("MoonAutoBuyData", "Enabled") == true
    			end
    			Auto.moonGameAutoOn = moonAutoOn
    
    			local function moonAutoWanted(now)
    				return S.moonGameAuto and readData("SPdata", "SP14") == true and not moonAutoOn() and now - MoonAuto.lastTry > 90 and worldUnlocked(moonWorld())
    			end
    
    			local function moonAutoTrip()
    				MoonAuto.lastTry = os.clock()
    				local remote = Auto.knitRemote("MoonAutoBuyService", "RE", "SetEnabled")
    				if not remote then
    					MoonAuto.status = "Unavailable"
    					return
    				end
    				local ok, err = travelTo(moonWorld())
    				if not ok then
    					MoonAuto.status = "Travel failed"
    					queueToast("Moon Auto Buy", tostring(err))
    					return
    				end
    				local shop = moonShop("Incremental")
    				local anchor = shop and shop.anchor()
    				if anchor and anchor:IsA("BasePart") then
    					Mover.task = "Turning on Moon Auto Buy"
    					pcall(standAt, anchor, 7)
    					task.wait(0.6)
    				end
    				pcall(function()
    					remote:FireServer(true)
    				end)
    				local waited = 0
    				while waited < 3 and not moonAutoOn() do
    					waited += task.wait(0.25) or 0.25
    				end
    				if moonAutoOn() then
    					MoonAuto.status = nil
    					queueToast("Moon Auto Buy", "The game now buys every incremental upgrade for you")
    				else
    					MoonAuto.status = "Did not turn on"
    				end
    			end
    
    			Auto.eggsActive = function()
    				local wants = ((S.autoHatch or S.farmOP) and (if Auto.effectiveEgg then Auto.effectiveEgg() else S.hatchEggName) ~= "") or (S.indexHunt and Hunter.egg ~= nil) or S.autoInvEggs
    				if not wants then
    					return false
    				end
    				return os.clock() - (HatchState.activeAt or -1e9) < 6
    			end
    
    			local function fishBlocked()
    				if S.fishPriority ~= "Fishing first" and Auto.eggsActive() then
    					return "Paused for eggs"
    				end
    				if Auto.Plan and Auto.Plan.on() and Auto.Plan.fishOff then
    					return "Farming pays more"
    				end
    				return nil
    			end
    
    			Auto.fishStep = function(now)
    				if not (S.autoFish and Fish.needTravel) or Fish.active or fishBlocked() then
    					return false
    				end
    				local world, frame = fishTarget()
    				if not world then
    					return false
    				end
    				if now - Fish.travelTry < (if Fish.travelFails >= 3 then 60 else 8) then
    					return false
    				end
    				Fish.travelTry = now
    				Mover.busy = true
    				Mover.task = "Going fishing in " .. prettyWorld(world)
    				local ok, reached = pcall(goToSpot, world, frame)
    				Mover.busy = false
    				Mover.task = ""
    				if ok and reached then
    					Fish.travelFails = 0
    					Fish.needTravel = false
    				else
    					Fish.travelFails += 1
    					if not ok then
    						Fish.error = shortError(reached)
    					end
    				end
    				return true
    			end
    
    			local previousErrand = Auto.nextUpdateErrand
    			Auto.nextUpdateErrand = function(now)
    				if merchantWanted(now) then
    					return "Fishing Merchant", merchantTrip
    				end
    				if moonAutoWanted(now) then
    					return "Moon Auto Buy", moonAutoTrip
    				end
    				if previousErrand then
    					return previousErrand(now)
    				end
    				return nil
    			end
    
    			task.spawn(function()
    				pcall(hookFishing)
    				pcall(function()
    					local remote = fishRemote("GetSession")
    					if remote then
    						local ok, data = Auto.invokeTimeout(remote, 6)
    						if ok and type(data) == "table" and data.Ok == true then
    							beginSession(data, false)
    						end
    					end
    				end)
    				local hookAt = os.clock()
    				while alive() do
    					task.wait(0.15)
    					local ok, err = pcall(function()
    						local now = os.clock()
    						if now - hookAt > 5 then
    							hookAt = now
    							hookFishing()
    						end
    						if now - Fish.invAt >= 0.5 then
    							Fish.invAt = now
    							invEggStep(now)
    						end
    						if not S.autoFish then
    							if Fish.active and Fish.own then
    								stopFishing("Off")
    							end
    							Fish.needTravel = false
    							Fish.status = if Fish.active then "You are fishing" else "Off"
    							return
    						end
    						if Fish.stopFor then
    							local reason = Fish.stopFor
    							Fish.stopFor = nil
    							if Fish.active then
    								stopFishing("Paused for " .. string.lower(reason))
    							end
    							return
    						end
    						local blocked = fishBlocked()
    						if blocked then
    							if Fish.active then
    								stopFishing(blocked)
    							end
    							Fish.status = blocked
    							Fish.needTravel = false
    							return
    						end
    						if Mover.busy then
    							Fish.wasBusy = true
    						elseif Fish.wasBusy then
    							Fish.resync()
    						end
    						if Fish.active then
    							Fish.status = "Fishing"
    							Fish.needTravel = false
    							tapStep(now)
    							baitStep(now)
    							return
    						end
    						if Mover.busy then
    							Fish.status = "Waiting: " .. (if Mover.task ~= "" then Mover.task else "travelling")
    							return
    						end
    						if now - Fish.startTry < (if Fish.startFails >= 3 then 10 else 2) then
    							return
    						end
    						Fish.startTry = now
    						if not getRoot() then
    							Fish.status = "Waiting for your character"
    							return
    						end
    						if not atFishingSpot() then
    							Fish.needTravel = fishTarget() ~= nil
    							Fish.status = if Fish.needTravel then "Going to the water" else "Stand next to water"
    							return
    						end
    						Fish.needTravel = false
    						local remote = fishRemote("StartFishing")
    						if not remote then
    							Fish.status = "Fishing is not in this server"
    							return
    						end
    						Fish.status = "Casting"
    						local okCall, result = Auto.invokeTimeout(remote, 6)
    						if okCall and type(result) == "table" and result.Ok == true then
    							beginSession(result, true)
    							Fish.status = "Fishing"
    						else
    							Fish.startFails += 1
    							Fish.error = resultError(okCall, result)
    							Fish.status = "Cast failed: " .. Fish.error
    							if Fish.startFails >= 3 then
    								local world = fishTarget()
    								if world then
    									Fish.spots[world] = nil
    									Fish.needTravel = true
    								end
    							end
    						end
    					end)
    					if not ok then
    						diag("fishing", err)
    					end
    				end
    			end)
    
    			task.spawn(function()
    				while alive() do
    					task.wait(1)
    					local ok, err = pcall(function()
    						if not S.autoFishTree then
    							FishTree.status = "Off"
    							return
    						end
    						local info = fishTreeInfo()
    						if not info.available then
    							FishTree.status = "Not in this game"
    						elseif not info.anyPicked then
    							FishTree.status = "Pick upgrades"
    						elseif info.allDone then
    							FishTree.status = "All done"
    						elseif not info.next then
    							FishTree.status = "Waiting"
    						elseif not info.affordable then
    							FishTree.status = "Saving up"
    						else
    							FishTree.status = if Mover.busy and string.find(Mover.task, "Buying", 1, true) then "Buying" else "Going to buy"
    						end
    					end)
    					if not ok then
    						diag("fishtree", err)
    					end
    				end
    			end)
    
    			Auto.collectFishing = function()
    				local okPlan, plan = pcall(Fish.indexPlan)
    				Fish.plan = if okPlan then plan else nil
    				local fish = { status = Fish.status, active = Fish.active, catches = Fish.catches, taps = Fish.taps, streak = Fish.streak, last = Fish.last, error = Fish.error, index = Fish.plan }
    				local target = fishTarget()
    				fish.world = if Fish.active then currentWorld() else target
    				if Fish.active and Fish.endsAt then
    					fish.left = math.max(0, Fish.endsAt - serverNow())
    					fish.duration = Fish.duration
    				end
    				local boosts = fishModule("FishingBoosts")
    				if type(boosts) == "table" then
    					local okLuck, luck = pcall(boosts.GetDisplayLuckMultiplier, LocalPlayer)
    					local okSpeed, speed = pcall(boosts.GetSpeedMultiplier, LocalPlayer)
    					local okRod, rod = pcall(boosts.GetRodName, LocalPlayer)
    					fish.luck = if okLuck then tonumber(luck) else nil
    					fish.speed = if okSpeed then tonumber(speed) else nil
    					fish.rod = if okRod and type(rod) == "string" then rod else nil
    				end
    				fish.worm, fish.wormLeft = activeWorm()
    				fish.golden, fish.normal = hookCharges()
    				fish.wormCount, fish.hookCount = 0, 0
    				for name in pairs(WormRank) do
    					fish.wormCount += tonumber(readData("FishingItemsData", name)) or 0
    				end
    				for _, name in ipairs(HookOrder) do
    					fish.hookCount += tonumber(readData("FishingItemsData", name)) or 0
    				end
    				fish.tokens = tokenBalance()
    				local sell = sellSummary()
    				fish.sellCount, fish.sellValue = sell.count, sell.value
    				local cfg = merchantCfg()
    				if type(cfg) == "table" and type(cfg.GetTimeToRestock) == "function" then
    					local okLeft, left = pcall(cfg.GetTimeToRestock)
    					fish.restock = if okLeft then tonumber(left) else nil
    					fish.restockTotal = tonumber(cfg.RESTOCK_SECONDS) or 1800
    				end
    				fish.merchant = if Mover.busy and (string.find(Mover.task, "Merchant", 1, true) or string.find(Mover.task, "Selling", 1, true)) then Mover.task else Merchant.status
    				local tree = fishTreeInfo()
    				tree.status = FishTree.status
    				tree.last = FishTree.last
    				fish.tree = tree
    				local names = invEggNames()
    				local owned = 0
    				for _, name in ipairs(names) do
    					owned += math.floor(tonumber(readData("Eggs", name)) or 0)
    				end
    				fish.inv = { status = Inv.status, names = names, owned = owned }
    				fish.moonAuto = { owned = readData("SPdata", "SP14") == true, on = moonAutoOn(), status = MoonAuto.status }
    				Snap.fish = fish
    			end
    		end
    		Auto.setupUpdate4()
    		Auto.setupProfileCard = function()
    			local Card = { nextAt = 0, busy = false, status = "Off", force = false, forceNew = false, avatar = nil, saved = {}, updatedAt = nil, file = SaveFolder .. "/PetsUniverse_card.json" }
    			Auto.Card = Card
    			local GREEN, ORANGE = "#60d696", "#ffb84d"
    
    			pcall(function()
    				if type(isfile) == "function" and type(readfile) == "function" and isfile(Card.file) then
    					local data = HttpService:JSONDecode(readfile(Card.file))
    					if type(data) == "table" and type(data.messages) == "table" then
    						Card.saved = data.messages
    					end
    				end
    			end)
    
    			local function saveIds()
    				pcall(function()
    					if type(writefile) ~= "function" then
    						return
    					end
    					if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(SaveFolder) then
    						makefolder(SaveFolder)
    					end
    					writefile(Card.file, HttpService:JSONEncode({ messages = Card.saved }))
    				end)
    			end
    
    			local function hookParts(url)
    				local id, token = string.match(tostring(url or ""), "/api/webhooks/(%d+)/([%w_%-]+)")
    				if not id then
    					return nil, nil, nil
    				end
    				local host = string.match(url, "^(https://[%w%.]+)") or "https://discord.com"
    				return host .. "/api/webhooks/" .. id .. "/" .. token, id, string.match(url, "[%?&]thread_id=(%d+)")
    			end
    
    			local function avatarUrl()
    				if Card.avatar ~= nil then
    					return Card.avatar or nil
    				end
    				Card.avatar = false
    				local response = httpRequest({
    					Url = "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=" .. tostring(LocalPlayer.UserId) .. "&size=420x420&format=Png&isCircular=false",
    					Method = "GET",
    				})
    				if response and response.Body then
    					pcall(function()
    						local decoded = HttpService:JSONDecode(response.Body)
    						local entry = decoded and decoded.data and decoded.data[1]
    						if entry and type(entry.imageUrl) == "string" and entry.imageUrl ~= "" then
    							Card.avatar = entry.imageUrl
    						end
    					end)
    				end
    				return Card.avatar or nil
    			end
    
    			local function rate(key)
    				local ok, value = pcall(Auto.Metrics.current, key)
    				return if ok and type(value) == "number" then value else nil
    			end
    
    			local function activityText()
    				local parts = {}
    				local here = Snap.worlds and Snap.worlds.here
    				if S.autoFarm then
    					table.insert(parts, "Farming" .. (if here then " in " .. prettyWorld(here) else ""))
    				end
    				if Auto.Fish and Auto.Fish.active then
    					table.insert(parts, "Fishing")
    				end
    				if tostring(HatchState.status) == "Hatching" then
    					table.insert(parts, "Hatching " .. tostring(if S.indexHunt and Hunter.egg then Hunter.egg else S.hatchEggName))
    				end
    				if S.indexHunt then
    					table.insert(parts, "Index Hunter on")
    				end
    				if Mover.busy and Mover.task ~= "" then
    					table.insert(parts, Mover.task)
    				end
    				return if #parts > 0 then table.concat(parts, "  \u{00B7}  ") else "Idle"
    			end
    
    			local function buildCard()
    				local show = S.profileShow or {}
    				local hidden = S.webhookHideName == true
    				local fields = {}
    				local function add(name, value, inline)
    					if #fields < 25 then
    						table.insert(fields, { name = name, value = tostring(value), inline = inline ~= false })
    					end
    				end
    				for _, key in ipairs({ "Coins", "Rubies", "Gems" }) do
    					local perHour = if show["Rates per hour"] then rate(key) else nil
    					if show.Currencies then
    						add(key, formatNumber(getStat(key) or 0) .. (if perHour then "\n+" .. formatNumber(perHour) .. "/h" else ""))
    					elseif show["Rates per hour"] then
    						add(key .. " per hour", if perHour then "+" .. formatNumber(perHour) else "warming up")
    					end
    				end
    				if show.Eggs then
    					local perHour = if show["Rates per hour"] then rate("Eggs") else nil
    					add("Eggs opened", formatNumber(getEggsOpenedTotal() or Saved.eggs) .. "\n" .. formatNumber(Session.eggs) .. " this session" .. (if perHour then "\n" .. formatNumber(perHour) .. "/h" else ""))
    				end
    				if show.Index and Auto.Live and Auto.Live.indexTotal then
    					add("Index", string.format("%s / %s", formatNumber(Auto.Live.indexCount or 0), formatNumber(Auto.Live.indexTotal)))
    				end
    				if show["Worlds and rebirths"] then
    					local worlds = Snap.worlds
    					if worlds then
    						add("Worlds", string.format("%d / %d", worlds.owned or 0, worlds.total or 0))
    					end
    					add("Moon rebirths", formatNumber(Snap.moonRebirths or 0))
    				end
    				if show.Team and Snap.team then
    					add("Team power", "x" .. formatNumber((Snap.team.power or 0) + 1) .. "\n" .. formatNumber(Snap.team.count or 0) .. " pets equipped")
    				end
    				if show.Fishing then
    					add("Fishing", formatNumber(tonumber(Saved.fishCaught) or 0) .. " caught\n" .. formatNumber(Snap.fish and Snap.fish.tokens or 0) .. " tokens")
    				end
    				if show.UFO then
    					add("UFO", string.format("%s won  \u{00B7}  %s top 3\n%s helped", formatNumber(tonumber(Saved.ufoWon) or 0), formatNumber(tonumber(Saved.ufoTop3) or 0), formatNumber(Saved.ufoBroken or 0)))
    				end
    				if show.Boosts then
    					local parts = {}
    					local luck = Snap.u2 and Snap.u2.luck
    					if luck and luck.left and luck.left > 0 then
    						table.insert(parts, "Server luck x" .. tostring(luck.mult))
    					end
    					local friends = Snap.friends
    					if friends and friends.percent and friends.percent > 0 then
    						table.insert(parts, string.format("Friends +%d%%", math.floor(friends.percent + 0.5)))
    					end
    					local combo = Auto.eggCombo and Auto.eggCombo()
    					if combo and combo.owned and combo.bonus > 0 then
    						table.insert(parts, "Egg combo +" .. (string.gsub(string.format("%.2f", combo.bonus * 100), "%.?0+$", "")) .. "%")
    					end
    					add("Boosts", if #parts > 0 then table.concat(parts, "\n") else "none active")
    				end
    				if show["Best pets"] then
    					local lines = {}
    					for i, entry in ipairs(getBest()) do
    						if i > 5 then
    							break
    						end
    						table.insert(lines, string.format("**%s**  \u{00B7}  %s%s", entry.name, entry.rarity, if (entry.count or 1) > 1 then "  x" .. formatNumber(entry.count) else ""))
    					end
    					if #lines > 0 then
    						add("Best hatches", table.concat(lines, "\n"), false)
    					end
    				end
    				local embed = {
    					title = if hidden then "Corvus player" else LocalPlayer.DisplayName .. "  (@" .. LocalPlayer.Name .. ")",
    					url = if hidden then nil else "https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile",
    					description = if show.Activity then "\u{25CF}  " .. activityText() .. "\nSession " .. Library:FormatDuration(os.clock() - Session.started) else nil,
    					color = 13158620,
    					fields = fields,
    					author = { name = "Pets Universe  \u{00B7}  live profile", icon_url = gameIcon() },
    					footer = { text = "Corvus " .. tostring(CorvusConfig.HubVersion) .. "  \u{00B7}  updates every " .. Library:FormatDuration(S.profileEvery or 300) },
    					timestamp = DateTime.now():ToIsoDate(),
    				}
    				local thumb = if hidden then gameIcon() else avatarUrl()
    				if thumb then
    					embed.thumbnail = { url = thumb }
    				end
    				return embed
    			end
    
    			local function cardRequest(method, url, payload)
    				local response = httpRequest({
    					Url = url,
    					Method = method,
    					Headers = { ["Content-Type"] = "application/json" },
    					Body = HttpService:JSONEncode(payload),
    				})
    				return response and tonumber(response.StatusCode) or 0, response and response.Body or nil
    			end
    
    			local function sendCard(forceNew)
    				local base, hookId, thread = hookParts(S.webhookUrl)
    				if not base then
    					Card.status = "Bad webhook URL"
    					return
    				end
    				local payload = { username = hookName(), embeds = { buildCard() }, allowed_mentions = { parse = {} } }
    				if S.profileButtons then
    					payload.components = {
    						{
    							type = 1,
    							components = {
    								{ type = 2, style = 5, label = "Play Pets Universe", url = "https://www.roblox.com/games/" .. tostring(game.PlaceId) },
    								{ type = 2, style = 5, label = "Corvus Discord", url = Discord },
    							},
    						},
    					}
    				end
    				local function query(wait)
    					local parts = {}
    					if wait then
    						table.insert(parts, "wait=true")
    					end
    					if thread then
    						table.insert(parts, "thread_id=" .. thread)
    					end
    					if payload.components then
    						table.insert(parts, "with_components=true")
    					end
    					return if #parts > 0 then "?" .. table.concat(parts, "&") else ""
    				end
    				local messageId = if forceNew then nil else Card.saved[hookId]
    				if messageId then
    					local edit = { embeds = payload.embeds, components = payload.components, allowed_mentions = payload.allowed_mentions }
    					local code = cardRequest("PATCH", base .. "/messages/" .. tostring(messageId) .. query(false), edit)
    					if code == 400 and payload.components then
    						payload.components = nil
    						edit.components = nil
    						code = cardRequest("PATCH", base .. "/messages/" .. tostring(messageId) .. query(false), edit)
    					end
    					if code >= 200 and code < 300 then
    						Card.status = "Live"
    						Card.updatedAt = os.clock()
    						return
    					end
    					if code ~= 404 then
    						Card.status = "Discord refused it (" .. tostring(code) .. ")"
    						return
    					end
    					Card.saved[hookId] = nil
    					saveIds()
    				end
    				local code, body = cardRequest("POST", base .. query(true), payload)
    				if code == 400 and payload.components then
    					payload.components = nil
    					code, body = cardRequest("POST", base .. query(true), payload)
    				end
    				if code >= 200 and code < 300 then
    					local ok, data = pcall(function()
    						return HttpService:JSONDecode(body)
    					end)
    					if ok and type(data) == "table" and data.id then
    						Card.saved[hookId] = tostring(data.id)
    						saveIds()
    					end
    					Card.status = "Live"
    					Card.updatedAt = os.clock()
    				else
    					Card.status = "Discord refused it (" .. tostring(code) .. ")"
    				end
    			end
    
    			Auto.refreshCard = function(forceNew)
    				if not (S.webhookOn and validWebhook(S.webhookUrl)) then
    					queueToast("Profile Card", "Turn on Discord posts and add a webhook URL first")
    					return
    				end
    				Card.force = true
    				Card.forceNew = forceNew == true
    				queueToast("Profile Card", if forceNew then "Posting a new card..." else "Refreshing the card...")
    			end
    
    			task.spawn(function()
    				while alive() do
    					task.wait(1)
    					local ok, err = pcall(function()
    						local now = os.clock()
    						local ready = S.webhookOn and validWebhook(S.webhookUrl)
    						if not ready then
    							Card.status = if S.profileOn then "Turn on Discord posts" else "Off"
    						elseif (S.profileOn or Card.force) and not Card.busy and (Card.force or now >= Card.nextAt) then
    							local forceNew = Card.forceNew
    							Card.force, Card.forceNew = false, false
    							Card.busy = true
    							Card.nextAt = now + (S.profileEvery or 300)
    							Card.status = "Updating"
    							task.spawn(function()
    								local okSend, errSend = pcall(sendCard, forceNew)
    								if not okSend then
    									Card.status = "Error"
    									diag("profile card", errSend)
    								end
    								Card.busy = false
    							end)
    						elseif not S.profileOn and not Card.busy and Card.status ~= "Live" then
    							Card.status = "Off"
    						end
    						local status = tostring(Card.status)
    						local value
    						if status == "Live" and Card.updatedAt then
    							value = string.format('<font color="%s">Live</font>  <font transparency="0.5">updated %s ago</font>', GREEN, Library:FormatDuration(math.max(1, now - Card.updatedAt)))
    						elseif status == "Off" then
    							value = '<font transparency="0.5">Off</font>'
    						else
    							value = string.format('<font color="%s">%s</font>', ORANGE, status)
    						end
    						setStat(UI.CardStateRow, nil, value)
    						setStat(UI.CardNextRow, nil, if S.profileOn and ready then formatClock(math.max(0, Card.nextAt - now)) else '<font transparency="0.5">-</font>')
    						local code = Hook.lastCode
    						if code and Hook.lastAt then
    							local ago = Library:FormatDuration(math.max(1, now - Hook.lastAt))
    							setStat(UI.HookLastRow, nil, if code >= 200 and code < 300 then string.format('<font color="%s">OK</font>  <font transparency="0.5">%s ago</font>', GREEN, ago) else string.format('<font color="%s">Error %d</font>  <font transparency="0.5">%s ago</font>', ORANGE, code, ago))
    						end
    					end)
    					if not ok then
    						diag("profile card", err)
    					end
    				end
    			end)
    		end
    		Auto.setupProfileCard()
    
    		Auto.Mover = Mover
    		Auto.Hunter = Hunter
    		Auto.goToEgg = goToEgg
    		Auto.loadEggPets = loadEggPets
    		Auto.updateHunter = updateHunter
    		Auto.collectMachines = collectMachines
    		Auto.collectItems = collectItems
    		Auto.collectHunt = collectHunt
    		Auto.collectQuests = collectQuests
    		Auto.formatClock = formatClock
    		Auto.formatChance = formatChance
    	end
    	setupAutomation()
    end
    
    do
    	-- Admin chat phrases: a global/system message like "type WORD for 100x eggs" -> the hub writes WORD once
    	local Chat = { seen = {}, ignored = 0, sent = 0 }
    	Auto.AdminChat = Chat
    	local function chatSend(word)
    		local sent = false
    		pcall(function()
    			local channels = game:GetService("TextChatService"):FindFirstChild("TextChannels")
    			local general = channels and channels:FindFirstChild("RBXGeneral")
    			if general then
    				general:SendAsync(word)
    				sent = true
    			end
    		end)
    		if not sent then
    			pcall(function()
    				local events = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    				local say = events and events:FindFirstChild("SayMessageRequest")
    				if say then
    					say:FireServer(word, "All")
    					sent = true
    				end
    			end)
    		end
    		return sent
    	end
    	local function chatWord(text)
    		local lower = string.lower(text)
    		for _, verb in ipairs({ "type", "say", "write", "enter" }) do
    			local at = 1
    			while true do
    				local s, e = string.find(lower, "%f[%a]" .. verb .. "%f[%A]", at)
    				if not s then
    					break
    				end
    				local rest = string.sub(text, e + 1)
    				local quoted = string.match(rest, '^%s*[:%-]?%s*["\']([%w_!%-]+)["\']')
    				if quoted then
    					return quoted
    				end
    				local bare = string.match(rest, "^%s*[:%-]?%s*([%w_!%-]+)")
    				if bare and #bare >= 3 and string.find(bare, "%a") and bare == string.upper(bare) then
    					return bare
    				end
    				at = e + 1
    			end
    		end
    		return nil
    	end
    	local function onSystemMessage(text, source)
    		if type(text) ~= "string" or text == "" or #text > 400 then
    			return
    		end
    		text = string.gsub(text, "<[^>]->", "")
    		local word = chatWord(text)
    		if not word then
    			if Chat.ignored < 5 then
    				Chat.ignored += 1
    				Auto.log("ADMIN", "ignore", source, 'msg="' .. text .. '"')
    			end
    			return
    		end
    		local now = os.clock()
    		local key = string.lower(word)
    		if now - (Chat.seen[key] or -1e9) < 60 then
    			return
    		end
    		Chat.seen[key] = now
    		if not S.autoAdminChat then
    			Auto.log("ADMIN", 'msg="' .. text .. '"', "word=" .. word, "toggle off")
    			return
    		end
    		task.delay(1 + math.random() * 2, function()
    			local ok = chatSend(word)
    			Chat.sent += 1
    			Auto.log("ADMIN", 'msg="' .. text .. '"', "typed=" .. word, "sent=" .. tostring(ok), source)
    			notify("Admin Phrase", (if ok then "Typed " else "Could not type ") .. word, 4)
    		end)
    	end
    	Auto.onSystemMessage = onSystemMessage
    	pcall(function()
    		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    		local announcements = remotes and remotes:FindFirstChild("Announcements")
    		local remote = announcements and announcements:FindFirstChild("GlobalBoostAnnounce")
    		if remote and remote:IsA("RemoteEvent") then
    			Library:GiveSignal(remote.OnClientEvent:Connect(function(text)
    				onSystemMessage(text, "announce")
    			end))
    		end
    	end)
    	task.spawn(function()
    		pcall(function()
    			local channels = game:GetService("TextChatService"):WaitForChild("TextChannels", 30)
    			if not channels then
    				return
    			end
    			local function hook(channel)
    				if channel and channel:IsA("TextChannel") then
    					Library:GiveSignal(channel.MessageReceived:Connect(function(message)
    						local ok, system = pcall(function() return message.TextSource == nil end)
    						if ok and system then
    							onSystemMessage(message.Text, "chat:" .. channel.Name)
    						end
    					end))
    				end
    			end
    			for _, channel in ipairs(channels:GetChildren()) do
    				hook(channel)
    			end
    			Library:GiveSignal(channels.ChildAdded:Connect(hook))
    		end)
    	end)
    end

    -- Luck Combo (EggLuckComboConfig): the combo drops after 150 s without a hatch, one cheap egg keeps it
    local ComboKeep = { last = -1e9, count = 0 }
    local function comboKeep(now)
    	if not ((S.autoHatch or S.farmOP) and EggHatch) then
    		return false
    	end
    	if now - HatchState.lastFire < 110 or now - ComboKeep.last < 20 then
    		return false
    	end
    	if Auto.Mover.busy or (Auto.Fish and Auto.Fish.active) then
    		return false
    	end
    	local folder = getDataFolder("EggLuckComboData")
    	local levelObj = folder and folder:FindFirstChild("Level")
    	local okLevel, level = pcall(function() return levelObj and levelObj.Value end)
    	level = tonumber(okLevel and level or nil) or 0
    	if level <= 0 then
    		return false
    	end
    	ComboKeep.last = now
    	local pets = if Auto.loadEggPets then Auto.loadEggPets() else nil
    	local pick, pickPrice = nil, math.huge
    	for egg in pairs(pets or {}) do
    		local price, free = getEggPrice(egg)
    		local cost = if free then 0 else price
    		if cost and cost < pickPrice and Auto.eggCurrency(egg) == "Coins" and checkHatch(egg) then
    			pick, pickPrice = egg, cost
    		end
    	end
    	if not pick then
    		Auto.log("COMBO", "keep", "level=" .. level, "idle=" .. math.floor(now - HatchState.lastFire), "no egg in range")
    		return false
    	end
    	ComboKeep.count += 1
    	Auto.log("COMBO", "keep", "level=" .. level, "idle=" .. math.floor(now - HatchState.lastFire), "egg=" .. pick, "price=" .. pickPrice, "was=" .. tostring(HatchState.status))
    	HatchState.lastFire = now
    	HatchState.waiting = true
    	HatchState.status = "Keeping the luck combo"
    	HatchState.count = 1
    	pcall(function() EggHatch:FireServer(pick, "Single") end)
    	return true
    end

    local hatchStepInner
    local function hatchStep()
    	hatchStepInner()
    	if not HatchState.waiting then
    		comboKeep(Clock)
    	end
    end

    function hatchStepInner()
    	local huntEgg = if S.indexHunt then Auto.Hunter.egg else nil
    	local eggName = huntEgg or (if S.autoHatch or S.farmOP then (if Auto.effectiveEgg then Auto.effectiveEgg() else S.hatchEggName) else nil)
    	if eggName == "" and not huntEgg and (S.autoHatch or S.farmOP) and Auto.Plan and Auto.Plan.eggAuto and Auto.Plan.eggAuto() then
    		HatchState.status = "Waiting: " .. Auto.Plan.eggWhy
    		HatchState.waiting = false
    		return
    	end
    	if not (eggName and EggHatch) then
    		HatchState.status = "Off"
    		return
    	end
    	if S.autoFish and S.fishPriority == "Fishing first" then
    		HatchState.status = "Paused for fishing"
    		HatchState.waiting = false
    		return
    	end
    	if Auto.Mover.busy then
    		HatchState.status = if Auto.Mover.task ~= "" then Auto.Mover.task else "Travelling"
    		HatchState.waiting = false
    		return
    	end
    	local remaining = nil
    	if not huntEgg then
    		HatchState.startEggs = HatchState.startEggs or Saved.eggs
    		if (S.hatchStopAfter or 0) > 0 then
    			remaining = S.hatchStopAfter - (Saved.eggs - HatchState.startEggs)
    			if remaining <= 0 then
    				HatchState.status = "Done"
    				HatchState.waiting = false
    				Auto.stopAutoHatch = Auto.stopAutoHatch or S.hatchStopAfter
    				return
    			end
    		end
    	end
    	local ok, reason = checkHatch(eggName)
    	if not ok then
    		HatchState.status = reason
    		HatchState.waiting = false
    		local far = reason == "Egg not in this world" or string.find(reason, "Too far", 1, true) ~= nil
    		Auto.logEvery("hatchwhy:" .. eggName .. ":" .. string.gsub(reason, "%d", ""), 120, "HATCH", "wait", "egg=" .. eggName, "reason=" .. reason, "travel=" .. tostring(far and (S.eggAutoTravel or S.farmOP or huntEgg ~= nil) == true))
    		if far and huntEgg then
    			Auto.Hunter.needMove = true
    			HatchState.activeAt = os.clock()
    		elseif far and (S.eggAutoTravel or S.farmOP) and Auto.EggTravel then
    			if S.autoUfo and Auto.Ufo and Auto.Ufo.engaged then
    				HatchState.status = "Paused for the UFO"
    			else
    				Auto.EggTravel.need = eggName
    				HatchState.activeAt = os.clock()
    			end
    		end
    		return
    	end
    	if Auto.EggTravel and not huntEgg then
    		Auto.EggTravel.need = nil
    	end
    	if huntEgg then
    		Auto.Hunter.needMove = false
    	end
    	local now = Clock
    	if HatchState.waiting and now - HatchState.lastFire < 4 then
    		HatchState.status = "Hatching"
    		return
    	end
    	if HatchState.waiting then
    		HatchState.noAnswer = (HatchState.noAnswer or 0) + 1
    		if HatchState.noAnswer == 3 or HatchState.noAnswer % 30 == 0 then
    			Auto.log("HATCH", "no answer", "egg=" .. eggName, "tries=" .. HatchState.noAnswer, "status=" .. tostring(HatchState.status))
    		end
    	end
    	if now - HatchState.lastFire < 0.5 then return end
    	local mode, count = Auto.hatchPlan(eggName, if huntEgg then "Max" else S.hatchMode, remaining)
    	if not mode then
    		HatchState.status = count or "Waiting"
    		HatchState.waiting = false
    		return
    	end
    	HatchState.activeAt = os.clock()
    	if Auto.Fish and Auto.Fish.active then
    		HatchState.waiting = false
    		if S.autoFish then
    			Auto.Fish.stopFor = "Eggs"
    			HatchState.status = "Stopping fishing"
    		else
    			HatchState.status = "You are fishing"
    		end
    		return
    	end
    	HatchState.lastFire = now
    	HatchState.waiting = true
    	HatchState.status = "Hatching"
    	HatchState.count = count
    	HatchState.fired = (HatchState.fired or 0) + 1
    	if HatchState.fired <= 3 or HatchState.lastEgg ~= eggName then
    		Auto.log("BUY", "egg", "egg=" .. eggName, "mode=" .. tostring(mode), "count=" .. tostring(count), "by=" .. (if huntEgg then "index" elseif S.farmOP then "planner" elseif S.eggSmart then "smart" else "switch"))
    	else
    		Auto.logEvery("buyegg", 300, "BUY", "egg", "egg=" .. eggName, "mode=" .. tostring(mode), "count=" .. tostring(count), "fired=" .. HatchState.fired)
    	end
    	HatchState.lastEgg = eggName
    	pcall(function() EggHatch:FireServer(eggName, mode) end)
    end
    
    local function collectFarm()
    	local bd = getDataFolder("BreakableData")
    	local areaVal = bd and bd:FindFirstChild("Area")
    	local inArea = bd and bd:FindFirstChild("InArea")
    	local autoBreak = bd and bd:FindFirstChild("AutoBreaking")
    	local area = Stats.lastArea
    	if areaVal then
    		local ok, v = pcall(function() return areaVal.Value end)
    		if ok and type(v) == "string" and v ~= "" then
    			area = v
    			Stats.lastArea = v
    		end
    	end
    
    	local farm = { area = area, suffix = "" }
    	local target = lockedTarget
    	local hasTarget = target ~= nil and target.Parent ~= nil
    	if not S.autoFarm then
    		farm.state = "idle"
    	elseif S.autoTap == false then
    		farm.state = "pets"
    		hasTarget = false
    	elseif hasTarget then
    		farm.state = "firing"
    	elseif area == "" then
    		farm.state = "noarea"
    	else
    		farm.state = "search"
    	end
    
    	if hasTarget then
    		farm.target = target.Name
    		pcall(function() farm.hp = getBreakableHP(target) end)
    		farm.currency = "Coins"
    		pcall(function() farm.currency = getCurrencySafe(target) end)
    	end
    
    	local okIn, inVal = pcall(function() return inArea and inArea.Value end)
    	if okIn and inArea and not inVal then
    		local okAuto, autoVal = pcall(function() return autoBreak and autoBreak.Value end)
    		farm.suffix = if okAuto and autoVal then " (auto)" else " (outside)"
    	end
    	Snap.farm = farm
    end
    
    local LastPartyElapsed
    local function collectParty()
    	local party = getPartyStatus()
    	if party then
    		if LastPartyElapsed and LastPartyElapsed >= party.required and party.elapsed < party.required - 5 then
    			Saved.partyEggs += 1
    			SaveDirty = true
    		end
    		LastPartyElapsed = party.elapsed
    	end
    	Snap.party = party
    end
    
    local function collectEggs()
    	local selected = Options.HatchEgg and Options.HatchEgg.Value
    	S.hatchEggName = if type(selected) == "string" then selected else ""
    	local status = HatchState.status
    	if S.indexHunt and Auto.Hunter.egg then
    		status = if S.autoHatch then "Paused for Index Hunter" else "Off"
    	end
    	local eggs = { name = S.hatchEggName, mode = S.hatchMode, status = status }
    	if S.hatchEggName ~= "" then
    		eggs.price, eggs.free = getEggPrice(S.hatchEggName)
    		eggs.visual = getEggVisual(S.hatchEggName)
    		eggs.currency = Auto.eggCurrency(S.hatchEggName)
    		eggs.event = Auto.eggEvent(S.hatchEggName)
    	end
    	eggs.combo = Auto.eggCombo()
    	Snap.eggs = eggs
    end
    
    local LastGiftFlags
    local function trackGifts()
    	local folder = getDataFolder("PlaytimeGiftsData")
    	if not folder then return end
    	local flags = {}
    	for i = 1, 9 do
    		local v = folder:FindFirstChild("Gift" .. i)
    		if v then
    			local ok, val = pcall(function() return v.Value end)
    			flags[i] = ok and val == true
    		end
    	end
    	if LastGiftFlags then
    		for i = 1, 9 do
    			if flags[i] and LastGiftFlags[i] == false then
    				Saved.gifts += 1
    				Session.gifts = (Session.gifts or 0) + 1
    				SaveDirty = true
    			end
    		end
    	end
    	LastGiftFlags = flags
    end
    
    local LastBrokenCheck = nil
    Library:GiveSignal(RunService.Heartbeat:Connect(function()
    	local current = lockedTarget
    	if LastBrokenCheck and LastBrokenCheck ~= current and LastBrokenCheck.Parent == nil then
    		Saved.broken += 1
    		SaveDirty = true
    	end
    	LastBrokenCheck = current
    end))
    
    local function collectStats()
    	pcall(trackGifts)
    	for _, name in ipairs({ "Coins", "Rubies", "Gems" }) do
    		local value = getStat(name)
    		if value then
    			trackCurrency(name, value)
    		end
    	end
    	local totalEggs = getEggsOpenedTotal()
    	if totalEggs then
    		trackEggs(totalEggs)
    	end
    	local best = {}
    	for i, entry in ipairs(getBest()) do
    		if i > #BestRows then break end
    		local saved = Saved.hatched[entry.name]
    		if type(saved) == "table" and saved.icon == nil and PetDisplay and PetDisplay.GetIcon then
    			local ok, result = pcall(PetDisplay.GetIcon, entry.name)
    			saved.icon = if ok and type(result) == "string" then result else ""
    		end
    		local icon = type(saved) == "table" and saved.icon or ""
    		table.insert(best, { name = entry.name, rarity = entry.rarity, count = entry.count, icon = if icon ~= "" then icon else GameIcons.Egg })
    	end
    	Snap.best = best
    	saveStats(false)
    end
    
    local function safe(fn, where)
    	local ok, err = pcall(fn)
    	if not ok then
    		diag(where or "loop", err)
    	end
    end
    
    task.spawn(function()
    	local collectAccum = 1
    	while alive() do
    		local dt = task.wait(0.25)
    		dt = tonumber(dt) or 0.25
    		Clock += dt
    		if S.autoFarm then
    			Saved.farmTime = (tonumber(Saved.farmTime) or 0) + dt
    			SaveDirty = true
    		end
    		safe(hatchStep, "hatch")
    		safe(Auto.Metrics.sample, "metrics")
    		collectAccum += dt
    		if collectAccum >= 0.5 then
    			collectAccum = 0
    			local shown = Library.Toggled ~= false
    			safe(collectParty, "party")
    			safe(Auto.updateHunter, "hunter")
    			safe(collectEggs, "eggs")
    			safe(collectStats, "stats")
    			safe(Auto.collectLive, "live")
    			safe(Auto.collectUpdate2, "update2")
    			if shown then
    				safe(collectFarm, "farm")
    				Snap.gifts = nil
    				safe(function() Snap.gifts = getGiftStatus() end, "gifts")
    				safe(Auto.collectMachines, "machines")
    				safe(Auto.collectItems, "items")
    				safe(Auto.collectHunt, "hunt")
    				safe(Auto.collectQuests, "quests")
    				safe(Auto.collectRound, "round")
    				if Auto.collectFishing then
    					safe(Auto.collectFishing, "fishing")
    				end
    			end
    		end
    	end
    end)
    
    local function drawFarm()
    	local farm = Snap.farm
    	local stateText = ({
    		idle = '<font transparency="0.5">Idle</font>',
    		firing = '<font color="#60d696">Firing...</font>',
    		noarea = '<font color="#ffb84d">No area</font>',
    		search = '<font color="#ffb84d">Searching...</font>',
    		pets = '<font color="#60d696">Pets on auto</font>',
    	})[farm.state] or "Idle"
    	setStat(FarmStateRow, nil, stateText)
    	if farm.target then
    		setStat(TargetRow, farm.target, if farm.hp then formatNumber(farm.hp) .. " HP" else "", CurrencyIcons[farm.currency or "Coins"] or GameIcons.Auto)
    	else
    		setStat(TargetRow, "No target", "")
    	end
    	setStat(AreaRow, nil, (if farm.area ~= "" then farm.area else "unknown") .. farm.suffix)
    end
    
    local function drawGifts()
    	local gifts = Snap.gifts
    	if gifts then
    		if gifts.claimed >= 9 then
    			setStat(GiftNextRow, "All gifts claimed", "")
    		elseif gifts.nextIndex then
    			setStat(GiftNextRow, "Gift " .. gifts.nextIndex, formatTime(gifts.nextLeft))
    		elseif gifts.claimable > 0 then
    			setStat(GiftNextRow, "All gifts unlocked", "")
    		else
    			setStat(GiftNextRow, "Next gift", "...")
    		end
    		setStat(GiftClaimRow, if gifts.claimable > 0 then string.format('Claimed  <font color="#60d696">%d ready</font>', gifts.claimable) else "Claimed", string.format("%d / 9", gifts.claimed))
    	else
    		setStat(GiftNextRow, "Next gift", "...")
    	end
    end
    
    local function drawParty()
    	local party = Snap.party
    	if party then
    		setStat(PartyRow, nil, if party.ready then '<font color="#60d696">Ready</font>' else formatTime(party.timeLeft))
    	else
    		setStat(PartyRow, nil, "unavailable")
    	end
    	setStat(PartyClaimedRow, nil, tostring(Saved.partyEggs))
    end
    
    local function drawEggs()
    	local eggs = Snap.eggs
    	if not eggs then return end
    	if eggs.name ~= "" then
    		setStat(SelectedEggRow, eggs.name, eggs.mode, eggs.visual or GameIcons.Egg)
    		local priceLabel = "Price"
    		if eggs.event and eggs.event.left and eggs.event.left > 0 then
    			priceLabel = 'Price  <font transparency="0.5">event ends in ' .. Library:FormatDuration(eggs.event.left) .. "</font>"
    		end
    		setStat(EggPriceRow, priceLabel, if eggs.free then '<font color="#60d696">FREE</font>' elseif eggs.price then formatNumber(eggs.price) else "?", CurrencyIcons[eggs.currency or "Coins"] or CurrencyIcons.Coins)
    	else
    		setStat(SelectedEggRow, "No egg selected", "", GameIcons.Egg)
    		setStat(EggPriceRow, "Price", "?", CurrencyIcons.Coins)
    	end
    	local combo = eggs.combo
    	if combo and combo.owned then
    		local percent = string.gsub(string.format("%.2f", combo.bonus * 100), "%.?0+$", "")
    		setStat(UI.EggComboRow, string.format('Egg Luck Combo  <font transparency="0.5">%d/%d</font>', combo.level, combo.max), string.format('<font color="#60d696">+%s%%</font>', percent))
    		local key = math.floor(combo.level / combo.max * 400 + 0.5)
    		if UI.eggComboKey ~= key and pcall(UI.EggComboRow.SetProgress, UI.EggComboRow, combo.level / combo.max) then
    			UI.eggComboKey = key
    		end
    	elseif combo then
    		setStat(UI.EggComboRow, "Egg Luck Combo", '<font transparency="0.5">needs the special upgrade</font>')
    	else
    		setStat(UI.EggComboRow, "Egg Luck Combo", '<font transparency="0.5">-</font>')
    	end
    	local status = eggs.status or "Off"
    	if status == "Off" then
    		setStat(HatchStateRow, nil, '<font transparency="0.5">Off</font>')
    	else
    		setStat(HatchStateRow, nil, string.format('<font color="%s">%s</font>', if status == "Hatching" then "#60d696" else "#ffb84d", status))
    	end
    	setStat(EggsTabOpenedRow, nil, formatNumber(Saved.eggs))
    end
    
    local function drawStats()
    	setLabel(EarnSinceLabel, '<font transparency="0.45">Counting for</font> ' .. Library:FormatDuration(os.time() - (tonumber(Saved.earningsSince) or os.time())))
    	setLabel(EggsSinceLabel, '<font transparency="0.45">Counting for</font> ' .. Library:FormatDuration(os.time() - (tonumber(Saved.eggsSince) or os.time())))
    	for _, name in ipairs({ "Coins", "Rubies", "Gems" }) do
    		setStat(CurrencyRows[name], nil, "+" .. formatNumber(Saved.earnings[name] or 0))
    	end
    	setStat(EggsOpenedRow, nil, formatNumber(Saved.eggs))
    	setStat(EggsSessionRow, nil, formatNumber(Session.eggs))
    	setStat(PartyStatRow, nil, formatNumber(Saved.partyEggs))
    	setStat(GiftStatRow, nil, formatNumber(Saved.gifts))
    	setStat(GiftSessionRow, nil, formatNumber(Session.gifts or 0))
    	setStat(FarmTimeRow, nil, Library:FormatDuration(Saved.farmTime))
    	setStat(BrokenRow, nil, formatNumber(Saved.broken))
    	setStat(UI.FruitBuyStatRow, nil, formatNumber(Saved.fruitBuys))
    	setStat(UI.FruitGotStatRow, nil, formatNumber(Saved.fruitsBought))
    	setStat(UI.GroupStatRow, nil, formatNumber(Saved.groupChests))
    	setStat(UI.MoonStatRow, nil, formatNumber(Saved.moonChests))
    	setStat(UI.FruitsUsedRow, nil, formatNumber(Saved.fruitsUsed))
    	setStat(UI.PotionsUsedRow, nil, formatNumber(Saved.potionsUsed))
    	setStat(UI.LuckyOpenedRow, nil, formatNumber(Saved.luckyOpened))
    	setStat(UI.GoldenStatRow, nil, formatNumber(Saved.goldenCrafts))
    	setStat(UI.DiamondStatRow, nil, formatNumber(Saved.diamondCrafts))
    	setStat(UI.MutatedStatRow, nil, formatNumber(tonumber(Saved.mutated) or 0))
    	setLabel(UI.ItemsSinceLabel, '<font transparency="0.45">Counting for</font> ' .. Library:FormatDuration(os.time() - (tonumber(Saved.itemsSince) or os.time())))
    	setLabel(RewardsSinceLabel, '<font transparency="0.45">Counting for</font> ' .. Library:FormatDuration(os.time() - (tonumber(Saved.rewardsSince) or os.time())))
    	for rarity, row in pairs(RarityRows) do
    		local count = tonumber(Saved.rarity[rarity]) or 0
    		setStat(row, nil, formatNumber(count))
    		setVisible(row, count > 0)
    	end
    	local best = Snap.best
    	setVisible(BestEmpty, #best == 0)
    	for i, row in ipairs(BestRows) do
    		local entry = best[i]
    		if entry then
    			setStat(row, string.format('%s  <font color="%s">%s</font>', entry.name, RarityColors[entry.rarity] or "#ffffff", entry.rarity), "x" .. formatNumber(entry.count), entry.icon)
    			setVisible(row, true)
    		else
    			setVisible(row, false)
    		end
    	end
    end
    
    do
    	local function setupDrawing()
    		local formatClock, formatChance = Auto.formatClock, Auto.formatChance
    		local ProgressCache = {}
    		local function setProgress(row, progress)
    			local key = -1
    			if type(progress) == "number" and progress == progress then
    				progress = math.clamp(progress, 0, 1)
    				key = math.floor(progress * 400 + 0.5)
    			else
    				progress = nil
    			end
    			if ProgressCache[row] == key then return end
    			if pcall(row.SetProgress, row, progress) then
    				ProgressCache[row] = key
    			end
    		end
    
    		local GREEN, ORANGE, RED = "#60d696", "#ffb84d", "#ff6e8a"
    		local function colored(color, text)
    			return string.format('<font color="%s">%s</font>', color, text)
    		end
    		local function dim(text)
    			return '<font transparency="0.5">' .. text .. "</font>"
    		end
    
    		local function drawMachines()
    			local fm = Snap.fm
    			if fm then
    				local text = if fm.status ~= "" then colored(ORANGE, fm.status) else "Restock"
    				if fm.ready then
    					setStat(UI.FMStateRow, text, if fm.affordable then colored(GREEN, "Ready") else colored(ORANGE, "Ready"))
    					setProgress(UI.FMStateRow, 1)
    				elseif fm.left then
    					setStat(UI.FMStateRow, text, formatClock(fm.left))
    					setProgress(UI.FMStateRow, if fm.total and fm.total > 0 then 1 - fm.left / fm.total else 0)
    				else
    					setStat(UI.FMStateRow, text, "...")
    					setProgress(UI.FMStateRow, 0)
    				end
    				if fm.price then
    					local label = if fm.stock then string.format("Price  %s", dim(fm.stock .. " fruits")) else "Price"
    					setStat(UI.FMPriceRow, label, if fm.affordable then formatNumber(fm.price) else colored(RED, formatNumber(fm.price)))
    				else
    					setStat(UI.FMPriceRow, "Price", "?")
    				end
    				setStat(UI.FMBoughtRow, nil, formatNumber(Saved.fruitBuys))
    				if fm.last then
    					setLabel(UI.FMLastLabel, dim("Last buy  ") .. fm.last)
    					setVisible(UI.FMLastLabel, true)
    				end
    			end
    
    			local gc = Snap.gc
    			if gc then
    				local text = if gc.status ~= "" then colored(ORANGE, gc.status) else "Group Chest"
    				if gc.member == false then
    					setStat(UI.GCStateRow, text, colored(RED, "Join group"))
    					setProgress(UI.GCStateRow, 0)
    				elseif gc.ready then
    					setStat(UI.GCStateRow, text, colored(GREEN, "Ready"))
    					setProgress(UI.GCStateRow, 1)
    				elseif gc.left then
    					setStat(UI.GCStateRow, text, formatClock(gc.left))
    					setProgress(UI.GCStateRow, if gc.total and gc.total > 0 then 1 - gc.left / gc.total else 0)
    				else
    					setStat(UI.GCStateRow, text, "...")
    					setProgress(UI.GCStateRow, 0)
    				end
    				setStat(UI.GCMemberRow, nil, if gc.member == true then colored(GREEN, "Member") elseif gc.member == false then colored(RED, "Not joined") else "checking...")
    				setStat(UI.GCClaimedRow, nil, formatNumber(Saved.groupChests))
    			end
    
    			local mc = Snap.mc
    			if mc then
    				local text = if mc.status ~= "" then colored(ORANGE, mc.status) else "Moon Chest"
    				if mc.unlocked == false then
    					setStat(UI.MCStateRow, text, colored(RED, "Moon locked"))
    					setProgress(UI.MCStateRow, 0)
    				elseif mc.ready then
    					setStat(UI.MCStateRow, text, colored(GREEN, "Ready"))
    					setProgress(UI.MCStateRow, 1)
    				elseif mc.left then
    					setStat(UI.MCStateRow, text, formatClock(mc.left))
    					setProgress(UI.MCStateRow, if mc.total and mc.total > 0 then 1 - mc.left / mc.total else 0)
    				else
    					setStat(UI.MCStateRow, text, "...")
    					setProgress(UI.MCStateRow, 0)
    				end
    				setStat(UI.MCLuckRow, nil, if mc.luck then string.format("%.1f%%", mc.luck) else "?")
    				setStat(UI.MCClaimedRow, nil, formatNumber(Saved.moonChests))
    				local VC = Auto.VipChest
    				if VC then
    					setStat(UI.VipKeysRow, nil, formatNumber(VC.keys) .. (if VC.halves > 0 then "  +" .. formatNumber(VC.halves) .. " to craft" else "") .. (if VC.status ~= "" then "  " .. VC.status else ""))
    					setStat(UI.VipOpenedRow, nil, formatNumber(VC.opened) .. " / " .. formatNumber(VC.crafted))
    				end
    			end
    
    			local quests = Snap.quests
    			if quests then
    				if quests.indexNext then
    					setStat(UI.QuestIndexRow, "Index  " .. dim(string.format("%s/%d pets", tostring(quests.indexCount or "?"), quests.indexNext)), string.format("%d / %d", quests.indexClaimed, quests.indexTotal))
    					setProgress(UI.QuestIndexRow, (quests.indexCount or 0) / quests.indexNext)
    				else
    					setStat(UI.QuestIndexRow, "Index", colored(GREEN, "All claimed"))
    					setProgress(UI.QuestIndexRow, 1)
    				end
    				local dayText = if quests.dailyDay then "Daily reward  " .. dim("day " .. quests.dailyDay) else "Daily reward"
    				if quests.dailyLeft == nil then
    					setStat(UI.QuestDailyRow, dayText, "...")
    					setProgress(UI.QuestDailyRow, 0)
    				elseif quests.dailyLeft <= 0 then
    					setStat(UI.QuestDailyRow, dayText, colored(GREEN, "Ready"))
    					setProgress(UI.QuestDailyRow, 1)
    				else
    					setStat(UI.QuestDailyRow, dayText, formatClock(quests.dailyLeft))
    					setProgress(UI.QuestDailyRow, 1 - quests.dailyLeft / 86400)
    				end
    				if quests.groupClaimed == true then
    					setStat(UI.QuestGroupRow, nil, dim("Claimed"))
    				elseif quests.member == false then
    					setStat(UI.QuestGroupRow, nil, colored(RED, "Join group"))
    				elseif quests.groupClaimed == false then
    					setStat(UI.QuestGroupRow, nil, colored(GREEN, "Ready"))
    				else
    					setStat(UI.QuestGroupRow, nil, "...")
    				end
    				if quests.verifyClaimed == true then
    					setStat(UI.QuestVerifyRow, nil, dim("Claimed"))
    				elseif quests.verifyClaimed == false then
    					setStat(UI.QuestVerifyRow, nil, if quests.verified >= 3 then colored(GREEN, "Ready") else string.format("%d / 3", quests.verified))
    				else
    					setStat(UI.QuestVerifyRow, nil, "...")
    				end
    				setStat(UI.QuestClaimedRow, nil, formatNumber(Saved.questsClaimed))
    			end
    
    			local errand = Snap.errand or ""
    			setStat(UI.ErrandRow, nil, if errand ~= "" then colored(GREEN, errand) else dim("Idle"))
    			local nextStop = Snap.nextStop
    			if nextStop then
    				setStat(UI.ErrandNextRow, nil, if nextStop.left <= 0 then nextStop.name .. "  " .. colored(GREEN, "now") else nextStop.name .. "  " .. dim(formatClock(nextStop.left)))
    			else
    				setStat(UI.ErrandNextRow, nil, dim("-"))
    			end
    		end
    
    		local function drawItems()
    			local items = Snap.items
    			if not items then return end
    			for name, row in pairs(UI.FruitRows) do
    				local data = items.fruits[name]
    				if data then
    					setStat(row, string.format("%s  %s", name, dim("x" .. formatNumber(data.count))), if data.left > 0 then colored(GREEN, formatClock(data.left)) else dim("Off"))
    					setProgress(row, if data.left > 0 then data.left / (Items.FruitSeconds[name] or 180) else 0)
    				end
    			end
    			local anyPotion = false
    			for name, row in pairs(UI.PotionRows) do
    				local data = items.potions[name]
    				if data then
    					local show = data.count > 0 or data.left > 0
    					anyPotion = anyPotion or show
    					if show then
    						local value = if data.paused then colored(ORANGE, "Paused") elseif data.left > 0 then colored(GREEN, formatClock(data.left)) else dim("Off")
    						setStat(row, string.format("%s  %s", Auto.itemDisplayName(name), dim("x" .. formatNumber(data.count))), value)
    						setProgress(row, if data.left > 0 then data.left / (Items.PotionSeconds[name] or 900) else 0)
    					end
    					setVisible(row, show)
    				end
    			end
    			setVisible(UI.PotionEmpty, not anyPotion)
    			for name, row in pairs(UI.LuckyRows) do
    				setStat(row, nil, "x" .. formatNumber(items.lucky[name] or 0))
    			end
    			setStat(UI.LuckyOpenedTabRow, nil, formatNumber(Saved.luckyOpened))
    			local luckyStatus = items.luckyStatus or "Idle"
    			setStat(UI.LuckyStateRow, nil, if luckyStatus == "Idle" or luckyStatus == "Nothing to open" then dim(luckyStatus) else colored(GREEN, luckyStatus))
    			if items.equipped then
    				setStat(UI.EquipRow, nil, if items.maxEquip then string.format("%d / %d", items.equipped, items.maxEquip) else tostring(items.equipped))
    			end
    			local function petsText(n)
    				n = n or 0
    				if n <= 0 then return dim("none") end
    				return colored(GREEN, string.format("%d pet%s", n, if n == 1 then "" else "s"))
    			end
    			setStat(UI.CraftGoldenRow, nil, petsText(items.goldenReady))
    			setStat(UI.CraftDiamondRow, nil, petsText(items.diamondReady))
    			setStat(UI.CraftDoneRow, "Golden / Diamond", string.format("%s / %s", formatNumber(Saved.goldenCrafts), formatNumber(Saved.diamondCrafts)))
    			local craftStatus = items.craftStatus or "Idle"
    			setStat(UI.CraftStateRow, nil, if craftStatus == "Idle" then dim("Idle") elseif string.find(craftStatus, "Crafting", 1, true) then colored(GREEN, craftStatus) else colored(ORANGE, craftStatus))
    			setStat(UI.EquipLastRow, nil, if items.lastEquip then formatClock(items.lastEquip) .. " ago" else dim("never"))
    		end
    
    		local function drawHunt()
    			local hunt = Snap.hunt
    			if not hunt then return end
    			if not hunt.on then
    				setStat(UI.HuntStateRow, nil, dim("Off"))
    				setStat(UI.HuntEggRow, "No target yet", "", GameIcons.Egg)
    				setStat(UI.HuntPetRow, "Pet", dim("-"), GameIcons.Index)
    				setProgress(UI.HuntPetRow, 0)
    				setStat(UI.HuntVariantRow, nil, dim("-"))
    				setStat(UI.HuntLeftRow, nil, dim("-"))
    				setProgress(UI.HuntLeftRow, 0)
    				return
    			end
    			if hunt.crafting then
    				setStat(UI.HuntEggRow, "Crafting at the machines", "", GameIcons.Index)
    			elseif hunt.egg then
    				setStat(UI.HuntEggRow, hunt.egg, prettyWorld(hunt.world or "Spawn"), hunt.visual or EggImages[hunt.egg] or GameIcons.Egg)
    			else
    				setStat(UI.HuntEggRow, "No target", "", GameIcons.Egg)
    			end
    			if hunt.pet then
    				local chance = if hunt.percent then "  " .. dim(formatChance(hunt.percent)) else ""
    				local label = string.format('%s  <font color="%s">%s</font>%s', hunt.pet, RarityColors[hunt.rarity] or "#ffffff", hunt.rarity or "", chance)
    				local need = hunt.normNeeded or 0
    				if need > 0 then
    					setStat(UI.HuntPetRow, label, string.format("%s / %s", formatNumber(math.min(hunt.availN or 0, need)), formatNumber(need)), hunt.icon or GameIcons.Index)
    					setProgress(UI.HuntPetRow, (hunt.availN or 0) / need)
    				elseif (hunt.goldNeeded or 0) > 0 then
    					setStat(UI.HuntPetRow, label, string.format("%d / %d gold", math.min(hunt.availG or 0, hunt.goldNeeded), hunt.goldNeeded), hunt.icon or GameIcons.Index)
    					setProgress(UI.HuntPetRow, (hunt.availG or 0) / hunt.goldNeeded)
    				else
    					setStat(UI.HuntPetRow, label, colored(GREEN, "ready"), hunt.icon or GameIcons.Index)
    					setProgress(UI.HuntPetRow, 1)
    				end
    				local parts = {}
    				for i, letter in ipairs({ "N", "G", "D" }) do
    					local state = hunt.variants and hunt.variants[i] or "skip"
    					table.insert(parts, if state == "done" then colored(GREEN, letter) elseif state == "missing" then colored(ORANGE, letter) else dim(letter))
    				end
    				setStat(UI.HuntVariantRow, nil, table.concat(parts, "  "))
    			else
    				setStat(UI.HuntPetRow, "Pet", dim("-"), GameIcons.Index)
    				setProgress(UI.HuntPetRow, if hunt.status == "Complete" then 1 else 0)
    				setStat(UI.HuntVariantRow, nil, dim("-"))
    			end
    			if hunt.allTotal and hunt.allTotal > 0 then
    				setStat(UI.HuntLeftRow, nil, string.format("%d / %d", hunt.allDone, hunt.allTotal))
    				setProgress(UI.HuntLeftRow, hunt.allDone / hunt.allTotal)
    			else
    				setStat(UI.HuntLeftRow, nil, dim("-"))
    				setProgress(UI.HuntLeftRow, 0)
    			end
    			local status = hunt.status or "Hunting"
    			local color = if status == "Hatching" or status == "Complete" or string.find(status, "Crafting", 1, true) then GREEN elseif status == "Off" then nil else ORANGE
    			setStat(UI.HuntStateRow, nil, if color then colored(color, status) else dim(status))
    		end
    
    		local function eta(currency, missing)
    			local M = Auto.Metrics
    			if not M or type(missing) ~= "number" or missing <= 0 then return nil end
    			local ok, rate = pcall(M.current, currency)
    			if not ok or type(rate) ~= "number" or rate <= 0 then return nil end
    			local seconds = missing / rate * 3600
    			if seconds > 604800 then return nil end
    			if seconds < 60 then return "<1m" end
    			local days, hours, minutes = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
    			if days > 0 then return string.format("~%dd %dh", days, hours) end
    			if hours > 0 then return string.format("~%dh %dm", hours, minutes) end
    			return string.format("~%dm", minutes)
    		end
    		Auto.eta = eta
    
    		local function drawShop(shop, rows, labels, stateRow)
    			if not shop then return end
    			for name, row in pairs(rows) do
    				local data = shop.rows[name]
    				if data then
    					local label = labels[name] or Auto.prettyUpgrade(name)
    					local uncapped = data.max >= 1e8
    					local level = if uncapped then "Lv " .. formatNumber(data.level) else string.format("Lv %d/%d", data.level, data.max)
    					local text = if data.picked then label .. "  " .. dim(level) else dim(label .. "  " .. level)
    					if data.max > 0 and data.level >= data.max then
    						setStat(row, text, colored(GREEN, "MAX"))
    					elseif data.level >= data.cap then
    						setStat(row, text, colored(ORANGE, "Rebirth"))
    					elseif data.price then
    						setStat(row, text, if shop.balance >= data.price then formatNumber(data.price) else colored(RED, formatNumber(data.price)))
    					else
    						setStat(row, text, dim("?"))
    					end
    					setProgress(row, if uncapped then (if data.cap and data.cap > 0 and data.cap < 1e8 then data.level / data.cap else 0) elseif data.max > 0 then data.level / data.max else 0)
    				end
    			end
    			local status = shop.status or "Off"
    			local color = if status == "Buying" or status == "Going to buy" or status == "All maxed" then GREEN elseif status == "Off" then nil else ORANGE
    			local value = if color then colored(color, status) else dim(status)
    			if shop.best and shop.bestPrice and status ~= "Off" then
    				local wait = if status == "Saving up" then eta(shop.currency or "Rubies", shop.bestPrice - (shop.balance - (tonumber(shop.reserve) or 0))) else nil
    				value = value .. "  " .. dim(wait or formatNumber(shop.bestPrice))
    			end
    			setStat(stateRow, nil, value)
    		end
    
    		local function drawRound()
    			local ufo = Snap.ufo
    			if ufo then
    				local status = ufo.status or "No UFO right now"
    				local value
    				if not ufo.active then
    					value = dim(status)
    				elseif status == "Hitting" then
    					value = colored(GREEN, "Hitting")
    				elseif not ufo.eligible then
    					value = colored(RED, status)
    				else
    					value = colored(ORANGE, status)
    				end
    				setStat(UI.UfoStateRow, if ufo.active and ufo.world then "UFO  " .. dim(prettyWorld(ufo.world)) else "UFO", value)
    				if ufo.active and ufo.hp and ufo.maxHp and ufo.maxHp > 0 then
    					setStat(UI.UfoHpRow, nil, string.format("%s / %s", formatNumber(ufo.hp), formatNumber(ufo.maxHp)))
    					setProgress(UI.UfoHpRow, ufo.hp / ufo.maxHp)
    				else
    					setStat(UI.UfoHpRow, nil, dim("-"))
    					setProgress(UI.UfoHpRow, 0)
    				end
    				setStat(UI.UfoHitsRow, nil, string.format("%s / %s", formatNumber(Saved.ufoBroken), formatNumber(tonumber(Saved.ufoWon) or 0)))
    				if ufo.active and ufo.rank then
    					setStat(UI.UfoRankRow, nil, colored(if ufo.rank == 1 then GREEN else ORANGE, "#" .. ufo.rank) .. "  " .. formatNumber(ufo.myDmg or 0))
    				elseif ufo.active and ufo.helped then
    					setStat(UI.UfoRankRow, nil, dim("not in the top 3") .. (if ufo.topDmg and ufo.topDmg > 0 then "  " .. dim("#1 has " .. formatNumber(ufo.topDmg)) else ""))
    				else
    					setStat(UI.UfoRankRow, nil, dim("-"))
    				end
    			end
    
    			local worlds = Snap.worlds
    			if worlds then
    				if worlds.next then
    					local icon = CurrencyIcons[worlds.currency or "Coins"] or CurrencyIcons.Coins
    					local label = prettyWorld(worlds.next)
    					if (S.autoBuyWorlds or S.farmOP) and worlds.status and worlds.status ~= "" then
    						label = label .. "  " .. dim(worlds.status)
    					end
    					if worlds.price and not worlds.affordable then
    						local wait = eta(worlds.currency or "Coins", worlds.price - (worlds.balance or 0))
    						if wait then
    							label = label .. "  " .. dim(wait)
    						end
    					end
    					if worlds.price then
    						setStat(UI.WorldNextRow, label, if worlds.affordable then colored(GREEN, formatNumber(worlds.price)) else formatNumber(worlds.price), icon)
    						setProgress(UI.WorldNextRow, (worlds.balance or 0) / worlds.price)
    					else
    						setStat(UI.WorldNextRow, label, dim("?"), icon)
    						setProgress(UI.WorldNextRow, 0)
    					end
    				else
    					setStat(UI.WorldNextRow, "Next world", colored(GREEN, "All unlocked"), GameIcons.AlienWorld)
    					setProgress(UI.WorldNextRow, 1)
    				end
    				setStat(UI.WorldOwnedRow, nil, string.format("%d / %d", worlds.owned or 0, worlds.total or 0))
    				setStat(UI.WorldHereRow, nil, if worlds.here then prettyWorld(worlds.here) else dim("unknown"))
    			end
    
    			local shops = Snap.shops
    			if shops then
    				drawShop(shops.spawn, UI.SpawnRows, UI.SpawnLabels, UI.SpawnStateRow)
    				drawShop(shops.Permanent, UI.MoonPerm.rows, UI.MoonPerm.labels, UI.MoonPerm.state)
    				drawShop(shops.Incremental, UI.MoonIncr.rows, UI.MoonIncr.labels, UI.MoonIncr.state)
    			end
    			setStat(UI.MoonGemsRow, nil, if Snap.gems then formatNumber(Snap.gems) else "?")
    
    			local team = Snap.team
    			if team then
    				local maxEquip = Snap.items and Snap.items.maxEquip
    				local countText = if maxEquip then string.format("%d/%d", team.count, maxEquip) else tostring(team.count)
    				setStat(UI.TeamPowerRow, "Team power  " .. dim(countText), "x" .. formatNumber(team.power + 1))
    				for i, row in ipairs(UI.TeamRows) do
    					local entry = team.list[i]
    					if entry then
    						local label = string.format('%s  <font color="%s">%s</font>', entry.name, RarityColors[entry.rarity] or "#ffffff", entry.rarity)
    						local value = if entry.count > 1 then dim("x" .. entry.count .. "  ") .. formatNumber(entry.power) else formatNumber(entry.power)
    						setStat(row, label, value, entry.icon or GameIcons.EquipBest)
    						setVisible(row, true)
    					else
    						setVisible(row, false)
    					end
    				end
    				local more = #team.list - #UI.TeamRows
    				if more > 0 then
    					setLabel(UI.TeamMoreLabel, dim(string.format("+%d more pet%s", more, if more == 1 then "" else "s")))
    				end
    				setVisible(UI.TeamMoreLabel, more > 0)
    			end
    
    			local friends = Snap.friends
    			if friends then
    				if friends.percent then
    					local luck = math.floor(friends.percent / 5 + 0.5)
    					setStat(UI.FriendBoostRow, "Boost  " .. dim(string.format("+%d%% luck", luck)), colored(GREEN, string.format("+%d%%", math.floor(friends.percent + 0.5))))
    				else
    					setStat(UI.FriendBoostRow, "Boost", dim("+0%"))
    				end
    				setStat(UI.FriendCountRow, nil, string.format("%d / %d", friends.here or 0, friends.total or 0))
    				setStat(UI.FriendSentRow, nil, formatNumber(friends.sent or 0))
    			end
    			setStat(UI.HookSentRow, nil, formatNumber(Saved.webhooksSent))
    			setStat(UI.UfoStatRow, nil, formatNumber(Saved.ufoBroken))
    			setStat(UI.UfoWonStatRow, nil, string.format("%s / %s", formatNumber(tonumber(Saved.ufoWon) or 0), formatNumber(tonumber(Saved.ufoTop3) or 0)))
    			do
    				local before = tonumber(Saved.ufoBeforeRate) or -1
    				local hours = ((tonumber(Saved.farmTime) or 0) - (tonumber(Saved.ufoPetFarm) or 0)) / 3600
    				local won = (tonumber(Saved.ufoWon) or 0) - (tonumber(Saved.ufoPetWon) or 0)
    				setStat(UI.UfoRateStatRow, nil, string.format("%s / %s", if before >= 0 then string.format("%.2f", before) else "-", if hours >= 0.25 and won >= 0 then string.format("%.2f", won / hours) else "-"))
    			end
    			setStat(UI.UpgradeStatRow, nil, formatNumber(Saved.upgradesBought))
    			setStat(UI.WorldStatRow, nil, formatNumber(Saved.worldsBought))
    			setStat(UI.TreeStatRow, nil, formatNumber(Saved.treeBought))
    			setStat(UI.SpecialStatRow, nil, formatNumber(Saved.specialBought))
    			setStat(UI.RebirthStatRow, nil, formatNumber(Saved.rebirthsDone))
    			setStat(UI.CodeStatRow, nil, formatNumber(Saved.codesRedeemed))
    		end
    
    		local function statusValue(status, good)
    			status = tostring(status or "Off")
    			if status == "Off" then
    				return dim("Off")
    			end
    			if good[status] or string.find(status, "Buying", 1, true) or string.find(status, "Redeeming", 1, true) then
    				return colored(GREEN, status)
    			end
    			return colored(ORANGE, status)
    		end
    
    		local function drawExtras()
    			if Snap.rubies then
    				setStat(UI.RubiesRow, nil, formatNumber(Snap.rubies))
    			end
    			local tree = Snap.tree
    			if tree then
    				if tree.available then
    					setStat(UI.TreeOwnedRow, nil, string.format("%d / %d", tree.owned, tree.total))
    					setProgress(UI.TreeOwnedRow, if tree.total > 0 then tree.owned / tree.total else 0)
    				else
    					setStat(UI.TreeOwnedRow, nil, dim("-"))
    					setProgress(UI.TreeOwnedRow, 0)
    				end
    				if tree.next and tree.cost then
    					local spend = (Snap.rubies or 0) - (S.rubyReserve or 0)
    					local wait = if spend < tree.cost then eta("Rubies", tree.cost - spend) else nil
    					setStat(UI.TreeNextRow, tree.title .. (if wait then "  " .. dim(wait) else ""), if spend >= tree.cost then formatNumber(tree.cost) else colored(RED, formatNumber(tree.cost)), tree.image or CurrencyIcons.Rubies)
    				else
    					setStat(UI.TreeNextRow, "Next", if tree.allDone and tree.anyPicked then colored(GREEN, "Done") else dim("-"), CurrencyIcons.Rubies)
    				end
    				setStat(UI.TreeStateRow, nil, statusValue(tree.status, { ["All done"] = true }))
    			end
    			local special = Snap.special
    			if special then
    				setStat(UI.SpecialOwnedRow, nil, string.format("%d / %d", special.owned, special.total))
    				setProgress(UI.SpecialOwnedRow, if special.total > 0 then special.owned / special.total else 0)
    				if special.next then
    					local spend = (Snap.rubies or 0) - (S.rubyReserve or 0)
    					local wait = if spend < special.next.price then eta("Rubies", special.next.price - spend) else nil
    					local label = special.next.title .. (if wait then "  " .. dim(wait) elseif special.next.world then "  " .. dim(prettyWorld(special.next.world)) else "")
    					setStat(UI.SpecialNextRow, label, if spend >= special.next.price then formatNumber(special.next.price) else colored(RED, formatNumber(special.next.price)))
    				else
    					setStat(UI.SpecialNextRow, "Next", if special.allDone and special.anyPicked then colored(GREEN, "Done") else dim("-"))
    				end
    				setStat(UI.SpecialStateRow, nil, statusValue(special.status, { ["All owned"] = true, ["Going to buy"] = true }))
    			end
    			local rebirth = Snap.rebirth
    			if rebirth then
    				if rebirth.available and rebirth.cap > 0 then
    					setStat(UI.RebirthProgressRow, if rebirth.ready then "Progress  " .. colored(GREEN, "ready") else "Progress", string.format("%d / %d", rebirth.owned, rebirth.cap))
    					setProgress(UI.RebirthProgressRow, rebirth.owned / rebirth.cap)
    				else
    					setStat(UI.RebirthProgressRow, "Progress", dim("-"))
    					setProgress(UI.RebirthProgressRow, 0)
    				end
    				setStat(UI.MoonRebirthRow, nil, formatNumber(rebirth.rebirths or 0))
    				setStat(UI.RebirthStateRow, nil, statusValue(rebirth.status, { Rebirthing = true, ["Buying upgrades"] = true }))
    			end
    			local hop = Snap.hop
    			if hop then
    				if hop.active then
    					setStat(UI.UfoNextRow, nil, colored(GREEN, if hop.left and hop.left > 0 then "Active  " .. formatClock(hop.left) else "Active"))
    				elseif hop.state == "Incoming" and hop.left then
    					setStat(UI.UfoNextRow, nil, colored(ORANGE, "Landing in " .. formatClock(hop.left)))
    				elseif hop.left then
    					setStat(UI.UfoNextRow, nil, "in " .. formatClock(hop.left))
    				else
    					setStat(UI.UfoNextRow, nil, dim("..."))
    				end
    				local hopText = tostring(hop.status or "Off")
    				if hopText == "Off" then
    					setStat(UI.UfoHopRow, nil, dim("Off"))
    				elseif hopText == "Breaking the UFO" or string.find(hopText, "staying", 1, true) then
    					setStat(UI.UfoHopRow, nil, colored(GREEN, hopText))
    				else
    					setStat(UI.UfoHopRow, nil, colored(ORANGE, hopText))
    				end
    				setStat(UI.UfoHopRow, if (hop.hops or 0) > 0 then "Hop  " .. dim(hop.hops .. " so far") else "Hop", nil)
    				setStat(UI.UfoTimerRow, nil, if hop.global == true then "Same on every server" elseif hop.global == false then "Differs per server" else dim("checking..."))
    			end
    			local codes = Snap.codes
    			if codes then
    				setStat(UI.CodesFoundRow, nil, formatNumber(codes.found))
    				local okCodes, badCodes = 0, 0
    				for _, result in pairs(Saved.codes) do
    					if result == "Redeemed" or result == "Already used" then
    						okCodes += 1
    					elseif result == "Invalid" or result == "Expired" or result == "Empty" then
    						badCodes += 1
    					end
    				end
    				setStat(UI.CodesDoneRow, "Codes redeemed", okCodes .. " / invalid " .. badCodes)
    				if codes.last then
    					local result = tostring(codes.last.result)
    					setStat(UI.CodesLastRow, "Last  " .. dim(codes.last.code), if result == "Redeemed" then colored(GREEN, result) else colored(ORANGE, result))
    				end
    				setStat(UI.CodesStateRow, nil, statusValue(codes.status, { ["Up to date"] = true }))
    			end
    		end
    
    		Auto.drawMachines = drawMachines
    		Auto.drawItems = drawItems
    		Auto.drawHunt = drawHunt
    		Auto.drawRound = drawRound
    		Auto.drawExtras = drawExtras
    	end
    	setupDrawing()
    end
    
    local function drawQueues()
    	if Auto.stopHunter then
    		Auto.stopHunter = false
    		pcall(Toggles.IndexHunter.SetValue, Toggles.IndexHunter, false)
    	end
    	if Auto.stopUfoHop then
    		local message = Auto.stopUfoHop
    		Auto.stopUfoHop = nil
    		if Toggles.UfoHop and Toggles.UfoHop.Value then
    			pcall(Toggles.UfoHop.SetValue, Toggles.UfoHop, false)
    			notify("UFO Hop", tostring(message), 5)
    		end
    	end
    	if Auto.enableUfo then
    		Auto.enableUfo = nil
    		if Toggles.AutoUfo and not Toggles.AutoUfo.Value then
    			pcall(Toggles.AutoUfo.SetValue, Toggles.AutoUfo, true)
    		end
    	end
    	if Auto.resumeUfoHop then
    		local resume = Auto.resumeUfoHop
    		Auto.resumeUfoHop = nil
    		for label, seconds in pairs(UI.HopWindows) do
    			if seconds == resume.window then
    				pcall(Options.UfoHopWindow.SetValue, Options.UfoHopWindow, label)
    			end
    		end
    		pcall(Toggles.UfoHopChase.SetValue, Toggles.UfoHopChase, resume.chase)
    		pcall(Toggles.AutoUfo.SetValue, Toggles.AutoUfo, true)
    		pcall(Toggles.UfoHop.SetValue, Toggles.UfoHop, true)
    		notify("UFO Hop", "Back after a hop, checking this server", 4)
    	end
    	if Auto.stopAutoHatch then
    		local amount = Auto.stopAutoHatch
    		Auto.stopAutoHatch = nil
    		if Toggles.AutoHatch and Toggles.AutoHatch.Value then
    			pcall(Toggles.AutoHatch.SetValue, Toggles.AutoHatch, false)
    			notify("Eggs", "Stopped after " .. formatNumber(tonumber(amount) or 0) .. " eggs", 5)
    		end
    	end
    	while #NotifyQueue > 0 do
    		local item = table.remove(NotifyQueue, 1)
    		notify(item[1], item[2], 5)
    	end
    	if DiagText then
    		setLabel(DiagLabel, DiagText)
    		setVisible(DiagLabel, true)
    		pcall(Library.ConsoleLog, Library, DiagText, "error")
    		DiagText = nil
    	end
    end
    
    task.spawn(function()
    	while alive() do
    		task.wait(0.5)
    		if Library.Toggled ~= false then
    			pcall(drawFarm)
    			pcall(drawGifts)
    			pcall(drawParty)
    			pcall(drawEggs)
    			pcall(drawStats)
    			pcall(Auto.drawMachines)
    			pcall(Auto.drawItems)
    			pcall(Auto.drawHunt)
    			pcall(Auto.drawRound)
    			pcall(Auto.drawExtras)
    			pcall(Auto.drawAnalytics, false)
    			pcall(Auto.drawLive, false)
    			pcall(Auto.drawUpdate2)
    			pcall(Auto.drawFishing)
    		end
    		pcall(drawQueues)
    	end
    end)
    
    task.spawn(function()
    	task.wait(2)
    	if S.autoFarm and SetAutoBreaking then
    		pcall(function() SetAutoBreaking:FireServer(true) end)
    	end
    	if #initialEggs == 0 then
    		refreshEggs(true)
    	end
    end)
    
    local map = workspace:FindFirstChild("Map")
    local eggsFolder = map and map:FindFirstChild("Eggs")
    if eggsFolder then
    	Library:GiveSignal(eggsFolder.ChildAdded:Connect(function()
    		task.defer(refreshEggs, true)
    	end))
    end
    
    Library:AddCommand({
    	Name = "bens",
    	Aliases = { "ben" },
    	Args = "[on/off]",
    	Description = "Starts or stops Auto Find Bens",
    	Callback = function(Args)
    		local State = if Args[1] then Args[1] == "on" else not Toggles.AutoBen.Value
    		Toggles.AutoBen:SetValue(State)
    		return "Auto Find Bens " .. (if State then "on" else "off")
    	end,
    })
    
    Library:AddCommand({
    	Name = "fish",
    	Aliases = { "fishing" },
    	Args = "[on/off]",
    	Description = "Starts or stops Auto Fish",
    	Callback = function(Args)
    		local State = if Args[1] then Args[1] == "on" else not Toggles.AutoFish.Value
    		Toggles.AutoFish:SetValue(State)
    		return "Auto Fish " .. (if State then "on" else "off")
    	end,
    })
    
    Library:AddCommand({
    	Name = "tap",
    	Args = "[on/off]",
    	Description = "Turns Auto Tap on or off",
    	Callback = function(Args)
    		local State = if Args[1] then Args[1] == "on" else not Toggles.AutoTap.Value
    		Toggles.AutoTap:SetValue(State)
    		return "Auto Tap " .. (if State then "on" else "off")
    	end,
    })
    
    Library:AddCommand({
    	Name = "planner",
    	Aliases = { "smart", "plan" },
    	Args = "[on/off]",
    	Description = "Turns the Smart Planner on or off",
    	Callback = function(Args)
    		local State = if Args[1] then Args[1] == "on" else not Toggles.SmartPlan.Value
    		Toggles.SmartPlan:SetValue(State)
    		return "Smart Planner " .. (if State then "on" else "off")
    	end,
    })

    Library:AddCommand({
    	Name = "farm",
    	Args = "[on/off]",
    	Description = "Starts or stops the auto farm",
    	Callback = function(Args)
    		local State = if Args[1] then Args[1] == "on" else not Toggles.AutoFarm.Value
    		Toggles.AutoFarm:SetValue(State)
    		return "Auto Farm " .. (if State then "on" else "off")
    	end,
    })
    
    Library:OnUnload(function()
    	INSTANCE.stop = true
    	saveStats(true)
    	if SetAutoBreaking and S.autoFarm then
    		pcall(function() SetAutoBreaking:FireServer(false) end)
    	end
    	if Auto.Fish and Auto.Fish.active and Auto.Fish.own then
    		local remote = Auto.knitRemote("FishingService", "RF", "StopFishing")
    		if remote then
    			task.spawn(Auto.invokeTimeout, remote, 5)
    		end
    	end
    end)
    
    Tabs.Commands = Window:AddCommandsTab()
    Tabs.RemoteSpy = Window:AddRemoteSpyTab()
    
    UI.MetricColors = {
    	Coins = Color3.fromHex("c98500"),
    	Gems = Color3.fromHex("9085e9"),
    	Eggs = Color3.fromHex("199e70"),
    	Rubies = Color3.fromHex("e66767"),
    }
    UI.RangeSeconds = { ["15m"] = 900, ["1h"] = 3600, ["6h"] = 21600, ["24h"] = 86400 }
    UI.RangeEdge = { ["15m"] = { "15m ago", "7m", "now" }, ["1h"] = { "1h ago", "30m", "now" }, ["6h"] = { "6h ago", "3h", "now" }, ["24h"] = { "24h ago", "12h", "now" } }
    
    UI.RatesBox = Tabs.Analytics:AddLeftGroupbox("Live Rates", "activity")
    UI.RateTiles = UI.RatesBox:AddStatTiles({
    	Tiles = {
    		{ Id = "Coins", Label = "Coins", Color = UI.MetricColors.Coins },
    		{ Id = "Gems", Label = "Gems", Color = UI.MetricColors.Gems },
    		{ Id = "Eggs", Label = "Eggs", Color = UI.MetricColors.Eggs },
    		{ Id = "Rubies", Label = "Rubies", Color = UI.MetricColors.Rubies },
    	},
    })
    UI.RatesBox:AddLabel({ Text = '<font transparency="0.45">Per hour, last 5 minutes. Arrows compare with your last hour.</font>', DoesWrap = true })
    
    UI.TrendBox = Tabs.Analytics:AddLeftGroupbox("Trend", "chart-spline")
    UI.TrendChart = UI.TrendBox:AddChart("TrendChart", {
    	Metrics = { "Coins", "Rubies", "Gems", "Eggs" },
    	Ranges = { "15m", "1h", "6h", "24h" },
    	Range = "15m",
    	Height = 132,
    	Changed = function()
    		if Auto.drawAnalytics then
    			Auto.drawAnalytics(true)
    		end
    	end,
    })
    
    UI.GoalsBox = Tabs.Analytics:AddRightGroupbox("Goals", "target")
    UI.Goals = UI.GoalsBox:AddGoals("GoalCards", {
    	EmptyText = "No goals yet. Pick what you want to collect below and Corvus tracks it with a live ETA.",
    	Removed = function(id)
    		if Auto.removeGoal then
    			Auto.removeGoal(id)
    		end
    	end,
    })
    UI.GoalKinds = { "Coins", "Rubies", "Gems", "Eggs opened", "Index entries" }
    UI.GoalsBox:AddDropdown("GoalKind", {
    	Text = "Collect",
    	Values = UI.GoalKinds,
    	ValueImages = { Coins = CurrencyIcons.Coins, Rubies = CurrencyIcons.Rubies, Gems = CurrencyIcons.Gems, ["Eggs opened"] = GameIcons.Egg, ["Index entries"] = GameIcons.Index },
    	Default = "Coins",
    })
    UI.GoalsBox:AddInput("GoalTarget", {
    	Text = "Target",
    	Placeholder = "10b, 500k, 1.5t... (empty = full index)",
    	Default = "",
    	ClearTextOnFocus = false,
    })
    UI.GoalsBox:AddButton({
    	Text = "Add goal",
    	Func = function()
    		if Auto.addGoal and Auto.addGoal(Options.GoalKind.Value, Options.GoalTarget.Value) then
    			pcall(Options.GoalTarget.SetValue, Options.GoalTarget, "")
    		end
    	end,
    }):AddButton({
    	Text = "Clear reached",
    	Func = function()
    		if Auto.clearGoals then
    			Auto.clearGoals()
    		end
    	end,
    })
    
    UI.HatchBox = Tabs.Analytics:AddRightGroupbox("Hatches", "egg")
    UI.HatchBars = UI.HatchBox:AddBarChart({
    	Scopes = { "Session", "All time" },
    	EmptyText = "Hatch an egg to fill this in",
    	Changed = function()
    		if Auto.drawAnalytics then
    			Auto.drawAnalytics(true)
    		end
    	end,
    })
    
    UI.LuckBox = Tabs.Analytics:AddRightGroupbox("Luck", "clover")
    UI.LuckEggRow = UI.LuckBox:AddStat({ Icon = GameIcons.Egg, Text = "Egg", Value = "-", Size = 24, ValueColor = "FontColor" })
    UI.LuckRows = {}
    for _, tier in ipairs({ "Legendary", "Mythical", "Secret" }) do
    	UI.LuckRows[tier] = UI.LuckBox:AddStat({ Icon = Rarities and Rarities[tier] and Rarities[tier][2] or GameIcons.Index, Text = tier, Value = "-", Size = 24, Progress = 0, ValueColor = "FontColor" })
    end
    UI.LuckBox:AddLabel({ Text = '<font transparency="0.45">First number: eggs opened since your last pet of that rarity or better. Second: how many eggs it takes on average from this egg (K = thousand, M = million). The bar fills as you get closer. On the right: how often it happens at your egg speed. Luck boosts make it sooner.</font>', DoesWrap = true })
    
    function Auto.drawAnalytics(force)
    	local M = Auto.Metrics
    	if not M then return end
    	local active = Library.ActiveTab == Tabs.Analytics
    	if not active and force ~= true then return end
    	local clock = os.clock()
    	if force ~= true and clock - (UI.analyticsAt or -1e9) < 3 then return end
    	UI.analyticsAt = clock
    
    	local hourly = {}
    	for _, key in ipairs({ "Coins", "Gems", "Eggs", "Rubies" }) do
    		local rate = M.current(key)
    		local hour = M.mean(M.series(key, 3600, 30))
    		hourly[key] = hour
    		UI.RateTiles:SetTile(key, {
    			Value = if rate then formatNumber(rate) else "-",
    			Suffix = "/h",
    			Delta = if rate and hour and hour > 0 then (rate - hour) / hour else nil,
    			Note = if rate == nil then "warming up" else "",
    			Points = M.series(key, 1800, 12),
    		})
    	end
    
    	local metric = UI.TrendChart.Metric or "Coins"
    	local rangeName = UI.TrendChart.Range or "1h"
    	local range = UI.RangeSeconds[rangeName] or 3600
    	local count = 60
    	local values = M.series(metric, range, count)
    	local average = M.mean(values)
    	local current = M.current(metric)
    	local now = M.now()
    	local labels = {}
    	for i = 1, count do
    		local t = now - range + range * (i - 1) / (count - 1)
    		local ok, text = pcall(os.date, "%H:%M", math.floor(t))
    		labels[i] = if ok then text else ""
    	end
    	local events = {}
    	for i = #M.events, 1, -1 do
    		local event = M.events[i]
    		if #events >= 12 then break end
    		if tonumber(event.t) and event.t >= now - range then
    			local color = nil
    			if type(event.c) == "string" then
    				local ok, parsed = pcall(Color3.fromHex, event.c)
    				color = if ok then parsed else nil
    			end
    			table.insert(events, {
    				Index = math.floor((event.t - (now - range)) / range * (count - 1) + 0.5) + 1,
    				Color = color or Library.Scheme.AccentColor,
    				Text = event.x,
    			})
    		end
    	end
    	UI.TrendChart:SetData({
    		Values = values,
    		Color = UI.MetricColors[metric],
    		Headline = if current then formatNumber(current) else "-",
    		Suffix = if metric == "Eggs" then "eggs/h" else string.lower(metric) .. "/h",
    		Delta = if current and average and average > 0 then (current - average) / average else nil,
    		DeltaLabel = "vs " .. rangeName .. " average",
    		Subtitle = "Rate over the last 5 minutes",
    		Average = average,
    		XLabels = UI.RangeEdge[rangeName],
    		Labels = labels,
    		Events = events,
    		Format = formatNumber,
    		EmptyText = "Farm for a minute to see your " .. string.lower(metric) .. " per hour",
    	})
    
    	local counts = if UI.HatchBars.Scope == "All time" then Saved.rarity else (Session.rarity or {})
    	local bars = {}
    	for _, rarity in ipairs(Items.Rarities) do
    		local amount = tonumber(counts[rarity]) or 0
    		if amount > 0 then
    			local ok, color = pcall(Color3.fromHex, RarityColors[rarity] or "#ffffff")
    			table.insert(bars, { Label = rarity, Value = amount, Color = if ok then color else nil, Text = formatNumber(amount) })
    		end
    	end
    	UI.HatchBars:SetData(bars)
    
    	local luck = Snap.luck
    	if luck then
    		setStat(UI.LuckEggRow, nil, if luck.egg and luck.egg ~= "" then luck.egg else '<font transparency="0.5">none selected</font>')
    		for tier, row in pairs(UI.LuckRows) do
    			local info = luck.tiers[tier]
    			local label = string.format('<font color="%s">%s</font>%s', RarityColors[tier] or "#ffffff", tier, if tier == "Secret" then "" else "+")
    			if info and info.expected then
    				local big = string.gsub(formatNumber(info.expected), "[kmbt]$", string.upper)
    				local perHour = Auto.Metrics and Auto.Metrics.current("Eggs")
    				local every
    				if type(perHour) == "number" and perHour > 0 then
    					local hours = info.expected / perHour
    					every = if hours < 1 then string.format("every ~%dm", math.max(1, math.floor(hours * 60 + 0.5))) elseif hours < 48 then string.format("every ~%sh", (string.gsub(string.format("%.1f", hours), "%.0$", ""))) elseif hours < 24 * 365 then string.format("every ~%dd", math.floor(hours / 24 + 0.5)) else "over a year"
    				else
    					every = "1 in " .. big
    				end
    				local late = info.since > info.expected
    				setStat(row, label .. string.format('  <font transparency="0.45">%s of %s</font>', formatNumber(info.since), big), if late then '<font color="#ffb84d">' .. every .. "</font>" else every)
    				pcall(row.SetProgress, row, math.clamp(info.since / info.expected, 0, 1))
    			else
    				setStat(row, label, '<font transparency="0.5">not in this egg</font>')
    				pcall(row.SetProgress, row, 0)
    			end
    		end
    	end
    end
    
    -- Quick Start: the main loop toggles as two-way mirrors of the originals in their tabs
    for _, id in ipairs({ "AutoFarm", "AutoTap", "AutoHatch", "AutoFish", "AutoSpawnUpgrades" }) do
    	pcall(Library.MirrorToggle, Library, id, UI.AllBox)
    end
    UI.AllBox:AddDivider()
    UI.AllBox:AddButton({
    	Text = "Stop Everything",
    	Tooltip = "Switches off every automatic toggle",
    	Func = function()
    		Auto.stopEverything()
    	end,
    })
    UI.AllBox:AddButton({
    	Text = "Reset Hub Options",
    	Tooltip = "Puts every toggle, dropdown, slider and input back to its default value. Saved configs are not deleted.",
    	Func = function()
    		Library:AskResetHubOptions(Library.ShareIgnore)
    	end,
    })

    if Library.SetQuickBar then
    	Library:SetQuickBar({
    		{ Toggle = "SmartPlan", Icon = "brain", Label = "Planner" },
    		{ Toggle = "AutoFarm", Icon = "swords", Label = "Farm" },
    		{ Toggle = "AutoHatch", Icon = "egg", Label = "Eggs" },
    		{ Toggle = "AutoUfo", Icon = "rocket", Label = "UFO" },
    		{ Toggle = "IndexHunter", Icon = "book-open", Label = "Hunt" },
    		{ Toggle = "AutoFish", Icon = "fish", Label = "Fish", Default = false },
    		{ Toggle = "AutoLucky", Icon = "package-open", Label = "Lucky", Default = false },
    		{ Toggle = "AutoQuests", Icon = "gift", Label = "Quests", Default = false },
    		{ Toggle = "AutoFruitMachine", Icon = "apple", Label = "Fruit", Default = false },
    		{ Toggle = "UfoHop", Icon = "radar", Label = "Hop", Default = false },
    	})
    end
    
    UI.ExecBox = Tabs.Misc:AddRightGroupbox("Auto Execute", "zap")
    UI.ExecBox:AddToggle("KeepOnTeleport", {
    	Text = "Keep after teleport",
    	Description = "Starts again after a rejoin, hop or reconnect",
    	Tooltip = "Works like Keep Infinite Yield: when the game teleports you, the hub is queued to start on the next server.",
    	Default = true,
    	Callback = function(v)
    		S.keepOnTeleport = v
    	end,
    })
    UI.ExecStartRow = UI.ExecBox:AddStat({ Icon = "zap", Text = "This start", Value = "...", Size = 22, ValueColor = "FontColor" })
    UI.ExecReloadRow = UI.ExecBox:AddStat({ Icon = "link", Text = "Reload source", Value = "...", Size = 22, ValueColor = "FontColor" })
    UI.ExecBox:AddButton({
    	Text = "Copy auto execute loader",
    	Func = function()
    		local source = Auto.loaderSource("autoexec")
    		pcall(function()
    			if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("Corvus") then
    				makefolder("Corvus")
    			end
    			if type(writefile) == "function" then
    				writefile("Corvus/autoexec_loader.lua", source)
    			end
    		end)
    		local copied = pcall(function()
    			(setclipboard or toclipboard)(source)
    		end)
    		notify("Auto Execute", if copied then "Loader copied. Paste it into a new file in your executor's autoexec folder." else "Saved to workspace/Corvus/autoexec_loader.lua. Move it into your executor's autoexec folder.", 7)
    	end,
    })
    UI.ExecBox:AddLabel({ Text = '<font transparency="0.45">Joining from the Roblox menu needs your executor\'s autoexec folder. The loader waits until the game has fully loaded and only starts in Pets Universe, so it never slows down other games.</font>', DoesWrap = true })
    do
    	local startedBy = tostring(Boot.CorvusStartedBy or "")
    	Boot.CorvusStartedBy = nil
    	UI.ExecStartedBy = ({ autoexec = "Auto execute", teleport = "After teleport", hop = "After a hop", reconnect = "After reconnect" })[startedBy] or "You started it"
    	UI.ExecStartedKind = startedBy
    	pcall(function()
    		Library:GiveSignal(LocalPlayer.OnTeleport:Connect(function(state)
    			if state == Enum.TeleportState.Started and S.keepOnTeleport then
    				Auto.queueSelf("teleport")
    			end
    		end))
    	end)
    end
    
    function Auto.oneInShort(percent)
    	percent = tonumber(percent)
    	if not percent or percent <= 0 then return "?" end
    	local n = 100 / percent
    	if n < 1.05 then return "100%" end
    	if n < 10 then
    		return "1/" .. (string.gsub(string.format("%.1f", n), "%.0$", ""))
    	end
    	return "1/" .. (string.gsub(Library.ChartCompact(math.floor(n + 0.5)), "[kmbt]$", string.upper))
    end
    
    function Auto.galleryDetail(pet, filter)
    	if type(pet) ~= "table" then return "" end
    	local color = RarityColors[pet.rarity] or RarityColors.Basic
    	local head = string.format('<b>%s%s</b>  <font color="%s">%s</font>', if filter == "Normal" then "" else filter .. " ", pet.name, color, pet.rarity)
    	if filter ~= "Normal" then
    		return head .. string.format('<font transparency="0.35">  \u{00B7}  crafted at the %s Machine from your %s pets</font>', filter, if filter == "Golden" then "normal" else "golden")
    	end
    	local where = if pet.egg then string.format("%s, %s", pet.egg, Auto.oneIn and Auto.oneIn(pet.percent) or "?") else "no egg found"
    	local tail
    	if pet.locked then
    		tail = "unlock its world first"
    	elseif S.huntPin == pet.id then
    		tail = if S.indexHunt then "pinned, the hunter goes for it first" else "pinned, turn on Index Hunter to go for it"
    	else
    		tail = "tap to hunt it first"
    	end
    	return head .. '<font transparency="0.35">  \u{00B7}  ' .. where .. "  \u{00B7}  " .. tail .. "</font>"
    end
    
    do
    	local U2Progress = {}
    	local function u2Progress(row, value)
    		value = math.clamp(tonumber(value) or 0, 0, 1)
    		local key = math.floor(value * 400 + 0.5)
    		if U2Progress[row] == key then return end
    		if pcall(row.SetProgress, row, value) then
    			U2Progress[row] = key
    		end
    	end
    	local function paint(color, text)
    		return string.format('<font color="%s">%s</font>', color, text)
    	end
    	local function faint(text)
    		return '<font transparency="0.5">' .. text .. "</font>"
    	end
    	local GOOD, WARN, BAD = "#60d696", "#ffb84d", "#ff6e8a"
    
    	function Auto.drawUpdate2()
    		local u2 = Snap.u2
    		if not u2 then return end
    		local function t(sec)
    			return if Auto.formatClock then Auto.formatClock(sec) else Library:FormatDuration(sec)
    		end
    
    		local luck = u2.luck
    		if luck then
    			local value = if luck.left > 0 then paint(GOOD, string.format("x%s  %s", tostring(luck.mult), t(luck.left))) else faint("x1  \u{00B7}  not active")
    			setStat(UI.ServerLuckNowRow, nil, value)
    			u2Progress(UI.ServerLuckNowRow, luck.left / math.max(1, luck.max))
    			local units = if S.luckMode == "10 minutes" then 1 elseif S.luckMode == "Max" then luck.fit else (luck.hourUnits or 6)
    			local cost = units * luck.price
    			if units <= 0 or luck.fit < units then
    				setStat(UI.ServerLuckPriceRow, "Price", faint("timer is full"))
    			else
    				setStat(UI.ServerLuckPriceRow, "Price  " .. faint("+" .. t(units * luck.unit)), if (u2.rubies or 0) >= cost then formatNumber(cost) else paint(BAD, formatNumber(cost)))
    			end
    		end
    		local luckStatus = tostring(u2.luckStatus or "Off")
    		setStat(UI.ServerLuckStateRow, nil, if luckStatus == "Off" then faint("Off") elseif luckStatus == "Bought" or luckStatus == "Topped up" then paint(GOOD, luckStatus) else paint(WARN, luckStatus))
    		setStat(UI.ServerLuckBoughtRow, nil, formatNumber(tonumber(Saved.serverLuckBuys) or 0))
    
    		if UI.FMAutoRow then
    			setVisible(UI.FMAutoRow, u2.sp17 == true)
    			local value
    			if u2.fruitAuto then
    				value = paint(GOOD, "On")
    			elseif u2.fruitStatus then
    				value = paint(WARN, tostring(u2.fruitStatus))
    			elseif S.autoFruitMachine then
    				value = faint("switching on")
    			else
    				value = faint("Off")
    			end
    			setStat(UI.FMAutoRow, nil, value)
    		end
    
    		if UI.ItemCraftReadyRow then
    			local text = u2.craftText or ""
    			local ready = tonumber(u2.craftReady) or 0
    			setStat(UI.ItemCraftReadyRow, nil, if text ~= "" then text .. (if ready > 1 then "  " .. faint("+" .. (ready - 1)) else "") else faint("nothing yet"))
    			local status = tostring(u2.craftStatus or "Off")
    			setStat(UI.ItemCraftStateRow, nil, if status == "Off" then faint("Off") elseif status == "Crafted" then paint(GOOD, status) elseif status == "Waiting for items" then faint(status) else paint(WARN, status))
    			setStat(UI.ItemCraftDoneRow, nil, formatNumber(tonumber(Saved.itemsCrafted) or 0))
    		end
    	end
    
    	local function trimmed(value, digits)
    		return (string.gsub(string.format("%." .. digits .. "f", tonumber(value) or 0), "%.?0+$", ""))
    	end
    
    	local function statusColor(status, good)
    		status = tostring(status or "Off")
    		if status == "Off" or status == "Waiting" or status == "Nothing to open" or status == "Nothing to do" then
    			return faint(status)
    		end
    		if good[status] or string.find(status, "Buying", 1, true) or string.find(status, "Opening", 1, true) or string.find(status, "Selling", 1, true) then
    			return paint(GOOD, status)
    		end
    		if string.find(status, "failed", 1, true) or string.find(status, "Unavailable", 1, true) then
    			return paint(BAD, status)
    		end
    		return paint(WARN, status)
    	end
    
    	function Auto.drawFishing()
    		setLabel(UI.FishSinceLabel, '<font transparency="0.45">Counting for</font> ' .. Library:FormatDuration(os.time() - (tonumber(Saved.fishSince) or os.time())))
    		setStat(UI.FishCaughtStatRow, nil, formatNumber(tonumber(Saved.fishCaught) or 0))
    		setStat(UI.FishRareStatRow, nil, formatNumber(tonumber(Saved.fishRare) or 0))
    		setStat(UI.FishSoldStatRow, nil, formatNumber(tonumber(Saved.fishSold) or 0))
    		setStat(UI.TokensStatRow, nil, formatNumber(tonumber(Saved.tokensEarned) or 0))
    		setStat(UI.MerchantStatRow, nil, formatNumber(tonumber(Saved.merchantBought) or 0))
    		setStat(UI.FishTreeStatRow, nil, formatNumber(tonumber(Saved.fishTreeBought) or 0))
    		setStat(UI.InvEggStatRow, nil, formatNumber(tonumber(Saved.invEggsOpened) or 0))
    
    		local fish = Snap.fish
    		if not fish then
    			return
    		end
    
    		setStat(UI.FishStateRow, nil, statusColor(fish.status, { Fishing = true, Casting = true }))
    		setStat(UI.FishSpotRow, nil, if fish.world then prettyWorld(fish.world) else faint("where you stand"))
    		local index = fish.index
    		if index and index.total > 0 then
    			setStat(UI.FishIndexRow, nil, string.format("%d / %d", index.have, index.total))
    			u2Progress(UI.FishIndexRow, index.have / index.total)
    			if #index.missing == 0 then
    				setStat(UI.FishMissingRow, nil, paint("#5ef08a", "Fish index done"))
    			elseif not S.fishIndexHunt then
    				setStat(UI.FishMissingRow, nil, faint(#index.missing .. " missing, hunter off"))
    			elseif index.key then
    				setStat(UI.FishMissingRow, nil, tostring(index.names[1] or "") .. (if #index.names > 1 then faint("  +" .. (#index.names - 1)) else "") .. faint("  1 in " .. formatNumber(math.ceil(1 / index.chance))))
    			elseif (index.craftOnly or 0) >= #index.missing then
    				setStat(UI.FishMissingRow, nil, paint("#ffb84d", "Crafting " .. #index.missing .. " at the machines"))
    			else
    				setStat(UI.FishMissingRow, nil, paint("#ffb84d", "Unlock more fishing worlds"))
    			end
    		end
    		if UI.FishFilterRow then
    			if not (index and index.total > 0) then
    				setStat(UI.FishFilterRow, nil, faint("Nothing picked, choose rarities and variants"))
    			elseif #index.missing == 0 then
    				local parts = {}
    				for _, variant in ipairs({ "Normal", "Golden", "Diamond" }) do
    					local group = index.groups and index.groups[variant]
    					if group and group.total > 0 then
    						table.insert(parts, group.total .. " " .. string.lower(variant))
    					end
    				end
    				setStat(UI.FishFilterRow, nil, paint("#5ef08a", "All done") .. faint("  \u{00B7}  " .. table.concat(parts, ", ")))
    			else
    				local parts = {}
    				for _, variant in ipairs({ "Normal", "Golden", "Diamond" }) do
    					local group = index.groups and index.groups[variant]
    					if group and group.total > 0 then
    						table.insert(parts, variant .. " " .. (group.total - group.have))
    					end
    				end
    				local rarities = {}
    				for _, rarity in ipairs(Items.HuntRarities) do
    					local n = index.rarity and index.rarity[rarity]
    					if n and n > 0 then
    						table.insert(rarities, rarity .. " " .. n)
    					end
    				end
    				setStat(UI.FishFilterRow, nil, table.concat(parts, "  ") .. (if #rarities > 0 then faint("  \u{00B7}  " .. table.concat(rarities, ", ")) else ""))
    			end
    		end
    		if fish.active and fish.left then
    			setStat(UI.FishTimerRow, nil, trimmed(fish.left, 1) .. "s")
    			u2Progress(UI.FishTimerRow, if fish.duration and fish.duration > 0 then 1 - fish.left / fish.duration else 0)
    		else
    			setStat(UI.FishTimerRow, nil, faint("-"))
    			u2Progress(UI.FishTimerRow, 0)
    		end
    		setStat(UI.FishCatchRow, nil, formatNumber(fish.catches or 0) .. "  " .. faint("this session"))
    		local last = fish.last
    		if last and last.kind == "Pet" then
    			local mutation = if last.mutation then (Auto.mutationInfo(last.mutation)) else nil
    			local value = string.format('<font color="%s">%s</font>', RarityColors[last.rarity or "Basic"] or RarityColors.Basic, tostring(last.rarity or "Basic"))
    			setStat(UI.FishLastRow, (if mutation then mutation .. " " else "") .. last.name, value .. (if last.deleted then faint("  auto deleted") else ""), last.icon or "fish")
    		elseif last then
    			local merchant = Auto.GameData.merchant
    			local icon = Items.Icons[last.name] or (type(merchant) == "table" and type(merchant.ICONS) == "table" and merchant.ICONS[last.name]) or "fish"
    			setStat(UI.FishLastRow, UI.MerchantNames[last.name] or Auto.itemDisplayName(last.name), "x" .. formatNumber(last.amount or 1), icon)
    		end
    		setStat(UI.FishStreakRow, nil, formatNumber(fish.streak or 0) .. "  " .. faint(formatNumber(fish.taps or 0) .. " taps"))
    		if fish.luck or fish.speed then
    			setStat(UI.FishBoostRow, nil, string.format("x%s  /  x%s", trimmed(fish.luck or 1, 2), trimmed(fish.speed or 1, 2)))
    		end
    		setStat(UI.FishRodRow, nil, if fish.rod then (string.gsub(fish.rod, "(%l)(%u)", "%1 %2")) else faint("Basic rod"))
    
    		if fish.worm then
    			setStat(UI.WormRow, (UI.MerchantNames[fish.worm] or fish.worm) .. "  " .. faint(formatNumber(fish.wormCount or 0) .. " owned"), paint(GOOD, Library:FormatDuration(fish.wormLeft or 0)))
    		else
    			setStat(UI.WormRow, "Worm  " .. faint(formatNumber(fish.wormCount or 0) .. " owned"), faint("none active"))
    		end
    		local charges = (fish.golden or 0) + (fish.normal or 0)
    		setStat(UI.HookRow, (if (fish.golden or 0) > 0 then "Golden Fishhook" else "Fishhook") .. "  " .. faint(formatNumber(fish.hookCount or 0) .. " owned"), if charges > 0 then paint(GOOD, formatNumber(charges) .. " catches") else faint("none active"))
    
    		setStat(UI.TokensRow, nil, formatNumber(fish.tokens or 0))
    		setStat(UI.SellReadyRow, nil, if (fish.sellCount or 0) > 0 then formatNumber(fish.sellCount) .. " pets  " .. faint("+" .. formatNumber(fish.sellValue or 0)) else faint("nothing"))
    		if fish.restock then
    			setStat(UI.RestockRow, nil, Auto.formatClock(fish.restock))
    			u2Progress(UI.RestockRow, 1 - fish.restock / math.max(1, fish.restockTotal or 1800))
    		end
    		setStat(UI.MerchantStateRow, nil, statusColor(fish.merchant, { Done = true, ["Going to the Merchant"] = true, ["Visiting the Merchant"] = true }))
    
    		local tree = fish.tree
    		if tree and tree.available then
    			setStat(UI.FishTreeOwnedRow, nil, string.format("%d / %d", tree.owned, tree.total))
    			u2Progress(UI.FishTreeOwnedRow, if tree.total > 0 then tree.owned / tree.total else 0)
    			if tree.next and tree.cost then
    				setStat(UI.FishTreeNextRow, tree.title, if tree.affordable then formatNumber(tree.cost) else paint(BAD, formatNumber(tree.cost)), tree.image or UI.TokenIcon)
    			else
    				setStat(UI.FishTreeNextRow, "Next", if tree.allDone and tree.anyPicked then paint(GOOD, "Done") else faint("-"), UI.TokenIcon)
    			end
    		else
    			setStat(UI.FishTreeOwnedRow, nil, faint("-"))
    		end
    		setStat(UI.FishTreeStateRow, nil, statusColor(tree and tree.status, { ["All done"] = true, ["Going to buy"] = true }))
    
    		local inv = fish.inv
    		if inv then
    			setStat(UI.InvEggOwnedRow, nil, formatNumber(inv.owned or 0))
    			setStat(UI.InvEggStateRow, nil, statusColor(inv.status, {}))
    			local changed = false
    			for _, name in ipairs(inv.names or {}) do
    				if not table.find(UI.InvEggNames, name) then
    					table.insert(UI.InvEggNames, name)
    					changed = true
    				end
    			end
    			if changed and Options.InvEggKeep then
    				table.sort(UI.InvEggNames)
    				pcall(Options.InvEggKeep.SetValues, Options.InvEggKeep, UI.InvEggNames)
    			end
    		end
    
    		local moon = fish.moonAuto
    		if moon then
    			local value
    			if moon.on then
    				value = paint(GOOD, "On")
    			elseif not moon.owned then
    				value = faint("needs Auto Buy Upgrades")
    			elseif moon.status then
    				value = paint(WARN, tostring(moon.status))
    			elseif S.moonGameAuto then
    				value = faint("switching on")
    			else
    				value = faint("Off")
    			end
    			setStat(UI.MoonAutoRow, nil, value)
    		end
    	end
    end
    
    function Auto.drawLive(force)
    	local tab = Library.ActiveTab
    	local clock = os.clock()
    	if tab == Tabs.Eggs or force == true then
    		local feed = Snap.feed
    		if UI.Feed and (feed ~= UI.feedShown or clock - (UI.feedAt or -1e9) >= 1 or force == true) then
    			UI.feedShown = feed
    			UI.feedAt = clock
    			UI.Feed:SetData(feed or {})
    		end
    		local gallery = Snap.gallery
    		local grid = UI.HuntGrid
    		if grid and gallery then
    			local filter = grid.Filter or "Normal"
    			local key = table.concat({ tostring(gallery), filter, tostring(S.huntPin), tostring(S.indexHunt) }, "|")
    			if key ~= UI.galleryKey or force == true then
    				UI.galleryKey = key
    				local list = gallery.lists[filter] or {}
    				local items = {}
    				local glowing = 0
    				for _, pet in ipairs(list) do
    					local caption
    					if filter ~= "Normal" then
    						caption = "craft"
    					elseif pet.locked then
    						caption = "locked"
    					else
    						caption = Auto.oneInShort(pet.percent)
    					end
    					if pet.target then
    						glowing += 1
    					end
    					local pinned = filter == "Normal" and S.huntPin == pet.id
    					table.insert(items, {
    						Id = pet.id,
    						Image = pet.icon or GameIcons.Index,
    						Color = RarityColors[pet.rarity] or RarityColors.Basic,
    						Caption = caption,
    						Dim = filter == "Normal" and pet.locked,
    						Highlight = pet.target,
    						Mark = if pinned then "pin" elseif pet.focus and pet.target then "crosshair" else nil,
    						MarkColor = if pinned then "#ffcf4d" else nil,
    						Detail = Auto.galleryDetail(pet, filter),
    						Pet = pet,
    					})
    				end
    				grid:SetItems(items)
    				local total = gallery.totals[filter] or 0
    				local summary = string.format("<b>%d</b> of %d missing", #list, total)
    				if glowing > 0 then
    					summary ..= string.format('  <font transparency="0.4">\u{00B7}  %d from this egg</font>', glowing)
    				elseif total > 0 and #list == 0 then
    					summary = '<font color="#60d696">All done</font>  <font transparency="0.4">\u{00B7}  ' .. total .. " " .. string.lower(filter) .. "</font>"
    				end
    				grid:SetSummary(summary)
    			end
    		end
    	end
    	if tab == Tabs.Analytics or force == true then
    		if UI.Goals and Auto.goalSnapshot and (force == true or clock - (UI.goalsAt or -1e9) >= 1) then
    			UI.goalsAt = clock
    			local entries = {}
    			for _, goal in ipairs(Auto.goalSnapshot(false)) do
    				local current = goal.current
    				local progress = if type(current) == "number" then math.clamp(current / goal.target, 0, 1) else 0
    				local note
    				if goal.done then
    					local ago = if goal.doneAt then math.max(0, os.time() - goal.doneAt) else 0
    					note = '<font color="#60d696">Reached</font>' .. (if ago >= 60 then string.format("  \u{00B7}  %s ago", Library:FormatDuration(ago)) else "")
    				elseif type(current) ~= "number" then
    					note = "Waiting for data"
    				elseif goal.eta then
    					note = goal.eta .. " at your current rate"
    				elseif goal.meta.metric then
    					note = formatNumber(goal.target - current) .. " to go  \u{00B7}  rate warming up"
    				else
    					note = formatNumber(goal.target - current) .. " to go"
    				end
    				table.insert(entries, {
    					Id = goal.id,
    					Title = goal.meta.label,
    					Icon = goal.meta.icon,
    					Color = goal.meta.color,
    					Progress = progress,
    					Done = goal.done,
    					Value = string.format("%s  <font transparency=\"0.45\">/ %s</font>", if type(current) == "number" then formatNumber(current) else "?", formatNumber(goal.target)),
    					Note = note,
    				})
    			end
    			UI.Goals:SetData(entries)
    		end
    	end
    end
    
    function Auto.applyWizard(values)
    	values = type(values) == "table" and values or {}
    	local tasks = type(values.tasks) == "table" and values.tasks or {}
    	local map = {
    		farm = { "AutoFarm" },
    		hatch = { "AutoHatch" },
    		index = { "IndexHunter" },
    		rewards = { "AutoGift", "AutoPartyEgg", "AutoQuests", "AutoMoonChest", "AutoGroupChest", "AutoFruitMachine", "AutoCodes" },
    		upgrades = { "AutoSpawnUpgrades", "AutoTree", "AutoSpecial" },
    		worlds = { "AutoBuyWorlds" },
    		ufo = { "AutoUfo" },
    		equip = { "AutoEquipBest" },
    		fish = { "AutoFish" },
    	}
    	if tasks.hatch and type(values.egg) == "string" and Options.HatchEgg then
    		pcall(Options.HatchEgg.SetValue, Options.HatchEgg, values.egg)
    	end
    	for key, ids in pairs(map) do
    		for _, id in ipairs(ids) do
    			local toggle = Toggles[id]
    			if toggle and (key ~= "hatch" or id ~= "EggAutoTravel" or tasks.hatch) then
    				pcall(toggle.SetValue, toggle, tasks[key] == true)
    			end
    		end
    	end
    	local function set(id, value)
    		local element = Toggles[id] or Options[id]
    		if element then
    			pcall(element.SetValue, element, value)
    		end
    	end
    	if values.device == "phone" then
    		set("CorvusAntiLagLevel", "Balanced")
    		set("CorvusAntiLag", true)
    		set("SkipHatchAnim", true)
    	elseif values.device == "afk" then
    		set("CorvusAntiLagLevel", "Ultra")
    		set("CorvusAntiLag", true)
    		set("SkipHatchAnim", true)
    		set("CorvusAntiAFK", true)
    		set("StopAfkRejoin", true)
    		set("CorvusAutoReconnect", true)
    		set("KeepOnTeleport", true)
    	end
    	Saved.setupDone = true
    	SaveDirty = true
    	saveStats(true)
    	local labels = { farm = "Farm", hatch = "Eggs", index = "Index", rewards = "Rewards", upgrades = "Upgrades", worlds = "Worlds", ufo = "UFO", equip = "Best pets", fish = "Fishing" }
    	local picked = {}
    	for _, key in ipairs({ "farm", "hatch", "index", "rewards", "upgrades", "worlds", "ufo", "equip", "fish" }) do
    		if tasks[key] then
    			table.insert(picked, labels[key])
    		end
    	end
    	notify("Quick setup done", if #picked > 0 then "Running: " .. table.concat(picked, ", ") else "Nothing turned on, pick things in the tabs any time", 6)
    end
    
    function Auto.openWizard()
    	local names = collectEggNames()
    	local visuals = getEggVisuals(names)
    	local eggChoices = {}
    	for index, name in ipairs(names) do
    		if index > 8 then break end
    		local known = Snap.eggPrices and Snap.eggPrices[name]
    		local price, free = known and known.price, known and known.free
    		table.insert(eggChoices, {
    			Id = name,
    			Title = name,
    			Description = if free then "Free right now" elseif price then formatNumber(price) .. " " .. string.lower(known and known.currency or "Coins") .. " each" else "Price unknown",
    			Icon = visuals[name] or GameIcons.Egg,
    			Color = "#3ccf91",
    		})
    	end
    	local defaultEgg = if S.hatchEggName ~= "" and table.find(names, S.hatchEggName) then S.hatchEggName else names[1]
    	return Library:ShowWizard({
    		SkipText = "Skip",
    		FinishText = "Start",
    		Steps = {
    			{
    				Id = "tasks",
    				Title = "What should Corvus do for you?",
    				Description = "Pick everything you want running. Tap again to unpick.",
    				Multi = true,
    				Required = true,
    				Default = {},
    				Choices = {
    					{ Id = "farm", Title = "Farm coins", Description = "Breaks coins and chests at full speed", Icon = "swords", Color = "#e0a526" },
    					{ Id = "hatch", Title = "Open eggs", Description = "Buys your egg whenever you can afford it", Icon = "egg", Color = "#3ccf91" },
    					{ Id = "index", Title = "Complete the index", Description = "Hunts missing pets, crafts Golden and Diamond", Icon = "book-open", Color = "#5fb8ff" },
    					{ Id = "rewards", Title = "Claim rewards", Description = "Gifts, quests, chests, party egg and codes", Icon = "gift", Color = "#ff5d8f" },
    					{ Id = "upgrades", Title = "Buy upgrades", Description = "Spends rubies: spawn shop, upgrade tree, special upgrades", Icon = "trending-up", Color = "#c77dff" },
    					{ Id = "worlds", Title = "Unlock worlds", Description = "Buys the next world when you have the coins", Icon = "globe", Color = "#7dffb3" },
    					{ Id = "ufo", Title = "UFO event", Description = "Joins every UFO and helps break it", Icon = "rocket", Color = "#e66767" },
    					{ Id = "equip", Title = "Equip best pets", Description = "Keeps your strongest team on", Icon = "paw-print", Color = "#ffb84d" },
    					{ Id = "fish", Title = "Go fishing", Description = "Casts, taps and catches fish for tokens", Icon = "fish", Color = "#8fe9ff" },
    				},
    			},
    			{
    				Id = "egg",
    				Title = "Which egg should it open?",
    				Description = "Eggs in your world right now. Corvus walks to it and opens it for you.",
    				Default = defaultEgg,
    				Choices = eggChoices,
    				Visible = function(state)
    					return type(state.tasks) == "table" and state.tasks.hatch == true and #eggChoices > 0
    				end,
    			},
    			{
    				Id = "device",
    				Title = "How does your game run?",
    				Description = "Corvus tunes performance for you. Nothing ever kicks you for low FPS.",
    				Default = if Library.IsMobile then "phone" else "smooth",
    				SingleColumn = true,
    				ChoiceHeight = 54,
    				Choices = {
    					{ Id = "smooth", Title = "Runs smooth", Description = "Keep the game exactly as it is", Icon = "monitor", Color = "#60d696" },
    					{ Id = "phone", Title = "Phone or weak PC", Description = "Anti lag on and the hatch cutscene skipped", Icon = "smartphone", Color = "#ffb84d" },
    					{ Id = "afk", Title = "AFK for hours", Description = "Ultra anti lag, anti AFK, auto reconnect, keeps running after teleports", Icon = "moon", Color = "#9085e9" },
    				},
    			},
    		},
    		Finish = function(values)
    			Auto.applyWizard(values)
    		end,
    		Skipped = function()
    			Saved.setupDone = true
    			SaveDirty = true
    			notify("Quick setup", "Skipped. You can open it again from the Info tab.", 4)
    		end,
    	})
    end
    
    Library.RenderOverlayInfo = function()
    	return string.format("+%s coins  \u{00B7}  %s eggs this session", formatNumber(Session.earned.Coins or 0), formatNumber(Session.eggs or 0))
    end
    
    Tabs.Settings = Window:AddSettingsTab({
    	ThemeManager = ThemeManager,
    	SaveManager = SaveManager,
    	Folder = "PetsUniverse",
    	MenuKeybind = "Z",
    })
    
    UI.DonateMethods = {
    	{ Id = "PayPal", Icon = "pay-paypal", Symbol = "PP", Name = "PayPal", Network = "paypal.me", Address = "https://paypal.me/KrystianKujawski73", Display = "KrystianKujawski73", Link = true, Color = "#0070e0", Note = "Paste the link in your browser and pick any amount" },
    	{ Id = "BTC", Icon = "pay-btc", Symbol = "BTC", Name = "Bitcoin", Network = "Bitcoin network", Address = "bc1q787972ksk3auu2d37gju8m6je0kx9mmskglsvh", Color = "#f7931a", Note = "Only send BTC on the Bitcoin network" },
    	{ Id = "ETH", Icon = "pay-eth", Symbol = "ETH", Name = "Ethereum", Network = "ERC20", Address = "0xBa0e07FdDB15fe3c9B7CE42F76cef8F09FEdAB64", Color = "#627eea", Note = "Only send ETH or ERC20 tokens on Ethereum" },
    	{ Id = "SOL", Icon = "pay-sol", Symbol = "SOL", Name = "Solana", Network = "Solana", Address = "4UriDCT4iBsLAuzLdowpSEL4mZq7Ecrxs4pNrV5ztHxW", Color = "#9945ff", Note = "Only send SOL or Solana tokens" },
    	{ Id = "BNB", Icon = "pay-bnb", Symbol = "BNB", Name = "BNB", Network = "BNB Smart Chain", Address = "0xBa0e07FdDB15fe3c9B7CE42F76cef8F09FEdAB64", Color = "#f0b90b", Note = "Only send on BNB Smart Chain (BEP20)" },
    }
    pcall(function()
    	local info = Tabs.Info
    	if not info then
    		return
    	end
    	local community = info.Groupboxes and info.Groupboxes.Community
    	if community then
    		community:AddLabel({
    			Text = '<font color="#60d696">All Corvus scripts are keyless and free.</font> <font transparency="0.35">Want your own script for any game? We make custom paid scripts on request, open a ticket on our Discord.</font>',
    			DoesWrap = true,
    		})
    	end
    	local right = info:AddRightGroupbox("Support Corvus", "heart", nil, true)
    	right:AddDonateBoard({ Methods = UI.DonateMethods })
    	right:AddLabel({
    		Text = '<font transparency="0.35">Donations are 100% voluntary, nothing is locked behind them. They help keep Corvus updated.</font>',
    		DoesWrap = true,
    	})
    	right.BoxHolder.LayoutOrder = -100
    end)
    
    Tabs.Main:Show()
    
    do
    	local key = "Z"
    	pcall(function()
    		if Options.MenuKeybind and Options.MenuKeybind.Value then
    			key = tostring(Options.MenuKeybind.Value)
    		end
    	end)
    	notify("Corvus", if Library.IsMobile then "Loaded and ready. The round Corvus button opens and closes the hub." else "Loaded. Press " .. key .. " to hide or show the menu.", 5)
    end
    
    setStat(UI.ExecStartRow, nil, UI.ExecStartedBy)
    setStat(UI.ExecReloadRow, nil, if CorvusConfig.LoaderUrl ~= "" then "Loader link" elseif Auto.canReload() then "Corvus/hub.lua" else '<font color="#ffb84d">Not set</font>')
    task.spawn(function()
    	if Saved.setupDone or (UI.ExecStartedKind and UI.ExecStartedKind ~= "" and UI.ExecStartedKind ~= "loader") then
    		return
    	end
    	local ok, autoload = pcall(SaveManager.GetAutoloadConfig, SaveManager)
    	if ok and type(autoload) == "string" and autoload ~= "" and autoload ~= "none" and autoload ~= "Auto Save" then
    		return
    	end
    	local waited = 0
    	while waited < 90 and not Library.Unloaded and (Library.IntroPlaying or Library.Toggled == false) do
    		waited += task.wait(0.5) or 0.5
    	end
    	task.wait(1.2)
    	if Library.Unloaded or Saved.setupDone or Library.Toggled == false or Library.ActiveWizard then
    		return
    	end
    	pcall(Auto.openWizard)
    end)
    Boot.CorvusBooting = nil
end, debug.traceback)
if not CorvusBootOk then
	local report = "[Corvus] Pets Universe failed to start:\n" .. tostring(CorvusBootError)
	warn(report)
	local env = getgenv()
	env.CorvusBooting = nil
	env.CorvusLastError = report
	local copied = pcall(setclipboard, report)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Corvus error",
			Text = if copied then "Hub failed to start. The error is copied, paste it to Cinek." else "Hub failed to start. Press F9 and send the red [Corvus] line.",
			Duration = 20,
		})
	end)
end
