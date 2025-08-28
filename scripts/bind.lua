script_name("Binder")
script_description('Binder for MonetLoader / MoonLoader')
script_author("MTG MODS")

require "lib.moonloader"
require 'encoding'.default = 'CP1251'
local u8 = require 'encoding'.UTF8

local settings = {}
local default_settings = {
	commands = {
		{ cmd = 'arma' , description = 'Rol de arma' , text = '/do severia marihuano sacar un fierro de su espalda para matar verdes', arg = '' , enable = true, deleted = false, waiting = '1.200' },
	},
}
local configDirectory = getWorkingDirectory() .. "/config"
local path = configDirectory .. "/bind.json"

function load_settings()
    if not doesDirectoryExist(configDirectory) then
        createDirectory(configDirectory)
    end
    if not doesFileExist(path) then
        settings = default_settings
		print('[Bind] No se encontro el archivo de configuracion, usando la configuracion estandar!')
    else
        local file = io.open(path, 'r')
        if file then
            local contents = file:read('*a')
            file:close()
			if #contents == 0 then
				settings = default_settings
				print('[Bind] No se pudo abrir el archivo de configuracion usando la configuracion estandar!')
			else
				local result, loaded = pcall(decodeJson, contents)
				if result then
					settings = loaded
					for category, _ in pairs(default_settings) do
						if settings[category] == nil then
							settings[category] = {}
						end
						for key, value in pairs(default_settings[category]) do
							if settings[category][key] == nil then
								settings[category][key] = value
							end
						end
					end
					print('[Bind] La configuracion se cargo correctamente!')
				else
					print('[Bind] No pude abrir el archivo de configuracion, estoy usando la configuracion estandar!')
				end
			end
        else
            settings = default_settings
			print('[Bind] No pude abrir el archivo de configuracion, estoy usando la configuracion estandar!')
        end
    end
end
function save_settings()
    local file, errstr = io.open(path, 'w')
    if file then
        local result, encoded = pcall(encodeJson, settings)
        file:write(result and encoded or "")
        file:close()
        return result
    else
        print('[Bind] No se pudo guardar la configuracion del asistente, error: ', errstr)
        return false
    end
end

load_settings()

function isMonetLoader() return MONET_VERSION ~= nil end
if MONET_DPI_SCALE == nil then MONET_DPI_SCALE = 1.0 end

local ffi = require 'ffi'

local message_color = 0x00CCFF
local message_color_hex = '{00CCFF}'

local fa = require('fAwesome6_solid')
local imgui = require('mimgui')
local sizeX, sizeY = getScreenResolution()
local new = imgui.new
local MainWindow = new.bool()
local BinderWindow = new.bool()
local ComboTags = new.int()
local item_list = {u8'Sin argumentos', u8'{arg} - Acepta cualquier cosa, letras/numeros/simbolos', u8'{arg_id} - Solo acepta ID de jugador', u8'{arg_id} {arg2} - Acepta 2 argumentos: ID del jugador y segundo cualquier cosa'}
local ImItems = imgui.new['const char*'][#item_list](item_list)
local change_cmd_bool = false
local change_cmd = ''
local change_description = ''
local change_text = ''
local change_arg = ''
local slider = new.float(0)

local isActiveCommand = false
local command_stop = false

local tagReplacements = {
	my_id = function() return select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) end,
    my_nick = function() return sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) end,
	my_ru_nick = function() return TranslateNick(sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))) end,
	get_time = function ()
		return os.date("%H:%M:%S")
	end,
}
local binder_tags_text = [[
{my_id} - Tu ID de juego
{my_nick} - Nick tu juego
{my_ru_nick} - Su nombre y apellido aparecen en el ayudante

{get_time} - Obtiene la hora actual

{get_nick({arg_id})} - Obtiene el Nick del jugador a partir del argumento ID del jugador
{get_rp_nick({arg_id})} - Obtiene el Nick del jugador sin el simbolo _ del argumento ID del jugador
{get_ru_nick({arg_id})} - Obtiene el Nick del jugador en cirilico a partir del argumento ID del jugador
]]

function main()

	if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(0) end 
	
	sampAddChatMessage('[Bind] {ffffff}Para abrir el menu de la carpeta, ingrese el comando ' .. message_color_hex .. '/bind', message_color)
	sampRegisterChatCommand("bind", function() MainWindow[0] = not MainWindow[0] end)
	sampRegisterChatCommand("stop", function() if isActiveCommand then command_stop = true else sampAddChatMessage('[Bind] {ffffff}Error, no se esta ejecutando ningun comando!', message_color) end end)
	registerCommandsFrom(settings.commands)

	wait(-1)

