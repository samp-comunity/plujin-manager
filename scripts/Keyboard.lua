script_name("KeyBoard")
script_author("vxnzz")
script_version("1.0")
--==================================== 

local imgui = require("mimgui")
local addons = require("ADDONS")
local sampEvents = require('samp.events')
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

local sc = loadLibrary 'supericon' 

---------------------- [ cfg ]----------------------
local inicfg = require("inicfg")
local directIni  = "keyboard.ini"
local ini = inicfg.load({
    settings = {
        theme = 0,
        anim = true,
    },
	keyboard = {
		active = true,
        scale = 1,
        mode = 0,
        x = 400,
		y = 500
	},
    mouse = {
		active = true,
		x = 400,
		y = 320,
        scale = 1
	}
}, directIni )
inicfg.save(ini, directIni)

function save()
    inicfg.save(ini, directIni)
end

local sw, sh = getScreenResolution()

local new = imgui.new
local settings = new.bool(false)
local kb_settings = new.bool(false)
local keyboard = new.bool(ini.keyboard.active)
local mouse = new.bool(ini.mouse.active)
local keyboard_x, keyboard_y = new.int(ini.keyboard.x), new.int(ini.keyboard.y)
local mouse_x, mouse_y = new.int(ini.mouse.x), new.int(ini.mouse.y)
local anim = new.bool(ini.settings.anim)
local theme = new.int(ini.settings.theme)
local color_theme = {'Verde', 'Rojo', 'Púrpura Claro', 'Púrpura Oscuro', 'Cereza', 'Amarillo', 'Azul'}
local theme_list = new["const char*"][#color_theme](color_theme)
local kbMode = new.int(ini.keyboard.mode)
local kbLabels = {'Teclado Completo', 'Sin Numpad', 'Solo Números', 'Números Compactos', 'Controles Principales'}
local kbList = new["const char*"][#kbLabels](kbLabels)
local key_scale = new.float(tonumber(ini.keyboard.scale or 1.0))
local mouse_scale = new.float(tonumber(ini.mouse.scale or 1.0))

  ---------------------- [FFI]----------------------
ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]

---------------------- [Function main]----------------------
function main()
	local fileName = getWorkingDirectory() .. "/Keyboard.lua"
	
	if fileExists(fileName) then
		print("cargado correctamente")
	else
		print("No renombres el mod")
		thisScript():unload()
	end
    repeat wait(0) until isSampAvailable()
    
    sampRegisterChatCommand('key', function()
        settings[0] = not settings[0]
    end)
	
end

inputActions = {
    jump = false, crouch = false, shoot = false, aim = false,
    direction = "0x00", highlightQ = false, highlightE = false,
    _wasMoving = false, _moveTapCount = 0, _lastMoveTapTime = 0,
}

local _lastWeapon = getCurrentCharWeapon(PLAYER_PED)
local _highlightTimer = 0
local lastX, lastY = getCharCoordinates(PLAYER_PED)
local lastHeading = 0

local function getCameraRotation()
    local cam = Camera.aCams[0]
    return cam.fHorizontalAngle, cam.fVerticalAngle
end

local function getMovementDirectionFromPosition()
    local x, y = getCharCoordinates(PLAYER_PED)
    local dx, dy = x - lastX, y - lastY
    lastX, lastY = x, y

    if math.sqrt(dx * dx + dy * dy) < 0.01 then return "0x00" end

    local moveAngle = math.atan2(dy, dx)
    local camAngle = getCameraRotation()
    local diff = (moveAngle - camAngle) % (2 * math.pi)

    if diff < math.pi / 4 or diff > 7 * math.pi / 4 then return "0x53" -- S
    elseif diff < 3 * math.pi / 4 then return "0x44" -- D
    elseif diff < 5 * math.pi / 4 then return "0x57" -- W
    else return "0x41" -- A
    end
end

local function getVehicleTurningDirection()
    local veh = storeCarCharIsInNoSave(PLAYER_PED)
    if not doesVehicleExist(veh) then return "0x00" end

    local delta = (getCarHeading(veh) - lastHeading + 360) % 360
    lastHeading = getCarHeading(veh)

    if delta > 1 and delta < 180 then return "0x41"
    elseif delta > 180 and delta < 359 then return "0x44"
    else return "0x00"
    end
end

local function getMovementDirection()
    return isCharInAnyCar(PLAYER_PED) and getVehicleTurningDirection() or getMovementDirectionFromPosition()
end

local usesGunStand = {}
for _, id in ipairs({22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34}) do
    usesGunStand[id] = true
end

function updateInputActions()
    local ped, now = PLAYER_PED, os.clock()
    local weapon = getCurrentCharWeapon(ped)

    -- Saltar
    inputActions.jump = isCharPlayingAnim(ped, "JUMP_glide") or isCharPlayingAnim(ped, "JUMP_launch")

    -- Agacharse (doble tap)
    local moving = isWidgetPressed(WIDGET_PED_MOVE)
    if moving and not inputActions._wasMoving then
        inputActions._moveTapCount = now - inputActions._lastMoveTapTime < 0.5
            and inputActions._moveTapCount + 1 or 1
        inputActions._lastMoveTapTime = now

        if inputActions._moveTapCount == 2 then
            inputActions.crouch = true
            inputActions._moveTapCount = 0
            lua_thread.create(function()
                wait(200)
                inputActions.crouch = false
            end)
        end
    end
    inputActions._wasMoving = moving

    -- Disparo visual timeout
    if inputActions._shootTimer and now - inputActions._shootTimer > 0.2 then
        inputActions.shoot = false
    end

    ---[Apuntar]---
    inputActions.aim =
        (usesGunStand[weapon] and isCharPlayingAnim(ped, "gun_stand")) or
        (weapon == 33 and isCharPlayingAnim(ped, "rifle_stand"))

    ---[Cambio de arma]---
    if weapon ~= _lastWeapon then
        inputActions.highlightQ = weapon < _lastWeapon
        inputActions.highlightE = weapon > _lastWeapon
        _highlightTimer = now + 0.3
        _lastWeapon = weapon
    elseif now > _highlightTimer then
        inputActions.highlightQ = false
        inputActions.highlightE = false
    end

    ---[Direccion]---
    inputActions.direction = getMovementDirection()
end

function sampEvents.onSendBulletSync()
    inputActions.shoot = true
    inputActions._shootTimer = os.clock()
    shootEffect, shootTimer = true, os.clock()
end

lua_thread.create(function()
    while true do
        wait(50)
        updateInputActions()
    end
end)

conditionMap = {
    ["@jump"]         = function() return inputActions.jump end,
    ["@crouch"]       = function() return inputActions.crouch end,
    ["@shootEffect"]  = function() return inputActions.shoot end,
    ["@aimingEffect"] = function() return inputActions.aim end,
    ["@highlightQ"]   = function() return inputActions.highlightQ end,
    ["@highlightE"]   = function() return inputActions.highlightE end,
}


local keyboardFrame = imgui.OnFrame(
    function() return keyboard[0] and not isGamePaused() end,

    function(self)
        imgui.GetStyle().WindowBorderSize = 0

        local scale = key_scale[0]
        local baseHeight = (imgui.CalcTextSize("A").y + 8) * scale

        imgui.SetNextWindowPos(imgui.ImVec2(ini.keyboard.x, ini.keyboard.y), imgui.Cond.Always)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(5.0 * scale, 2.4 * scale))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))

        imgui.Begin("##keyboard", _, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
        keyboardSize = imgui.GetWindowSize()
        imgui.PushFont(font1)
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0, 0, 0, 0.4))

        local buttonActiveColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
        local spacingY = 2.0 * scale
        local currentY = 0

        local selectedKeyboard = keyboards[kbMode[0] + 1] or keyboards[1]

        for rowIndex, row in ipairs(selectedKeyboard) do
            imgui.SetCursorPosY(currentY)

            for keyIndex, key in ipairs(row) do
                local label = key[1]
                local widgetInfo = key[2]
                local indent = key[3]

                local isActive = false

                if type(widgetInfo) == "string" then
                    local fn = conditionMap[widgetInfo]
                    isActive = fn and fn() or false

                elseif type(widgetInfo) == "number" then
                    isActive = isWidgetPressed(widgetInfo)

                elseif type(widgetInfo) == "table" then
                    for _, v in ipairs(widgetInfo) do
                        if type(v) == "number" and isWidgetPressed(v) then
                            isActive = true
                            break
                        elseif type(v) == "string" and inputActions.direction == v then
                            isActive = true
                            break
                        end
                    end
                end

                local textSize = imgui.CalcTextSize(label)
                local width = ((label == "        ") and 100 or textSize.x + 14) * scale
                local height = (textSize.y + 8) * scale

                if ini.settings.anim and isActive then
                    imgui.PushStyleColor(imgui.Col.ChildBg, buttonActiveColor)
                end

                imgui.BeginChild("##key_" .. rowIndex .. "_" .. keyIndex, imgui.ImVec2(width, height), true)
                    imgui.SetCursorPos(imgui.ImVec2(
                        (imgui.GetWindowWidth() - textSize.x) / 2,
                        (height - textSize.y) / 2
                    ))
                    imgui.Text(label)
                imgui.EndChild()

                if ini.settings.anim and isActive then imgui.PopStyleColor() end

                if keyIndex < #row then
                    if indent then
                        imgui.SameLine(nil, indent * scale)
                    else
                        imgui.SameLine()
                    end
                end
            end

            currentY = currentY + baseHeight + spacingY
        end

        imgui.PopStyleColor()
        imgui.End()
        imgui.PopStyleColor()
        imgui.PopStyleVar()
    end
)

