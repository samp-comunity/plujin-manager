script_name("Cipher")
script_author("_vxnzz")
script_version("1.0")
script_description("Un mod menu con varios chetos")

local imgui = require("mimgui")
local addons = require("ADDONS")
local sf = require('sampfuncs')
local sampEvents = require('samp.events')
local check_sampev, sampev = pcall(require, "samp.events")
local gtasaweapons = require("gtasaweapons")
local widgets = require("widgets")
local fa = require("fAwesome6_solid")
local inicfg = require("inicfg")
local ffi = require("ffi")
local gta = ffi.load("GTASA")
local hook = require('monethook')
local vec3 = require("vector3d")
local SaMemory = require("SAMemory")
SaMemory.require("CCamera")
local Camera = SaMemory.camera

---------------------- [ cfg ]----------------------
local configFile  = "Cipher.ini"
local configData = inicfg.load({
	main = {
		aimbot = false,
		aimbot_circle = false
	},
	weapons = {
		buttonSize = 55
	}, 
	settings = {
		theme = 0,
		style = 0,
		autosave = true,
		imguiItemsScale = 0.84,
		notification = true,
		showmenubutton = true,
		menubutton_x = 30,
		menubutton_y = 250,
		menubutton_w = 60,
		menubutton_h = 40
	}, 
	colors = {
		color1 = 1
	},
	commands = {
		openmenu = "/cipher",
		aimbot = "/aim",
		kill = "/matar",
		crazyanim = "/crvx",
		spinneranim = "/rot",
		bypass = "/bypass",
		giveweapon = "/arma",
		respawncar = "/respawn",
		fcrash = "/fcrash"
	}
}, configFile )
inicfg.save(configData, configFile )

function openLink(url)
	gta._Z12AND_OpenLinkPKc(url)
end

function fileExists(filePath)
	local file = io.open(filePath, "r")
	
	if file then
		io.close(file)
		
		return true
	else
		return false
	end
end

function msg(text)
   if configData.settings.notification then
        return sampAddChatMessage(text, -1)
    end
end

function doSave()
    if configData.settings.autosave then
        inicfg.save(configData, configFile)
    end
end

local imguiNew = imgui.new

-------------------------- [window] --------------------------
local toggleMenu = imguiNew.bool(false)
local showMenuButton = imguiNew.bool(configData.settings.showmenubutton)
local toggleButtonSettings = imgui.new.bool(false)
local settingsSubPage = imguiNew.int(0)
local menuConfig = {
	opened = imguiNew .bool(false),
	selected = {
		[0] = " Cheats"
	},
	tabs = {
		[fa.PERSON_RIFLE] = " Weapon ",
		[fa.GEAR] = " Settings",
		[fa.KEYBOARD] = " Commands",
		[fa.CROSSHAIRS] = " Aimbot",
		[fa.SKULL] = " Cheats"
	}
}

-------------------------- [sliders] --------------------------
local sliders = {
	opacityLevel = imguiNew.float(1),
	fontSizeScale = imguiNew.float(configData.settings.imguiItemsScale),
	slider_buttonSize = imguiNew.int(configData.weapons.buttonSize),
	buttonPosX = imguiNew.int(configData.settings.menubutton_x),
	buttonPosY = imguiNew.int(configData.settings.menubutton_y),
	buttonWidth = imguiNew.int(configData.settings.menubutton_w),
	buttonHeight = imguiNew.int(configData.settings.menubutton_h)
}

--------------------------- [checkboxes] ---------------------------
local checkboxes = {
	notification_checkbox = imguiNew.bool(configData.settings.notification),
	menubutton_checkbox = imguiNew.bool(configData.settings.showmenubutton),
	toggleAimbot = imguiNew.bool(configData.main.aimbot),
	aimbotFovCircle = imguiNew.bool(configData.main.aimbot_circle)
}

-------------------------- [buffer] --------------------------
local buffers = {
	cmd_openmenu = imguiNew.char[128](configData.commands.openmenu),
	cmd_aimbot = imguiNew.char[128](configData.commands.aimbot),
	cmd_kill = imguiNew.char[128](configData.commands.kill),
	cmd_crazyanim = imguiNew.char[128](configData.commands.crazyanim),
	cmd_spinneranim = imguiNew.char[128](configData.commands.spinneranim),
	cmd_bypass = imguiNew.char[128](configData.commands.bypass),
	cmd_giveweapon = imguiNew.char[128](configData.commands.giveweapon),
	cmd_respawncar = imguiNew.char[128](configData.commands.respawncar),
	cmd_fcrash = imguiNew.char[128](configData.commands.fcrash)
}

local script_name = "{73b461}[Cipher]"
local selectedTab = 1
local colorListNumber = imguiNew.int(configData.settings.theme)
local colorList = {"Rojo","Verde","Azul", "Oscuro", "Cian", "Morado Neon", "Cyberpunk"}
local colorListBuffer = imguiNew["const char*"][#colorList](colorList)
local styleList = {"Base", "Moderno", "TechEdge"}
local styleListNumber = imguiNew.int(configData.settings.style)
local styleListBuffer = imguiNew["const char*"][#styleList](styleList)

  ---------------------- [FFI]----------------------
ffi.cdef[[
	typedef struct RwRect RwRect;
	typedef struct RwCamera RwCamera;
	void _Z10CameraSizeP8RwCameraP6RwRectff(RwCamera *camera, RwRect *rect, float unk, float aspect);
    float _ZN7CCamera22m_f3rdPersonCHairMultXE;
    float _ZN7CCamera22m_f3rdPersonCHairMultYE;
    void _ZN4CHud14DrawCrossHairsEv();
    void _Z12AND_OpenLinkPKc(const char* link);
	float AIMWEAPON_STICK_SENS;
]]

--------[WEAPON MENU - BYPASS & CONEXIÓN]--------
local weapons = {
    22, 23, 24,
    25, 26, 27,
    28, 29, 32,
    30, 31,
    33, 34,
    35, 36, 37, 38,
    16, 17, 18, 39, 40, 41, 42, 43, 46
}

local bypass = false
local weaponFont

local isConnected = false
local lastPacketTime = os.clock()
local DISCONNECT_TIMEOUT = 10

local PACKET_DISCONNECTION_NOTIFICATION = 32
local PACKET_CONNECTION_LOST = 33
local PACKET_CONNECTION_BANNED = 36

---------------------- [Button Menu]----------------------
local floatingButtonFrame = imgui.OnFrame(function()
    return showMenuButton[0] and not isGamePaused()
end, function()
    imgui.SetNextWindowPos(imgui.ImVec2(configData.settings.menubutton_x, configData.settings.menubutton_y), imgui.Cond.Always)
	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(4, 4))
	imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(6, 4))

    imgui.Begin("##botonAbrirMenu", nil, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize)

    if imgui.Button(fa.SKULL .. "", imgui.ImVec2(configData.settings.menubutton_w, configData.settings.menubutton_h)) then
        toggleMenu[0] = not toggleMenu[0]
    end

    imgui.End()
end)

local buttonSettingsMenuFrame = imgui.OnFrame(function()
    return toggleButtonSettings[0]
end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(400, 320), imgui.Cond.FirstUseEver)
    imgui.PushFont(font1)
    imgui.Begin("Botón flotante", toggleButtonSettings, imgui.WindowFlags.AlwaysAutoResize)
    imgui.PopFont()

    imgui.Dummy(imgui.ImVec2(0, 10))

    local paddingX = 20
    local winWidth = imgui.GetWindowSize().x
    local contentWidth = winWidth - (paddingX * 2)

    if checkboxes.menubutton_checkbox[0] then
        local screenX, screenY = getScreenResolution()
        imgui.PushFont(font2)

        imgui.SetCursorPosX(paddingX)
        imgui.Separator()

        imgui.SetCursorPosX(paddingX)
        imgui.Text("Posición del botón:")

        imgui.SetCursorPosX(paddingX)
        if imgui.SliderInt("X", sliders.buttonPosX, 0, screenX - 50) then
            configData.settings.menubutton_x = sliders.buttonPosX[0]
            doSave()
        end

        imgui.SetCursorPosX(paddingX)
        if imgui.SliderInt("Y", sliders.buttonPosY, 0, screenY - 50) then
            configData.settings.menubutton_y = sliders.buttonPosY[0]
            doSave()
        end

        imgui.SetCursorPosX(paddingX)
        imgui.Separator()

        imgui.SetCursorPosX(paddingX)
        imgui.Text("Tamaño del botón:")

        imgui.SetCursorPosX(paddingX)
        if imgui.SliderInt("Ancho  ", sliders.buttonWidth, 50, 300) then
            configData.settings.menubutton_w = sliders.buttonWidth[0]
            doSave()
        end

        imgui.SetCursorPosX(paddingX)
        if imgui.SliderInt("Alto", sliders.buttonHeight, 40, 150) then
            configData.settings.menubutton_h = sliders.buttonHeight[0]
            doSave()
        end

        imgui.PopFont()
    end

    imgui.Dummy(imgui.ImVec2(0, 10))

    imgui.PushFont(nil)
    imgui.End()
end)



