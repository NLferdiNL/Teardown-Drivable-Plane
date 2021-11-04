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

-- TODO: Rewrite menu system to auto generate textboxes.
-- TODO: Make aiming system around plane if no raycast hit.

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

local selectedPlane = 1
local planeCount = 2

--local lastFlightCameraPos = Vec()

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
	
	local isMenuOpenRightNow = isMenuOpen()
	
	if not canUseTool() then
		return
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
	
	--[[if planeActive and inFlightCamera then
	UiPush()
		UiAlign("center middle")
		UiTranslate(UiCenter(), UiMiddle())
		c_UiColor(Color4.Red)
		UiRect(200, 200)
	UiPop()
	end]]--
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
	
	lastFlightCameraPos = worldCameraTransform.pos
end

function thirdPersonControls()
	local goalRot = nil
	local tiltRot = 0
		
	if InputDown(binds["Tilt_Counter_Clockwise"]) then
		tiltRot = tiltRot - 10
	end
	
	if  InputDown(binds["Tilt_Clockwise"]) then
		tiltRot = tiltRot + 10
	end
	
	local tiltVel = tiltRot * 10
	
	local mouseDeltaX = InputValue("mousedx")
	local mouseDeltaY = InputValue("mousedy")
	
	local rotDist = -5
	
	--local currentDir = Vec(0, 0, rotDist)
	local turnDir = Vec(mouseDeltaX, -mouseDeltaY, rotDist)
	
	--local lerpDir = VecLerp(currentDir, turnDir, GetValue("TurnSpeed") * dt)
	
	local goalPos = TransformToParentPoint(planeTransform, turnDir)
	goalRot = QuatLookAt(planePosition, goalPos)
	--[[
	--mouseDeltaX = mouseDeltaX - (mouseDeltaX % 100)
	--mouseDeltaY = mouseDeltaY - (mouseDeltaY % 100)
	
	--if mouseDeltaX ~= 0 or mouseDeltaY ~= 0 or tiltVel ~= 0 then
		local xRotAxis = Vec(1, 0, 0)
		local yRotAxis = Vec(0, 1, 0)
		local zRotAxis = Vec(0, 0, 1)
	
		local xRot = QuatAxisAngle(xRotAxis, -mouseDeltaY)
		local yRot = QuatAxisAngle(yRotAxis, -mouseDeltaX)
		local zRot = QuatAxisAngle(zRotAxis, -tiltVel)
		
		DebugWatch("dx", mouseDeltaX)
		DebugWatch("dy", mouseDeltaY)
		DebugWatch("dz", tiltVel)
		
		goalRot = QuatRotateQuat(QuatRotateQuat(xRot, yRot), zRot)
		
		goalRot = QuatRotateQuat(goalRot, planeRotation)]]--
	--end
	
	return goalRot
end

function rcControls()
	local goalRot = nil

	local playerCameraTransform = GetPlayerCameraTransform()
		
	local origin = playerCameraTransform.pos
	
	local direction = TransformToParentVec(playerCameraTransform, Vec(0, 0, -1))
	
	local hit, hitPoint = raycast(origin, direction)
	
	if hit then
		goalRot = QuatLookAt(planePosition, hitPoint)
	else
		--local dirToPlayer = VecDir(planePosition, origin)
		--local freeFlightDirection = VecNormalize(VecAdd(direction, dirToPlayer))
	
		local goalPos = VecAdd(planePosition, direction)-- VecAdd(planePosition, freeFlightDirection)
		
		goalRot = QuatLookAt(planePosition, goalPos)
	end
	
	return goalRot
end

function handleFlight(dt)
	local localVelocity = VecScale(planeDirection, GetValue("Speed") * dt)
	
	local planePosition = planeTransform.pos
	
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
end

function handlePlaneCollisions()
	local planeTransform = Transform(planePosition, planeRotation)
	
	--local offset = Vec(0.25, 0.25, 0.25)
	
	local origin = planePosition --VecAdd(planePosition, offset)
	
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
	
	local planeTransform = Transform(planePosition, planeRotation)
	
	local worldCameraTransform = TransformToParentTransform(planeTransform, localCameraTransform)
	
	--local curspeed = GetValue("CameraLerpSpeed") * dt
	
	--worldCameraTransform.pos = VecLerp(lastFlightCameraPos, worldCameraTransform.pos, curspeed)
	
	SetCameraTransform(worldCameraTransform)
	
end

function resetShapeLocation(toolShape)
	local tempTransform = Transform(Vec(0, 0, 0), Quat())
	
	local localTransform = TransformToLocalTransform(toolTransform, tempTransform)
	
	SetShapeLocalTransform(toolShape, localTransform)
end




















