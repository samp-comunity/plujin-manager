script_name("GamePatch")
script_author("vxnzz")
script_version("1.0")
--====================================

local imgui = require("mimgui")
local addons = require("ADDONS")
local sampEvents = require("samp.events")
local widgets = require("widgets")
local fa = require("fAwesome6")
local ffi = require("ffi")
local gta = ffi.load("GTASA")
local hook = require("monethook")
local SaMemory = require("SAMemory")
SaMemory.require("CCamera")
local Camera = SaMemory.camera

local https = require("ssl.https")
local ltn12 = require("ltn12")
local json = require("dkjson")
local socket = require("socket")
local ssl = require("ssl")
local webview = require("webviews")
local lfs = require("lfs")

local function loadLibrary(libName, optionalMessage)
	local success, lib = pcall(require, libName)
	if not success then
		print(string.format('No se encuentra la libreria: "%s"%s', libName, optionalMessage or ""))
	end
	return lib
end

local sc = loadLibrary("supericon")

local sw, sh = getScreenResolution()

local cfgFile = getWorkingDirectory() .. "/config/GamePatch.json"
function cfgLoad(defaults)
	local f = io.open(cfgFile, "r")
	if f then
		local content = f:read("*a")
		f:close()
		local data = json.decode(content)
		if data then
			return data
		end
	end
	return defaults
end

function cfgSave(cfg)
	local f = io.open(cfgFile, "w+")
	if f then
		f:write(json.encode(cfg, { indent = true }))
		f:close()
	end
end

local defaultCfg = { scripts = {} }
local cfgData = cfgLoad(defaultCfg)

local new = imgui.new
local windowState = new.bool(false)

---------------------- [FFI]----------------------
ffi.cdef([[
    void _Z12AND_OpenLinkPKc(const char* link);
]])

-- ruta absoluta
local basePath = getWorkingDirectory() .. "/resource/gamepatch"
lfs.mkdir(basePath)
lfs.mkdir(basePath .. "/icons")

---------------------- [Function main]----------------------
function main()
	local fileName = getWorkingDirectory() .. "/GamePatch.lua"

	if fileExists(fileName) then
		print("cargado correctamente")
	else
		print("No renombres el mod")
		thisScript():unload()
	end
	repeat
		wait(0)
	until isSampAvailable()

	while true do
		if isWidgetSwipedRight(WIDGET_RADAR) then
			windowState[0] = not windowState[0]
		end
		wait(0)
	end
end

local pendingTextures = {}

-- tabla que guarda los bool de imgui
local scriptEnabled = {}

local function ensureBool(key)
	if cfgData.scripts[key] == nil then
		cfgData.scripts[key] = true
		cfgSave(cfgData)
	end
	if scriptEnabled[key] == nil then
		scriptEnabled[key] = new.bool(cfgData.scripts[key])
	else
		scriptEnabled[key][0] = cfgData.scripts[key]
	end
end

-- inicializamos los bool según el JSON
for key, value in pairs(cfgData.scripts) do
	scriptEnabled[key] = new.bool(value)
end

local selectedFile = nil
local showInfoWindow = new.bool(false) -- usar ImGui bool
-- 🔹 Estados de paginación
local currentPage = 1
local itemsPerPage = 8 -- o 8 si prefieres

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
		colorOn = imgui.ImVec4(0.6, 0.6, 0.6, 0.9),
	},
}

-- 🎨 paleta de colores por etiqueta
local coloresEtiquetas = {
	legal = {
		off = imgui.ImVec4(0.2, 0.4, 0.8, 0.3), -- azul opaco
		on = imgui.ImVec4(0.2, 0.6, 1.0, 0.9), -- azul brillante
	},
	utilidad = {
		off = imgui.ImVec4(0.2, 0.6, 0.2, 0.3), -- verde opaco
		on = imgui.ImVec4(0.2, 0.9, 0.2, 0.9), -- verde brillante
	},
	visual = {
		off = imgui.ImVec4(0.5, 0.2, 0.7, 0.3), -- morado opaco
		on = imgui.ImVec4(0.8, 0.4, 1.0, 0.9), -- morado brillante
	},
	sonido = {
		off = imgui.ImVec4(0.6, 0.4, 0.2, 0.3), -- marrón opaco
		on = imgui.ImVec4(1.0, 0.6, 0.2, 0.9), -- marrón brillante
	},
}

function buildTags()
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
							colorOn = colores.on,
						}
					else
						-- fallback gris si no definiste color
						etiquetas[tag] = {
							activo = false,
							colorOff = imgui.ImVec4(0.4, 0.4, 0.4, 0.3),
							colorOn = imgui.ImVec4(0.7, 0.7, 0.7, 0.9),
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
			colorOn = imgui.ImVec4(0.6, 0.6, 0.6, 0.9),
		}
	end
end

function DrawTags()
	imgui.Text("Etiquetas")
	imgui.Spacing()

	local colorTextoOff = imgui.ImVec4(0.7, 0.7, 0.7, 1.0)
	local colorTextoOn = imgui.ImVec4(1, 1, 1, 1)

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
			lua_thread.create(function()
				refreshRepoFiles()
			end)
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

lua_thread.create(function()
	wait(2000)
	refreshRepoFiles()
end)

function clearStatusCache()
	scriptStatusCache = {}
end


local installedPending = {}

function downloadFile(url, filename, onFinish)
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

					-- 🔁 Manejar redirección (302/301)
					local location = headers:match("Location: ([^\r\n]+)")
					local status_code = headers:match("HTTP/%d+.%d+ (%d+)")
					if
						location
						and (
							status_code == "301"
							or status_code == "302"
							or status_code == "307"
							or status_code == "308"
						)
					then
						tcp:close()
						file:close()
						os.remove(savePath) -- limpiar archivo incompleto
						print("[Downloader] 🔁 Redirigiendo a " .. location)
						return downloadFile(location, filename, onFinish)
					end

					-- ✅ Procesar respuesta normal (200 OK)
					totalSize = tonumber(headers:match("Content%-Length: (%d+)")) or 0
					file:write(data:sub(header_end + 4))
					received = #data - (header_end + 4)
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
		if status == "closed" then
			break
		end
		wait(0)
	end

	file:close()
	tcp:close()

	isDownloading = false
	downloadProgress = 1.0

	clearStatusCache()

	if onFinish then
		onFinish(filename)
	end

	if filename:match("%.lua$") then
		table.insert(installedPending, filename)
		showRestartPrompt = true
	end

	print("[Downloader] ✅ Descarga terminada: " .. savePath)

	return true
end

function loadScriptsInfo()
	local url = "https://raw.githubusercontent.com/samp-comunity/plujin-manager/refs/heads/main/assets/scripts.json"
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

					if not doesFileExist(localIcon) then
						lua_thread.create(function()
							downloadFile(mod.icon, "resource/gamepatch/icons/" .. mod.name .. ".png", function()
								table.insert(pendingTextures, { name = mod.name, path = localIcon })
							end)
						end)
					else
						scriptsInfo[mod.name].iconFile = localIcon
						-- la textura se cargará después, en el render
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
	buildTags()

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
		if cfgData.scripts[key] ~= nil and not cfgData.scripts[key] then
			print("[GamePatch] 🔴 Desactivando " .. filename .. " (guardado en config)")
			script.unload(scr)
		end
	end
end)