---------------------- [Main Menu]----------------------
local mainMenuFrame = imgui.OnFrame(function()
	return toggleMenu[0]
	end, function(arg_12_0)
	local screenWidth, screenHeight = getScreenResolution()
	local menuWidth = 1266
	local menuHeight = 775

	imgui.GetStyle().Alpha = sliders.opacityLevel[0]

	imgui.SetNextWindowSize(imgui.ImVec2(menuWidth, menuHeight), imgui.Cond.FirstUseEver)
	imgui.BeginWin11Menu(" ", toggleMenu, false, menuConfig.tabs, menuConfig.selected, menuConfig.opened, 90, 130)
	imgui.SetWindowFontScale(sliders.fontSizeScale[0])

	local windowSize = imgui.GetWindowSize()
	imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
	addons.CloseButton("##closemenu", toggleMenu, 33, 5)
	
	if menuConfig.selected[0] == " Weapon " then
		imgui.PushFont(font1)
		imgui.SetCursorPosY(18)
		imgui.Spacing()
		imgui.Spacing()
		imgui.Text("Armas & ByPass")
		imgui.PopFont()
		imgui.SetCursorPosY(90)
		imgui.BeginChild("##MainScroll", imgui.ImVec2(-1), true, imgui.WindowFlags.AlwaysVerticalScrollbar)
		imgui.PushFont(font2)

		local buttonSize = sliders.slider_buttonSize[0]
		local spacing = 6

		local availableWidth = imgui.GetContentRegionAvail().x
		local buttonsPerRow = math.floor((availableWidth + spacing) / (buttonSize + spacing))
		if buttonsPerRow < 1 then buttonsPerRow = 1 end
		local totalRowWidth = buttonsPerRow * buttonSize + (buttonsPerRow - 1) * spacing
		local horizontalPadding = (availableWidth - totalRowWidth) * 0.5

		local currentCol = 0
		imgui.SetCursorPosX(horizontalPadding)

		for i, weaponId in ipairs(weapons) do
			local icon = getWeaponIcon(weaponId)
			if icon then
				if currentCol > 0 then
					imgui.SameLine(0, spacing)
				end

				if weaponFont then imgui.PushFont(weaponFont) end

				if imgui.Button(icon .. "##" .. weaponId, imgui.ImVec2(buttonSize, buttonSize)) then
					giveWeaponById(weaponId)
				end

				if weaponFont then imgui.PopFont() end

				if imgui.IsItemHovered() then
					imgui.SetTooltip("ID: " .. weaponId)
				end

				currentCol = currentCol + 1
				if currentCol >= buttonsPerRow then
					currentCol = 0
					imgui.NewLine()
					imgui.SetCursorPosX(horizontalPadding)
				end
			end
		end

		imgui.NewLine()

		local bypassText = bypass and "Bypass: ON" or "Bypass: OFF"
		local bypassColor = bypass and imgui.ImVec4(0.2, 0.8, 0.2, 1) or imgui.ImVec4(0.8, 0.2, 0.2, 1)

		local fullWidth = imgui.GetWindowSize().x
		local bypassButtonWidth = 320
		local buttonX = (fullWidth - bypassButtonWidth) * 0.5
		imgui.SetCursorPosX(buttonX)

		imgui.PushStyleColor(imgui.Col.Button, bypassColor)
		imgui.PushStyleColor(imgui.Col.ButtonHovered, bypassColor)
		imgui.PushStyleColor(imgui.Col.ButtonActive, bypassColor)

		if imgui.Button(bypassText, imgui.ImVec2(bypassButtonWidth, 50)) then
			bypassweapon()
		end

		imgui.PopStyleColor(3)
		imgui.NewLine()
		imgui.Separator()
		
		imgui.NewLine()
		imgui.Text("Tamaño de los botones")
		imgui.PushItemWidth(-1)
		if imgui.SliderInt("##btnsize", sliders.slider_buttonSize, 30, 100, "%.2f") then 
			configData.weapons.buttonSize = sliders.slider_buttonSize[0]
			doSave()
		end
		imgui.PopItemWidth()
		imgui.PopFont()
		imgui.Spacing()
		
		imgui.EndChild()

		elseif menuConfig.selected[0] == " Settings" then
			imgui.PushFont(font1)
			imgui.SetCursorPosY(18)
			imgui.Text("Configuración")
			imgui.SetCursorPosY(90)
			imgui.Spacing()
			local fullWidth = imgui.GetContentRegionAvail().x
			local halfWidth = fullWidth / 2
			local buttonHeight = 35

			if settingsSubPage[0] == 0 then
				if imgui.Button("Ajustes", imgui.ImVec2(halfWidth, buttonHeight)) then
					settingsSubPage[0] = 0
				end
			else
				imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0)) -- fondo invisible
				imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0)) -- sin efecto hover
				if imgui.Button("Ajustes", imgui.ImVec2(halfWidth, buttonHeight)) then
					settingsSubPage[0] = 0
				end
				imgui.PopStyleColor(2)
			end
			
			imgui.SameLine()
			
			if settingsSubPage[0] == 1 then
				if imgui.Button("Interfaz", imgui.ImVec2(halfWidth, buttonHeight)) then
					settingsSubPage[0] = 1
				end
			else
				imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0)) -- fondo invisible
				imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0, 0, 0, 0)) -- sin efecto hover
				if imgui.Button("Interfaz", imgui.ImVec2(halfWidth, buttonHeight)) then
					settingsSubPage[0] = 1
				end
				imgui.PopStyleColor(2)
			end
		
			imgui.PopFont()
			imgui.PushFont(font2)
		
			if settingsSubPage[0] == 0 then
				imgui.Spacing()
				imgui.TextDisabled("Opacidad")
				imgui.PushItemWidth(-1)
				imgui.SliderFloat("##alpha", sliders.opacityLevel, 0.1, 1, "%.2f")
				imgui.Spacing()
				imgui.Spacing()
				imgui.TextDisabled("Tamaño de los items")
				if imgui.SliderFloat("##imguiItemsScale", sliders.fontSizeScale, 0.5, 1, "%.2f") then 
					configData.settings.imguiItemsScale = sliders.fontSizeScale[0]
					doSave()
				end
				imgui.Spacing()
				imgui.Spacing()

				local maxX = imgui.GetWindowContentRegionMax().x
				local cursorX = imgui.GetCursorPosX()
				local totalWidth = maxX - cursorX
				if not totalWidth or totalWidth <= 0 then totalWidth = 300 end

				local temaWidth = totalWidth * 0.66
				local aspectoWidth = totalWidth * 0.34

				-- Grupo: Seleccionar tema
				imgui.BeginGroup()
					imgui.AlignTextToFramePadding() -- Alinea verticalmente con combo
					imgui.TextDisabled("Seleccionar tema")
					imgui.PushItemWidth(temaWidth)
					imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(5, 15))
					if imgui.Combo("##tema", colorListNumber, colorListBuffer, #colorList) then
						configData.settings.theme = colorListNumber[0]
						doSave()
						local themeIndex = colorListNumber[0] + 1
						if theme[themeIndex] and theme[themeIndex].change then
							theme[themeIndex].change()
						end
					end
					imgui.PopStyleVar()
					imgui.PopItemWidth()
				imgui.EndGroup()

				imgui.SameLine()

				-- Grupo: Seleccionar aspecto
				imgui.BeginGroup()
					imgui.AlignTextToFramePadding() -- Alinea verticalmente con combo
					imgui.TextDisabled("Estilo de Interfaz")
					imgui.PushItemWidth(aspectoWidth)
					imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(5, 15))
					if imgui.Combo("##aspecto", styleListNumber, styleListBuffer, #styleList) then
						configData.settings.style = styleListNumber[0]
						doSave()

						local styleIndex = styleListNumber[0] + 1
						if style[styleIndex] and style[styleIndex].change then
							style[styleIndex].change()
						end
					end
					imgui.PopStyleVar()
					imgui.PopItemWidth()
				imgui.EndGroup()

				imgui.SetCursorPosY(windowSize.y - 35)
				imgui.PopFont()
				imgui.PushFont(font1)
				imgui.Text("Autor:")
				imgui.SameLine()
				imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.0, 1.0, 0.6, 1))
				imgui.Text("_vxnzz")
				imgui.PopStyleColor()
			
				if imgui.IsItemClicked() then
					openLink("https://discord.gg/PSJT2SX7fh")
				end
				
				if not configData.settings.autosave then
					imgui.PushFont(nil)
					imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 181, windowSize.y - 70))
					if imgui.Button(fa.FLOPPY_DISK .. "##save", imgui.ImVec2(60, 50)) then
						inicfg.save(configData, configFile)
						msg(script_name .. "{FFFFFF} Configuracion guardada.")
					end
					imgui.PopFont()
				end

				imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 116, windowSize.y - 70))
				imgui.PushFont(nil)
				if imgui.Button(fa.ROTATE_RIGHT .. "##reload", imgui.ImVec2(60, 50)) then
					thisScript():reload()
				end

			else
				imgui.Spacing()
				if imgui.Checkbox("Notificaciones en el chat", checkboxes.notification_checkbox) then
					configData.settings.notification = checkboxes.notification_checkbox[0]
					doSave()
				end	
				imgui.Spacing()
				if imgui.Checkbox("Guardar automáticamente", imguiNew.bool(configData.settings.autosave)) then
					configData.settings.autosave = not configData.settings.autosave
					inicfg.save(configData, configFile)
				end

				imgui.Spacing()

				if imgui.Checkbox("Mostrar botón flotante del menú", checkboxes.menubutton_checkbox) then
					configData.settings.showmenubutton = checkboxes.menubutton_checkbox[0]
					showMenuButton[0] = checkboxes.menubutton_checkbox[0]
					doSave()
				end

				if checkboxes.menubutton_checkbox[0] then
					imgui.Spacing()
					if imgui.Button("Configurar botón flotante", imgui.ImVec2(-1, 35)) then
						toggleButtonSettings[0] = not toggleButtonSettings[0]
					end
				end
			end

		elseif menuConfig.selected[0] == " Commands" then
		imgui.PushFont(font1)
		imgui.SetCursorPosY(18)
		imgui.Text("Comandos")
		imgui.PopFont()
		imgui.PushFont(font2)
		imgui.SetCursorPosY(90)
		imgui.BeginChild("##MainScroll", imgui.ImVec2(-1), true, imgui.WindowFlags.AlwaysVerticalScrollbar)
		imgui.Spacing()
		imgui.Spacing()
		imgui.PushItemWidth(120)

		local function drawCommandInput(label, buffer, configKey)
			if imgui.InputText(label, buffer, ffi.sizeof(buffer)) then
				configData.commands[configKey] = ffi.string(buffer)
				doSave()
				reloadCommands()
			end

			if ffi.string(buffer):sub(1, 1) ~= "/" then
				imgui.SameLine()
			
				imgui.PushFont(nil)  
				imgui.TextColored(imgui.ImVec4(1, 0, 0, 1), "") 
				imgui.PopFont()
				imgui.SameLine()
				imgui.PushFont(font2)  
				imgui.TextColored(imgui.ImVec4(1, 0, 0, 1), "debe empezar con /")
				imgui.PopFont()
			end
			
			imgui.Spacing()
			imgui.Spacing()
		end

		drawCommandInput(" Comando para abrir el mod menú", buffers.cmd_openmenu, "openmenu")
		drawCommandInput(" Activar/desactivar Aimbot", buffers.cmd_aimbot, "aimbot")
		drawCommandInput(" Comando para matar", buffers.cmd_kill, "kill")
		drawCommandInput(" Animacion deformacion", buffers.cmd_crazyanim, "crazyanim")
		drawCommandInput(" Animacion de Spinner", buffers.cmd_spinneranim, "spinneranim")
		drawCommandInput(" Activar/descactivar bypass", buffers.cmd_bypass, "bypass")
		drawCommandInput(" Dar arma", buffers.cmd_giveweapon, "giveweapon")
		drawCommandInput(" Desaparece/destruye todos los vehiculos", buffers.cmd_respawncar, "respawncar")
		drawCommandInput(" Crashear a los negroides", buffers.cmd_fcrash, "fcrash")
	
		imgui.PopItemWidth()
		
		elseif menuConfig.selected[0] == " Aimbot" then
		imgui.PushFont(font1)
		imgui.SetCursorPosY(18)
		imgui.Text("Aimbot")
		imgui.PopFont()
		imgui.PushFont(font2)
		imgui.SetCursorPosY(90)

		if imgui.Checkbox("Activar Aimbot", checkboxes.toggleAimbot) then
			configData.main.aimbot = checkboxes.toggleAimbot[0]
			doSave()
		end
		imgui.TextDisabled("En proceso...")

		imgui.Spacing()
		imgui.Spacing()

		
		elseif menuConfig.selected[0] == " Cheats" then
		imgui.PushFont(font1)
		imgui.SetCursorPosY(18)
		imgui.Text("Cheats")
		imgui.PopFont()
		imgui.PushFont(font2)
		imgui.SetCursorPosY(90)
		imgui.BeginChild("##MainScroll", imgui.ImVec2(-1), true, imgui.WindowFlags.AlwaysVerticalScrollbar)
		imgui.TextDisabled("En proceso...")
		imgui.Spacing()
		imgui.Separator()
	
		imgui.EndChild()
	
	end

	imgui.EndWin11Menu()
