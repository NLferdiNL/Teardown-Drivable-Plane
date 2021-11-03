#include "scripts/utils.lua"

binds = {
	Shoot = "usetool",
	Disengage = "rmb",
	Toggle_Camera = "r",
	Tilt_Clockwise = "e",
	Tilt_Counter_Clockwise = "q",
	Plane_Select_Move = "mousewheel",
	Open_Menu = "c",
}

local bindBackup = deepcopy(binds)

bindOrder = {
	"Disengage",
	"Toggle_Camera",
	--"Tilt_Clockwise",
	--"Tilt_Counter_Clockwise",
	"Open_Menu",
}
		
bindNames = {
	Shoot = "Shoot",
	Disengage = "Disengage",
	Toggle_Camera = "Toggle Camera",
	Tilt_Clockwise = "Tilt Clockwise",
	Tilt_Counter_Clockwise = "Tilt Counter Clockwise",
	Plane_Select_Move = "Plane Select Move",
	Open_Menu = "Open Menu",
}

function resetKeybinds()
	binds = deepcopy(bindBackup)
end

function getFromBackup(id)
	return bindBackup[id]
end