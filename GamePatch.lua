script_name("GamePatch")
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
local scfg = require('jsoncfg')

local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")
local socket = require("socket")
local ssl = require("ssl")
local webview   = require 'webviews'
local lfs = require "lfs"

local function loadLibrary(libName, optionalMessage)
    local success, lib = pcall(require, libName)
    if not success then
        print(string.format('No se encuentra la libreria: "%s"%s', libName, optionalMessage or ""))
    end
    return lib
end

local sc = loadLibrary 'supericon' 

local sw, sh = getScreenResolution()

local new = imgui.new
local windowState = new.bool(false)
local filters = new.bool(false)

  ---------------------- [FFI]----------------------
ffi.cdef[[
    void _Z12AND_OpenLinkPKc(const char* link);
]]

-- ruta absoluta
local basePath = getWorkingDirectory() .. "/resource"
lfs.mkdir(basePath)
lfs.mkdir(basePath .. "/icons")

local Image = {
    file = 'resource/icons/gamefixer.png',
    url = 'https://raw.githubusercontent.com/Nelson-hast/plujin-manager/refs/heads/master/assets/icons/gamefixer.png',
    img = nil
}
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
    
    if not doesFileExist(Image.file) then
        local dlstatus = require('moonloader').download_status
        downloadFile(Image.url, Image.file, function (id, status, p1, p2)
            if status == dlstatus.STATUSEX_ENDDOWNLOAD then
                thisScript():reload()
            end
        end)
    end

   while true do
        if isWidgetSwipedRight(WIDGET_RADAR) then
            windowState[0] = not windowState[0]
        end
        wait(0)
    end
	
end




local DEFAULT_SCRIPT_CONFIG = {
    scripts = {}
}

local scriptConfig = scfg.load(DEFAULT_SCRIPT_CONFIG)

-- tabla que guarda los bool de imgui
local scriptEnabled = {}

-- inicializamos los bool según el JSON
for key, value in pairs(scriptConfig.scripts) do
    scriptEnabled[key] = imgui.new.bool(value)
end


local selectedFile = nil
local showInfoWindow = new.bool(false) -- usar ImGui bool
-- 🔹 Estados de paginación
local currentPage = 1
local itemsPerPage = 8   -- o 8 si prefieres


local repoFiles = {}
local scriptsInfo = {} -- datos extra desde scripts.json

-- 🔽 estados nuevos para el prompt de reinicio
local showRestartPrompt = false
local lastDownloaded = nil

-- 🔹 etiquetas iniciales (fallback mientras carga JSON)
local etiquetas = {
    ["Cargando..."] = {
        activo = false,
        colorOff = imgui.ImVec4(0.3, 0.3, 0.3, 0.5),
        colorOn  = imgui.ImVec4(0.6, 0.6, 0.6, 0.9),
    }
}

-- 🎨 paleta de colores por etiqueta
local coloresEtiquetas = {
    legal = {
        off = imgui.ImVec4(0.2, 0.4, 0.8, 0.3), -- azul opaco
        on  = imgui.ImVec4(0.2, 0.6, 1.0, 0.9), -- azul brillante
    },
    utilidad = {
        off = imgui.ImVec4(0.2, 0.6, 0.2, 0.3), -- verde opaco
        on  = imgui.ImVec4(0.2, 0.9, 0.2, 0.9), -- verde brillante
    },
    visual = {
        off = imgui.ImVec4(0.5, 0.2, 0.7, 0.3), -- morado opaco
        on  = imgui.ImVec4(0.8, 0.4, 1.0, 0.9), -- morado brillante
    },
    sonido = {
        off = imgui.ImVec4(0.6, 0.4, 0.2, 0.3), -- marrón opaco
        on  = imgui.ImVec4(1.0, 0.6, 0.2, 0.9), -- marrón brillante
    },
}

function buildEtiquetas()
    etiquetas = {}
    local found = false
    for _, info in pairs(scriptsInfo) do
        if info.tags and type(info.tags) == "table" then
            for _, tag in ipairs(info.tags) do
                if not etiquetas[tag] then
                    local colores = coloresEtiquetas[string.lower(tag)]
                    if colores then
                        etiquetas[tag] = {
                            activo = false,
                            colorOff = colores.off,
                            colorOn  = colores.on,
                        }
                    else
                        -- fallback gris si no definiste color
                        etiquetas[tag] = {
                            activo = false,
                            colorOff = imgui.ImVec4(0.4, 0.4, 0.4, 0.3),
                            colorOn  = imgui.ImVec4(0.7, 0.7, 0.7, 0.9),
                        }
                    end
                end
                found = true
            end
        end
    end
    -- si el JSON no tenía etiquetas → dejar dummy
    if not found then
        etiquetas["Sin etiquetas"] = {
            activo = false,
            colorOff = imgui.ImVec4(0.3, 0.3, 0.3, 0.5),
            colorOn  = imgui.ImVec4(0.6, 0.6, 0.6, 0.9),
        }
    end
