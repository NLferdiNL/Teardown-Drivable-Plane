#include "datascripts/inputList.lua"
#include "datascripts/keybinds.lua"
#include "scripts/ui.lua"
#include "scripts/utils.lua"
#include "scripts/textbox.lua"

local menuOpened = false
local menuOpenLastFrame = false

local rebinding = nil

local erasingBinds = 0
local erasingValues = 0

local colums = 1

local menuMargin = 10

local menuWidth = 0
local menuHeight = 0

local textBoxes = {}

function menu_init()
	setupTextBoxes()
	
	menuWidth = 384
	menuHeight = ((#bindOrder + #menuVarOrder) / colums + 4) * 50 + menuMargin
end

function menu_tick(dt)
	if PauseMenuButton(toolReadableName .. " Settings") then
		setMenuOpen(true)
	end
	
	if GetString("game.player.tool") == toolName and GetPlayerVehicle() == 0 and InputPressed(binds["Open_Menu"]) then
		setMenuOpen(not menuOpened)
	end
	
	if menuOpened and not menuOpenLastFrame then
		menuUpdateActions()
		menuOpenActions()
	end
	
	if not menuOpened and menuOpenLastFrame then
		menuCloseActions()
	end
	
	menuOpenLastFrame = menuOpened
	
	if rebinding ~= nil then
		local lastKeyPressed = getKeyPressed()
		
		if lastKeyPressed ~= nil then
			binds[rebinding] = lastKeyPressed
			rebinding = nil
		end
	end
	
	textboxClass_tick()
	
	if erasingBinds > 0 then
		erasingBinds = erasingBinds - dt
	end
end

function drawTitle()
	UiPush()
		UiFont("bold.ttf", 45)
		
		local titleText = toolReadableName .. " Settings"
		
		local titleBoxWidth, titleBoxHeight = UiGetTextSize(titleText)
		
		UiTranslate(0, -40 - titleBoxHeight / 2)
		
		UiPush()
			UiColorFilter(0, 0, 0, 0.25)
			UiImageBox("MOD/sprites/square.png", titleBoxWidth + 20, titleBoxHeight + 20, 10, 10)
		UiPop()
		
		UiText(titleText)
	UiPop()
end

function bottomMenuButtons()
	UiPush()
		UiFont("regular.ttf", 26)
	
		UiButtonImageBox("MOD/sprites/square.png", 6, 6, 0, 0, 0, 0.5)
		
		UiAlign("center bottom")
		
		local buttonWidth = 250
		
		UiPush()
			UiTranslate(0, -100)
			if erasingValues > 0 then
				UiPush()
				c_UiColor(Color4.Red)
				if UiTextButton("Are you sure?" , buttonWidth, 40) then
					resetValues()
					erasingValues = 0
				end
				UiPop()
			else
				if UiTextButton("Reset values to defaults" , buttonWidth, 40) then
					erasingValues = 5
				end
			end
		UiPop()
		
		
		UiPush()
			--UiAlign("right bottom")
			--UiTranslate(230, 0)
			UiTranslate(0, -50)
			if erasingBinds > 0 then
				UiPush()
				c_UiColor(Color4.Red)
				if UiTextButton("Are you sure?" , buttonWidth, 40) then
					resetKeybinds()
					erasingBinds = 0
				end
				UiPop()
			else
				if UiTextButton("Reset binds to defaults" , buttonWidth, 40) then
					erasingBinds = 5
				end
			end
		UiPop()
		
		
		UiPush()
			--UiAlign("left bottom")
			--UiTranslate(-230, 0)
			if UiTextButton("Close" , buttonWidth, 40) then
				menuCloseActions()
			end
		UiPop()
	UiPop()
end

function disableButtonStyle()
	UiButtonImageBox("MOD/sprites/square.png", 6, 6, 0, 0, 0, 0.5)
	UiButtonPressColor(1, 1, 1)
	UiButtonHoverColor(1, 1, 1)
	UiButtonPressDist(0)
end

function greenAttentionButtonStyle()
	local greenStrength = math.sin(GetTime() * 5) - 0.5
	local otherStrength = 0.5 - greenStrength
	
	if greenStrength < otherStrength then
		greenStrength = otherStrength
	end
	
	UiButtonImageBox("MOD/sprites/square.png", 6, 6, otherStrength, greenStrength, otherStrength, 0.5)
end

function leftSideMenu()
	UiPush()
		UiTranslate(-menuWidth / 5, 0)
		
	UiPop()
end

function rightSideMenu()
	UiPush()
		UiPush()
			UiTranslate(menuWidth / 5, 0)
			
			UiFont("regular.ttf", 20)
		UiPop()
	UiPop()
end

function menu_draw(dt)
	if not isMenuOpen() then
		return
	end
	
	UiMakeInteractive()
	
	UiPush()
		UiBlur(0.75)
		
		UiAlign("center middle")
		UiTranslate(UiWidth() * 0.5, UiHeight() * 0.5)
		
		UiPush()
			UiColorFilter(0, 0, 0, 0.25)
			UiImageBox("MOD/sprites/square.png", menuWidth, menuHeight, 10, 10)
		UiPop()
		
		UiWordWrap(menuWidth)
		
		UiTranslate(0, -menuHeight / 2)
		
		drawTitle()
		
		--UiTranslate(menuWidth / 10, 0)
		
		UiFont("regular.ttf", 26)
		UiAlign("center middle")
		
		UiTranslate(0, menuMargin + 20)
		
		UiPush()
			for i = 1, #bindOrder do
				local id = bindOrder[i]
				local key = binds[id]
				drawRebindable(id, key)
				UiTranslate(0, 50)
			end
		UiPop()
		
		UiTranslate(0, 50 * (#bindOrder))
		--textboxClass_render(perUnitBox)
		
		UiPush()
		for i = 1, #menuVarOrder do
			local varName = menuVarOrder[i]
			local varData = savedVars[varName]
			local boxId = varData["boxId"]
			
			if boxId ~= nil then
				local currTextBox = textBoxes[boxId]
			
				textboxClass_render(currTextBox)
			else
				drawToggle(varData["name"] .. ":", varData["current"], function(i) varData["current"] = i end, 300)
			end
			
			UiTranslate(0, 50)
		end
		UiPop()
		
		UiTranslate(0, 50 * (#menuVarOrder))
		
		--leftSideMenu()
		
		--rightSideMenu()
	UiPop()
	
	UiPush()
		UiTranslate(UiWidth() * 0.5, UiHeight() * 0.5)
		--UiTranslate(0, menuHeight / 2)
		UiTranslate(0, menuHeight / 2 - menuMargin)
		
		bottomMenuButtons()
	UiPop()

	textboxClass_drawDescriptions()
end

function setupTextBoxes()
	--[[local textBox01, newBox01 = textboxClass_getTextBox(1)
	
	if newBox01 then
		textBox01.name = "Per Unit"
		textBox01.value = GetValue("PerUnit") .. ""
		textBox01.numbersOnly = true
		textBox01.limitsActive = true
		textBox01.numberMin = 0.1
		textBox01.numberMax = 50
		textBox01.description = "Min: 0.1\nDefault: 5\nMax: 50"
		textBox01.onInputFinished = function(v) SetValue("PerUnit", tonumber(v)) end
		
		perUnitBox = textBox01
	end]]--
	for i = 1, #menuVarOrder do
		local varName = menuVarOrder[i]
		local varData = savedVars[varName]
		local useTextbox = varData["valueType"] == "float" or varData["valueType"] == "int" or varData["valueType"] == "string"
		
		if useTextbox then
			local newIndex = #textBoxes + 1
			local newTextBox, isNewBox = textboxClass_getTextBox(newIndex)
			
			local isNumber = varData["valueType"] == "float" or varData["valueType"] == "int"
			local limitedRange = varData["minVal"] ~= nil and varData["maxVal"] ~= nil and isNumber
			
			local description = varData["description"]
			
			if description == nil then
				description = ""
			end
			
			if limitedRange then
				description = description .. string.format("\nMin: %s\nDefault: %s\nMax: %s", varData.minVal, varData.default, varData.maxVal)
			end
			
			if isNewBox then
				newTextBox.disabled = not varData.configurable
				newTextBox.name = varData.name
				newTextBox.value = varData.current .. ""
				newTextBox.numbersOnly = isNumber
				newTextBox.limitsActive = limitedRange
				newTextBox.numberMin = varData["minVal"]
				newTextBox.numberMax = varData["maxVal"]
				newTextBox.description = description
				newTextBox.onInputFinished = function(v) SetValue(varName, tonumber(v)) end
				
				textBoxes[newIndex] = newTextBox
			end
			
			varData["boxId"] = newIndex
		end
	end
end

function drawRebindable(id, key)
	UiPush()
		UiButtonImageBox("MOD/sprites/square.png", 6, 6, 0, 0, 0, 0.5)
	
		--UiTranslate(menuWidth / 1.5, 0)
	
		UiAlign("right middle")
		UiText(bindNames[id] .. "")
		
		--UiTranslate(menuWidth * 0.1, 0)
		
		UiAlign("left middle")
		
		if rebinding == id then
			c_UiColor(Color4.Green)
		else
			c_UiColor(Color4.Yellow)
		end
		
		if UiTextButton(key:upper(), 40, 40) then
			rebinding = id
		end
	UiPop()
end

function menuOpenActions()
	
end

function menuUpdateActions()
	--[[if resolutionBox ~= nil then
		resolutionBox.value = resolution .. ""
	end]]--
end

function menuCloseActions()
	menuOpened = false
	rebinding = nil
	erasingBinds = 0
	erasingValues = 0
	saveData(savedVars)
end

function resetValues()
	menuUpdateActions()
	
	ResetValuesToDefault()
	
	perUnitBox.value = GetValue("PerUnit") .. ""
	holeSizeBox.value = GetValue("HoleSize") .. ""
end

function isMenuOpen()
	return menuOpened
end

function setMenuOpen(val)
	menuOpened = val
end