end)

----------------------------------------------------- [Functions] ----------------------------------------------------------

--------[FCRASH]--------

local isCrasherEnabled = false
local isSpectatorModeEnabled = false
local toggleCrasherCommand = false
local spectateTargetId = false
local isRpcBlockerEnabled = false
local crasherSyncToggle = false

function toggleCrasherCommand()
	isCrasherEnabled = not isCrasherEnabled

	if isRpcBlockerEnabled then
		msg(script_name .. " {ff0000}[Fcrash] {ffffff} Desactivado.")

		isRpcBlockerEnabled = false
	else
		msg(script_name .. " {ff0000}[Fcrash] {ffffff} Activado.")

		isRpcBlockerEnabled = true
	end
end

function onReceiveRpc(rpcId, bitstream)
	if isRpcBlockerEnabled and rpcId == 13 then
		return false
	end

	if isRpcBlockerEnabled and rpcId == 87 then
		return false
	end
end

function sampEvents.onSendPlayerSync(syncData)
	if isCrasherEnabled then
		isSpectatorModeEnabled = not isSpectatorModeEnabled
		samp_create_sync_data("aim").camMode = 0
	end

	if isSpectatorModeEnabled then
		sendSpectator(spectateTargetId)
	end

	if isCrasherEnabled then
		crasherSyncToggle = not crasherSyncToggle

		if crasherSyncToggle then
			local playerSync = samp_create_sync_data("player")

			playerSync.weapon = 40
			playerSync.keysData = 128

			playerSync.send()
			printStringNow("~r~Jugador Crasheado", 500)

			return false
		end
	end
end

function sendSpectator(playerId)
	if isSpectatorModeEnabled then
		local aimSync = samp_create_sync_data("aim")

		aimSync.camMode = 51

		aimSync.send()
	end
end

function samp_create_sync_data(syncType, targetId)
	local raknet = require("samp.raknet")

	targetId = targetId or true

	local syncDataConfig = ({
		player = {
			"PlayerSyncData",
			raknet.PACKET.PLAYER_SYNC,
			sampStorePlayerOnfootData
		},
		vehicle = {
			"VehicleSyncData",
			raknet.PACKET.VEHICLE_SYNC,
			sampStorePlayerIncarData
		},
		passenger = {
			"PassengerSyncData",
			raknet.PACKET.PASSENGER_SYNC,
			sampStorePlayerPassengerData
		},
		aim = {
			"AimSyncData",
			raknet.PACKET.AIM_SYNC,
			sampStorePlayerAimData
		},
		trailer = {
			"TrailerSyncData",
			raknet.PACKET.TRAILER_SYNC,
			sampStorePlayerTrailerData
		},
		unoccupied = {
			"UnoccupiedSyncData",
			raknet.PACKET.UNOCCUPIED_SYNC
		},
		bullet = {
			"BulletSyncData",
			raknet.PACKET.BULLET_SYNC
		},
		spectator = {
			"SpectatorSyncData",
			raknet.PACKET.SPECTATOR_SYNC
		}
	})[syncType]
	local syncStructName = "struct " .. syncDataConfig[1]
	local syncStruct = ffi.new(syncStructName, {})
	local syncStructPtr = tonumber(ffi.cast("uintptr_t", ffi.new(syncStructName .. "*", syncStruct)))

	if targetId then
		local syncStoreFunction = syncDataConfig[3]

		if syncStoreFunction then
			local resolvedPlayerId

			if targetId == true then
				local unused_charHandle

				unused_charHandle, resolvedPlayerId = sampGetPlayerIdByCharHandle(PLAYER_PED)
			else
				resolvedPlayerId = tonumber(targetId)
			end

			syncStoreFunction(resolvedPlayerId, syncStructPtr)
		end
	end

	local function sendFunction()
		local bitstream = raknetNewBitStream()

		raknetBitStreamWriteInt8(bitstream, syncDataConfig[2])
		raknetBitStreamWriteBuffer(bitstream, syncStructPtr, ffi.sizeof(syncStruct))
		raknetSendBitStreamEx(bitstream, sf.HIGH_PRIORITY, sf.UNRELIABLE_SEQUENCED, 1)
		raknetDeleteBitStream(bitstream)
	end

	local syncMetatable = {
		__index = function(self, key)
			return syncStruct[key]
		end,
		__newindex = function(self, key, value)
			syncStruct[key] = value
		end
	}

	return setmetatable({
		send = sendFunction
	}, syncMetatable)
end

