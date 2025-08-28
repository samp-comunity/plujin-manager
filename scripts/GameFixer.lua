script_name = "[GameFixer]"
script_author = "vxnzz"
script_version = "1.2"
--==================================== 

local imgui = require("mimgui")
local addons = require("ADDONS")
local sf = require('sampfuncs')
local sampEvents = require('samp.events')
local check_sampev, sampev = pcall(require, "samp.events")
local widgets = require("widgets")
local fa = require("fAwesome6")
local ffi = require("ffi")
local gta = ffi.load("GTASA")
local hook = require('monethook')
local SaMemory = require("SAMemory")
SaMemory.require("CCamera")
local Camera = SaMemory.camera

local function loadLibrary(libName, optionalMessage)
    local success, lib = pcall(require, libName)
    if not success then
        print(string.format('No se encuentra la libreria: "%s"%s', libName, optionalMessage or ""))
    end
    return lib
end

local lfs = loadLibrary("lfs")
local sc = loadLibrary 'supericon' 

local resourceDir = getWorkingDirectory() .. "/GameFixer"
if not doesDirectoryExist(resourceDir) then createDirectory(resourceDir) end

local subfolders = { "images", "fonts", "GENRL" }

for _, folder in ipairs(subfolders) do
    local path = resourceDir .. "/" .. folder
    if not doesDirectoryExist(path) then
        createDirectory(path)
    end
end

---------------------- [ cfg ]----------------------
local inicfg = require("inicfg")
local directIni  = "GameFixer.ini"
local ini = inicfg.load({
	main = {
		croshair = false;
		hitmarker = false,
		hitefects = false,
		miraposx = 0.5185,
		miraposy = 0.438,
		auto_miraposx = 0.5185,
    	auto_miraposy = 0.438,
		auto_crosshair = true
	},
	settings = {
		theme = 0,
		style = 0,
		imguiItemsScale = 0.84,
		notify = true,
		notifyScreen = true,
		autosave = true,
        autoReconnect = true,
		blocktime = false,
		blockweather = false,
		weather = 1,
		hours = 12,
		min = 0,
		aspectratio = 1.250,
		fov = 70,
        fov_mode = 0,
		drawdist = 900,
		camera = 0.80,
		aspectratio_status = true,
		fov_status = true,
		givemedist = false
	},
	button = {
		showmenubutton = true,
		background = true,
		menubutton_x = 100,
		menubutton_y = 450,
		menubutton_w = 60,
		menubutton_h = 45
	}, 
	colors = {
		hit1r = 1,
		hit1g = 1,
		hit1b = 1,
		hit1a = 1,
		hit2r = 1,
		hit2g = 1,
		hit2b = 1,
		hit2a = 1,
	},
	commands = {
		openmenu = "/gmenu",
		settime = "/st",
		setweather = "/sw",
		blockservertime = "/bt",
		blockserverweather = "/bw",
		clearchat = "/cc",
		togglechat = "/tc",
		reconect = "/rec",
		ugenrl = "/ugenrl",
		uds = "/uds",
		uss = "/uss",
		ums = "/ums",
		urs = "/urs",
		umps = "/umps",
		uuzi = "/uuzi",
		uaks = "/uaks",
		usps = "/usps",
		ucolt = "/ucolt",
		uedc = "/uedc",
		ubs = "/ubs",
		ups = "/ups"
	},
	ugenrl_main = {
        enable = true,
		autonosounds = true,
    	hit = true,	
        pain = true,
        weapon = true,
		enemyWeapon = true,
		enemyWeaponDist = 70,
    },
	ugenrl_volume = {
		hit = 0.30,
		pain = 0.30,
		weapon = 0.30
	},
	ugenrl_sounds = {
		[22] = 'Colt-45_01.mp3',
        [23] = 'SDPistol.mp3',
        [24] = 'Deagle_01.mp3',
        [25] = 'Shotgun_01.mp3',
        [26] = 'Sawnoff-shotgun.mp3',
        [27] = 'EDC_01.mp3',
        [28] = 'Uzi.mp3',
        [29] = 'MP5_01.mp3',
        [30] = 'AK_01.mp3',
        [31] = 'M4.01.mp3',
        [32] = 'TEC-9.mp3',
        [33] = 'Rifle.mp3',
        [34] = 'Sniper.mp3',
        [35] = 'RPG.mp3',
        [36] = 'RPG.mp3',
        [38] = 'Minigun.mp3',
        hit = 'Bell_01.mp3',
        pain = 'Pain_01.mp3',
	},
	--=======================[[Tema personalizado, configuraci n]]=====================

	--ordenarlo mejor
    borderchild = { draw = false,},
    PLeftUp = { r = 0.133, g = 0.62, b = 1, a = 0.735,},
    PLeftDown = { r = 0.133, g = 0.62, b = 1, a = 0.733,},
    PRightUp = { r = 0, g = 0, b = 0, a = 0,},
    PRightDown = { r = 0, g = 0, b = 0, a = 0,},
    WindowBG = { r = 0, g = 0, b = 0, a = 0.825,},
    BaseColor = { r = 0.183, g = 0.461, b = 0.678, a = 1.00,},
    ColorChildMenu = { r = 0.133, g = 0.62, b = 1, a = 0.733,},
    ColorFoneImg = { r = 0.06, g = 0.06, b = 0.06, a = 0.834,},
    ColorNavi = { r = 0, g = 0, b = 0, a = 0.213,},
    ColorTop = { r = 0, g = 0, b = 0, a = 1.00,},
    ActiveText = { r = 1.00, g = 1.00, b = 1.00, a = 1.00,},
    PassiveText = { r = 1.00, g = 1.00, b = 1.00, a = 1.00,},
    ColorText = { r = 1.00, g = 1.00, b = 1.00, a = 1.00,},
    FrameBg = { r = 0.053, g = 0.08, b = 0.277, a = 1.00,},
    FrameBgHovered = { r = 0.304, g = 0.281, b = 0.945, a = 0.694,},
    FrameBgActive = { r = 0.398, g = 0.329, b = 0.953, a = 0.936,},
    CheckMark = { r = 0.502, g = 0.455, b = 1.00, a = 1.00,},
    SliderGrab = { r = 0.33, g = 0.33, b = 0.33, a = 1.00,},
    SliderGrabActive = { r = 0.347, g = 0.17, b = 1.00, a = 1.00,},
    Button = { r = 0.54, g = 0.396, b = 1.00, a = 1.00,},
    ButtonHovered = { r = 0.562, g = 0.281, b = 1.00, a = 0.635,},
    ButtonActive = { r = 0.386, g = 0.289, b = 1.00, a = 1.00,},
    Header = { r = 0.439, g = 0.264, b = 1.00, a = 1.00,},
    HeaderHovered = { r = 0.389, g = 0.332, b = 1.00, a = 0.477,},
    HeaderActive = { r = 0.376, g = 0.336, b = 1.00, a = 1.00,},
    ScrollbarBg = { r = 0.386, g = 0.268, b = 1.00, a = 0.635,},
    ScrollbarGrab = { r = 0.521, g = 0.349, b = 1.00, a = 1.00,},
    ScrollbarGrabHovered = { r = 0.434, g = 0.345, b = 1.00, a = 1.00,},
    ScrollbarGrabActive = { r = 0.441, g = 0.289, b = 1.00, a = 1.00,},
    logocolor = { r = 0.133, g = 0.62, b = 1, a = 0.733,},
    BeginColor = { r = 1.00, g = 1.00, b = 1.00, a = 1.00,},
    mainBoxColor = { r = 0.133, g = 0.62, b = 1, a = 0.299,},
    mainBoxColorUP = { r = 0.0, g = 0.0, b = 0.0, a = 0.00,},


    --=============================================================================
}, directIni )

inicfg.save(ini, directIni)

function save()
    if ini.settings.autosave then
        inicfg.save(ini, directIni)
    end
end

local weaponSoundDelayPainAndHit = {[9] = 800, [37] = 900, } -- ugenrl
local weaponSoundDelayGuns = {[38] = 300,}
---------------------------------------------------------
local sw, sh = getScreenResolution()

function imgui.Link(url)
	gta._Z12AND_OpenLinkPKc(url)
end

local function setSensitivity(value)
	gta.AIMWEAPON_STICK_SENS = 0.001 + (value * 0.033)
end

function setCameraRenderDistance(distance)
    Camera.pRwCamera.farplane = distance
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


--Para los colores del hit....
local function colorToRGBAString(col)
	local r = math.floor(col[0] * 255)
	local g = math.floor(col[1] * 255)
	local b = math.floor(col[2] * 255)
	local a = math.floor(col[3] * 255)
	return string.format("rgba(%d,%d,%d,%d)", r, g, b, a)
end

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof


local navigations = {
	activeTab = {
        home = new.int(1),
        fixesandpatches = new.int(1),
        graphics = new.int(1),
        optimization = new.int(1),
        gameinterface = new.int(1),
    },
	home = {
        fa.HOUSE..' Principal',
        fa.DESKTOP.. ' Gráficos',
        fa.WRENCH.. ' Extras',
        fa.MUSIC.. ' Sonidos',
        fa.KEYBOARD.. ' Comandos',
        fa.PALETTE.. ' Diseño',
        fa.GEAR.. ' Ajustes',
    },
    graphics = {
        'Tiempo y hora',
        'Distancia de Dibujo',
        'Parámetros de pantalla',
    },
    current_graphics = 1,
    fixes = {
        'Mira',
        'Ai-Sens',
        'Damager Informer',
    },
    current_fixes = 1,
    settings = {
        'Principales',
        'Secundarios',
    },
    current_settings = 1,
}

-------------------------- [windows] --------------------------
local UI = {
	main = new.bool(false),
	btnmenu = new.bool(ini.button.showmenubutton),
	settingsbtn = new.bool(false),
	croshair = new.bool(false),
}
renderNotify = new.bool(false)

local settingsSubPage = new.int(0)

local buffers = {}
function imgui_Data()
-------------------------- [buffer] --------------------------

	buffers.cmd_openmenu = new.char[128](ini.commands.openmenu)
	buffers.cmd_settime = new.char[128](ini.commands.settime)
	buffers.cmd_setweather = new.char[128](ini.commands.setweather)
	buffers.cmd_blockservertime = new.char[128](ini.commands.blockservertime)
	buffers.cmd_blockserverweather = new.char[128](ini.commands.blockserverweather)
	buffers.cmd_clearchat = new.char[128](ini.commands.clearchat)
	buffers.cmd_togglechat = new.char[128](ini.commands.togglechat)
	buffers.cmd_reconect = new.char[128](ini.commands.reconect)
	buffers.cmd_ugenrl = new.char[128](ini.commands.ugenrl)
	buffers.cmd_uds = new.char[128](ini.commands.uds)
	buffers.cmd_uss = new.char[128](ini.commands.uss)
	buffers.cmd_ums = new.char[128](ini.commands.ums)
	buffers.cmd_urs = new.char[128](ini.commands.urs)
	buffers.cmd_umps = new.char[128](ini.commands.umps)
	buffers.cmd_uuzi = new.char[128](ini.commands.uuzi)
	buffers.cmd_uaks = new.char[128](ini.commands.uaks)
    buffers.cmd_usps = new.char[128](ini.commands.usps)
    buffers.cmd_ucolt = new.char[128](ini.commands.ucolt)
    buffers.cmd_uedc = new.char[128](ini.commands.uedc)
    buffers.cmd_ubs = new.char[128](ini.commands.ubs)
    buffers.cmd_ups = new.char[128](ini.commands.ups)

end
imgui_Data()


buffers.multilineText = imgui.new.char[14000]()
buffers.search_cmd = imgui.new.char[64]()
buffers.IEpresetName = imgui.new.char[128]()



local imguiInputsCmdEditor = {
    ["Abrir el menú del script"] = {var = buffers.cmd_openmenu, cfg = "openmenu"},
    ["Ajustar la hora"] = {var = buffers.cmd_settime, cfg = "settime"},
    ["Modificar el clima"] = {var = buffers.cmd_setweather, cfg = "setweather"},
    ["Bloquear hora del servidor"] = {var = buffers.cmd_blockservertime, cfg = "blockservertime"},
    ["Bloquear clima del servidor"] = {var = buffers.cmd_blockserverweather, cfg = "blockserverweather"},
    ["Limpiar el chat"] = {var = buffers.cmd_clearchat, cfg = "clearchat"},
    ["Mostrar/Ocultar mensajes del chat"] = {var = buffers.cmd_togglechat, cfg = "togglechat"},
    ["Reconectarse al servidor"] = {var = buffers.cmd_reconect, cfg = "reconect"},
    ["Encender/Apagar Ultimate Genrl"] = {var = buffers.cmd_ugenrl, cfg = "ugenrl"},
    ["Cambiar sonido de la desert"] = {var = buffers.cmd_uds, cfg = "uds"},
    ["Cambiar sonido de la m4"] = {var = buffers.cmd_ums, cfg = "ums"},
    ["Cambiar sonido de la escopeta"] = {var = buffers.cmd_uss, cfg = "uss"},
    ["Cambiar sonido del rifle"] = {var = buffers.cmd_urs, cfg = "urs"},
    ["Cambiar sonido de la mp5"] = {var = buffers.cmd_umps, cfg = "umps"},
    ["Cambiar sonido de la uzi"] = {var = buffers.cmd_uuzi, cfg = "uuzi"},
    ["Cambiar sonido de la ak47"] = {var = buffers.cmd_uaks, cfg = "uaks"},
    ["Cambiar sonido de la Colt-45"] = {var = buffers.cmd_ucolt, cfg = "ucolt"},
    ["Cambiar sonido de la edc"] = {var = buffers.cmd_uedc, cfg = "uedc"},
    ["Cambiar sonido del sniper"] = {var = buffers.cmd_usps, cfg = "usps"},
    ["Cambiar sonido del HiSound"] = {var = buffers.cmd_ubs, cfg = "ubs"},
    ["Cambiar sonido de dolor"] = {var = buffers.cmd_ups, cfg = "ups"}
}

-------------------------- [sliders] --------------------------
local sliders = {
	opacityLevel = new.float(1),
	fontSizeScale = new.float(ini.settings.imguiItemsScale),
	miraPosX = new.float(ini.main.miraposx),
	miraPosY = new.float(ini.main.miraposy),
	renderdist = new.float(ini.settings.drawdist),
	aspectratio = new.float(ini.settings.aspectratio),
	fov = new.float(ini.settings.fov),
	camera = new.float(ini.settings.camera),
	weather = new.int(ini.settings.weather == -1 and 0 or ini.settings.weather),
	hours = new.int(ini.settings.hours == -1 and 0 or ini.settings.hours),
	min = new.int(ini.settings.min == -1 and 0 or ini.settings.min),
	hit_volume = new.float(ini.ugenrl_volume.hit),
    pain_volume = new.float(ini.ugenrl_volume.pain),
    weapon_volume = new.float(ini.ugenrl_volume.weapon),
    enemyweapon_dist = new.float(ini.ugenrl_main.enemyWeaponDist),
	buttonPosX = new.int(ini.button.menubutton_x),
	buttonPosY = new.int(ini.button.menubutton_y),
	buttonWidth = new.int(ini.button.menubutton_w),
	buttonHeight = new.int(ini.button.menubutton_h)
}

--------------------------- [checkboxes] ---------------------------
local checkboxes = {
	enableCustomCrosshair = new.bool(ini.main.croshair),
	enabledHitMarker = new.bool(ini.main.hitmarker),
	enabledHitEfects = new.bool(ini.main.hitefects),
	ugenrl_enable = new.bool(ini.ugenrl_main.enable),
	autonosounds = new.bool(ini.ugenrl_main.autonosounds),
	weapon_checkbox = new.bool(ini.ugenrl_main.weapon),
	enemyweapon_checkbox = new.bool(ini.ugenrl_main.enemyWeapon),
	hit_checkbox = new.bool(ini.ugenrl_main.hit),
	pain_checkbox = new.bool(ini.ugenrl_main.pain),
	weapon_checkbox = new.bool(ini.ugenrl_main.weapon),
	autoCrosshair = imgui.new.bool(ini.main.auto_crosshair),
	notify = new.bool(ini.settings.notify),
	blocktime = new.bool(ini.settings.blocktime),
	blockweather = new.bool(ini.settings.blockweather),
	notifyScreen = new.bool(ini.settings.notifyScreen),
	autoReconnect = new.bool(ini.settings.autoReconnect),
	menubutton_checkbox = new.bool(ini.button.showmenubutton),
	menubutton_background = new.bool(ini.button.background),
	borderchild_draw = new.bool(ini.borderchild.draw),
	aspectratio_status = new.bool(ini.settings.aspectratio_status),
	fov_status = new.bool(ini.settings.fov_status),
	givemedist = new.bool(ini.settings.givemedist)
}