end

function registerCommandsFrom(array)
	for _, command in ipairs(array) do
		if command.enable and not command.deleted then
			register_command(command.cmd, command.arg, command.text, tonumber(command.waiting))
		end
	end
end
function register_command(chat_cmd, cmd_arg, cmd_text, cmd_waiting)
	sampRegisterChatCommand(chat_cmd, function(arg)
		if not isActiveCommand then
			local arg_check = false
			local modifiedText = cmd_text
			if cmd_arg == '{arg}' then
				if arg and arg ~= '' then
					modifiedText = modifiedText:gsub('{arg}', arg or "")
					arg_check = true
				else
					sampAddChatMessage('[Bind] {ffffff}Usa ' .. message_color_hex .. '/' .. chat_cmd .. ' [argumento]', message_color)
					play_error_sound()
				end
			elseif cmd_arg == '{arg_id}' then
				if isParamSampID(arg) then
					arg = tonumber(arg)
					modifiedText = modifiedText:gsub('%{get_nick%(%{arg_id%}%)%}', sampGetPlayerNickname(arg) or "")
					modifiedText = modifiedText:gsub('%{get_rp_nick%(%{arg_id%}%)%}', sampGetPlayerNickname(arg):gsub('_',' ') or "")
					modifiedText = modifiedText:gsub('%{get_ru_nick%(%{arg_id%}%)%}', TranslateNick(sampGetPlayerNickname(arg)) or "")
					modifiedText = modifiedText:gsub('%{arg_id%}', arg or "")
					arg_check = true
				else
					sampAddChatMessage('[Bind] {ffffff}Usa ' .. message_color_hex .. '/' .. chat_cmd .. ' [ID del jugador]', message_color)
					play_error_sound()
				end
			elseif cmd_arg == '{arg_id} {arg2}' then
				if arg and arg ~= '' then
					local arg_id, arg2 = arg:match('(%d+) (.+)')
					if isParamSampID(arg_id) and arg2 then
						arg_id = tonumber(arg_id)
						modifiedText = modifiedText:gsub('%{get_nick%(%{arg_id%}%)%}', sampGetPlayerNickname(arg_id) or "")
						modifiedText = modifiedText:gsub('%{get_rp_nick%(%{arg_id%}%)%}', sampGetPlayerNickname(arg_id):gsub('_',' ') or "")
						modifiedText = modifiedText:gsub('%{get_ru_nick%(%{arg_id%}%)%}', TranslateNick(sampGetPlayerNickname(arg_id)) or "")
						modifiedText = modifiedText:gsub('%{arg_id%}', arg_id or "")
						modifiedText = modifiedText:gsub('%{arg2%}', arg2 or "")
						arg_check = true
					else
						sampAddChatMessage('[Bind] {ffffff}Usa ' .. message_color_hex .. '/' .. chat_cmd .. ' [ID del jugador] [argumento]', message_color)
						play_error_sound()
					end
				else
					sampAddChatMessage('[Bind] {ffffff}Usa ' .. message_color_hex .. '/' .. chat_cmd .. ' [ID del jugador] [argumento]', message_color)
					play_error_sound()
				end
			elseif cmd_arg == '' then
				arg_check = true
			end
			if arg_check then
				lua_thread.create(function()
					isActiveCommand = true
					local lines = {}
					for line in string.gmatch(modifiedText, "[^&]+") do
						table.insert(lines, line)
					end
					for _, line in ipairs(lines) do
						if command_stop then 
							command_stop = false 
							isActiveCommand = false
							sampAddChatMessage('[Bind] {ffffff}Comando /' .. chat_cmd .. " Detenido con exito!", message_color) 
							return 
						end
						for tag, replacement in pairs(tagReplacements) do
							line = line:gsub("{" .. tag .. "}", replacement())
						end
						sampSendChat(line)
						wait(cmd_waiting * 1000)
					end
					isActiveCommand = false
				end)
			end
		else
			sampAddChatMessage('[Bind] {ffffff}Espere hasta que se complete el comando anterior!', message_color)
		end
	end)
end

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = nil
	fa.Init(14 * MONET_DPI_SCALE)
	apply_dark_theme()
end)