end

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

        -- 🔹 Ajustar botón al tamaño del texto
        local textSize = imgui.CalcTextSize(nombre)
        local paddingX, paddingY = 20, 8
        local buttonSize = imgui.ImVec2(textSize.x + paddingX, textSize.y + paddingY)

        if imgui.Button(nombre, buttonSize) then
            data.activo = not data.activo
            lua_thread.create(function() refreshRepoFiles() end)
        end
        imgui.PopStyleColor(4)
        imgui.SameLine()
    end
end

local isRefreshing = false
repoFiles = {}

function refreshRepoFiles()
    isRefreshing = true
    repoFiles = {}

    lua_thread.create(function()
        local tempList = {}
        -- 🔹 scriptsInfo ya tiene los mods desde el JSON
        for name, info in pairs(scriptsInfo) do
            local include = true

            -- 🔑 verificar si hay filtros activos
            local hayFiltros = false
            for _, data in pairs(etiquetas) do
                if data.activo then
                    hayFiltros = true
                    break
                end
            end

            if hayFiltros then
                include = false
                if info.tags and type(info.tags) == "table" then
                    for _, tag in ipairs(info.tags) do
                        if etiquetas[tag] and etiquetas[tag].activo then
                            include = true
                            break
                        end
                    end
                end
            end

            -- si pasa filtros → agregar
            if include then
                table.insert(tempList, { name = name, url = info.url })
            end
            wait(0)
        end

        -- 🔹 ordenar alfabéticamente los que no son "GamePatch.lua"
        table.sort(tempList, function(a, b)
            return a.name:lower() < b.name:lower()
        end)

        -- 🔹 armar repoFiles con fijo primero
        repoFiles = {}
        for i, f in ipairs(tempList) do
            if f.name == "GamePatch.lua" then
                table.insert(repoFiles, 1, f) -- siempre en la posición 1
            else
                table.insert(repoFiles, f)
            end
        end

        print("[Downloader] ✅ Lista actualizada con " .. tostring(#repoFiles) .. " archivos")
        isRefreshing = false
    end)
end


-- 🔹 llamada inicial: al iniciar el script siempre actualiza la lista
lua_thread.create(function()
    wait(2000) -- espera 2s a que todo cargue
    refreshRepoFiles()
end)

-- 🔽 en vez de solo uno, usamos lista acumulativa
local installedPending = {}

function downloadFile(url, filename)
    local savePath = getWorkingDirectory() .. "/" .. filename
    local file = io.open(savePath, "wb")
    if not file then
        print("[Downloader] ❌ No se pudo abrir el archivo para escribir")
        return false
    end

    local host, path = url:match("https://([^/]+)(/.+)")
    local tcp = assert(socket.tcp())
    tcp:connect(host, 443)
    tcp = ssl.wrap(tcp, { mode = "client", protocol = "tlsv1_2", verify = "none" })
    tcp:dohandshake()

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
        wait(0)
    end

    file:close()
    tcp:close()

    isDownloading = false
    downloadProgress = 1.0

    -- 🔽 limpiar cache para que el botón cambie a "Desinstalar"
    clearStatusCache()

    -- 🔽 en vez de 1 archivo, acumulamos varios
    table.insert(installedPending, filename)
    showRestartPrompt = true

    print("[Downloader] ✅ Descarga terminada: " .. savePath)
    return true
end


function loadScriptsInfo()
    local url = "https://raw.githubusercontent.com/Nelson-hast/plujin-manager/refs/heads/master/assets/scripts.json"
    local body, code = https.request(url)
    if code == 200 and body then
        local data, _, err = json.decode(body, 1, nil)
        if not err and type(data) == "table" and data.mods then
            scriptsInfo = {} -- limpiar antes de recargar
            for _, mod in ipairs(data.mods) do
                scriptsInfo[mod.name] = mod

                -- 🔹 Ruta local del icono
                if mod.icon and mod.icon ~= "" then
                    local localIcon = basePath .. "/icons/" .. mod.name .. ".png"
                    scriptsInfo[mod.name].iconFile = localIcon

                    -- si no existe el archivo → descargarlo
                    if not doesFileExist(localIcon) then
                        lua_thread.create(function()
                            downloadFile(mod.icon, "resource/icons/" .. mod.name .. ".png")
                        end)
                    else
                        -- si ya existe, crear la textura
                        scriptsInfo[mod.name].img = imgui.CreateTextureFromFile(localIcon)
                    end
                end
            end
            print("[Downloader] ✅ Datos extra cargados de scripts.json")
        else
            print("[Downloader] ❌ Error al decodificar scripts.json")
        end
    else
        print("[Downloader] ❌ No se pudo cargar scripts.json, code: " .. tostring(code))
    end

    -- 🔹 reconstruir etiquetas dinámicas
    buildEtiquetas()

    -- 🔹 refrescar lista con nuevas etiquetas
    refreshRepoFiles()
end


lua_thread.create(function()
    loadScriptsInfo()
end)

lua_thread.create(function()
    wait(1000) -- esperamos 1s que terminen de cargar todos
    for _, scr in ipairs(script.list()) do
        local filename = scr.path:match("([^/\\]+)$") -- solo nombre
        local key = filename:gsub("%.lua$", "")
        if scriptConfig.scripts[key] ~= nil and not scriptConfig.scripts[key] then
            print("[GamePatch] 🔴 Desactivando " .. filename .. " (guardado en config)")
            script.unload(scr)
        end
    end
end)




-- renderDownloaderUI con cuadritos y botón "Descargar" en azul
function renderDownloaderUI()
    imgui.Separator()

    if imgui.Button(fa.FILTER) then
        filters[0] = not filters[0]
    end
    imgui.SameLine()
    if imgui.Button(" Actualizar lista") then
        refreshRepoFiles()
    end

    imgui.Separator()
    imgui.NewLine()

    if isRefreshing then
        local winSize = imgui.GetWindowSize()
        local cursorPos = imgui.GetCursorPos()
        local availableHeight = winSize.y - cursorPos.y

        local spinnerSize = 36
        local spinnerThickness = 5
        local centerX = (winSize.x / 2) - (spinnerSize / 2)
        local centerY = cursorPos.y + (availableHeight / 2) - (spinnerSize / 2)

        imgui.SetCursorPos(imgui.ImVec2(centerX, centerY))
        Spinner("##refreshspinner", spinnerSize, spinnerThickness, imgui.ImVec4(1, 1, 1, 1))
    else
      -- Medidas de cada item
        local itemWidth = 200
        local itemHeight = 250
        local spacing = 0

        -- Tamaño de ventana
        local winSize = imgui.GetWindowSize()
        local maxCols = math.max(1, math.min(4, math.floor((winSize.x - 40) / (itemWidth + spacing))))


        -- Paginación
        local totalPages = math.max(1, math.ceil(#repoFiles / itemsPerPage))
        local startIndex = (currentPage - 1) * itemsPerPage + 1
        local endIndex = math.min(startIndex + itemsPerPage - 1, #repoFiles)

        -- 🔹 Calcular filas necesarias en esta página
        local numItems = endIndex - startIndex + 1
        local rows = math.ceil(numItems / maxCols)

        -- 🔹 Ancho y alto del contenedor padre
        local parentWidth = winSize.x * 1

        -- 🔹 Centrar horizontalmente
        local avail = imgui.GetContentRegionAvail()
        local offsetX = (avail.x - parentWidth) / 2
        if offsetX > 0 then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
        end

        local parentHeight = 600
        imgui.BeginChild("##mods_parent", imgui.ImVec2(parentWidth, parentHeight), false)

            local col = 0
            for i = startIndex, endIndex do
                local f = repoFiles[i]

                -- 🔹 Si es el primer item de la fila, aplicar centrado REAL
                -- 🔹 Si es el primer item de la fila, aplicar centrado REAL por fila
                if col == 0 then
                    local itemsLeft = math.min(maxCols, endIndex - i + 1) -- cuantos quedan en esta fila
                    local rowWidth = itemsLeft * (itemWidth + spacing) - spacing

                    -- ancho real del contenedor padre
                    local parentContentWidth = imgui.GetWindowContentRegionWidth()

                    local offsetX = (parentContentWidth - rowWidth) / 2
                    if offsetX > 0 then
                        imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
                    end
                end

                imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.15, 0.15, 0.15, 1.0)) 
                imgui.BeginChild("##mod_" .. f.name, imgui.ImVec2(itemWidth, itemHeight), false)

                    imgui.NewLine()
                    local imgSize = 90
local extra = scriptsInfo[f.name]

if extra and extra.img then
    -- 🔹 centrar el cuadrado del icono dentro del begin grande
    local avail = imgui.GetContentRegionAvail()
    local offsetX = (avail.x - imgSize) / 2
    if offsetX > 0 then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
    end

    imgui.BeginChild("##icon_" .. f.name, imgui.ImVec2(imgSize, imgSize), false)
        imgui.Image(extra.img, imgui.ImVec2(imgSize, imgSize))
    imgui.EndChild()
else
    -- 🔹 si aún no se descargó el icono → mostrar spinner placeholder
    local avail = imgui.GetContentRegionAvail()
    local offsetX = (avail.x - imgSize) / 2
    if offsetX > 0 then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
    end

    imgui.BeginChild("##icon_empty_" .. f.name, imgui.ImVec2(imgSize, imgSize), false)
        local spinnerSize = 20
        local spinnerThickness = 2.5

        local childSize = imgui.GetWindowSize()
        local posX = childSize.x / 2
        local posY = childSize.y / 2

        imgui.SetCursorPos(imgui.ImVec2(posX, posY))
        Spinner("##checkspinner_" .. f.name, spinnerSize, spinnerThickness, imgui.ImVec4(1,1,1,1))
    imgui.EndChild()
end

                    imgui.Spacing()

                    -- 🔹 Nombre centrado
                    local displayName = f.name:gsub("%.lua$", "")
                    imgui.CenterText(displayName)
                    imgui.Spacing()

                    -- Verificar si está instalado
                    local savePath = getWorkingDirectory() .. "/" .. f.name
                    local isInstalled = fileExists(savePath)
                    local label = isInstalled and "Ver info" or "Descargar"

                    if not isInstalled then
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.0, 0.45, 0.85, 1.0))
                        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.0, 0.55, 1.0, 1.0))
                        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.0, 0.35, 0.7, 1.0))
                    end

                    if isInstalled and f.name ~= "GamePatch.lua" then
                        local key = f.name:gsub("%.lua$", "")

                        if scriptConfig.scripts[key] == nil then
                            scriptConfig.scripts[key] = true
                            scfg.save(scriptConfig)
                        end

                        if scriptEnabled[key] == nil then
                            scriptEnabled[key] = imgui.new.bool(scriptConfig.scripts[key])
                            print("[DEBUG] Creado checkbox para "..key.." con valor:", scriptConfig.scripts[key])
                        else
                            scriptEnabled[key][0] = scriptConfig.scripts[key]
                        end

                        -- 🔹 Layout con checkbox + botón centrados
                        local checkSize = imgui.GetFrameHeight()
                        local btnWidth = imgui.CalcTextSize(label).x + 20
                        local totalWidth = checkSize + 6 + btnWidth
                        local avail = imgui.GetContentRegionAvail()
                        local offsetX = (avail.x - totalWidth) / 2
                        if offsetX > 0 then
                            imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
                        end

                        imgui.BeginGroup()

                            if imgui.Checkbox("##"..key, scriptEnabled[key]) then
                                scriptConfig.scripts[key] = scriptEnabled[key][0]
                                scfg.save(scriptConfig)

                                if scriptEnabled[key][0] then
                                    local path = getWorkingDirectory() .. "/" .. f.name
                                    script.load(path)
                                else
                                    for _, scr in ipairs(script.list()) do
                                        if scr.path:find(f.name, 1, true) then
                                            script.unload(scr)
                                            break
                                        end
                                    end
                                end
                            end

                            imgui.SameLine()

                            if imgui.Button(label .. "##" .. f.name, imgui.ImVec2(btnWidth, 30)) then
                                selectedFile = f
                                showInfoWindow[0] = true
                            end

                        imgui.EndGroup()

                    else
                        -- 🔹 Solo el botón centrado
                        local btnWidth = imgui.CalcTextSize(label).x + 20
                        local avail = imgui.GetContentRegionAvail()
                        local offsetX = (avail.x - btnWidth) / 2
                        if offsetX > 0 then
                            imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
                        end

                        if imgui.Button(label .. "##" .. f.name, imgui.ImVec2(btnWidth, 30)) then
                            selectedFile = f
                            showInfoWindow[0] = true
                        end
                    end

                    if not isInstalled then
                        imgui.PopStyleColor(3)
                    end

                imgui.EndChild()
                imgui.PopStyleColor()

                col = col + 1
                if col < maxCols then
                    imgui.SameLine()
                else
                    col = 0
                end
            end

            if totalPages > 1 then
                -- 🔹 Medidas
                local btnWidth, btnHeight = 100, 30
                local winSize = imgui.GetWindowSize()
                local contentMin = imgui.GetWindowContentRegionMin()
                local contentMax = imgui.GetWindowContentRegionMax()

                -- 🔹 Posición vertical (centrado respecto al parentHeight)
                local parentY = parentHeight / 2
                local offsetY = parentY - (btnHeight / 2)

                -- Guardar cursor actual
                local oldCursor = imgui.GetCursorPos()

                -- 🔹 Botón "Anterior" → izquierda (solo si currentPage > 1)
                if currentPage > 1 then
                    imgui.SetCursorPos(imgui.ImVec2(contentMin.x, offsetY))
                    if imgui.Button("◀ Anterior", imgui.ImVec2(btnWidth, btnHeight)) then
                        currentPage = currentPage - 1
                    end
                end

                -- 🔹 Botón "Siguiente" → derecha (solo si currentPage < totalPages)
                if currentPage < totalPages then
                    imgui.SetCursorPos(imgui.ImVec2(contentMax.x - btnWidth, offsetY))
                    if imgui.Button("Siguiente ▶", imgui.ImVec2(btnWidth, btnHeight)) then
                        currentPage = currentPage + 1
                    end
                end

            end

        imgui.EndChild()

    end

    imgui.Spacing()

    imgui.Image(Image.img, imgui.ImVec2(100, 100))

      if isDownloading then
        imgui.Separator()
        imgui.Text("Descargando: " .. currentDownload)

        -- ===== Config =====
        local barSize          = imgui.ImVec2(360, 22)  -- barra más ancha
        local spinnerRadius    = 12                     -- spinner más grande
        local spinnerThickness = 3
        local gap              = 16                     -- espacio entre spinner y barra
        local gapText          = 12                     -- espacio entre barra y porcentaje
        local leftPad          = 6                      -- margen izquierdo

        -- Alturas para centrar verticalmente spinner vs barra vs texto
        local barH        = barSize.y
        local spinnerH    = spinnerRadius * 2
        local alignOffset = (barH - spinnerH) * 0.5

        -- Porcentaje redondeado (0–100%)
        local percentStr  = tostring(math.floor(downloadProgress * 100 + 0.5)) .. "%"

        -- Calcular ancho total del grupo
        local textWidth   = imgui.CalcTextSize(percentStr).x
        local groupWidth  = leftPad + spinnerH + gap + barSize.x + gapText + textWidth
        local winWidth    = imgui.GetWindowSize().x

        -- Centrar grupo en ventana
        local startX = (winWidth - groupWidth) * 0.5
        local baseY  = imgui.GetCursorPosY()

        imgui.BeginGroup()
            -- Spinner
            imgui.SetCursorPos(imgui.ImVec2(startX + leftPad, baseY + alignOffset))
            Spinner("##downloadspinner", spinnerRadius, spinnerThickness, imgui.ImVec4(0.0, 0.85, 0.45, 1.0))

            -- Barra
            imgui.SetCursorPos(imgui.ImVec2(startX + leftPad + spinnerH + gap, baseY))
            imgui.ProgressBar(downloadProgress, barSize, "")

            -- Texto porcentaje (ej: "42%")
            local textHeight = imgui.CalcTextSize(percentStr).y
            imgui.SetCursorPos(imgui.ImVec2(startX + leftPad + spinnerH + gap + barSize.x + gapText,
                                            baseY + (barH - textHeight) * 0.5))
            imgui.TextUnformatted(percentStr)
        imgui.EndGroup()
    end

    if showRestartPrompt and #installedPending > 0 then
        imgui.Separator()
        imgui.Text("Instalados:")
        for _, name in ipairs(installedPending) do
            imgui.BulletText(name)
        end

        imgui.Separator()
        imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.0, 0.85, 0.45, 1.0))
        imgui.Text("Reiniciar ahora")
        if imgui.IsItemClicked(0) then
            for _, filename in ipairs(installedPending) do
                local path = getWorkingDirectory() .. "/" .. filename
                script.load(path)
            end
            installedPending = {}
            showRestartPrompt = false
        end
        imgui.PopStyleColor()
    end
