-- Whole hub in xpcall: a start error is shown, copied and kept for the loader's error report
local CorvusBootOk, CorvusBootError = xpcall(function()
    local Boot = getgenv()
    if Boot.CorvusBooting and os.clock() - Boot.CorvusBooting < 90 then
    	return
    end
    Boot.CorvusBooting = os.clock()
    if not game:IsLoaded() then
    	game.Loaded:Wait()
    end
    do
    	local players = game:GetService("Players")
    	local replicated = game:GetService("ReplicatedStorage")
    	local waited = 0
    	while not players.LocalPlayer and waited < 30 do
    		waited += task.wait(0.1) or 0.1
    	end
    	local packages = replicated:WaitForChild("Packages", 25)
    	local knit = packages and packages:WaitForChild("Knit", 25)
    	local services = knit and knit:WaitForChild("Services", 25)
    	if not (players.LocalPlayer and services and services:WaitForChild("EggHatchService", 20)) then
    		Boot.CorvusBooting = nil
    		warn("[Corvus] This is not Pets Universe, the hub was not started")
    		return
    	end
    	local started = false
    	task.spawn(function()
    		pcall(function()
    			require(knit).OnStart():await()
    		end)
    		started = true
    	end)
    	waited = 0
    	while not started and waited < 40 do
    		waited += task.wait(0.25) or 0.25
    	end
    	local player = players.LocalPlayer
    	waited = 0
    	while player:GetAttribute("SPdataLoaded") ~= true and waited < 20 do
    		waited += task.wait(0.25) or 0.25
    	end
    	player:WaitForChild("PlayerGui", 20)
    	task.wait(0.5)
    end
    
    local AddonsUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/"
    
