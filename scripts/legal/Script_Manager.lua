-- MonetLoader for Android 3.0.0
-- Reference script: Script Manager
--
-- For script developers:
-- If you want to allow your script to be toggled from Script Manager, you must implement the following API in EXPORTS:
-- 1. For "Enabled" checkbox:
--    a. canToggle: return true
--    b. getToggle: return <your toggled status variable>
--    c. toggle: execute any code, and switch <your toggled status variable> (switching is optional)
-- 2. For "Activate button":
--    a. canToggle: return false
--    b. getToggle: return false
--    c. toggle: execute any code
--
-- Simple example that implements "Enabled" checkbox:
-- local toggled = false
-- EXPORTS = {
--   canToggle = function() return true end,
--   getToggle = function() return toggled end,
--   toggle = function() toggled = not toggled end
-- }
--

-- script info
script_name('Script Manager')
script_version('1.2')
script_version_number(3)
script_author('The MonetLoader Team')
script_description('Administrador de scripts que se abre al deslizar hacia la izquierda sobre el radar y proporciona la capacidad de gestionar scripts, ver registros, ejecutar código Lua en un modo similar a REPL y recibir notificaciones de scripts..')
script_properties('work-in-pause', 'forced-reloading-only') -- work even in pause and don't reload ourselves on reloadScripts()


-- libs
local levels = require('moonloader').message_prefix
local ffi = require('ffi')
local widgets = require('widgets') -- for WIDGET_(...)
local imgui = require('mimgui')
local faicons = require('fAwesome6')
local cfg = require('jsoncfg')

local https = require("ssl.https")
local ltn12 = require("ltn12")

-- pretty printing (https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console)

local repoFiles = {}
local json = require("dkjson")

