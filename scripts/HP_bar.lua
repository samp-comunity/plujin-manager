

-- Для автоматического включения скрипта измените значение переменной active ( ниже ) на 1, для автоматического выключения на 0


    active = 1






script_name("HPbar")
script_description("example of using drawBar function")
script_version_number(1)
script_version("v.001")
script_authors("hnnssy")

function main()
    if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
    local font = renderCreateFont("Arial", 12, 7)
    sampRegisterChatCommand("hp", activatecmd)
    sampAddChatMessage("[{FF0000}HP bar{FFFFFF}]: HP bar успешно загружен! Для вкл/выкл скрипта: {FF0000}/hp", -1)
    while true do
        wait(0)
        if not isPauseMenuActive() and isPlayerPlaying(playerHandle) then
          if active == 1 then
            local HP = getCharHealth(playerPed)
            local arm = getCharArmour(playerPed)
            local playerposX, playerposY, playerposZ = getCharCoordinates(playerPed)
            local screenX, screenY = convert3DCoordsToScreen(playerposX, playerposY, playerposZ)
            local screenYY = screenY + 30
            drawBar(screenX - 50, screenY, 100, 20, 0xBFDF0101, 0xBF610B0B, 2, font, HP)
            drawBar(screenX - 50, screenYY, 100, 20, -1, 0xBF610B0B, 2, font, arm)
        end
    end
end
end

function drawBar(posX, posY, sizeX, sizeY, color1, color2, borderThickness, font, value)
    renderDrawBoxWithBorder(posX, posY, sizeX, sizeY, color2, borderThickness, 0xFF000000)
    renderDrawBox(posX + borderThickness, posY + borderThickness, sizeX / 100 * value - (borderThickness * 2), sizeY - (2 * borderThickness), color1)
    local textLenght = renderGetFontDrawTextLength(font, tostring(value))
    local textHeight = renderGetFontDrawHeight(font)
    renderFontDrawText(font, tostring(value), posX + (sizeX / 2) - (textLenght / 2), posY + (sizeY / 2) - (textHeight / 2), 0xFFFFFFFF)
end

function activatecmd()
   if active == 0 then
       active = 1
   else
       active = 0
     end
end