local icolors = {}


    ------------------- [icolors] ----------------------------
    icolors.PLeftUp = new.float[4](ini.PLeftUp.r, ini.PLeftUp.g, ini.PLeftUp.b, ini.PLeftUp.a)
    icolors.PLeftDown = new.float[4](ini.PLeftDown.r, ini.PLeftDown.g, ini.PLeftDown.b, ini.PLeftDown.a)
    icolors.PRightUp = new.float[4](ini.PRightUp.r, ini.PRightUp.g, ini.PRightUp.b, ini.PRightUp.a)
    icolors.PRightDown = new.float[4](ini.PRightDown.r, ini.PRightDown.g, ini.PRightDown.b, ini.PRightDown.a)
    icolors.WindowBG = new.float[4](ini.WindowBG.r, ini.WindowBG.g, ini.WindowBG.b, ini.WindowBG.a)
    icolors.BaseColor = new.float[4](ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, ini.BaseColor.a)
    icolors.ColorChildMenu = new.float[4](ini.ColorChildMenu.r, ini.ColorChildMenu.g, ini.ColorChildMenu.b, ini.ColorChildMenu.a)
    --  icolors.ColorFoneImg = new.float[4](ini.ColorFoneImg.r, ini.ColorFoneImg.g, ini.ColorFoneImg.b, ini.ColorFoneImg.a)

    icolors.ColorNavi = new.float[4](ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a)
    icolors.ColorTop = new.float[4](ini.ColorTop.r, ini.ColorTop.g, ini.ColorTop.b, ini.ColorTop.a)
    icolors.ActiveText = new.float[4](ini.ActiveText.r, ini.ActiveText.g, ini.ActiveText.b, ini.ActiveText.a)
    icolors.PassiveText = new.float[4](ini.PassiveText.r, ini.PassiveText.g, ini.PassiveText.b, ini.PassiveText.a)
    icolors.ColorText = new.float[4](ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
    icolors.FrameBg = new.float[4](ini.FrameBg.r, ini.FrameBg.g, ini.FrameBg.b, ini.FrameBg.a)
    icolors.FrameBgHovered = new.float[4](ini.FrameBgHovered.r, ini.FrameBgHovered.g, ini.FrameBgHovered.b, ini.FrameBgHovered.a)
    icolors.FrameBgActive = new.float[4](ini.FrameBgActive.r, ini.FrameBgActive.g, ini.FrameBgActive.b, ini.FrameBgActive.a)
    icolors.CheckMark = new.float[4](ini.CheckMark.r, ini.CheckMark.g, ini.CheckMark.b, ini.CheckMark.a)
    icolors.SliderGrab = new.float[4](ini.SliderGrab.r, ini.SliderGrab.g, ini.SliderGrab.b, ini.SliderGrab.a)
    icolors.SliderGrabActive = new.float[4](ini.SliderGrabActive.r, ini.SliderGrabActive.g, ini.SliderGrabActive.b, ini.SliderGrabActive.a)
    icolors.Button = new.float[4](ini.Button.r, ini.Button.g, ini.Button.b, ini.Button.a)
    icolors.ButtonHovered = new.float[4](ini.ButtonHovered.r, ini.ButtonHovered.g, ini.ButtonHovered.b, ini.ButtonHovered.a)
    icolors.ButtonActive = new.float[4](ini.ButtonActive.r, ini.ButtonActive.g, ini.ButtonActive.b, ini.ButtonActive.a)
    icolors.Header = new.float[4](ini.Header.r, ini.Header.g, ini.Header.b, ini.Header.a)
    icolors.HeaderHovered = new.float[4](ini.HeaderHovered.r, ini.HeaderHovered.g, ini.HeaderHovered.b, ini.HeaderHovered.a)
    icolors.HeaderActive = new.float[4](ini.HeaderActive.r, ini.HeaderActive.g, ini.HeaderActive.b, ini.HeaderActive.a)
    icolors.ScrollbarBg = new.float[4](ini.ScrollbarBg.r, ini.ScrollbarBg.g, ini.ScrollbarBg.b, ini.ScrollbarBg.a)
    icolors.ScrollbarGrab = new.float[4](ini.ScrollbarGrab.r, ini.ScrollbarGrab.g, ini.ScrollbarGrab.b, ini.ScrollbarGrab.a)
    icolors.ScrollbarGrabHovered = new.float[4](ini.ScrollbarGrabHovered.r, ini.ScrollbarGrabHovered.g, ini.ScrollbarGrabHovered.b, ini.ScrollbarGrabHovered.a)
    icolors.ScrollbarGrabActive = new.float[4](ini.ScrollbarGrabActive.r, ini.ScrollbarGrabActive.g, ini.ScrollbarGrabActive.b, ini.ScrollbarGrabActive.a)
    icolors.LogoColor = new.float[4](ini.logocolor.r, ini.logocolor.g, ini.logocolor.b, ini.logocolor.a)
    icolors.BeginColor = new.float[4](ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a)

    icolors.mainBoxColor = new.float[4](ini.mainBoxColor.r, ini.mainBoxColor.g, ini.mainBoxColor.b, ini.mainBoxColor.a)

    icolors.mainBoxColorUP = new.float[4](ini.mainBoxColorUP.r, ini.mainBoxColorUP.g, ini.mainBoxColorUP.b, ini.mainBoxColorUP.a)



local toggled_sm = false
local zoom_offset = 0
local is_fov_modified = false
local hitMarkerColor = new.float[4](ini.colors.hit1r, ini.colors.hit1g, ini.colors.hit1b, ini.colors.hit1a)
local hitEfectsColor = new.float[4](ini.colors.hit2r, ini.colors.hit2g, ini.colors.hit2b, ini.colors.hit2a)
local selected_fov_mode = new.int(ini.settings.fov_mode)
local fov_modes = { "Siempre activo", "Solo a pie", "Solo en vehículos" }
local fov_list = new["const char*"][#fov_modes](fov_modes)


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

---------------------- [Load Images]----------------------
--[[
local images = {}
local texturesLoaded = false

function LoadMenuTextures()
    if texturesLoaded then return end
    texturesLoaded = true
	local imgPath = getWorkingDirectory() .. "/gamefixer/images/"

    images.logo        = imgui.CreateTextureFromFile(imgPath .. "logo.png")
    images.home        = imgui.CreateTextureFromFile(imgPath .. "one.png")
    images.fix         = imgui.CreateTextureFromFile(imgPath .. "two.png")
    images.performance = imgui.CreateTextureFromFile(imgPath .. "three.png")
    images.sound       = imgui.CreateTextureFromFile(imgPath .. "four.png")
    images.keys        = imgui.CreateTextureFromFile(imgPath .. "five.png")
    images.config      = imgui.CreateTextureFromFile(imgPath .. "six.png")
end]]

---------------------- [Button Menu]----------------------

local floatingButtonFrame = imgui.OnFrame(function()
    return UI.btnmenu[0] and not isGamePaused()
end, function()
    local buttonTexturePath = getWorkingDirectory() .. "/gamefixer/images/button.png"
    if not buttonTexture and doesFileExist(buttonTexturePath) then
        buttonTexture = imgui.CreateTextureFromFile(buttonTexturePath)
    end

    imgui.SetNextWindowPos(imgui.ImVec2(ini.button.menubutton_x, ini.button.menubutton_y), imgui.Cond.Always)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(4, 4))
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(6, 4))

    local windowFlags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.NoMove +
    imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.AlwaysAutoResize

    if not checkboxes.menubutton_background[0] then
        windowFlags = windowFlags + imgui.WindowFlags.NoBackground
    end

    imgui.Begin("##botonAbrirMenu", nil, windowFlags)

    local size = imgui.ImVec2(ini.button.menubutton_w, ini.button.menubutton_h)

    if imgui.Selectable("##imagenBotonFlotante", false, nil, size) then
        UI.main[0] = not UI.main[0]
    end

    local pos = imgui.GetItemRectMin()
    if buttonTexture then
        imgui.GetWindowDrawList():AddImage(buttonTexture, pos, imgui.ImVec2(pos.x + size.x, pos.y + size.y))
    else
        local icon = sc.LAYOUT_F
        local textSize = imgui.CalcTextSize(icon)
        local centerX = pos.x + (size.x - textSize.x) / 2
        local centerY = pos.y + (size.y - textSize.y) / 2

        imgui.SetCursorScreenPos(imgui.ImVec2(centerX, centerY))
        imgui.PushFont(iconFont)
        imgui.Text(icon)
        imgui.PopFont()
    end

    imgui.End()
    imgui.PopStyleVar(2)
end)


local buttonSettingsMenuFrame = imgui.OnFrame(function()
    return UI.settingsbtn[0]
end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(400, 320), imgui.Cond.FirstUseEver)

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20, 20))
    imgui.Begin("Botón flotante", false, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar) 

	local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
	local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
	imgui.PushFont(logofont)
	imgui.PushStyleColor(imgui.Col.Text, col1)
	imgui.Text("Configurar Boton")

	local windowSize = imgui.GetWindowSize()
	imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
	imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
	addons.CloseButton("##closemenuboton", UI.settingsbtn, 33, 5)
	imgui.PopStyleColor()

    imgui.Dummy(imgui.ImVec2(0, 25))

    if checkboxes.menubutton_checkbox[0] then
		imgui.PushStyleColor(imgui.Col.Text, col2)
        imgui.PushFont(font2)

        imgui.Checkbox("Fondo del botón", checkboxes.menubutton_background)
        if checkboxes.menubutton_background[0] ~= ini.button.background then
            ini.button.background = checkboxes.menubutton_background[0]
            save()
        end

        imgui.NewLine()
        imgui.Text("Posción del botón:")
        
        imgui.Spacing()
		if imgui.CustomSlider("##btn_pos_x", sliders.buttonPosX, 0, sw - 50, 'X', 300) then
			ini.button.menubutton_x = sliders.buttonPosX[0]
			save()
		end
        imgui.Spacing()
        
		if imgui.CustomSlider("##btn_pos_y", sliders.buttonPosY, 0, sh - 50, 'Y', 300) then
			ini.button.menubutton_y = sliders.buttonPosY[0]
			save()
		end
        
        imgui.NewLine()
        imgui.Text("Tamaño del botón:")
        
        imgui.Spacing()
		if imgui.CustomSlider("##btn_width", sliders.buttonWidth, 50, 300, 'Ancho', 300) then
			ini.button.menubutton_w = sliders.buttonWidth[0]
			save()
		end
        imgui.Spacing()

		if imgui.CustomSlider("##btn_height", sliders.buttonHeight, 45, 150, 'Alto', 300) then
			 ini.button.menubutton_h = sliders.buttonHeight[0]
			save()
		end

        imgui.NewLine()
        if imgui.Button(fa.UP_DOWN_LEFT_RIGHT, imgui.ImVec2(50, 40)) then
            btnpos = not btnpos
            UI.settingsbtn[0] = not UI.settingsbtn[0]
            msgPrint("btnpos")
        end

        imgui.PopFont()
    end

    imgui.Dummy(imgui.ImVec2(0, 10))
    imgui.End()
    imgui.PopStyleVar()
end)


local croshairSettings = imgui.OnFrame(function()
    return UI.croshair[0]
end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(400, 320), imgui.Cond.FirstUseEver)

    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20, 20))
    imgui.Begin("Croshair", false, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar) 

	local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
	local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
	imgui.PushFont(logofont)
	imgui.PushStyleColor(imgui.Col.Text, col1)
	imgui.Text(fa.CROSSHAIRS.." Configurar Mira")

	local windowSize = imgui.GetWindowSize()
	imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
	imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
	addons.CloseButton("##closemenuboton", UI.croshair, 33, 5)
	imgui.PopStyleColor()

    imgui.Dummy(imgui.ImVec2(0, 25))

    imgui.PushStyleColor(imgui.Col.Text, col2)
    imgui.PushFont(font2)
    if imgui.Checkbox("Activar mira personalizada", checkboxes.enableCustomCrosshair) then
        if checkboxes.enableCustomCrosshair[0] then
            checkboxes.autoCrosshair[0] = false
            ini.main.auto_crosshair = false
        end
        ini.main.croshair = checkboxes.enableCustomCrosshair[0]
        save()
    end
    imgui.PopFont()

    if checkboxes.enableCustomCrosshair[0] then	

        imgui.PushFont(font2)
        imgui.NewLine()

        imgui.Text("Posción Horizontal")
        imgui.Spacing()

        local buttonSize = imgui.ImVec2(43, 38)
        imgui.BeginGroup()

            local sliderStartY = imgui.GetCursorPosY()
            if imgui.CustomSlider("##miraX", sliders.miraPosX, 0.0, 1.0, '%.3f', 400) then
                ini.main.miraposx = sliders.miraPosX[0]
                save()
            end
            local sliderHeight = imgui.GetCursorPosY() - sliderStartY

            imgui.SameLine(480)

            imgui.SetCursorPosY(sliderStartY + (sliderHeight - buttonSize.y) / 2)
            if imgui.Button(fa.PLUS.. "##miraposx_plus", buttonSize) then
                sliders.miraPosX[0] = sliders.miraPosX[0] + 0.001
                if sliders.miraPosX[0] > 0.671 then
                    sliders.miraPosX[0] = 0.671
                end
                ini.main.miraposx = sliders.miraPosX[0]
                save()
            end

            imgui.SameLine()
            imgui.SetCursorPosY(sliderStartY + (sliderHeight - buttonSize.y) / 2)
            if imgui.Button(fa.MINUS.. "##miraposx_minus", buttonSize) then
                sliders.miraPosX[0] = sliders.miraPosX[0] - 0.001
                if sliders.miraPosX[0] < 0.371 then
                sliders.miraPosX[0] = 0.371
            end
                ini.main.miraposx = sliders.miraPosX[0]
                save()
            end

        imgui.EndGroup()

        imgui.Spacing()
        imgui.Text("Posción vertical")

        imgui.BeginGroup()

            local sliderStartY = imgui.GetCursorPosY()
             if imgui.CustomSlider("##miraY", sliders.miraPosY, 0.0, 1.0, "%.3f", 400) then
                ini.main.miraposy = sliders.miraPosY[0]
                save()
            end

            local sliderHeight = imgui.GetCursorPosY() - sliderStartY

            imgui.SameLine(480) 
            imgui.SetCursorPosY(sliderStartY + (sliderHeight - buttonSize.y) / 2)
            if imgui.Button(fa.PLUS .. "##miraposy_plus", buttonSize) then
                sliders.miraPosY[0] = sliders.miraPosY[0] + 0.001
                if sliders.miraPosY[0] > 0.585 then
                    sliders.miraPosY[0] = 0.585
                end
                ini.main.miraposy = sliders.miraPosY[0]
                save()
            end

            -- BOTÓN -
            imgui.SameLine()
            imgui.SetCursorPosY(sliderStartY + (sliderHeight - buttonSize.y) / 2)
            if imgui.Button(fa.MINUS .. "##miraposy_minus", buttonSize) then
                sliders.miraPosY[0] = sliders.miraPosY[0] - 0.001
                if sliders.miraPosY[0] < 0.285 then
                    sliders.miraPosY[0] = 0.285
                end
                ini.main.miraposy = sliders.miraPosY[0]
                save()
            end

        imgui.EndGroup()

        imgui.NewLine()
        if imgui.Button(fa.UP_DOWN_LEFT_RIGHT..' Cambiar de posicion', imgui.ImVec2(0, 40)) then
            chpos = not chpos
            UI.croshair[0] = not UI.croshair[0]
            msgPrint("chpos")
        end
        imgui.SameLine()
        if imgui.Button(fa.ROTATE_LEFT..' Restablecer', imgui.ImVec2(0, 40)) then
            ini.main.miraposx = 0.5185
            ini.main.miraposy = 0.438
            save()
            sliders.miraPosX[0] = ini.main.miraposx
            sliders.miraPosY[0] = ini.main.miraposy
        end

    end
    
    imgui.PopStyleColor()
    imgui.Dummy(imgui.ImVec2(0, 10))
    imgui.End()
    imgui.PopStyleVar()
end)

