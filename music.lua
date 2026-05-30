-- Noisy Advanced Computer Music Player
-- Works WITHOUT speaker peripheral

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

    table.sort(result)

    return result
end

local function play(fileName)
    clear()

    print("Now Playing:")
    print(fileName)
    print("")
    print("Press Q to stop")

    local file = fs.open(musicFolder .. "/" .. fileName, "rb")

    if not file then
        print("Cannot open file")
        sleep(2)
        return
    end

    while true do
        local chunk = file.read(16 * 1024)

        if not chunk then
            break
        end

        local buffer = decoder(chunk)

        -- Noisy computers can play audio directly
        while not os.queueAudio(buffer) do
            os.pullEvent("audio_empty")
        end

        local event = {os.pullEvent()}

        if event[1] == "key" and event[2] == keys.q then
            break
        end
    end

    file.close()

    os.pullEvent("audio_empty")

    print("")
    print("Playback finished")
    sleep(1)
end

while true do
    clear()

    print("=== MUSIC PLAYER ===")
    print("")

    local files = getFiles()

    if #files == 0 then
        print("No music files found")
        print("")
        print("Download music with:")
        print("wget URL music/song.dfpwm")
        print("")
        print("Press any key")
        os.pullEvent("key")
    else
        for i, file in ipairs(files) do
            print(i .. ". " .. file)
        end

        print("")
        print("Select track number:")

        local input = read()
        local id = tonumber(input)

        if id and files[id] then
            play(files[id])
        end
    end
end