end


local scriptStatusCache = {}

function checkScriptRemote(file, callback)
    lua_thread.create(function()
        local path = getWorkingDirectory() .. "/" .. file.name
        local f = io.open(path, "rb")
        if not f then
            callback("missing")
            return
        end
        local localContent = f:read("*a")
        f:close()

        -- parsear URL
        local host, pathUrl = file.url:match("https://([^/]+)(/.+)")
        local tcp = assert(socket.tcp())
        tcp:connect(host, 443)
        tcp = ssl.wrap(tcp, { mode = "client", protocol = "tlsv1_2", verify = "none" })
        tcp:dohandshake()

        -- pedir archivo
        tcp:send("GET " .. pathUrl .. " HTTP/1.1\r\nHost: " .. host .. "\r\nConnection: close\r\n\r\n")

        local data, headers_done, body = "", false, ""
        while true do
            local chunk, status, partial = tcp:receive(1024)
            local buff = chunk or partial
            if buff and #buff > 0 then
                data = data .. buff
                if not headers_done then
                    local header_end = data:find("\r\n\r\n", 1, true)
                    if header_end then
                        headers_done = true
                        body = data:sub(header_end+4)
                    end
                else
                    body = body .. buff
                end
            end
            if status == "closed" then break end
            wait(0) -- 🔑 deja respirar al juego
        end
        tcp:close()

        if body == "" then
            callback("unknown")
        elseif body == localContent then
            callback("same")
        else
            callback("different")
        end
    end)