local mouseFrame = imgui.OnFrame(
    function() return mouse[0] and not isGamePaused() end,

    function(self)
        imgui.GetStyle().WindowBorderSize = 0
        if shootEffect and os.clock() - shootTimer > 0.2 then
            shootEffect = false
        end

        local scale = mouse_scale[0]
        local spacingY = 4 * scale
        local buttonActiveColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]

        imgui.SetNextWindowPos(imgui.ImVec2(ini.mouse.x, ini.mouse.y), imgui.Cond.Always)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(4.0 * scale, 4.0 * scale))
        imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0, 0, 0, 0))

        imgui.Begin("##Mouse", _, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize)
        mouseSize = imgui.GetWindowSize()

        imgui.PushFont(font1)
        imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0, 0, 0, 0.4))

        for i, btn in ipairs(mouse_keys) do
            local label     = btn[1]
            local condition = btn[2]
            local width     = (btn[3] or 60) * scale
            local height    = (btn[4] or 40) * scale

            local isActive =
                (condition == "@shootEffect" and shootEffect) or
                (condition == "@aimingEffect" and inputActions.aim)

            if ini.settings.anim and isActive then
                imgui.PushStyleColor(imgui.Col.ChildBg, buttonActiveColor)
            end

            imgui.BeginChild("##btn_"..i, imgui.ImVec2(width, height), true)
                local textSize = imgui.CalcTextSize(label)
                imgui.SetCursorPos(imgui.ImVec2(
                    (width - textSize.x) / 2,
                    (height - textSize.y) / 2
                ))
                imgui.Text(label)
            imgui.EndChild()

            if ini.settings.anim and isActive then imgui.PopStyleColor() end

            if i % 3 ~= 0 and i < #mouse_keys then
                imgui.SameLine()
            elseif i == 3 then
                imgui.Dummy(imgui.ImVec2(0, spacingY))
            end
        end

        imgui.PopStyleColor()
        imgui.End()
        imgui.PopStyleColor()
        imgui.PopStyleVar()
    end
)


