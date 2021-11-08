#include "scripts/utils.lua"
#include "scripts/savedata.lua"
#include "scripts/menu.lua"
#include "scripts/varhandlers.lua"
#include "datascripts/keybinds.lua"
#include "datascripts/inputList.lua"
#include "datascripts/color4.lua"

toolName = "drivableplane"
toolReadableName = "Drivable Plane"

local menu_disabled = false


savedVars = {
	Speed = { name = "Speed",
			  boxDescription = "Plane speed.",
			  default = 10,
			  current = nil,
			  valueType = "float",
			  configurable = true,
			  minVal = 0.1,
			  maxVal = 50,
			},
			
	TurnSpeed = { name = "Turn Speed",
				  boxDescription = "Plane turn speed.",
				  default = 5,
				  current = nil,
				  valueType = "float",
				  configurable = true,
				  minVal = 0.1,
				  maxVal = 50
				},
	
	CameraLerpSpeed = { name = "Camera Lerp Speed",
						boxDescription = "Camera move speed.",
						default = 100,
						current = nil,
						valueType = "float",
						configurable = false,
						minVal = 0.1,
						maxVal = 25,
					  },
}

menuVarOrder = { "Speed", "TurnSpeed" }

local inFlightCamera = false
local firstCameraTick = false

local planeActive = false
local planeTransform = Transform(planePosition, planeRotation)

local planeDirection = Vec(0, 0, -1) -- local space
--local planeTilt = 0

local cameraTransform = Transform()

local selectedPlane = 1
local planeCount = 2

local cameraLocalPos = Vec(0, 0.5, 5)
local cameraLocalLookPos = Vec(0, 0.25, 0)
local cameraLocalRot = QuatLookAt(cameraLocalPos, cameraLocalLookPos)

local planeTest = LoadSprite("MOD/sprites/square.png")
--local planeSprites = { "MOD/sprites/square.png", "MOD/sprites/square.png"}
local localPlaneOffsets = { Vec(-0.45, 0, 0), Vec(-0.65, 0, 0) }

local targetSprite = LoadSprite("MOD/sprites/target.png")

local damageTick = 0
local maxDamageTick = 0.1
local forceWaveRange = 2
local forceRayLength = 0.25
local forceRayWidth = 0.3
local collisionForce = 20

local setGoalPos = Vec()
local setGoalPosActive = false

function init()
	saveFileInit(savedVars)
	menu_init()
	
	RegisterTool(toolName, toolReadableName, "MOD/vox/plane.vox")
	SetBool("game.tool." .. toolName .. ".enabled", true)
	
	--[[for i = 1, #planeSprites do
		planeSprites[i] = LoadSprite(planeSprites[i])
	end]]--
end

function tick(dt)
	if not menu_disabled then
		menu_tick(dt)
	end
	
	local isMenuOpenRightNow = isMenuOpen()
	
	if not canUseTool() and not planeActive then
		return
	end
	
	planeBodiesLogic(dt)
	
	if planeActive then
		SetString("game.player.tool", toolName)
		
		if InputPressed(binds["Fly_To_Target"]) and not inFlightCamera and not isMenuOpen() then
			setSetGoalPos()
		end
		
		if inFlightCamera then
			DebugWatch("dist", VecDist(GetPlayerCameraTransform().pos, planeTransform.pos))
		
			if VecDist(GetPlayerCameraTransform().pos, planeTransform.pos) > 10 and firstCameraTicks <= 0 then
				inFlightCamera = false
			end
			
			if firstCameraTicks then
				firstCameraTicks = firstCameraTicks - 1
			end
			cameraLogic(dt)
			--renderPlaneSprite()
		end
		
		if InputPressed(binds["Toggle_Camera"]) then
			inFlightCamera = not inFlightCamera
			
			if inFlightCamera then
				firstCameraTicks = 2
			end
		end
		
		if InputPressed(binds["Disengage"]) then
			planeActive = false
			setGoalPosActive = false
		end
		
		if setGoalPosActive then
			renderSetGoalSprite()
		end
		
		handleFlight(dt)
		
		if damageTick <= 0 then
			handlePlaneCollisions(planeTransform.pos)
		else
			damageTick = damageTick - dt
		end
	end
	
	if isMenuOpenRightNow then
		return
	end
	
	if InputPressed(binds["Shoot"]) and not planeActive then
		startFlight()
	end
end

function draw(dt)
	menu_draw(dt)
end

