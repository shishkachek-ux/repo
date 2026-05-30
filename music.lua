local speaker = peripheral.find("speaker")

if not speaker then
    print("Speaker not found")
    print("Place speaker near computer")
    return
end

local dfpwm = require("cc.audio.dfpwm")
local decoder = dfpwm.make_decoder()

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

local function playMusic(path)
    clear()

    print("Playing:")
    print(path)
    print("")
    print("Press Q to stop")

    local file = fs.open(musicFolder .. "/" .. path, "rb")

    while true do
        local chunk = file.read(16 * 1024)

        if not chunk then
            break
        end

        local buffer = decoder(chunk)

        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end

        local event = {os.pullEventRaw()}

        if event[1] == "key" and event[2] == keys.q then
            break
        end
    end

    file.close()

    sleep(1)
end

while true do
    clear()

    print("=== MUSIC PLAYER ===")
    print("")

    local files = getFiles()

    if #files == 0 then
        print("No music found")
        print("")
        print("Use:")
        print("wget URL music/song.dfpwm")

        os.pullEvent("key")
    else
        for i, file in ipairs(files) do
            print(i .. ". " .. file)
        end

        print("")
        print("Select music:")

        local input = read()
        local num = tonumber(input)

        if num and files[num] then
            playMusic(files[num])
        end
    end
end
