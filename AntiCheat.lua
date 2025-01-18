-- Configuration
local speedLimit = 20 -- Maximum allowable speed in studs per second
local maxJumpHeight = 10 -- Maximum allowable jump height in studs
local teleportDistanceLimit = 50 -- Max distance a player can move in one check
local flagThreshold = 3 -- Number of violations before kicking
local detectionInterval = 0.3 -- Time interval for checks
local noclipGraceFrames = 2 -- Number of consecutive noclip detections before flagging
local debugMode = true -- Enable debug messages for testing

-- Whitelisted User IDs
local whitelistedUserIds = {
	[3013310676] = true, --histr221
	[1428684657] = true, --SomeoneStoleMyRubax
	[1708138976] = true, --iwzro12
}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Data storage
local playerData = {}

-- Utility: Check for noclip
local function checkNoclip(player, character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.FilterDescendantsInstances = {character}

		-- Cast a ray downward to check for ground
		local ray = Workspace:Raycast(rootPart.Position, Vector3.new(0, -5, 0), params)

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local isFalling = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Freefall

		-- If no collision and not falling, potential noclip
		return not ray and not isFalling
	end
	return false
end

-- Utility: Check for speed hacking
local function checkSpeed(player, data)
	local lastPosition = data.lastPosition
	local currentPosition = player.Character.PrimaryPart.Position
	local distance = (currentPosition - lastPosition).Magnitude
	local speed = distance / detectionInterval

	if speed > speedLimit then
		return true, speed
	end

	data.lastPosition = currentPosition
	return false, speed
end

-- Utility: Check for flying
local function checkFly(player, character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Blacklist
		params.FilterDescendantsInstances = {character}

		local ray = Workspace:Raycast(rootPart.Position, Vector3.new(0, -5, 0), params)
		return not ray -- No ground detected
	end
	return false
end

-- Monitor players
local function monitorPlayer(player)
	if whitelistedUserIds[player.UserId] then
		if debugMode then
			warn(player.Name .. " is whitelisted. Skipping anti-cheat checks.")
		end
		return
	end

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")

	local data = {
		lastPosition = humanoidRootPart.Position,
		flags = 0,
		noclipCounter = 0
	}
	playerData[player] = data

	while player.Parent and character.Parent do
		local violations = {}

		-- Speed check
		local speedViolation, speed = checkSpeed(player, data)
		if speedViolation then
			table.insert(violations, "Speed: " .. speed)
			data.flags += 1
		end

		-- Fly check
		if checkFly(player, character) then
			table.insert(violations, "Flying detected")
			data.flags += 1
		end

		-- Noclip check
		if checkNoclip(player, character) then
			data.noclipCounter += 1
			if data.noclipCounter >= noclipGraceFrames then
				table.insert(violations, "Noclip detected")
				data.flags += 1
			end
		else
			data.noclipCounter = 0 -- Reset if grounded
		end

		-- Debug messages
		if debugMode and #violations > 0 then
			warn(player.Name .. " violations: " .. table.concat(violations, ", "))
		end

		-- Take action
		if data.flags >= flagThreshold then
			player:Kick("You have been detected using exploits.")
			break
		end

		-- Wait before checking again
		task.wait(detectionInterval)
	end

	playerData[player] = nil
end

-- Handle new players
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.delay(2, function() -- Allow time for character to load
			monitorPlayer(player)
		end)
	end)
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
end)