function emul_rpc(eventName, params)
	local bitstreamIo = require("samp.events.bitstream_io")
	local customWriters = require("samp.events.handlers")
	local extraTypes = require("samp.events.extra_types")
	local rpcSchemas = {
		onInitGame = {
			139
		},
		onPlayerJoin = {
			"int16",
			"int32",
			"bool8",
			"string8",
			137
		},
		onPlayerQuit = {
			"int16",
			"int8",
			138
		},
		onRequestClassResponse = {
			"bool8",
			"int8",
			"int32",
			"int8",
			"vector3d",
			"float",
			"Int32Array3",
			"Int32Array3",
			128
		},
		onRequestSpawnResponse = {
			"bool8",
			129
		},
		onSetPlayerName = {
			"int16",
			"string8",
			"bool8",
			11
		},
		onSetPlayerPos = {
			"vector3d",
			12
		},
		onSetPlayerPosFindZ = {
			"vector3d",
			13
		},
		onSetPlayerHealth = {
			"float",
			14
		},
		onTogglePlayerControllable = {
			"bool8",
			15
		},
		onPlaySound = {
			"int32",
			"vector3d",
			16
		},
		onSetWorldBounds = {
			"float",
			"float",
			"float",
			"float",
			17
		},
		onGivePlayerMoney = {
			"int32",
			18
		},
		onSetPlayerFacingAngle = {
			"float",
			19
		},
		onGivePlayerWeapon = {
			"int32",
			"int32",
			22
		},
		onSetPlayerTime = {
			"int8",
			"int8",
			29
		},
		onSetToggleClock = {
			"bool8",
			30
		},
		onPlayerStreamIn = {
			"int16",
			"int8",
			"int32",
			"vector3d",
			"float",
			"int32",
			"int8",
			32
		},
		onSetShopName = {
			"string256",
			33
		},
		onSetPlayerSkillLevel = {
			"int16",
			"int32",
			"int16",
			34
		},
		onSetPlayerDrunk = {
			"int32",
			35
		},
		onCreate3DText = {
			"int16",
			"int32",
			"vector3d",
			"float",
			"bool8",
			"int16",
			"int16",
			"encodedString4096",
			36
		},
		onSetRaceCheckpoint = {
			"int8",
			"vector3d",
			"vector3d",
			"float",
			38
		},
		onPlayAudioStream = {
			"string8",
			"vector3d",
			"float",
			"bool8",
			41
		},
		onRemoveBuilding = {
			"int32",
			"vector3d",
			"float",
			43
		},
		onCreateObject = {
			44
		},
		onSetObjectPosition = {
			"int16",
			"vector3d",
			45
		},
		onSetObjectRotation = {
			"int16",
			"vector3d",
			46
		},
		onDestroyObject = {
			"int16",
			47
		},
		onPlayerDeathNotification = {
			"int16",
			"int16",
			"int8",
			55
		},
		onSetMapIcon = {
			"int8",
			"vector3d",
			"int8",
			"int32",
			"int8",
			56
		},
		onRemoveVehicleComponent = {
			"int16",
			"int16",
			57
		},
		onRemove3DTextLabel = {
			"int16",
			58
		},
		onPlayerChatBubble = {
			"int16",
			"int32",
			"float",
			"int32",
			"string8",
			59
		},
		onUpdateGlobalTimer = {
			"int32",
			60
		},
		onShowDialog = {
			"int16",
			"int8",
			"string8",
			"string8",
			"string8",
			"encodedString4096",
			61
		},
		onDestroyPickup = {
			"int32",
			63
		},
		onLinkVehicleToInterior = {
			"int16",
			"int8",
			65
		},
		onSetPlayerArmour = {
			"float",
			66
		},
		onSetPlayerArmedWeapon = {
			"int32",
			67
		},
		onSetSpawnInfo = {
			"int8",
			"int32",
			"int8",
			"vector3d",
			"float",
			"Int32Array3",
			"Int32Array3",
			68
		},
		onSetPlayerTeam = {
			"int16",
			"int8",
			69
		},
		onPutPlayerInVehicle = {
			"int16",
			"int8",
			70
		},
		onSetPlayerColor = {
			"int16",
			"int32",
			72
		},
		onDisplayGameText = {
			"int32",
			"int32",
			"string32",
			73
		},
		onAttachObjectToPlayer = {
			"int16",
			"int16",
			"vector3d",
			"vector3d",
			75
		},
		onInitMenu = {
			76
		},
		onShowMenu = {
			"int8",
			77
		},
		onHideMenu = {
			"int8",
			78
		},
		onCreateExplosion = {
			"vector3d",
			"int32",
			"float",
			79
		},
		onShowPlayerNameTag = {
			"int16",
			"bool8",
			80
		},
		onAttachCameraToObject = {
			"int16",
			81
		},
		onInterpolateCamera = {
			"bool",
			"vector3d",
			"vector3d",
			"int32",
			"int8",
			82
		},
		onGangZoneStopFlash = {
			"int16",
			85
		},
		onApplyPlayerAnimation = {
			"int16",
			"string8",
			"string8",
			"bool",
			"bool",
			"bool",
			"bool",
			"int32",
			86
		},
		onClearPlayerAnimation = {
			"int16",
			87
		},
		onSetPlayerSpecialAction = {
			"int8",
			88
		},
		onSetPlayerFightingStyle = {
			"int16",
			"int8",
			89
		},
		onSetPlayerVelocity = {
			"vector3d",
			90
		},
		onSetVehicleVelocity = {
			"bool8",
			"vector3d",
			91
		},
		onServerMessage = {
			"int32",
			"string32",
			93
		},
		onSetWorldTime = {
			"int8",
			94
		},
		onCreatePickup = {
			"int32",
			"int32",
			"int32",
			"vector3d",
			95
		},
		onMoveObject = {
			"int16",
			"vector3d",
			"vector3d",
			"float",
			"vector3d",
			99
		},
		onEnableStuntBonus = {
			"bool",
			104
		},
		onTextDrawSetString = {
			"int16",
			"string16",
			105
		},
		onSetCheckpoint = {
			"vector3d",
			"float",
			107
		},
		onCreateGangZone = {
			"int16",
			"vector2d",
			"vector2d",
			"int32",
			108
		},
		onPlayCrimeReport = {
			"int16",
			"int32",
			"int32",
			"int32",
			"int32",
			"vector3d",
			112
		},
		onGangZoneDestroy = {
			"int16",
			120
		},
		onGangZoneFlash = {
			"int16",
			"int32",
			121
		},
		onStopObject = {
			"int16",
			122
		},
		onSetVehicleNumberPlate = {
			"int16",
			"string8",
			123
		},
		onTogglePlayerSpectating = {
			"bool32",
			124
		},
		onSpectatePlayer = {
			"int16",
			"int8",
			126
		},
		onSpectateVehicle = {
			"int16",
			"int8",
			127
		},
		onShowTextDraw = {
			134
		},
		onSetPlayerWantedLevel = {
			"int8",
			133
		},
		onTextDrawHide = {
			"int16",
			135
		},
		onRemoveMapIcon = {
			"int8",
			144
		},
		onSetWeaponAmmo = {
			"int8",
			"int16",
			145
		},
		onSetGravity = {
			"float",
			146
		},
		onSetVehicleHealth = {
			"int16",
			"float",
			147
		},
		onAttachTrailerToVehicle = {
			"int16",
			"int16",
			148
		},
		onDetachTrailerFromVehicle = {
			"int16",
			149
		},
		onSetWeather = {
			"int8",
			152
		},
		onSetPlayerSkin = {
			"int32",
			"int32",
			153
		},
		onSetInterior = {
			"int8",
			156
		},
		onSetCameraPosition = {
			"vector3d",
			157
		},
		onSetCameraLookAt = {
			"vector3d",
			"int8",
			158
		},
		onSetVehiclePosition = {
			"int16",
			"vector3d",
			159
		},
		onSetVehicleAngle = {
			"int16",
			"float",
			160
		},
		onSetVehicleParams = {
			"int16",
			"int16",
			"bool8",
			161
		},
		onChatMessage = {
			"int16",
			"string8",
			101
		},
		onConnectionRejected = {
			"int8",
			130
		},
		onPlayerStreamOut = {
			"int16",
			163
		},
		onVehicleStreamIn = {
			164
		},
		onVehicleStreamOut = {
			"int16",
			165
		},
		onPlayerDeath = {
			"int16",
			166
		},
		onPlayerEnterVehicle = {
			"int16",
			"int16",
			"bool8",
			26
		},
		onUpdateScoresAndPings = {
			"PlayerScorePingMap",
			155
		},
		onSetObjectMaterial = {
			84
		},
		onSetObjectMaterialText = {
			84
		},
		onSetVehicleParamsEx = {
			"int16",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			"int8",
			24
		},
		onSetPlayerAttachedObject = {
			"int16",
			"int32",
			"bool",
			"int32",
			"int32",
			"vector3d",
			"vector3d",
			"vector3d",
			"int32",
			"int32",
			113
		}
	}
	local specialRpcWriters = {
		onShowTextDraw = true,
		onSetObjectMaterialText = true,
		onVehicleStreamIn = true,
		onSetObjectMaterial = true,
		onInitMenu = true,
		onInitGame = true,
		onCreateObject = true
	}
	local complexTypes = {
		Int32Array3 = true,
		PlayerScorePingMap = true
	}
	local rpcDefinition = rpcSchemas[eventName]

	if rpcDefinition then
		local bitstream = raknetNewBitStream()

		if not specialRpcWriters[eventName] then
			local paramCount = #rpcDefinition - 1

			if paramCount > 0 then
				for i = 1, paramCount do
					local paramType = rpcDefinition[i]

					if complexTypes[paramType] then
						extraTypes[paramType].write(bitstream, params[i])
					else
						bitstreamIo[paramType].write(bitstream, params[i])
					end
				end
			end
		elseif eventName == "onInitGame" then
			customWriters.on_init_game_writer(bitstream, params)
		elseif eventName == "onCreateObject" then
			customWriters.on_create_object_writer(bitstream, params)
		elseif eventName == "onInitMenu" then
			customWriters.on_init_menu_writer(bitstream, params)
		elseif eventName == "onShowTextDraw" then
			customWriters.on_show_textdraw_writer(bitstream, params)
		elseif eventName == "onVehicleStreamIn" then
			customWriters.on_vehicle_stream_in_writer(bitstream, params)
		elseif eventName == "onSetObjectMaterial" then
			customWriters.on_set_object_material_writer(bitstream, params, 1)
		elseif eventName == "onSetObjectMaterialText" then
			customWriters.on_set_object_material_writer(bitstream, params, 2)
		end

		raknetEmulRpcReceiveBitStream(rpcDefinition[#rpcDefinition], bitstream)
		raknetDeleteBitStream(bitstream)
	end
end



--------[WEAPON MENU - BYPASS & CONEXIÓN]--------

function bypassweapon()
    bypass = not bypass
end

function giveWeaponById(weaponId)
    local modelarma = getWeapontypeModel(weaponId)
    requestModel(modelarma)
    loadAllModelsNow()

    giveWeaponToChar(PLAYER_PED, weaponId, 1000)
    freezeCharPosition(PLAYER_PED, false)
    restoreCameraJumpcut()
    setPlayerControl(PLAYER_HANDLE, true)
end

function getWeaponIcon(weaponId)
    if gtasaweapons then
        local icon = gtasaweapons[weaponId]
        if icon and icon ~= "?" then
            return icon
        end

        if gtasaweapons.get_weapon_icon then
            return gtasaweapons.get_weapon_icon(weaponId)
        end

        if gtasaweapons.min_range and gtasaweapons.max_range and 
           weaponId >= gtasaweapons.min_range and weaponId <= gtasaweapons.max_range then
            return string.char(0xEE, 0xA0, 0x80 + weaponId)
        end
    end
    return nil
end

function removerTodasLasArmas()
    for i = 1, 46 do
        if hasCharGotWeapon(PLAYER_PED, i) then
            removeWeaponFromChar(PLAYER_PED, i)
        end
    end
end

function handleDisconnection()
    if bypass then
        bypass = false
    end
    removerTodasLasArmas()
    isConnected = false
end

function monitorConnection()
    local currentTime = os.clock()

    if sampIsLocalPlayerSpawned() then
        if not isConnected then
            isConnected = true
        end
        lastPacketTime = currentTime
        return
    end

    if isConnected and (currentTime - lastPacketTime) > DISCONNECT_TIMEOUT then
        handleDisconnection()
    end
end

function onReceivePacket(id, bs)
    if id == PACKET_CONNECTION_LOST or id == PACKET_DISCONNECTION_NOTIFICATION or id == PACKET_CONNECTION_BANNED then
        handleDisconnection()
    end
    lastPacketTime = os.clock()
end

function sampEvents.onResetPlayerWeapons()
    if bypass then return false end
end

function sampEvents.onSendGiveDamage()
    if bypass then return false end
end

function sampEvents.onSendVehicleDamaged()
    if bypass then return false end
end

function sampEvents.onClientCheck()
    if bypass then return false end
end

function onReceiveRpc(id)
    if bypass and (id == 115 or id == 67 or id == 21 or id == 139 or id == 22 or id == 145) then
        return false
    end
end

---------------------- [Matar(id)]----------------------
damage = 0
damag = math.random(0,10)
gun = math.random(24,31)

function findPlayer()
    local peds = getAllChars()
    local selectedPed = nil
    local v = 1000000
    for k, ped in pairs(peds) do
        if ped ~= PLAYER_PED and (settings.search.canSee.v and isCharOnScreen(ped) or not settings.search.canSee.v) and not isCharDead(ped) then
            local _, id = sampGetPlayerIdByCharHandle(ped)
            if _ and not sampIsPlayerPaused(id) then
                local cHp = sampGetPlayerHealth(id) + sampGetPlayerArmor(id)
                local x, y, z = getCharCoordinates(ped)
                local mx, my, mz = getCharCoordinates(PLAYER_PED)
                local weapon = getWeaponInfoById(getCurrentCharWeapon(PLAYER_PED))
                if isLineOfSightClear(mx, my, mz, x, y, z, true, not settings.search.ignoreCars.v, false, true, false) and getDistanceBetweenCoords3d(mx, my, mz, x, y, z) < ((settings.search.useWeaponRadius.v and weapon ~= nil and weapon.distance) or settings.search.radius.v) then
                    if settings.search.searchMethod.v == 0 then
                        if cHp < v then
                            v = cHp
                            selectedPed = ped
                        end
                    elseif settings.search.searchMethod.v == 1 then
                        if getDistanceBetweenCoords3d(mx, my, mz, x, y, z) < v then
                            v = getDistanceBetweenCoords3d(mx, my, mz, x, y, z)
                            selectedPed = ped
                        end
                    elseif settings.search.searchMethod.v == 2 then
                        if shootingAtMe == id then
                            --shootingAtMe = -1
                            selectedPed = ped
                            break
                        else
                            if getDistanceBetweenCoords3d(mx, my, mz, x, y, z) < v then
                                v = getDistanceBetweenCoords3d(mx, my, mz, x, y, z)
                                selectedPed = ped
                            end
                        end
                    end
                end
            end
        end
    end
    return selectedPed
end

function brutalKill(palyerid)
    lua_thread.create(function()
        if palyerid ~= "" and palyerid:match("%d") then
            for i = 0, 350 do
                damage = damage + 30000.0
                math.randomseed(os.time()); dw = math.random(3,9)
                sampSendGiveDamage(palyerid, damag, getCurrentCharWeapon(PLAYER_PED), dw)
                wait(10)
            end
            damage = 0
        else
            msg(script_name.." {FFFFFF}Utilice " .. configData.commands.kill .. " (id)")
        end
    end)
end

---------------------- [Anims]----------------------
local crazyAnimState = false
local spinnerAnimState = false

function crazyAnim() 
	crazyAnimState = not crazyAnimState
    if not crazyAnimState then
        clearCharTasks(PLAYER_PED)
    end
end

function sppinerAnim(speed)
    if not isCharOnFoot(PLAYER_PED) then
        msg(script_name .. '{FFFFFF} No estas en pie.', 0xFFFFFF)
        return
    end

    if speed == nil or speed == "" or tonumber(speed) == nil then
        if spinnerAnimState then
            spinnerAnimState = false
            msg(script_name .. '{FFFFFF} Animacion desactivada.', 0xFFFFFF)
        else
            msg(script_name .. '{FFFFFF} Utilice: {00FF00}' .. configData.commands.spinneranim .. ' [1-100]{FFFFFF}.', 0xFFFFFF)
        end
        return
    end

    speedAnim = tonumber(speed)
    if speedAnim > 100 or speedAnim < 1 then
        msg(script_name .. '{FFFFFF} Utilice: {00FF00}' .. configData.commands.spinneranim .. ' [1-100]{FFFFFF}.', 0xFFFFFF)
        return
    end

    -- Activar o actualizar
    if not spinnerAnimState then
        spinnerAnimState = true
        msg(script_name .. '{FFFFFF} Activado - Velocidad: {00FF00}'..speedAnim..'{FFFFFF}.', 0xFFFFFF)
    else
        msg(script_name .. '{FFFFFF} Velocidad actualizada a: {00FF00}'..speedAnim..'{FFFFFF}.', 0xFFFFFF)
    end
end


---------------------- [Commands]----------------------
local lastRegisteredCommands = {}

function registerCommand(command, callback)
    if command:sub(1, 1) ~= "/" then
        return
    end

    local cmd = command:sub(2)
    if lastRegisteredCommands[cmd] then
        sampUnregisterChatCommand(lastRegisteredCommands[cmd])
    end

    sampRegisterChatCommand(cmd, callback)
    lastRegisteredCommands[cmd] = cmd
end

function reloadCommands()
    for cmd, _ in pairs(lastRegisteredCommands) do
        sampUnregisterChatCommand(cmd)
    end
    lastRegisteredCommands = {}  

    registerCommand(ffi.string(buffers.cmd_openmenu), function()
        toggleMenu[0] = not toggleMenu[0]
    end)

	registerCommand(ffi.string(buffers.cmd_kill), function(palyerid)
		brutalKill(palyerid)
    end)

	registerCommand(ffi.string(buffers.cmd_crazyanim), function()
        crazyAnim()
    end)

	registerCommand(ffi.string(buffers.cmd_spinneranim), function(speed)
		sppinerAnim(speed)
    end)

	registerCommand(ffi.string(buffers.cmd_bypass), function()
		bypassweapon()
		local estado = bypass and "activado" or "desactivado"
		msg(script_name .. " {FFFFFF}Bypass " .. estado .. ".")
    end)

	registerCommand(ffi.string(buffers.cmd_respawncar), function()
		activeRespawn = not activeRespawn
        printStringNow("Estado " ..(activeRespawn and "~g~ACTIVADO" or "~r~DESACTIVADO"), 1500)
    end)

	
	registerCommand(ffi.string(buffers.cmd_giveweapon), function(id)
		if id and tonumber(id) then
			giveWeaponById(tonumber(id))
			msg(script_name .. " {FFFFFF}Arma ID " .. id .. " otorgada.")
		else
			msg(script_name .. " {FFFFFF}Utilice: " .. configData.commands.giveweapon .. " [ID]")
		end
    end)
	
	registerCommand(ffi.string(buffers.cmd_fcrash), function()
		toggleCrasherCommand()
	end)
end

---------------------- [Function main]----------------------
function main()
	local fileName = getWorkingDirectory() .. "/Cipher.lua"
	
	if fileExists(fileName) then
		print("cargado correctamente")
	else
		print("No renombres el mod")
		thisScript():unload()
	end
	
	repeat wait(0) until isSampAvailable()
    msg(script_name .. " {FFFFFF}Cargado con exito. Utilice " .. configData.commands.openmenu .. ".")

	lua_thread.create(function()
        while true do
            wait(1000)
            if isSampAvailable() then
                monitorConnection()
            end
        end
    end)


	while true do

		reloadCommands()

		wait(0)

		if crazyAnimState then
			requestAnimation("PARACHUTE")
			if hasAnimationLoaded("PARACHUTE") then
				taskPlayAnim(PLAYER_PED, "PARA_RIP_LOOP_O", "PARACHUTE", 4.0, true, false, true, false, -1)
				removeAnimation("PARACHUTE")
			end
		end

		if spinnerAnimState then
			setCharHeading(PLAYER_PED, (getCharHeading(PLAYER_PED) + speedAnim))
		end

		if activeRespawn then
            for k, v in pairs(getAllVehicles()) do
                local _, id = sampGetVehicleIdByCarHandle(v)
                if _ then
                        sampSendVehicleDestroyed(id)
                        printStringNow("respawn id: "..id, 100)
                end
            end
        end

	end
end

---------------------- [Load fonts/theme]----------------------
imgui.OnInitialize(function()
	fa.Init()
	theme[colorListNumber[0]+1].change()
	style[styleListNumber[0]+1].change()
	
	local glyph_ranges  = imgui.GetIO().Fonts:GetGlyphRangesDefault()
	local fontPath = getWorkingDirectory() .. "/resource/"
	
	font1 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "sgame.ttf", 30, _, glyph_ranges )
	font2 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "Verdana.ttf", 25, _, glyph_ranges )

	    local config = imgui.ImFontConfig()
    config.MergeMode = false
    config.PixelSnapH = true
    config.OversampleH = 1
    config.OversampleV = 1

    if gtasaweapons then
        if gtasaweapons.get_font_data_base85 and gtasaweapons.min_range and gtasaweapons.max_range then
            local iconRanges = imgui.new.ImWchar[3](gtasaweapons.min_range, gtasaweapons.max_range, 0)
            weaponFont = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(
                gtasaweapons.get_font_data_base85(), 32, config, iconRanges)
        elseif gtasaweapons.get_font_data and gtasaweapons.get_font_size then
            weaponFont = imgui.GetIO().Fonts:AddFontFromMemoryTTF(
                gtasaweapons.get_font_data(), gtasaweapons.get_font_size(), 32, config)
        end

        if gtasaweapons.build_atlas then
            gtasaweapons.build_atlas()
        end
    end

    if not weaponFont then
        weaponFont = imgui.GetIO().Fonts:AddFontDefault(config)
    end


end)