local MainWindow = imgui.OnFrame(
    function() return MainWindow[0] end,
    function(player)
	
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(600 * MONET_DPI_SCALE, 425	* MONET_DPI_SCALE), imgui.Cond.FirstUseEver)
		imgui.Begin(u8" BIND Version en espanol", MainWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize )
	
		if imgui.BeginChild('##1', imgui.ImVec2(589 * MONET_DPI_SCALE, 333 * MONET_DPI_SCALE), true) then
			imgui.Columns(3)
			imgui.CenterColumnText(u8"Comando")
			imgui.SetColumnWidth(-1, 170 * MONET_DPI_SCALE)
			imgui.NextColumn()
			imgui.CenterColumnText(u8"Descripcion")
			imgui.SetColumnWidth(-1, 300 * MONET_DPI_SCALE)
			imgui.NextColumn()
			imgui.CenterColumnText(u8"Accion")
			imgui.SetColumnWidth(-1, 150 * MONET_DPI_SCALE)
			imgui.Columns(1)
			imgui.Separator()
			imgui.Columns(3)
			imgui.CenterColumnText(u8"/bind")
			imgui.NextColumn()
			imgui.CenterColumnText(u8"Abre el menu principal de la carpeta bind")
			imgui.NextColumn()
			imgui.CenterColumnText(u8"No disponible")
			imgui.Columns(1)	
			imgui.Separator()
			imgui.Columns(3)
			imgui.CenterColumnText(u8"/stop")
			imgui.NextColumn()
			imgui.CenterColumnText(u8"Detiene todos los comandos de la carpeta bind")
			imgui.NextColumn()
			imgui.CenterColumnText(u8"No disponible")
			imgui.Columns(1)	
			imgui.Separator()
			for index, command in ipairs(settings.commands) do
				if not command.deleted then
					imgui.Columns(3)
					if command.enable then
						imgui.CenterColumnText('/' .. u8(command.cmd))
						imgui.NextColumn()
						imgui.CenterColumnText(u8(command.description))
						imgui.NextColumn()
					else
						imgui.CenterColumnTextDisabled('/' .. u8(command.cmd))
						imgui.NextColumn()
						imgui.CenterColumnTextDisabled(u8(command.description))
						imgui.NextColumn()
					end
					imgui.Text(' ')
					imgui.SameLine()
					if command.enable then
						if imgui.SmallButton(fa.TOGGLE_ON .. '##'..command.cmd) then
							command.enable = not command.enable
							save_settings()
							sampUnregisterChatCommand(command.cmd)
						end
						if imgui.IsItemHovered() then
							imgui.SetTooltip(u8"Desactivar comando /"..command.cmd)
						end
					else
						if imgui.SmallButton(fa.TOGGLE_OFF .. '##'..command.cmd) then
							command.enable = not command.enable
							save_settings()
							register_command(command.cmd, command.arg, command.text, tonumber(command.waiting))
						end
						if imgui.IsItemHovered() then
							imgui.SetTooltip(u8"Activar comando /"..command.cmd)
						end
					end
					imgui.SameLine()
					if imgui.SmallButton(fa.PEN_TO_SQUARE .. '##'..command.cmd) then
						change_description = command.description
						input_description = imgui.new.char[256](u8(change_description))
						change_arg = command.arg
						if command.arg == '' then
							ComboTags[0] = 0
						elseif command.arg == '{arg}' then	
							ComboTags[0] = 1
						elseif command.arg == '{arg_id}' then
							ComboTags[0] = 2
						elseif command.arg == '{arg_id} {arg2}' then
							ComboTags[0] = 3
						end
						change_cmd = command.cmd
						input_cmd = imgui.new.char[256](u8(command.cmd))
						change_text = command.text:gsub('&', '\n')		
						input_text = imgui.new.char[8192](u8(change_text))
						change_waiting = command.waiting
						waiting_slider = imgui.new.float(tonumber(command.waiting))	
						BinderWindow[0] = true
					end
					if imgui.IsItemHovered() then
						imgui.SetTooltip(u8"Editar comando /"..command.cmd)
					end
					imgui.SameLine()
					if imgui.SmallButton(fa.TRASH_CAN .. '##'..command.cmd) then
						imgui.OpenPopup(fa.TRIANGLE_EXCLAMATION .. u8' Advertencia ##' .. command.cmd)
					end
					if imgui.IsItemHovered() then
						imgui.SetTooltip(u8"Eliminar comando /"..command.cmd)
					end
					if imgui.BeginPopupModal(fa.TRIANGLE_EXCLAMATION .. u8' Advertencia ##' .. command.cmd, _, imgui.WindowFlags.NoResize ) then
						imgui.CenterText(u8'Estas seguro de que deseas eliminar el comando /' .. u8(command.cmd) .. '?')
						imgui.Separator()
						if imgui.Button(fa.CIRCLE_XMARK .. u8' No, cancelalo', imgui.ImVec2(200 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
							imgui.CloseCurrentPopup()
						end
						imgui.SameLine()
						if imgui.Button(fa.TRASH_CAN .. u8' Si, eliminar', imgui.ImVec2(200 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
							command.enable = false
							command.deleted = true
							sampUnregisterChatCommand(command.cmd)
							save_settings()
							imgui.CloseCurrentPopup()
						end
						imgui.End()
					end
					imgui.Columns(1)
					imgui.Separator()
				end
			end
			imgui.EndChild()
		end
		if imgui.Button(fa.CIRCLE_PLUS .. u8' Crear un nuevo comando##new_cmd',imgui.ImVec2(imgui.GetMiddleButtonX(1), 0)) then
			local new_cmd = {cmd = '', description = '', text = '', arg = '', enable = true , waiting = '1.200', deleted = false }
			table.insert(settings.commands, new_cmd)
			change_description = new_cmd.description
			input_description = imgui.new.char[256](u8(change_description))
			change_arg = new_cmd.arg
			ComboTags[0] = 0
			change_cmd = new_cmd.cmd
			input_cmd = imgui.new.char[256](u8(new_cmd.cmd))
			change_text = new_cmd.text:gsub('&', '\n')
			input_text = imgui.new.char[8192](u8(change_text))
			change_waiting = 1.200
			waiting_slider = imgui.new.float(1.200)	
			BinderWindow[0] = true
		end
		if imgui.Button(fa.HEADSET .. u8' Servidor de Discord MST - Community/Mods',imgui.ImVec2(imgui.GetMiddleButtonX(1), 0)) then
			openLink('https://discord.gg/99nDhgmv')
		end
		imgui.End()
    end
)

imgui.OnFrame(
    function() return BinderWindow[0] end,
    function(player)
		imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(600 * MONET_DPI_SCALE, 425	* MONET_DPI_SCALE), imgui.Cond.FirstUseEver)
		imgui.Begin(u8" BIND - Editar Comando " .. change_cmd, BinderWindow, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize  )
		if imgui.BeginChild('##binder_edit', imgui.ImVec2(589 * MONET_DPI_SCALE, 361 * MONET_DPI_SCALE), true) then
			imgui.CenterText(fa.FILE_LINES .. u8' Descripcion del comando:')
			imgui.PushItemWidth(579 * MONET_DPI_SCALE)
			imgui.InputText("##input_description", input_description, 256)
			imgui.Separator()
			imgui.CenterText(fa.TERMINAL .. u8' Comando para usar en el chat (ponerlo sin /):')
			imgui.PushItemWidth(579 * MONET_DPI_SCALE)
			imgui.InputText("##input_cmd", input_cmd, 256)
			imgui.Separator()
			imgui.CenterText(fa.CODE .. u8' Argumentos aceptados por el comando:')
	    	imgui.Combo(u8'',ComboTags, ImItems, #item_list)
	 	    imgui.Separator()
	        imgui.CenterText(fa.FILE_WORD .. u8' Vincular texto para el comando:')
			imgui.InputTextMultiline("##text_multiple", input_text, 8192, imgui.ImVec2(579 * MONET_DPI_SCALE, 173 * MONET_DPI_SCALE))
		imgui.EndChild() end
		if imgui.Button(fa.CIRCLE_XMARK .. u8' Cancelar', imgui.ImVec2(imgui.GetMiddleButtonX(4), 0)) then
			BinderWindow[0] = false
		end
		imgui.SameLine()
		if imgui.Button(fa.CLOCK .. u8' Demora',imgui.ImVec2(imgui.GetMiddleButtonX(4), 0)) then
			imgui.OpenPopup(fa.CLOCK .. u8' Retraso (en segundos) ')
		end
		if imgui.BeginPopupModal(fa.CLOCK .. u8' Retraso (en segundos) ', _, imgui.WindowFlags.NoResize ) then
			imgui.PushItemWidth(200 * MONET_DPI_SCALE)
			imgui.SliderFloat(u8'##waiting', waiting_slider, 0.3, 5)
			imgui.Separator()
			if imgui.Button(fa.CIRCLE_XMARK .. u8' Cancelar', imgui.ImVec2(imgui.GetMiddleButtonX(2), 0)) then
				waiting_slider = imgui.new.float(tonumber(change_waiting))	
				imgui.CloseCurrentPopup()
			end
			imgui.SameLine()
			if imgui.Button(fa.FLOPPY_DISK .. u8' Guardar', imgui.ImVec2(imgui.GetMiddleButtonX(2), 0)) then
				imgui.CloseCurrentPopup()
			end
			imgui.End()
		end
		imgui.SameLine()
		if imgui.Button(fa.TAGS .. u8' Etiqueta ', imgui.ImVec2(imgui.GetMiddleButtonX(4), 0)) then
			imgui.OpenPopup(fa.TAGS .. u8' Etiquetas principales para uso en bind')
		end
		if imgui.BeginPopupModal(fa.TAGS .. u8' Etiquetas principales para uso en bind', _, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize  + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.AlwaysAutoResize ) then
			imgui.Text(u8(binder_tags_text))
			imgui.Separator()
			if imgui.Button(fa.CIRCLE_XMARK .. u8' Cerrar', imgui.ImVec2(imgui.GetMiddleButtonX(1), 0)) then
				imgui.CloseCurrentPopup()
			end
			imgui.End()
		end
		imgui.SameLine()
if imgui.Button(fa.FLOPPY_DISK .. ' Guardar', imgui.ImVec2(imgui.GetMiddleButtonX(4), 0)) then
	if ffi.string(input_cmd):find('%W') or ffi.string(input_cmd) == '' or ffi.string(input_description) == '' or ffi.string(input_text) == '' then
		imgui.OpenPopup(fa.TRIANGLE_EXCLAMATION .. ' Error al guardar el pedido')
	else
		local new_arg = ''
		if ComboTags[0] == 0 then
			new_arg = ''
		elseif ComboTags[0] == 1 then
			new_arg = '{arg}'
		elseif ComboTags[0] == 2 then
			new_arg = '{arg_id}'
		elseif ComboTags[0] == 3 then
			new_arg = '{arg_id} {arg2}'
		end
		local new_waiting = waiting_slider[0]
		local new_description = u8:decode(ffi.string(input_description))
		local new_command = u8:decode(ffi.string(input_cmd))
		local new_text = u8:decode(ffi.string(input_text)):gsub('\n', '&')
		if binder_create_command_9_10 then
			for _, command in ipairs(settings.commands_manage) do
				if command.cmd == change_cmd and command.description == change_description and command.arg == change_arg and command.text:gsub('&', '\n') == change_text then
					command.cmd = new_command
					command.arg = new_arg
					command.description = new_description
					command.text = new_text
					command.waiting = new_waiting
					save_settings()
					if command.arg == '' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' {ffffff}Guardado exitosamente!', message_color)
					elseif command.arg == '{arg}' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' [argumento] {ffffff}Guardado exitosamente!', message_color)
					elseif command.arg == '{arg_id}' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' [ID del jugador] {ffffff}Guardado exitosamente!', message_color)
					elseif command.arg == '{arg_id} {arg2}' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' [ID del jugador] [argumento] {ffffff}Guardado exitosamente!', message_color)
					end
					sampUnregisterChatCommand(change_cmd)
					register_command(command.cmd, command.arg, command.text, tonumber(command.waiting))
					binder_create_command_9_10 = false
					break
				end
			end
		else
			for _, command in ipairs(settings.commands) do
				if command.cmd == change_cmd and command.description == change_description and command.arg == change_arg and command.text:gsub('&', '\n') == change_text then
					command.cmd = new_command
					command.arg = new_arg
					command.description = new_description
					command.text = new_text
					command.waiting = new_waiting
					save_settings()
					if command.arg == '' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' {ffffff}Guardado exitosamente!', message_color)
					elseif command.arg == '{arg}' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' [argumento] {ffffff}Guardado exitosamente!', message_color)
					elseif command.arg == '{arg_id}' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' [ID del jugador] {ffffff}Guardado exitosamente!', message_color)
					elseif command.arg == '{arg_id} {arg2}' then
						sampAddChatMessage('[Bind] {ffffff}Comando ' .. message_color_hex .. '/' .. new_command .. ' [ID del jugador] [argumento] {ffffff}Guardado exitosamente!', message_color)
					end
					sampUnregisterChatCommand(change_cmd)
					register_command(command.cmd, command.arg, command.text, tonumber(command.waiting))
					break
				end
			end
		end
		BinderWindow[0] = false
	end
