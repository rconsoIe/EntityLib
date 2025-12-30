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

local function createEntity(model, player)
	if byModel[model] then
		return byModel[model]
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hrp = model:FindFirstChild("HumanoidRootPart")

	local entity = {
		id = newId(),
		model = model,
		player = player,
		humanoid = humanoid,
		hrp = hrp,
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

local function getViewOrigin()
	local cam = Workspace.CurrentCamera
	if cam then
		return cam.CFrame.Position, cam.CFrame.LookVector
	end

	local hrp = getLocalHRP()
	if hrp then
		return hrp.Position, hrp.CFrame.LookVector
	end
end

local function raycast(origin, targetPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true

	return Workspace:Raycast(origin, targetPos - origin, params)
end

function EntityLib.fromModel(model)
	return byModel[model]
end

function EntityLib.fromPlayer(player)
	local char = player.Character
	if not char then return end
	return byModel[char]
end

function EntityLib.getAll()
	local list = {}
	for _, entity in pairs(entities) do
		list[#list + 1] = entity
	end
	return list
end

function EntityLib.getById(id)
	return entities[id]
end

function EntityLib.isAlive(entity)
	return entity.humanoid and entity.humanoid.Health > 0
end

function EntityLib.getPosition(entity)
	return entity.hrp and entity.hrp.Position
end

function EntityLib.getNearby(radius, angle)
	local char = localPlayer.Character
	if not char then return {} end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return {} end

	local origin = hrp.Position
	local radiusSq = radius * radius

	local useAngle = angle ~= nil
	local cosLimit

	if useAngle then
		cosLimit = math.cos(math.rad(angle) * 0.5)
	end

	local lookVector
	local cam = Workspace.CurrentCamera
	if cam then
		lookVector = cam.CFrame.LookVector
	else
		lookVector = hrp.CFrame.LookVector
	end

	local results = {}

	for _, entity in pairs(entities) do
		if entity.player ~= localPlayer and entity.hrp then
			local delta = entity.hrp.Position - origin
			local distSq = delta:Dot(delta)

			if distSq <= radiusSq then
				if useAngle then
					local dir = delta.Unit
					if dir:Dot(lookVector) >= cosLimit then
						results[#results + 1] = entity
					end
				else
					results[#results + 1] = entity
				end
			end
		end
	end

	return results
end

function EntityLib.hasLineOfSight(entity)
	if not entity or not entity.hrp then return false end

	local origin = getViewOrigin()
	if not origin then return false end

	local hit = raycast(
		origin,
		entity.hrp.Position,
		{ localPlayer.Character }
	)

	return hit and hit.Instance:IsDescendantOf(entity.model)
end

function EntityLib.isVisible(entity, angle)
	if not entity or not entity.hrp then return false end

	local origin, look = getViewOrigin()
	if not origin then return false end

	local delta = entity.hrp.Position - origin

	if angle then
		local cosLimit = math.cos(math.rad(angle) * 0.5)
		if delta.Unit:Dot(look) < cosLimit then
			return false
		end
	end

	return EntityLib.hasLineOfSight(entity)
end

function EntityLib.getVisible(radius, angle)
	local hrp = getLocalHRP()
	if not hrp then return {} end

	local origin = hrp.Position
	local radiusSq = radius * radius

	local visible = {}

	for _, entity in pairs(entities) do
		if entity.hrp and entity.player ~= localPlayer then
			local d = entity.hrp.Position - origin
			if d:Dot(d) <= radiusSq and EntityLib.isVisible(entity, angle) then
				visible[#visible + 1] = entity
			end
		end
	end

	return visible
end

function EntityLib.getNearestVisibleEnemy(radius, angle)
	local hrp = getLocalHRP()
	if not hrp then return end

	local origin = hrp.Position
	local radiusSq = radius * radius

	local best
	local bestDist = math.huge

	for _, entity in pairs(entities) do
		if entity.hrp and isEnemy(entity) then
			local d = entity.hrp.Position - origin
			local dsq = d:Dot(d)

			if dsq <= radiusSq and dsq < bestDist then
				if EntityLib.isVisible(entity, angle) then
					best = entity
					bestDist = dsq
				end
			end
		end
	end

	return best
end

function EntityLib.getEntitiesInBox(cframe, size)
	local half = size * 0.5
	local right = cframe.RightVector
	local up = cframe.UpVector
	local look = cframe.LookVector
	local pos = cframe.Position

	local results = {}

	for _, entity in pairs(entities) do
		if entity.hrp then
			local delta = entity.hrp.Position - pos

			local x = math.abs(delta:Dot(right))
			local y = math.abs(delta:Dot(up))
			local z = math.abs(delta:Dot(look))

			if x <= half.X and y <= half.Y and z <= half.Z then
				results[#results + 1] = entity
			end
		end
	end

	return results
end

function EntityLib.onAdded(fn)
	addedListeners[fn] = true
end

function EntityLib.onRemoved(fn)
	removedListeners[fn] = true
end

local function trackCharacter(player, character)
	local entity = createEntity(character, player)

	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeEntity(entity)
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		trackCharacter(player, player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		trackCharacter(player, char)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		trackCharacter(player, char)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	local entity = EntityLib.fromPlayer(player)
	if entity then
		removeEntity(entity)
	end
end)

return EntityLib
