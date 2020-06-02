TOOL.Name="Luasool"
TOOL.Tab="Wire"
TOOL.Category="Advanced"

if CLIENT
then
	language.Add("Tool.luasool.name","Luasool")
	language.Add("Tool.luasool.desc","Right-click to open LUA editor.")
	language.Add("Tool.luasool.0","Left-click to run current script on server. Shift+Left-Click to run current script on client.")
	function TOOL:LeftClick() return true end
	function TOOL.BuildCPanel(panel)
		local currentDirectory
		local FileBrowser=vgui.Create("wire_expression2_browser",panel)
		panel:AddPanel(FileBrowser)
		FileBrowser:Setup("Luasool")
		FileBrowser:SetSize(235,400)
		function FileBrowser:OnFileOpen(path) Luasool.openEditor(path) end
		local New=vgui.Create("DButton",panel)
		panel:AddPanel(New)
		New:SetText("New file")
		New.DoClick=Luasool.newFile
		local OpenEditor=vgui.Create("DButton",panel)
		panel:AddPanel(OpenEditor)
		OpenEditor:SetText("Open Editor")
		OpenEditor.DoClick=Luasool.openEditor
	end
end
if SERVER
then
	function TOOL:LeftClick(tr)
		net.Start(LUASOOL_NET_RUNCODE)
		net.Send(self:GetOwner())
	end
	function TOOL:RightClick(tr)
		net.Start(LUASOOL_NET_OPENEDITOR)
		net.Send(self:GetOwner())
	end
end