end
if imgui.BeginPopupModal(fa.TRIANGLE_EXCLAMATION .. ' Error al guardar el pedido', _, imgui.WindowFlags.AlwaysAutoResize) then
	if ffi.string(input_cmd):find('%W') then
		imgui.BulletText(" Dalam perintah hanya boleh menggunakan huruf Inggris dan/atau angka!")
	elseif ffi.string(input_cmd) == '' then
		imgui.BulletText(" El comando no puede estar vacio!")
	end
	if ffi.string(input_description) == '' then
		imgui.BulletText(" La descripcion no puede estar vacia!")
	end
	if ffi.string(input_text) == '' then
		imgui.BulletText(" La vinculacion de texto no puede estar vacia!")
	end
	imgui.Separator()
	if imgui.Button(fa.CIRCLE_XMARK .. ' Cerrar', imgui.ImVec2(300 * MONET_DPI_SCALE, 25 * MONET_DPI_SCALE)) then
		imgui.CloseCurrentPopup()
	end
	imgui.End()
end
imgui.End()
end
)

function imgui.CenterText(text)
local width = imgui.GetWindowWidth()
local calc = imgui.CalcTextSize(text)
imgui.SetCursorPosX(width / 2 - calc.x / 2)
imgui.Text(text)
end
function imgui.CenterColumnText(text)
imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text).x / 2)
imgui.Text(text)
end
function imgui.CenterColumnTextDisabled(text)
imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text).x / 2)
imgui.TextDisabled(text)
end