local KeySettings = imgui.OnFrame(function()
    return kb_settings[0]
end, function()
    imgui.SetNextWindowSize(imgui.ImVec2(830, 380), imgui.Cond.FirstUseEver)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(20, 20))
    imgui.Begin("key_settings", false, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar) 

        local bgColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
        imgui.PushStyleColor(imgui.Col.Text, bgColor)
        imgui.PushFont(logofont)
        imgui.Text("Configuracion " .. fa.GEARS)
        imgui.PopStyleColor()
        imgui.PopFont()

        local windowSize = imgui.GetWindowSize()
        imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
        addons.CloseButton("##closemenuboton", kb_settings, 33, 5)
        imgui.PopStyleColor()
        
        imgui.PushFont(font1)
        imgui.Dummy(imgui.ImVec2(0, 30))

            if ini.keyboard.active then
                imgui.BeginChild("KeyboardBlock", imgui.ImVec2(400, 350), false)
                    imgui.PushStyleColor(imgui.Col.Text, bgColor)
                    imgui.Text("KEYBOARD ".. fa.KEYBOARD)
                    imgui.PopStyleColor()
                    imgui.NewLine()
                    if imgui.CustomSlider("##key_scale", key_scale, 1, 2, 'Escala', 250) then
                    ini.keyboard.scale = tostring(key_scale[0])
                    save()
                    end
                    imgui.NewLine()
                    if imgui.CustomSlider("##key_pos_x", keyboard_x, 0, sw - keyboardSize.x, 'Posicion X', 250) then
                    ini.keyboard.x = keyboard_x[0]
                    save()
                    end
                    imgui.NewLine()
                    if imgui.CustomSlider("##key_pos_y", keyboard_y, 0, sh - keyboardSize.y, 'Posicion Y', 250) then
                    ini.keyboard.y = keyboard_y[0]
                    save()
                    end
                    imgui.NewLine()
                    if imgui.Button(fa.UP_DOWN_LEFT_RIGHT.. " Mover con un toque##key", imgui.ImVec2(0, 40)) then
                        keypos = not keypos
                        kb_settings[0] = not kb_settings[0]
                    end
                imgui.EndChild()
                imgui.SameLine()
            end


            if ini.mouse.active then
                imgui.BeginChild("MouseBlock", imgui.ImVec2(400, 350), false)
                    imgui.PushStyleColor(imgui.Col.Text, bgColor)
                    imgui.Text("MOUSE " .. fa.JOYSTICK)
                    imgui.PopStyleColor()
                    imgui.NewLine()
                    if imgui.CustomSlider("##mouse_scale", mouse_scale, 1, 2, 'Escala', 250) then
                        ini.mouse.scale = tostring(mouse_scale[0])
                        save()
                    end
                    imgui.NewLine()
                    if imgui.CustomSlider("##mse_pos_x", mouse_x, 0, sw - mouseSize.x, 'Posicion X', 250) then
                    ini.mouse.x = mouse_x[0]
                    save()
                    end
                    imgui.NewLine()
                    if imgui.CustomSlider("##mse_pos_y", mouse_y, 0, sh - mouseSize.y, 'Posicion Y', 250) then
                        ini.mouse.y = mouse_y[0]
                        save()
                    end
                    imgui.NewLine()
                    if imgui.Button(fa.UP_DOWN_LEFT_RIGHT.. " Mover con un toque##mouse", imgui.ImVec2(0, 40)) then
                        msepos = not msepos
                        kb_settings[0] = not kb_settings[0]
                    end
                imgui.EndChild()
            end
        imgui.PopFont()

        imgui.Dummy(imgui.ImVec2(0, 10))
    imgui.End()
    imgui.PopStyleVar()
end)

local MainMenu = imgui.OnFrame(
    function() return settings[0] end,

    function(self)
        imgui.SetNextWindowSize(imgui.ImVec2(622, 388), imgui.Cond.FirstUseEver)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        imgui.Begin("##settings", settings, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
        local windowSize = imgui.GetWindowSize()

        imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
        addons.CloseButton("##closemenu", settings, 33, 5)
        imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(15, 15)) 
        imgui.BeginChild("##settings_inner", imgui.ImVec2(windowSize.x - 30, windowSize.y - 30), false)

        local bgColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
        imgui.PushStyleColor(imgui.Col.Text, bgColor)
        imgui.PushFont(logofont)
        imgui.Text('Fake Keyboard ')
        imgui.PopStyleColor()
        imgui.PopFont()
        imgui.Spacing()
        imgui.Spacing()

        imgui.PushFont(font1)
        imgui.PushItemWidth(280)
        if imgui.Combo('Tipo de Keyboard', kbMode, kbList, #kbLabels) then
            ini.keyboard.mode = kbMode[0]
            save()
        end
        imgui.PopItemWidth()
        imgui.Spacing()
        imgui.Spacing()
        if imgui.Checkbox('Keyboard', keyboard) then
            ini.keyboard.active = keyboard[0]
            save()
        end
        imgui.Spacing()
        if imgui.Checkbox('Mouse', mouse) then
            ini.mouse.active = mouse[0]
            save()
        end
        imgui.Spacing()
        if imgui.Checkbox('Animacion', anim) then
            ini.settings.anim = anim[0]
            save()
        end
        imgui.Spacing()
        if imgui.Button(fa.SCREWDRIVER_WRENCH.. (' Ajustes extras'), imgui.ImVec2(0, 35)) then
            kb_settings[0] = not kb_settings[0]
        end
        imgui.Spacing()
        imgui.Spacing()

        imgui.PushItemWidth(280)
        if imgui.Combo('Tema', theme, theme_list, #color_theme) then
            ini.settings.theme = theme[0]
            SwitchTheStyle(theme[0])
            save()
        end
        imgui.PopItemWidth()
        imgui.Dummy(imgui.ImVec2(0, 15))
        imgui.Separator()
        imgui.Dummy(imgui.ImVec2(0, 15))
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.345, 0.396, 0.949, 1.0))
        imgui.Text(sc.DISCORD .. (' Discord '))
        imgui.PopStyleColor()
        if imgui.IsItemClicked() then
            imgui.Link("https://discord.gg/PSJT2SX7fh")
        end
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.0, 0.0, 1.0))
        imgui.Text(sc.YOUTUBE .. (' YouTube '))
        imgui.PopStyleColor()
        if imgui.IsItemClicked() then
            imgui.Link("https://youtube.com/@mstcommunity2023?si=1AjZ9r8Kw7Pa8PMh")
        end
        imgui.SameLine()
        imgui.PushStyleColor(imgui.Col.Text, imgui.GetStyle().Colors[imgui.Col.ButtonActive])
        imgui.Text(sc.USER .. (' by: _vxnzz'))
        imgui.PopStyleColor()
        imgui.PopFont()

        imgui.EndChild()
        imgui.End()
        imgui.PopStyleVar()
    end
)


