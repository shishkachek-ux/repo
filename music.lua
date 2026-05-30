local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then
    print("Speaker not found")
    return
end

local decoder = dfpwm.make_decoder()

local folder = "music"

if not fs.exists(folder) then
    fs.makeDir(folder)
end

local function clear()
    term.clear()
    term.setCursorPos(1,1)
end

local function getSongs()
    local files = fs.list(folder)
    local songs = {}

    for _, file in ipairs(files) do
        if file:match("%.dfpwm$") then
            table.insert(songs, file)
        end
    end

    return songs
end

local function play(song)
    clear()

    print("Playing:")
    print(song)
    print("")
    print("Hold CTRL+T to stop")

    for chunk in io.lines(folder .. "/" .. song, 16 * 1024) do
        local buffer = decoder(chunk)

        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end

    print("")
    print("Finished")
    sleep(1)
end

while true do
    clear()

    print("=== MUSIC PLAYER ===")
    print("")

    local songs = getSongs()

    if #songs == 0 then
        print("No music files")
        print("")
        print("Download with:")
        print("wget URL music/song.dfpwm")
        print("")
        os.pullEvent("key")
    else
        for i, song in ipairs(songs) do
            print(i .. ". " .. song)
        end

        print("")
        write("Select song: ")

        local input = tonumber(read())

        if input and songs[input] then
            play(songs[input])
        end
    end
end