function imgui.CenterColumnColorText(imgui_RGBA, text)
    imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text).x / 2)
	imgui.TextColored(imgui_RGBA, text)
end
function imgui.CenterColumnInputText(text,v,size)

	if text:find('^(.+)##(.+)') then
		local text1, text2 = text:match('(.+)##(.+)')
		imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - (imgui.CalcTextSize(text1).x / 2) - (imgui.CalcTextSize(v).x / 2 ))
	elseif text:find('^##(.+)') then
		imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2) ) - (imgui.CalcTextSize(v).x / 2 ) )
	else
		imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - (imgui.CalcTextSize(text).x / 2) - (imgui.CalcTextSize(v).x / 2 ))
	end   
	
	if imgui.InputText(text,v,size) then
		return true
	else
		return false
	end
	
end
function imgui.CenterColumnButton(text)

	if text:find('(.+)##(.+)') then
		local text1, text2 = text:match('(.+)##(.+)')
		imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text1).x / 2)
	else
		imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text).x / 2)
	end
	
    if imgui.Button(text) then
		return true
	else
		return false
	end
end
function imgui.CenterColumnSmallButton(text)

	if text:find('(.+)##(.+)') then
		local text1, text2 = text:match('(.+)##(.+)')
		imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text1).x / 2)
	else
		imgui.SetCursorPosX((imgui.GetColumnOffset() + (imgui.GetColumnWidth() / 2)) - imgui.CalcTextSize(text).x / 2)
	end
	
    if imgui.SmallButton(text) then
		return true
	else
		return false
	end
	
