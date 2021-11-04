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

-- TODO: Fix third person camera: Plane moves right during turn.

savedVars = {
	Speed = { name = "Speed",
			  boxDescription = "Plane speed.",
			  default = 10,
			  current = nil,
			  valueType = "float",
			  visible = true,
			  configurable = true,
			  minVal = 0.1,
			  maxVal = 50,
			},
			
	TurnSpeed = { name = "Turn Speed",
				  boxDescription = "Plane turn speed.",
				  default = 5,
				  current = nil,
				  valueType = "float",
				  visible = true,
				  configurable = true,
				  minVal = 0.1,
				  maxVal = 50
				},
	
	CameraLerpSpeed = { name = "Camera Lerp Speed",
						boxDescription = "Camera move speed.",
						default = 100,
						current = nil,
						valueType = "float",
						visible = true,
						configurable = true,
						minVal = 0.1,
						maxVal = 50,
					  },
}

menuVarOrder = { "Speed", "TurnSpeed", "CameraLerpSpeed" }

local inFlightCamera = false
local planeActive = false
local planeTransform = Transform(planePosition, planeRotation)

local planeDirection = Vec(0, 0, -1) -- local space
local planeTilt = 0

local cameraTransform = Transform()

local selectedPlane = 1
local planeCount = 2

local cameraLocalPos = Vec(0, 0.5, 5)
local cameraLocalLookPos = Vec(0, 0.25, 0)
local cameraLocalRot = QuatLookAt(cameraLocalPos, cameraLocalLookPos)

local planeTest = LoadSprite("MOD/sprites/square.png")

function init()
	saveFileInit(savedVars)
	menu_init()
	
	RegisterTool(toolName, toolReadableName, "MOD/vox/plane.vox")
	SetBool("game.tool." .. toolName .. ".enabled", true)
end

function tick(dt)
	if not menu_disabled then
		menu_tick(dt)
	end
	
	local isMenuOpenRightNow = isMenuOpen()
	
	if not canUseTool() then
		return
	end
	
	planeBodiesLogic(dt)
	
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
	local toolShapes = GetBodyShapes(toolBody)
	
	local planeShape = toolShapes[selectedPlane]
	
	if planeActive then
		SetString("game.player.tool", toolName)
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
		
		local offset = Vec(-0.25, -0.125, -0.125)
		local planePosition = planeTransform.pos
		local planeRotation = planeTransform.rot
		
		placeLocalBodyAtPos(toolBody, planeShape, VecAdd(planePosition, offset), planeRotation)
		
		if inFlightCamera then
			cameraLogic(dt)
			renderPlaneSprite()
		end
		
		handleFlight(dt)
		handlePlaneCollisions()
		
		if InputPressed(binds["Toggle_Camera"]) then
			inFlightCamera = not inFlightCamera
		end
		
		if InputPressed(binds["Disengage"]) then
			planeActive = false
		end
	end
	
	for i = 1, planeCount do
		if i ~= selectedPlane or (i == selectedPlane and not planeActive) then
			placeLocalBodyAtPos(toolBody, toolShapes[i], Vec(0, -500, 0), Quat())
		end
	end
end

function renderPlaneSprite()
	local cameraTransform = GetCameraTransform()
	local planePosition = planeTransform.pos

	local lookRot = QuatLookAt(planePosition, cameraTransform.pos)
	
	local spriteTransform = Transform(planePosition, lookRot)
	
	DrawSprite(planeTest, spriteTransform, 0.25, 0.25, 1, 1, 1, 1, true, true)
end

function canUseTool()
	return GetString("game.player.tool") == toolName and GetPlayerVehicle() == 0
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
	
	local mouseDeltaX = InputValue("mousedx")
	local mouseDeltaY = InputValue("mousedy")
	
	local rotDist = -5
	
	local turnDir = Vec(mouseDeltaX, -mouseDeltaY, rotDist)
	
	local goalPos = TransformToParentPoint(planeTransform, turnDir)
	
	goalRot = QuatLookAt(planePosition, goalPos)
	
	--[[ParticleReset()
	ParticleRadius(0.1)
	ParticleColor(1, 0, 0, 1)
	SpawnParticle(goalPos, Vec(), 0.25)]]--
	
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
	
	if inFlightCamera then
		goalRot = thirdPersonControls()
	else
		goalRot = rcControls()
	end
	
	if goalRot ~= nil then
		planeRotation = QuatSlerp(planeRotation, goalRot, GetValue("TurnSpeed") * dt)
	end
	
	planeTransform.pos = planePosition
	planeTransform.rot = planeRotation
end

function handlePlaneCollisions()
	local origin = planeTransform.pos 
	
	local direction = TransformToParentVec(planeTransform, Vec(0, 0, -1))
	
	--function raycast(origin, direction, maxDistance, radius, rejectTransparant)
	-- local hit, hitPoint, distance, normal, shape = raycast(origin, direction, 0.1, 0.1)
	local hit, hitPoint = raycast(origin, direction, 0.1, 0.25)
	
	if hit then
		MakeHole(hitPoint, 0.75, 0.75, 0.75)
	end
end

function placeLocalBodyAtPos(toolBody, toolShape, shapeWorldPosition, shapeWorldRot)
	local toolTransform = GetBodyTransform(toolBody)
	
	local tempTransform = Transform(shapeWorldPosition, shapeWorldRot)
	
	local localTransform = TransformToLocalTransform(toolTransform, tempTransform)
	
	SetShapeLocalTransform(toolShape, localTransform)
end

function cameraLogic(dt)
	-- lastFlightCameraPos
	
	local localCameraTransform = Transform(cameraLocalPos, cameraLocalRot)
	
	local worldCameraTransform = TransformToParentTransform(planeTransform, localCameraTransform)
	
	cameraTransform.pos = VecLerp(cameraTransform.pos, worldCameraTransform.pos, GetValue("CameraLerpSpeed") * dt)
	cameraTransform.rot = QuatSlerp(cameraTransform.rot, worldCameraTransform.rot, GetValue("CameraLerpSpeed") * dt)
	
	SetCameraTransform(cameraTransform)
	
end

function resetShapeLocation(toolShape)
	local tempTransform = Transform(Vec(0, 0, 0), Quat())
	
	local localTransform = TransformToLocalTransform(toolTransform, tempTransform)
	
	SetShapeLocalTransform(toolShape, localTransform)
end




















