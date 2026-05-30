local musicDir = "music"

local speakerSide = nil
for _, side in ipairs(rs.getSides()) do
  if peripheral.getType(side) == "speaker" then
    speakerSide = side
    break
  end
end

if not speakerSide then
  print("Speaker not found next to the computer!")
  return
end

local speaker = peripheral.wrap(speakerSide)

local function listTracks()
  if not fs.exists(musicDir) then
    print("Folder '" .. musicDir .. "' not found.")
    return {}
  end

  local files = fs.list(musicDir)
  local tracks = {}
  for _, f in ipairs(files) do
    local path = fs.combine(musicDir, f)
    if not fs.isDir(path) then
      table.insert(tracks, f)
    end
  end
  return tracks
end

local function drawUI(tracks, currentIndex, status)
  term.clear()
  term.setCursorPos(1,1)
  print("=== MUSIC PLAYER ===")
  print("Folder: " .. musicDir)
  print("Controls: ↑/↓ - select, Enter - play, S - stop, Q - quit")
  print("Status: " .. status)
  print("")

  for i, name in ipairs(tracks) do
    if i == currentIndex then
      term.setTextColor(colors.yellow)
      print("> " .. name)
      term.setTextColor(colors.white)
    else
      print("  " .. name)
    end
  end
end

local function playTrack(filename)
    local path = fs.combine(musicDir, filename)
    if not fs.exists(path) then
        return "File not found: " .. path
    end

    local h = fs.open(path, "rb")
    local dfpwm = require("cc.audio.dfpwm")
    local decoder = dfpwm.make_decoder()

    local stopPlayback = false
    local paused = false

    -- file size for progress bar
    local fileSize = fs.getSize(path)
    local bytesRead = 0

    local function drawProgress()
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
                    drawProgress()

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

    return "Playback finished"
end


  h.close()
  return "Playback finished"
end

local function main()
  local tracks = listTracks()
  if #tracks == 0 then
    print("No tracks in folder '" .. musicDir .. "'.")
    return
  end

  local currentIndex = 1
  local status = "Ready"

  drawUI(tracks, currentIndex, status)

  while true do
    local event, key = os.pullEvent("key")

    if key == keys.up then
      if currentIndex > 1 then
        currentIndex = currentIndex - 1
      end
      drawUI(tracks, currentIndex, status)

    elseif key == keys.down then
      if currentIndex < #tracks then
        currentIndex = currentIndex + 1
      end
      drawUI(tracks, currentIndex, status)

    elseif key == keys.enter then
      status = "Playing: " .. tracks[currentIndex]
      drawUI(tracks, currentIndex, status)
      local msg = playTrack(tracks[currentIndex])
      status = msg
      drawUI(tracks, currentIndex, status)

    elseif key == keys.s then
      speaker.stop()
      status = "Stopped"
      drawUI(tracks, currentIndex, status)

    elseif key == keys.q then
      term.clear()
      term.setCursorPos(1,1)
      print("Exiting player.")
      break
    end
  end
end

main()