end
function imgui.CenterTextDisabled(text)
    local width = imgui.GetWindowWidth()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.TextDisabled(text)
end
function imgui.GetMiddleButtonX(count)
    local width = imgui.GetWindowContentRegionWidth() -- ������ ��������� ����
    local space = imgui.GetStyle().ItemSpacing.x
    return count == 1 and width or width/count - ((space * (count-1)) / count) -- �������� ������� ������ �� ����������
end
function apply_dark_theme()

	imgui.SwitchContext()
    imgui.GetStyle().WindowPadding = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
    imgui.GetStyle().FramePadding = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
    imgui.GetStyle().ItemSpacing = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
    imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(2 * MONET_DPI_SCALE, 2 * MONET_DPI_SCALE)
    imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(0, 0)
    imgui.GetStyle().IndentSpacing = 0
    imgui.GetStyle().ScrollbarSize = 10 * MONET_DPI_SCALE
    imgui.GetStyle().GrabMinSize = 10 * MONET_DPI_SCALE
    imgui.GetStyle().WindowBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().ChildBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().PopupBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().FrameBorderSize = 1 * MONET_DPI_SCALE
    imgui.GetStyle().TabBorderSize = 1 * MONET_DPI_SCALE
	imgui.GetStyle().WindowRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().ChildRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().FrameRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().PopupRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().ScrollbarRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().GrabRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().TabRounding = 8 * MONET_DPI_SCALE
    imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
    imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
    
    imgui.GetStyle().Colors[imgui.Col.Text]                   = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextDisabled]           = imgui.ImVec4(0.50, 0.50, 0.50, 1.00)
    imgui.GetStyle().Colors[imgui.Col.WindowBg]               = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ChildBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PopupBg]                = imgui.ImVec4(0.07, 0.07, 0.07, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Border]                 = imgui.ImVec4(0.25, 0.25, 0.26, 0.54)
    imgui.GetStyle().Colors[imgui.Col.BorderShadow]           = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]         = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.FrameBgActive]          = imgui.ImVec4(0.25, 0.25, 0.26, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBg]                = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgActive]          = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.MenuBarBg]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarBg]            = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]          = imgui.ImVec4(0.00, 0.00, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]   = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]    = imgui.ImVec4(0.51, 0.51, 0.51, 1.00)
    imgui.GetStyle().Colors[imgui.Col.CheckMark]              = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrab]             = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]       = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Button]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonHovered]          = imgui.ImVec4(0.21, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ButtonActive]           = imgui.ImVec4(0.41, 0.41, 0.41, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Header]                 = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderHovered]          = imgui.ImVec4(0.20, 0.20, 0.20, 1.00)
    imgui.GetStyle().Colors[imgui.Col.HeaderActive]           = imgui.ImVec4(0.47, 0.47, 0.47, 1.00)
    imgui.GetStyle().Colors[imgui.Col.Separator]              = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorHovered]       = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.SeparatorActive]        = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.ResizeGrip]             = imgui.ImVec4(1.00, 1.00, 1.00, 0.25)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]      = imgui.ImVec4(1.00, 1.00, 1.00, 0.67)
    imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]       = imgui.ImVec4(1.00, 1.00, 1.00, 0.95)
    imgui.GetStyle().Colors[imgui.Col.Tab]                    = imgui.ImVec4(0.12, 0.12, 0.12, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabHovered]             = imgui.ImVec4(0.28, 0.28, 0.28, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabActive]              = imgui.ImVec4(0.30, 0.30, 0.30, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocused]           = imgui.ImVec4(0.07, 0.10, 0.15, 0.97)
    imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive]     = imgui.ImVec4(0.14, 0.26, 0.42, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLines]              = imgui.ImVec4(0.61, 0.61, 0.61, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]       = imgui.ImVec4(1.00, 0.43, 0.35, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogram]          = imgui.ImVec4(0.90, 0.70, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.PlotHistogramHovered]   = imgui.ImVec4(1.00, 0.60, 0.00, 1.00)
    imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]         = imgui.ImVec4(1.00, 0.00, 0.00, 0.35)
    imgui.GetStyle().Colors[imgui.Col.DragDropTarget]         = imgui.ImVec4(1.00, 1.00, 0.00, 0.90)
    imgui.GetStyle().Colors[imgui.Col.NavHighlight]           = imgui.ImVec4(0.26, 0.59, 0.98, 1.00)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]  = imgui.ImVec4(1.00, 1.00, 1.00, 0.70)
    imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]      = imgui.ImVec4(0.80, 0.80, 0.80, 0.20)
    imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]       = imgui.ImVec4(0.12, 0.12, 0.12, 0.95)
	
	
	
