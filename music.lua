-- ╔══════════════════════════════════════════════════╗
-- ║     CC Tweaked MIDI Player  v1.0                 ║
-- ║     Требует: Advanced Computer + Speakers        ║
-- ╚══════════════════════════════════════════════════╝
--
-- Установка:
--   1. Скопируй этот файл как /midi_player.lua на компьютер
--   2. Запусти: lua midi_player.lua
--   3. Или переименуй в startup.lua для автозапуска
--
-- Нужны динамики, подключённые к компьютеру (любая сторона).
-- Чем больше динамиков — тем больше нот одновременно.

-- ─── Конфигурация ────────────────────────────────────────────────────────────
local SERVER_URL = "ws://192.168.1.100:8765"  -- ИЗМЕНИ НА СВОЙ IP
local SPEAKER_SIDES = {"left", "right", "top", "bottom", "front", "back"}
-- ─────────────────────────────────────────────────────────────────────────────

-- ─── Состояние ───────────────────────────────────────────────────────────────
local state = {
    screen       = "menu",   -- menu | loading | playing | paused | error
    files        = {},
    selected     = 1,
    song         = nil,      -- {title, duration, count}
    events       = {},       -- все ноты
    ws           = nil,
    playing      = false,
    paused       = false,
    start_time   = 0,
    pause_offset = 0,
    event_idx    = 1,
    volume       = 1.0,
    chunks_recv  = 0,
    chunks_total = 0,
    error_msg    = "",
    scroll       = 0,        -- прокрутка списка
}

-- ─── Динамики ────────────────────────────────────────────────────────────────
local speakers = {}

local function find_speakers()
    speakers = {}
    for _, side in ipairs(SPEAKER_SIDES) do
        if peripheral.isPresent(side) and peripheral.getType(side) == "speaker" then
            table.insert(speakers, peripheral.wrap(side))
        end
    end
    -- Также ищем networked speakers
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "speaker" then
            local already = false
            for _, sp in ipairs(speakers) do if sp == peripheral.wrap(name) then already = true end end
            if not already then
                table.insert(speakers, peripheral.wrap(name))
            end
        end
    end
    return #speakers
end

