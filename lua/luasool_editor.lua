local _LuasoolEditor

function CreateNewLuasoolEditor()
	local retVal=vgui.Create("Expression2EditorFrame")
	retVal:Setup("Luasool Editor","luasool")
	return retVal
end

LuasoolEditor=LuasoolEditor||function(forceReset)
	_LuasoolEditor=((not forceReset)&&_LuasoolEditor)||CreateNewLuasoolEditor()
	return _LuasoolEditor
end

function ReloadLuasoolEditor()
	LuasoolEditor(true)
end