keyboards = {
    { -- Whole Keyboard
        { -- Line 1
            {'Esc'},
            {'F1'},
            {'F2'},
            {'F3'},
            {'F4'},
            {'F5'},
            {'F6'},
            {'F7'},
            {'F8'},
            {'F9'},
            {'F10'},
            {'F11'},
            {'F12', nil, 57},
            {'PS'},
            {'SL'},
            {'P'},
        },
        { -- Line 2
            {'`'},
            {'1'},
            {'2'},
            {'3'},
            {'4'},
            {'5'},
            {'6'},
            {'7'},
            {'8'},
            {'9'},
            {'0'},
            {'-'},
            {'+'},
            {'<-'},
            {'Ins'},
            {'Home'},
            {'PgUp'},
            {'NL'},
            {'/'},
            {'*'},
            {'-'},
        },
        { -- Line 3
            {'Tab'},
            {'Q', "@highlightQ"},
            {'W', { 0x2, "0x57" }},
            {'E', "@highlightE" },
            {'R'},
            {'T'},
            {'Y'},
            {'U'},
            {'I'},
            {'O'},
            {'P'},
            {'['},
            {']'},
            {'\\'},
            {'Del'},
            {'End'},
            {'PgDn', nil, 28},
            {'7'},
            {'8'},
            {'9'},
            {'\n+'},
        },
        { -- Line 4
            {'Caps '},
            {'A', { 0x5, "0x41" }},
            {'S', { 0x3, "0x53" }},
            {'D', { 0x6, "0x44" }},
            {'F'},
            {'G'},
            {'H', 0x7},
            {'J'},
            {'K'},
            {'L'},
            {';'},
            {"'"},
            {' Enter ', nil, 162},
            {'4'},
            {'5'},
            {'6'},
        },
        { -- Line 5
            {' LShift  ', "@jump"},
            {'Z'},
            {'X'},
            {'C', "@crouch" },
            {'V', 0x12},
            {'B'},
            {'N'},
            {'M'},
            {','},
            {'.'},
            {'/'},
            {' RShift  ', nil, 73},
            {'/\\', nil, 41},
            {'1'},
            {'2'},
            {'3'},
            {'\nE'},
        },
        { -- Line 6
            {'Ctrl'},
            {'Win'},
            {'Alt'},
            {'                             ', { 0x4, 0x1F }},
            {'Alt'},
            {'Win'},
            {'Ctrl'},
            {'<'},
            {'\\/'},
            {'>',},
            {'0      '},
            {'.'},
        }
    },
    { -- No Numpad
        {
            {'Esc'},
            {'F1'},
            {'F2'},
            {'F3'},
            {'F4'},
            {'F5'},
            {'F6'},
            {'F7'},
            {'F8'},
            {'F9'},
            {'F10'},
            {'F11'},
            {'F12'},
        },
        {
            {'`'},
            {'1'},
            {'2'},
            {'3'},
            {'4'},
            {'5'},
            {'6'},
            {'7'},
            {'8'},
            {'9'},
            {'0'},
            {'-'},
            {'+'},
            {'<-'}, 
            {'Ins'},
            {'Home'},
            {'PU'},
        },
        {
            {'Tab'},
            {'Q', "@highlightQ"},
            {'W', { 0x2, "0x57" }},
            {'E', "@highlightE"},
            {'R'},
            {'T'},
            {'Y'},
            {'U'},
            {'I'},
            {'O'},
            {'P'},
            {'['},
            {']'},
            {'\\'},
            {'Del'},
            {'End'},
            {'PD'},
        },
        {
            {'Caps '},
            {'A', { 0x5, "0x41" }},
            {'S', { 0x3, "0x53" }},
            {'D', { 0x6, "0x44" }},
            {'F'},
            {'G'},
            {'H', 0x7},
            {'J'},
            {'K'},
            {'L'},
            {';'},
            {"'"},
            {' Enter '},
        },
        {
            {' LShift  ', "@jump"},
            {'Z'},
            {'X'},
            {'C', "@crouch"},
            {'V', 0x12},
            {'B'},
            {'N'},
            {'M'},
            {','},
            {'.'},
            {'/'},
            {' RShift  ', nil, 83},
            {'/\\'},
        },
        {
            {'Ctrl'},
            {'Win'},
            {'Alt'},
            {'                              ', { 0x4, 0x1F }},
            {'Alt'},
            {'Win'},
            {'Ctrl', nil, 10},
            {'<'},
            {'\\/'},
            {'>'},
        }
    },
    { -- Only Numbers
        {
            {'1'},
            {'2'},
            {'3'},
            {'4'},
            {'5'},
            {'6'},
            {'7'},
            {'8'},
            {'9'},
            {'0'},
        },
        {
            {'N'},
            {' Enter '},
        }
    },
    { -- Compact Numbers
        {
            {'1'},
            {'2'},
            {'3'},
        },
        {
            {'4'},
            {'5'},
            {'6'},
        },
        {
            {'7'},
            {'8'},
            {'9'},
        },
        {
            {'0'},
            {'N'},
        },
        {
            {' Enter '},
        }
    },
    { --control buttons
        { -- Línea 1
            { "Tab" },
            { "Q", "@highlightQ" },
            { "W", { 0x2, "0x57" } },
            { "E", "@highlightE" }, 
        },
        { -- Línea 2
            { "Shift", "@jump" }, 
            { "A", { 0x5, "0x41" } },
            { "S", { 0x3, "0x53" } }, 
            { "D", { 0x6, "0x44" } },
            { "C", "@crouch" },
        },
        { -- Línea 3
            { "Ctrl" },
            { "Alt" },
            { "             ", { 0x4, 0x1F } }
        }
    }
}

mouse_keys = {
    { "LMB", "@shootEffect",  58, 78 },
    { "MMB", nil,             56, 35 },
    { "RMB", "@aimingEffect", 58, 78 },
    { "FWD", nil,             89, 35 },
    { "BWD", nil,             89, 35 },
}

function fileExists(filePath)
    local file = io.open(filePath, "r")
    
    if file then
        io.close(file)
        return true
    else
        return false
    end
end


function onTouch(type, id, x, y)
    if keypos and id == 0 then
        ini.keyboard.x = x - (keyboardSize and keyboardSize.x or 0) / 2
        ini.keyboard.y = y - (keyboardSize and keyboardSize.y or 0) / 2
        save()
        keyboard_x[0] = ini.keyboard.x 
        keyboard_y[0] = ini.keyboard.y 

        keypos = false
        kb_settings[0] = not kb_settings[0]
    end

    if msepos and id == 0 then
        ini.mouse.x = x - (mouseSize and mouseSize.x or 0) / 2
        ini.mouse.y = y - (mouseSize and mouseSize.y or 0) / 2
        save()
        mouse_x[0] = ini.mouse.x 
        mouse_y[0] = ini.mouse.y 

        msepos = false
        kb_settings[0] = not kb_settings[0]
    end
end


------------[IMGUI]------------
function imgui.Link(url)
	gta._Z12AND_OpenLinkPKc(url)
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


---------------------- [FONTS]----------------------
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
    iconRanges = new.ImWchar[3](fa.min_range, fa.max_range, 0)

	return imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85(style), size, cfg, iconRanges)
end