local speaker_idx = 1
local function play_note(instrument, note, volume)
    if #speakers == 0 then return end
    local sp = speakers[speaker_idx]
    speaker_idx = (speaker_idx % #speakers) + 1
    -- pcall на случай переполнения буфера динамика
    local ok, err = pcall(function()
        sp.playNote(instrument, math.floor(volume * state.volume * 3), note)
    end)
    if not ok and err and err:find("Too many notes") then
        -- Пробуем другой динамик
        for i = 1, #speakers do
            local ok2 = pcall(function()
                speakers[i].playNote(instrument, math.floor(volume * state.volume * 3), note)
            end)
            if ok2 then return end
        end
    end
end

-- ─── Отрисовка ───────────────────────────────────────────────────────────────
local W, H = term.getSize()

local function cls()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
end

local function set_color(fg, bg)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
end

local function write_at(x, y, text, fg, bg)
    set_color(fg or colors.white, bg or colors.black)
    term.setCursorPos(x, y)
    term.write(text)
end

local function fill_line(y, char, fg, bg)
    write_at(1, y, string.rep(char or " ", W), fg, bg)
end

local function center(y, text, fg, bg)
    local x = math.floor((W - #text) / 2) + 1
    write_at(x, y, text, fg, bg)
end

local function draw_header()
    fill_line(1, " ", colors.black, colors.cyan)
    center(1, " CC MIDI Player ", colors.black, colors.cyan)
    local spk_txt = "Speakers: " .. #speakers
    write_at(W - #spk_txt, 1, spk_txt, colors.black, colors.cyan)
end

local function draw_footer(hints)
    fill_line(H, " ", colors.black, colors.gray)
    write_at(2, H, hints, colors.white, colors.gray)
end

local function format_time(secs)
    secs = math.floor(secs)
    return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end

local function progress_bar(x, y, width, val, max_val, fg, bg)
    local filled = max_val > 0 and math.floor(val / max_val * width) or 0
    filled = math.min(filled, width)
    set_color(fg or colors.lime, bg or colors.gray)
    term.setCursorPos(x, y)
    term.write(string.rep("\127", filled))
    set_color(colors.gray, bg or colors.gray)
    term.write(string.rep("\127", width - filled))
end

-- ─── Экраны ──────────────────────────────────────────────────────────────────

local function draw_menu()
    cls()
    draw_header()
    
    if #state.files == 0 then
        center(math.floor(H / 2), "Нет файлов на сервере", colors.gray)
        center(math.floor(H / 2) + 1, "Положите .mid в папку midi/", colors.lightGray)
        draw_footer("[R] Обновить  [Q] Выход")
        return
    end
    
    write_at(2, 2, "Выберите трек:", colors.lightGray)
    
    local list_h = H - 4  -- строки для списка
    local max_scroll = math.max(0, #state.files - list_h)
    state.scroll = math.min(math.max(state.scroll, state.selected - list_h), state.selected - 1)
    state.scroll = math.max(0, math.min(state.scroll, max_scroll))
    
    for i = 1, list_h do
        local idx = i + state.scroll
        if idx > #state.files then break end
        local f = state.files[idx]
        local y = i + 2
        
        if idx == state.selected then
            fill_line(y, " ", colors.black, colors.cyan)
            write_at(2, y, "► " .. f.name, colors.black, colors.cyan)
        else
            fill_line(y, " ", colors.white, colors.black)
            write_at(2, y, "  " .. f.name, colors.white, colors.black)
        end
    end
    
    -- Скроллбар
    if #state.files > list_h then
        local bar_y = 3 + math.floor(state.scroll / max_scroll * (list_h - 1))
        write_at(W, bar_y, "\x16", colors.gray, colors.black)
    end
    
    draw_footer("[Up/Down] Выбор  [Enter] Играть  [R] Обновить  [Q] Выход")
end

local function draw_loading()
    cls()
    draw_header()
    
    local title = state.song and state.song.title or "..."
    center(4, "Загрузка:", colors.lightGray)
    center(5, title, colors.white)
    
    if state.chunks_total > 0 then
        local pct = math.floor(state.chunks_recv / state.chunks_total * 100)
        center(7, "Получено нот: " .. (state.chunks_recv * 200) .. " / загружается...", colors.gray)
        progress_bar(4, 9, W - 6, state.chunks_recv, state.chunks_total, colors.lime, colors.gray)
        center(11, pct .. "%", colors.lime)
    else
        center(7, "Ожидание данных...", colors.gray)
    end
    
    draw_footer("[Q] Отмена")
end

local function draw_player()
    cls()
    draw_header()
    
    local song = state.song
    if not song then return end
    
    -- Название
    center(3, song.title, colors.white)
    
    -- Время
    local elapsed = 0
    if state.playing and not state.paused then
        elapsed = os.clock() - state.start_time + state.pause_offset
    else
        elapsed = state.pause_offset
    end
    elapsed = math.min(elapsed, song.duration)
    
    local time_str = format_time(elapsed) .. " / " .. format_time(song.duration)
    center(5, time_str, colors.lightGray)
    
    -- Прогресс-бар
    progress_bar(4, 7, W - 6, elapsed, song.duration, colors.cyan, colors.gray)
    
    -- Статус
    local status_icon = state.paused and "|| ПАУЗА" or (state.playing and "> ИГРАЕТ" or "  СТОП")
    center(9, status_icon, state.paused and colors.yellow or colors.lime)
    
    -- Ноты сыграно
    local played = math.max(0, state.event_idx - 1)
    center(10, "Нот: " .. played .. " / " .. song.count, colors.gray)
    
    -- Громкость
    local vol_bar = math.floor(state.volume * 10)
    local vol_str = "Громкость: [" .. string.rep("|", vol_bar) .. string.rep(".", 10 - vol_bar) .. "]"
    center(12, vol_str, colors.lightGray)
    
    -- Динамики
    center(13, "Динамиков: " .. #speakers, colors.gray)
    
    -- Подсказки
    if state.paused then
        draw_footer("[Space] Продолжить  [S] Стоп  [-/+] Громкость  [Q] Выход")
    else
        draw_footer("[Space] Пауза  [S] Стоп  [-/+] Громкость  [Q] Выход")
    end
end

local function draw_error()
    cls()
    draw_header()
    center(5, "Ошибка!", colors.red)
    center(7, state.error_msg, colors.white)
    draw_footer("[Any] Назад")
end

local function redraw()
    local s = state.screen
    if s == "menu" then draw_menu()
    elseif s == "loading" then draw_loading()
    elseif s == "playing" then draw_player()
    elseif s == "error" then draw_error()
    end
    term.setCursorPos(1, 1)
end

-- ─── Сеть ────────────────────────────────────────────────────────────────────

local function ws_send(data)
    if state.ws then
        state.ws.send(textutils.serialiseJSON(data))
    end
end

local function connect()
    local ws, err = http.websocket(SERVER_URL)
    if not ws then
        return nil, err or "не удалось подключиться"
    end
    return ws
end

local function request_list()
    ws_send({cmd = "list"})
end

local function request_song(id)
    state.events = {}
    state.chunks_recv = 0
    state.chunks_total = 0
    state.screen = "loading"
    redraw()
    ws_send({cmd = "load", id = id})
end

-- ─── Плеер ───────────────────────────────────────────────────────────────────

local function stop_playing()
    state.playing = false
    state.paused  = false
    state.pause_offset = 0
    state.event_idx = 1
    state.start_time = 0
end

local function start_playing()
    if #state.events == 0 then return end
    state.playing      = true
    state.paused       = false
    state.event_idx    = 1
    state.pause_offset = 0
    state.start_time   = os.clock()
end

local function pause_resume()
    if not state.playing then return end
    if state.paused then
        -- Возобновляем
        state.start_time = os.clock() - state.pause_offset
        state.paused = false
    else
        -- Ставим на паузу
        state.pause_offset = os.clock() - state.start_time
        state.paused = true
    end
end

-- Вызывается в главном цикле каждый тик для воспроизведения нот
local function tick_player()
    if not state.playing or state.paused then return end
    if state.event_idx > #state.events then
        -- Песня закончилась
        state.playing = false
        state.screen  = "menu"
        redraw()
        return
    end
    
    local now = os.clock() - state.start_time + state.pause_offset
    
    -- Играем все ноты, которые пора было сыграть
    while state.event_idx <= #state.events do
        local ev = state.events[state.event_idx]
        if ev.t > now then break end
        play_note(ev.i, ev.n, ev.v)
        state.event_idx = state.event_idx + 1
    end
end

-- ─── Главный цикл ────────────────────────────────────────────────────────────

local function handle_ws_message(raw)
    local ok, msg = pcall(textutils.unserialiseJSON, raw)
    if not ok or not msg then return end
    
    local cmd = msg.cmd
    
    if cmd == "list" then
        state.files = msg.files or {}
        state.selected = 1
        state.screen = "menu"
        redraw()
    
    elseif cmd == "song_info" then
        state.song = {
            title    = msg.title or "Неизвестно",
            duration = msg.duration or 0,
            count    = msg.count or 0,
        }
        state.chunks_total = msg.chunks or 1
        redraw()
    
    elseif cmd == "notes" then
        state.chunks_recv = (msg.chunk or 0) + 1
        for _, ev in ipairs(msg.events or {}) do
            table.insert(state.events, ev)
        end
        redraw()
    
    elseif cmd == "ready" then
        state.screen = "playing"
        start_playing()
        redraw()
    
    elseif cmd == "pong" then
        -- keep-alive ответ
    
    elseif msg.error then
        state.error_msg = msg.error
        state.screen = "error"
        redraw()
    end
end

local function handle_key(key)
    local s = state.screen
    
    if s == "error" then
        state.screen = "menu"
        redraw()
        return
    end
    
    if s == "menu" then
        if key == keys.up then
            state.selected = math.max(1, state.selected - 1)
            redraw()
        elseif key == keys.down then
            state.selected = math.min(#state.files, state.selected + 1)
            redraw()
        elseif key == keys.enter then
            if #state.files > 0 then
                request_song(state.selected - 1)
            end
        elseif key == keys.r then
            request_list()
        elseif key == keys.q then
            return "quit"
        end
    
    elseif s == "loading" then
        if key == keys.q then
            state.screen = "menu"
            stop_playing()
            redraw()
        end
    
    elseif s == "playing" then
        if key == keys.space then
            pause_resume()
            redraw()
        elseif key == keys.s then
            stop_playing()
            state.screen = "menu"
            redraw()
        elseif key == keys.minus or key == keys.leftBracket then
            state.volume = math.max(0.1, state.volume - 0.1)
            redraw()
        elseif key == keys.equals or key == keys.rightBracket then
            state.volume = math.min(1.0, state.volume + 0.1)
            redraw()
        elseif key == keys.q then
            stop_playing()
            state.screen = "menu"
            redraw()
        end
    end
end

local function main()
    -- Проверяем HTTP
    if not http then
        term.setTextColor(colors.red)
        print("Ошибка: HTTP/WebSocket не включён!")
        print("Добавьте в конфиг: http_enable = true")
        return
    end
    
    -- Ищем динамики
    find_speakers()
    
    -- Подключаемся
    cls()
    center(5, "Подключение к серверу...", colors.lightGray)
    center(6, SERVER_URL, colors.gray)
    
    local ws, err = connect()
    if not ws then
        cls()
        term.setTextColor(colors.red)
        center(5, "Ошибка подключения:", colors.red)
        center(6, tostring(err), colors.white)
        center(8, "Проверь SERVER_URL в начале файла", colors.gray)
        return
    end
    state.ws = ws
    
    -- Запрашиваем список
    request_list()
    
    -- Таймер для keep-alive и обновления плеера
    local last_ping   = os.clock()
    local last_draw   = os.clock()
    local PING_INTERVAL = 10
    local DRAW_INTERVAL = 0.1
    
    while true do
        -- Проверяем входящие WS сообщения (неблокирующий режим)
        local raw = ws.receive(0)  -- 0 = не ждать
        if raw then
            handle_ws_message(raw)
        end
        
        -- Тикаем плеер (воспроизводим ноты)
        tick_player()
        
        -- Обновляем экран плеера не чаще чем раз в 0.1 сек
        if state.screen == "playing" and (os.clock() - last_draw) >= DRAW_INTERVAL then
            draw_player()
            last_draw = os.clock()
        end
        
        -- Keep-alive пинг
        if (os.clock() - last_ping) >= PING_INTERVAL then
            ws_send({cmd = "ping"})
            last_ping = os.clock()
        end
        
        -- Обрабатываем клавиши (неблокирующий)
        local ev, p1 = os.pullEventRaw("key")
        if ev == "terminate" then break end
        if ev == "key" then
            local result = handle_key(p1)
            if result == "quit" then break end
        end
        
        -- Небольшой sleep чтобы не жрать CPU
        os.sleep(0.05)
    end
    
    ws.close()
    cls()
    term.setTextColor(colors.white)
    print("До свидания!")
end

-- Запуск
local ok, err = pcall(main)
if not ok then
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.red)
    print("\nНепредвиденная ошибка:")
    term.setTextColor(colors.white)
    print(tostring(err))
end
