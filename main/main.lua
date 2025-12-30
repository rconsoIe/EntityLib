local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local EntityLib = {}

local localPlayer = Players.LocalPlayer

local entities = {}
local byModel = {}
local nextId = 0

local addedListeners = {}
local removedListeners = {}

local function emit(listeners, ...)
	for fn in pairs(listeners) do
		fn(...)
	end
end

local function newId()
	nextId += 1
	return nextId
end

local function getLocalHRP()
	local char = localPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function isEnemy(entity)
	if entity.player == nil then
		return true
	end
	return entity.player ~= localPlayer
end

local function createEntity(model, player)
	if byModel[model] then
		return byModel[model]
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		return
	end

	local entity = {
		id = newId(),
		model = model,
		player = player,
		humanoid = humanoid,
		hrp = hrp,
		isNPC = player == nil
	}

	entities[entity.id] = entity
	byModel[model] = entity

	emit(addedListeners, entity)

	return entity
end

local function removeEntity(entity)
	if not entity then return end
	entities[entity.id] = nil
	byModel[entity.model] = nil
	emit(removedListeners, entity)
end

-- =====================
-- Core API
-- =====================

function EntityLib.init()
	return EntityLib
end

function EntityLib.getAll()
	local list = {}
	for _, e in pairs(entities) do
		list[#list + 1] = e
	end
	return list
end

function EntityLib.fromModel(model)
	return byModel[model]
end

function EntityLib.fromPlayer(player)
	return player.Character and byModel[player.Character]
end

function EntityLib.isAlive(entity)
	return entity.humanoid and entity.humanoid.Health > 0
end

-- =====================
-- Spatial Queries
-- =====================

function EntityLib.getNearby(radius, angle)
	local hrp = getLocalHRP()
	if not hrp then return {} end

	local origin = hrp.Position
	local radiusSq = radius * radius
	local results = {}

	local cam = Workspace.CurrentCamera
	local look = cam and cam.CFrame.LookVector or hrp.CFrame.LookVector
	local cosLimit = angle and math.cos(math.rad(angle) * 0.5)

	for _, e in pairs(entities) do
		if e.hrp and e ~= EntityLib.fromPlayer(localPlayer) then
			local delta = e.hrp.Position - origin
			local distSq = delta:Dot(delta)

			if distSq <= radiusSq then
				if angle then
					if delta.Unit:Dot(look) >= cosLimit then
						results[#results + 1] = e
					end
				else
					results[#results + 1] = e
				end
			end
		end
	end

	return results
end

function EntityLib.getClosest(radius, angle)
	local list = EntityLib.getNearby(radius, angle)
	local best, bestDist

	local hrp = getLocalHRP()
	if not hrp then return end

	for _, e in ipairs(list) do
		local d = (e.hrp.Position - hrp.Position).Magnitude
		if not best or d < bestDist then
			best = e
			bestDist = d
		end
	end

	return best
end

function EntityLib.getNearestEnemy(radius, angle)
	local list = EntityLib.getNearby(radius, angle)
	local best, bestDist

	local hrp = getLocalHRP()
	if not hrp then return end

	for _, e in ipairs(list) do
		if isEnemy(e) then
			local d = (e.hrp.Position - hrp.Position).Magnitude
			if not best or d < bestDist then
				best = e
				bestDist = d
			end
		end
	end

	return best
end

function EntityLib.getEntitiesInBox(cframe, size)
	local half = size * 0.5
	local pos = cframe.Position
	local r, u, l = cframe.RightVector, cframe.UpVector, cframe.LookVector

	local results = {}

	for _, e in pairs(entities) do
		if e.hrp then
			local d = e.hrp.Position - pos
			if math.abs(d:Dot(r)) <= half.X
			and math.abs(d:Dot(u)) <= half.Y
			and math.abs(d:Dot(l)) <= half.Z then
				results[#results + 1] = e
			end
		end
	end

	return results
end

-- =====================
-- Perception
-- =====================

function EntityLib.hasLineOfSight(entity)
	local cam = Workspace.CurrentCamera
	if not cam or not entity.hrp then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = { localPlayer.Character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(
		cam.CFrame.Position,
		entity.hrp.Position - cam.CFrame.Position,
		params
	)

	return result and result.Instance:IsDescendantOf(entity.model)
end

function EntityLib.isVisible(entity, angle)
	if angle then
		local cam = Workspace.CurrentCamera
		if not cam then return false end
		local dir = (entity.hrp.Position - cam.CFrame.Position).Unit
		if dir:Dot(cam.CFrame.LookVector) < math.cos(math.rad(angle) * 0.5) then
			return false
		end
	end

	return EntityLib.hasLineOfSight(entity)
end

-- =====================
-- Events
-- =====================

function EntityLib.onAdded(fn)
	addedListeners[fn] = true
end

function EntityLib.onRemoved(fn)
	removedListeners[fn] = true
end

-- =====================
-- Tracking
-- =====================

local function trackCharacter(player, character)
	local entity = createEntity(character, player)
	if not entity then return end

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeEntity(entity)
		end
	end)
end

-- Players
for _, p in ipairs(Players:GetPlayers()) do
	if p.Character then
		trackCharacter(p, p.Character)
	end
	p.CharacterAdded:Connect(function(c)
		trackCharacter(p, c)
	end)
end

Players.PlayerAdded:Connect(function(p)
	p.CharacterAdded:Connect(function(c)
		trackCharacter(p, c)
	end)
end)

Players.PlayerRemoving:Connect(function(p)
	removeEntity(EntityLib.fromPlayer(p))
end)

-- NPCs
for _, m in ipairs(Workspace:GetChildren()) do
	if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
		createEntity(m, nil)
	end
end

Workspace.ChildAdded:Connect(function(m)
	if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
		createEntity(m, nil)
	end
end)

return EntityLib