end

-- cache
local scriptStatusCache = {}

function getScriptStatus(file)
    if not file then return "unknown" end
    if not scriptStatusCache[file.name] then
        scriptStatusCache[file.name] = "checking"
        checkScriptRemote(file, function(result)
            scriptStatusCache[file.name] = result
        end)
    end
    return scriptStatusCache[file.name]
end


-- 🔽 limpiar cache cuando refrescamos lista o instalamos algo
function clearStatusCache()
    scriptStatusCache = {}
end
function Spinner(label, radius, thickness, color)
    local draw_list = imgui.GetWindowDrawList()
    local center = imgui.GetCursorScreenPos()  -- ahora el cursor es el centro exacto
    local time = os.clock()

    local num_segments = 30
    local start = math.floor(num_segments * (time * 0.8 - math.floor(time * 0.8)))

    local a_min = math.pi * 2 * start / num_segments
    local a_max = math.pi * 2 * (start + num_segments / 3) / num_segments

    for i = 0, num_segments do
        local a = a_min + (i / num_segments) * (a_max - a_min)
        local x = center.x + math.cos(a) * radius
        local y = center.y + math.sin(a) * radius
        local col = imgui.GetColorU32Vec4(color)
        draw_list:AddCircleFilled(imgui.ImVec2(x, y), thickness, col)
    end

    -- reserva espacio visual correcto
    imgui.Dummy(imgui.ImVec2(radius * 2, radius * 2))