---------------------- [Menu style windows 11]----------------------
function imgui.BeginWin11Menu(title, isOpen, toggleButton, tabList, selectedTab, menuState, menuWidth, contentWidth, extraFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
    imgui.Begin(title, isOpen, imgui.WindowFlags.NoTitleBar + (extraFlags or 0))

    local windowSize = imgui.GetWindowSize()
    local windowPos = imgui.GetWindowPos()
    local drawList = imgui.GetWindowDrawList()
    local buttonSize = menuWidth - 10

	imgui.SetCursorPos(imgui.ImVec2(menuWidth, menuWidth))
    local menuPos = imgui.GetCursorScreenPos()

	drawList:AddRectFilled(menuPos, imgui.ImVec2(menuPos.x + windowSize.x - menuWidth, menuPos.y + windowSize.y - menuWidth), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.ChildBg]), imgui.GetStyle().WindowRounding, 9)
    imgui.SetCursorPos(imgui.ImVec2(0, 0))
    local backgroundPos = imgui.GetCursorScreenPos()
	
	drawList:AddRectFilled(backgroundPos, imgui.ImVec2(backgroundPos.x + (menuState[0] and contentWidth or menuWidth), backgroundPos.y + windowSize.y), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.WindowBg]), imgui.GetStyle().WindowRounding, 5)
    imgui.SetCursorPos(imgui.ImVec2(buttonSize + 10, menuWidth / 2 - imgui.CalcTextSize(title).y / 2))
    imgui.Text(title)
    imgui.SetCursorPosY(5)

    if toggleButton then
        imgui.SetCursorPosX(5)
        if imgui.Button(toggleButton, imgui.ImVec2(buttonSize, buttonSize)) then
            menuState[0] = not menuState[0]
        end
    else
        imgui.SetCursorPosY(25)
    end

    imgui.SetCursorPosX(5)
	
	local orderedTabs = {
        fa.SKULL,
        fa.PERSON_RIFLE,
        fa.CROSSHAIRS,
        fa.KEYBOARD,
        fa.GEAR
    }

    for _, tabIcon in ipairs(orderedTabs) do
        local tabName = tabList[tabIcon]

        if tabName then 
            imgui.SetCursorPosX(5)
            imgui.PushStyleColor(imgui.Col.Button, selectedTab[0] == tabName 
                and imgui.GetStyle().Colors[imgui.Col.ButtonActive] 
                or imgui.GetStyle().Colors[imgui.Col.WindowBg])

            imgui.PushStyleVarVec2(imgui.StyleVar.ButtonTextAlign, imgui.ImVec2(menuState[0] and 0.1 or 0.5, 0.5))
            imgui.SetWindowFontScale(1.5)

            local iconColor = imgui.GetStyle().Colors[imgui.Col.NavHighlight] or imgui.ImVec4(1.0, 1.0, 1.0, 1.0)
            imgui.PushStyleColor(imgui.Col.Text, iconColor)

            if imgui.Button(menuState[0] and tabIcon .. " " .. tabName or tabIcon, 
                imgui.ImVec2(menuState[0] and contentWidth - 10 or buttonSize, buttonSize)) then
                selectedTab[0] = tabName
            end

            imgui.PopStyleColor()
            imgui.SetWindowFontScale(1.0)
            imgui.PopStyleVar()
            imgui.PopStyleColor()
        end
    end
	imgui.SetCursorPos(imgui.ImVec2(menuWidth, 0))
	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(15, 15))
	imgui.BeginChild(title .. "::mainchild", imgui.ImVec2(windowSize.x - menuWidth, windowSize.y), true, imgui.WindowFlags.NoScrollbar)