local mainMenuFrame = imgui.OnFrame(
    function()
        return UI.main[0]
    end,

    function(self)
        imgui.GetStyle().Alpha = sliders.opacityLevel[0]
        imgui.SetNextWindowSize(imgui.ImVec2(940, 610), imgui.Cond.FirstUseEver)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        imgui.Begin("##GameFixer", UI.main, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
        imgui.SetWindowFontScale(sliders.fontSizeScale[0])

		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.0, 0.0, 0.0, 0.0))
        local eColor = imgui.GetStyle().Colors[imgui.Col.PlotLinesHovered]
        --imgui.Image(fone, imgui.ImVec2(imgui.GetWindowSize().x, imgui.GetWindowSize().y), _,_, imgui.ImVec4(ini.BaseColor.r + 0.40, ini.BaseColor.g + 0.40, ini.BaseColor.b + 0.40, eColor.w + 1.0))
        
        imgui.SetCursorPos(imgui.ImVec2(175, 0))
		imgui.SetCursorPos(imgui.ImVec2(0, 0))
		local draw_list = imgui.GetWindowDrawList()
		local p = imgui.GetCursorScreenPos()
		local eColor = imgui.GetStyle().Colors[imgui.Col.WindowBg]
		local col_box = imgui.GetColorU32Vec4(imgui.ImVec4(ini.ColorTop.r, ini.ColorTop.g, ini.ColorTop.b, ini.ColorTop.a))
		
		local p = imgui.GetCursorScreenPos()
		
		imgui.GetWindowDrawList():AddRectFilledMultiColor(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x + imgui.GetWindowWidth(), p.y + imgui.GetWindowHeight()), imgui.GetColorU32Vec4(imgui.ImVec4(ini.ColorTop.r, ini.ColorTop.g, ini.ColorTop.b, ini.ColorTop.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.ColorTop.r, ini.ColorTop.g, ini.ColorTop.b, ini.ColorTop.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.WindowBG.r, ini.WindowBG.g, ini.WindowBG.b, eColor.w)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.WindowBG.r, ini.WindowBG.g, ini.WindowBG.b, eColor.w)))
		imgui.GetWindowDrawList():AddRectFilledMultiColor(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x+230, p.y + 1400), imgui.GetColorU32Vec4(imgui.ImVec4(ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a)))
		--draw_list:AddRectFilled(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x+190, p.y + 1400), col_box)

		imgui.BeginChild("##LeftMenu", imgui.ImVec2(230, 430), false)
                
			imgui.SetCursorPos(imgui.ImVec2(7, 40))
			imgui.PushFont(logofont)
			imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(ini.logocolor.r, ini.logocolor.g, ini.logocolor.b, ini.logocolor.a))
			imgui.Text(fa.GEARS.. " GameFixer")
			imgui.PopStyleColor()
			imgui.PopFont()
			imgui.SetCursorPos(imgui.ImVec2(0, 100))
			imgui.PushFont(font1)
			imgui.CustomMenu(navigations.home, navigations.activeTab.home, imgui.ImVec2(230, 37))
			imgui.PopFont()
			
		imgui.EndChild()

		local windowSize = imgui.GetWindowSize()
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
		imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
		addons.CloseButton("##closemenu", UI.main, 33, 5)
		imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(260, 50))
		imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20, 20))
		imgui.BeginChild("##MainMenu", imgui.ImVec2(imgui.GetContentRegionAvail().x - 10, 0), false)

        if navigations.activeTab.home[0] == 1 then

			imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowSize().x / 90, imgui.GetCursorPosY() + 8))
			imgui.PushFont(font1)
			imgui.TextColored(imgui.ImVec4(ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a), "INICIO")
			imgui.PopFont()
			imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
			imgui.BeginChild("##rightmenugg", imgui.ImVec2(imgui.GetWindowSize().x - 20, imgui.GetWindowSize().y - 90), true)
			imgui.PopStyleColor(1)

				imgui.MainBox("infoofscr", imgui.ImVec2(1000,510), 0)
					local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
					local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
					imgui.PushFont(font1)
					imgui.PushStyleColor(imgui.Col.Text, col1)
					imgui.Text("Información sobre el script")
					imgui.PopStyleColor()
					imgui.PopFont()
					imgui.Spacing()
					imgui.PushStyleColor(imgui.Col.Text, col2)
					imgui.PushFont(font2)
					imgui.Text("GAMEFIXER - Personaliza el juego para ti.")
					imgui.NewLine()
					imgui.Text("Con GAMEFIXER puedes personalizar el juego,\ncomo tú quieras.\nDesde la corrección de errores y parches para el juego, hasta el control completo\ndel clima, tiempo y demás.")
					imgui.Text("Optimiza los gráficos y personaliza incluso cosas que antes no estaban disponibles.")
					imgui.Text("GAMEFIXER - máxima personalización y mejores prestaciones\nen un solo mod.")
					imgui.NewLine()

					imgui.Text("Versión:") imgui.SameLine()
					imgui.TextColored(imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.CheckMark]), script_version)
					
					imgui.Text("Autor:")
					imgui.SameLine()
					imgui.TextColored(imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.CheckMark]), script_author)
					imgui.PopFont()
					
					imgui.Spacing()
					imgui.PushFont(iconFont)
					imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0, 0, 0.8))
					imgui.Text(sc.YOUTUBE)
					imgui.PopStyleColor()
					if imgui.IsItemClicked() then
						imgui.Link("https://youtube.com/@vxnzz_wz?si=-yvXxv_dZckthHrJ")
					end
					imgui.SameLine()
					imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.345, 0.396, 0.949, 1.0))
					imgui.Text(sc.DISCORD)
					imgui.PopStyleColor()
					if imgui.IsItemClicked() then
						imgui.Link("https://discord.gg/PSJT2SX7fh")
					end
					imgui.PopStyleColor()
					
					imgui.EndChild()


            elseif navigations.activeTab.home[0] == 2 then
                
				imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowSize().x / 90, imgui.GetCursorPosY() + 8))
				imgui.PushFont(font1)
				imgui.TextColored(imgui.ImVec4(ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a), "GRAFICOS")
				imgui.PopFont()
				imgui.PushFont(font2)
				
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
				
				for i, title in ipairs(navigations.graphics) do
					if HeaderButton(navigations.current_graphics  == i, title) then
						navigations.current_graphics  = i
					end
					if i ~= #navigations.graphics  then
						imgui.SameLine(nil, 20)
					end
				end
				imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX(), imgui.GetCursorPosY() + 5))
				imgui.BeginChild("##rightmenudd", imgui.ImVec2(imgui.GetWindowSize().x - 20,imgui.GetWindowSize().y - 120), true)
				imgui.PopStyleColor(2)
					if navigations.current_graphics == 1 then
                        
                        local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
						local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
                        
						imgui.PushStyleColor(imgui.Col.Text, col2)
						imgui.PushFont(font2)
						imgui.Text(fa.CLOUD_RAIN.. " Clima:")
						imgui.SameLine()
						imgui.SetCursorPosX(150)
						
						if imgui.CustomSlider("##weather", sliders.weather, 0, 45, '', 400) then
							ini.settings.weather = sliders.weather[0]
							save()
						end
						imgui.SameLine()
						imgui.PushItemWidth(45)
						if imgui.InputInt("##Weather_input", sliders.weather, 0, 45) then
							if sliders.weather[0] < 0 then
								sliders.weather[0] = 0
							end
							if sliders.weather[0] > 45 then
								sliders.weather[0] = 45
							end
							ini.settings.weather = sliders.weather[0]
							save()
							gotofunc("SetWeather")
						end
						imgui.PopItemWidth()

						imgui.Spacing()
					
						imgui.PushFont(font2)
						imgui.Text(fa.CLOCK.. " Hora:")
						imgui.SameLine()
						imgui.SetCursorPosX(150)
						if imgui.CustomSlider("##hours", sliders.hours, 0, 23, '', 400) then
							ini.settings.hours = sliders.hours[0]
							save()
						end
					
						imgui.SameLine()
						imgui.PushItemWidth(45)
						if imgui.InputInt("##Hours_input", sliders.hours, 0, 23) then
							
							if sliders.hours[0] < 0 then
								sliders.hours[0] = 0
							end
							
							if sliders.hours[0] > 24 then
								sliders.hours[0] = 24
							end
							ini.settings.hours = sliders.hours[0]
							save()
							gotofunc("SetTime")
						end
						imgui.PopItemWidth()

						imgui.Spacing()
				
						imgui.Text(fa.HOURGLASS.. " Minutos:")
						imgui.SameLine()
						imgui.SetCursorPosX(150)
						if imgui.CustomSlider("##min", sliders.min, 0, 59, '', 400) then
							ini.settings.min = sliders.min[0]
							save()
						end
					
						imgui.SameLine()
						imgui.PushItemWidth(45)
						if imgui.InputInt("##Mins_input", sliders.min, 0, 23) then
							
							if sliders.min[0] < 0 then
								sliders.min[0] = 0
							end
						
							if sliders.min[0] > 59 then
								sliders.min[0] = 59
							end
							ini.settings.min = sliders.min[0]
							save()
							gotofunc("SetTime")
						end
						imgui.PopItemWidth()

						imgui.Spacing()
						imgui.PushFont(font1)
						imgui.PushStyleColor(imgui.Col.Text, col1)
						imgui.Text("Cambiar Clima y Hora")
						imgui.PopStyleColor()
						imgui.PopFont()
						imgui.PushFont(font2)
						if imgui.Checkbox("Bloquear clima del servidor", checkboxes.blockweather) then
							ini.settings.blockweather = checkboxes.blockweather[0]
							save()
						end	
						if imgui.Checkbox("Bloquear hora del servidor", checkboxes.blocktime) then
							ini.settings.blocktime = checkboxes.blocktime[0]
							save()
						end	

					elseif navigations.current_graphics == 2 then

						if imgui.Checkbox("Activar función de cambiar distancia de dibujo", checkboxes.givemedist) then
							ini.settings.givemedist =  checkboxes.givemedist[0]
							save()
						end
                        imgui.NewLine()

						if ini.settings.givemedist then
							if imgui.CustomSlider("##Drawdist", sliders.renderdist, 50, 900, "distancia de dibujado: %.0f", 300) then
								ini.settings.drawdist = sliders.renderdist[0]
								save()
							end
						end

					elseif navigations.current_graphics == 3 then

						if imgui.Checkbox("Activar el editor de relación de aspecto de la pantalla", checkboxes.aspectratio_status) then
							ini.settings.aspectratio_status = checkboxes.aspectratio_status[0]
							save()
							--gotofunc("ScreenOptions")
						end
                        
						if ini.settings.aspectratio_status then
                            imgui.NewLine()
							if imgui.CustomSlider("##aspect", sliders.aspectratio, 0.5, 2.0, "Relación entre las partes: %.3f", 200) then
								ini.settings.aspectratio = sliders.aspectratio[0]
								save()
								if checkboxes.autoCrosshair[0] then
									gotofunc('AdjustCrosshair')
								end
							end

							imgui.Spacing()

							local label = "Restablecer"
							local textSize = imgui.CalcTextSize(label)
							local padding = 20

							if imgui.Button(label, imgui.ImVec2(textSize.x + padding, 35)) then
								ini.settings.aspectratio = 1.25
								save()
								sliders.aspectratio[0] = ini.settings.aspectratio
							end

						end

						imgui.NewLine()
						if imgui.Checkbox("Activar el editor de FOV", checkboxes.fov_status) then
							ini.settings.fov_status = checkboxes.fov_status[0]
							save()
						end
                        
						if ini.settings.fov_status then
                            imgui.NewLine()

                            if imgui.CustomSlider("##fov", sliders.fov, 20, 120, "fov: %.0f", 200) then
								ini.settings.fov = sliders.fov[0]
								save()
							end
                            
                            imgui.SameLine(350)
                            imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(5, 12))
                            imgui.PushItemWidth(300)
                            if imgui.Combo("##fov_combo", selected_fov_mode, fov_list, #fov_modes) then
                                ini.settings.fov_mode = selected_fov_mode[0]
                                save()
                            end
                            imgui.PopItemWidth()
                            imgui.PopStyleVar()

						end

					end

				

            elseif navigations.activeTab.home[0] == 3 then

				imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowSize().x / 90, imgui.GetCursorPosY() + 8))
				imgui.PushFont(font1)
				imgui.TextColored(imgui.ImVec4(ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a), "EXTRAS") 
				imgui.PopFont()
				imgui.PushFont(font2)
				
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
				
				for i, title in ipairs(navigations.fixes) do
					if HeaderButton(navigations.current_fixes  == i, title) then
						navigations.current_fixes  = i
					end
					if i ~= #navigations.fixes  then
						imgui.SameLine(nil, 20)
					end
				end
				imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX(), imgui.GetCursorPosY() + 5))
				imgui.BeginChild("##rightmenudd", imgui.ImVec2(imgui.GetWindowSize().x - 20,imgui.GetWindowSize().y - 120), true)
				imgui.PopStyleColor(2)
				if navigations.current_fixes == 1 then

                    local fullWidth = imgui.GetContentRegionAvail().x
                    imgui.MainBox("croshair", imgui.ImVec2(fullWidth, 380), 0)

                    local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
                    local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
                    imgui.PushFont(font1)
                    imgui.PushStyleColor(imgui.Col.Text, col1)
                    imgui.Text("Mira")
                    imgui.PopStyleColor()
                    imgui.PopFont()
                    imgui.Spacing()
                    imgui.PushStyleColor(imgui.Col.Text, col2)

                        imgui.NewLine()
                        imgui.Text("Descripción:")
                        imgui.BulletText("Permite centrar la mira automáticamente según la relación de aspecto.")
                        imgui.NewLine()
                        if imgui.Checkbox("Mira centralizada", checkboxes.autoCrosshair) then
                            if checkboxes.autoCrosshair[0] then
                                checkboxes.enableCustomCrosshair[0] = false
                                ini.main.croshair = false
                                gotofunc('AdjustCrosshair')
                            end
                            ini.main.auto_crosshair = checkboxes.autoCrosshair[0]
                            save()
                        end
                        imgui.NewLine()
                        imgui.Text("Nota:")
                        imgui.BulletText("Si la opción de arriba no centra bien la mira,\nutilice el ajuste manual disponible a continuación.")
                        imgui.SameLine()
                        if imgui.Button(fa.SCREWDRIVER_WRENCH, imgui.ImVec2(40, 35)) then
                            UI.croshair[0] = not UI.croshair[0]
                        end
                        imgui.NewLine()
                        
                    imgui.EndChild()

			    elseif navigations.current_fixes == 2 then

                    local fullWidth = imgui.GetContentRegionAvail().x
                    imgui.MainBox("sensitivity", imgui.ImVec2(fullWidth, 380), 0)
                        local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
                        local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
                        imgui.PushFont(font1)
                        imgui.PushStyleColor(imgui.Col.Text, col1)
                        imgui.Text("Ai - Sens")
                        imgui.PopStyleColor()
                        imgui.PopFont()
                        imgui.Spacing()
                        imgui.PushStyleColor(imgui.Col.Text, col2)

                            imgui.NewLine()
                            imgui.Text("Descripción:")
                            imgui.BulletText("Ajusta la sensibilidad de la camara.")
                            imgui.NewLine()
                            imgui.Text("Nota:")
                            imgui.BulletText("Por ahora solo se ajusta la sensibilidad de la cámara. Tal vez más adelante \nse incluya al apuntar... quién sabe, el universo es misterioso.")
                            imgui.NewLine()
                            
                            if imgui.CustomSlider("##camera", sliders.camera, 0, 1, "", 300) then
                                ini.settings.camera = ("%.2f"):format(sliders.camera[0])
                                save()
                                gotofunc("Ai-Sens")
                            end
                            imgui.SameLine()
                            imgui.PushItemWidth(80)
                            if imgui.InputFloat("Al girar la cámara", sliders.camera, 0.000, 1.000, "%.3f") then
                                -- 
                                if sliders.camera[0] < 0.005 then
                                    sliders.camera[0] = 0.005
                                end
                                -- 
                                if sliders.camera[0] > 1.000 then
                                    sliders.camera[0] = 1.000
                                end
                                ini.settings.camera = ("%.2f"):format(sliders.camera[0])
                                save()
                                gotofunc("Ai-Sens")
                            end
                            imgui.PopItemWidth()

                        imgui.PopStyleColor()
                    imgui.EndChild()

                elseif navigations.current_fixes == 3 then

                    local fullWidth = imgui.GetContentRegionAvail().x
                    local fullHeigth = imgui.GetContentRegionAvail().y
                    imgui.MainBox("dmg_informer", imgui.ImVec2(fullWidth, fullHeigth), 0)
                        local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
                        local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
                        imgui.PushFont(font1)
                        imgui.PushStyleColor(imgui.Col.Text, col1)
                        imgui.Text("Damager Informer")
                        imgui.PopStyleColor()
                        imgui.PopFont()
                        imgui.Spacing()
                        imgui.PushStyleColor(imgui.Col.Text, col2)

                            imgui.NewLine()
                            imgui.Text("Descripción:")
                            imgui.BulletText("Muestra indicadores visuales cuando haces daño a un enemigo.")
                            imgui.NewLine()

                            if imgui.Checkbox("Activar marcador de impacto", checkboxes.enabledHitMarker) then
                                ini.main.hitmarker = checkboxes.enabledHitMarker[0]
                                save()
                            end
                            imgui.Spacing()

                            imgui.Text("Color del marcador")
                            imgui.SameLine(250)
                            if imgui.ColorEdit4("##hitMarkerColor", hitMarkerColor, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                                ini.colors.hit1r = tonumber(string.format("%.2f", hitMarkerColor[0]))
                                ini.colors.hit1g = tonumber(string.format("%.2f", hitMarkerColor[1]))
                                ini.colors.hit1b = tonumber(string.format("%.2f", hitMarkerColor[2]))
                                ini.colors.hit1a = tonumber(string.format("%.2f", hitMarkerColor[3]))
                                save()
                            end
                            
                            imgui.Spacing()
                            if imgui.Checkbox("Activar Hit efects", checkboxes.enabledHitEfects) then
                                ini.main.hitefects = checkboxes.enabledHitEfects[0]
                                save()
                            end
                            imgui.Spacing()
                            imgui.Text("Color de los numeros")
                            imgui.SameLine(250)
                            if imgui.ColorEdit4("##hitEfectsColor", hitEfectsColor, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                                ini.colors.hit2r = tonumber(string.format("%.2f", hitEfectsColor[0]))
                                ini.colors.hit2g = tonumber(string.format("%.2f", hitEfectsColor[1]))
                                ini.colors.hit2b = tonumber(string.format("%.2f", hitEfectsColor[2]))
                                ini.colors.hit2a = tonumber(string.format("%.2f", hitEfectsColor[3]))
                                save()
                            end

                        imgui.PopStyleColor()
                    imgui.EndChild()

                end

			 elseif navigations.activeTab.home[0] == 4 then

				imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowSize().x / 90, imgui.GetCursorPosY() + 8))
				imgui.PushFont(font1)
				imgui.TextColored(imgui.ImVec4(ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a), "SONIDOS")
				imgui.PopFont()
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
				
				imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX(), imgui.GetCursorPosY() + 5))
				imgui.BeginChild("##rightmenugg", imgui.ImVec2(imgui.GetWindowSize().x - 20, imgui.GetWindowSize().y - 110), true)
				imgui.PopStyleColor(1)

				imgui.PushFont(font2)
				imgui.Spacing()
				imgui.Spacing()
				if imgui.Checkbox("Activar Ultimate Genrl", checkboxes.ugenrl_enable) then
					ini.ugenrl_main.enable = checkboxes.ugenrl_enable[0]
					save()
				end		
				
				if checkboxes.ugenrl_enable[0] then

                imgui.SetCursorPosX(imgui.GetCursorPos().x+6)
                imgui.MainBox("Parametros UGenrl", imgui.ImVec2(440,300), 0)
                        local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
                        local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
                        imgui.PushFont(font1)
                        imgui.PushStyleColor(imgui.Col.Text, col1)
                        imgui.Text("Parámetros Ultimate Genrl")
                        imgui.PopStyleColor()
                        imgui.PopFont()
                        imgui.Spacing()
                        imgui.PushStyleColor(imgui.Col.Text, col2)

                            if imgui.Checkbox("Sonidos de disparo del jugador", checkboxes.weapon_checkbox) then
                                ini.ugenrl_main.weapon = checkboxes.weapon_checkbox[0]
                                save()
                            end
                            --[[imgui.SameLine()
                            if imgui.Checkbox("Sonidos del juego", checkboxes.autonosounds) then
                                ini.ugenrl_main.autonosounds = checkboxes.autonosounds[0]
                                save()
                            end]]
                            imgui.Spacing()
                            if imgui.Checkbox("Sonidos de disparo del enemigo", checkboxes.enemyweapon_checkbox) then
                                ini.ugenrl_main.enemyWeapon = checkboxes.enemyweapon_checkbox[0]
                                save()
                            end
                            imgui.Spacing()
                            if imgui.Checkbox("Sonido de hitsounds", checkboxes.hit_checkbox) then
                                ini.ugenrl_main.hit = checkboxes.hit_checkbox[0]
                                save()
                            end
                            imgui.Spacing()
                            if imgui.Checkbox("Sonidos de dolor", checkboxes.pain_checkbox) then
                                ini.ugenrl_main.pain = checkboxes.pain_checkbox[0]
                                save()
                            end
                        
                            imgui.Text("El sonido de los jugadores:")
                            if imgui.CustomSlider("##Alcance del sonido", sliders.enemyweapon_dist, 1, 70, "%d Metros", 180) then
                                ini.ugenrl_main.enemyWeaponDist = sliders.enemyweapon_dist[0]
                                save()
                            end
                            
                            imgui.SetCursorPos(imgui.ImVec2(300, 45))
                            
                        imgui.PopStyleColor()
                    imgui.EndChild()
                            
                    imgui.SameLine()
                    imgui.MainBox("Volumen", imgui.ImVec2(500,300), 0)
                        local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
                        local col2 = imgui.ImVec4(0.0, 0.0, 0.0, 1.0)
                        imgui.PushFont(font1)
                        imgui.PushStyleColor(imgui.Col.Text, col1)
                        imgui.Text("Volumen")
                        imgui.PopStyleColor()
                        imgui.PopFont()
                        imgui.PushFont(font2)
                        imgui.Spacing()
                        imgui.PushStyleColor(imgui.Col.Text, col2)
                        imgui.SameLine(nil, 10)
                        imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX(), imgui.GetCursorPosY() + 15))
                        if imgui.Volume("##Volumen de disparo##1", sliders.weapon_volume, 0.01, 1.00, "Armas: %.2f") then
                            ini.ugenrl_volume.weapon = ("%.2f"):format(sliders.weapon_volume[0])
                            save()
                        end

                        imgui.SameLine(nil, 80)
                        if imgui.Volume("##Volumen de golpes##1",sliders.hit_volume, 0.01, 1.00, "Hitsound: %.2f") then
                            ini.ugenrl_volume.hit = ("%.2f"):format(sliders.hit_volume[0])
                            save()
                        end
                        imgui.SameLine(nil, 80)
                        if imgui.Volume("##Volumen de dolor##1", sliders.pain_volume, 0.01, 1.00, "Dolor: %.2f") then
                            ini.ugenrl_volume.pain = ("%.2f"):format(sliders.pain_volume[0]) 
                            save()
                        end
                            
                        imgui.PopStyleColor()
                    imgui.EndChild()

                    local weapons = {
                        { "Deagle", 24, deagleSounds, "selected_deagle" },
                        { "Shotgun", 25, shotgunSounds, "selected_shotgun" },
                        { "M4", 31, m4Sounds, "selected_m4" },
                        { "Rifle", 33, rifleSounds, "selected_rifle" },
                        { "Sniper", 34, sniperSounds, "selected_sniper" },
                        { "MP5", 29, mp5Sounds, "selected_mp5" },
                        { "UZI", 28, uziSounds, "selected_uzi" },
                        { "Silenciada", 23, sdpistolSounds, "selected_sdp" },
                        { "AK-47", 30, AKSounds, "selected_ak47" },
                        { "Colt-45", 22, colt45Sounds, "selected_colt45" },
                        { "Recortada", 26, SawnoffShotgunounds, "Sawnoff" },
                        { "EDC", 27, edcSounds, "selected_edc" },
                        { "Hit", "hit", hitSounds, "selected_hit", ini.ugenrl_volume.hit },
                        { "Dolor", "pain", painSounds, "selected_pain", ini.ugenrl_volume.pain },
                    }

                    local soundConfigs = {}

                    for _, w in ipairs(weapons) do
                        table.insert(soundConfigs, {
                            label = w[1],
                            weaponId = w[2],
                            soundTable = w[3],
                            selectedVar = w[4],
                            volume = w[5] or ini.ugenrl_volume.weapon
                        })
                    end

                    imgui.SoundGrid(soundConfigs)
				end

			elseif navigations.activeTab.home[0] == 5 then
				
				 imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowSize().x / 90, imgui.GetCursorPosY() + 8))
                        imgui.PushFont(font1)
                        imgui.TextColored(imgui.ImVec4(ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a), "COMANDOS")
                        imgui.PopFont()
                        imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0)) 

						imgui.BeginChild("##rightmenugg", imgui.ImVec2(imgui.GetWindowSize().x - 20, imgui.GetWindowSize().y - 85), true)
                            imgui.PopStyleColor(1)
                            imgui.SetCursorPosX(10)
                            imgui.PushItemWidth(130)
                            imgui.Indent(10)

                            for label, v in orderedPairs(imguiInputsCmdEditor) do
                                if imgui.InputText("##" .. v.cfg, v.var, sizeof(v.var)) then
                                    local cmd = string.lower(str(v.var))
                                    ini.commands[v.cfg] = cmd
                                    save()
                                end
                                imgui.SameLine()
                                imgui.SetCursorPosX(imgui.GetCursorPosX() + 20) 
                                imgui.Text(label)
                                imgui.Dummy(imgui.ImVec2(0, 4))
                            end
                            imgui.Unindent(10)
                            imgui.PopItemWidth()

                        imgui.EndChild()

			elseif navigations.activeTab.home[0] == 6 then

				imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowSize().x / 90, imgui.GetCursorPosY() + 8))
				imgui.PushFont(font1)
				imgui.TextColored(imgui.ImVec4(ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a), "DISEÑO")
				imgui.PopFont()
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0)) -- aqu�
			
				imgui.BeginChild("##rightmenugg", imgui.ImVec2(imgui.GetWindowSize().x - 20, imgui.GetWindowSize().y - 85), true)
				imgui.PopStyleColor(1)

				imgui.MainBox("Colores del menu principal", imgui.ImVec2(400,500), 0)
                    local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
                    local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
                    imgui.PushFont(font1)
                    imgui.PushStyleColor(imgui.Col.Text, col1)
                    imgui.Text("Menú principal")
                    imgui.PopStyleColor()
                    imgui.PopFont()
                    imgui.Spacing()
                    imgui.PushStyleColor(imgui.Col.Text, col2)
                    imgui.PushFont(font2)
                    imgui.Text("Color de fondo:") imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##WindowBG", icolors.WindowBG,  imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.WindowBG.r, ini.WindowBG.g, ini.WindowBG.b, ini.WindowBG.a = tonumber(("%.3f"):format(icolors.WindowBG[0])), tonumber(("%.3f"):format(icolors.WindowBG[1])), tonumber(("%.3f"):format(icolors.WindowBG[2])), tonumber(("%.3f"):format(icolors.WindowBG[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    imgui.Text("Color principal:") imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##BaseColor", icolors.BaseColor,  imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, ini.BaseColor.a = tonumber(("%.3f"):format(icolors.BaseColor[0])), tonumber(("%.3f"):format(icolors.BaseColor[1])), tonumber(("%.3f"):format(icolors.BaseColor[2])), tonumber(("%.3f"):format(icolors.BaseColor[3]))
                        save()
                        SwitchTheStyle("change")
                    end
    
                    
                    imgui.Text("Color superior:") imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##ColorTop", icolors.ColorTop,  imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.ColorTop.r, ini.ColorTop.g, ini.ColorTop.b, ini.ColorTop.a = tonumber(("%.3f"):format(icolors.ColorTop[0])), tonumber(("%.3f"):format(icolors.ColorTop[1])), tonumber(("%.3f"):format(icolors.ColorTop[2])), tonumber(("%.3f"):format(icolors.ColorTop[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    imgui.Text("Color del texto:") imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##ColorText", icolors.ColorText, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a = tonumber(("%.3f"):format(icolors.ColorText[0])), tonumber(("%.3f"):format(icolors.ColorText[1])), tonumber(("%.3f"):format(icolors.ColorText[2])), tonumber(("%.3f"):format(icolors.ColorText[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    imgui.Text("Color del logotipo:") imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##LogoColor", icolors.LogoColor, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.logocolor.r, ini.logocolor.g, ini.logocolor.b, ini.logocolor.a = tonumber(("%.3f"):format(icolors.LogoColor[0])), tonumber(("%.3f"):format(icolors.LogoColor[1])), tonumber(("%.3f"):format(icolors.LogoColor[2])), tonumber(("%.3f"):format(icolors.LogoColor[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    imgui.Text("Color del título:") imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##BeginColor", icolors.BeginColor, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a = tonumber(("%.3f"):format(icolors.BeginColor[0])), tonumber(("%.3f"):format(icolors.BeginColor[1])), tonumber(("%.3f"):format(icolors.BeginColor[2])), tonumber(("%.3f"):format(icolors.BeginColor[3]))
                        save()
                    end
                    imgui.Text("Color del marco del menú:") imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##colorchildmenu", icolors.ColorChildMenu,  imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.ColorChildMenu.r, ini.ColorChildMenu.g, ini.ColorChildMenu.b, ini.ColorChildMenu.a = tonumber(("%.3f"):format(icolors.ColorChildMenu[0])), tonumber(("%.3f"):format(icolors.ColorChildMenu[1])), tonumber(("%.3f"):format(icolors.ColorChildMenu[2])), tonumber(("%.3f"):format(icolors.ColorChildMenu[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    if imgui.Checkbox('Mostrar marco en el menú', checkboxes.borderchild_draw) then
                        ini.borderchild.draw = not ini.borderchild.draw
                        save()
                    end
                    imgui.Text("Color de caja:") 
                    imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##Color mainboxcolor", icolors.mainBoxColor, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.mainBoxColor.r, ini.mainBoxColor.g, ini.mainBoxColor.b, ini.mainBoxColor.a = tonumber(("%.3f"):format(icolors.mainBoxColor[0])), tonumber(("%.3f"):format(icolors.mainBoxColor[1])), tonumber(("%.3f"):format(icolors.mainBoxColor[2])), tonumber(("%.3f"):format(icolors.mainBoxColor[3]))
                        save() 
                    end
                    imgui.Text("Color de la tapa de la caja:")
                    imgui.SameLine()
                    imgui.SetCursorPosX(350)
                    if imgui.ColorEdit4("##Color mainboxcolorUP", icolors.mainBoxColorUP, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.mainBoxColorUP.r, ini.mainBoxColorUP.g, ini.mainBoxColorUP.b, ini.mainBoxColorUP.a = tonumber(("%.3f"):format(icolors.mainBoxColorUP[0])), tonumber(("%.3f"):format(icolors.mainBoxColorUP[1])), tonumber(("%.3f"):format(icolors.mainBoxColorUP[2])), tonumber(("%.3f"):format(icolors.mainBoxColorUP[3]))
                        save() 
                    end
                        
                    imgui.PopStyleColor()
                imgui.EndChild()
                imgui.SameLine()
                imgui.SetCursorPosX(imgui.GetCursorPos().x+30)
                imgui.MainBox("Colores de la barra de navegacion", imgui.ImVec2(500,500), 0)
                    imgui.PushFont(font1)
                    local col1 = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
                    local col2 = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
                    
                    imgui.PushStyleColor(imgui.Col.Text, col1)
                    imgui.Text("Navegación")
                    imgui.PopStyleColor()
                    imgui.PopFont()
                    imgui.Spacing()
                    imgui.PushStyleColor(imgui.Col.Text, col2)
                    imgui.PushFont(font2)

                    imgui.Text("Color del panel:") imgui.SameLine()
                    imgui.SetCursorPosX(450)
                    if imgui.ColorEdit4("##ColorNavi", icolors.ColorNavi,  imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a = tonumber(("%.3f"):format(icolors.ColorNavi[0])), tonumber(("%.3f"):format(icolors.ColorNavi[1])), tonumber(("%.3f"):format(icolors.ColorNavi[2])), tonumber(("%.3f"):format(icolors.ColorNavi[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    imgui.Text("Pestaña activa (arriba a la izquierda):") imgui.SameLine()
                    imgui.SetCursorPosX(450)
                    if imgui.ColorEdit4("##Color Panel Left Up", icolors.PLeftUp, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.PLeftUp.r, ini.PLeftUp.g, ini.PLeftUp.b, ini.PLeftUp.a = tonumber(("%.3f"):format(icolors.PLeftUp[0])), tonumber(("%.3f"):format(icolors.PLeftUp[1])), tonumber(("%.3f"):format(icolors.PLeftUp[2])), tonumber(("%.3f"):format(icolors.PLeftUp[3]))
                        save() 
                    end
                    imgui.Text("Pestaña activa (abajo a la izquierda):")  imgui.SameLine()
                    imgui.SetCursorPosX(450)

                    if imgui.ColorEdit4("##Color Panel Left Down", icolors.PLeftDown, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.PLeftDown.r, ini.PLeftDown.g, ini.PLeftDown.b, ini.PLeftDown.a = tonumber(("%.3f"):format(icolors.PLeftDown[0])), tonumber(("%.3f"):format(icolors.PLeftDown[1])), tonumber(("%.3f"):format(icolors.PLeftDown[2])), tonumber(("%.3f"):format(icolors.PLeftDown[3]))
                        save() 
                    end
                    imgui.Text("Pestaña activa (arriba a la derecha):") imgui.SameLine()
                    imgui.SetCursorPosX(450)

                    if imgui.ColorEdit4("##Color Panel Right Up", icolors.PRightUp, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.PRightUp.r, ini.PRightUp.g, ini.PRightUp.b, ini.PRightUp.a = tonumber(("%.3f"):format(icolors.PRightUp[0])), tonumber(("%.3f"):format(icolors.PRightUp[1])), tonumber(("%.3f"):format(icolors.PRightUp[2])), tonumber(("%.3f"):format(icolors.PRightUp[3]))
                        save() 
                    end
                    imgui.Text("Pestaña activa (abajo a la derecha):")  imgui.SameLine()
                    imgui.SetCursorPosX(450)

                    if imgui.ColorEdit4("##Color Panel Right Down", icolors.PRightDown, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.PRightDown.r, ini.PRightDown.g, ini.PRightDown.b, ini.PRightDown.a = tonumber(("%.3f"):format(icolors.PRightDown[0])), tonumber(("%.3f"):format(icolors.PRightDown[1])), tonumber(("%.3f"):format(icolors.PRightDown[2])), tonumber(("%.3f"):format(icolors.PRightDown[3]))
                        save() 
                    end
                    imgui.Text("Color de texto activo:")  imgui.SameLine()
                    imgui.SetCursorPosX(450)

                    if imgui.ColorEdit4("##ActiveText", icolors.ActiveText,  imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.ActiveText.r, ini.ActiveText.g, ini.ActiveText.b, ini.ActiveText.a = tonumber(("%.3f"):format(icolors.ActiveText[0])), tonumber(("%.3f"):format(icolors.ActiveText[1])), tonumber(("%.3f"):format(icolors.ActiveText[2])), tonumber(("%.3f"):format(icolors.ActiveText[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    imgui.Text("Color de texto pasivo:")  imgui.SameLine()
                    imgui.SetCursorPosX(450)

                    if imgui.ColorEdit4("##PassiveText", icolors.PassiveText, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.NoInputs) then
                        ini.PassiveText.r, ini.PassiveText.g, ini.PassiveText.b, ini.PassiveText.a = tonumber(("%.3f"):format(icolors.PassiveText[0])), tonumber(("%.3f"):format(icolors.PassiveText[1])), tonumber(("%.3f"):format(icolors.PassiveText[2])), tonumber(("%.3f"):format(icolors.PassiveText[3]))
                        save()
                        SwitchTheStyle("change")
                    end
                    imgui.PopStyleColor()
                imgui.EndChild()

			elseif navigations.activeTab.home[0] == 7 then

				imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowSize().x / 90, imgui.GetCursorPosY() + 8))
				imgui.PushFont(font1)
				imgui.TextColored(imgui.ImVec4(ini.BeginColor.r, ini.BeginColor.g, ini.BeginColor.b, ini.BeginColor.a), "CONFIGURACIÓN")
				imgui.PopFont()
				imgui.PushFont(font2)
				
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
				imgui.PushStyleColor(imgui.Col.Border, ini.borderchild.draw and imgui.GetStyle().Colors[imgui.Col.PlotHistogram] or imgui.ImVec4(0,0,0,0))  
				
				for i, title in ipairs(navigations.settings) do
					if HeaderButton(navigations.current_settings  == i, title) then
						navigations.current_settings  = i
					end
					if i ~= #navigations.settings  then
						imgui.SameLine(nil, 20)
					end
				end
				imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX(), imgui.GetCursorPosY() + 5))
				imgui.BeginChild("##rightmenudd", imgui.ImVec2(imgui.GetWindowSize().x - 20,imgui.GetWindowSize().y - 120), true)
				imgui.PopStyleColor(2)
				
					if navigations.current_settings == 1 then

						imgui.CustomSlider("##alpha", sliders.opacityLevel, 0.1, 1, "%.2f", 180)
							
						imgui.Spacing()
						if imgui.CustomSlider("##imguiItemsScale", sliders.fontSizeScale, 0.5, 1, "Tamaño de los items %.2f", 180) then
							ini.settings.imguiItemsScale = sliders.fontSizeScale[0]
							save()
						end
						imgui.NewLine()
						
						if imgui.Button(fa.REPEAT.. "##reload", imgui.ImVec2(60, 50)) then
							thisScript():reload()
						end
						
                        --[[imgui.SameLine()
                        if imgui.Button(fa.POWER_OFF.. "##unload", imgui.ImVec2(60, 50))  then
                            script_unload()
                        end]]
                        imgui.SameLine()
						if not ini.settings.autosave then
							if imgui.Button(fa.FLOPPY_DISK.. "##save", imgui.ImVec2(60, 50)) then
								inicfg.save(ini, directIni)
								imgui.Notify(script_name.." {FFFFFF}Configuracion {dc4747}guardada.", 5000, 520)
							end
						end
						imgui.PopFont()
						
					elseif navigations.current_settings == 2 then
						
						if imgui.Checkbox("Notificaciones del script", checkboxes.notify) then
							ini.settings.notify = checkboxes.notify[0]
							save()
							imgui.Notify(ini.settings.notify and script_name.." {FFFFFF}Notificaciones {88aa62}activadas" or script_name.." {FFFFFF}Notificaciones {dc4747}desactivadas", 3000)
						end	
						imgui.Spacing()
						if ini.settings.notify then
							if imgui.Checkbox("Notificaciones en pantalla en lugar de texto en el chat", checkboxes.notifyScreen) then
								ini.settings.notifyScreen = checkboxes.notifyScreen[0]
								save()
								imgui.Notify(ini.settings.notifyScreen and script_name.." {FFFFFF}Notificaciones {88aa62}activadas" or script_name.." {FFFFFF}Notificaciones en pantalla {dc4747}desactivadas", 3000, 450)
							end	
						end
						imgui.Spacing()
						if imgui.Checkbox("Guardar automáticamente", new.bool(ini.settings.autosave)) then
							ini.settings.autosave = not ini.settings.autosave
							inicfg.save(ini, directIni)
						end

                        imgui.Spacing()
                        if imgui.Checkbox("AutoReconectar", checkboxes.autoReconnect) then
                            ini.settings.autoReconnect = checkboxes.autoReconnect[0]
                            save()
                        end	

						imgui.Spacing()

						if imgui.Checkbox("Mostrar botón flotante del menú", checkboxes.menubutton_checkbox) then
							ini.button.showmenubutton = checkboxes.menubutton_checkbox[0]
							UI.btnmenu[0] = checkboxes.menubutton_checkbox[0]
							save()
						end

						if checkboxes.menubutton_checkbox[0] then
							imgui.Spacing()
							if imgui.Button("Configurar botón flotante", imgui.ImVec2(-1, 35)) then
								UI.settingsbtn[0] = not UI.settingsbtn[0]
							end
						end
					end
			end

        imgui.EndChild()
        imgui.End()
        imgui.PopStyleVar()
    end
)

----------------------------------------------------- [Functions] ----------------------------------------------------------

-------------------Autoreconect-------------------

local isConnected = false
local lastPacketTime = os.clock()
local reconnectInProgress = false
local lastReconnectTime = 0
local RECONNECT_COOLDOWN = 10

function monitorConnection()
    if not ini.settings.autoReconnect then return end

    local currentTime = os.clock()

    if sampIsLocalPlayerSpawned() then
        isConnected = true
        lastPacketTime = currentTime
        reconnectInProgress = false
        return
    end
    
    if isConnected and (currentTime - lastPacketTime) > 10 then
        imgui.Notify(script_name.." {FFFFFF}Conexion perdida detectada", 3000)
        handleDisconnection()
    end
end

function handleDisconnection()
    if reconnectInProgress then
        return
    end
    
    local currentTime = os.clock()
    
    if (currentTime - lastReconnectTime) < RECONNECT_COOLDOWN then
        -- local remainingTime = RECONNECT_COOLDOWN - (currentTime - lastReconnectTime)
        -- sampAddChatMessage("Esperando cooldown: " .. math.floor(remainingTime) .. " segundos", 0xFFFF00)
        return
    end
    
    isConnected = false
    reconnectInProgress = true
    lastReconnectTime = currentTime
    
    lua_thread.create(function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sf.PACKET_DISCONNECTION_NOTIFICATION)
        raknetSendBitStreamEx(bs, sf.SYSTEM_PRIORITY, sf.RELIABLE, 0)
        raknetDeleteBitStream(bs)
        
        wait(2000)
        
        performReconnection()
    end)
end

function performReconnection()
    imgui.Notify(script_name.." {FFFFFF}Reconectando...", 3000)
    
    local bs = raknetNewBitStream()
    raknetEmulPacketReceiveBitStream(sf.PACKET_CONNECTION_LOST, bs)
    raknetDeleteBitStream(bs)
    
    lua_thread.create(function()
        while reconnectInProgress do
            wait(500)
            
            if sampIsLocalPlayerSpawned() then
                isConnected = true
                reconnectInProgress = false
                break
            end
        end
    end)
end

function onReceivePacket(id, bs)
    if not ini.settings.autoReconnect then return end
    if id == sf.PACKET_CONNECTION_LOST or id == sf.PACKET_DISCONNECTION_NOTIFICATION then
        imgui.Notify(script_name.." {FFFFFF}Desconexion detectada", 3000)
        handleDisconnection()
    end
    
    lastPacketTime = os.clock()
end

-------------------
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs(t) do
        table.insert( orderedIndex, key )
    end
    table.sort( orderedIndex )
    return orderedIndex
end

function orderedNext(t, state)
    local key = nil
    if state == nil then
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        for i = 1,table.getn(t.__orderedIndex) do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end
    if key then
        return key, t[key]
    end
    t.__orderedIndex = nil
    return
end
function orderedPairs(t)
    return orderedNext, t, nil
end
------------------

function onTouch(type, id, x, y)
    if chpos and id == 0 then
        local x = x / sw
        local y = y / sh

        ini.main.miraposx = x
        ini.main.miraposy = y
        save()
        sliders.miraPosX[0] = ini.main.miraposx
        sliders.miraPosY[0] = ini.main.miraposy

        chpos = false
        UI.croshair[0] = not UI.croshair[0]
    end
    if btnpos and id == 0 then
 
        ini.button.menubutton_x = x
        ini.button.menubutton_y = y
        save()
        sliders.buttonPosX[0] = ini.button.menubutton_x
        sliders.buttonPosY[0] = ini.button.menubutton_y
        btnpos = false
        UI.settingsbtn[0] = not UI.settingsbtn[0]
    end
end

function msgPrint(flag)
    lua_thread.create(function()
        while _G[flag] do
            printStringNow("Toca la pantalla", 1000)
            wait(950)
        end
    end)
end

------------------

function gotofunc(fnc)
    if fnc == "GTATime" or fnc == "all" then
		if ini.settings.hours ~= -1 and not ini.settings.blocktime then
        setTimeOfDay(ini.settings.hours, ini.settings.min)
		end
    end

    if fnc == "GTAWeather" or fnc == "all" then
        if ini.settings.weather ~= -1 and not ini.settings.blockweather then
			forceWeatherNow(ini.settings.weather)
		else
			forceWeatherNow(0)
		end
    end

    if fnc == "Fov" or fnc == "all" then

        if sliders.fov[0] == 70 or not ini.settings.fov_status then
            is_fov_modified = false
        else
            is_fov_modified = true
        end

        local fov_mode = ini.settings.fov_mode or 0

        if is_fov_modified and (fov_mode == 0 or (fov_mode == 1 and not isCharInAnyCar(PLAYER_PED)) or (fov_mode == 2 and isCharInAnyCar(PLAYER_PED))) then
            if isCurrentCharWeapon(PLAYER_PED, 34) and isCharPlayingAnim(PLAYER_PED, "gun_stand") then
                if isWidgetPressed(WIDGET_ZOOM_IN) then
                    zoom_offset = zoom_offset + 6

                    if zoom_offset > 10 + sliders.fov[0] then
                        zoom_offset = 10 + sliders.fov[0]
                    end
                elseif isWidgetPressed(WIDGET_ZOOM_OUT) then
                    zoom_offset = zoom_offset - 4.5

                    if zoom_offset < 0 then
                        zoom_offset = 0
                    end
                end

                cameraSetLerpFov(sliders.fov[0] - zoom_offset, sliders.fov[0] - zoom_offset, 1000, true)
            else
                reduction_factor = zoom_offset / 10
                zoom_offset = zoom_offset - reduction_factor

                if zoom_offset < 0 then
                    zoom_offset = 0
                end

                cameraSetLerpFov(sliders.fov[0] - zoom_offset, sliders.fov[0] - zoom_offset, 1000, true)
            end
        end

    end

    if fnc == "GivemeDist" or fnc == "all" then
		if ini.settings.givemedist then
			setCameraRenderDistance(ini.settings.drawdist)
		end
    end

    if fnc == "Ai-Sens" or fnc == "all" then
		setSensitivity(ini.settings.camera)
    end

    if fnc == "AdjustCrosshair" then
        adjustCrosshairToAspectRatio()
    end
	if fnc == "OpenMenu" then
        UI.main[0] = not UI.main[0]
	end
end

--------------[UGENRL]--------------
 
local soundDirectory = resourceDir .. "/GENRL/"
 
local weaponDirs = {
    Colt45 = "Colt-45",
    SDPistol = "SDPistol",
    Deagle = "Deagle",
    Shotgun = "Shotgun",
    CombatShotgun = "EDC",
    SawnoffShotgun = "Sawnoff-Shotgun",
    Rifle = "Rifle",
    M4 = "M4",
    MP5 = "MP5",
    Uzi = "Uzi",
    Minigun = "Minigun",
    Sniper = "Sniper",
    TEC9 = "TEC-9",
    AK = "AK-47",
    RPG = "RPG",
    Bell = "Bell",
    Pain = "Pain",
    Explosion = "Explosion"
}

 
function getFilesFromDirectory(directory)
    local files = {}
    for file in lfs.dir(directory) do
        if file ~= "." and file ~= ".." then
            table.insert(files, file)
        end
    end
    return files
end

 
function loadSounds()
    for name, path in pairs(weaponDirs) do
        local dirPath = soundDirectory .. path
        if not doesDirectoryExist(dirPath) then
            createDirectory(dirPath)
        end
    end

    colt45Sounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Colt45"])
    sdpistolSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["SDPistol"])
    deagleSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Deagle"])
    shotgunSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Shotgun"])
    rifleSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Rifle"])
    sniperSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Sniper"])
    m4Sounds = getFilesFromDirectory(soundDirectory .. weaponDirs["M4"])
    mp5Sounds = getFilesFromDirectory(soundDirectory .. weaponDirs["MP5"])
    uziSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Uzi"])
    MinigunSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Minigun"])
    AKSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["AK"])
    hitSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Bell"])
    painSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Pain"])
    explSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["Explosion"])
    edcSounds = getFilesFromDirectory(soundDirectory .. weaponDirs["CombatShotgun"])
    SawnoffShotgunounds = getFilesFromDirectory(soundDirectory .. weaponDirs["SawnoffShotgun"])
end


function changeSound(id, name, vol)
    playSound(name, vol)
    ini.ugenrl_sounds[id] = name
    save()
end

 
function getNumberSounds(id, name)
    for i, v in ipairs(name) do
        if v == ini.ugenrl_sounds[id] then
            return i
        end
    end
    return false
end


function playSound(soundFile, soundVol, charHandle)

    if not soundFile then return false end

    local filePath = nil
    for _, folder in pairs(weaponDirs) do
        local possiblePath = soundDirectory .. folder .. "/" .. soundFile
        if doesFileExist(possiblePath) then
            filePath = possiblePath
            break
        end
    end

    if not filePath then return false end

    if audio then collectgarbage() end
    if charHandle == nil then
        audio = loadAudioStream(filePath)
    else
        audio = load3dAudioStream(filePath)
        setPlay3dAudioStreamAtChar(audio, charHandle)
    end
    setAudioStreamVolume(audio, soundVol)
    setAudioStreamState(audio, 1)
    clearSound(audio)
end

 
function clearSound(audio)
    lua_thread.create(function()
        while getAudioStreamState(audio) == 1 do wait(50) end
        collectgarbage()
    end)
end


--------------[Comands]--------------
function onSendRpc(id, bs, priority, reliability, orderingChannel, shiftTs)
    if id == 50 then
        local cmd_len = raknetBitStreamReadInt32(bs)
        local cmd = raknetBitStreamReadString(bs, cmd_len)
        cmd = string.lower(cmd)
    
        if cmd:find("^"..ini.commands.openmenu.."$") then
            gotofunc("OpenMenu")
            return false
        elseif cmd:find("^"..ini.commands.settime.." .+") or cmd:find("^"..ini.commands.settime.."$")then
            local hours = tonumber(cmd:match(ini.commands.settime.." (%d+)"))
            local min = tonumber(cmd:match(ini.commands.settime.." %d+%s(%d+)"))
            if min == nil then min = 0 end
            if not ini.settings.blocktime then
                if type(hours) ~= 'number' or hours < 0 or hours > 23 or type(min) ~= 'number' or min < 0 or min > 59 then
                    imgui.Notify(script_name.." {FFFFFF}Utilice: {dc4747}" .. ini.commands.settime .. " [0-23 - horas] [0-59 - minutos]", 3000)
                    imgui.Notify(string.format(script_name.." {FFFFFF}Parametro actual: {dc4747}%02d:%02d", ini.settings.hours, ini.settings.min), 3000)
                    return false
                end

                if ini.settings.hours == hours and ini.settings.min == min then
                    imgui.Notify(script_name.." {FFFFFF}La hora ya esta establecida en {dc4747}" .. string.format("%02d:%02d", hours, min), 3000)
                    return false
                end

                ini.settings.hours = hours
                ini.settings.min = min
                save()
                sliders.hours[0] = ini.settings.hours
                sliders.min[0] = ini.settings.min
                imgui.Notify(string.format(script_name.." {FFFFFF}La Hora ha sido fijada en: {dc4747}%02d:%02d", hours, min), 3000)
            else 
                imgui.Notify(script_name.." {FFFFFF}Tienes prohibido cambiar la hora, ingresa: {dc4747}" ..ini.commands.blockservertime.. '', 3000)
            end
            if check_sampev then
                function sampev.onSetPlayerTime(r, s)
                    if ini.settings.hours ~= -1 then return false end
                    return {r, s}
                end
            end
            return false
        elseif cmd:find("^"..ini.commands.setweather.." .+") or cmd:find("^"..ini.commands.setweather.."$")then
            local weather = tonumber(cmd:match(ini.commands.setweather.." (.+)"))
            if not ini.settings.blockweather then
                if weather == nil or weather < 0 or weather > 45 then
                    imgui.Notify(script_name.." {FFFFFF}Utilice: {dc4747}" .. ini.commands.setweather .. " [0-45]", 3000)
                    imgui.Notify(string.format(script_name.." {FFFFFF}Parametro actual: {dc4747}%d", ini.settings.weather), 3000)
                    return false
                end

                if ini.settings.weather == weather then
                    imgui.Notify(script_name.." {FFFFFF}El clima ya esta establecido en: {dc4747}" .. weather, 3000)
                    return false
                end

                ini.settings.weather = weather
                save()
                sliders.weather[0] = weather
                imgui.Notify(string.format(script_name.." {FFFFFF}El clima se ha establecido a: {dc4747}%d", weather), 3000)
            else
                imgui.Notify(script_name.." {FFFFFF}Tienes prohibido cambiar el clima, ingresa: {dc4747}" ..ini.commands.blockserverweather.. '', 3000)
            end
            if check_sampev then
                function sampev.onSetWeather(z)
                    if ini.settings.weather ~= -1 then return false end
                    return {z}
                end
            end
            return false
        elseif cmd:find("^"..ini.commands.blockservertime.."$") then
            checkboxes.blocktime[0] = not checkboxes.blocktime[0]
            ini.settings.blocktime = checkboxes.blocktime[0]
            save()
            imgui.Notify(checkboxes.blocktime[0] and script_name.." {FFFFFF}Ahora el servidor {dc4747}no cambia {FFFFFF}su hora" or script_name.."Ahora el servidor {88aa62}cambia {FFFFFF}su hora", 3000)
            return false
        elseif cmd:find("^"..ini.commands.blockserverweather.."$") then
            checkboxes.blockweather[0] = not checkboxes.blockweather[0]
            ini.settings.blockweather = checkboxes.blockweather[0]
            save()
            imgui.Notify(checkboxes.blockweather[0] and script_name.." {FFFFFF}Ahora el servidor {dc4747}no cambia {FFFFFF}su clima" or script_name.."Ahora el servidor {88aa62}cambia {FFFFFF}su clima", 3000)
            return false
        elseif cmd:find("^"..ini.commands.clearchat.."$") then
            for i = 1, 15 do
                sampAddChatMessage("", -1)
            end
            return false
        elseif cmd:find("^"..ini.commands.togglechat.."$") then
            toggled_sm = not toggled_sm
            imgui.Notify(script_name.." {FFFFFF}Chat "..(toggled_sm and "{dc4747}Desactivado" or "{73b461}Activado"), 3000)
            if check_sampev then
                function blockChatMessages(color, text)
                    if toggled_sm then return false end
                end

                function sampev.onServerMessage(color, text)
                    return blockChatMessages(color, text)
                end
            end
            return false
        elseif cmd:find("^" .. ini.commands.reconect .. " .+") or cmd:find("^" .. ini.commands.reconect .. "$") then
            local time = tonumber(cmd:match(ini.commands.reconect .. " (%d+)")) or 0
            lua_thread.create(function()
                local ms = 500 + time * 1000
                if ms <= 0 then
                    ms = 100
                end

                while ms > 0 do
                    if ms <= 500 then
                        local bs = raknetNewBitStream()
                        raknetBitStreamWriteInt8(bs, sf.PACKET_DISCONNECTION_NOTIFICATION)
                        raknetSendBitStreamEx(bs, sf.SYSTEM_PRIORITY, sf.RELIABLE, 0)
                        raknetDeleteBitStream(bs)
                    end

                    printStringNow("Espera: ~g~" .. tostring(ms) .. "ms", 100)
                    wait(100)
                    ms = ms - 100
                end

                local bs = raknetNewBitStream()
                raknetEmulPacketReceiveBitStream(sf.PACKET_CONNECTION_LOST, bs)
                raknetDeleteBitStream(bs)
            end)
            return false
        elseif cmd:find("^"..ini.commands.ugenrl.."$") then
            checkboxes.ugenrl_enable[0] = not checkboxes.ugenrl_enable[0]
            ini.ugenrl_main.enable = checkboxes.ugenrl_enable[0]
            save()
            imgui.Notify(checkboxes.ugenrl_enable[0] and script_name.." {FFFFFF}Ultimate Genrl {73b461}Activado" or script_name.." {FFFFFF}Ultimate Genrl {dc4747}Desactivado", 3000)
            return false
        elseif cmd:find("^"..ini.commands.uds.." .+") or cmd:find("^"..ini.commands.uds.."$")then
            local param = tonumber(cmd:match(ini.commands.uds.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#deagleSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.uds.." [1-"..#deagleSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(24, deagleSounds), 3000)
            else
                changeSound(24, deagleSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de deagle ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.ums.." .+") or cmd:find("^"..ini.commands.ums.."$")then
            local param = tonumber(cmd:match(ini.commands.ums.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#m4Sounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.ums.." [1-"..#m4Sounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(31, m4Sounds), 3000)
            else
                changeSound(31, m4Sounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de m4 ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.uss.." .+") or cmd:find("^"..ini.commands.uss.."$")then
            local param = tonumber(cmd:match(ini.commands.uss.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#shotgunSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.uss.." [1-"..#shotgunSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(25, shotgunSounds), 3000)
            else
                changeSound(25, shotgunSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de escopeta ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.urs.." .+") or cmd:find("^"..ini.commands.urs.."$")then
            local param = tonumber(cmd:match(ini.commands.urs.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#rifleSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.urs.." [1-"..#rifleSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(33, rifleSounds), 3000)
            else
                changeSound(33, rifleSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de rifle ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.usps.." .+") or cmd:find("^"..ini.commands.usps.."$")then
            local param = tonumber(cmd:match(ini.commands.usps.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#sniperSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.usps.." [1-"..#sniperSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(34, sniperSounds), 3000)
            else
                changeSound(34, sniperSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de sniper ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.umps.." .+") or cmd:find("^"..ini.commands.umps.."$")then
            local param = tonumber(cmd:match(ini.commands.umps.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#mp5Sounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.umps.." [1-"..#mp5Sounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(29, mp5Sounds), 3000)
            else
                changeSound(29, mp5Sounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de mp5 ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.uuzi.." .+") or cmd:find("^"..ini.commands.uuzi.."$")then
            local param = tonumber(cmd:match(ini.commands.uuzi.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#uziSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.uuzi.." [1-"..#uziSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(28, uziSounds), 3000)
            else
                changeSound(28, uziSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de uzi ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.uaks.." .+") or cmd:find("^"..ini.commands.uaks.."$")then
            local param = tonumber(cmd:match(ini.commands.uaks.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#AKSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.uaks.." [1-"..#AKSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(30, AKSounds), 3000)
            else
                changeSound(30, AKSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de ak-47 ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.ucolt.." .+") or cmd:find("^"..ini.commands.ucolt.."$")then
            local param = tonumber(cmd:match(ini.commands.ucolt.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#colt45Sounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.ucolt.." [1-"..#colt45Sounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(22, colt45Sounds), 3000)
            else
                changeSound(22, colt45Sounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de colt-45 ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.uedc.." .+") or cmd:find("^"..ini.commands.uedc.."$")then
            local param = tonumber(cmd:match(ini.commands.uedc.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#edcSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.uedc.." [1-"..#edcSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds(27, edcSounds), 3000)
            else
                changeSound(27, edcSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de edc ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.ubs.." .+") or cmd:find("^"..ini.commands.ubs.."$")then
            local param = tonumber(cmd:match(ini.commands.ubs.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#hitSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.ubs.." [1-"..#hitSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds('hit', hitSounds), 3000)
            else
                changeSound('hit', hitSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de HitSound ajustado a: {dc4747}"..param, 3000)
            end
            return false
        elseif cmd:find("^"..ini.commands.ups.." .+") or cmd:find("^"..ini.commands.ups.."$")then
            local param = tonumber(cmd:match(ini.commands.ups.." (.+)"))
            if param == nil or param < 1 or param > tonumber(#painSounds) then
                imgui.Notify(script_name.." {FFFFFF}Usar: {dc4747}"..ini.commands.ups.." [1-"..#painSounds.."]", 3000)
                imgui.Notify(script_name.." {FFFFFF}Parametro actual: {dc4747}"..getNumberSounds('pain', painSounds), 3000)
            else
                changeSound('pain', painSounds[param], ini.ugenrl_volume.weapon)
                save()
                imgui.Notify(script_name.." {FFFFFF}Sonido de dolor ajustado a: {dc4747}"..param, 3000)
            end
            return false
        end
    end
end

---------------------- [IMGUI]----------------------

HeaderButton = function(bool, str_id)
    local DL = imgui.GetWindowDrawList()
    local ToU32 = imgui.ColorConvertFloat4ToU32
    local result = false
    local label = string.gsub(str_id, "##.*$", "")
    local duration = { 0.5, 0.3 }
    local cols = {
        idle = imgui.GetStyle().Colors[imgui.Col.TextDisabled],
        hovr = imgui.GetStyle().Colors[imgui.Col.Text],
        slct = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
    }

    if not AI_HEADERBUT then AI_HEADERBUT = {} end
     if not AI_HEADERBUT[str_id] then
        AI_HEADERBUT[str_id] = {
            color = bool and cols.slct or cols.idle,
            clock = os.clock() + duration[1],
            h = {
                state = bool,
                alpha = bool and 1.00 or 0.00,
                clock = os.clock() + duration[2],
            }
        }
    end
    local pool = AI_HEADERBUT[str_id]

    local degrade = function(before, after, start_time, duration)
        local result = before
        local timer = os.clock() - start_time
        if timer >= 0.00 then
            local offs = {
                x = after.x - before.x,
                y = after.y - before.y,
                z = after.z - before.z,
                w = after.w - before.w
            }

            result.x = result.x + ( (offs.x / duration) * timer )
            result.y = result.y + ( (offs.y / duration) * timer )
            result.z = result.z + ( (offs.z / duration) * timer )
            result.w = result.w + ( (offs.w / duration) * timer )
        end
        return result
    end

    local pushFloatTo = function(p1, p2, clock, duration)
        local result = p1
        local timer = os.clock() - clock
        if timer >= 0.00 then
            local offs = p2 - p1
            result = result + ((offs / duration) * timer)
        end
        return result
    end

    local set_alpha = function(color, alpha)
        return imgui.ImVec4(color.x, color.y, color.z, alpha or 1.00)
    end

    imgui.BeginGroup()
        local pos = imgui.GetCursorPos()
        local p = imgui.GetCursorScreenPos()
      
        imgui.TextColored(pool.color, label)
        local s = imgui.GetItemRectSize()
        local hovered = imgui.IsItemHovered()
        local clicked = imgui.IsItemClicked()
      
        if pool.h.state ~= hovered and not bool then
            pool.h.state = hovered
            pool.h.clock = os.clock()
        end
      
        if clicked then
            pool.clock = os.clock()
            result = true
        end

        if os.clock() - pool.clock <= duration[1] then
            pool.color = degrade(
                imgui.ImVec4(pool.color),
                bool and cols.slct or (hovered and cols.hovr or cols.idle),
                pool.clock,
                duration[1]
            )
        else
            pool.color = bool and cols.slct or (hovered and cols.hovr or cols.idle)
        end

        if pool.h.clock ~= nil then
            if os.clock() - pool.h.clock <= duration[2] then
                pool.h.alpha = pushFloatTo(
                    pool.h.alpha,
                    pool.h.state and 1.00 or 0.00,
                    pool.h.clock,
                    duration[2]
                )
            else
                pool.h.alpha = pool.h.state and 1.00 or 0.00
                if not pool.h.state then
                    pool.h.clock = nil
                end
            end

            local max = s.x / 2
            local Y = p.y + s.y + 3
            local mid = p.x + max

            DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid + (max * pool.h.alpha), Y), ToU32(set_alpha(pool.color, pool.h.alpha)), 3)
            DL:AddLine(imgui.ImVec2(mid, Y), imgui.ImVec2(mid - (max * pool.h.alpha), Y), ToU32(set_alpha(pool.color, pool.h.alpha)), 3)
        end

    imgui.EndGroup()
    return result
end


function imgui.CustomMenu(labels, selected, size, speed, centering)
    local bool = false
    speed = speed and speed or 0.500
    local radius = size.y * 0.50
    local draw_list = imgui.GetWindowDrawList()
    if LastActiveTime == nil then LastActiveTime = {} end
    if LastActive == nil then LastActive = {} end
    local function ImSaturate(f)
        return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
    end
    for i, v in ipairs(labels) do
        local c = imgui.GetCursorPos()
        local p = imgui.GetCursorScreenPos()
        if imgui.InvisibleButton(v..'##'..i, size) then
            selected[0] = i
            LastActiveTime[v] = os.clock()
            LastActive[v] = true
            bool = true
        end
        imgui.SetCursorPos(c)
        local t = selected[0] == i and 1.0 or 0.0
        if LastActive[v] then
            local time = os.clock() - LastActiveTime[v]
            if time <= 0.3 then
                local t_anim = ImSaturate(time / speed)
                t = selected[0] == i and t_anim or 1.0 - t_anim
            else
                LastActive[v] = false
            end
        end
        local col_bg = imgui.GetColorU32Vec4(selected[0] == i and imgui.ImVec4(0.10, 0.10, 0.10, 0.60) or imgui.ImVec4(0,0,0,0))
        local col_box = imgui.GetColorU32Vec4(selected[0] == i and imgui.ImVec4(ini.logocolor.r, ini.logocolor.g, ini.logocolor.b, ini.logocolor.a) or imgui.ImVec4(0,0,0,0))
        local col_hovered = imgui.GetStyle().Colors[imgui.Col.ButtonHovered]
        local col_hovered = imgui.GetColorU32Vec4(imgui.ImVec4(col_hovered.x, col_hovered.y, col_hovered.z, (imgui.IsItemHovered() and 0.2 or 0)))
        
        if selected[0] == i then draw_list:AddRectFilledMultiColor(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + t * size.x, p.y + size.y), imgui.GetColorU32Vec4(imgui.ImVec4(icolors.PLeftUp[0], icolors.PLeftUp[1], icolors.PLeftUp[2], icolors.PLeftUp[3])), imgui.GetColorU32Vec4(imgui.ImVec4(icolors.PRightUp[0], icolors.PRightUp[1], icolors.PRightUp[2], icolors.PRightUp[3])), imgui.GetColorU32Vec4(imgui.ImVec4(icolors.PRightDown[0], icolors.PRightDown[1], icolors.PRightDown[2], icolors.PRightDown[3])), imgui.GetColorU32Vec4(imgui.ImVec4(icolors.PLeftDown[0], icolors.PLeftDown[1], icolors.PLeftDown[2], icolors.PLeftDown[3]))) end
        draw_list:AddRectFilled(imgui.ImVec2(p.x-size.x/6, p.y), imgui.ImVec2(p.x + (radius * 0.65) + size.x, p.y + size.y), col_hovered, 0.0)
        imgui.SetCursorPos(imgui.ImVec2(c.x+(centering and (size.x-imgui.CalcTextSize(v).x)/2 or 15), c.y+(size.y-imgui.CalcTextSize(v).y)/2))
        if selected[0] == i then 
            imgui.TextColored(imgui.ImVec4(icolors.ActiveText[0], icolors.ActiveText[1], icolors.ActiveText[2], icolors.ActiveText[3]), v)
        else
            imgui.TextColored(imgui.ImVec4(icolors.PassiveText[0], icolors.PassiveText[1], icolors.PassiveText[2], icolors.PassiveText[3]), v)
        end
        draw_list:AddRectFilled(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x+3.5, p.y + size.y), col_box)
        imgui.SetCursorPos(imgui.ImVec2(c.x, c.y+size.y))
    end
    return bool
end

function imgui.SoundGrid(configs)
    local containerW, spacingY, scrollbar = 230, 10, 70
    local index = 1

    while index <= #configs do
        local availW = imgui.GetContentRegionAvail().x - scrollbar
        local perRow = math.max(1, math.floor(availW / containerW))
        local blocksLeft = #configs - index + 1
        local rowCount = math.min(perRow, blocksLeft)

        local spacingX = 0
        if perRow > 1 then
            spacingX = (availW - containerW * perRow) / (perRow - 1)
            local offsetX = (availW - (perRow * containerW + spacingX * (perRow - 1))) / 2
            imgui.SetCursorPosX(imgui.GetCursorPos().x + offsetX)
        end

        for i = 1, perRow do
            if i > 1 then imgui.SameLine(nil, spacingX) end

            if i <= rowCount then
                local cfg = configs[index]
                SoundBox(cfg.label, cfg.weaponId, cfg.soundTable, cfg.selectedVar, cfg.volume, cfg.idSuffix)
                index = index + 1
            else
                imgui.BeginChild("##empty_"..i.."_"..index, imgui.ImVec2(containerW, 0), false)
                imgui.EndChild()
            end
        end

        imgui.Spacing()
        imgui.Dummy(imgui.ImVec2(0, spacingY))
    end
end

function SoundBox(label, weaponId, soundTable, selectedIndexVar, volume, idSuffix)
    local id = idSuffix or label
    imgui.BeginChild('##container_'..id, imgui.ImVec2(250, 250), false)

    local hoveredColor = imgui.GetStyle().Colors[imgui.Col.FrameBgHovered]
    local textColor = imgui.ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)

    imgui.PushFont(font2)
    imgui.PushStyleColor(imgui.Col.Text, hoveredColor)
    imgui.Text(label)
    imgui.PopStyleColor()
    imgui.PopFont()
    imgui.Spacing()

    imgui.PushStyleColor(imgui.Col.Text, textColor)
    imgui.MainBox('##list_'..id, imgui.ImVec2(230, 210), true)

    local currentIndex = _G[selectedIndexVar]
    local defaultIndex = getNumberSounds(weaponId, soundTable)
    if currentIndex ~= defaultIndex then
        _G[selectedIndexVar] = defaultIndex
        currentIndex = defaultIndex
    end

    for i, v in ipairs(soundTable) do
        local name = v:gsub("%.mp3", ""):gsub("%.wav", "")
        if imgui.Selectable(i .. ". " .. name .. "##" .. i .. id, currentIndex == i) then
            changeSound(weaponId, soundTable[i], volume)
        end
    end

    imgui.EndChild()
    imgui.PopStyleColor()
    imgui.EndChild()
end


function imgui.MainBox(str_id, size, rounding)
    local ImVec2 = imgui.ImVec2
    local DL = imgui.GetWindowDrawList()
    local posS = imgui.GetCursorScreenPos()
    local title = str_id:gsub('##.+$', '')
    local sizeT = imgui.CalcTextSize(title)
    local bgColor = imgui.GetStyle().Colors[imgui.Col.Button]
    local bgColorHover = imgui.GetColorU32Vec4(imgui.ImVec4(bgColor.x, bgColor.y, bgColor.z, 0.7))
    local bgColorNormal = imgui.GetColorU32Vec4(imgui.ImVec4(bgColor.x, bgColor.y, bgColor.z, 0.7))

    imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0, 0, 0, 0))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, rounding)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
    
    local posE = ImVec2(posS.x + size.x, posS.y + size.y)
    local mousePos = imgui.GetMousePos()
    DL:AddRectFilledMultiColor(posS, imgui.ImVec2(posS.x+size.x, posS.y+size.y), imgui.GetColorU32Vec4(imgui.ImVec4(ini.mainBoxColorUP.r, ini.mainBoxColorUP.g, ini.mainBoxColorUP.b, ini.mainBoxColorUP.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.mainBoxColorUP.r, ini.mainBoxColorUP.g, ini.mainBoxColorUP.b, ini.mainBoxColorUP.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.mainBoxColor.r, ini.mainBoxColor.g, ini.mainBoxColor.b, ini.mainBoxColor.a)), imgui.GetColorU32Vec4(imgui.ImVec4(ini.mainBoxColor.r, ini.mainBoxColor.g, ini.mainBoxColor.b, ini.mainBoxColor.a)))
   
    imgui.BeginChild(str_id, size, true)
    imgui.PopStyleColor(2)
end

function imgui.Volume(str_id, value, min, max, format)
    imgui.SetCursorPos(imgui.ImVec2(imgui.GetCursorPosX() + 5, imgui.GetCursorPosY()))
    local radius_outer, radius_inner = 42, 22
    local p = imgui.GetCursorScreenPos()
    local centerX, centerY = p.x + radius_outer, p.y + radius_outer
    local DL = imgui.GetWindowDrawList()

    imgui.InvisibleButton(str_id, imgui.ImVec2(radius_outer * 2, radius_outer * 2))
    local isActive = imgui.IsItemActive()

    local norm_value = (value[0] - min) / (max - min)
    local angle = norm_value * 2 * math.pi

    if isActive and imgui.IsMouseDown(0) then
        local mouse_pos = imgui.GetMousePos()
        local dx, dy = mouse_pos.x - centerX, mouse_pos.y - centerY
        local mouse_angle = math.atan2(dy, dx) + math.pi / 2
        if mouse_angle < 0 then mouse_angle = mouse_angle + 2 * math.pi end
        if mouse_angle > 2 * math.pi then mouse_angle = 2 * math.pi end
        local new_value = mouse_angle / (2 * math.pi)
        value[0] = min + new_value * (max - min)
        angle = new_value * 2 * math.pi
    end

    DL:AddCircleFilled(imgui.ImVec2(centerX, centerY), radius_outer, imgui.GetColorU32(imgui.Col.FrameBgActive), 100)
    DL:AddCircleFilled(imgui.ImVec2(centerX, centerY), radius_inner, imgui.GetColorU32(imgui.Col.WindowBg), 100)
    DL:AddCircle(imgui.ImVec2(centerX, centerY), radius_outer, imgui.GetColorU32(imgui.Col.Text), 100, 2.0)

    local indicator_length = radius_outer - 10
    local indicator_x = centerX + math.cos(angle - math.pi / 2) * indicator_length
    local indicator_y = centerY + math.sin(angle - math.pi / 2) * indicator_length
    DL:AddLine(imgui.ImVec2(centerX, centerY), imgui.ImVec2(indicator_x, indicator_y), imgui.GetColorU32(imgui.Col.Text), 2.0)
    DL:AddCircleFilled(imgui.ImVec2(centerX, centerY), 5, imgui.GetColorU32(imgui.Col.Text), 100)

    local text_value = string.format(format, value[0])
    local text_size = imgui.CalcTextSize(text_value)
    local text_x = centerX - text_size.x / 2
    local text_y = p.y + radius_outer * 2 + 20
    local padding = 4
    DL:AddRectFilled(
        imgui.ImVec2(text_x - padding, text_y - padding),
        imgui.ImVec2(text_x + text_size.x + padding, text_y + text_size.y + padding),
        imgui.GetColorU32(imgui.Col.FrameBg), 0.0
    )
    DL:AddText(imgui.ImVec2(text_x, text_y), imgui.GetColorU32(imgui.Col.Text), text_value)

    return isActive
end


function imgui.CustomSlider(str_id, value, min, max, sformat, width)
    local width = width or 100
    local DL = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()

    local function bringVec4To(from, to, start_time, duration)
        local timer = os.clock() - start_time
        if timer <= duration then
            local count = timer / (duration / 100)
            return imgui.ImVec4(
                from.x + (count * (to.x - from.x) / 100),
                from.y + (count * (to.y - from.y) / 100),
                from.z + (count * (to.z - from.z) / 100),
                from.w + (count * (to.w - from.w) / 100)
            ), true
        end
        return to, false
    end

    UI_CUSTOM_SLIDER = UI_CUSTOM_SLIDER or {}
    UI_CUSTOM_SLIDER[str_id] = UI_CUSTOM_SLIDER[str_id] or {active = false, hovered = false, start = 0}

    imgui.InvisibleButton(str_id, imgui.ImVec2(width, 20))
    local isActive, isHovered = imgui.IsItemActive(), imgui.IsItemHovered()
    UI_CUSTOM_SLIDER[str_id].active, UI_CUSTOM_SLIDER[str_id].hovered = isActive, isHovered

    if isActive then
        if imgui.GetIO().KeyAlt then alt_active_slider_id = str_id else active_slider_id = str_id end
    else
        if active_slider_id == str_id then active_slider_id = nil end
        if alt_active_slider_id == str_id and not imgui.GetIO().KeyAlt then alt_active_slider_id = nil end
    end

    local colorPadding = bringVec4To(
        isHovered and imgui.ImVec4(0.3, 0.3, 0.3, 0.8) or imgui.ImVec4(0.95, 0.95, 0.95, 0.8),
        isHovered and imgui.ImVec4(0.95, 0.95, 0.95, 0.8) or imgui.ImVec4(0.3, 0.3, 0.3, 0.8),
        UI_CUSTOM_SLIDER[str_id].start, 0.2
    )

    local isAltPressed, mouseDown = imgui.GetIO().KeyAlt, imgui.IsMouseDown(0)
    local isInteger, step = (math.floor(min) == min) and (math.floor(max) == max), (max - min) / (width * 80)
    if isInteger then step = 1 end

    if ((str_id == active_slider_id and not isAltPressed) or (str_id == alt_active_slider_id and isAltPressed)) and mouseDown then
        local c, delta = imgui.GetMousePos(), imgui.GetIO().MouseDelta.x
        if isAltPressed then
            local v = value[0] + delta * step
            value[0] = math.max(min, math.min(max, isInteger and math.floor(v + 0.5) or v))
        else
            if c.x - p.x >= 0 and c.x - p.x <= width then
                local s, pr, step = c.x - p.x - 10, (c.x - p.x - 10) / (width - 20), (max - min) / (width * 100)
                local v = min + math.floor((max - min) * pr / step + 0.5) * step
                local v = min + (max - min) * pr
				v = tonumber(string.format("%.3f", v))
				if v < min then v = min end
				if v > max then v = max end
				value[0] = v

            end
        end
    end

    local posCircleX = p.x + 7.5 + (width - 10) / (max - min) * (value[0] - min)
    local eCol, brightness = imgui.GetStyle().Colors[imgui.Col.FrameBg], 0.2
    local triangleColor = imgui.ImVec4(eCol.x, eCol.y, eCol.z, 1.0)
    if isHovered then triangleColor = imgui.ImVec4(eCol.x + brightness, eCol.y + brightness, eCol.z + brightness, 1.0) end

    if (str_id == active_slider_id and isAltPressed) or (str_id == alt_active_slider_id and isAltPressed) then
        DL:AddRectFilledMultiColor(
            imgui.ImVec2(p.x, p.y + 7), imgui.ImVec2(p.x + width, p.y + 14), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button])
        )
        local arrowSize, halfArrowSize, midY, leftX, rightX = 10, 5, p.y + 10, p.x, p.x + width

        DL:AddLine(imgui.ImVec2(leftX, midY - halfArrowSize), imgui.ImVec2(leftX + arrowSize, midY), imgui.GetColorU32Vec4(triangleColor), 1)
        DL:AddLine(imgui.ImVec2(leftX, midY + halfArrowSize), imgui.ImVec2(leftX + arrowSize, midY), imgui.GetColorU32Vec4(triangleColor), 1)
        DL:AddLine(imgui.ImVec2(leftX, midY - halfArrowSize), imgui.ImVec2(leftX, midY + halfArrowSize), imgui.GetColorU32Vec4(triangleColor), 1)
        DL:AddLine(imgui.ImVec2(rightX, midY - halfArrowSize), imgui.ImVec2(rightX - arrowSize, midY), imgui.GetColorU32Vec4(triangleColor), 1)
        DL:AddLine(imgui.ImVec2(rightX, midY + halfArrowSize), imgui.ImVec2(rightX - arrowSize, midY), imgui.GetColorU32Vec4(triangleColor), 1)
        DL:AddLine(imgui.ImVec2(rightX, midY - halfArrowSize), imgui.ImVec2(rightX, midY + halfArrowSize), imgui.GetColorU32Vec4(triangleColor), 1)
    else
        DL:AddRectFilledMultiColor(
            imgui.ImVec2(p.x, p.y + 7), imgui.ImVec2(p.x + width, p.y + 18), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.FrameBg]), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.FrameBg]), 
            imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button])
        )
        drawTriangle(imgui.ImVec2(posCircleX - 11, p.y + 1), imgui.ImVec2(posCircleX + 6, p.y + 23), imgui.ImVec2(posCircleX, p.y + 8), imgui.GetColorU32Vec4(triangleColor), 2)
    end

    DL:AddText(imgui.ImVec2(p.x + width + 10, p.y), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Text]), string.format(sformat, value[0]))
    return UI_CUSTOM_SLIDER[str_id].active
end

function drawTriangle(p1, p2, p3, color, thickness)
    local drawList = imgui.GetWindowDrawList()
    drawList:AddRectFilled(p1, p2, color)
    drawList:AddRect(p1, p2, imgui.GetColorU32Vec4(imgui.ImVec4(0.0, 0.0, 0.0, 1.0)), 0, 0, thickness)
end

local notifications = {}


function imgui.AddTextColoredHex(DL, pos, text, defaultColor, out, outcol, fontsize, font, alpha)
    local function explode_hex(hex)
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        return r, g, b
    end

    local charIndex, lastColorCharIndex, lastColor = 0, -100, defaultColor

    imgui.PushFont(font)
    local text_without_colors = text:gsub('{%x%x%x%x%x%x}', '')
    for Char in text:gmatch('.') do
        charIndex = charIndex + 1
        if Char == '{' and text:sub(charIndex + 7, charIndex + 7) == '}' then
            local hexColor = text:sub(charIndex + 1, charIndex + 6)
            lastColorCharIndex = charIndex
            lastColor = hexColor
        end
        if charIndex < lastColorCharIndex or charIndex > lastColorCharIndex + 7 then
            local r, g, b = explode_hex(type(lastColor) == 'string' and lastColor or defaultColor)
            if out > 0 then
                DL:AddTextFontPtr(font, fontsize, imgui.ImVec2(pos.x + out, pos.y + out), imgui.GetColorU32Vec4(outcol), (Char))
                DL:AddTextFontPtr(font, fontsize, imgui.ImVec2(pos.x - out, pos.y - out), imgui.GetColorU32Vec4(outcol), (Char))
                DL:AddTextFontPtr(font, fontsize, imgui.ImVec2(pos.x + out, pos.y - out), imgui.GetColorU32Vec4(outcol), (Char))
                DL:AddTextFontPtr(font, fontsize, imgui.ImVec2(pos.x - out, pos.y + out), imgui.GetColorU32Vec4(outcol), (Char))
            end
            DL:AddTextFontPtr(font, fontsize, pos, imgui.GetColorU32Vec4(imgui.ImVec4(r / 255, g / 255, b / 255, alpha)), (Char))          
            pos.x = pos.x + imgui.CalcTextSize((Char)).x + (Char == ' ' and 2 or 0)
        end
    end

    imgui.PopFont()

end

function imgui.Notify(text, displayTime, width)
    if ini.settings.notifyScreen then
        table.insert(notifications, {
            text = text,
            displayTime = displayTime / 1000,
            startTime = os.clock(),
            alpha = 1,
            isFadingOut = false,
            fadeOutStartTime = nil,
            fixedWidth = width or nil, 
        })
        renderNotify[0] = true
    else
        sampAddChatMessage(text, 0x88aa62)
    end
end

local notifyFrame = imgui.OnFrame(
    function() return renderNotify[0] end,
    function(player)

        local resX, resY = getScreenResolution()
        local DL = imgui.GetBackgroundDrawList()

        local yOffset = 0 

        --
        for i = #notifications, 1, -1 do
            local notification = notifications[i]
            local now = os.clock()
            local elapsedTime = now - notification.startTime

            -- 
            if not notification.isFadingOut then
                if elapsedTime >= notification.displayTime then
                    notification.isFadingOut = true
                    notification.fadeOutStartTime = now
                end
            else
                local fadeOutElapsed = now - notification.fadeOutStartTime
                notification.alpha = math.max(0, 1 - (fadeOutElapsed / 1)) 
                if notification.alpha <= 0 then
                    table.remove(notifications, i)
                    renderNotify[0] = #notifications > 0
                    break
                end
            end

            imgui.PushFont(font2)

            local padding = 10
            local textMargin = 20  
            local verticalMargin = 5  
            local cleanText = notification.text:gsub('{%x%x%x%x%x%x}', '')
            local textSize = imgui.CalcTextSize((cleanText))

            
            local pos = imgui.ImVec2(500, resY - yOffset - (textSize.y + 2 * padding) - 50)
            yOffset = yOffset + textSize.y + 2 * padding + verticalMargin

            
            local rectWidth = notification.fixedWidth or (textSize.x + 2 * padding + textMargin)
            local rectSize = imgui.ImVec2(rectWidth, textSize.y + 2 * padding)

           
            local bgColor = imgui.GetColorU32Vec4(imgui.ImVec4(ini.WindowBG.r, ini.WindowBG.g, ini.WindowBG.b, notification.alpha * 0.8))
            DL:AddRectFilled(pos, imgui.ImVec2(pos.x + rectSize.x, pos.y + rectSize.y), bgColor, 0)

            imgui.AddTextColoredHex(DL, imgui.ImVec2(pos.x + padding, pos.y + padding), notification.text, "88aa62", 0, imgui.ImVec4(0, 0, 0, 0.5), 25, font2, notification.alpha)

            imgui.PopFont()
        end

        
        renderNotify[0] = #notifications > 0
    end
)
notifyFrame.HideCursor = true


---------------------- [Autocroshair]----------------------
function adjustCrosshairToAspectRatio()
    local aspect = ini.settings.aspectratio

	local crosshairPositions = {
		[1.00] = { x = 0.5185, y = 0.438 },
		[1.10] = { x = 0.5185, y = 0.448 },
		[1.20] = { x = 0.5185, y = 0.452 },
		[1.30] = { x = 0.5185, y = 0.455 },
		[1.40] = { x = 0.5185, y = 0.460 },
		[1.50] = { x = 0.5185, y = 0.463 },
		[1.60] = { x = 0.5185, y = 0.465 },
		[1.70] = { x = 0.5185, y = 0.467 },
		[1.80] = { x = 0.5185, y = 0.470 },
		[1.90] = { x = 0.5185, y = 0.470 },
		[2.00] = { x = 0.5185, y = 0.472 },
		[2.10] = { x = 0.5185, y = 0.474 },
		[2.20] = { x = 0.5185, y = 0.475 },
		[2.30] = { x = 0.5185, y = 0.476 },
		[2.40] = { x = 0.5185, y = 0.477 },
		[2.50] = { x = 0.5185, y = 0.478 },
		[2.60] = { x = 0.5185, y = 0.478 },
		[2.70] = { x = 0.5185, y = 0.478 },
		[2.80] = { x = 0.5185, y = 0.479 },
		[2.90] = { x = 0.5185, y = 0.480 },
		[3.00] = { x = 0.519, y = 0.481 }
	}

    local pos = crosshairPositions[aspect]
    
    if pos then
        ini.main.auto_miraposx = pos.x
        ini.main.auto_miraposy = pos.y
    else
        local closestAspect = 1.00
        for key, _ in pairs(crosshairPositions) do
            if math.abs(aspect - key) < math.abs(aspect - closestAspect) then
                closestAspect = key
            end
        end
        ini.main.auto_miraposx = crosshairPositions[closestAspect].x
        ini.main.auto_miraposy = crosshairPositions[closestAspect].y
    end
    save()
end

---------------------- [Adjusts croshair]----------------------
function drawCrosshairHook()
    local save1 = gta._ZN7CCamera22m_f3rdPersonCHairMultXE
    local save2 = gta._ZN7CCamera22m_f3rdPersonCHairMultYE

    if ini.main.croshair then
        gta._ZN7CCamera22m_f3rdPersonCHairMultXE = ini.main.miraposx
        gta._ZN7CCamera22m_f3rdPersonCHairMultYE = ini.main.miraposy
    elseif ini.main.auto_crosshair then
        gta._ZN7CCamera22m_f3rdPersonCHairMultXE = ini.main.auto_miraposx
        gta._ZN7CCamera22m_f3rdPersonCHairMultYE = ini.main.auto_miraposy
    else
        gta._ZN7CCamera22m_f3rdPersonCHairMultXE = 0.5185
        gta._ZN7CCamera22m_f3rdPersonCHairMultYE = 0.438
    end

    local r = drawCrosshairHook()

    gta._ZN7CCamera22m_f3rdPersonCHairMultXE = save1
    gta._ZN7CCamera22m_f3rdPersonCHairMultYE = save2

    return r
end

drawCrosshairHook = hook.new('void(*)()', drawCrosshairHook, ffi.cast('uintptr_t', ffi.cast('void*', gta._ZN4CHud14DrawCrossHairsEv)))

---------------------- [Adjusts AspectRatio]----------------------
function aspectHook(camera, rect, unk, aspect)
	local ratio = sliders.aspectratio[0]

	if not checkboxes.aspectratio_status[0] or ratio == 2.0 then
		return aspectHook(camera, rect, unk, aspect)
	end

	local t = (ratio - 0.5) / (2.0 - 0.5)
	local mappedAspect = 0.7 + (2.1 - 0.7) * t

	return aspectHook(camera, rect, unk, mappedAspect)
end


aspectHook = hook.new("void(*)(RwCamera *camera, RwRect *rect, float unk, float aspect)", aspectHook, ffi.cast("uintptr_t", ffi.cast("void*", gta._Z10CameraSizeP8RwCameraP6RwRectff)))

---------------------- [RGB colors to hexadecimal]----------------------
function RGBToHex(red, green, blue, alpha)
	if red < 0 or red > 255 or green < 0 or green > 255 or blue < 0 or blue > 255 or alpha and (alpha < 0 or alpha > 255) then
		return nil
	end

	if alpha then
		return tonumber(string.format("0x%.2X%.2X%.2X%.2X", alpha, red, green, blue))
	else
		return tonumber(string.format("0x%.2X%.2X%.2X", red, green, blue))
	end
end

---------------------- [Hits]----------------------
local color = 0xFFFFA500
local fontFlag = require('moonloader').font_flag
local hitMarkerFont = renderCreateFont('Segoe UI', 15, fontFlag.BOLD + fontFlag.SHADOW)
math.randomseed(os.time())
local hitEffectFont = renderCreateFont("Consolas", 12, fontFlag.BOLD + fontFlag.BORDER + fontFlag.SHADOW)
math.randomseed(os.time())


function renderHitMarker(data)
    if not data or not data[1] or not data[2] or not data[3] then return end

    local startTime = os.clock()
    local x, y, z = data[1], data[2], data[3] 
    local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
    local charIsExist, ped = sampGetCharHandleBySampPlayerId(data[4])

    if not charIsExist then return end

    local r = math.max(0, math.min(255, math.floor(hitMarkerColor[0] * 255)))
    local g = math.max(0, math.min(255, math.floor(hitMarkerColor[1] * 255)))
    local b = math.max(0, math.min(255, math.floor(hitMarkerColor[2] * 255)))
    local a = math.max(0, math.min(255, math.floor(hitMarkerColor[3] * 255)))
    local hitMarkerHex = RGBToHex(r, g, b, a)

    if not hitMarkerHex then return end

    while os.clock() - startTime < 5.75 do
        wait(0)

        if isPointOnScreen(x, y, z, 1) then
            local elapsedTime = os.clock() - startTime
            local alpha = math.floor(decreaseAlpha(hitMarkerHex, math.ceil(bringFloatTo(0, 255, elapsedTime, 5.75))))
            local alphaColor = (alpha * 0x1000000) + (hitMarkerHex % 0x1000000)

            local backX, backY = convert3DCoordsToScreen(x, y, z)
            if backX and backY then
                renderFontDrawText(hitMarkerFont, "x", backX, backY, string.format("0x%08X", alphaColor))
            end
        end
    end
end

function renderHitEffect(data)
    if not data or not data[1] or not data[2] or not data[3] or not data[5] then return end

    local startTime = os.clock()
    local x, y, z = data[1], data[2], data[3] 
    local damage = data[5]
    local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
    local charIsExist, ped = sampGetCharHandleBySampPlayerId(data[4])

    if not charIsExist then return end

    local r = math.max(0, math.min(255, math.floor(hitEfectsColor[0] * 255)))
    local g = math.max(0, math.min(255, math.floor(hitEfectsColor[1] * 255)))
    local b = math.max(0, math.min(255, math.floor(hitEfectsColor[2] * 255)))
    local a = math.max(0, math.min(255, math.floor(hitEfectsColor[3] * 255)))
    local hitEffectHex = RGBToHex(r, g, b, a)

    if not hitEffectHex then return end

    while os.clock() - startTime < 2.5 do
        wait(0)

        if isPointOnScreen(x, y, z, 1) then
            local elapsedTime = os.clock() - startTime
            local alpha = math.floor(decreaseAlpha(hitEffectHex, math.ceil(bringFloatTo(0, 255, elapsedTime, 2.5))))
            local alphaColor = (alpha * 0x1000000) + (hitEffectHex % 0x1000000)

            local backX, backY = convert3DCoordsToScreen(x, y, z)
            if backX and backY then
                local moveUp = math.ceil(bringFloatTo(0, 200, elapsedTime, 2.5))
                renderFontDrawText(hitEffectFont, tostring(damage), backX, backY - moveUp, string.format("0x%08X", alphaColor))
            end
        end
    end
end

function decreaseAlpha(color, decreaseAmount)
    local alpha = math.floor(color / 0x1000000)
    local newAlpha = math.max(0, alpha - decreaseAmount)
    return newAlpha
end

function bringFloatTo(from, to, elapsedTime, duration)
    local progress = elapsedTime / duration
    local newValue = from + (progress * (to - from))
    return newValue
end


---------------------- [Pause-Menu]----------------------
local isPaused = false
local last, waiting, start

imgui.OnFrame(function()
    return true
end, function()
    local paused = isGamePaused()
    if paused ~= last then
        last = paused
        if paused then
            isPaused, waiting = true, false
        else
            start = os.clock()
            waiting = true
        end
    end
    if waiting and os.clock() - start >= 1.5 then
        isPaused, waiting = false, false
    end
end)

---------------------- [Samp Events]----------------------

function sampEvents.onSendBulletSync(bulletSync)
    -- hitMarker
    if bulletSync.target then
        bulletX, bulletY, bulletZ = bulletSync.target.x, bulletSync.target.y, bulletSync.target.z
    end

 	 -- Sistema UGENRL
    if not (ini.ugenrl_main.enable and ini.ugenrl_main.weapon) then return end

    if ini.ugenrl_sounds[bulletSync.weaponId] then
        playSound(ini.ugenrl_sounds[bulletSync.weaponId], ini.ugenrl_volume.weapon)
    end

end

function sampEvents.onBulletSync(playerId, bulletSync)
    if isPaused or not (ini.ugenrl_main.enable and ini.ugenrl_main.enemyWeapon) then return end

    local weaponId = bulletSync.weaponId
    local soundFile = ini.ugenrl_sounds[weaponId]

    local ok, enemyPed = sampGetCharHandleBySampPlayerId(playerId)
    if not ok or not doesCharExist(enemyPed) then return end

    local ex, ey, ez = getCharCoordinates(enemyPed)
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    if not ex or not px then return end

    local distance = getDistanceBetweenCoords3d(px, py, pz, ex, ey, ez)
    local maxDistance = ini.ugenrl_main.enemyWeaponDist
    if distance > maxDistance then return end

    local baseVolume = sliders.weapon_volume[0]
    local multiplier = ({0.50, 0.40, 0.35, 0.28, 0.20, 0.15, 0.10, 0.05})[math.min(math.ceil(distance / 7), 8)]
    local volume = baseVolume * multiplier

    --print(string.format("[SOUND DEBUG] Distancia: %.2f m | Multiplicador: %.2f | Volumen final: %.2f", distance, multiplier, volume))
    playSound(soundFile, volume)
end

local lastSoundTime = {
    hit = 0,
    pain = 0,
}

function canPlaySound(type, cooldown)
    local now = os.clock()
    if now - (lastSoundTime[type] or 0) >= cooldown then
        lastSoundTime[type] = now
        return true
    end
    return false
end

function sampEvents.onSendGiveDamage(playerId, damage, weapon, bodypart)
    -- Hitmarker
    if checkboxes.enabledHitMarker[0] and weapon > 21 and weapon < 35 then
        lua_thread.create(renderHitMarker, {bulletX, bulletY, bulletZ, playerId, math.ceil(damage)})
    end

	-- Hiteffects
    if checkboxes.enabledHitEfects[0] and weapon > 21 and weapon < 35 then
        lua_thread.create(renderHitEffect, {bulletX, bulletY, bulletZ, playerId, math.ceil(damage)})
    end

    if ini.ugenrl_main.enable and ini.ugenrl_main.hit and canPlaySound("hit", 0.1) then
        playSound(ini.ugenrl_sounds.hit, ini.ugenrl_volume.hit)
    end

end

function sampEvents.onSendTakeDamage()
    if not isPaused and ini.ugenrl_main.enable and ini.ugenrl_sounds.pain and ini.ugenrl_volume.pain and canPlaySound("pain", 0.4)then
        playSound(ini.ugenrl_sounds.pain, ini.ugenrl_volume.pain)
    end
end


---------------------- [Function main]----------------------
function main()
	local fileName = getWorkingDirectory() .. "/GameFixer.lua"
	
	if fileExists(fileName) then
		print("cargado correctamente")
	else
		print("No renombres el mod")
		thisScript():unload()
	end
	
	repeat wait(0) until isSampAvailable()
    --imgui.Notify(script_name.." {FFFFFF}Cargado con exito. Utilice {dc4747}" .. ini.commands.openmenu .. "", 3000)
    loadSounds()--ugenrl

    lua_thread.create(function()
        while true do
            wait(1000)
            
            if isSampAvailable() then
                monitorConnection()
            end
        end
    end)


	while true do
		wait(0)

		drawCrosshairHook()
		
		gotofunc("all")
		
		
	end
end

---------------------- [font SuperIcon]----------------------
local function loadSCFont(size, merge)
    local cfg = imgui.ImFontConfig()
    cfg.MergeMode = merge or false
    cfg.PixelSnapH = true
    local iconRanges = new.ImWchar[3](sc.min_range, sc.max_range, 0)

    return imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(sc.get_font_data_base85(), size, cfg, iconRanges)
end

local function loadFAFont(style, size, merge)
    local cfg = imgui.ImFontConfig()
    cfg.MergeMode = merge or false
    cfg.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](fa.min_range, fa.max_range, 0)

	return imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85(style), size, cfg, iconRanges)
end

---------------------- [Load fonts/theme]----------------------
imgui.OnInitialize(function()
	SwitchTheStyle()
    
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesDefault()
    local fontPath = resourceDir .. "/fonts/"
    
	font1 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "sgame.ttf", 30, nil, glyph_ranges)
	loadFAFont("solid", 22, true)
	font2 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "Verdana.ttf", 25, nil, glyph_ranges)
	loadFAFont("solid", 20, true)

    --font3 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "pricedown_rus.ttf", 35, nil, glyph_ranges)
	logofont = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "fonte3.otf", 40, nil, glyph_ranges)
	loadFAFont("solid", 30, true)
	iconFont = loadSCFont(40)
end)

---------------------- [Theme]----------------------

function SwitchTheStyle(param)
    param = param or "init"
    imgui.SwitchContext()

    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
    if param ~= "change" then
        --==[ STYLE ]==--
        imgui.GetStyle().WindowPadding = imgui.ImVec2(3, 3)
        imgui.GetStyle().FramePadding = imgui.ImVec2(3, 3)
        imgui.GetStyle().ItemSpacing = imgui.ImVec2(5, 5)
        imgui.GetStyle().ItemInnerSpacing = imgui.ImVec2(4, 4)
        imgui.GetStyle().TouchExtraPadding = imgui.ImVec2(4, 4)
        imgui.GetStyle().IndentSpacing = 2
        imgui.GetStyle().ScrollbarSize = 13
        imgui.GetStyle().GrabMinSize = 15

        style.AntiAliasedLines = true
        style.AntiAliasedFill = true
        --==[ BORDER ]==--
        imgui.GetStyle().WindowBorderSize = 0
        imgui.GetStyle().ChildBorderSize = 2
        imgui.GetStyle().PopupBorderSize = 1
        imgui.GetStyle().FrameBorderSize = 0
        imgui.GetStyle().TabBorderSize = 1

        --==[ ROUNDING ]==--
        imgui.GetStyle().WindowRounding = 0
        imgui.GetStyle().ChildRounding = 0
        imgui.GetStyle().FrameRounding = 0
        imgui.GetStyle().PopupRounding = 0
        imgui.GetStyle().ScrollbarRounding = 0
        imgui.GetStyle().GrabRounding = 0
        imgui.GetStyle().TabRounding = 0
        --==[ ALIGN ]==--
        imgui.GetStyle().WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
        imgui.GetStyle().ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
        imgui.GetStyle().SelectableTextAlign = imgui.ImVec2(0.5, 0.5)
    end
    
    local eColor = imgui.GetStyle().Colors[imgui.Col.WindowBg]
   
	--imgui.GetStyle().Colors[imgui.Col.Border] = ImVec4(0.1, 0.6, 0.7, 1)
	--imgui.GetStyle().Colors[imgui.Col.ResizeGrip] = ImVec4(0.1, 0.6, 0.7, 0.7)
	
    colors[clr.WindowBg]               = ImVec4(ini.WindowBG.r, ini.WindowBG.g, ini.WindowBG.b, ini.WindowBG.a)
    colors[clr.FrameBg]                = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.80)
    colors[clr.FrameBgHovered]         = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.90)
    colors[clr.FrameBgActive]          = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 1.00)
    colors[clr.CheckMark]              = ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
    colors[clr.SliderGrab]             = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 1.80)
    colors[clr.SliderGrabActive]       = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 1.00)
    colors[clr.Button]                 = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.30)
    colors[clr.ButtonHovered]          = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.50)
    colors[clr.ButtonActive]           = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.70)
    colors[clr.Header]                 = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.80)
    colors[clr.HeaderHovered]          = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.90)
    colors[clr.HeaderActive]           = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 1.0)
    colors[clr.Separator]              = colors[clr.Border]
    colors[clr.SeparatorHovered]       = ImVec4(0.26, 0.59, 0.98, 0.78)
    colors[clr.SeparatorActive]        = ImVec4(0.26, 0.59, 0.98, 1.00)
    colors[clr.ResizeGrip]             = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.4)
    colors[clr.ResizeGripHovered]      = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.6)
    colors[clr.ResizeGripActive]       = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 1)
    colors[clr.TextSelectedBg]         = ImVec4(0.26, 0.59, 0.98, 0.35)
    colors[clr.Text]                   = ImVec4(ini.ColorText.r, ini.ColorText.g, ini.ColorText.b, ini.ColorText.a)
    colors[clr.TextDisabled]           = ImVec4(0.50, 0.50, 0.50, 1.00)
    colors[clr.ChildBg]                = ImVec4(0,0,0,0)
    colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border]                 = ImVec4(1.0, 1.0, 1.0, 0.10)
    colors[clr.BorderShadow]           = ImVec4(1.00, 1.00, 1.00, 0.07)
    colors[clr.MenuBarBg]              = ImVec4(0.14, 0.14, 0.14, 1.00)
    colors[clr.ScrollbarBg]            = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.1)
    colors[clr.ScrollbarGrab]          = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.4)
    colors[clr.ScrollbarGrabHovered]   = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.5)
    colors[clr.ScrollbarGrabActive]    = ImVec4(ini.BaseColor.r, ini.BaseColor.g, ini.BaseColor.b, 0.7)
    colors[clr.PlotLines]              = ImVec4(ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a)
    colors[clr.PlotLinesHovered]       = ImVec4(ini.ColorNavi.r, ini.ColorNavi.g, ini.ColorNavi.b, ini.ColorNavi.a) 
    colors[clr.PlotHistogram]          = ImVec4(ini.ColorChildMenu.r, ini.ColorChildMenu.g, ini.ColorChildMenu.b, ini.ColorChildMenu.a)
    colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.80, 0.00, 1.00)
   
end