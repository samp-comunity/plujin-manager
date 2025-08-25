script_name("GamePatch")
script_author("_vxnzz")
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

local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")
local socket = require("socket")
local ssl = require("ssl")

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
local directIni  = "GamePatch.ini"
local ini = inicfg.load({
	settings = {
        theme = 0
	}
}, directIni )
inicfg.save(ini, directIni)

function save()
    inicfg.save(ini, directIni)
end

local sw, sh = getScreenResolution()

local new = imgui.new
local windowState = new.bool(false)
local filters = new.bool(false)

  ---------------------- [FFI]----------------------
ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]

---------------------- [Function main]----------------------
function main()
	local fileName = getWorkingDirectory() .. "/GamePatch.lua"
	
	if fileExists(fileName) then
		print("cargado correctamente")
	else
		print("No renombres el mod")
		thisScript():unload()
	end
    repeat wait(0) until isSampAvailable()
    
   while true do
        if isWidgetSwipedRight(WIDGET_RADAR) then
            windowState[0] = not windowState[0]
        end
        wait(0)
    end
	
end

local repoFiles = {}

-- etiquetas con estado + colores
local etiquetas = {
    Legal = {
        activo = false,
        colorOff = imgui.ImVec4(0.4, 0.2, 0.5, 0.5), -- púrpura opaco
        colorOn  = imgui.ImVec4(0.7, 0.3, 0.9, 0.9), -- púrpura vivo
    },
    Ilegal = {
        activo = false,
        colorOff = imgui.ImVec4(0.5, 0.2, 0.2, 0.5), -- rojo opaco
        colorOn  = imgui.ImVec4(0.9, 0.3, 0.3, 0.9), -- rojo vivo
    }
}

-- dibuja etiquetas y refresca lista al cambiar
function DrawEtiquetas()
    imgui.Text("Etiquetas")
    imgui.Spacing()

    local colorTextoOff = imgui.ImVec4(0.7, 0.7, 0.7, 1.0)
    local colorTextoOn  = imgui.ImVec4(1, 1, 1, 1)

    for nombre, data in pairs(etiquetas) do
        if data.activo then
            imgui.PushStyleColor(imgui.Col.Button, data.colorOn)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, data.colorOn)
            imgui.PushStyleColor(imgui.Col.ButtonActive, data.colorOn)
            imgui.PushStyleColor(imgui.Col.Text, colorTextoOn)
        else
            imgui.PushStyleColor(imgui.Col.Button, data.colorOff)
            imgui.PushStyleColor(imgui.Col.ButtonHovered, data.colorOff)
            imgui.PushStyleColor(imgui.Col.ButtonActive, data.colorOff)
            imgui.PushStyleColor(imgui.Col.Text, colorTextoOff)
        end

        if imgui.Button(nombre, imgui.ImVec2(80, 30)) then
            data.activo = not data.activo
            lua_thread.create(function() refreshRepoFiles() end)
        end
        imgui.PopStyleColor(4)

        imgui.SameLine()
    end
end