end

---------------------- [Finish script]----------------------
function imgui.EndWin11Menu()
	imgui.EndChild()
	imgui.End()
	imgui.PopStyleVar(2)
end

---------------------- [Themes]----------------------
function apply_monet()
	imgui.SwitchContext()
	local style = imgui.GetStyle()
	local colors = style.Colors
	local clr = imgui.Col
	local ImVec4 = imgui.ImVec4
	local generated_color = monet.buildColors(ini.cfg.color, 1.0, true)
	colors[clr.Text] = ColorAccentsAdapter(generated_color.accent2.color_50):as_vec4()
	colors[clr.TextDisabled] = ColorAccentsAdapter(generated_color.neutral1.color_600):as_vec4()
	colors[clr.WindowBg] = ColorAccentsAdapter(generated_color.accent2.color_900):as_vec4()
	colors[clr.ChildBg] = ColorAccentsAdapter(generated_color.accent2.color_800):as_vec4()
	colors[clr.PopupBg] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
	colors[clr.Border] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0xcc):as_vec4()
	colors[clr.Separator] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0xcc):as_vec4()
	colors[clr.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.FrameBg] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x60):as_vec4()
	colors[clr.FrameBgHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x70):as_vec4()
	colors[clr.FrameBgActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x50):as_vec4()
	colors[clr.TitleBg] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xcc):as_vec4()
	colors[clr.TitleBgCollapsed] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0x7f):as_vec4()
	colors[clr.TitleBgActive] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
	colors[clr.MenuBarBg] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x91):as_vec4()
	colors[clr.ScrollbarBg] = imgui.ImVec4(0,0,0,0)
	colors[clr.ScrollbarGrab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x85):as_vec4()
	colors[clr.ScrollbarGrabHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.ScrollbarGrabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.CheckMark] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.SliderGrab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.SliderGrabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x80):as_vec4()
	colors[clr.Button] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.ButtonHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.ButtonActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.Tab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.TabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.TabHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.Header] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
	colors[clr.HeaderHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.HeaderActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
	colors[clr.ResizeGrip] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xcc):as_vec4()
	colors[clr.ResizeGripHovered] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
	colors[clr.ResizeGripActive] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xb3):as_vec4()
	colors[clr.PlotLines] = ColorAccentsAdapter(generated_color.accent2.color_600):as_vec4()
	colors[clr.PlotLinesHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.PlotHistogram] = ColorAccentsAdapter(generated_color.accent2.color_600):as_vec4()
	colors[clr.PlotHistogramHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.TextSelectedBg] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
	colors[clr.ModalWindowDimBg] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0x26):as_vec4()
end

style = {
    ------------ [BASE] ------------
    {
        change = function()
            local style = imgui.GetStyle()
			style.WindowPadding = imgui.ImVec2(14, 14)
			style.WindowRounding = 0
			style.WindowBorderSize = 3
			style.WindowMinSize = imgui.ImVec2(50, 50)
			style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
			style.ChildRounding = 0
			style.ChildBorderSize = 2
			style.PopupRounding = 0
			style.PopupBorderSize = 2
			style.FramePadding = imgui.ImVec2(12, 9)
			style.FrameRounding = 0
			style.FrameBorderSize = 0
			style.ItemSpacing = imgui.ImVec2(14, 5)
			style.ItemInnerSpacing = imgui.ImVec2(8, 8)
			style.IndentSpacing = 30
			style.ScrollbarSize = 18
			style.ScrollbarRounding = 0
			style.GrabMinSize = 20
			style.GrabRounding = 0
			style.TabRounding = 0
			style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
			style.SelectableTextAlign = imgui.ImVec2(0, 0)
        end
    },

	 ------------ [MODERNO] ------------
    {
        change = function()
           local style = imgui.GetStyle()
		style.WindowPadding = imgui.ImVec2(14, 14)
		style.WindowRounding = 12
		style.WindowBorderSize = 3
		style.WindowMinSize = imgui.ImVec2(50, 50)
		style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
		style.ChildRounding = 10
		style.ChildBorderSize = 2
		style.PopupRounding = 10
		style.PopupBorderSize = 2
		style.FramePadding = imgui.ImVec2(12, 9)
		style.FrameRounding = 8
		style.FrameBorderSize = 0
		style.ItemSpacing = imgui.ImVec2(14, 5)
		style.ItemInnerSpacing = imgui.ImVec2(8, 8)
		style.IndentSpacing = 30
		style.ScrollbarSize = 18
		style.ScrollbarRounding = 10
		style.GrabMinSize = 20
		style.GrabRounding = 10
		style.TabRounding = 10
		style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
		style.SelectableTextAlign = imgui.ImVec2(0, 0)
        end
    },

	------------ [NEOSTYLE] ------------
	{
		change = function()
			local style = imgui.GetStyle()
			style.WindowPadding = imgui.ImVec2(14, 14)
			style.WindowRounding = 0
			style.WindowBorderSize = 2
			style.WindowMinSize = imgui.ImVec2(50, 50)
			style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
			style.ChildRounding = 0
			style.ChildBorderSize = 2
			style.PopupRounding = 0
			style.PopupBorderSize = 2
			style.FramePadding = imgui.ImVec2(12, 10)
			style.FrameRounding = 0
			style.FrameBorderSize = 1
			style.ItemSpacing = imgui.ImVec2(14, 6)
			style.ItemInnerSpacing = imgui.ImVec2(10, 10)
			style.IndentSpacing = 30
			style.ScrollbarSize = 20
			style.ScrollbarRounding = 2
			style.GrabMinSize = 22
			style.GrabRounding = 0
			style.TabRounding = 0
			style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
			style.SelectableTextAlign = imgui.ImVec2(0, 0)
		end
	}
}



