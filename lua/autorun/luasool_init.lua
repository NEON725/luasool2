LUASOOL_NET_OPENEDITOR="luasool_openeditor"
LUASOOL_NET_RUNCODE="luasool_runcode"
LUASOOL_NET_ERROR="luasool_error"
LUASOOL_NET_CLIENT_PROXY_CALL="lua_client_proxy_call"
LUASOOL_FILE_SCRIPT_DIR="luasool"
LUASOOL_ERROR_SERVER_MAX_PRINT_LENGTH=200
LUASOOL_ERROR_CLIENT_MAX_HINT_LENGTH=100

Luasool=(function()
	local Luasool={}
	if CLIENT
	then
		include("luasool_editor.lua")
		-- Data directory must be present to prevent problems with e2 editor.
		if not file.Exists(LUASOOL_FILE_SCRIPT_DIR,"DATA") then file.CreateDir(LUASOOL_FILE_SCRIPT_DIR) end
		-- Convenience functions for interacting with editor panel.
		function Luasool.openEditor(filepath,newtab)
			LuasoolEditor():Open(filepath,nil,newtab)
		end
		function Luasool.newFile()
			LuasoolEditor():AutoSave()
			LuasoolEditor():NewScript(false)
                end
		function Luasool.getActiveCode()
			return LuasoolEditor():GetCode()
		end
		-- Submits a luasool to server for execution.
		-- TODO: Replace with chunk queue to handle large scripts.
		function Luasool.runCodeOnServer(code)
			if not code then code=Luasool.getActiveCode() end
			net.Start(LUASOOL_NET_RUNCODE)
			net.WriteString(code)
			net.SendToServer()
		end
		-- Pretty print functions.
		function Luasool.printError(err)
			ErrorNoHalt("Luasool Error: "..err)
			if #err > LUASOOL_ERROR_CLIENT_MAX_HINT_LENGTH
			then
				err=err:sub(1,LUASOOL_ERROR_CLIENT_MAX_HINT_LENGTH).."..."
			end
			WireLib.AddNotify(LocalPlayer(),"Error: "..err,NOTIFY_ERROR,3,NOTIFYSOUND_ERROR1)
		end
		function Luasool.print(...)
			local args={...}
			print(...)
			for k,v in pairs(args)
			do
				chat.AddText(v)
			end
		end
		function Luasool.printTable(tab)
			PrintTable(tab)
			chat.AddText("<PrintTable sent to console.>")
		end

		net.Receive(LUASOOL_NET_OPENEDITOR,function() Luasool.openEditor() end)
		net.Receive(LUASOOL_NET_RUNCODE,function() Luasool.runCodeOnServer() end)
		net.Receive(LUASOOL_NET_ERROR,function() Luasool.printError(net.ReadString()) end)
		--Receives client proxy requests from an actively-running luasool and executes it.
		net.Receive(LUASOOL_NET_CLIENT_PROXY_CALL,function()
			local functionAddress=net.ReadString()
			local arg=net.ReadTable()
			local obj=_G
			for part in string.gmatch(functionAddress,"([^.]+)")
			do
				obj=obj[part]
				if not obj
				then
					Luasool.printError("Could not find function by address: "..functionAddress)
					return
				end
			end
			obj(unpack(arg))
		end)
	end
	if SERVER
	then
		util.AddNetworkString(LUASOOL_NET_OPENEDITOR)
		util.AddNetworkString(LUASOOL_NET_RUNCODE)
		util.AddNetworkString(LUASOOL_NET_ERROR)
		util.AddNetworkString(LUASOOL_NET_CLIENT_PROXY_CALL)
		function Luasool.sendError(ply,error)
			net.Start(LUASOOL_NET_ERROR)
			net.WriteString(error)
			net.Send(ply)
		end
		-- Handles a request from a player to execute a luasool.
		net.Receive(LUASOOL_NET_RUNCODE,function(len,ply)
			if not ply:IsAdmin()
			then
				Luasool.sendError(ply,"Only admins can run code on the server!")
			else
				local code=net.ReadString()
				local fullCode=Luasool.generateInjectableHeader(ply)..code
				local err=RunString(fullCode,"Luasool Execution",false)
				if err
				then
					print("Luasool error from "..ply:GetName()..": "..err)
					print(code:sub(1,LUASOOL_ERROR_SERVER_MAX_PRINT_LENGTH))
					Luasool.sendError(ply,err)
				end
			end
		end)
		-- Generates a table of variables that executed luasools should have acccess to.
		function Luasool.generateInjectables(ply)
			local plyTrace=ply:GetEyeTrace()
			-- NOTE: This is set as a globally-accessible variable, and is overwritten
			--  by subsequent calls. Header code will create a file-local closure
			--  for the luasool, at which point it is safe to generate a new batch
			--  of injectables.
			Luasool.currentInjectables={
				trace=plyTrace,
				player=ply,
				this=plyTrace.Entity,
				print=Luasool.generateClientProxyFunction(ply,"Luasool.print"),
				serverPrint=print,
				PrintTable=Luasool.generateClientProxyFunction(ply,"Luasool.printTable"),
				ServerPrintTable=PrintTable
			}
			return Luasool.currentInjectables
		end
		-- Inserted at the start of every executed luasool to generate a closure.
		function Luasool.generateInjectableHeader(ply)
			local retVal="local Luasool=Luasool.currentInjectables\n"
			local injectables=Luasool.generateInjectables(ply)
			for i,v in pairs(injectables)
			do
				retVal=retVal.."local "..i.."=Luasool[\""..i.."\"]\n"
			end
			return retVal
		end
		-- Returns a function that, when called, delegates calling that function
		--  to the client.
		function Luasool.generateClientProxyFunction(ply,functionAddressableName)
			return function(...)
				local args={...}
				net.Start(LUASOOL_NET_CLIENT_PROXY_CALL)
				net.WriteString(functionAddressableName)
				net.WriteTable(args)
				net.Send(ply)
			end
		end
	end
	return Luasool
end)()
return Luasool
