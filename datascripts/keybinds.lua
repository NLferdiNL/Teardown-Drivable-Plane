#include "scripts/utils.lua"

binds = {
	Shoot = "lmb",
	Disengage = "r",
	Toggle_Camera = "t",
	Plane_Select_Move = "mousewheel",
	Fly_To_Target = "rmb",
	Release_Target = "e",
	Open_Menu = "c",
}

local bindBackup = deepcopy(binds)

bindOrder = {
	"Disengage",
	"Toggle_Camera",
	"Release_Target",
	"Open_Menu",
}
		
bindNames = {
	Shoot = "Shoot",
	Disengage = "Disengage",
	Toggle_Camera = "Toggle Camera",
	Plane_Select_Move = "Plane Select Move",
	Fly_To_Target = "Fly To Target",
	Release_Target = "Release Target",
	Open_Menu = "Open Menu",
}

function resetKeybinds()
	binds = deepcopy(bindBackup)
end

function getFromBackup(id)
	return bindBackup[id]
end