theme = {
	------------ [RED] ------------
	{
		change = function()
			local ImVec4 = imgui.ImVec4
			local ImVec4 = imgui.ImVec4
			imgui.SwitchContext()
			
			imgui.GetStyle().Colors[imgui.Col.Text] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.TextDisabled] = ImVec4(0.8, 0.5, 0.5, 1)
			imgui.GetStyle().Colors[imgui.Col.WindowBg] = ImVec4(0.15, 0, 0, 1)
			imgui.GetStyle().Colors[imgui.Col.ChildBg] = ImVec4(0.2, 0.05, 0.05, 0.3)
			imgui.GetStyle().Colors[imgui.Col.PopupBg] = ImVec4(0.25, 0.07, 0.07, 1)
			imgui.GetStyle().Colors[imgui.Col.Border] = ImVec4(0.8, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.BorderShadow] = ImVec4(0.4, 0.1, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBg] = ImVec4(0.6, 0.15, 0.15, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = ImVec4(0.7, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = ImVec4(0.8, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBg] = ImVec4(0.3, 0.1, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = ImVec4(0.6, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = ImVec4(0.2, 0.05, 0.05, 0.5)
			imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = ImVec4(0.3, 0.1, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = ImVec4(0.2, 0.05, 0.05, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = ImVec4(0.6, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = ImVec4(0.7, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = ImVec4(0.8, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.CheckMark] = ImVec4(0.8, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrab] = ImVec4(0.8, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = ImVec4(0.9, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.Button] = ImVec4(0.6, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = ImVec4(0.7, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonActive] = ImVec4(0.8, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.Header] = ImVec4(0.6, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = ImVec4(0.7, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderActive] = ImVec4(0.8, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.Separator] = ImVec4(0.6, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = ImVec4(0.7, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = ImVec4(0.8, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = ImVec4(0.6, 0.2, 0.2, 0.7)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = ImVec4(0.7, 0.3, 0.3, 0.8)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = ImVec4(0.8, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.Tab] = ImVec4(0.6, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.TabHovered] = ImVec4(0.7, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.TabActive] = ImVec4(0.8, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = ImVec4(0.3, 0.1, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = ImVec4(0.5, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = ImVec4(0.8, 0.3, 0.3, 0.5)
			imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = ImVec4(0.8, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.NavHighlight] = ImVec4(1.0, 1.0, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = ImVec4(0, 0, 0, 0.33)			
		end		
	},
	------------ [GREEN] ------------
	{
		change = function()
			local ImVec4 = imgui.ImVec4
			imgui.SwitchContext()
		
			imgui.GetStyle().Colors[imgui.Col.Text] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.TextDisabled] = ImVec4(0.6, 0.6, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.WindowBg] = ImVec4(0.02, 0.15, 0.02, 1)
			imgui.GetStyle().Colors[imgui.Col.ChildBg] = ImVec4(0.02, 0.2, 0.02, 0.3)
			imgui.GetStyle().Colors[imgui.Col.PopupBg] = ImVec4(0.02, 0.25, 0.02, 1)
			imgui.GetStyle().Colors[imgui.Col.Border] = ImVec4(0.1, 0.8, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.BorderShadow] = ImVec4(0.05, 0.05, 0.05, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBg] = ImVec4(0.1, 0.4, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = ImVec4(0.2, 0.9, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = ImVec4(0.3, 1.0, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBg] = ImVec4(0.05, 0.3, 0.05, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = ImVec4(0.1, 0.9, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = ImVec4(0.02, 0.2, 0.02, 0.5)
			imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = ImVec4(0.02, 0.2, 0.02, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = ImVec4(0.02, 0.1, 0.02, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = ImVec4(0.1, 0.6, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = ImVec4(0.2, 0.8, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = ImVec4(0.3, 1.0, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.CheckMark] = ImVec4(0.4, 1.0, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrab] = ImVec4(0.3, 1.0, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = ImVec4(0.2, 1.0, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.Button] = ImVec4(0.1, 0.8, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = ImVec4(0.2, 1.0, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonActive] = ImVec4(0.05, 0.9, 0.05, 1)
			imgui.GetStyle().Colors[imgui.Col.Header] = ImVec4(0.1, 0.8, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = ImVec4(0.2, 1.0, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderActive] = ImVec4(0.3, 1.0, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.Separator] = ImVec4(0.1, 0.8, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = ImVec4(0.2, 1.0, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = ImVec4(0.3, 1.0, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = ImVec4(0.1, 0.8, 0.1, 0.7)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = ImVec4(0.2, 1.0, 0.2, 0.8)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = ImVec4(0.3, 1.0, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.Tab] = ImVec4(0.1, 0.8, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.TabHovered] = ImVec4(0.2, 1.0, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.TabActive] = ImVec4(0.3, 1.0, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = ImVec4(0.02, 0.2, 0.02, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = ImVec4(0.1, 0.4, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = ImVec4(0.2, 1.0, 0.2, 0.5)
			imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = ImVec4(0.2, 1.0, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.NavHighlight] = ImVec4(1.0, 1.0, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = ImVec4(0, 0, 0, 0.33)
		end		
	},
	------------ [BLUE] ------------
	{
		change = function()
			local ImVec4 = imgui.ImVec4
			imgui.SwitchContext()

			imgui.GetStyle().Colors[imgui.Col.Text] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.TextDisabled] = ImVec4(0.6, 0.6, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.WindowBg] = ImVec4(0.02, 0.2, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.ChildBg] = ImVec4(0.05, 0.3, 0.5, 0.3)
			imgui.GetStyle().Colors[imgui.Col.PopupBg] = ImVec4(0.07, 0.35, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.Border] = ImVec4(0.2, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.BorderShadow] = ImVec4(0.1, 0.2, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBg] = ImVec4(0.15, 0.5, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = ImVec4(0.2, 0.6, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = ImVec4(0.3, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBg] = ImVec4(0.05, 0.3, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = ImVec4(0.1, 0.4, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = ImVec4(0.02, 0.25, 0.5, 0.5)
			imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = ImVec4(0.05, 0.3, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = ImVec4(0.02, 0.2, 0.5, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = ImVec4(0.2, 0.5, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = ImVec4(0.3, 0.6, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = ImVec4(0.4, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.CheckMark] = ImVec4(0.3, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrab] = ImVec4(0.3, 0.6, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = ImVec4(0.2, 0.5, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Button] = ImVec4(0.2, 0.6, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = ImVec4(0.3, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonActive] = ImVec4(0.35, 0.75, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Header] = ImVec4(0.2, 0.6, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = ImVec4(0.3, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderActive] = ImVec4(0.35, 0.75, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Separator] = ImVec4(0.2, 0.6, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = ImVec4(0.3, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = ImVec4(0.35, 0.75, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = ImVec4(0.2, 0.6, 1.0, 0.7)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = ImVec4(0.3, 0.7, 1.0, 0.8)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = ImVec4(0.35, 0.75, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Tab] = ImVec4(0.2, 0.6, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TabHovered] = ImVec4(0.3, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TabActive] = ImVec4(0.35, 0.75, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = ImVec4(0.05, 0.3, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = ImVec4(0.1, 0.4, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = ImVec4(0.3, 0.7, 1.0, 0.5)
			imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = ImVec4(0.3, 0.7, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavHighlight] = ImVec4(1.0, 1.0, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = ImVec4(0, 0, 0, 0.33)
		end		
	},
	------------ [DARK] ------------
	{
		change = function()
			local ImVec4 = imgui.ImVec4
			imgui.SwitchContext()
		
			imgui.GetStyle().Colors[imgui.Col.Text] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.TextDisabled] = ImVec4(0.6, 0.6, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.WindowBg] = ImVec4(0.02, 0.02, 0.02, 1)
			imgui.GetStyle().Colors[imgui.Col.ChildBg] = ImVec4(0.1, 0.1, 0.1, 0.5)
			imgui.GetStyle().Colors[imgui.Col.PopupBg] = ImVec4(0.12, 0.12, 0.12, 1)
			imgui.GetStyle().Colors[imgui.Col.Border] = ImVec4(0.3, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.BorderShadow] = ImVec4(0, 0, 0, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBg] = ImVec4(0.18, 0.18, 0.18, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = ImVec4(0.25, 0.25, 0.25, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = ImVec4(0.4, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBg] = ImVec4(0.08, 0.08, 0.08, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = ImVec4(0.15, 0.15, 0.15, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = ImVec4(0.08, 0.08, 0.08, 0.5)
			imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = ImVec4(0.1, 0.1, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = ImVec4(0.05, 0.05, 0.05, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = ImVec4(0.2, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = ImVec4(0.3, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = ImVec4(0.4, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.CheckMark] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrab] = ImVec4(0.5, 0.5, 0.5, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = ImVec4(0.7, 0.7, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.Button] = ImVec4(0.2, 0.2, 0.2, 1.00)
			imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = ImVec4(0.4, 0.4, 0.4, 1.00)
			imgui.GetStyle().Colors[imgui.Col.ButtonActive] = ImVec4(0.8, 0.8, 0.8, 1.00)			
			imgui.GetStyle().Colors[imgui.Col.Header] = ImVec4(0.2, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = ImVec4(0.3, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderActive] = ImVec4(0.4, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.Separator] = ImVec4(0.2, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = ImVec4(0.3, 0.3, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = ImVec4(0.4, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = ImVec4(0.2, 0.2, 0.2, 0.7)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = ImVec4(0.3, 0.3, 0.3, 0.8)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = ImVec4(0.4, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.Tab] = ImVec4(0.15, 0.15, 0.15, 1)
			imgui.GetStyle().Colors[imgui.Col.TabHovered] = ImVec4(0.25, 0.25, 0.25, 1)
			imgui.GetStyle().Colors[imgui.Col.TabActive] = ImVec4(0.35, 0.35, 0.35, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = ImVec4(0.1, 0.1, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = ImVec4(0.2, 0.2, 0.2, 1)
			imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = ImVec4(0.4, 0.4, 0.4, 0.5)
			imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = ImVec4(0.4, 0.4, 0.4, 1)
			imgui.GetStyle().Colors[imgui.Col.NavHighlight] = ImVec4(1.0, 1.0, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = ImVec4(0, 0, 0, 0.33)
		end		
	},
	------------ [CIAN] ------------
	{
		change = function()
			local ImVec4 = imgui.ImVec4
			imgui.SwitchContext()
		
			imgui.GetStyle().Colors[imgui.Col.Text] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.TextDisabled] = ImVec4(0.6, 0.6, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.WindowBg] = ImVec4(0.02, 0.1, 0.12, 1)
			imgui.GetStyle().Colors[imgui.Col.ChildBg] = ImVec4(0.05, 0.15, 0.18, 0.5)
			imgui.GetStyle().Colors[imgui.Col.PopupBg] = ImVec4(0.08, 0.2, 0.22, 1)
			imgui.GetStyle().Colors[imgui.Col.Border] = ImVec4(0.1, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.BorderShadow] = ImVec4(0, 0, 0, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBg] = ImVec4(0.1, 0.4, 0.45, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = ImVec4(0.15, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = ImVec4(0.2, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBg] = ImVec4(0.02, 0.12, 0.15, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = ImVec4(0.1, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = ImVec4(0.02, 0.12, 0.15, 0.5)
			imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = ImVec4(0.02, 0.15, 0.18, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = ImVec4(0.02, 0.1, 0.12, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = ImVec4(0.1, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = ImVec4(0.15, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = ImVec4(0.2, 0.8, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.CheckMark] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrab] = ImVec4(0.15, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = ImVec4(0.2, 0.8, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.Button] = ImVec4(0.1, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = ImVec4(0.2, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonActive] = ImVec4(0.3, 0.8, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.Header] = ImVec4(0.1, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = ImVec4(0.2, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderActive] = ImVec4(0.3, 0.8, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.Separator] = ImVec4(0.1, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = ImVec4(0.2, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = ImVec4(0.3, 0.8, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = ImVec4(0.1, 0.6, 0.7, 0.7)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = ImVec4(0.2, 0.7, 0.8, 0.8)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = ImVec4(0.3, 0.8, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.Tab] = ImVec4(0.08, 0.5, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.TabHovered] = ImVec4(0.15, 0.6, 0.7, 1)
			imgui.GetStyle().Colors[imgui.Col.TabActive] = ImVec4(0.2, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = ImVec4(0.1, 0.4, 0.5, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = ImVec4(0.15, 0.5, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = ImVec4(0.2, 0.7, 0.8, 0.5)
			imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = ImVec4(0.2, 0.7, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.NavHighlight] = ImVec4(1.0, 1.0, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = ImVec4(0, 0, 0, 0.33)
		end		
	},
	------------ [NEON] ------------
	{
		change = function()
			local ImVec4 = imgui.ImVec4
			imgui.SwitchContext()
		
			imgui.GetStyle().Colors[imgui.Col.Text] = ImVec4(1, 1, 1, 1)
			imgui.GetStyle().Colors[imgui.Col.TextDisabled] = ImVec4(0.6, 0.6, 0.6, 1)
			imgui.GetStyle().Colors[imgui.Col.WindowBg] = ImVec4(0.05, 0.02, 0.1, 1)
			imgui.GetStyle().Colors[imgui.Col.ChildBg] = ImVec4(0.1, 0.03, 0.2, 0.3)
			imgui.GetStyle().Colors[imgui.Col.PopupBg] = ImVec4(0.12, 0.04, 0.25, 1)
			imgui.GetStyle().Colors[imgui.Col.Border] = ImVec4(0.5, 0.1, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.BorderShadow] = ImVec4(0.2, 0.05, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBg] = ImVec4(0.4, 0.1, 0.8, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgHovered] = ImVec4(0.6, 0.2, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgActive] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBg] = ImVec4(0.2, 0.05, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgActive] = ImVec4(0.4, 0.1, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.TitleBgCollapsed] = ImVec4(0.1, 0.03, 0.2, 0.5)
			imgui.GetStyle().Colors[imgui.Col.MenuBarBg] = ImVec4(0.15, 0.04, 0.35, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarBg] = ImVec4(0.08, 0.02, 0.25, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab] = ImVec4(0.4, 0.1, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered] = ImVec4(0.6, 0.2, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.CheckMark] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrab] = ImVec4(0.6, 0.2, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrabActive] = ImVec4(0.5, 0.15, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Button] = ImVec4(0.6, 0.2, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonHovered] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ButtonActive] = ImVec4(0.8, 0.4, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Header] = ImVec4(0.6, 0.2, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderHovered] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.HeaderActive] = ImVec4(0.8, 0.4, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Separator] = ImVec4(0.6, 0.2, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorHovered] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.SeparatorActive] = ImVec4(0.8, 0.4, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = ImVec4(0.6, 0.2, 1.0, 0.7)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered] = ImVec4(0.7, 0.3, 1.0, 0.8)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripActive] = ImVec4(0.8, 0.4, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.Tab] = ImVec4(0.6, 0.2, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TabHovered] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TabActive] = ImVec4(0.8, 0.4, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocused] = ImVec4(0.2, 0.05, 0.3, 1)
			imgui.GetStyle().Colors[imgui.Col.TabUnfocusedActive] = ImVec4(0.4, 0.1, 0.9, 1)
			imgui.GetStyle().Colors[imgui.Col.TextSelectedBg] = ImVec4(0.7, 0.3, 1.0, 0.5)
			imgui.GetStyle().Colors[imgui.Col.DragDropTarget] = ImVec4(0.7, 0.3, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavHighlight] = ImVec4(1.0, 1.0, 1.0, 1)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg] = ImVec4(0, 0, 0, 0.33)
			imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg] = ImVec4(0, 0, 0, 0.33)
		end			
	},
	------------ [Cyberpunk] ------------
	{
		change=function()
			local ImVec4=imgui.ImVec4
			imgui.SwitchContext()
			
			imgui.GetStyle().Colors[imgui.Col.WindowBg]=ImVec4(0.05,0.05,0,1)
			imgui.GetStyle().Colors[imgui.Col.ChildBg]=ImVec4(0.1,0.1,0,0.3)
			imgui.GetStyle().Colors[imgui.Col.PopupBg]=ImVec4(0.12,0.12,0,1)
			imgui.GetStyle().Colors[imgui.Col.Text]=ImVec4(1,1,1,1)
			imgui.GetStyle().Colors[imgui.Col.TextDisabled]=ImVec4(0.7,0.7,0,1)
			imgui.GetStyle().Colors[imgui.Col.Border]=ImVec4(1,1,0,1)
			imgui.GetStyle().Colors[imgui.Col.Separator]=ImVec4(1,1,0,1)
			imgui.GetStyle().Colors[imgui.Col.FrameBg]=ImVec4(0.3,0.3,0,1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]=ImVec4(0.5,0.5,0,1)
			imgui.GetStyle().Colors[imgui.Col.FrameBgActive]=ImVec4(0.7,0.7,0,1)
			imgui.GetStyle().Colors[imgui.Col.Header]=ImVec4(0.5,0.5,0,1)
			imgui.GetStyle().Colors[imgui.Col.HeaderHovered]=ImVec4(0.6,0.6,0,1)
			imgui.GetStyle().Colors[imgui.Col.HeaderActive]=ImVec4(0.7,0.7,0,1)
			imgui.GetStyle().Colors[imgui.Col.Button]=ImVec4(1,1,0,1)
			imgui.GetStyle().Colors[imgui.Col.ButtonHovered]=ImVec4(1,0.9,0,1)
			imgui.GetStyle().Colors[imgui.Col.ButtonActive]=ImVec4(1,0.8,0,1)
			imgui.GetStyle().Colors[imgui.Col.Tab]=ImVec4(0.5,0.5,0,1)
			imgui.GetStyle().Colors[imgui.Col.TabHovered]=ImVec4(0.6,0.6,0,1)
			imgui.GetStyle().Colors[imgui.Col.TabActive]=ImVec4(0.7,0.7,0,1)
			imgui.GetStyle().Colors[imgui.Col.CheckMark]=ImVec4(1,1,0,1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrab]=ImVec4(1,1,0,1)
			imgui.GetStyle().Colors[imgui.Col.SliderGrabActive]=ImVec4(1,0.9,0,1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrab]=ImVec4(1,1,0,1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabHovered]=ImVec4(1,0.9,0,1)
			imgui.GetStyle().Colors[imgui.Col.ScrollbarGrabActive]=ImVec4(1,0.8,0,1)
			imgui.GetStyle().Colors[imgui.Col.ResizeGrip]=ImVec4(1,1,0,0.7)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripHovered]=ImVec4(1,0.9,0,0.8)
			imgui.GetStyle().Colors[imgui.Col.ResizeGripActive]=ImVec4(1,0.8,0,1)
			imgui.GetStyle().Colors[imgui.Col.TextSelectedBg]=ImVec4(1,1,0,0.3)
			imgui.GetStyle().Colors[imgui.Col.DragDropTarget]=ImVec4(1,1,0,1)
			imgui.GetStyle().Colors[imgui.Col.NavHighlight]=ImVec4(1,1,0.5,1)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingHighlight]=ImVec4(0,0,0,0.33)
			imgui.GetStyle().Colors[imgui.Col.NavWindowingDimBg]=ImVec4(0,0,0,0.33)
			imgui.GetStyle().Colors[imgui.Col.ModalWindowDimBg]=ImVec4(0,0,0,0.33)
		end		
	},

	{
		change = function()
			apply_monet()
		end
	},
}