end


local infoFrame = imgui.OnFrame(
    function() return showInfoWindow[0] end,
    function(self)
        imgui.SetNextWindowSize(imgui.ImVec2(400, 260), imgui.Cond.FirstUseEver)
        imgui.Begin("Información del script", showInfoWindow,
            imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)

        local windowSize = imgui.GetWindowSize()

        -- Botón cerrar
        imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 46, 10))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
        addons.CloseButton("##closemenu", showInfoWindow, 36, 15)
        imgui.PopStyleColor()

        -- Contenedor principal con padding
        imgui.SetCursorPos(imgui.ImVec2(15, 15))
        imgui.BeginChild("##settings_inner", imgui.ImVec2(windowSize.x - 30, windowSize.y - 30), false)

        if selectedFile then
            local totalWidth   = imgui.GetContentRegionAvail().x
            local totalHeight  = imgui.GetContentRegionAvail().y

            local gapBetween   = 10   -- espacio central
            local paddingRight = 10   -- espacio borde derecho

            local leftWidth  = (totalWidth * 0.40) - (gapBetween / 2)
            local rightWidth = (totalWidth * 0.60) - paddingRight - (gapBetween / 2)
            local childHeight = totalHeight - 10

            -- Columna izquierda
            imgui.BeginChild("##leftpanel", imgui.ImVec2(leftWidth, childHeight), false,
                imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

                local displayName = selectedFile.name:gsub("%.lua$", "")
                local extra = scriptsInfo[selectedFile.name]

                local function s(v)
                    if v == nil or v == "" then return "N/A" end
                    return tostring(v)
                end

                -- Título
                imgui.PushFont(font1)
                imgui.Text(displayName)
                imgui.PopFont()
                
                -- 🔹 Contenedor horizontal (imagen + textos del autor)
                imgui.BeginChild("##row_author", imgui.ImVec2(0, 70), false)
                    local totalWidth = imgui.GetContentRegionAvail().x
                    local imgSize = 50
                    local gap = 10

                    -- Columna izquierda: imagen
                    imgui.BeginChild("##img_author", imgui.ImVec2(imgSize, imgSize), false)
                       
                    imgui.EndChild()

                    imgui.SameLine()

                    -- Columna derecha: textos
                    imgui.BeginChild("##txt_author", imgui.ImVec2(totalWidth - imgSize - gap, imgSize), false)
                        imgui.PushFont(font3)
                        if extra then
                            imgui.Text("By: " .. s(extra.author))
                            imgui.Text("Versión: " .. s(extra.version or "N/A"))
                        else
                            imgui.Text("By: N/A")
                            imgui.Text("Versión: N/A")
                        end
                        imgui.PopFont()
                    imgui.EndChild()
                imgui.EndChild()

                imgui.NewLine()
                imgui.PushFont(font2)

                -- 🔹 Info técnica
                imgui.BeginChild("##techinfo", imgui.ImVec2(0, 150), true,
                    imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

                    imgui.Text(fa.DOWNLOAD .. " Descargas: " .. s(extra and extra.downloads))
                    imgui.Spacing()
                    imgui.Text(fa.CALENDAR .. " Released: " .. s(extra and extra.released))
                    imgui.Spacing()
                    imgui.Text(fa.ROTATE .. " Updated: " .. s(extra and extra.updated))
                    imgui.Spacing()
                    imgui.Text(fa.CODE_BRANCH .. " Versión: " .. s(extra and extra.version))

                imgui.EndChild()

                imgui.Spacing()
                imgui.Spacing()
                imgui.Text("Etiquetas")
                imgui.Spacing()

                -- Tags
                imgui.BeginChild("##tagsinfo", imgui.ImVec2(0, 70), true,
                    imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

                if extra and extra.tags and type(extra.tags) == "table" and next(extra.tags) ~= nil then
                    local first = true
                    for _, tag in ipairs(extra.tags) do
                        local colores = coloresEtiquetas[string.lower(tag)]
                        if colores then
                            imgui.PushStyleColor(imgui.Col.Button, colores.off)
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, colores.off)
                            imgui.PushStyleColor(imgui.Col.ButtonActive, colores.off)
                            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.7, 0.7, 0.7, 1))
                        else
                            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.4, 0.4, 0.4, 0.3))
                            imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.4, 0.4, 0.4, 0.3))
                            imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.4, 0.4, 0.4, 0.3))
                            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.7, 0.7, 0.7, 1))
                        end

                        if not first then imgui.SameLine() end
                        first = false

                        local textSize = imgui.CalcTextSize(tag)
                        local paddingX, paddingY = 20, 8
                        local buttonWidth  = textSize.x + paddingX
                        local buttonHeight = textSize.y + paddingY

                        imgui.Button(tag, imgui.ImVec2(buttonWidth, buttonHeight))

                        imgui.PopStyleColor(4)
                    end
                else
                    imgui.Text("Sin etiquetas disponibles")
                end
                imgui.EndChild()

                imgui.Spacing()
                imgui.Text("Administrar")
                imgui.Spacing()

                -- Acciones
                imgui.BeginChild("##actions", imgui.ImVec2(0, 70), true,
                    imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
                    local status = getScriptStatus(selectedFile)
                    if status == "checking" then
                        Spinner("##checkspinner", 12, 2.5, imgui.ImVec4(1,1,1,1))
                    elseif status == "same" then
                        if imgui.Button(fa.TRASH .. " Desinstalar") then
                            lua_thread.create(function()
                                local filename = selectedFile.name
                                local path = getWorkingDirectory() .. "/" .. filename
                                local ok, err = os.remove(path)
                                if ok then
                                    clearStatusCache()
                                    for _, scr in ipairs(script.list()) do
                                        if scr.path:find(filename, 1, true) then
                                            script.unload(scr)
                                            break
                                        end
                                    end
                                end
                            end)
                            showInfoWindow[0] = false
                        end
                    elseif status == "different" then
                        if imgui.Button(fa.UPLOAD .. " Actualizar") then
                            lua_thread.create(function()
                                downloadFile(selectedFile.url, selectedFile.name)
                            end)
                            showInfoWindow[0] = false
                        end
                    else
                        if imgui.Button(fa.DOWNLOAD .. " Instalar") then
                            lua_thread.create(function()
                                downloadFile(selectedFile.url, selectedFile.name)
                            end)
                            showInfoWindow[0] = false
                        end
                    end
                imgui.EndChild()
            imgui.EndChild()
                    
            -- Espacio entre columnas
            imgui.SameLine()
            imgui.Dummy(imgui.ImVec2(gapBetween, 0))
            imgui.SameLine()

            -- Columna derecha
            imgui.BeginChild("##rightpanel", imgui.ImVec2(rightWidth, childHeight), false,
            imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

                if extra then
                    -- Botón "Descripción"
                    local label = fa.COMMENT_DOTS .. " Descripción"

                    local textSize = imgui.CalcTextSize(label)
                    local paddingX, paddingY = 20, 8
                    local buttonWidth  = textSize.x + paddingX
                    local buttonHeight = textSize.y + paddingY

                    imgui.Button(label, imgui.ImVec2(buttonWidth, buttonHeight))
                    imgui.Spacing()

                    -- Caja de descripción + créditos
                    imgui.BeginChild("##descriptionBox", imgui.ImVec2(0, 0), true,
                        imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)

                        imgui.TextWrapped(fa.FILE_LINES .. " " .. s(extra.description))
                        imgui.Spacing()
                        imgui.Text("Créditos:")
                        imgui.BulletText(s(extra.author))
                        if extra.credits and type(extra.credits) == "table" then
                            for _, c in ipairs(extra.credits) do
                                imgui.BulletText(s(c))
                            end
                        end

                    imgui.EndChild()
                else
                    imgui.TextWrapped("No hay información adicional")
                end

            imgui.EndChild()
            imgui.PopFont()
        end
        
        imgui.EndChild()
        imgui.End()
    end
)


local MainMenu = imgui.OnFrame(
    function() return windowState[0] end,

    function(self)
        imgui.SetNextWindowSize(imgui.ImVec2(622, 388), imgui.Cond.FirstUseEver)
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        imgui.Begin("##windowState", windowState, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
        local windowSize = imgui.GetWindowSize()

        imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 46, 10))
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
        addons.CloseButton("##closemenu", windowState, 36, 15)
        imgui.PopStyleColor()

        imgui.SetCursorPos(imgui.ImVec2(15, 15)) 
        imgui.BeginChild("##settings_inner", imgui.ImVec2(windowSize.x - 30, windowSize.y - 30), false)

        local bgColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
        imgui.PushStyleColor(imgui.Col.Text, bgColor)
        imgui.PushFont(font1)
        imgui.CenterText('GamePatch ')
        imgui.PopStyleColor()
        imgui.PopFont()
        imgui.PushFont(font2)
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
        imgui.PushFont(font1)
        imgui.CenterText('Buscar filtros')
        imgui.PopStyleColor()
        imgui.PopFont()
        imgui.PushFont(font2)
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

function onScriptTerminate(script, quitGame)
    if script == thisScript() then
        
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
    for name, info in pairs(scriptsInfo) do
    if info.iconFile and doesFileExist(info.iconFile) then
        info.img = imgui.CreateTextureFromFile(info.iconFile)
    end
end


    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesDefault()
    local fontPath = getWorkingDirectory()  .. "/resource/fonts/"

	font1 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "Verdana.ttf", 32, nil, glyph_ranges)
	loadFAFont("solid", 25, true)
    loadSCFont(25, true)
	font2 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "Verdana.ttf", 25, nil, glyph_ranges)
	loadFAFont("solid", 20, true)
    loadSCFont(25, true)
	font3 = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "Cinzel-Bold.ttf", 22, nil, glyph_ranges)
	loadFAFont("solid", 15, true)
    loadSCFont(20, true)
	logofont = imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath .. "font2.otf", 45, nil, glyph_ranges)
	loadFAFont("solid", 30, true)

    if doesFileExist(Image.file) then
        Image.img = imgui.CreateTextureFromFile(Image.file)
    end

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