function planeBodiesLogic(dt)
	SetToolTransform(Transform(), 0)
	
	local toolBody = GetToolBody()
	local toolTransform = GetBodyTransform(toolBodyx)
	local toolShapes = GetBodyShapes(toolBody)
	
	local planeShape = toolShapes[selectedPlane]
	
	if planeActive then
		local scroll = InputValue(binds["Plane_Select_Move"])
		
		if scroll > 0 then
			selectedPlane = selectedPlane - 1
			
			if selectedPlane < 1 then
				selectedPlane = planeCount
			end
		elseif scroll < 0 then
			selectedPlane = selectedPlane + 1
			
			if selectedPlane > planeCount then
				selectedPlane = 1
			end
		end
		
		local planePosition = planeTransform.pos
		local planeRotation = planeTransform.rot
		
		
		--[[ParticleReset()
		ParticleRadius(0.1)
		ParticleColor(1, 0, 0, 1)
		SpawnParticle(planePosition, Vec(), 0.5)]]--
		
		placeLocalBodyAtPos(toolBody, planeShape, planePosition, planeRotation, localPlaneOffsets[selectedPlane])
	end
	
	for i = 1, planeCount do
		if i ~= selectedPlane or (i == selectedPlane and not planeActive) then
			placeLocalBodyAtPos(toolBody, toolShapes[i], Vec(0, -500, 0), Quat(), Vec())
		end
	end
end

function renderPlaneSprite()
	local cameraTransform = GetCameraTransform()
	local planePosition = planeTransform.pos

	local lookRot = QuatLookAt(planePosition, cameraTransform.pos)
	
	local spriteTransform = Transform(planePosition, lookRot)
	
	DrawSprite(planeTest, spriteTransform, 0.25, 0.25, 0.5, 0.5, 0.5, 1, true, true)
	--DrawSprite(planeSprites[selectedPlane], spriteTransform, 0.25, 0.25, 0.5, 0.5, 0.5, 1, true, true)
end

function renderSetGoalSprite()
	local cameraTransform = GetCameraTransform()
	
	local lookAtCameraRot = QuatLookAt(setGoalPos, cameraTransform.pos)

	local goalTransform = Transform(setGoalPos, lookAtCameraRot)
	DrawSprite(targetSprite, goalTransform, 0.5, 0.5, 1, 0, 0, 1, false, false)
end

function canUseTool()
	return GetString("game.player.tool") == toolName and GetPlayerVehicle() == 0
end

function setSetGoalPos()
	local cameraTransform = GetPlayerCameraTransform()
	local origin = cameraTransform.pos
	local direction = TransformToParentVec(cameraTransform, Vec(0, 0, -1))
	
	local hit, hitPoint = raycast(origin, direction)
	
	if hit then
		setGoalPos = hitPoint
		setGoalPosActive = true
	end
end

function startFlight()
	local playerCameraTransform = GetPlayerCameraTransform()
	
	local planePosition = playerCameraTransform.pos
	local planeRotation = playerCameraTransform.rot
	
	planeTransform = Transform(planePosition, planeRotation)
	
	planeActive = true
	
	local localCameraTransform = Transform(cameraLocalPos, cameraLocalRot)
	
	local worldCameraTransform = TransformToParentTransform(planeTransform, localCameraTransform)
	
	cameraTransform.pos = worldCameraTransform.pos
	cameraTransform.rot = worldCameraTransform.rot
end

function thirdPersonControls()
	local planePosition = planeTransform.pos
	local planeRotation = planeTransform.rot
	
	local goalRot = nil
	--[[local tiltRot = 0
		
	if InputDown(binds["Tilt_Counter_Clockwise"]) then
		tiltRot = tiltRot - 10
	end
	
	if  InputDown(binds["Tilt_Clockwise"]) then
		tiltRot = tiltRot + 10
	end
	
	local tiltVel = tiltRot * 10]]--
	
	local mouseDeltaX = InputValue("mousedx") / 2 
	local mouseDeltaY = InputValue("mousedy") / 2
	
	local rotDist = -5
	
	local turnDir = Vec(mouseDeltaX, -mouseDeltaY, rotDist)
	
	local goalPos = TransformToParentPoint(planeTransform, turnDir)
	
	goalRot = QuatLookAt(planePosition, goalPos)
	
	return goalRot
end

function rcControls()
	local planePosition = planeTransform.pos
	local planeRotation = planeTransform.rot
	
	local goalRot = nil

	local playerCameraTransform = GetPlayerCameraTransform()
		
	local origin = playerCameraTransform.pos
	
	local direction = TransformToParentVec(playerCameraTransform, Vec(0, 0, -1))
	
	local hit, hitPoint = raycast(origin, direction)
	
	if hit then
		goalRot = QuatLookAt(planePosition, hitPoint)
	else
		local goalPos = VecAdd(planePosition, direction)
		
		goalRot = QuatLookAt(planePosition, goalPos)
	end
	
	return goalRot
end

