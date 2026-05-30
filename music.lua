-- CC Tweaked Music Player
-- Загружай .dfpwm файлы через wget и воспроизводи их

local speaker = peripheral.find("speaker")

if not speaker then
    print("Колонка не найдена!")
    print("Поставь speaker рядом с компьютером.")
    return
end

local decoder = require("cc.audio.dfpwm").make_decoder()

local musicFolder = "music"

if not fs.exists(musicFolder) then
    fs.makeDir(musicFolder)
end

local function clear()
    term.clear()
    term.setCursorPos(1,1)
end

local function getFiles()
    local files = fs.list(musicFolder)
    local result = {}

    for _, file in ipairs(files) do
        if file:match("%.dfpwm$") then
            table.insert(result, file)
        end
    end

    return result
end

local function play(fileName)
    clear()
    print("Сейчас играет:")
    print(fileName)
    print("")
    print("Q - остановить")

    local file = fs.open(musicFolder .. "/" .. fileName, "rb")

    while true do
        local chunk = file.read(16 * 1024)

        if not chunk then
            break
        end

        local buffer = decoder(chunk)

        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end

        if os.pullEventRaw then
            local event, key = os.pullEventRaw()

            if event == "key" and key == keys.q then
                file.close()
                return
            end
        end
    end

    file.close()

    print("")
    print("Трек закончился.")
    sleep(2)
end

while true do
    clear()

    print("=== MUSIC PLAYER ===")
    print("")

    local files = getFiles()

    if #files == 0 then
        print("Нет музыки.")
        print("")
        print("Загрузи файл так:")
        print('wget URL music/song.dfpwm')
        print("")
        print("Нажми любую клавишу.")
        os.pullEvent("key")
    else
        for i, file in ipairs(files) do
            print(i .. ". " .. file)
        end

        print("")
        print("Выбери номер трека:")
        local input = read()

        local id = tonumber(input)

        if id and files[id] then
            play(files[id])
        end
    end
end