end

function openLink(link)
	if isMonetLoader() then
		local gta = ffi.load('GTASA')
		ffi.cdef[[
			void _Z12AND_OpenLinkPKc(const char* link);
		]]
		gta._Z12AND_OpenLinkPKc(link)
	else
		os.execute("explorer " .. link)
	end
end
function play_error_sound()
	if not isMonetLoader() and sampIsLocalPlayerSpawned() then
		addOneOffSound(getCharCoordinates(PLAYER_PED), 1149)
	end
end
local russian_characters = {
    [168] = '�', [184] = '�', [192] = '�', [193] = '�', [194] = '�', [195] = '�', [196] = '�', [197] = '�', [198] = '�', [199] = '�', [200] = '�', [201] = '�', [202] = '�', [203] = '�', [204] = '�', [205] = '�', [206] = '�', [207] = '�', [208] = '�', [209] = '�', [210] = '�', [211] = '�', [212] = '�', [213] = '�', [214] = '�', [215] = '�', [216] = '�', [217] = '�', [218] = '�', [219] = '�', [220] = '�', [221] = '�', [222] = '�', [223] = '�', [224] = '�', [225] = '�', [226] = '�', [227] = '�', [228] = '�', [229] = '�', [230] = '�', [231] = '�', [232] = '�', [233] = '�', [234] = '�', [235] = '�', [236] = '�', [237] = '�', [238] = '�', [239] = '�', [240] = '�', [241] = '�', [242] = '�', [243] = '�', [244] = '�', [245] = '�', [246] = '�', [247] = '�', [248] = '�', [249] = '�', [250] = '�', [251] = '�', [252] = '�', [253] = '�', [254] = '�', [255] = '�',
}
function string.rlower(s)
    s = s:lower()
    local strlen = s:len()
    if strlen == 0 then return s end
    s = s:lower()
    local output = ''
    for i = 1, strlen do
        local ch = s:byte(i)
        if ch >= 192 and ch <= 223 then -- upper russian characters
            output = output .. russian_characters[ch + 32]
        elseif ch == 168 then -- �
            output = output .. russian_characters[184]
        else
            output = output .. string.char(ch)
        end
    end
    return output
