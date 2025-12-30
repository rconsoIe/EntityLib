local Players = game:GetService("Players")

local EntityLib = {}

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