-- renderDownloaderUI con cuadritos y botón "Descargar" en azul
function renderDownloaderUI()
	imgui.Separator()

	-- 🔹 Inicializar (arriba, donde cargas cfgData)
	viewMode = cfgData.viewMode or 1

	-- 🔹 Función helper para dibujar botones de vista
	local function DrawViewButton(id, icon, viewIndex)
		if viewMode == viewIndex then
			imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.0, 0.45, 0.85, 1.0)) -- Azul activo
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.0, 0.55, 1.0, 1.0))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.0, 0.35, 0.7, 1.0))
		end

		local clicked = imgui.Button(icon .. "##" .. id, imgui.ImVec2(40, 40))

		if viewMode == viewIndex then
			imgui.PopStyleColor(3)
		end

		if clicked then
			viewMode = viewIndex
			cfgData.viewMode = viewMode -- 🔹 Guardar en JSON
			cfgSave(cfgData)
		end
	end

	-- 🔹 Uso en tu ventana
	DrawViewButton("btnVistaPantalla", fa.MOBILE_SCREEN, 1)
	imgui.SameLine()
	DrawViewButton("btnVistaGrid", fa.TABLE_CELLS_LARGE, 2)
	imgui.SameLine()

	if imgui.Button(fa.FILTER) then
		imgui.OpenPopup("##popup_tags")
	end
	imgui.SameLine()
	if imgui.Button(" Actualizar lista") then
		refreshRepoFiles()
	end


	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(15, 15)) -- padding interno
	if imgui.BeginPopupModal("##popup_tags", nil,
	imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoTitleBar) then
		local windowSize = imgui.GetWindowSize()
		

		imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 0.843, 0.0, 1.0))
		imgui.SetCursorPosY(5)
		imgui.Text(" ") -- algo mínimo para ocupar línea
		imgui.SameLine()
		imgui.SetCursorPosX(imgui.GetWindowContentRegionMax().x - 40) -- margen derecho

		-- correcto: botón que al clickear cierra el popup
		if addons.CloseButton("##closemenu", showInfoWindow, 36, 15) then
			imgui.CloseCurrentPopup()
		end
		imgui.PopStyleColor()


		local bgColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
		imgui.PushStyleColor(imgui.Col.Text, bgColor)
		imgui.PushFont(font1)
		imgui.CenterText("Buscar filtros")
		imgui.PopStyleColor()
		imgui.PopFont()
		imgui.PushFont(font2)
		imgui.Spacing()

		DrawTags()

		
		imgui.Spacing()
		imgui.Separator()

		local buttonSize = imgui.ImVec2(100, 30) -- ancho 100, alto 30

		imgui.SetCursorPosX((windowSize.x - buttonSize.x) / 2)

		if imgui.Button("OK", buttonSize) then
			imgui.CloseCurrentPopup()
		end

		imgui.PopFont()

		imgui.EndPopup()
	end
	imgui.PopStyleVar()


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
		imgui.spinner("##refreshspinner", spinnerSize, spinnerThickness, imgui.ImVec4(1, 1, 1, 1))
	else
		local childW = imgui.GetContentRegionAvail().x
		local childH = 450
		imgui.BeginChild(
			"##view_container",
			imgui.ImVec2(childW, childH),
			false,
			imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoMove
		)

		-- proporciones
		local leftW = childW * 0.1
		local centerW = childW * 0.8
		local rightW = childW * 0.1

		-- 🔹 Columna izquierda
		imgui.BeginChild("##left_col", imgui.ImVec2(leftW, childH), false)

		local btnSize = 60
		-- centrar vertical
		local offsetY = (childH - btnSize) / 2
		-- centrar horizontal
		local offsetX = (leftW - btnSize) / 2

		imgui.SetCursorPos(imgui.ImVec2(offsetX, offsetY))

		local totalPages = 1
		if viewMode == 1 then
			local itemsPerPage = 6
			totalPages = math.max(1, math.ceil(#repoFiles / itemsPerPage))
		elseif viewMode == 2 then
			totalPages = math.max(1, math.ceil(#repoFiles / itemsPerPage))
		end

		if currentPage > 1 and (viewMode == 1 or viewMode == 2) then
			if imgui.arrowButton("##prev_page", btnSize, "left") then
				currentPage = currentPage - 1
			end
		end

		imgui.EndChild()

		imgui.SameLine()

		imgui.BeginChild(
			"##center_col",
			imgui.ImVec2(centerW, childH),
			false,
			imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoMove
		)
		TouchScroll()
		if viewMode == 1 then
			local itemsPerPage = 6
			local totalPages = math.max(1, math.ceil(#repoFiles / itemsPerPage))
			local startIndex = (currentPage - 1) * itemsPerPage + 1
			local endIndex = math.min(startIndex + itemsPerPage - 1, #repoFiles)

			for i = startIndex, endIndex do
				local f = repoFiles[i]
				local extra = scriptsInfo[f.name]
				local displayName = f.name:gsub("%.lua$", "")
				local savePath = getWorkingDirectory() .. "/" .. f.name
				local isInstalled = fileExists(savePath)

				-- 🔹 centramos BeginChild al 80% del ancho
				local avail = imgui.GetContentRegionAvail()
				local childWidth = avail.x
				local childHeight = 100

				imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.153, 0.153, 0.212, 1.0))
				imgui.BeginChild("##row_" .. f.name, imgui.ImVec2(childWidth, childHeight), false)

				local innerAvail = imgui.GetContentRegionAvail()
				local centerY = (childHeight - 50) / 2 -- centrar la imagen de 50px dentro del child

				-- 🔹 ICONO o spinner si no existe
				local imgSize = 50
				if extra and extra.iconFile and not extra.img and doesFileExist(extra.iconFile) then
					extra.img = imgui.CreateTextureFromFile(extra.iconFile)
				end

				local avail = imgui.GetContentRegionAvail()
				local offsetX = 15 -- padding inicial
				imgui.SetCursorPosY(centerY)

				if extra and extra.img then
					imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
					imgui.Image(extra.img, imgui.ImVec2(imgSize, imgSize))
					imgui.SameLine()
					imgui.SetCursorPosX(imgui.GetCursorPosX() + 12) -- espacio extra entre icono y texto
				else
					-- spinner centrado
					imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
					imgui.BeginChild("##icon_empty_" .. f.name, imgui.ImVec2(imgSize, imgSize), false)

					local spinnerSize, spinnerThickness = 12, 2.5

					-- truco: centrar el cursor en el child restando la mitad del dummy
					local childSize = imgui.GetWindowSize()
					local posX = (childSize.x - spinnerSize * 2) / 2
					local posY = (childSize.y - spinnerSize * 2) / 2
					imgui.SetCursorPos(imgui.ImVec2(posX, posY))

					-- dibujar spinner (ya se auto-centra dentro del dummy)
					imgui.spinner("##checkspinner_" .. f.name, spinnerSize, spinnerThickness, imgui.ImVec4(1, 1, 1, 1))

					imgui.EndChild()
					imgui.SameLine()
					imgui.SetCursorPosX(imgui.GetCursorPosX() + 12) -- mismo espacio que cuando hay imagen
				end

				-- 🔹 Centro para texto (nombre + autor)
				imgui.SetCursorPosY(centerY)
				imgui.BeginGroup()
				imgui.PushFont(boldFont or imgui.GetFont())
				imgui.Text(displayName .. " v" .. (extra and extra.version or "1.0.0"))
				imgui.PopFont()
				local autor = (extra and extra.author or ""):gsub("^%s*$", "Desconocido")
				imgui.TextColored(imgui.ImVec4(1, 0.8, 0.2, 1), autor)

				imgui.EndGroup()

				-- 🔹 Botones a la derecha (misma posición que antes GET)
				local key = displayName
				local loaded = false
				for _, scr in ipairs(script.list()) do
					local scrName = scr.path:match("([^/\\]+)$")
					if scrName == f.name then
						loaded = true
						break
					end
				end

				-- calcular ancho del botón según texto
				local btnText
				if isInstalled then
					btnText = "Ver info"
				else
					btnText = "Descargar"
				end
				local btnWidth = imgui.CalcTextSize(btnText).x + 20 -- padding 20px
				local btnHeight = 30

				-- calcular ancho del checkbox si aplica
				local checkWidth = 0
				local spacing = 0
				if isInstalled and f.name ~= "GamePatch.lua" then
					checkWidth = imgui.GetFrameHeight() -- checkbox cuadrado
					spacing = 6 -- espacio entre checkbox y botón
				end

				local totalWidth = btnWidth + checkWidth + spacing
				local padding = 10

				-- mover todo a la derecha según ancho total
				imgui.SetCursorPosY(centerY + 10)
				imgui.SetCursorPosX(innerAvail.x - totalWidth - padding)

				imgui.BeginGroup()

				if not isInstalled then
					local key = f.name:gsub("%.lua$", "")
					if cfgData.scripts[key] ~= nil then
						cfgData.scripts[key] = nil
						cfgSave(cfgData)
						scriptEnabled[key] = nil
						print("[GamePatch] 🧹 Eliminada variable huérfana del JSON: " .. key)
					end
				end

				if isInstalled then
					if f.name ~= "GamePatch.lua" then
						ensureBool(key)

						if imgui.Checkbox("##" .. key, scriptEnabled[key]) then
							cfgData.scripts[key] = scriptEnabled[key][0]
							cfgSave(cfgData)
							local path = getWorkingDirectory() .. "/" .. f.name
							if scriptEnabled[key][0] then
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
					end

					-- Botón Ver info
					if imgui.Button(btnText .. "##" .. f.name, imgui.ImVec2(btnWidth, btnHeight)) then
						selectedFile = f
						showInfoWindow[0] = true
					end

				-- Si no está instalado → Descargar
				else
					if imgui.Button(btnText .. "##" .. f.name, imgui.ImVec2(btnWidth, btnHeight)) then
						selectedFile = f
						showInfoWindow[0] = true
					end
				end
				imgui.EndGroup()

				imgui.EndChild()
				imgui.PopStyleColor()

				-- 🔹 espacio entre rows
				imgui.Dummy(imgui.ImVec2(0, 8))
			end

		-- ==============================
		-- 🔹 Vista 2 (grid original intacto)
		-- ==============================
		elseif viewMode == 2 then
			-- Medidas de cada item
			local itemWidth = 255
			local itemHeight = 280

			-- Tamaño del área disponible (usa el padre directo)
			local parentWidth = imgui.GetContentRegionAvail().x

			-- Calcular cuántas columnas caben (máx 4)
			local maxCols = math.max(1, math.min(4, math.floor(parentWidth / (itemWidth + 10))))

			-- Calcular spacing dinámico
			local spacing = 10
			if maxCols > 1 then
				local totalItemsWidth = maxCols * itemWidth
				local availableSpacing = (parentWidth - totalItemsWidth) / (maxCols - 1)
				spacing = math.max(10, availableSpacing)
			end

			-- Paginación
			local itemsPerPage = maxCols * 2 -- mínimo 2 filas por página
			local totalPages = math.max(1, math.ceil(#repoFiles / itemsPerPage))
			local startIndex = (currentPage - 1) * itemsPerPage + 1
			local endIndex = math.min(startIndex + itemsPerPage - 1, #repoFiles)

			local col = 0
			for i = startIndex, endIndex do
				local f = repoFiles[i]

				imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.153, 0.153, 0.212, 1.0))
				imgui.BeginChild("##mod_" .. f.name, imgui.ImVec2(itemWidth, itemHeight), false)

				-- 🔹 ICONO
				imgui.NewLine()
				local imgSize = 90
				local extra = scriptsInfo[f.name]

				if extra and extra.iconFile and not extra.img and doesFileExist(extra.iconFile) then
					extra.img = imgui.CreateTextureFromFile(extra.iconFile)
				end

				if extra and extra.img then
					local avail = imgui.GetContentRegionAvail()
					local offsetX = (avail.x - imgSize) / 2
					if offsetX > 0 then
						imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
					end
					imgui.BeginChild("##icon_" .. f.name, imgui.ImVec2(imgSize, imgSize), false)
					imgui.Image(extra.img, imgui.ImVec2(imgSize, imgSize))
					imgui.EndChild()
				else
					local avail = imgui.GetContentRegionAvail()
					local offsetX = (avail.x - imgSize) / 2
					if offsetX > 0 then
						imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
					end

					imgui.BeginChild("##icon_empty_" .. f.name, imgui.ImVec2(imgSize, imgSize), false)

					local spinnerSize, spinnerThickness = 20, 2.5
					local childSize = imgui.GetWindowSize()

					-- centrar el dummy del spinner en el medio exacto del child
					local posX = (childSize.x - spinnerSize * 2) / 2
					local posY = (childSize.y - spinnerSize * 2) / 2
					imgui.SetCursorPos(imgui.ImVec2(posX, posY))

					-- dibujar spinner
					imgui.spinner("##checkspinner_" .. f.name, spinnerSize, spinnerThickness, imgui.ImVec4(1, 1, 1, 1))

					imgui.EndChild()
				end

				imgui.Spacing()
				local displayName = f.name:gsub("%.lua$", "")
				imgui.CenterText(displayName)
				imgui.Spacing()

				-- Autor centrado debajo
				local author = (extra and extra.author or ""):gsub("^%s*$", "Desconocido")

				local avail = imgui.GetContentRegionAvail()
				local authorWidth = imgui.CalcTextSize(author).x
				imgui.SetCursorPosX(imgui.GetCursorPosX() + (avail.x - authorWidth) / 2)
				imgui.TextColored(imgui.ImVec4(1, 0.8, 0.2, 1), author)
				imgui.Spacing()

				-- 🔹 BOTONES
				local savePath = getWorkingDirectory() .. "/" .. f.name
				local isInstalled = fileExists(savePath)
				if not isInstalled then
					local key = f.name:gsub("%.lua$", "")
					if cfgData.scripts[key] ~= nil then
						cfgData.scripts[key] = nil
						cfgSave(cfgData)
						scriptEnabled[key] = nil
						print("[GamePatch] 🧹 Eliminada variable huérfana del JSON: " .. key)
					end
				end

				local loaded = false
				for _, scr in ipairs(script.list()) do
					local scrName = scr.path:match("([^/\\]+)$")
					if scrName == f.name then
						loaded = true
						break
					end
				end

				if (not isInstalled) or (isInstalled and not loaded) then
					local btnWidth = imgui.CalcTextSize("Descargar").x + 20
					local avail = imgui.GetContentRegionAvail()
					local offsetX = (avail.x - btnWidth) / 2
					if offsetX > 0 then
						imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
					end

					imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.0, 0.45, 0.85, 1.0))
					imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.0, 0.55, 1.0, 1.0))
					imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.0, 0.35, 0.7, 1.0))

					if imgui.Button("Descargar##" .. f.name, imgui.ImVec2(btnWidth, 30)) then
						selectedFile = f
						showInfoWindow[0] = true
					end

					imgui.PopStyleColor(3)
				elseif isInstalled and loaded then
					local key = f.name:gsub("%.lua$", "")
					ensureBool(key)

					local checkSize = imgui.GetFrameHeight()
					local btnWidth = imgui.CalcTextSize("Ver info").x + 20
					local totalWidth

					-- 🔹 Si NO es GamePatch.lua → espacio para checkbox + botón
					if f.name ~= "GamePatch.lua" then
						totalWidth = checkSize + 6 + btnWidth
					else
						totalWidth = btnWidth
					end

					local avail = imgui.GetContentRegionAvail()
					local offsetX = (avail.x - totalWidth) / 2
					if offsetX > 0 then
						imgui.SetCursorPosX(imgui.GetCursorPosX() + offsetX)
					end

					imgui.BeginGroup()
					-- 🔹 Dibujar checkbox SOLO si no es GamePatch.lua
					if f.name ~= "GamePatch.lua" then
						if imgui.Checkbox("##" .. key, scriptEnabled[key]) then
							cfgData.scripts[key] = scriptEnabled[key][0]
							cfgSave(cfgData)
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
					end

					-- 🔹 Botón Ver info (siempre visible)
					if imgui.Button("Ver info##" .. f.name, imgui.ImVec2(btnWidth, 30)) then
						selectedFile = f
						showInfoWindow[0] = true
					end
					imgui.EndGroup()
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
		end
		imgui.EndChild()

		imgui.SameLine()
		imgui.BeginChild("##right_col", imgui.ImVec2(rightW, childH), false)

		local btnSize = 60
		local offsetY = (childH - btnSize) / 2 -- centrar vertical
		local offsetX = (rightW - btnSize) / 2 -- centrar horizontal

		imgui.SetCursorPos(imgui.ImVec2(offsetX, offsetY))

		local totalPages = 1
		if viewMode == 1 then
			local itemsPerPage = 6
			totalPages = math.max(1, math.ceil(#repoFiles / itemsPerPage))
		elseif viewMode == 2 then
			totalPages = math.max(1, math.ceil(#repoFiles / itemsPerPage))
		end

		if currentPage < totalPages and (viewMode == 1 or viewMode == 2) then
			if imgui.arrowButton("##next_page", btnSize, "right") then
				currentPage = currentPage + 1
			end
		end

		imgui.EndChild()
		imgui.EndChild()
		imgui.BeginChild("##right_col", imgui.ImVec2(0, 100), true)
		if isDownloading then
			imgui.Separator()
			imgui.Text("Descargando: " .. currentDownload)

			-- ===== Config =====
			local barSize = imgui.ImVec2(360, 22) -- barra más ancha
			local spinnerRadius = 12 -- spinner más grande
			local spinnerThickness = 3
			local gap = 16 -- espacio entre spinner y barra
			local gapText = 12 -- espacio entre barra y porcentaje
			local leftPad = 6 -- margen izquierdo

			-- Alturas para centrar verticalmente spinner vs barra vs texto
			local barH = barSize.y
			local spinnerH = spinnerRadius * 2
			local alignOffset = (barH - spinnerH) * 0.5

			-- Porcentaje redondeado (0–100%)
			local percentStr = tostring(math.floor(downloadProgress * 100 + 0.5)) .. "%"

			-- Calcular ancho total del grupo
			local textWidth = imgui.CalcTextSize(percentStr).x
			local groupWidth = leftPad + spinnerH + gap + barSize.x + gapText + textWidth
			local winWidth = imgui.GetWindowSize().x

			-- Centrar grupo en ventana
			local startX = (winWidth - groupWidth) * 0.5
			local baseY = imgui.GetCursorPosY()

			imgui.BeginGroup()
			-- imgui.spinner
			imgui.SetCursorPos(imgui.ImVec2(startX + leftPad, baseY + alignOffset))
			imgui.spinner("##downloadspinner", spinnerRadius, spinnerThickness, imgui.ImVec4(0.0, 0.85, 0.45, 1.0))

			-- Barra
			imgui.SetCursorPos(imgui.ImVec2(startX + leftPad + spinnerH + gap, baseY))
			imgui.ProgressBar(downloadProgress, barSize, "")

			-- Texto porcentaje (ej: "42%")
			local textHeight = imgui.CalcTextSize(percentStr).y
			imgui.SetCursorPos(
				imgui.ImVec2(startX + leftPad + spinnerH + gap + barSize.x + gapText, baseY + (barH - textHeight) * 0.5)
			)
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

			lua_thread.create(function()
				-- Recargar los scripts
				for _, filename in ipairs(installedPending) do
					local path = getWorkingDirectory() .. "/" .. filename
					script.load(path)
				end

				wait(5000)

				installedPending = {}
				showRestartPrompt = false
			end)
		end

		imgui.EndChild()
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

		if not file.url or file.url == "" then
			callback("installed")
			return
		end

		local function fetchBody(url)
			local host, pathUrl = url:match("https://([^/]+)(/.+)")
			local tcp = assert(socket.tcp())
			tcp:connect(host, 443)
			tcp = ssl.wrap(tcp, { mode = "client", protocol = "tlsv1_2", verify = "none" })
			tcp:dohandshake()

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
							local headers = data:sub(1, header_end)
							body = data:sub(header_end + 4)

							-- 🔁 Manejo de redirección (302/301/307/308)
							local location = headers:match("Location: ([^\r\n]+)")
							local status_code = headers:match("HTTP/%d+.%d+ (%d+)")
							if
								location
								and (
									status_code == "301"
									or status_code == "302"
									or status_code == "307"
									or status_code == "308"
								)
							then
								tcp:close()
								return fetchBody(location)
							end
						end
					else
						body = body .. buff
					end
				end
				if status == "closed" then
					break
				end
				wait(0)
			end
			tcp:close()
			return body
		end

		local body = fetchBody(file.url)

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
	if not file then
		return "unknown"
	end
	if not scriptStatusCache[file.name] then
		scriptStatusCache[file.name] = "checking"
		checkScriptRemote(file, function(result)
			scriptStatusCache[file.name] = result
		end)
	end
	return scriptStatusCache[file.name]
end

function imgui.spinner(label, radius, thickness, color)
	local draw_list = imgui.GetWindowDrawList()
	local pos = imgui.GetCursorScreenPos()
	local time = os.clock()

	-- El centro real debe estar en el medio del dummy
	local center = imgui.ImVec2(pos.x + radius, pos.y + radius)

	local num_segments = 60
	local coverage = 0.7
	local arc_steps = math.max(1, math.floor(num_segments * coverage))
	local speed = 0.9

	local phase = (time * speed - math.floor(time * speed)) * num_segments
	local start = math.floor(phase)
	local a_min = 2 * math.pi * start / num_segments
	local a_max = a_min + 2 * math.pi * coverage

	for i = 0, arc_steps do
		local tt = i / arc_steps
		local a = a_min + tt * (a_max - a_min)
		local x = center.x + math.cos(a) * radius
		local y = center.y + math.sin(a) * radius
		local alpha = 0.3 + 0.7 * tt
		local brightness = 0.6 + 0.4 * tt

		local col = imgui.GetColorU32(brightness, brightness, brightness, alpha)
		draw_list:AddCircleFilled(imgui.ImVec2(x, y), thickness, col)
	end

	-- ahora sí ocupa bien su espacio
	imgui.Dummy(imgui.ImVec2(radius * 2, radius * 2))
end

function imgui.arrowButton(id, size, direction, fillColor, borderColor)
	local draw_list = imgui.GetWindowDrawList()
	local p = imgui.GetCursorScreenPos()

	-- Botón invisible con hitbox
	local pressed = imgui.InvisibleButton(id, imgui.ImVec2(size, size))

	-- Centro del botón
	local cx = p.x + size / 2
	local cy = p.y + size / 2
	local half = size / 3

	-- Colores
	local colFill = fillColor or imgui.GetColorU32(0, 1, 1, 1) -- Cyan por defecto
	local colBorder = borderColor or imgui.GetColorU32(0, 0, 0, 1) -- Negro por defecto

	-- Calcular puntos del triángulo
	local p1, p2, p3
	if direction == "right" then
		p1 = imgui.ImVec2(cx - half, cy - half)
		p2 = imgui.ImVec2(cx - half, cy + half)
		p3 = imgui.ImVec2(cx + half, cy)
	elseif direction == "left" then
		p1 = imgui.ImVec2(cx + half, cy - half)
		p2 = imgui.ImVec2(cx + half, cy + half)
		p3 = imgui.ImVec2(cx - half, cy)
	elseif direction == "up" then
		p1 = imgui.ImVec2(cx - half, cy + half)
		p2 = imgui.ImVec2(cx + half, cy + half)
		p3 = imgui.ImVec2(cx, cy - half)
	else -- down
		p1 = imgui.ImVec2(cx - half, cy - half)
		p2 = imgui.ImVec2(cx + half, cy - half)
		p3 = imgui.ImVec2(cx, cy + half)
	end

	-- Dibujar borde (un poquito más grande)
	local expand = 2
	local function expandPoint(pt, factor)
		return imgui.ImVec2(pt.x + (pt.x - cx) / half * factor, pt.y + (pt.y - cy) / half * factor)
	end

	draw_list:AddTriangleFilled(expandPoint(p1, expand), expandPoint(p2, expand), expandPoint(p3, expand), colBorder)

	-- Dibujar relleno encima
	draw_list:AddTriangleFilled(p1, p2, p3, colFill)

	return pressed
end

-- Estado global de la función de scroll
local scrollState = {
	lastTouchY = 0,
	isDragging = false,
}

function TouchScroll()
	-- 🔹 Aceptar hover aunque haya hijos activos
	if imgui.IsWindowHovered(imgui.HoveredFlags.ChildWindows + imgui.HoveredFlags.AllowWhenBlockedByActiveItem) then
		if imgui.IsMouseClicked(0) then
			scrollState.lastTouchY = imgui.GetMousePos().y
			scrollState.isDragging = true
		elseif imgui.IsMouseReleased(0) then
			scrollState.isDragging = false
		end

		if scrollState.isDragging then
			local currentY = imgui.GetMousePos().y
			local delta = scrollState.lastTouchY - currentY
			scrollState.lastTouchY = currentY

			local currentScroll = imgui.GetScrollY()
			imgui.SetScrollY(currentScroll + delta)
		end
	end
end

local infoFrame = imgui.OnFrame(function()
	return showInfoWindow[0]
end, function(self)
	imgui.SetNextWindowSize(imgui.ImVec2(400, 260), imgui.Cond.FirstUseEver)
	imgui.Begin(
		"Información del script",
		showInfoWindow,
		imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar
	)

	local windowSize = imgui.GetWindowSize()

	-- Botón cerrar
	imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 46, 5))
	imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 0.843, 0.0, 1.0))
	addons.CloseButton("##closemenu", showInfoWindow, 36, 15)
	imgui.PopStyleColor()

	-- Contenedor principal con padding
	imgui.SetCursorPos(imgui.ImVec2(30, 35))
	imgui.BeginChild(
		"##settings_inner",
		imgui.ImVec2(windowSize.x - 40, windowSize.y - 30),
		false,
		imgui.WindowFlags.NoScrollbar
	)

	if selectedFile then
		local totalWidth = imgui.GetContentRegionAvail().x
		local totalHeight = imgui.GetContentRegionAvail().y

		local gapBetween = 10 -- espacio central
		local paddingRight = 10 -- espacio borde derecho

		local leftWidth = (totalWidth * 0.40) - (gapBetween / 2)
		local rightWidth = (totalWidth * 0.60) - paddingRight - (gapBetween / 2)
		local childHeight = totalHeight - 10
		local status = getScriptStatus(selectedFile)

		-- Columna izquierda
		imgui.BeginChild("##leftpanel", imgui.ImVec2(leftWidth, childHeight), false, imgui.WindowFlags.NoScrollbar)

		local displayName = selectedFile.name:gsub("%.lua$", "")
		local extra = scriptsInfo[selectedFile.name]

		local function s(v)
			if v == nil or v == "" then
				return "N/A"
			end
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
		local gap = 15

		-- Columna izquierda: imagen
		imgui.BeginChild("##img_author", imgui.ImVec2(imgSize, imgSize), false)
		if extra and extra.iconFile and doesFileExist(extra.iconFile) then
			if not extra.img then
				extra.img = imgui.CreateTextureFromFile(extra.iconFile)
			end
			if extra.img then
				imgui.Image(extra.img, imgui.ImVec2(imgSize, imgSize))
			else
				local childSize = imgui.GetWindowSize()
				local spinnerSize, spinnerThickness = 14, 2.5
				local posX = (childSize.x - spinnerSize * 2) / 2
				local posY = (childSize.y - spinnerSize * 2) / 2
				imgui.SetCursorPos(imgui.ImVec2(posX, posY))
				imgui.spinner(
					"##spinner_author_" .. selectedFile.name,
					spinnerSize,
					spinnerThickness,
					imgui.ImVec4(1, 1, 1, 1)
				)
			end
		else
			local childSize = imgui.GetWindowSize()
			local spinnerSize, spinnerThickness = 14, 2.5
			local posX = (childSize.x - spinnerSize * 2) / 2
			local posY = (childSize.y - spinnerSize * 2) / 2
			imgui.SetCursorPos(imgui.ImVec2(posX, posY))
			imgui.spinner(
				"##spinner_author_" .. (selectedFile and selectedFile.name or "unknown"),
				spinnerSize,
				spinnerThickness,
				imgui.ImVec4(1, 1, 1, 1)
			)
		end
		imgui.EndChild()

		imgui.SameLine(0, gap)

		-- Columna derecha: textos
		imgui.BeginChild("##txt_author", imgui.ImVec2(totalWidth - imgSize - gap, imgSize), false)
		imgui.PushFont(font3)
		if extra then
			imgui.Text("By: " .. s(extra.author))
			imgui.Text("Versión: " .. s(extra.version))
		end
		imgui.PopFont()
		imgui.EndChild()
		imgui.EndChild()

		imgui.NewLine()
		imgui.PushFont(font2)

		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.109, 0.106, 0.149, 1.0))
		imgui.BeginChild("##techinfo", imgui.ImVec2(0, 180), false, imgui.WindowFlags.NoScrollbar)

		imgui.Text(fa.DOWNLOAD .. " Descargas: " .. s(extra and extra.total_downloads))
		imgui.Spacing()
		imgui.Text(fa.CALENDAR .. " Publicado: " .. s(extra and extra.created))
		imgui.Spacing()
		imgui.Text(fa.ROTATE .. " Actualizado: " .. s(extra and extra.last_update))
		imgui.Spacing()
		imgui.Text(fa.CODE_BRANCH .. " Versión: " .. s(extra and extra.latest_version))
		imgui.Spacing()
		if status == "checking" then
			local avail = imgui.GetContentRegionAvail()
			local childWidth = avail.x -- ocupar todo el ancho
			local childHeight = 30

			imgui.BeginChild("##checking_spinner", imgui.ImVec2(childWidth, childHeight), false)

			local spinnerRadius, spinnerThickness = 9, 2.5
			local spinnerSize = spinnerRadius * 2
			local text = "Buscando actualizaciones"
			local textHeight = imgui.GetTextLineHeight()

			-- centrar verticalmente el bloque (spinner + texto)
			local blockHeight = math.max(spinnerSize, textHeight)
			local centerY = (childHeight - blockHeight) / 2

			-- spinner alineado a la izquierda con padding
			local paddingX = 5
			imgui.SetCursorPos(imgui.ImVec2(paddingX, centerY + (blockHeight - spinnerSize) / 2))
			imgui.spinner("##checkspinner", spinnerRadius, spinnerThickness, imgui.ImVec4(1, 1, 1, 1))

			imgui.SameLine(nil, 10) -- 👈 10 píxeles de espacio extra
			imgui.SetCursorPosY(centerY + (blockHeight - textHeight) / 2)
			imgui.Text(text)

			imgui.EndChild()
		elseif status == "same" then
			imgui.TextColored(imgui.ImVec4(0.2, 0.8, 0.2, 1.0), fa.CHECK .. " Actualizado!")
		elseif status == "different" then
			imgui.TextColored(imgui.ImVec4(0.3, 0.6, 1.0, 1.0), fa.ARROW_UP .. " Actualización encontrada")
		else
			imgui.TextColored(imgui.ImVec4(0.6, 0.6, 0.6, 1.0), fa.BAN .. " No Instalado")
		end

		imgui.EndChild()

		imgui.Spacing()
		imgui.Spacing()
		imgui.Text("Etiquetas")
		imgui.Spacing()

		-- Tags
		imgui.BeginChild(
			"##tagsinfo",
			imgui.ImVec2(0, 70),
			false,
			imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
		)

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

				if not first then
					imgui.SameLine()
				end
				first = false

				local textSize = imgui.CalcTextSize(tag)
				local paddingX, paddingY = 20, 8
				local buttonWidth = textSize.x + paddingX
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
		imgui.BeginChild(
			"##actions",
			imgui.ImVec2(0, 70),
			false,
			imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
		)

		-- ===== CÁLCULO DE CENTRADO PRECISO =====
		local style = imgui.GetStyle()
		local crmin = imgui.GetWindowContentRegionMin()
		local crmax = imgui.GetWindowContentRegionMax()
		local contentW = crmax.x - crmin.x
		local contentH = crmax.y - crmin.y

		local spacing = 10

		-- Ancho auto de botones de texto
		local function BtnWidth(text)
			local sz = imgui.CalcTextSize(text)
			return sz.x + style.FramePadding.x * 2
		end

		-- Altura exacta de botón según el estilo (lo que usa ImGui)
		local btnH = imgui.GetTextLineHeight() + style.FramePadding.y * 2

		-- Anchos
		local wUpdate = BtnWidth(fa.UPLOAD .. " Actualizar")
		local wInstall = BtnWidth(fa.DOWNLOAD .. " Instalar")
		local wUninstall = BtnWidth(fa.TRASH .. " Desinstalar")
		local wX, wTrash = 50, 60

		-- Ancho total del grupo según status
		local totalW
		if status == "different" then
			totalW = wUpdate + spacing + wX + spacing + wTrash
		elseif status == "checking" or status == "same" then
			totalW = wUninstall
		else
			totalW = wInstall
		end

		-- Centro exacto dentro del child (usa min/max de la región de contenido)
		local posX = crmin.x + (contentW - totalW) * 0.5
		local posY = crmin.y + (contentH - btnH) * 0.5
		-- Redondeo para evitar medio píxel
		posX = math.floor(posX + 0.5)
		posY = math.floor(posY + 0.5)
		imgui.SetCursorPos(imgui.ImVec2(posX, posY))

		if status == "checking" or status == "same" then
			local key = selectedFile.name:gsub("%.lua$", "")

			-- ⚠️ Caso especial: GamePatch.lua → solo mostrar Desinstalar
			if selectedFile.name == "GamePatch.lua" then
				local wUninstall = BtnWidth(fa.TRASH .. " Desinstalar")
				local totalW = wUninstall
				local totalH = btnH

				local posX = crmin.x + (contentW - totalW) * 0.5
				local posY = crmin.y + (contentH - totalH) * 0.5
				imgui.SetCursorPos(imgui.ImVec2(posX, posY))

				if imgui.Button(fa.TRASH .. " Desinstalar", imgui.ImVec2(0, btnH)) then
					lua_thread.create(function()
						local filename = selectedFile.name
						local path = getWorkingDirectory() .. "/" .. filename
						local ok = os.remove(path)
						if ok then
							clearStatusCache()
							for _, scr in ipairs(script.list()) do
								if scr.path:find(filename, 1, true) then
									script.unload(scr)
									break
								end
							end
							-- eliminar de config
							cfgData.scripts[key] = nil
							cfgSave(cfgData)
							scriptEnabled[key] = nil

							refreshRepoFiles()
						end
					end)
					showInfoWindow[0] = false
				end
			else
				-- === Resto de scripts → Activar/Desactivar + Desinstalar ===
				local isEnabled = cfgData.scripts[key]
				if isEnabled == nil then
					isEnabled = true
					cfgData.scripts[key] = true
				end

				local toggleLabel, toggleColor
				if isEnabled then
					toggleLabel = fa.XMARK .. " Desactivar"
					toggleColor = imgui.ImVec4(0.85, 0.00, 0.00, 1.00)
				else
					toggleLabel = fa.CHECK .. " Activar"
					toggleColor = imgui.ImVec4(0.00, 0.70, 0.00, 1.00)
				end

				local wToggle = BtnWidth(toggleLabel)
				local wUninstall = BtnWidth(fa.TRASH .. " Desinstalar")
				local totalW = wToggle + spacing + wUninstall
				local totalH = btnH

				local posX = crmin.x + (contentW - totalW) * 0.5
				local posY = crmin.y + (contentH - totalH) * 0.5
				imgui.SetCursorPos(imgui.ImVec2(posX, posY))

				-- Botón Activar/Desactivar
				imgui.PushStyleColor(imgui.Col.Button, toggleColor)
				imgui.PushStyleColor(
					imgui.Col.ButtonHovered,
					imgui.ImVec4(
						math.min(toggleColor.x + 0.1, 1.0),
						math.min(toggleColor.y + 0.1, 1.0),
						math.min(toggleColor.z + 0.1, 1.0),
						1.0
					)
				)
				imgui.PushStyleColor(imgui.Col.ButtonActive, toggleColor)
				if imgui.Button(toggleLabel, imgui.ImVec2(0, btnH)) then
					if isEnabled then
						for _, scr in ipairs(script.list()) do
							if scr.path:find(selectedFile.name, 1, true) then
								script.unload(scr)
								break
							end
						end
						cfgData.scripts[key] = false
					else
						script.load(getWorkingDirectory() .. "/" .. selectedFile.name)
						cfgData.scripts[key] = true
					end
					cfgSave(cfgData)
				end
				imgui.PopStyleColor(3)

				imgui.SameLine(nil, spacing)

				-- Botón Desinstalar
				if imgui.Button(fa.TRASH .. " Desinstalar", imgui.ImVec2(0, btnH)) then
					lua_thread.create(function()
						local filename = selectedFile.name
						local path = getWorkingDirectory() .. "/" .. filename
						local ok = os.remove(path)
						if ok then
							clearStatusCache()
							for _, scr in ipairs(script.list()) do
								if scr.path:find(filename, 1, true) then
									script.unload(scr)
									break
								end
							end
							cfgData.scripts[key] = nil
							cfgSave(cfgData)
						end
					end)
					showInfoWindow[0] = false
				end
			end
		elseif status == "different" then
			local key = selectedFile.name:gsub("%.lua$", "")

			-- ==== BOTÓN ACTUALIZAR ====
			local wUpdate = imgui.CalcTextSize(fa.UPLOAD .. " Actualizar").x + 20
			local totalW = wUpdate
			local hasToggle = (selectedFile.name ~= "GamePatch.lua")

			if hasToggle then
				totalW = totalW + spacing + wX -- espacio para activar/desactivar
			end

			totalW = totalW + spacing + wTrash -- espacio trash

			-- Calcular posición centrada
			local crmin = imgui.GetWindowContentRegionMin()
			local crmax = imgui.GetWindowContentRegionMax()
			local contentW = crmax.x - crmin.x
			local posX = crmin.x + (contentW - totalW) * 0.5
			local posY = imgui.GetCursorPosY()
			imgui.SetCursorPos(imgui.ImVec2(posX, posY))

			-- Botón Actualizar (azul)
			imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.00, 0.45, 0.85, 1.00))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.10, 0.55, 0.95, 1.00))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.35, 0.75, 1.00))
			if imgui.Button(fa.UPLOAD .. " Actualizar", imgui.ImVec2(0, btnH)) then
				lua_thread.create(function()
					downloadFile(selectedFile.url, selectedFile.name)
				end)
				showInfoWindow[0] = false
			end
			imgui.PopStyleColor(3)

			-- 🔹 Si NO es GamePatch.lua → mostrar toggle
			if hasToggle then
				imgui.SameLine(nil, spacing)

				local isEnabled = cfgData.scripts[key]
				if isEnabled == nil then
					isEnabled = true
					cfgData.scripts[key] = true
				end

				local toggleIcon, toggleColor
				if isEnabled then
					toggleIcon = fa.XMARK -- rojo → desactivar
					toggleColor = imgui.ImVec4(0.85, 0.00, 0.00, 1.00)
				else
					toggleIcon = fa.CHECK -- verde → activar
					toggleColor = imgui.ImVec4(0.00, 0.70, 0.00, 1.00)
				end

				imgui.PushStyleColor(imgui.Col.Button, toggleColor)
				imgui.PushStyleColor(
					imgui.Col.ButtonHovered,
					imgui.ImVec4(
						math.min(toggleColor.x + 0.1, 1.0),
						math.min(toggleColor.y + 0.1, 1.0),
						math.min(toggleColor.z + 0.1, 1.0),
						1.0
					)
				)
				imgui.PushStyleColor(imgui.Col.ButtonActive, toggleColor)

				if imgui.Button(toggleIcon, imgui.ImVec2(wX, btnH)) then
					if isEnabled then
						for _, scr in ipairs(script.list()) do
							if scr.path:find(selectedFile.name, 1, true) then
								script.unload(scr)
								break
							end
						end
						cfgData.scripts[key] = false
					else
						script.load(getWorkingDirectory() .. "/" .. selectedFile.name)
						cfgData.scripts[key] = true
					end
					cfgSave(cfgData)
				end
				imgui.PopStyleColor(3)
			end

			-- 🔹 Siempre → Trash
			imgui.SameLine(nil, spacing)
			imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.05, 0.05, 0.05, 1.00))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.15, 0.15, 0.15, 1.00))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.00, 0.00, 1.00))
			imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(0.65, 0.65, 0.65, 1.00))
			if imgui.Button(fa.TRASH, imgui.ImVec2(wTrash, btnH)) then
				lua_thread.create(function()
					local filename = selectedFile.name
					local path = getWorkingDirectory() .. "/" .. filename
					local ok = os.remove(path)
					if ok then
						clearStatusCache()
						for _, scr in ipairs(script.list()) do
							if scr.path:find(filename, 1, true) then
								script.unload(scr)
								break
							end
						end
						cfgData.scripts[key] = nil
						cfgSave(cfgData)

						scriptEnabled[key] = nil
						refreshRepoFiles()
					end
				end)
				showInfoWindow[0] = false
			end
			imgui.PopStyleColor(4)
		else
			imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.00, 0.45, 0.85, 1.00))
			imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.10, 0.55, 0.95, 1.00))
			imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.00, 0.35, 0.75, 1.00))
			if imgui.Button(fa.DOWNLOAD .. " Instalar", imgui.ImVec2(0, btnH)) then
				lua_thread.create(function()
					downloadFile(selectedFile.url, selectedFile.name)
				end)
				showInfoWindow[0] = false
			end
			imgui.PopStyleColor(3)
		end

		imgui.EndChild()

		imgui.EndChild()
		imgui.PopStyleColor()

		-- Espacio entre columnas
		imgui.SameLine()
		imgui.Dummy(imgui.ImVec2(gapBetween, 0))
		imgui.SameLine()

		-- Columna derecha
		imgui.BeginChild(
			"##rightpanel",
			imgui.ImVec2(rightWidth - 10, childHeight - 20),
			false,
			imgui.WindowFlags.NoScrollbar
		)

		if extra then
			-- Botón "Descripción"
			local label = fa.COMMENT_DOTS .. " Descripción"

			local textSize = imgui.CalcTextSize(label)
			local paddingX, paddingY = 20, 8
			local buttonWidth = textSize.x + paddingX
			local buttonHeight = textSize.y + paddingY

			imgui.Button(label, imgui.ImVec2(buttonWidth, buttonHeight))
			imgui.Spacing()

			imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.109, 0.106, 0.149, 1.0))
			-- Caja de descripción + créditos
			imgui.BeginChild(
				"##descriptionBox",
				imgui.ImVec2(0, 0),
				false,
				imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
			)

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
			imgui.PopStyleColor()
		else
			imgui.TextWrapped("No hay información adicional")
		end

		imgui.EndChild()
		imgui.PopFont()
	end

	imgui.EndChild()
	imgui.End()
