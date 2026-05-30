local function playTrackOrFolder(name)
    local path = fs.combine(musicDir, name)

    -- check if folder
    local isDir = fs.isDir(path)

    local files = {}

    if isDir then
        -- list all files inside folder
        for _, f in ipairs(fs.list(path)) do
            local full = fs.combine(path, f)
            if not fs.isDir(full) then
                table.insert(files, full)
            end
        end
        table.sort(files)
    else
        files = { path }
    end

    local dfpwm = require("cc.audio.dfpwm")
    local decoder = dfpwm.make_decoder()

    local stopPlayback = false
    local paused = false

    local function drawProgress(bytesRead, fileSize)
        local width = 30
        local progress = bytesRead / fileSize
        local filled = math.floor(progress * width)

        term.setCursorPos(1, 10)
        term.clearLine()
        term.write("Progress: [")

        for i = 1, width do
            if i <= filled then
                term.write("#")
            else
                term.write("-")
            end
        end

        term.write("] " .. math.floor(progress * 100) .. "%")
    end

    for _, filePath in ipairs(files) do
        if stopPlayback then break end

        local h = fs.open(filePath, "rb")
        local fileSize = fs.getSize(filePath)
        local bytesRead = 0

        parallel.waitForAny(
            -- AUDIO THREAD
            function()
                while true do
                    if stopPlayback then break end

                    if paused then
                        sleep(0.1)
                    else
                        local chunk = h.read(16 * 1024)
                        if not chunk then break end

                        bytesRead = bytesRead + #chunk
                        drawProgress(bytesRead, fileSize)

                        local decoded = decoder(chunk)
                        while not speaker.playAudio(decoded) do
                            os.pullEvent("speaker_audio_empty")
                        end
                    end
                end
                h.close()
            end,

            -- KEYBOARD THREAD
            function()
                while true do
                    local event, key = os.pullEvent("key")

                    if key == keys.s then
                        stopPlayback = true
                        speaker.stop()
                        break
                    end

                    if key == keys.p then
                        paused = not paused
                        term.setCursorPos(1, 12)
                        term.clearLine()
                        if paused then
                            term.write("Status: PAUSED")
                        else
                            term.write("Status: PLAYING")
                        end
                    end
                end
            end
        )
    end

    return "Playback finished"
end
