local musicDir = "music"

local speakerSide = nil
for _, side in ipairs(rs.getSides()) do
  if peripheral.getType(side) == "speaker" then
    speakerSide = side
    break
  end
end

if not speakerSide then
  print("Не найден speaker рядом с компьютером!")
  return
end

local speaker = peripheral.wrap(speakerSide)

local function listTracks()
  if not fs.exists(musicDir) then
    print("Папка '" .. musicDir .. "' не найдена.")
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
  print("Папка: " .. musicDir)
  print("Управление: ↑/↓ - выбор, Enter - играть, S - стоп, Q - выход")
  print("Статус: " .. status)
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
    return "Файл не найден: " .. path
  end

  local h = fs.open(path, "rb")
  if not h then
    return "Не удалось открыть файл: " .. path
  end

  local dfpwm = require("cc.audio.dfpwm")
  local decoder = dfpwm.make_decoder()

  while true do
    local chunk = h.read(16 * 1024)
    if not chunk then break end
    local decoded = decoder(chunk)
    while not speaker.playAudio(decoded) do
      os.pullEvent("speaker_audio_empty")
    end
  end

  h.close()
  return "Воспроизведение завершено"
end

local function main()
  local tracks = listTracks()
  if #tracks == 0 then
    print("Нет треков в папке '" .. musicDir .. "'.")
    return
  end

  local currentIndex = 1
  local status = "Готов"

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
      status = "Играет: " .. tracks[currentIndex]
      drawUI(tracks, currentIndex, status)
      local msg = playTrack(tracks[currentIndex])
      status = msg
      drawUI(tracks, currentIndex, status)

    elseif key == keys.s then
      -- В CC:Tweaked нет глобального "stop", но можно сбросить спикер
      speaker.stop()
      status = "Остановлено"
      drawUI(tracks, currentIndex, status)

    elseif key == keys.q then
      term.clear()
      term.setCursorPos(1,1)
      print("Выход из плеера.")
      break
    end
  end
end

main()