function handleFlight(dt)
	local localVelocity = VecScale(planeDirection, GetValue("Speed") * dt)
	
	local planePosition = planeTransform.pos
	local planeRotation = planeTransform.rot
	
	local worldVelocity = TransformToParentVec(planeTransform, localVelocity)
	
	planePosition = VecAdd(planePosition, worldVelocity)
	
	local goalRot = nil
	
	if not setGoalPosActive then
		if inFlightCamera then
			goalRot = thirdPersonControls()
		else
			goalRot = rcControls()
		end
	else
		goalRot = QuatLookAt(planePosition, setGoalPos)
		
		if VecDist(planeTransform.pos, setGoalPos) < 1 then
			setGoalPosActive = false
		end
	end
	
	if goalRot ~= nil then
		planeRotation = QuatSlerp(planeRotation, goalRot, GetValue("TurnSpeed") * dt)
	end
	
	planeTransform.pos = planePosition
	planeTransform.rot = planeRotation
end

function handlePlaneCollisions(fromPos)
	local origin = fromPos
	
	local direction = TransformToParentVec(planeTransform, Vec(0, 0, -1))
	
	--function raycast(origin, direction, maxDistance, radius, rejectTransparant)
	-- local hit, hitPoint, distance, normal, shape = raycast(origin, direction, 0.1, 0.1)
	local hit, hitPoint = raycast(origin, direction, 0.1, 0.25)
	
	if hit then
		--MakeHole(hitPoint, 0.75, 0.75, 0.75)
		MakeHole(hitPoint, 4, 4, 4)
		
		damageTick = maxDamageTick
		
		--[[for x = -forceWaveRange, forceWaveRange do
			for y = -forceWaveRange, forceWaveRange do
				local iOrigin = VecAdd(planeTransform.pos, Vec(x, y, 0))
				local iDir = TransformToParentVec(planeTransform, Vec(0, 0, -1))
				
				QueryRequire("dynamic")
				local iHit, iHitPoint, distance, normal, shape = raycast(iOrigin, iDir, forceRayLength, forceRayWidth)
				
				if iHit then
					local iBody = GetShapeBody(shape)
					
					SetBodyVelocity(iBody, VecScale(VecDir(iOrigin, iHitPoint), collisionForce))
					--ApplyBodyImpulse(iBody, iHitPoint, VecScale(VecDir(iOrigin, iHitPoint), 500))
					
					DebugPrint("daa")
				end
			end
		end]]--
		
		QueryRequire("dynamic")
		
		local inFrontPos = VecAdd(origin, VecScale(direction, forceWaveRange / 2))
		
		local minPos = VecAdd(inFrontPos, Vec(-forceWaveRange, -forceWaveRange, -forceWaveRange))
		local maxPos = VecAdd(inFrontPos, Vec(forceWaveRange, forceWaveRange, forceWaveRange))
		
		local bodies = QueryAabbBodies(minPos, maxPos)
		
		for i = 1, #bodies do
			local hitBody = bodies[i]
			--local bodyTransform = GetBodyTransform(hitBody)
			--local bodyCOM = GetBodyCenterOfMass(hitBody)
			
			
			
			SetBodyVelocity(hitBody, VecScale(direction, collisionForce))
		end
	end
end

function placeLocalBodyAtPos(toolBody, toolShape, shapeWorldPosition, shapeWorldRot, localOffset)
	local toolTransform = GetBodyTransform(toolBody)
	
	local tempTransform = Transform(shapeWorldPosition, shapeWorldRot)
	
	local localTransform = TransformToLocalTransform(toolTransform, tempTransform)
	
	localTransform.pos = VecAdd(localTransform.pos, localOffset)
	
	local backToWorld = TransformToParentTransform(toolTransform, localTransform)
	
	SetShapeLocalTransform(toolShape, localTransform)
end

function cameraLogic(dt)
	-- lastFlightCameraPos
	
	local localCameraTransform = Transform(cameraLocalPos, cameraLocalRot)
	
	local worldCameraTransform = TransformToParentTransform(planeTransform, localCameraTransform)
	
	cameraTransform.pos = VecLerp(cameraTransform.pos, worldCameraTransform.pos, GetValue("CameraLerpSpeed") * dt)
	cameraTransform.rot = worldCameraTransform.rot--QuatSlerp(cameraTransform.rot, worldCameraTransform.rot, GetValue("CameraLerpSpeed") * dt)
	
	--SetCameraTransform(cameraTransform)
	SetPlayerTransform(cameraTransform)
end

function resetShapeLocation(toolShape)
	local tempTransform = Transform(Vec(0, 0, 0), Quat())
	
	local localTransform = TransformToLocalTransform(toolTransform, tempTransform)
	
	SetShapeLocalTransform(toolShape, localTransform)
end




















