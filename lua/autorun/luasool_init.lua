LUASOOL_NET_OPENEDITOR="luasool_openeditor"
LUASOOL_NET_RUNCODE="luasool_runcode"
LUASOOL_NET_CLIENT_PROXY_CALL="lua_client_proxy_call"
LUASOOL_FILE_SCRIPT_DIR="luasool"

local DEFAULT_FLAGS=FCVAR_ARCHIVE
CreateConVar("luasool_error_client_max_hint_length",100,DEFAULT_FLAGS,"Maximum length of error printed to client popup hint.",0)

Luasool=(function()
	local Luasool={}

	-- Generates a table of variables that executed luasools should have acccess to.
	function Luasool.generateInjectables(ply)
		local plyTrace=ply:GetEyeTrace()
		return {
			trace=plyTrace,
			player=ply,
			this=plyTrace.Entity,
			print=SERVER and Luasool.generateClientProxyFunction(ply,"Luasool.print") or Luasool.print,
			PrintTable=SERVER and Luasool.generateClientProxyFunction(ply,"Luasool.printTable") or Luasool.printTable,
		}
	end
	-- Inserted at the start of every executed luasool to generate a closure.
	function Luasool.generateInjectableHeader(ply)
		local retVal="local Luasool=Luasool.currentInjectables\n"
		-- This sets the injectables as a global object temporarily, which
		--  the running script will immediately assign to a local value
		--  to generate the closure.
		-- After that the currentInjectables property can be reassigned.
		Luasool.currentInjectables=Luasool.generateInjectables(ply)
		for i,v in pairs(Luasool.currentInjectables)
		do
			retVal=retVal.."local "..i.."=Luasool[\""..i.."\"]\n"
		end
		return retVal
	end
	-- Prints or dispatches error message.
	function Luasool.error(error,ply)
		if SERVER
		then
			print("Luasool error from "..ply:GetName()..": "..error)
			Luasool.generateClientProxyFunction(ply,"Luasool.printError")(error)
		else
			ErrorNoHalt("Luasool Error: "..error)
			local maxHintLength=GetConVar("luasool_error_client_max_hint_length"):GetInt()
			if #error > maxHintLength then error=error:sub(1,maxHintLength).."..." end
			WireLib.AddNotify(ply,"Error: "..error,NOTIFY_ERROR,3,NOTIFYSOUND_ERROR1)
		end
	end
	-- Executes a provided luasool.
	function Luasool.execute(code,ply)
		if CLIENT and not ply then ply=LocalPlayer() end
		if SERVER and not ply:IsAdmin()	then Luasool.sendError(ply,"Only admins can run code on the server!")
		else
			local fullCode=Luasool.generateInjectableHeader(ply)..code
			local err=RunString(fullCode,"Luasool Execution",false)
			if err then Luasool.error(err,ply) end
		end
	end

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
			net.Start(LUASOOL_NET_RUNCODE)
			net.WriteString(code)
			net.SendToServer()
		end
		-- Pretty print functions.
		function Luasool.print(...)
			local args={...}
			print(...)
			for k,v in pairs(args) do chat.AddText(v) end
		end
		function Luasool.printTable(tab)
			PrintTable(tab)
			chat.AddText("<PrintTable sent to console.>")
		end

		net.Receive(LUASOOL_NET_OPENEDITOR,function() Luasool.openEditor() end)
		net.Receive(LUASOOL_NET_RUNCODE,function()
			local code=Luasool.getActiveCode()
			if LocalPlayer():KeyDown(IN_SPEED) then Luasool.execute(code)
			else Luasool.runCodeOnServer(code) end
		end)
		-- Receives client proxy requests from an actively-running luasool and executes it.
		--  functionAddress refers to name of a globally-accessible function, by however
		--  that variable is referenced from the global object.
		-- By splitting the address by dot operator and indexing an object/table property
		--  by each substring, the specified address can be of arbitrary depth as long as
		--  it is globally-accessible.
		net.Receive(LUASOOL_NET_CLIENT_PROXY_CALL,function()
			local functionAddress=net.ReadString()
			local arg=net.ReadTable()
			local obj=_G
			-- For each substring between dot operators, we perform an operation
			--  to index the next-deep property.
			for part in string.gmatch(functionAddress,"([^\\.]+)")
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
		util.AddNetworkString(LUASOOL_NET_CLIENT_PROXY_CALL)

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
		-- Handles a request from a player to execute a luasool.
		net.Receive(LUASOOL_NET_RUNCODE,function(len,ply) Luasool.execute(net.ReadString(),ply) end)
	end
	return Luasool
end)()
return Luasool