function refreshRepoFiles()
    local url = "https://api.github.com/repos/Nelson-hast/plujin-manager/contents/scripts/legal"
    local body, code = https.request(url)

    if code ~= 200 then
        print("[Downloader] ❌ Error al obtener lista: " .. tostring(code))
        return
    end

    local data, _, err = json.decode(body, 1, nil)
    if err then
        print("[Downloader] ❌ Error parseando JSON: " .. tostring(err))
        return
    end

    repoFiles = {}
    for _, item in ipairs(data) do
        if item.type == "file" and item.name:match("%.lua$") then
            table.insert(repoFiles, { name = item.name, url = item.download_url })
        end
    end

    print("[Downloader] ✅ Lista actualizada (" .. tostring(#repoFiles) .. " archivos)")
end

-- Llamamos al inicio para tener la lista cargada
refreshRepoFiles()

function renderDownloaderUI()
    if imgui.CollapsingHeader("📥 Descargas disponibles") then
        
        -- Botón para refrescar la lista desde GitHub
        if imgui.Button("🔄 Actualizar lista") then
            lua_thread.create(function()
                refreshRepoFiles()
            end)
        end

        imgui.Separator()

        -- Dibujar un botón por cada archivo
        for _, f in ipairs(repoFiles) do
            if imgui.Button(f.name) then
                lua_thread.create(function()
                    downloadFile(f.url, f.name)
                end)
            end
        end
    end
end

function downloadFile(url, filename)
    local savePath = getWorkingDirectory() .. "/" .. filename

    print("[Downloader] savePath = " .. tostring(savePath))

    local file = io.open(savePath, "wb")
    if not file then
        print("[Downloader] ❌ No se pudo abrir el archivo para escribir")
        return false
    end
    print("[Downloader] Archivo abierto correctamente, iniciando request...")

    local body, code, headers, status = https.request{
        url = url,
        sink = ltn12.sink.file(file)
    }

    print("[Downloader] body=" .. tostring(body))
    print("[Downloader] code=" .. tostring(code))
    print("[Downloader] status=" .. tostring(status))

    if code == 200 then
        print("[Downloader] ✅ Descarga completada en: " .. savePath)
        return true
    else
        print("[Downloader] ❌ Error HTTP: " .. tostring(code))
        return false
    end
end

function prettyPrintTable(node)
  local cache, stack, output = {},{},{}
  local depth = 1
  local output_str = "{"

  while true do
    local size = 0
    for k,v in pairs(node) do
      size = size + 1
    end

    local cur_index = 1
    for k,v in pairs(node) do
      if (cache[node] == nil) or (cur_index >= cache[node]) then

        if (string.find(output_str,"}",output_str:len())) then
          output_str = output_str .. ","
        end

        -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
        table.insert(output,output_str)
        output_str = ""

        local key
        if (type(k) == "string") then
          key = "['"..tostring(k).."']"
        else
          key = "["..tostring(k).."]"
        end

        if (type(v) ~= "table" and type(v) ~= "string") then
          output_str = output_str .. key .. " = "..tostring(v)
        elseif (type(v) == "table") then
          output_str = output_str .. key .. " = {"
          table.insert(stack,node)
          table.insert(stack,v)
          cache[node] = cur_index+1
          break
        else
          output_str = output_str .. key .. " = '"..tostring(v).."'"
        end

        if (cur_index == size) then
          output_str = output_str .. "}"
        else
          output_str = output_str .. ","
        end
      else
        -- close the table
        if (cur_index == size) then
          output_str = output_str .. "}"
        end
      end

      cur_index = cur_index + 1
    end

    if (size == 0) then
      output_str = output_str .. "}"
    end

    if (#stack > 0) then
      node = stack[#stack]
      stack[#stack] = nil
      depth = cache[node] == nil and depth + 1 or depth - 1
    else
      break
    end
  end

  -- This is necessary for working with HUGE tables otherwise we run out of memory using concat on huge strings
  table.insert(output,output_str)
  output_str = table.concat(output)
  
  return output_str
end

-- pretty prints arguments, expanding tables (also supports multiple nils without omitting them)
function prettyPrint(...)
  -- we use select instead of table unpacking in order to handle nil values correctly
  local argc = select('#', ...)
  if argc == 0 then
    return 'nil'
  end

  local output_str = ''
  for i=1, argc do
    local v = select(i, ...)
    if type(v) == 'table' then
        output_str = output_str .. prettyPrintTable(v)
    elseif type(v) == 'string' then
        output_str = output_str .. "'" .. v .. "'"
    else
        output_str = output_str .. tostring(v)
    end
    if i ~= argc then
      output_str = output_str .. ',' 
    end
  end

  return output_str
end


-- simple ipairs implementation that supports any type

function stateless_iter(a, i)
  i = i + 1
  local v = a[i]
  if v then
    return i, v
  end
end

function any_ipairs(a)
  return stateless_iter, a, 0
end


-- circular buffer class (https://gist.github.com/johndgiese/3e1c6d6e0535d4536692)

local function rotate_indice(i, n)
  return ((i - 1) % n) + 1
end

local circular_buffer = {}

function circular_buffer.reverse_iter(a, i)
  i = i - 1
  local v = a[i]
  if v then
    return i, v
  end
end

function circular_buffer.reverse_ipairs(self)
  return circular_buffer.reverse_iter, self, 0
end

function circular_buffer.filled(self)
  return #(self.history) == self.max_length
end

function circular_buffer.push(self, value)
  if self:filled() then
    local value_to_be_removed = self.history[self.oldest]
    self.history[self.oldest] = value
    self.oldest = self.oldest == self.max_length and 1 or self.oldest + 1
  else
    self.history[#(self.history) + 1] = value
  end
end

function circular_buffer.clear(self)
  self.history = {}
  self.oldest = 1
end

circular_buffer.metatable = {}

-- positive values index from newest to oldest (starting with 1)
-- negative values index from oldest to newest (starting with -1)
function circular_buffer.metatable.__index(self, i)
  local history_length = #(self.history)
  if i == 0 or math.abs(i) > history_length then
    return nil
  elseif i > 0 then
    local i_rotated = rotate_indice(self.oldest - 1 + i, history_length)
    return self.history[i_rotated]
  else
    local i_rotated = rotate_indice(self.oldest + i, history_length)
    return self.history[i_rotated]
  end
end

function circular_buffer.metatable.__len(self)
  return #(self.history)
end

function circular_buffer.new(max_length)
  if type(max_length) ~= 'number' or max_length <= 1 then
    error("Buffer length must be a positive integer")
  end

  local instance = {
    history = {},
    oldest = 1,
    max_length = max_length,
    push = circular_buffer.push,
    filled = circular_buffer.filled,
    clear = circular_buffer.clear
  }
  setmetatable(instance, circular_buffer.metatable)
  return instance
end


-- notifications (https://www.blast.hk/threads/132205/)

Notifications = {
  _version = '0.2',
  _list = {},
  _COLORS = {
    [0] = {back = {0.26, 0.71, 0.81, 1},    text = {1, 1, 1, 1}, icon = {1, 1, 1, 1}, border = {1, 0, 0, 0}},
    [1] = {back = {0.26, 0.81, 0.31, 1},    text = {1, 1, 1, 1}, icon = {1, 1, 1, 1}, border = {1, 0, 0, 0}},
    [2] = {back = {1, 0.39, 0.39, 1},       text = {1, 1, 1, 1}, icon = {1, 1, 1, 1}, border = {1, 0, 0, 0}},
    [3] = {back = {0.97, 0.57, 0.28, 1},    text = {1, 1, 1, 1}, icon = {1, 1, 1, 1}, border = {1, 0, 0, 0}},
    [4] = {back = {0, 0, 0, 1},             text = {1, 1, 1, 1}, icon = {1, 1, 1, 1}, border = {1, 0, 0, 0}},
  },

  TYPE = {
      INFO = 0,
      OK = 1,
      ERROR = 2,
      WARN = 3,
      DEBUG = 4
  },
  ICON = {
      [0] = faicons('CIRCLE_INFO'),
      [1] = faicons('CHECK'),
      [2] = faicons('XMARK'),
      [3] = faicons('EXCLAMATION'),
      [4] = faicons('WRENCH')
  }
}

Notifications.Show = function(text, type, time, colors)
  table.insert(Notifications._list, {
    text = text,
    type = type or 2,
    time = time or 4,
    start = os.clock(),
    alpha = 0,
    colors = colors or Notifications._COLORS[type]
  })
end

Notifications._TableToImVec = function(tbl)
  return imgui.ImVec4(tbl[1], tbl[2], tbl[3], tbl[4])
end

Notifications._BringFloatTo = function(from, to, start_time, duration)
  local timer = os.clock() - start_time
  if timer >= 0.00 and timer <= duration then
      local count = timer / (duration / 100)
      return from + (count * (to - from) / 100), true
  end
  return (timer > duration) and to or from, false
end

imgui.OnFrame(
  function() return #Notifications._list > 0 end,
  function(self)
    self.HideCursor = true

    for k, data in ipairs(Notifications._list) do
      --==[ UPDATE ALPHA ]==--
      if data.alpha == nil then Notifications._list[k].alpha = 0 end
      if os.clock() - data.start < 0.5 then
        Notifications._list[k].alpha = Notifications._BringFloatTo(0, 1, data.start, 0.5)
      elseif data.time - 0.5 < os.clock() - data.start then
        Notifications._list[k].alpha = Notifications._BringFloatTo(1, 0, data.start + data.time - 0.5, 0.5)
      end

      --==[ REMOVE ]==--
      if os.clock() - data.start > data.time then
        table.remove(Notifications._list, k)
      end
    end

    local resX, resY = getScreenResolution()
    local sizeX, sizeY = 300 * MONET_DPI_SCALE, 300 * MONET_DPI_SCALE
    imgui.SetNextWindowPos(imgui.ImVec2(resX * 0.5, resY * 0.5), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
    imgui.Begin('notf_window', _, 0
        + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoTitleBar
        + imgui.WindowFlags.NoResize
        + imgui.WindowFlags.NoMove
        + imgui.WindowFlags.NoBackground
    )
    
    local fiveSc = 5 * MONET_DPI_SCALE
    local winSize = imgui.GetWindowSize()
    imgui.SetWindowPosVec2(imgui.ImVec2(resX - 10 * MONET_DPI_SCALE - winSize.x, resY * 0.4))
    
    for k, data in ipairs(Notifications._list) do
      ------------------------------------------------
      local default_data = {
        text = 'text',
        type = 0,
        time = 1500
      }
      for k, v in pairs(default_data) do
        if data[k] == nil then
          data[k] = v
        end
      end
  
  
      local c = imgui.GetCursorPos()
      local p = imgui.GetCursorScreenPos()
      local DL = imgui.GetWindowDrawList()
  
      local textSize = imgui.CalcTextSize(data.text)
      local iconSize = imgui.CalcTextSize(Notifications.ICON[data.type] or faicons('XMARK'))
      local size = imgui.ImVec2(fiveSc + iconSize.x + fiveSc + textSize.x + fiveSc, fiveSc + textSize.y + fiveSc)
  
  
      local winSize = imgui.GetWindowSize()
      if winSize.x > size.x + 20 * MONET_DPI_SCALE then
          imgui.SetCursorPosX(winSize.x - size.x - 8 * MONET_DPI_SCALE)
      end
  
      
      imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, data.alpha)
      imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, fiveSc)
      imgui.PushStyleColor(imgui.Col.ChildBg,     Notifications._TableToImVec(data.colors.back or Notifications._COLORS[data.type].back))
      imgui.PushStyleColor(imgui.Col.Border,      Notifications._TableToImVec(data.colors.border or Notifications._COLORS[data.type].border))
      imgui.BeginChild('toastNotf:'..tostring(k)..tostring(data.text), size, true, imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoScrollWithMouse)
        imgui.PushStyleColor(imgui.Col.Text,    Notifications._TableToImVec(data.colors.icon or Notifications._COLORS[data.type].icon))
        imgui.SetCursorPos(imgui.ImVec2(fiveSc, size.y / 2 - iconSize.y / 2))
        imgui.Text(Notifications.ICON[data.type] or faicons('XMARK'))
        imgui.PopStyleColor()

        imgui.PushStyleColor(imgui.Col.Text,    Notifications._TableToImVec(data.colors.text or Notifications._COLORS[data.type].text))
        imgui.SetCursorPos(imgui.ImVec2(fiveSc + iconSize.x + fiveSc, size.y / 2 - textSize.y / 2))
        imgui.Text(data.text)
        imgui.PopStyleColor()
      imgui.EndChild()
      imgui.PopStyleColor(2)
      imgui.PopStyleVar(2)
      ------------------------------------------------
    end
    
    imgui.End()
  end
)


-- global vars

local DEFAULT_CONFIG = { -- default config
  crashNotifications = true, -- whether to show script crash notifications or not
  scriptMessageNotifications = false, -- whether to show script message notifications or not
  messagesCount = 100, -- count of saved messages
  lastCrashesCount = 10, -- count of saved crashed scripts
  shellHistoryCount = 50 -- count of saved shell history
}

local config = cfg.load(DEFAULT_CONFIG) -- simply config
local messages = circular_buffer.new(config.messagesCount) -- buffer that stores last messages
local lastCrashes = circular_buffer.new(config.lastCrashesCount) -- buffer that stores script info about last crashes
local shellHistory = circular_buffer.new(config.shellHistoryCount) -- buffer that stores shell history
local shellInputHistory = circular_buffer.new(math.ceil(config.shellHistoryCount / 2)) -- buffer that stores shell input history
local shellInputHistoryPos = 0 -- current position in shellInputHistory
local scriptCrashInfos = {} -- buffer that stores reasons for script crash
local reloadLastCrashInfos = {} -- buffer that stores crash info that initiated reload for a given path

local selectedScriptId = -1 -- id of selected script
local selectedScriptExports -- table returned by import on selected script
local wasInLog = false -- set to true when tab is log, used to auto-scroll to bottom on tab switch
local wasInShell = false -- same, but with shell
local windowState = imgui.new.bool(false) -- script mgr window is active or not
-- some imgui wrappers
local imScriptStatus = imgui.new.bool(false) -- ffi variable for script toggling
local imCrashNotifications = imgui.new.bool(config.crashNotifications)
local imScriptMessageNotifications = imgui.new.bool(config.scriptMessageNotifications)
local imMessagesCount = imgui.new.int(config.messagesCount)
local imLastCrashesCount = imgui.new.int(config.lastCrashesCount)
local imShellHistoryCount = imgui.new.int(config.shellHistoryCount)

local scriptsSearchBuffer = imgui.new.char[128]() -- buffer for scripts search input
local scriptsSearchText = '' -- scripts search input as lua string
local logSearchBuffer = imgui.new.char[128]() -- buffer for log search input
local logSearchText = '' -- log search input as lua string
local shellInputBuffer = imgui.new.char[512]() -- buffer for shell input

-- utils

-- formats time in seconds into format: xxh xxm xxs (hours and minutes are omitted if not present)
function formatClock(diff)
  diff = math.floor(diff)
  local seconds = diff % 60
  diff = math.floor(diff / 60)
  local minutes = diff % 60
  diff = math.floor(diff / 60)
  local hours = diff

  return (hours > 0 and tostring(hours) .. 'h ' or '') .. (minutes > 0 and tostring(minutes) .. 'm ' or '') .. tostring(seconds) .. 's'
end


-- https://www.blast.hk/threads/111224/
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil

    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true

    -- bake only needed glyphs in atlas in order to not waste videomemory
    local builder = imgui.ImFontGlyphRangesBuilder()
    for _, v in pairs(Notifications.ICON) do
      builder:AddText(v)
    end
    glyphRanges = imgui.ImVector_ImWchar() -- global, because it must be present until font atlas is built
    builder:BuildRanges(glyphRanges)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14 * MONET_DPI_SCALE, config, glyphRanges[0].Data) -- load scaled DPI font

    imgui.GetStyle():ScaleAllSizes(MONET_DPI_SCALE) -- scale default style
end)


-- rendering

-- main window
imgui.OnFrame(
  function() return windowState[0] end,
  function(self)
    imgui.SetNextWindowSize(imgui.ImVec2(530 * MONET_DPI_SCALE, 330 * MONET_DPI_SCALE), imgui.Cond.FirstUseEver)
    imgui.Begin('Script Manager v' .. script.this.version, windowState, imgui.WindowFlags.NoCollapse)

    if imgui.BeginTabBar('Tabs') then
      local didLogRender = false
      local didShellRender = false

      if imgui.BeginTabItem('Scripts') then -- common scripts control
        if imgui.InputTextWithHint('##ScriptsSearch', 'Buscar...', scriptsSearchBuffer, ffi.sizeof(scriptsSearchBuffer)) then
          scriptsSearchText = ffi.string(scriptsSearchBuffer):lower()
        end
        imgui.SameLine()
        if imgui.Button('Recargar todo') then
          imgui.OpenPopup('Confirmar recargar todo')
        end

        if imgui.BeginPopupModal('Confirmar recargar todo') then
          imgui.Text('Estás seguro de que quieres recargar todos los scripts?')
    
          if imgui.Button('Si', imgui.ImVec2(150 * MONET_DPI_SCALE, 50 * MONET_DPI_SCALE)) then
            reloadScripts()
            Notifications.Show('Todos los scripts recargados!', Notifications.TYPE.OK)
            imgui.CloseCurrentPopup()
          end
          imgui.SameLine()
          if imgui.Button('No', imgui.ImVec2(150 * MONET_DPI_SCALE, 50 * MONET_DPI_SCALE)) then
            imgui.CloseCurrentPopup()
          end
    
          imgui.End()
        end

        imgui.BeginChild('##ScriptsChild') -- child in order to only scroll scripts
        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 0))
        imgui.Columns(2, '##ScriptsColumns', false)
        imgui.PopStyleVar()
        local scripts = script.list()

        if imgui.ListBoxHeaderVec2('##ScriptsListBox', imgui.ImVec2(-1, -1)) then
          for i, v in ipairs(scripts) do
            if v.name:lower():find(scriptsSearchText, 1, true) then
              if imgui.Selectable(v.name .. '##' .. tostring(v.id), selectedScriptId == v.id) then
                selectedScriptId = v.id
                selectedScriptExports = v.exports
              end
            end
          end
          imgui.ListBoxFooter()
        end

        imgui.NextColumn()

        local scr = script.get(selectedScriptId)
        if scr ~= nil then
          imgui.TextWrapped('Nombre: %s', scr.name)
          if scr.filename ~= scr.name then
            imgui.TextWrapped('Nombre del archivo: %s', scr.filename)
          end

          local version = scr.version
          local version_num = scr.version_num
          if #version ~= 0 and version_num ~= 0 then
            imgui.TextWrapped('Version: %s (%g)', version, version_num)
          elseif #version == 0 and version_num ~= 0 then
            imgui.TextWrapped('Version: %g', version_num)
          elseif #version ~= 0 and version_num == 0 then
            imgui.TextWrapped('Version: %s', version)
          end

          local authors = table.concat(scr.authors, ', ')
          if #authors ~= 0 then
            imgui.TextWrapped('Autores: %s', authors)
          end

          local desc = scr.description
          if #desc ~= 0 then
            imgui.TextWrapped('Descripcion: %s', desc)
          end

          local url = scr.url
          if #url ~= 0 then
            imgui.TextWrapped('URL: %s', url)
          end

          if imgui.Button('Descargar') then
            scr:unload()
            Notifications.Show(scr.name .. ':\nDescargado!', Notifications.TYPE.OK)
          end
          imgui.SameLine()
          if imgui.Button('Recargar') then
            scr:reload()
            Notifications.Show(scr.name .. ':\nRecargado!', Notifications.TYPE.OK)
          end

          -- pcall hell in order to not crash Script Manager if selected script implements invalid API
          if selectedScriptExports.canToggle ~= nil and selectedScriptExports.getToggle ~= nil and selectedScriptExports.toggle ~= nil then
            local status, result = pcall(selectedScriptExports.canToggle)
            if not status or type(result) ~= 'boolean' then
              Notifications.Show(scr.name .. ':\nError calling canToggle!\nMake sure it returns a boolean.', Notifications.TYPE.WARN)
            else
              if result then
                local status2, toggle = pcall(selectedScriptExports.getToggle)
                if not status2 or type(toggle) ~= 'boolean' then
                  Notifications.Show(scr.name .. ':\nError calling getToggle!\nMake sure it returns a boolean.', Notifications.TYPE.WARN)
                else
                  imScriptStatus[0] = toggle
                  if imgui.Checkbox('Habilitado', imScriptStatus) then
                    local status3 = pcall(selectedScriptExports.toggle)
                    if not status3 then
                      Notifications.Show(scr.name .. ':\nError calling toggle!', Notifications.TYPE.WARN)
                    end
                  end
                end
              else
                if imgui.Button('Activate') then
                  local status2 = pcall(selectedScriptExports.toggle)
                  if not status2 then
                    Notifications.Show(scr.name .. ':\nError calling toggle!', Notifications.TYPE.WARN)
                  end
                end
              end
            end
          end
        else
          imgui.Text('<<<\nSelecciona cualquier script de la izquierda')
        end

        imgui.Columns(1)
        imgui.EndChild()

        imgui.EndTabItem()
      end

      if imgui.BeginTabItem('Registro') then -- log of recent events
        if imgui.InputTextWithHint('##LogSearch', 'Buscar...', logSearchBuffer, ffi.sizeof(logSearchBuffer)) then
          logSearchText = ffi.string(logSearchBuffer):lower()
        end
        imgui.SameLine()
        if imgui.Button('Borrar historial') then
          messages:clear()
        end

        imgui.BeginChild('##LogChild') -- child in order to only scroll text without scrolling search and etc

        for i, v in any_ipairs(messages) do
          if v:lower():find(logSearchText, 1, true) then
            imgui.TextWrapped('%s', v)
          end
        end

        if imgui.GetScrollY() >= imgui.GetScrollMaxY() or not wasInLog then
          imgui.SetScrollHereY(1.0)
        end

        imgui.EndChild()
  
        imgui.EndTabItem()
        didLogRender = true
      end

      if imgui.BeginTabItem('Ultimos crash') then -- log of last crashes
        imgui.BeginChild('##LastCrashesChild', imgui.ImVec2(0, 0), true) -- child in order to only scroll table and for border
        imgui.Columns(3, '##LastCrashesColumns', true)

        imgui.AlignTextToFramePadding()
        imgui.Text('Nombre del script')
        imgui.NextColumn()
        imgui.AlignTextToFramePadding()
        imgui.Text('Tiempo desde el crash')
        imgui.NextColumn()
        imgui.AlignTextToFramePadding()
        imgui.Text('Acciones')
        imgui.Separator()
        imgui.NextColumn()

        for i, v in circular_buffer.reverse_ipairs(lastCrashes) do
          if not v.hidden then
            imgui.AlignTextToFramePadding()
            imgui.Text('%s', v.name)
            imgui.NextColumn()
            imgui.AlignTextToFramePadding()
            imgui.Text('%s', formatClock(os.clock() - v.time))
            imgui.NextColumn()

            if not v.reloaded then
              if imgui.Button('Reload##' .. tostring(i)) then
                reloadLastCrashInfos[v.path] = v
                script.load(v.path)

                lua_thread.create(function()
                  wait(0)
                  if not v.reloaded then
                    Notifications.Show(v.name .. ':\nReload failed!', Notifications.TYPE.ERROR)
                    reloadLastCrashInfos[v.path] = nil
                  end
                end)
              end

              imgui.SameLine()
            end

            if imgui.Button('Hide##' .. tostring(i)) then
              v.hidden = true
            end

            imgui.Separator()
            imgui.NextColumn()
          end
        end

        imgui.Columns(1)
        imgui.EndChild()
  
        imgui.EndTabItem()
      end

      if imgui.BeginTabItem('Consola') then -- lua shell
        imgui.SetNextItemWidth(-1)
        if imgui.InputTextWithHint('##ShellInput', 'Ejecutar...', shellInputBuffer, ffi.sizeof(shellInputBuffer), imgui.InputTextFlags.EnterReturnsTrue) then
          local text = ffi.string(shellInputBuffer)
          imgui.StrCopy(shellInputBuffer, '')
          shellHistory:push('>> ' .. text)
          shellInputHistory:push(text)
          shellInputHistoryPos = 0

          -- first try to load as expression
          local chunk, err = load('return prettyPrint(' .. text .. ')')
          if not chunk then
            -- then as statement
            chunk, err = load(text)
          end
          if not chunk then
            -- compilation failed
            shellHistory:push('<!> Syntax error: ' .. tostring(err))
          else
            -- provide repl result
            local result, err = pcall(chunk)
            if not result then
              shellHistory:push('<!> Error: ' .. tostring(err))
            else
              shellHistory:push(tostring(err))
            end
          end
        end

        if imgui.Button('Arriba') then
          shellInputHistoryPos = shellInputHistoryPos - 1
          if shellInputHistory[shellInputHistoryPos] ~= nil then
            imgui.StrCopy(shellInputBuffer, shellInputHistory[shellInputHistoryPos])
          else
            shellInputHistoryPos = shellInputHistoryPos + 1
          end
        end
        imgui.SameLine()
        if imgui.Button('Abajo') then
          shellInputHistoryPos = shellInputHistoryPos + 1
          if shellInputHistoryPos >= 0 then
            shellInputHistoryPos = 0
            imgui.StrCopy(shellInputBuffer, '')
          else
            imgui.StrCopy(shellInputBuffer, shellInputHistory[shellInputHistoryPos])
          end
        end
        imgui.SameLine()
        if imgui.Button('Limpiar') then
          imgui.StrCopy(shellInputBuffer, '')
          shellInputHistoryPos = 0
        end
        imgui.SameLine()
        if imgui.Button('Borrar historial') then
          imgui.StrCopy(shellInputBuffer, '')
          shellInputHistoryPos = 0

          shellHistory:clear()
          shellInputHistory:clear()
        end

        imgui.BeginChild('##ShellChild') -- child in order to only scroll text without scrolling input and etc

        for i, v in any_ipairs(shellHistory) do
          local doPop = false
          if v:sub(1, 3) == '<!>' then
            doPop = true
            imgui.PushStyleColor(imgui.Col.Text, imgui.ImVec4(1.0, 0.0, 0.0, 1.0))
          end
          imgui.TextWrapped('%s', v)
          if doPop then
            imgui.PopStyleColor()
          end
        end

        if imgui.GetScrollY() >= imgui.GetScrollMaxY() or not wasInShell then
          imgui.SetScrollHereY(1.0)
        end

        imgui.EndChild()
  
        imgui.EndTabItem()
        didShellRender = true
      end

      if imgui.BeginTabItem('Configuración') then -- settings menu
        if imgui.Checkbox('Notificaciones de crash', imCrashNotifications) then
          config.crashNotifications = imCrashNotifications[0]
          cfg.save(config)
        end

        if imgui.Checkbox('Notificaciones de mensajes de script', imScriptMessageNotifications) then
          config.scriptMessageNotifications = imScriptMessageNotifications[0]
          cfg.save(config)
        end

        if imgui.InputInt('Cantidad de mensajes', imMessagesCount, 1, 20) then
          if imMessagesCount[0] < 10 then
            imMessagesCount[0] = 10
          elseif imMessagesCount[0] > 5000 then
            imMessagesCount[0] = 5000
          end

          config.messagesCount = imMessagesCount[0]
          cfg.save(config)

          local newBuffer = circular_buffer.new(config.messagesCount)

          for i, v in any_ipairs(messages) do
            newBuffer:push(v)
          end

          messages = newBuffer
        end

        if imgui.InputInt('Cantidad de crash', imLastCrashesCount, 1, 1) then
          if imLastCrashesCount[0] < 2 then
            imLastCrashesCount[0] = 2
          elseif imLastCrashesCount[0] > 100 then
            imLastCrashesCount[0] = 100
          end

          config.lastCrashesCount = imLastCrashesCount[0]
          cfg.save(config)

          local newBuffer = circular_buffer.new(config.lastCrashesCount)

          for i, v in any_ipairs(lastCrashes) do
            newBuffer:push(v)
          end

          lastCrashes = newBuffer
        end

        if imgui.InputInt('Cantidad de historial', imShellHistoryCount, 1, 20) then
          if imShellHistoryCount[0] < 10 then
            imShellHistoryCount[0] = 10
          elseif imShellHistoryCount[0] > 5000 then
            imShellHistoryCount[0] = 5000
          end

          config.shellHistoryCount = imShellHistoryCount[0]
          cfg.save(config)

          local newBuffer = circular_buffer.new(config.shellHistoryCount)
          for i, v in any_ipairs(shellHistory) do
            newBuffer:push(v)
          end
          shellHistory = newBuffer

          local newInputBuffer = circular_buffer.new(math.ceil(config.shellHistoryCount / 2))
          for i, v in any_ipairs(shellInputHistory) do
            newInputBuffer:push(v)
          end
          shellInputHistory = newInputBuffer
        end
        imgui.EndTabItem()
      end

      if imgui.BeginTabItem('Descargas') then
        imgui.Text("Aquí puedes descargar archivos desde GitHub")

        if imgui.Button("Descargar MinecraftHud.lua") then
            lua_thread.create(function()
                print("[Downloader] >>> Iniciando descarga <<<")
                local url = "https://raw.githubusercontent.com/Nelson-hast/plujin-manager/refs/heads/master/scripts/legal/MinecraftHud.lua"
                downloadFile(url, "MinecraftHud.lua")
                print("[Downloader] >>> Hilo de descarga finalizado <<<")
            end)
        end

        renderDownloaderUI()

        imgui.EndTabItem()
      end


      
      imgui.EndTabBar()
      wasInLog = didLogRender
      wasInShell = didShellRender
    end

    imgui.End()
  end
)


-- custom events

-- called whenever a script crashes
function onScriptCrashed(scr, msg)
  if config.crashNotifications then
    Notifications.Show(scr.name .. ':\nCrashed!', Notifications.TYPE.ERROR)
  end

  lastCrashes:push({
    name = scr.name,
    path = scr.path,
    time = os.clock(),
    reloaded = false,
    hidden = false
  })
  messages:push('(crash) ' .. scr.name .. ': ' .. msg)
end


-- events

-- script message handler, save them to buffer
function onScriptMessage(msg, scr)
  if config.scriptMessageNotifications then
    Notifications.Show(scr.name .. ':\n' .. msg, Notifications.TYPE.INFO)
  end

  messages:push('(script) ' .. scr.name .. ': ' .. msg)
end

-- system message handler, get crash info
function onSystemMessage(msg, level, scr)
  if level == levels.TYPE_SYSTEM then
    if scr ~= nil then
      messages:push('(Sistema) ' .. scr.name .. ': ' .. msg)
    else
      messages:push('(Sistema) ' .. msg)
    end
    return
  end

  if scr ~= nil and level == levels.TYPE_ERROR then
    if msg:find('El script fallo debido a') and scriptCrashInfos[scr.id] ~= nil then
      scriptCrashInfos[scr.id].crashed = true
    else
      scriptCrashInfos[scr.id] = {
        message = msg,
        crashed = false
      }
    end
  end
end

-- invoke onScriptCrashed if terminate was called due to script crash
function onScriptTerminate(scr, quit)
  if quit then return end

  if scriptCrashInfos[scr.id] ~= nil then
    if scriptCrashInfos[scr.id].crashed then
      onScriptCrashed(scr, scriptCrashInfos[scr.id].message)
    end
    scriptCrashInfos[scr.id] = nil
  end

  -- if scr == script.this then
  --   cfg.save(config)
  -- end
end

-- mark script as reloaded in last crashes if it was loaded
function onScriptLoad(scr)
  local path = scr.path
  if reloadLastCrashInfos[path] ~= nil then
    local v = reloadLastCrashInfos[path]
    v.reloaded = true
    Notifications.Show(v.name .. ':\nReloaded!', Notifications.TYPE.OK)
    reloadLastCrashInfos[path] = nil
  else
    for i, v in any_ipairs(lastCrashes) do
      if v.path == path then
        v.reloaded = true
      end
    end
  end
end

-- check for menu opening
function main()
  while true do
    if isWidgetSwipedLeft(WIDGET_RADAR) then
      windowState[0] = not windowState[0]
    end
    wait(0)
  end
end