end
function string.rupper(s)
    s = s:upper()
    local strlen = s:len()
    if strlen == 0 then return s end
    s = s:upper()
    local output = ''
    for i = 1, strlen do
        local ch = s:byte(i)
        if ch >= 224 and ch <= 255 then -- lower russian characters
            output = output .. russian_characters[ch - 32]
        elseif ch == 184 then -- �
            output = output .. russian_characters[168]
        else
            output = output .. string.char(ch)
        end
    end
    return output
end
function TranslateNick(name)
	if name:match('%a+') then
        for k, v in pairs({['ph'] = '�',['Ph'] = '�',['Ch'] = '�',['ch'] = '�',['Th'] = '�',['th'] = '�',['Sh'] = '�',['sh'] = '�', ['ea'] = '�',['Ae'] = '�',['ae'] = '�',['size'] = '����',['Jj'] = '��������',['Whi'] = '���',['lack'] = '���',['whi'] = '���',['Ck'] = '�',['ck'] = '�',['Kh'] = '�',['kh'] = '�',['hn'] = '�',['Hen'] = '���',['Zh'] = '�',['zh'] = '�',['Yu'] = '�',['yu'] = '�',['Yo'] = '�',['yo'] = '�',['Cz'] = '�',['cz'] = '�', ['ia'] = '�', ['ea'] = '�',['Ya'] = '�', ['ya'] = '�', ['ove'] = '��',['ay'] = '��', ['rise'] = '����',['oo'] = '�', ['Oo'] = '�', ['Ee'] = '�', ['ee'] = '�', ['Un'] = '��', ['un'] = '��', ['Ci'] = '��', ['ci'] = '��', ['yse'] = '��', ['cate'] = '����', ['eow'] = '��', ['rown'] = '����', ['yev'] = '���', ['Babe'] = '�����', ['Jason'] = '�������', ['liy'] = '���', ['ane'] = '���', ['ame'] = '���'}) do
            name = name:gsub(k, v) 
        end
		for k, v in pairs({['B'] = '�',['Z'] = '�',['T'] = '�',['Y'] = '�',['P'] = '�',['J'] = '��',['X'] = '��',['G'] = '�',['V'] = '�',['H'] = '�',['N'] = '�',['E'] = '�',['I'] = '�',['D'] = '�',['O'] = '�',['K'] = '�',['F'] = '�',['y`'] = '�',['e`'] = '�',['A'] = '�',['C'] = '�',['L'] = '�',['M'] = '�',['W'] = '�',['Q'] = '�',['U'] = '�',['R'] = '�',['S'] = '�',['zm'] = '���',['h'] = '�',['q'] = '�',['y'] = '�',['a'] = '�',['w'] = '�',['b'] = '�',['v'] = '�',['g'] = '�',['d'] = '�',['e'] = '�',['z'] = '�',['i'] = '�',['j'] = '�',['k'] = '�',['l'] = '�',['m'] = '�',['n'] = '�',['o'] = '�',['p'] = '�',['r'] = '�',['s'] = '�',['t'] = '�',['u'] = '�',['f'] = '�',['x'] = 'x',['c'] = '�',['``'] = '�',['`'] = '�',['_'] = ' '}) do
            name = name:gsub(k, v) 
        end
        return name
    end
	return name
end
function isParamSampID(id)
	id = tonumber(id)
	if id ~= nil and tostring(id):find('%d') and not tostring(id):find('%D') and string.len(id) >= 1 and string.len(id) <= 3 then
		if id == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) then
			return true
		elseif sampIsPlayerConnected(id) then
			return true
		else
			return false
		end
	else
		return false
	end
end