---------------------- [Load fonts/theme]----------------------
imgui.OnInitialize(function()
    SwitchTheStyle(ini.settings.theme)

    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesDefault()
    local fontPath = getWorkingDirectory()  .. "/resource/fonts/"

	font1 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "Verdana.ttf", 25, nil, glyph_ranges)
	loadFAFont("solid", 20, true)
    loadSCFont(25, true)
	logofont = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "font1.otf", 45, nil, glyph_ranges)
	loadFAFont("solid", 30, true)
end)

function SwitchTheStyle(theme)
   	imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    style.WindowRounding = 10
    style.FrameRounding = 6.0

    style.ItemSpacing = imgui.ImVec2(3.0, 3.0)
    style.ItemInnerSpacing = imgui.ImVec2(3.0, 3.0)
    style.IndentSpacing = 21
    style.ScrollbarSize = 10.0
    style.ScrollbarRounding = 13
    style.GrabMinSize = 17.0
    style.GrabRounding = 16.0

    style.ChildRounding = 20.0
    style.ChildBorderSize = 2.0

    style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
    style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)

    if theme == 0 or theme == nil then
    
        colors[clr.Text]                   = ImVec4(0.90, 0.90, 0.90, 1.00)
		colors[clr.TextDisabled]           = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.WindowBg]               = ImVec4(0.08, 0.08, 0.08, 1.00)
		colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 1.00)
		colors[clr.Border]                 = ImVec4(0.70, 0.70, 0.70, 0.40)
		colors[clr.BorderShadow]           = ImVec4(0.00, 0.00, 0.00, 0.00)
		colors[clr.FrameBg]                = ImVec4(0.00, 0.38, 0.18, 1.00)
		colors[clr.FrameBgHovered]         = ImVec4(0.19, 0.19, 0.19, 0.71)
		colors[clr.FrameBgActive]          = ImVec4(0.34, 0.34, 0.34, 0.79)
		colors[clr.TitleBg]                = ImVec4(0.00, 0.69, 0.33, 0.80)
		colors[clr.TitleBgActive]          = ImVec4(0.00, 0.74, 0.36, 1.00)
		colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.69, 0.33, 0.50)
		colors[clr.MenuBarBg]              = ImVec4(0.00, 0.80, 0.38, 1.00)
		colors[clr.ScrollbarBg]            = ImVec4(0.16, 0.16, 0.16, 1.00)
		colors[clr.ScrollbarGrab]          = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.ScrollbarGrabHovered]   = ImVec4(0.00, 0.82, 0.39, 1.00)
		colors[clr.ScrollbarGrabActive]    = ImVec4(0.00, 1.00, 0.48, 1.00)
		colors[clr.CheckMark]              = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.SliderGrab]             = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.SliderGrabActive]       = ImVec4(0.00, 0.77, 0.37, 1.00)
		colors[clr.Button]                 = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.ButtonHovered]          = ImVec4(0.00, 0.82, 0.39, 1.00)
		colors[clr.ButtonActive]           = ImVec4(0.00, 0.87, 0.42, 1.00)
		colors[clr.Header]                 = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.HeaderHovered]          = ImVec4(0.00, 0.76, 0.37, 0.57)
		colors[clr.HeaderActive]           = ImVec4(0.00, 0.88, 0.42, 0.89)
		colors[clr.Separator]              = ImVec4(1.00, 1.00, 1.00, 0.40)
		colors[clr.SeparatorHovered]       = ImVec4(1.00, 1.00, 1.00, 0.60)
		colors[clr.SeparatorActive]        = ImVec4(1.00, 1.00, 1.00, 0.80)
		colors[clr.ResizeGrip]             = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.ResizeGripHovered]      = ImVec4(0.00, 0.76, 0.37, 1.00)
		colors[clr.ResizeGripActive]       = ImVec4(0.00, 0.86, 0.41, 1.00)
		colors[clr.PlotLines]              = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.PlotLinesHovered]       = ImVec4(0.00, 0.74, 0.36, 1.00)
		colors[clr.PlotHistogram]          = ImVec4(0.00, 0.69, 0.33, 1.00)
		colors[clr.PlotHistogramHovered]   = ImVec4(0.00, 0.80, 0.38, 1.00)
		colors[clr.TextSelectedBg]         = ImVec4(0.00, 0.69, 0.33, 0.72)

    elseif theme == 1 then
       
        colors[clr.Text]                   = ImVec4(0.95, 0.96, 0.98, 1.00)
		colors[clr.TextDisabled]           = ImVec4(1.00, 0.28, 0.28, 1.00)
		colors[clr.WindowBg]               = ImVec4(0.14, 0.14, 0.14, 1.00)
		colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
		colors[clr.Border]                 = ImVec4(0.14, 0.14, 0.14, 1.00)
		colors[clr.BorderShadow]           = ImVec4(1.00, 1.00, 1.00, 0.00)
		colors[clr.FrameBg]                = ImVec4(0.40, 0.14, 0.14, 1.00)
		colors[clr.FrameBgHovered]         = ImVec4(0.18, 0.18, 0.18, 1.00)
		colors[clr.FrameBgActive]          = ImVec4(0.09, 0.12, 0.14, 1.00)
		colors[clr.TitleBg]                = ImVec4(0.14, 0.14, 0.14, 0.81)
		colors[clr.TitleBgActive]          = ImVec4(0.14, 0.14, 0.14, 1.00)
		colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
		colors[clr.MenuBarBg]              = ImVec4(0.20, 0.20, 0.20, 1.00)
		colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.39)
		colors[clr.ScrollbarGrab]          = ImVec4(0.36, 0.36, 0.36, 1.00)
		colors[clr.ScrollbarGrabHovered]   = ImVec4(0.18, 0.22, 0.25, 1.00)
		colors[clr.ScrollbarGrabActive]    = ImVec4(0.24, 0.24, 0.24, 1.00)
		colors[clr.CheckMark]              = ImVec4(1.00, 0.28, 0.28, 1.00)
		colors[clr.SliderGrab]             = ImVec4(1.00, 0.28, 0.28, 1.00)
		colors[clr.SliderGrabActive]       = ImVec4(1.00, 0.28, 0.28, 1.00)
		colors[clr.Button]                 = ImVec4(1.00, 0.28, 0.28, 1.00)
		colors[clr.ButtonHovered]          = ImVec4(1.00, 0.39, 0.39, 1.00)
		colors[clr.ButtonActive]           = ImVec4(1.00, 0.21, 0.21, 1.00)
		colors[clr.Header]                 = ImVec4(1.00, 0.28, 0.28, 1.00)
		colors[clr.HeaderHovered]          = ImVec4(1.00, 0.39, 0.39, 1.00)
		colors[clr.HeaderActive]           = ImVec4(1.00, 0.21, 0.21, 1.00)
		colors[clr.ResizeGrip]             = ImVec4(1.00, 0.28, 0.28, 1.00)
		colors[clr.ResizeGripHovered]      = ImVec4(1.00, 0.39, 0.39, 1.00)
		colors[clr.ResizeGripActive]       = ImVec4(1.00, 0.19, 0.19, 1.00)
		colors[clr.PlotLines]              = ImVec4(0.61, 0.61, 0.61, 1.00)
		colors[clr.PlotLinesHovered]       = ImVec4(1.00, 0.43, 0.35, 1.00)
		colors[clr.PlotHistogram]          = ImVec4(1.00, 0.21, 0.21, 1.00)
		colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.18, 0.18, 1.00)
		colors[clr.TextSelectedBg]         = ImVec4(1.00, 0.32, 0.32, 1.00)


    elseif theme == 2 then

        colors[clr.FrameBg]                = ImVec4(0.46, 0.11, 0.29, 1.00)
		colors[clr.FrameBgHovered]         = ImVec4(0.69, 0.16, 0.43, 1.00)
		colors[clr.FrameBgActive]          = ImVec4(0.58, 0.10, 0.35, 1.00)
		colors[clr.TitleBg]                = ImVec4(0.00, 0.00, 0.00, 1.00)
		colors[clr.TitleBgActive]          = ImVec4(0.61, 0.16, 0.39, 1.00)
		colors[clr.TitleBgCollapsed]       = ImVec4(0.00, 0.00, 0.00, 0.51)
		colors[clr.CheckMark]              = ImVec4(0.94, 0.30, 0.63, 1.00)
		colors[clr.SliderGrab]             = ImVec4(0.85, 0.11, 0.49, 1.00)
		colors[clr.SliderGrabActive]       = ImVec4(0.89, 0.24, 0.58, 1.00)
		colors[clr.Button]                 = ImVec4(0.46, 0.11, 0.29, 1.00)
		colors[clr.ButtonHovered]          = ImVec4(0.69, 0.17, 0.43, 1.00)
		colors[clr.ButtonActive]           = ImVec4(0.59, 0.10, 0.35, 1.00)
		colors[clr.Header]                 = ImVec4(0.46, 0.11, 0.29, 1.00)
		colors[clr.HeaderHovered]          = ImVec4(0.69, 0.16, 0.43, 1.00)
		colors[clr.HeaderActive]           = ImVec4(0.58, 0.10, 0.35, 1.00)
		colors[clr.Separator]              = ImVec4(0.69, 0.16, 0.43, 1.00)
		colors[clr.SeparatorHovered]       = ImVec4(0.58, 0.10, 0.35, 1.00)
		colors[clr.SeparatorActive]        = ImVec4(0.58, 0.10, 0.35, 1.00)
		colors[clr.ResizeGrip]             = ImVec4(0.46, 0.11, 0.29, 0.70)
		colors[clr.ResizeGripHovered]      = ImVec4(0.69, 0.16, 0.43, 0.67)
		colors[clr.ResizeGripActive]       = ImVec4(0.70, 0.13, 0.42, 1.00)
		colors[clr.TextSelectedBg]         = ImVec4(1.00, 0.78, 0.90, 0.35)
		colors[clr.Text]                   = ImVec4(1.00, 1.00, 1.00, 1.00)
		colors[clr.TextDisabled]           = ImVec4(0.60, 0.19, 0.40, 1.00)
		colors[clr.WindowBg]               = ImVec4(0.06, 0.06, 0.06, 0.94)
		colors[clr.PopupBg]                = ImVec4(0.08, 0.08, 0.08, 0.94)
		colors[clr.Border]                 = ImVec4(0.49, 0.14, 0.31, 1.00)
		colors[clr.BorderShadow]           = ImVec4(0.49, 0.14, 0.31, 0.00)
		colors[clr.MenuBarBg]              = ImVec4(0.15, 0.15, 0.15, 1.00)
		colors[clr.ScrollbarBg]            = ImVec4(0.02, 0.02, 0.02, 0.53)
		colors[clr.ScrollbarGrab]          = ImVec4(0.31, 0.31, 0.31, 1.00)
		colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
		colors[clr.ScrollbarGrabActive]    = ImVec4(0.51, 0.51, 0.51, 1.00)

    elseif theme == 3 then

        colors[clr.WindowBg]              = ImVec4(0.14, 0.12, 0.16, 1.00)
		colors[clr.PopupBg]               = ImVec4(0.05, 0.05, 0.10, 0.90)
		colors[clr.Border]                = ImVec4(0.89, 0.85, 0.92, 0.30)
		colors[clr.BorderShadow]          = ImVec4(0.00, 0.00, 0.00, 0.00)
		colors[clr.FrameBg]               = ImVec4(0.30, 0.20, 0.39, 1.00)
		colors[clr.FrameBgHovered]        = ImVec4(0.41, 0.19, 0.63, 0.68)
		colors[clr.FrameBgActive]         = ImVec4(0.41, 0.19, 0.63, 1.00)
		colors[clr.TitleBg]               = ImVec4(0.41, 0.19, 0.63, 0.45)
		colors[clr.TitleBgCollapsed]      = ImVec4(0.41, 0.19, 0.63, 0.35)
		colors[clr.TitleBgActive]         = ImVec4(0.41, 0.19, 0.63, 0.78)
		colors[clr.MenuBarBg]             = ImVec4(0.30, 0.20, 0.39, 0.57)
		colors[clr.ScrollbarBg]           = ImVec4(0.30, 0.20, 0.39, 1.00)
		colors[clr.ScrollbarGrab]         = ImVec4(0.41, 0.19, 0.63, 0.31)
		colors[clr.ScrollbarGrabHovered]  = ImVec4(0.41, 0.19, 0.63, 0.78)
		colors[clr.ScrollbarGrabActive]   = ImVec4(0.41, 0.19, 0.63, 1.00)
		colors[clr.CheckMark]             = ImVec4(0.56, 0.61, 1.00, 1.00)
		colors[clr.SliderGrab]            = ImVec4(0.41, 0.19, 0.63, 0.24)
		colors[clr.SliderGrabActive]      = ImVec4(0.41, 0.19, 0.63, 1.00)
		colors[clr.Button]                = ImVec4(0.41, 0.19, 0.63, 0.44)
		colors[clr.ButtonHovered]         = ImVec4(0.41, 0.19, 0.63, 0.86)
		colors[clr.ButtonActive]          = ImVec4(0.64, 0.33, 0.94, 1.00)
		colors[clr.Header]                = ImVec4(0.41, 0.19, 0.63, 0.76)
		colors[clr.HeaderHovered]         = ImVec4(0.41, 0.19, 0.63, 0.86)
		colors[clr.HeaderActive]          = ImVec4(0.41, 0.19, 0.63, 1.00)
		colors[clr.ResizeGrip]            = ImVec4(0.41, 0.19, 0.63, 0.20)
		colors[clr.ResizeGripHovered]     = ImVec4(0.41, 0.19, 0.63, 0.78)
		colors[clr.ResizeGripActive]      = ImVec4(0.41, 0.19, 0.63, 1.00)
		colors[clr.PlotLines]             = ImVec4(0.89, 0.85, 0.92, 0.63)
		colors[clr.PlotLinesHovered]      = ImVec4(0.41, 0.19, 0.63, 1.00)
		colors[clr.PlotHistogram]         = ImVec4(0.89, 0.85, 0.92, 0.63)
		colors[clr.PlotHistogramHovered]  = ImVec4(0.41, 0.19, 0.63, 1.00)
		colors[clr.TextSelectedBg]        = ImVec4(0.41, 0.19, 0.63, 0.43)
		colors[clr.TextDisabled]          = ImVec4(0.41, 0.19, 0.63, 1.00)

    elseif theme == 4 then

        colors[clr.Text]                  = ImVec4(0.86, 0.93, 0.89, 0.78)
		colors[clr.TextDisabled]          = ImVec4(0.71, 0.22, 0.27, 1.00)
		colors[clr.WindowBg]              = ImVec4(0.13, 0.14, 0.17, 1.00)
		colors[clr.PopupBg]               = ImVec4(0.20, 0.22, 0.27, 0.90)
		colors[clr.Border]                = ImVec4(0.31, 0.31, 1.00, 0.00)
		colors[clr.BorderShadow]          = ImVec4(0.00, 0.00, 0.00, 0.00)
		colors[clr.FrameBg]               = ImVec4(0.20, 0.22, 0.27, 1.00)
		colors[clr.FrameBgHovered]        = ImVec4(0.46, 0.20, 0.30, 0.78)
		colors[clr.FrameBgActive]         = ImVec4(0.46, 0.20, 0.30, 1.00)
		colors[clr.TitleBg]               = ImVec4(0.23, 0.20, 0.27, 1.00)
		colors[clr.TitleBgActive]         = ImVec4(0.50, 0.08, 0.26, 1.00)
		colors[clr.TitleBgCollapsed]      = ImVec4(0.20, 0.20, 0.27, 0.75)
		colors[clr.MenuBarBg]             = ImVec4(0.20, 0.22, 0.27, 0.47)
		colors[clr.ScrollbarBg]           = ImVec4(0.20, 0.22, 0.27, 1.00)
		colors[clr.ScrollbarGrab]         = ImVec4(0.09, 0.15, 0.10, 1.00)
		colors[clr.ScrollbarGrabHovered]  = ImVec4(0.46, 0.20, 0.30, 0.78)
		colors[clr.ScrollbarGrabActive]   = ImVec4(0.46, 0.20, 0.30, 1.00)
		colors[clr.CheckMark]             = ImVec4(0.71, 0.22, 0.27, 1.00)
		colors[clr.SliderGrab]            = ImVec4(0.47, 0.77, 0.83, 0.14)
		colors[clr.SliderGrabActive]      = ImVec4(0.71, 0.22, 0.27, 1.00)
		colors[clr.Button]                = ImVec4(0.47, 0.77, 0.83, 0.14)
		colors[clr.ButtonHovered]         = ImVec4(0.46, 0.20, 0.30, 0.86)
		colors[clr.ButtonActive]          = ImVec4(0.46, 0.20, 0.30, 1.00)
		colors[clr.Header]                = ImVec4(0.46, 0.20, 0.30, 0.76)
		colors[clr.HeaderHovered]         = ImVec4(0.46, 0.20, 0.30, 0.86)
		colors[clr.HeaderActive]          = ImVec4(0.50, 0.08, 0.26, 1.00)
		colors[clr.ResizeGrip]            = ImVec4(0.47, 0.77, 0.83, 0.04)
		colors[clr.ResizeGripHovered]     = ImVec4(0.46, 0.20, 0.30, 0.78)
		colors[clr.ResizeGripActive]      = ImVec4(0.46, 0.20, 0.30, 1.00)
		colors[clr.PlotLines]             = ImVec4(0.86, 0.93, 0.89, 0.63)
		colors[clr.PlotLinesHovered]      = ImVec4(0.46, 0.20, 0.30, 1.00)
		colors[clr.PlotHistogram]         = ImVec4(0.86, 0.93, 0.89, 0.63)
		colors[clr.PlotHistogramHovered]  = ImVec4(0.46, 0.20, 0.30, 1.00)
		colors[clr.TextSelectedBg]        = ImVec4(0.46, 0.20, 0.30, 0.43)

    elseif theme == 5 then

        colors[clr.Text]                 = ImVec4(0.92, 0.92, 0.92, 1.00)
		colors[clr.TextDisabled]         = ImVec4(0.78, 0.55, 0.21, 1.00)
		colors[clr.WindowBg]             = ImVec4(0.06, 0.06, 0.06, 1.00)
		colors[clr.PopupBg]              = ImVec4(0.08, 0.08, 0.08, 0.94)
		colors[clr.Border]               = ImVec4(0.51, 0.36, 0.15, 1.00)
		colors[clr.BorderShadow]         = ImVec4(0.00, 0.00, 0.00, 0.00)
		colors[clr.FrameBg]              = ImVec4(0.50, 0.36, 0.15, 1.00)
		colors[clr.FrameBgHovered]       = ImVec4(0.51, 0.36, 0.15, 1.00)
		colors[clr.FrameBgActive]        = ImVec4(0.78, 0.55, 0.21, 1.00)
		colors[clr.TitleBg]              = ImVec4(0.51, 0.36, 0.15, 1.00)
		colors[clr.TitleBgActive]        = ImVec4(0.91, 0.64, 0.13, 1.00)
		colors[clr.TitleBgCollapsed]     = ImVec4(0.00, 0.00, 0.00, 0.51)
		colors[clr.MenuBarBg]            = ImVec4(0.11, 0.11, 0.11, 1.00)
		colors[clr.ScrollbarBg]          = ImVec4(0.06, 0.06, 0.06, 0.53)
		colors[clr.ScrollbarGrab]        = ImVec4(0.21, 0.21, 0.21, 1.00)
		colors[clr.ScrollbarGrabHovered] = ImVec4(0.47, 0.47, 0.47, 1.00)
		colors[clr.ScrollbarGrabActive]  = ImVec4(0.81, 0.83, 0.81, 1.00)
		colors[clr.CheckMark]            = ImVec4(0.78, 0.55, 0.21, 1.00)
		colors[clr.SliderGrab]           = ImVec4(0.91, 0.64, 0.13, 1.00)
		colors[clr.SliderGrabActive]     = ImVec4(0.91, 0.64, 0.13, 1.00)
		colors[clr.Button]               = ImVec4(0.51, 0.36, 0.15, 1.00)
		colors[clr.ButtonHovered]        = ImVec4(0.91, 0.64, 0.13, 1.00)
		colors[clr.ButtonActive]         = ImVec4(0.78, 0.55, 0.21, 1.00)
		colors[clr.Header]               = ImVec4(0.51, 0.36, 0.15, 1.00)
		colors[clr.HeaderHovered]        = ImVec4(0.91, 0.64, 0.13, 1.00)
		colors[clr.HeaderActive]         = ImVec4(0.93, 0.65, 0.14, 1.00)
		colors[clr.Separator]            = ImVec4(0.21, 0.21, 0.21, 1.00)
		colors[clr.SeparatorHovered]     = ImVec4(0.91, 0.64, 0.13, 1.00)
		colors[clr.SeparatorActive]      = ImVec4(0.78, 0.55, 0.21, 1.00)
		colors[clr.ResizeGrip]           = ImVec4(0.21, 0.21, 0.21, 1.00)
		colors[clr.ResizeGripHovered]    = ImVec4(0.91, 0.64, 0.13, 1.00)
		colors[clr.ResizeGripActive]     = ImVec4(0.78, 0.55, 0.21, 1.00)
		colors[clr.PlotLines]            = ImVec4(0.61, 0.61, 0.61, 1.00)
		colors[clr.PlotLinesHovered]     = ImVec4(1.00, 0.43, 0.35, 1.00)
		colors[clr.PlotHistogram]        = ImVec4(0.90, 0.70, 0.00, 1.00)
		colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
		colors[clr.TextSelectedBg]       = ImVec4(0.26, 0.59, 0.98, 0.35)

    elseif theme == 6 then

        colors[clr.Text]                 = ImVec4(0.92, 0.95, 0.97, 1.00)
        colors[clr.TextDisabled]         = ImVec4(0.65, 0.78, 0.85, 1.00)
        colors[clr.WindowBg]             = ImVec4(0.10, 0.15, 0.18, 1.00)
        colors[clr.PopupBg]              = ImVec4(0.12, 0.18, 0.22, 0.94)
        colors[clr.Border]               = ImVec4(0.30, 0.45, 0.55, 1.00)
        colors[clr.BorderShadow]         = ImVec4(0.00, 0.00, 0.00, 0.00)
        colors[clr.FrameBg]              = ImVec4(0.20, 0.30, 0.38, 0.85)
        colors[clr.FrameBgHovered]       = ImVec4(0.35, 0.70, 0.90, 1.00)
        colors[clr.FrameBgActive]        = ImVec4(0.28, 0.58, 0.80, 1.00)
        colors[clr.TitleBg]              = ImVec4(0.16, 0.30, 0.40, 1.00)
        colors[clr.TitleBgActive]        = ImVec4(0.28, 0.58, 0.80, 1.00)
        colors[clr.TitleBgCollapsed]     = ImVec4(0.00, 0.00, 0.00, 0.51)
        colors[clr.MenuBarBg]            = ImVec4(0.13, 0.20, 0.25, 1.00)
        colors[clr.ScrollbarBg]          = ImVec4(0.10, 0.14, 0.18, 0.53)
        colors[clr.ScrollbarGrab]        = ImVec4(0.28, 0.50, 0.65, 1.00)
        colors[clr.ScrollbarGrabHovered] = ImVec4(0.38, 0.65, 0.85, 1.00)
        colors[clr.ScrollbarGrabActive]  = ImVec4(0.50, 0.75, 0.95, 1.00)
        colors[clr.CheckMark]            = ImVec4(0.40, 0.85, 0.95, 1.00)
        colors[clr.SliderGrab]           = ImVec4(0.35, 0.65, 0.90, 1.00)
        colors[clr.SliderGrabActive]     = ImVec4(0.28, 0.58, 0.80, 1.00)
        colors[clr.Button]               = ImVec4(0.24, 0.42, 0.58, 1.00)
        colors[clr.ButtonHovered]        = ImVec4(0.35, 0.70, 0.90, 1.00)
        colors[clr.ButtonActive]         = ImVec4(0.28, 0.58, 0.80, 1.00)
        colors[clr.Header]               = ImVec4(0.28, 0.50, 0.65, 1.00)
        colors[clr.HeaderHovered]        = ImVec4(0.35, 0.70, 0.90, 1.00)
        colors[clr.HeaderActive]         = ImVec4(0.28, 0.58, 0.80, 1.00)
        colors[clr.Separator]            = ImVec4(0.22, 0.33, 0.40, 1.00)
        colors[clr.SeparatorHovered]     = ImVec4(0.35, 0.70, 0.90, 1.00)
        colors[clr.SeparatorActive]      = ImVec4(0.28, 0.58, 0.80, 1.00)
        colors[clr.ResizeGrip]           = ImVec4(0.24, 0.42, 0.58, 1.00)
        colors[clr.ResizeGripHovered]    = ImVec4(0.35, 0.70, 0.90, 1.00)
        colors[clr.ResizeGripActive]     = ImVec4(0.28, 0.58, 0.80, 1.00)
        colors[clr.PlotLines]            = ImVec4(0.70, 0.80, 0.90, 1.00)
        colors[clr.PlotLinesHovered]     = ImVec4(0.40, 0.85, 0.95, 1.00)
        colors[clr.PlotHistogram]        = ImVec4(0.50, 0.85, 0.90, 1.00)
        colors[clr.PlotHistogramHovered] = ImVec4(0.40, 0.95, 1.00, 1.00)
        colors[clr.TextSelectedBg]       = ImVec4(0.28, 0.58, 0.80, 0.35)

    end
end