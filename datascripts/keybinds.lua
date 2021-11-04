#include "scripts/utils.lua"

binds = {
	Shoot = "usetool",
	Disengage = "r",
	Toggle_Camera = "t",
	--Tilt_Clockwise = "e",
	--Tilt_Counter_Clockwise = "q",
	Plane_Select_Move = "mousewheel",
	Fly_To_Target = "rmb",
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
	--Tilt_Clockwise = "Tilt Clockwise",
	--Tilt_Counter_Clockwise = "Tilt Counter Clockwise",
	Plane_Select_Move = "Plane Select Move",
	Fly_To_Target = "Fly To Target",
	Open_Menu = "Open Menu",
}

function resetKeybinds()
	binds = deepcopy(bindBackup)
end

function getFromBackup(id)
	return bindBackup[id]
end