-- obtiene lista según etiquetas activas
function refreshRepoFiles()
    local urls = {}

    if etiquetas.Legal.activo then
        table.insert(urls, "https://api.github.com/repos/Nelson-hast/plujin-manager/contents/scripts/legal")
    end
    if etiquetas.Ilegal.activo then
        table.insert(urls, "https://api.github.com/repos/Nelson-hast/plujin-manager/contents/scripts/ilegal")
    end

    -- si no hay etiquetas activas → mostrar todo
    if #urls == 0 then
        urls = {
            "https://api.github.com/repos/Nelson-hast/plujin-manager/contents/scripts/legal",
            "https://api.github.com/repos/Nelson-hast/plujin-manager/contents/scripts/ilegal"
        }
    end

    repoFiles = {}

    for _, url in ipairs(urls) do
        local body, code = https.request(url)
        if code == 200 then
            local data, _, err = json.decode(body, 1, nil)
            if not err then
                for _, item in ipairs(data) do
                    if item.type == "file" and item.name:match("%.lua$") then
                        table.insert(repoFiles, { name = item.name, url = item.download_url })
                    end
                end
            end
        else
            print("[Downloader] ❌ Error al obtener lista: " .. tostring(code))
        end
    end

    print("[Downloader] ✅ Lista actualizada con " .. tostring(#repoFiles) .. " archivos")
end

-- refresco inicial automático al arrancar
lua_thread.create(function()
    refreshRepoFiles()
end)


function downloadFile(url, filename)
    local savePath = getWorkingDirectory() .. "/" .. filename
    local file = io.open(savePath, "wb")
    if not file then
        print("[Downloader] ❌ No se pudo abrir el archivo para escribir")
        return false
    end

    -- separar host y ruta
    local host, path = url:match("https://([^/]+)(/.+)")
    local tcp = assert(socket.tcp())
    tcp:connect(host, 443)
    tcp = ssl.wrap(tcp, { mode = "client", protocol = "tlsv1_2", verify = "none" })
    tcp:dohandshake()

    -- mandar request manual
    tcp:send("GET " .. path .. " HTTP/1.1\r\nHost: " .. host .. "\r\nConnection: close\r\n\r\n")

    isDownloading = true
    currentDownload = filename
    downloadProgress = 0.0

    local data = ""
    local headers_done = false
    local totalSize, received = 0, 0

    while true do
        local chunk, status, partial = tcp:receive(1024)
        local buff = chunk or partial
        if buff and #buff > 0 then
            if not headers_done then
                data = data .. buff
                local header_end = data:find("\r\n\r\n", 1, true)
                if header_end then
                    local headers = data:sub(1, header_end)
                    totalSize = tonumber(headers:match("Content%-Length: (%d+)")) or 0
                    file:write(data:sub(header_end+4))
                    received = #data - (header_end+4)
                    headers_done = true
                end
            else
                file:write(buff)
                received = received + #buff
            end
            if totalSize > 0 then
                downloadProgress = received / totalSize
            end
        end
        if status == "closed" then break end
        wait(0) -- 👉 importante, no congela la pantalla
    end

    file:close()
    tcp:close()

    isDownloading = false
    downloadProgress = 1.0
    print("[Downloader] ✅ Descarga terminada: " .. savePath)
    return true
end

function renderDownloaderUI()
    -- etiquetas arriba

    imgui.Separator()

    -- solo dejamos Filter y Actualizar
    if imgui.Button(fa.FILTER) then
        filters[0] = not filters[0]
    end
    imgui.SameLine()
    if imgui.Button(" Actualizar lista") then
        lua_thread.create(function() refreshRepoFiles() end)
    end

    imgui.Separator()

    -- lista de archivos
    for _, f in ipairs(repoFiles) do
        if imgui.Button(f.name) then
            lua_thread.create(function()
                downloadFile(f.url, f.name)
            end)
        end
    end

    -- barra de progreso
    if isDownloading then
        imgui.Separator()
        imgui.Text("Descargando: " .. currentDownload)
        imgui.ProgressBar(downloadProgress, imgui.ImVec2(300, 20))
    end
end


local MainMenu = imgui.OnFrame(
    function() return windowState[0] end,

    function(self)
        imgui.SetNextWindowSize(imgui.ImVec2(622, 388), imgui.Cond.FirstUseEver)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        imgui.Begin("##windowState", windowState, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
        local windowSize = imgui.GetWindowSize()

        imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
        addons.CloseButton("##closemenu", windowState, 33, 5)
        imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(15, 15)) 
        imgui.BeginChild("##settings_inner", imgui.ImVec2(windowSize.x - 30, windowSize.y - 30), false)

        local bgColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
        imgui.PushStyleColor(imgui.Col.Text, bgColor)
        imgui.PushFont(logofont)
        imgui.Text('GamePatch ')
        imgui.PopStyleColor()
        imgui.PopFont()
        imgui.PushFont(font1)
        imgui.Spacing()
        if imgui.Button(fa.REPEAT.. "##reload", imgui.ImVec2(40, 30)) then
            thisScript():reload()
        end
        imgui.Spacing()
        imgui.Spacing()

        imgui.Text("Aquí puedes descargar archivos desde GitHub")
        
        renderDownloaderUI()
        
        imgui.PopFont()
        imgui.EndChild()
        imgui.End()
        imgui.PopStyleVar()
    end
)

local filtersFrame = imgui.OnFrame(
    function() return filters[0] end,

    function(self)
        imgui.SetNextWindowSize(imgui.ImVec2(222, 158), imgui.Cond.FirstUseEver)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        imgui.Begin("##filters", filters, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
        local windowSize = imgui.GetWindowSize()

        imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 43, 10))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
        addons.CloseButton("##closemenu", filters, 33, 5)
        imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(15, 15)) 
        imgui.BeginChild("##settings_inner", imgui.ImVec2(windowSize.x - 30, windowSize.y - 30), false)

        local bgColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
        imgui.PushStyleColor(imgui.Col.Text, bgColor)
        imgui.PushFont(logofont)
        imgui.CenterText('Buscar filtros')
        imgui.PopStyleColor()
        imgui.PopFont()
        imgui.PushFont(font1)
        imgui.Spacing()
   
        DrawEtiquetas()

        imgui.PopFont()
        imgui.EndChild()
        imgui.End()
        imgui.PopStyleVar()
    end
)


function fileExists(filePath)
    local file = io.open(filePath, "r")
    
    if file then
        io.close(file)
        return true
    else
        return false
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

function imgui.CenterText(text)
    imgui.SetCursorPosX(imgui.GetWindowSize().x / 2 - imgui.CalcTextSize(tostring(text)).x / 2)
    imgui.Text(text)
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
    SwitchTheStyle()

    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesDefault()
    local fontPath = getWorkingDirectory()  .. "/resource/fonts/"

	font1 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "Verdana.ttf", 25, nil, glyph_ranges)
	loadFAFont("solid", 20, true)
    loadSCFont(25, true)
	logofont = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "font1.otf", 45, nil, glyph_ranges)
	loadFAFont("solid", 30, true)
end)

function SwitchTheStyle()
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

end