
-- ===== CC CHAT =====

local w,h = term.getSize()

local friends = {}
local messages = {}
local selected = nil

local modem = peripheral.find("modem")
if modem then
    rednet.open(peripheral.getName(modem))
end

local speaker = peripheral.find("speaker")

local function saveFriends()
    local f = fs.open("friends.db","w")
    f.write(textutils.serialize(friends))
    f.close()
end

local function loadFriends()
    if fs.exists("friends.db") then
        local f = fs.open("friends.db","r")
        friends = textutils.unserialize(f.readAll()) or {}
        f.close()
    end
end

loadFriends()

local function beep()
    if speaker then
        speaker.playNote("bell", 1, 12)
    else
        pcall(function()
            term.setTextColor(colors.yellow)
            print("NEW MESSAGE!")
            term.setTextColor(colors.white)
        end)
    end
end

local function center(y,text,color)
    term.setCursorPos(math.floor((w-#text)/2), y)
    term.setTextColor(color or colors.white)
    write(text)
end

local function draw()
    term.setBackgroundColor(colors.black)
    term.clear()

    paintutils.drawFilledBox(1,1,18,h,colors.gray)

    term.setCursorPos(2,1)
    term.setTextColor(colors.cyan)
    write(" FRIENDS ")

    local y = 3

    for id,name in pairs(friends) do
        term.setCursorPos(2,y)

        if tonumber(id) == selected then
            term.setBackgroundColor(colors.lightBlue)
            term.setTextColor(colors.black)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.white)
        end

        write(name)

        term.setBackgroundColor(colors.black)

        y = y + 1
    end

    paintutils.drawLine(19,1,19,h,colors.lightGray)

    term.setCursorPos(22,1)
    term.setTextColor(colors.green)

    if selected then
        write("Chat with "..friends[tostring(selected)])
    else
        write("No chat selected")
    end

    local my = 3

    if selected and messages[selected] then
        for i,v in ipairs(messages[selected]) do
            if my < h-2 then
                term.setCursorPos(22,my)

                if v.mine then
                    term.setTextColor(colors.lime)
                    write("You: "..v.text)
                else
                    term.setTextColor(colors.white)
                    write(v.name..": "..v.text)
                end

                my = my + 1
            end
        end
    end

    term.setBackgroundColor(colors.gray)
    paintutils.drawFilledBox(20,h-1,w,h,colors.gray)

    term.setCursorPos(21,h)
    term.setTextColor(colors.black)
    write("Type message...")
end

local function addFriend()
    term.clear()

    center(2,"ADD FRIEND",colors.cyan)

    term.setCursorPos(2,5)
    write("Computer ID: ")
    local id = tonumber(read())

    term.setCursorPos(2,7)
    write("Name: ")
    local name = read()

    friends[tostring(id)] = name
    saveFriends()
end

local function sendMessage()
    if not selected then return end

    term.setCursorPos(21,h)
    term.clearLine()

    local msg = read()

    rednet.send(selected,{
        type="chat",
        text=msg,
        from=os.getComputerID()
    })

    messages[selected] = messages[selected] or {}

    table.insert(messages[selected],{
        mine=true,
        text=msg
    })
end

local function receiveLoop()
    while true do
        local id,msg = rednet.receive()

        if type(msg) == "table" and msg.type == "chat" then

            if not friends[tostring(id)] then
                friends[tostring(id)] = "PC "..id
            end

            messages[id] = messages[id] or {}

            table.insert(messages[id],{
                mine=false,
                text=msg.text,
                name=friends[tostring(id)]
            })

            beep()
            draw()
        end
    end
end

local function uiLoop()

    while true do
        draw()

        local e,b,x,y = os.pullEvent()

        if e == "mouse_click" then

            if x <= 18 then

                local cy = 3
                for id,name in pairs(friends) do
                    if y == cy then
                        selected = tonumber(id)
                    end
                    cy = cy + 1
                end
            end

            if y == h then
                sendMessage()
            end

        elseif e == "key" then

            if b == keys.f then
                addFriend()
            end

        end
    end
end

parallel.waitForAny(uiLoop,receiveLoop)