end)
local MainMenu = imgui.OnFrame(function()
	return windowState[0]
end, function(self)
	imgui.SetNextWindowSize(imgui.ImVec2(622, 388), imgui.Cond.FirstUseEver)
	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
	imgui.Begin(
		"##windowState",
		windowState,
		imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoScrollbar
	)

	local windowSize = imgui.GetWindowSize()

	-- 🔹 Header fijo arriba (40px de alto aprox)
	local headerHeight = 40
	imgui.BeginChild(
		"##header",
		imgui.ImVec2(windowSize.x, headerHeight),
		false,
		imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
	)

	-- título a la izquierda
	imgui.SetCursorPos(imgui.ImVec2(15, 10))
	local bgColor = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
	imgui.PushStyleColor(imgui.Col.Text, bgColor)
	imgui.PushFont(font1)
	imgui.CenterText("GamePatch ")
	imgui.PopFont()
	imgui.PopStyleColor()

	-- botón cerrar a la derecha
	imgui.SetCursorPos(imgui.ImVec2(windowSize.x - 46, 10))
	imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(1.0, 1.0, 1.0, 1))
	addons.CloseButton("##closemenu", windowState, 36, 15)
	imgui.PopStyleColor()

	imgui.EndChild()

	-- 🔹 Contenido debajo del header
	imgui.SetCursorPos(imgui.ImVec2(15, headerHeight + 10))
	imgui.BeginChild(
		"##settings_inner",
		imgui.ImVec2(windowSize.x - 30, windowSize.y - headerHeight - 20),
		false,
		imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse
	)

	imgui.PushFont(font2)
	imgui.Spacing()
	if imgui.Button(fa.REPEAT .. "##reload", imgui.ImVec2(40, 30)) then
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
end)

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
			),
				true
		end
		return to, false
	end

	UI_CUSTOM_SLIDER = UI_CUSTOM_SLIDER or {}
	UI_CUSTOM_SLIDER[str_id] = UI_CUSTOM_SLIDER[str_id] or { active = false, hovered = false, start = 0 }

	imgui.InvisibleButton(str_id, imgui.ImVec2(width, 20))
	local isActive, isHovered = imgui.IsItemActive(), imgui.IsItemHovered()
	UI_CUSTOM_SLIDER[str_id].active, UI_CUSTOM_SLIDER[str_id].hovered = isActive, isHovered

	if isActive then
		if imgui.GetIO().KeyAlt then
			alt_active_slider_id = str_id
		else
			active_slider_id = str_id
		end
	else
		if active_slider_id == str_id then
			active_slider_id = nil
		end
		if alt_active_slider_id == str_id and not imgui.GetIO().KeyAlt then
			alt_active_slider_id = nil
		end
	end

	local colorPadding = bringVec4To(
		isHovered and imgui.ImVec4(0.3, 0.3, 0.3, 0.8) or imgui.ImVec4(0.95, 0.95, 0.95, 0.8),
		isHovered and imgui.ImVec4(0.95, 0.95, 0.95, 0.8) or imgui.ImVec4(0.3, 0.3, 0.3, 0.8),
		UI_CUSTOM_SLIDER[str_id].start,
		0.2
	)

	local isAltPressed, mouseDown = imgui.GetIO().KeyAlt, imgui.IsMouseDown(0)
	local isInteger, step = (math.floor(min) == min) and (math.floor(max) == max), (max - min) / (width * 80)
	if isInteger then
		step = 1
	end

	if
		((str_id == active_slider_id and not isAltPressed) or (str_id == alt_active_slider_id and isAltPressed))
		and mouseDown
	then
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
				if v < min then
					v = min
				end
				if v > max then
					v = max
				end
				value[0] = v
			end
		end
	end

	local posCircleX = p.x + 7.5 + (width - 10) / (max - min) * (value[0] - min)
	local eCol, brightness = imgui.GetStyle().Colors[imgui.Col.FrameBg], 0.2
	local triangleColor = imgui.ImVec4(eCol.x, eCol.y, eCol.z, 1.0)
	if isHovered then
		triangleColor = imgui.ImVec4(eCol.x + brightness, eCol.y + brightness, eCol.z + brightness, 1.0)
	end

	if (str_id == active_slider_id and isAltPressed) or (str_id == alt_active_slider_id and isAltPressed) then
		DL:AddRectFilledMultiColor(
			imgui.ImVec2(p.x, p.y + 7),
			imgui.ImVec2(p.x + width, p.y + 14),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button])
		)
		local arrowSize, halfArrowSize, midY, leftX, rightX = 10, 5, p.y + 10, p.x, p.x + width

		DL:AddLine(
			imgui.ImVec2(leftX, midY - halfArrowSize),
			imgui.ImVec2(leftX + arrowSize, midY),
			imgui.GetColorU32Vec4(triangleColor),
			1
		)
		DL:AddLine(
			imgui.ImVec2(leftX, midY + halfArrowSize),
			imgui.ImVec2(leftX + arrowSize, midY),
			imgui.GetColorU32Vec4(triangleColor),
			1
		)
		DL:AddLine(
			imgui.ImVec2(leftX, midY - halfArrowSize),
			imgui.ImVec2(leftX, midY + halfArrowSize),
			imgui.GetColorU32Vec4(triangleColor),
			1
		)
		DL:AddLine(
			imgui.ImVec2(rightX, midY - halfArrowSize),
			imgui.ImVec2(rightX - arrowSize, midY),
			imgui.GetColorU32Vec4(triangleColor),
			1
		)
		DL:AddLine(
			imgui.ImVec2(rightX, midY + halfArrowSize),
			imgui.ImVec2(rightX - arrowSize, midY),
			imgui.GetColorU32Vec4(triangleColor),
			1
		)
		DL:AddLine(
			imgui.ImVec2(rightX, midY - halfArrowSize),
			imgui.ImVec2(rightX, midY + halfArrowSize),
			imgui.GetColorU32Vec4(triangleColor),
			1
		)
	else
		DL:AddRectFilledMultiColor(
			imgui.ImVec2(p.x, p.y + 7),
			imgui.ImVec2(p.x + width, p.y + 18),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button]),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.FrameBg]),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.FrameBg]),
			imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button])
		)
		drawTriangle(
			imgui.ImVec2(posCircleX - 11, p.y + 1),
			imgui.ImVec2(posCircleX + 6, p.y + 23),
			imgui.ImVec2(posCircleX, p.y + 8),
			imgui.GetColorU32Vec4(triangleColor),
			2
		)
	end

	DL:AddText(
		imgui.ImVec2(p.x + width + 10, p.y),
		imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Text]),
		string.format(sformat, value[0])
	)
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

	return imgui
		.GetIO().Fonts
		:AddFontFromMemoryCompressedBase85TTF(fa.get_font_data_base85(style), size, cfg, iconRanges)
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
	local fontPath = getWorkingDirectory() .. "/resource/fonts/"

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
	colors[clr.Text] = ImVec4(0.95, 0.95, 0.95, 1.00)
	colors[clr.TextDisabled] = ImVec4(0.50, 0.50, 0.50, 1.00)
	colors[clr.WindowBg] = ImVec4(0.137, 0.137, 0.188, 1.0)
	colors[clr.PopupBg] = ImVec4(0.13, 0.13, 0.13, 1.00)
	colors[clr.Border] = ImVec4(0.40, 0.40, 0.40, 0.40)
	colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
	colors[clr.FrameBg] = ImVec4(0.20, 0.20, 0.20, 1.00)
	colors[clr.FrameBgHovered] = ImVec4(0.28, 0.28, 0.28, 1.00)
	colors[clr.FrameBgActive] = ImVec4(0.35, 0.35, 0.35, 1.00)
	colors[clr.TitleBg] = ImVec4(0.08, 0.08, 0.08, 1.00)
	colors[clr.TitleBgActive] = ImVec4(0.16, 0.16, 0.16, 1.00)
	colors[clr.TitleBgCollapsed] = ImVec4(0.05, 0.05, 0.05, 0.80)
	colors[clr.MenuBarBg] = ImVec4(0.14, 0.14, 0.14, 1.00)
	colors[clr.ScrollbarBg] = ImVec4(0.05, 0.05, 0.05, 0.53)
	colors[clr.ScrollbarGrab] = ImVec4(0.30, 0.30, 0.30, 1.00)
	colors[clr.ScrollbarGrabHovered] = ImVec4(0.40, 0.40, 0.40, 1.00)
	colors[clr.ScrollbarGrabActive] = ImVec4(0.50, 0.50, 0.50, 1.00)
	colors[clr.CheckMark] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.SliderGrab] = ImVec4(0.26, 0.59, 0.98, 0.78)
	colors[clr.SliderGrabActive] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.Button] = ImVec4(0.20, 0.20, 0.20, 1.00)
	colors[clr.ButtonHovered] = ImVec4(0.28, 0.28, 0.28, 1.00)
	colors[clr.ButtonActive] = ImVec4(0.35, 0.35, 0.35, 1.00)
	colors[clr.Header] = ImVec4(0.26, 0.59, 0.98, 0.55)
	colors[clr.HeaderHovered] = ImVec4(0.26, 0.59, 0.98, 0.80)
	colors[clr.HeaderActive] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.Separator] = ImVec4(0.60, 0.60, 0.60, 0.50)
	colors[clr.SeparatorHovered] = ImVec4(0.75, 0.75, 0.75, 0.78)
	colors[clr.SeparatorActive] = ImVec4(0.90, 0.90, 0.90, 1.00)
	colors[clr.ResizeGrip] = ImVec4(0.26, 0.59, 0.98, 0.25)
	colors[clr.ResizeGripHovered] = ImVec4(0.26, 0.59, 0.98, 0.67)
	colors[clr.ResizeGripActive] = ImVec4(0.26, 0.59, 0.98, 0.95)
	colors[clr.PlotLines] = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotLinesHovered] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.PlotHistogram] = ImVec4(0.61, 0.61, 0.61, 1.00)
	colors[clr.PlotHistogramHovered] = ImVec4(0.26, 0.59, 0.98, 1.00)
	colors[clr.TextSelectedBg] = ImVec4(0.26, 0.59, 0.98, 0.35)
end
