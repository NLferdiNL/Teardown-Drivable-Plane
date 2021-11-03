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
	Speed = { default = 10, current = nil, valueType = "float" },
	TurnSpeed = { default = 1, current = nil, valueType = "float" },
	CameraLerpSpeed = { default = 10, current = nil, valueType = "float" },
}

local inFlightCamera = false
local planeActive = false
local planePosition = Vec()
local planeRotation = Quat()
local planeDirection = Vec(0, 0, -1) -- local space
local planeTilt = 0

local selectedPlane = 2
local planeCount = 2

local lastFlightCameraPos = Vec()

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
		
		placeLocalBodyAtPos(toolBody,  planeShape, VecAdd(planePosition, offset), planeRotation)
		
		if inFlightCamera then
			cameraLogic(planeShape, dt)
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
	
end

function canUseTool()
	return GetString("game.player.tool") == toolName and GetPlayerVehicle() == 0
end

function startFlight()
	local playerCameraTransform = GetPlayerCameraTransform()
	
	planePosition = playerCameraTransform.pos
	planeRotation = playerCameraTransform.rot
	
	planeActive = true
	
	local cameraLocalPos = Vec(0, 0, 1)
	
	local cameraLocalRot = Quat()
	
	local localCameraTransform = Transform(cameraLocalPos, cameraLocalRot)
	
	local planeTransform = Transform(planePosition, planeRotation)
	
	local worldCameraTransform = TransformToParentTransform(planeTransform, localCameraTransform)
	
	lastFlightCameraPos = worldCameraTransform.pos
end

function handleFlight(dt)
	local localVelocity = VecScale(planeDirection, GetValue("Speed") * dt * 10)
	
	local planeTransform = Transform(planePosition, planeRotation)
	
	local globalVelocity = TransformToParentVec(planeTransform, localVelocity)
	
	planePosition = VecAdd(planePosition, globalVelocity)
	
	local goalRot = nil
	
	if inFlightCamera then
		local tiltRot = 0
		
		if InputDown(binds["Tilt_Counter_Clockwise"]) then
			tiltRot = tiltRot - 10
		end
		
		if  InputDown(binds["Tilt_Clockwise"]) then
			tiltRot = tiltRot + 10
		end
		
		local tiltVel = tiltRot * 10
		
		local mouseDeltaX = 0 --InputValue("mousedx") * 2
		local mouseDeltaY = InputValue("mousedy") * 2
		
		local goalPos = TransformToParentPoint(planeTransform, Vec(mouseDeltaX, -mouseDeltaY, -5))
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
	else
		local playerCameraTransform = GetPlayerCameraTransform()
		
		local origin = playerCameraTransform.pos
		
		local direction = TransformToParentVec(playerCameraTransform, Vec(0, 0, -1))
		
		local hit, hitPoint = raycast(origin, direction)
		
		if hit then
			goalRot = QuatLookAt(planePosition, hitPoint)
		end
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
	local hit, hitPoint = raycast(origin, direction, 0.1, 0.1)
	
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

function cameraLogic(planeShape, dt)
	-- lastFlightCameraPos

	local cameraLocalPos = Vec(0, 0, 1)
	
	local cameraLocalRot = Quat()
	
	local localCameraTransform = Transform(cameraLocalPos, cameraLocalRot)
	
	local planeTransform = Transform(planePosition, planeRotation)
	
	local worldCameraTransform = TransformToParentTransform(planeTransform, localCameraTransform)
	
	worldCameraTransform.pos = VecLerp(worldCameraTransform.pos, lastFlightCameraPos, GetValue("CameraLerpSpeed") * dt)
	
	SetCameraTransform(worldCameraTransform)
	
end

function resetShapeLocation(toolShape)
	local tempTransform = Transform(Vec(0, 0, 0), Quat())
	
	local localTransform = TransformToLocalTransform(toolTransform, tempTransform)
	
	SetShapeLocalTransform(toolShape, localTransform)
end




















