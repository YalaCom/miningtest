require("moonloader")
local sampev = require("samp.events")
local imgui = require("imgui")
local encoding = require('encoding')
encoding.default =('CP1251')
local u8 = encoding.UTF8

-- MiningStats compatibility bridge.
local __msStatsLockPath = getWorkingDirectory() .. '\\MiningStatsInterop.lock'
local __msBusyLockPath = getWorkingDirectory() .. '\\MiningToolFixed_AllHouses.busy'
local __msBusyWritten = false
local __msBusySecond = -1

local function __msReadFreshLock(path, ttl)
    local f = io.open(path, 'r')
    if not f then return false end
    local stamp = tonumber(f:read('*l') or '')
    f:close()
    if not stamp then
        pcall(os.remove, path)
        return false
    end
    local age = os.time() - stamp
    if age >= 0 and age <= (ttl or 4) then return true end
    pcall(os.remove, path)
    return false
end

local function __msStatsBusy()
    return __msReadFreshLock(__msStatsLockPath, 4)
end

local function __msClearBusyLock()
    pcall(os.remove, __msBusyLockPath)
    __msBusyWritten = false
    __msBusySecond = -1
end

local function __msUpdateBusyLock(active, force)
    if not active then
        if __msBusyWritten then __msClearBusyLock() end
        return
    end
    local now = os.time()
    if not force and __msBusyWritten and __msBusySecond == now then return end
    local f = io.open(__msBusyLockPath, 'w')
    if f then
        f:write(tostring(now), '\n')
        f:close()
        __msBusyWritten = true
        __msBusySecond = now
    end
end

if sampev.INTERFACE.INCOMING_RPCS[61][2]['dialogId'] == 'uint16' then
    print('normal sampev, patched.')
    
    sampev.INTERFACE.INCOMING_RPCS[61] = {
        'onShowDialog',
        {dialogId = 'uint16'},
        {style = 'uint8'},
        {title = 'string8'},
        {button1 = 'string8'},
        {button2 = 'string8'},
        {text = 'encodedString4096'},
        {placeholder = 'string8'}
    }
else
    print('old sampev, skip patch onShowDialog')
end
  
local themes = {
    {name='Графит', bg='18191b', panel='222427', frame='33363a', hover='554334', ink='f8f3ed', quiet='beb8ae', accent='efac76'},
    {name='Фарфор', bg='e9e8e3', panel='faf9f6', frame='dcdedc', hover='c4d0dd', ink='18232d', quiet='485664', accent='27569a'},
    {name='Нефрит', bg='101e1a', panel='172a23', frame='233e32', hover='355543', ink='eff8ef', quiet='a8c3b1', accent='91d9af'}
}
local function color(hex)
    return imgui.ImVec4(tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255, 1)
end
local function applyTheme(index)
    imgui.SwitchContext()
    local style, t = imgui.GetStyle(), themes[index]
    local groups = {
        bg={'WindowBg','ScrollbarBg'}, panel={'ChildWindowBg','PopupBg','TitleBg','TitleBgActive'},
        frame={'FrameBg','Button','Header','Separator','Border','ScrollbarGrab'},
        hover={'FrameBgHovered','FrameBgActive','ButtonHovered','ButtonActive','HeaderHovered','HeaderActive','ScrollbarGrabHovered'},
        ink={'Text'}, quiet={'TextDisabled'}, accent={'CheckMark','SliderGrab','SliderGrabActive','ScrollbarGrabActive'}
    }
    for key, roles in pairs(groups) do
        t[key..'Color'] = color(t[key])
        for _, role in ipairs(roles) do style.Colors[imgui.Col[role]] = t[key..'Color'] end
    end
    style.WindowPadding = imgui.ImVec2(12,12)
    style.FramePadding = imgui.ImVec2(8,5)
    style.ItemSpacing = imgui.ImVec2(8,6)
    style.WindowRounding, style.ChildWindowRounding, style.FrameRounding = 7,5,4
    style.ScrollbarSize, style.GrabRounding = 10,3
end
do
    Jcfg = {
        _version = 0.1,
        _author = "JustFedot",
        _telegram = "@justfedot",
        _help = [[
            Jcfg - модуль для сохранения и загрузки конфигурационных файлов в Lua, используя формат JSON, с поддержкой конфигурации для ImGui.
            Важно: модуль должен быть подключен после всех необходимых `require`.
        
            Использование:
                - Инициализация модуля:
                    jcfg = Jcfg()
        
                - Сохранение массива в файл:
                    jcfg.save(table, path)
                    - table: массив, который нужно сохранить.
                    - path: путь для сохранения. Если не указан, сохранение будет в moonloader/config/Имя_скрипта/config.json
        
                - Загрузка массива из файла:
                    table = jcfg.load(path)
                    - table: переменная, в которую будет загружен массив.
                    - path: путь к файлу для загрузки. Если не указан, будет искать в moonloader/config/Имя_скрипта/config.json
        
                - Обновление массива данными из файла:
                    jcfg.update(table, path)
                    - table: массив, который нужно обновить данными из файла.
                    - path: путь к файлу для загрузки. Если не указан, будет искать в moonloader/config/Имя_скрипта/config.json
        
                - Настройка массива для использования с ImGui:
                    imtable = jcfg.setupImgui(table)
                    - table: массив, который будет преобразован для использования с ImGui.
                    - imtable: возвращает массив, готовый к использованию с ImGui.
        
            Пример использования:
        
                -- Инициализация модуля
                local jcfg = Jcfg()
        
                -- Создание конфигурации
                local cfg = {
                    params = {'123'},
                    param = 12
                }
        
                -- Обновление конфигурации данными из файла (если файл существует)
                jcfg.update(cfg)
        
                -- Настройка конфигурации для использования с ImGui
                local imcfg = jcfg.setupImgui(cfg)
        
                -- Сохранение конфигурации в файл
                jcfg.save(cfg)
        ]]                      
    }

    function Jcfg.__init()
        local self = {}

        local json = require('dkjson')

        local function makeDirectory(path)
            assert(type(path) == "string" and path:find('moonloader'), "Path must be a string and include 'moonloader' folder")
            
            path = path:gsub("[\\/][^\\/]+%.json$", "")

            if not doesDirectoryExist(path) then
                if not createDirectory(path) then
                    return error("Failed to create directory: " .. path)
                end
            end
        end        

        local function setupImguiConfig(table)
            assert(type(table) == "table", ("bad argument #1 to 'setupImgui' (table expected, got %s)"):format(type(table)))
            local function setupImguiConfigRecursive(table)
                local imcfg = {}
                for k, v in pairs(table) do
                    if type(v) == "table" then
                        imcfg[k] = setupImguiConfigRecursive(v)
                    elseif type(v) == "number" then
                        if v % 1 == 0 then
                            imcfg[k] = imgui.ImInt(v)
                        else
                            imcfg[k] = imgui.ImFloat(v)
                        end
                    elseif type(v) == "string" then
                        imcfg[k] = imgui.ImBuffer(256)
                        imcfg[k].v = u8(v)
                    elseif type(v) == "boolean" then
                        imcfg[k] = imgui.ImBool(v)
                    else
                        error(("Unsupported type for imguiConfig: %s"):format(type(v)))
                    end
                end
                return imcfg
            end
            return setupImguiConfigRecursive(table)
        end
        ----------------------------------------------------------------

        function self.save(table, path)
            assert(type(table)=="table", ("bad argument #1 to 'save' (table expected, got %s)"):format(type(table)))
            assert(path == nil or type(path) == "string", "Path must be nil or a valid file path.")
            if path then
                path = path:find('%.json$') and path or path..'.json'
            else
                assert(thisScript().name, "Script name is not defined")
                path = getWorkingDirectory()..'\\config\\'..thisScript().name..'\\config.json'
            end
            makeDirectory(path)
            local file = io.open(path,"w")
            if file then
                file:write(json.encode(table, {indent = true}))
                file:close()
            else
                error("Could not open file for writing: " .. path)
            end
        end

        function self.load(path)
            assert(path == nil or type(path) == "string", "Path must be nil or a valid file path.")
            if path then
                path = path:find('%.json$') and path or path..'.json'
			else
				path = getWorkingDirectory()..'\\config\\'..thisScript().name..'\\config.json'
			end
            if doesFileExist(path) then
                local file = io.open(path, "r")
                if file then
                    local content = file:read("*all")
                    file:close()
                    return json.decode(content)
                else
                    return error("Could not load configuration")
                end
            else
                return {}
            end
        end

        function self.update(table, path)
            assert(type(table)=="table", ("bad argument #1 to 'update' (table expected, got %s)"):format(type(table)))
            assert(path == nil or (type(path) == "string" and path:match("^.+%.json$")), "Path must be nil or a valid file path ending with '.json'")
            local loadedCfg = self.load(path)
			
			if loadedCfg then
				for k, v in pairs(table) do
					if loadedCfg[k] ~= nil then
						table[k] = loadedCfg[k]
					end
				end
			end

            return true
        end

        function self.setupImgui(table)
            assert(imgui ~= nil, "The imgui library is not loaded. Please ensure it is required before using 'setupImgui' function.")
            return setupImguiConfig(table)
        end

        return self
    end

    setmetatable(Jcfg, {
        __call = function(self)
            return self.__init()
        end
    })
end
local jcfg = Jcfg()

local cfg = {
    on = true,
    coolantPercents = 50,
    multiply = 1,
    theme = 1
}
local configRoot = getWorkingDirectory()..'\\config\\'
if not doesFileExist(configRoot..'MiningMAX\\config.json') then
    jcfg.update(cfg, configRoot..'[JF, F] Mining Tools [Fixed]\\config.json')
end
jcfg.update(cfg)
if not themes[cfg.theme] then cfg.theme = 1 end
applyTheme(cfg.theme)
local imcfg = jcfg.setupImgui(cfg)
function save()
    jcfg.save(cfg)
end

local utils = (function()
    local self = {}

    local function cyrillic(text)
        local convtbl = {[230]=155,[231]=159,[247]=164,[234]=107,[250]=144,[251]=168,[254]=171,[253]=170,[255]=172,[224]=97,[240]=112,[241]=99,[226]=162,[228]=154,[225]=151,[227]=153,[248]=165,[243]=121,[184]=101,[235]=158,[238]=111,[245]=120,[233]=157,[242]=166,[239]=163,[244]=63,[237]=174,[229]=101,[246]=36,[236]=175,[232]=156,[249]=161,[252]=169,[215]=141,[202]=75,[204]=77,[220]=146,[221]=147,[222]=148,[192]=65,[193]=128,[209]=67,[194]=139,[195]=130,[197]=69,[206]=79,[213]=88,[168]=69,[223]=149,[207]=140,[203]=135,[201]=133,[199]=136,[196]=131,[208]=80,[200]=133,[198]=132,[210]=143,[211]=89,[216]=142,[212]=129,[214]=137,[205]=72,[217]=138,[218]=167,[219]=145}
        local result = {}
        for i = 1, #text do
            local c = text:byte(i)
            result[i] = string.char(convtbl[c] or c)
        end
        return table.concat(result)
    end

    local function roundUpToThreeDecimalPlaces(num)
        local mult = 10^3
        return math.ceil(num * mult) / mult
    end

    --------------------------------------------------------------------------------------------------------------------------------

    function self.addChat(a)
        if a then local a_type = type(a) if a_type == 'number' then a = tostring(a) elseif a_type ~= 'string' then return end else return end
        sampAddChatMessage('{ffa500}'..thisScript().name..'{ffffff}: '..a, -1)
    end

    function self.printStringNow(text, time)
        if not text then return end
        time = time or 100
        text = type(text) == "number" and tostring(text) or text
        if type(text) ~= 'string' then return end
        printStringNow(cyrillic(text), time)
    end

    function self.getVideocardEarnings(level)
        -- local earningsTable = {
        --     0.0327855,  -- 1 лвл
        --     0.06557125, -- 2 лвл
        --     0.09835675, -- 3 лвл
        --     0.13114275, -- 4 лвл
        --     0.1639285,  -- 5 лвл
        --     0.19671425, -- 6 лвл
        --     0.22949975, -- 7 лвл
        --     0.2622855,  -- 8 лвл
        --     0.2950715,  -- 9 лвл
        --     0.327857    -- 10 лвл
        -- }
        local earningsTable = {
            0.021858,  -- 1 лвл
            0.043716, -- 2 лвл
            0.065568, -- 3 лвл
            0.087432, -- 4 лвл
            0.109284,  -- 5 лвл
            0.131142, -- 6 лвл
            0.153, -- 7 лвл
            0.174858,  -- 8 лвл
            0.196716,  -- 9 лвл
            0.218568    -- 10 лвл
        }

        local mult = cfg.multiply == 1 and 1 or cfg.multiply == 2 and 1.5 or cfg.multiply == 3 and 2

        if earningsTable[level] then
            return roundUpToThreeDecimalPlaces(earningsTable[level] * mult * 1.22)
            --return earningsTable[level]*1.15
        else
            return 0
        end
    end

    function self.calculateRemainingHours(percent)
        local consumptionPerHour = 0.48
        local remainingHours = percent / consumptionPerHour
        return remainingHours
    end    

    return self
end)()

local work = {
    on = false,
    mode = 1,
    needSkip = false,
    videocardMode = ""
}

local imgui_windows = {
    main = imgui.ImBool(false),
    dialog = imgui.ImBool(false)
}

local json_timer = {false, os.clock(), 0, 0, 0, ''}

function main()
    repeat wait(0) until isSampAvailable()
    while not isSampLoaded() do wait(0) end
    __msClearBusyLock()

    local ok, registered = pcall(sampRegisterChatCommand, 'jmnt', function()
        cfg.on = not cfg.on
        local text = cfg.on and "Скрипт {99ff99}включен{ffffff}." or "Скрипт {ff0000}отключен{ffffff}."
        utils.addChat(text)
        save()
    end)
    if not ok or registered == false then
        utils.addChat('{ff9999}Не загружен: команда /jmnt недоступна. @exquown')
        print(tostring(registered))
        return
    end
    utils.addChat('{99ff99}Загружен{ffffff} | @exquown | /jmnt'..(cfg.on and '' or ' | обработка отключена'))
    

    while true do wait(0)
        __msUpdateBusyLock(work.on, false)
        imgui.Process = imgui_windows.dialog.v
        
        if json_timer[1] then
            if json_timer[2] + 0.125 <= os.clock() then
                json_timer[2] = os.clock()
                json_timer[1] = false
                sampSendDialogResponse(json_timer[3], json_timer[4], json_timer[5], json_timer[6])
            end
        end
    end
end

local __imDialogData = {
    id = 25565,
    title = "Dialog",
    videocards = {},
    selectedVideocard = -1
}

local allHouses = {
    active = false,
    mode = 0,
    currentHouse = nil,
    awaitingHouseList = false,
    visited = {}
}

local getHouseNumber, finishAllHouses, goToHouseList
local cryptoAnalysys

local workLauncher = (function()
    local self = {}

    local checkers = {
        [1] = function(v) -- checkVideocardStatus
            if work.mode == 3 then
                if v[2]:find("{F78181}На паузе") and tonumber(v[2]:match("(%d+%.%d+)%%?%s*$")) > 0 then
                    return true
                else
                    return false
                end
            else
                return v[2]:find("{BEF781}Работает") and true or false
            end
        end,
        
        [2] = function(v) -- checkProfit
            return tonumber(v[2]:match("(%d+)%.%d%d%d%d%d%d")) > 0
        end,

        [3] = function(v) -- checkCoolant
            return tonumber(v[2]:match("(%d+%.%d+)%%?%s*$")) <= cfg.coolantPercents
        end
    }

    function self.handleVideocardAction(mode, checkFunction, successMessage)
        work.on = true
        __msUpdateBusyLock(true, true)
        work.mode = mode
        work.needSkip = false
        for k, v in pairs(__imDialogData.videocards) do
            if checkers[checkFunction](v) then
                sampSendDialogResponsed(__imDialogData.id, 1, v[1])
                return
            end
        end
        if allHouses.active and allHouses.mode == mode then
            goToHouseList(__imDialogData.id, __imDialogData.title)
            return
        end
        work.on = false
        utils.addChat(successMessage)
    end

    return self
end)()

local tab, art, changed = 1, nil, 0
local tabs = {'Обзор','Действия','Настройки'}
local vec = imgui.ImVec2
local function banner(t)
    local width = imgui.GetContentRegionAvail().x
    local height = math.min(130, width / 3)
    local p = imgui.GetCursorScreenPos()
    if art == nil then
        local ok, tex = pcall(imgui.CreateTextureFromFile, getWorkingDirectory() .. '\\MiningMAX\\hardware.jpg')
        art = ok and tex or false
        if not art then print('[MiningMAX] hardware.jpg: texture unavailable') end
    end
    local time = math.min(1, (os.clock()-changed)/0.45)
    local ease = 1-(1-time)^3
    if art then
        local delta = 0.018*(1-ease)
        local cx = cfg.theme == 1 and 0.5+delta or 0.5
        local span = 0.46 - (cfg.theme == 2 and delta or 0)
        local sy = height/width * span
        local cy = (cfg.theme-0.5)/3 + (cfg.theme == 3 and delta*0.5 or 0)
        imgui.Image(art,vec(width,height),vec(cx-span,cy-sy),vec(cx+span,cy+sy))
    else
        imgui.Dummy(vec(width,height))
    end
    imgui.GetWindowDrawList():AddLine(vec(p.x,p.y+height-1),vec(p.x+width*ease,p.y+height-1),imgui.GetColorU32(t.accentColor),2)
end

local function metric(label, value, t)
    imgui.TextColored(t.quietColor,u8(label))
    imgui.SameLine()
    imgui.TextUnformatted(u8(value))
end

function imgui.OnDrawFrame()
    if not imgui_windows.dialog.v then return end
    local w,h = getScreenResolution()
    local width,height = math.min(1060,w-16),math.min(670,h-16)
    local t = themes[cfg.theme]
    imgui.SetNextWindowSize(vec(width,height))
    imgui.SetNextWindowPos(vec((w-width)/2,(h-height)/2))
    imgui.Begin('##MiningMAX',imgui_windows.dialog,imgui.WindowFlags.NoTitleBar+imgui.WindowFlags.NoResize+imgui.WindowFlags.NoMove)
    imgui.SetWindowFontScale(1.45)
    imgui.TextUnformatted('MiningMAX')
    imgui.SetWindowFontScale(1)
    imgui.SameLine()
    if imgui.Link('@exquown',u8'Открыть Telegram') then os.execute('explorer.exe "https://t.me/exquown"') end
    imgui.SameLine()
    imgui.SetCursorPosX(width-50)
    if imgui.Button('X##close',vec(34,24)) and not work.on then __closeWindow(true) end
    imgui.Separator()
    imgui.BeginChild('##cards',vec(math.floor((width-32)*0.49),0),true)
    banner(t)
    imgui.TextUnformatted(u8((__imDialogData.title:gsub('{%x%x%x%x%x%x}',''))))
    local cards = __imDialogData.videocards
    local hourly, available = {BTC=0,ASC=0}, {BTC=0,ASC=0}
    local minimum, attention = nil,false
    imgui.BeginChild('##list',vec(0,-38),false)
    for i,v in ipairs(cards) do
        local line = v[2]:gsub('{%x%x%x%x%x%x}','')
        local level = tonumber(line:match('(%d+) уровень'))
        local coolant = tonumber(line:match('(%d+%.%d+)%%'))
        local amount,coin = line:match('(%d+%.%d+)%s+([AB][ST][CC])')
        local rate = utils.getVideocardEarnings(level)
        local paused = line:find('На паузе',1,true)
        attention = attention or paused or (coolant and coolant <= cfg.coolantPercents)
        if coolant then minimum = math.min(minimum or coolant,coolant) end
        if coin and hourly[coin] then
            hourly[coin] = hourly[coin] + rate
            available[coin] = available[coin] + math.floor(tonumber(amount))
        end
        local pos = imgui.GetCursorScreenPos()
        local selected = __imDialogData.selectedVideocard == v[1]
        if imgui.Selectable('##card'..i,selected,0,vec(0,47)) then __imDialogData.selectedVideocard = v[1] end
        if imgui.IsItemHovered() then
            if imgui.IsMouseDoubleClicked(0) and not work.on then
                sampSendDialogResponsed(__imDialogData.id,1,v[1])
                imgui_windows.dialog.v = false
            end
            imgui.SetTooltip(u8(line..'\nВ час: '..rate..' '..(coin or '')..'   В сутки: '..(rate*24)..' '..(coin or '')..
                (coolant and '\nПроработает: ~'..math.floor(utils.calculateRemainingHours(coolant))..' ч.' or '')))
        end
        local draw = imgui.GetWindowDrawList()
        draw:AddText(vec(pos.x+8,pos.y+3),imgui.GetColorU32(t.inkColor),u8('Видеокарта №'..i..'   '..(paused and 'На паузе' or 'Работает')))
        draw:AddText(vec(pos.x+8,pos.y+24),imgui.GetColorU32(t.quietColor),u8((amount or '-')..' '..(coin or '')..'   |   ур. '..(level or '-')..'   |   '..(coolant or '-')..'%'))
        if selected then draw:AddLine(vec(pos.x+1,pos.y+4),vec(pos.x+1,pos.y+41),imgui.GetColorU32(t.accentColor),2) end
    end
    imgui.EndChild()
    local half = (imgui.GetContentRegionAvail().x-8)/2
    if imgui.Button(u8'Выбрать',vec(half,31)) and not work.on and #cards>0 then
        sampSendDialogResponsed(__imDialogData.id,1,__imDialogData.selectedVideocard)
        imgui_windows.dialog.v=false
    end
    imgui.SameLine()
    if imgui.Button(u8'Закрыть',vec(half,31)) and not work.on then __closeWindow(true) end
    imgui.EndChild()
    imgui.SameLine()
    imgui.BeginChild('##details',vec(0,0),true)
    local tw=(imgui.GetContentRegionAvail().x-16)/3
    for i,label in ipairs(tabs) do
        if i>1 then imgui.SameLine() end
        if i==tab then imgui.PushStyleColor(imgui.Col.Button,t.hoverColor) end
        local clicked = imgui.Button(u8(label),vec(tw,30))
        if i==tab then imgui.PopStyleColor() end
        if clicked then tab=i end
    end
    imgui.Separator()
    if work.on then
        imgui.MihailKrug(({'Забираю прибыль...','Заправляю...','Включаю карты...','Выключаю карты...'})[work.mode])
    elseif tab==1 then
        imgui.TextColored(t.accentColor,u8(attention and 'Требует внимания' or 'Всё в порядке'))
        local capacity = __imDialogData.title:find('дом') and 20 or 4
        metric('Видеокарты',#cards..' / '..capacity,t)
        metric('До заправки',minimum and ('~'..math.floor(utils.calculateRemainingHours(minimum))..' ч.') or '-',t)
        imgui.Separator()
        for _,coin in ipairs({'BTC','ASC'}) do
            imgui.SetWindowFontScale(1.25)
            imgui.TextColored(t.accentColor,coin)
            imgui.SetWindowFontScale(1)
            metric('В час',string.format('%.3f',hourly[coin]),t)
            metric('В сутки',string.format('%.3f',hourly[coin]*24),t)
            metric('Можно снять',tostring(available[coin]),t)
            imgui.Separator()
        end
        imgui.TextUnformatted(u8'Множитель доходности')
        for i,name in ipairs({'x1','x1.5','x2'}) do
            if i>1 then imgui.SameLine() end
            if imgui.RadioButton(name,imcfg.multiply,i) then cfg.multiply=i save() end
        end
    elseif tab==2 then
        local function action(label) return imgui.Button(u8(label),vec(imgui.GetContentRegionAvail().x,33)) end
        imgui.TextColored(t.quietColor,u8'Текущая ферма')
        if action('Включить видеокарты') then workLauncher.handleVideocardAction(3,1,'Все видеокарты включены, или в видеокартах нет охл. жидкости.') end
        if action('Выключить видеокарты') then workLauncher.handleVideocardAction(4,1,'Все видеокарты выключены.') end
        if action('Забрать прибыль') then workLauncher.handleVideocardAction(1,2,'Нечего забирать.') end
        if imgui.ButtonClickable("Недоступно через флэшку майнера",not __imDialogData.title:find('дом'),u8'Заправить охлаждающую жидкость',vec(imgui.GetContentRegionAvail().x,33)) then
            workLauncher.handleVideocardAction(2,3,'Охлаждение не требуется.')
        end
        imgui.Separator()
        imgui.TextColored(t.quietColor,u8'Все дома')
        for _,entry in ipairs({{3,'Запустить видеокарты во всех домах'},{1,'Собрать прибыль со всех домов'}}) do
            if action(entry[2]) then
                allHouses.active,allHouses.mode = true,entry[1]
                allHouses.currentHouse = getHouseNumber(__imDialogData.title)
                allHouses.awaitingHouseList,allHouses.visited = false,{}
                if allHouses.currentHouse then allHouses.visited[allHouses.currentHouse]=true end
                if entry[1]==1 then cryptoAnalysys.btc,cryptoAnalysys.asc=0,0 end
                workLauncher.handleVideocardAction(entry[1],entry[1]==1 and 2 or 1,entry[1]==1 and 'Нечего забирать.' or 'Все видеокарты включены, или в видеокартах нет охл. жидкости.')
            end
        end
    else
        imgui.TextUnformatted(u8'Тема оформления')
        for i,theme in ipairs(themes) do
            if imgui.RadioButton(u8(theme.name),imcfg.theme,i) then
                cfg.theme=i
                applyTheme(i)
                changed=os.clock()
                save()
            end
        end
        imgui.Separator()
        imgui.TextUnformatted(u8'Порог дозаправки')
        imgui.PushItemWidth(imgui.GetContentRegionAvail().x)
        if imgui.SliderInt('##coolant',imcfg.coolantPercents,1,99,'%.0f%%') then
            cfg.coolantPercents=imcfg.coolantPercents.v
            save()
        end
        imgui.PopItemWidth()
    end
    imgui.EndChild()
    imgui.End()
end
function imgui.ButtonClickable(hint, clickable, ...)
    if clickable then
        return imgui.Button(...)

    else
        local r, g, b, a = imgui.ImColor(imgui.GetStyle().Colors[imgui.Col.Button]):GetFloat4()
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(r, g, b, a/2) )
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(r, g, b, a/2))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(r, g, b, a/2))
        imgui.PushStyleColor(imgui.Col.Text, imgui.GetStyle().Colors[imgui.Col.TextDisabled])
            imgui.Button(...)
        imgui.PopStyleColor()
        imgui.PopStyleColor()
        imgui.PopStyleColor()
        imgui.PopStyleColor()
        if hint then
            if imgui.IsItemHovered() then
                imgui.SetTooltip(u8(hint))
            end
        end
    end
end
function imgui.MihailKrug(text, hint)
    local value = 0.3
    local bgColor = imgui.GetColorU32(imgui.ImVec4(0.2, 0.2, 0.2, 1.0))
    local fgColor = imgui.GetColorU32(themes[cfg.theme].accentColor)
    local speed = ({2.1,1.45,1.8})[cfg.theme]
    local width = ({5,2,7})[cfg.theme]
    text = u8(text or "Process...")
    hint = hint and u8(hint) or nil

    -- Вычисление размеров текста и радиуса круга
    local textSize = imgui.CalcTextSize(text)
    local radius = math.max(textSize.x, textSize.y) * 0.5 + width + 10

    -- Установка позиции курсора для центрирования круга
    imgui.SetCursorPosX((imgui.GetContentRegionAvail().x - (radius * 2)) / 2)

    local drawList = imgui.GetWindowDrawList()
    local cursorPos = imgui.GetCursorScreenPos()
    local centerX = cursorPos.x + radius
    local centerY = cursorPos.y + radius

    -- Параметры анимации
    local segments = 64
    local angle = (1.0 - value) * math.pi
    local animatedAngle = (math.pi * 0.5 + os.clock() * speed) % (math.pi * 2)
    local endAngle = animatedAngle + angle
    local radiusInner = radius - width

    -- Рисование круга и проверка наведения курсора
    imgui.Dummy(imgui.ImVec2(radius * 2, radius * 2))
    if hint and imgui.IsItemHovered() then
        fgColor = imgui.GetColorU32(imgui.ImVec4(imgui.GetStyle().Colors[imgui.Col.ButtonHovered]))
        imgui.SetTooltip(hint)
    end

    -- Рисование сегментов круга
    if angle > 0 then
        local step = angle / segments
        for i = 0, segments - 1 do
            local currentAngle = animatedAngle + i * step
            local nextAngle = currentAngle + step

            local x1 = centerX + math.cos(currentAngle) * radius
            local y1 = centerY + math.sin(currentAngle) * radius
            local x2 = centerX + math.cos(nextAngle) * radius
            local y2 = centerY + math.sin(nextAngle) * radius
            local x3 = centerX + math.cos(currentAngle) * radiusInner
            local y3 = centerY + math.sin(currentAngle) * radiusInner
            local x4 = centerX + math.cos(nextAngle) * radiusInner
            local y4 = centerY + math.sin(nextAngle) * radiusInner

            drawList:AddQuadFilled(imgui.ImVec2(x1, y1), imgui.ImVec2(x2, y2), imgui.ImVec2(x4, y4), imgui.ImVec2(x3, y3), fgColor)
        end
    end

    -- Рисование текста в центре круга
    local textPos = imgui.ImVec2(centerX - textSize.x * 0.5, centerY - textSize.y * 0.5)
    drawList:AddText(textPos, fgColor, text)

    -- Проверка нажатия на элемент
    if imgui.IsItemHovered() and imgui.IsItemClicked(0) then
        return true
    end
end
function imgui.Link(label, description)

    local size = imgui.CalcTextSize(label)
    local p = imgui.GetCursorScreenPos()
    local p2 = imgui.GetCursorPos()
    local result = imgui.InvisibleButton(label, size)

    imgui.SetCursorPos(p2)

    if imgui.IsItemHovered() then
        if description then
            imgui.BeginTooltip()
            imgui.PushTextWrapPos(600)
            imgui.TextUnformatted(description)
            imgui.PopTextWrapPos()
            imgui.EndTooltip()

        end

        imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.CheckMark], label)
        imgui.GetWindowDrawList():AddLine(imgui.ImVec2(p.x, p.y + size.y), imgui.ImVec2(p.x + size.x, p.y + size.y), imgui.GetColorU32(imgui.GetStyle().Colors[imgui.Col.CheckMark]))

    else
        imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.CheckMark], label)
    end

    return result
end
function __closeWindow(bool)
    sampSendDialogResponsed(__imDialogData.id, 0)
    imgui_windows.dialog.v = false
    if bool and sampIsDialogActive() then sampCloseCurrentDialogWithButton(0) end
end

local needReturnToMainWindow = false
cryptoAnalysys = {
    btc = 0,
    asc = 0
}

getHouseNumber = function(text)
    if not text then return nil end
    return tonumber(text:match("%(дом[^%d]*(%d+)"))
        or tonumber(text:match("Дом[^%d]*(%d+)"))
        or tonumber(text:match("дом[^%d]*(%d+)"))
        or tonumber(text:match("№%s*(%d+)"))
        or tonumber(text:match("ID[^%d]*(%d+)"))
end

local function resetAllHouses()
    allHouses.active = false
    allHouses.mode = 0
    allHouses.currentHouse = nil
    allHouses.awaitingHouseList = false
    allHouses.visited = {}
end

finishAllHouses = function()
    local mode = allHouses.mode
    resetAllHouses()
    work.on = false
    imgui_windows.dialog.v = false

    if mode == 1 then
        if cryptoAnalysys.btc > 0 or cryptoAnalysys.asc > 0 then
            utils.addChat("Забрали: {99ff99}"..cryptoAnalysys.btc.." BTC {ffffff}| {ffa500}"..cryptoAnalysys.asc..' ASC{ffffff}.')
            cryptoAnalysys.btc = 0
            cryptoAnalysys.asc = 0
        end
    elseif mode == 3 then
        utils.addChat("Все видеокарты включены, или в видеокартах нет охл. жидкости.")
    end
end

goToHouseList = function(dialogId, title)
    local house = getHouseNumber(title)
    if house then
        allHouses.currentHouse = house
        allHouses.visited[house] = true
    end
    allHouses.awaitingHouseList = true
    imgui_windows.dialog.v = false
    sampSendDialogResponsed(dialogId, 0)
end

function sampev.onShowDialog(id, style, title, button1, button2, text, placeholder)
    if __msStatsBusy() then
        json_timer[1] = false
        imgui_windows.dialog.v = false
        needReturnToMainWindow = false
        return
    end

    if needReturnToMainWindow then
        local a = title:gsub("%-","")
        if a:find("{BFBBBA}Стойка №%d+ | Полка №%d+") or a:find("{BFBBBA}Выберите тип жидкости") then
            sampSendDialogResponsed(id, 0)
        end
    end

    if title:find("{BFBBBA}Выберите видеокарту") then
        needReturnToMainWindow = false
        if not cfg.on then return end
        __imDialogData.id = id
        __imDialogData.title = title
        if allHouses.active then
            local house = getHouseNumber(title)
            if house then
                allHouses.currentHouse = house
                allHouses.visited[house] = true
            end
            allHouses.awaitingHouseList = false
        end
        __imDialogData.videocards = {}
        __imDialogData.selectedVideocard = -1

        local listboxId = -1

        --Полка №1 | {BEF781}Работает	2.449996 BTC	7 уровень	91.37%
        for line in text:gmatch("[^\r\n]+") do

            if line:find("^Полка") then
                local insertText = (line:find("Работает") and line:gsub("Работает", "Работает{ffffff}") or line:gsub("На паузе", "На паузе{ffffff}")):gsub("Полка №%d+", "Видеокарта №"..(#__imDialogData.videocards+1))
                local properDetect = line:match("(%d+%.%d+)%%?%s*$")
                if properDetect and tonumber(properDetect) <= cfg.coolantPercents then
                    insertText = insertText:gsub("(%d+%.%d+)%%?%s*$", "{ff9999}%1%%")
                elseif properDetect then
                    insertText = insertText:gsub("(%d+%.%d+)%%?%s*$", "{99ff99}%1%%")
                end
                insertText = insertText:gsub("(%d+%.%d+%s+BTC)", "{99ff99}%1{ffffff}"):gsub("(%d+%.%d+%s+ASC)", "{ffa500}%1{ffffff}")
                
                table.insert(__imDialogData.videocards, {
                    listboxId,
                    insertText
                })
                __imDialogData.selectedVideocard = __imDialogData.selectedVideocard==-1 and listboxId or __imDialogData.selectedVideocard
            end

            listboxId = listboxId+1

        end

        if not imgui_windows.dialog.v then changed=os.clock() end
        imgui_windows.dialog.v = true

        if not work.on then
            return false
        end
    else
        if not work.on then imgui_windows.dialog.v = false end
    end

    if allHouses.active and allHouses.awaitingHouseList and not title:find("{BFBBBA}Выберите видеокарту") then
        local rows = {}
        local listboxId = (style == 5) and -1 or 0

        for line in text:gmatch("[^\r\n]+") do
            if listboxId >= 0 then
                local house = getHouseNumber(line)
                if house then
                    table.insert(rows, { id = listboxId, text = line, house = house })
                end
            end
            listboxId = listboxId + 1
        end

        if #rows == 0 then
            finishAllHouses()
            return
        end

        local currentIndex = nil
        for i, row in ipairs(rows) do
            if allHouses.currentHouse and row.house == allHouses.currentHouse then
                currentIndex = i
                break
            end
        end

        local nextRow = nil
        if currentIndex then
            for offset = 1, #rows do
                local i = ((currentIndex - 1 + offset) % #rows) + 1
                if not allHouses.visited[rows[i].house] then
                    nextRow = rows[i]
                    break
                end
            end
        else
            for _, row in ipairs(rows) do
                if not allHouses.visited[row.house] then
                    nextRow = row
                    break
                end
            end
        end

        if nextRow then
            allHouses.currentHouse = nextRow.house
            allHouses.visited[nextRow.house] = true
            allHouses.awaitingHouseList = false
            sampSendDialogResponsed(id, 1, nextRow.id, nextRow.text)
        else
            sampSendDialogResponsed(id, 0)
            finishAllHouses()
        end
        return
    end

    if not work.on then return end

    local function deactivateScript(message, needOff)
        if needOff then imgui_windows.dialog.v = false end
        work.on = false
        utils.addChat(message)
    end

    local function findLineAndRespond(pattern, checkFunc, listboxId)
        for line in string.gmatch(text, "[^\r\n]+") do
            if line:find(pattern) and checkFunc(line) then
                sampSendDialogResponsed(id, 1, listboxId, line)
                return true
            end
            listboxId = listboxId + 1
        end
        return false
    end

    if work.mode == 1 then
        if title:find('{BFBBBA}Выберите видеокарту') then
            if not text:find('%d+%.%d%d%d%d%d%d') then
                deactivateScript("Ошибка! Код 1.")
                return
            end
    
            if not findLineAndRespond('%d+%.%d%d%d%d%d%d', function(line)
                return tonumber(line:match("(%d+)%.%d%d%d%d%d%d")) > 0
            end, -1) then
                if allHouses.active and allHouses.mode == 1 then
                    goToHouseList(id, title)
                    return
                end
                deactivateScript("Криптовалюта не найдена.")
                if cryptoAnalysys.btc > 0 or cryptoAnalysys.asc > 0 then
                    utils.addChat("Забрали: {99ff99}"..cryptoAnalysys.btc.." BTC {ffffff}| {ffa500}"..cryptoAnalysys.asc..' ASC{ffffff}.')
                    cryptoAnalysys.btc = 0
                    cryptoAnalysys.asc = 0
                end
            end
    
        elseif title:gsub("%-",""):find("{BFBBBA}Стойка №%d+ | Полка №%d+") then
            if not findLineAndRespond('%d+%.%d%d%d%d%d%d', function(line)
                return tonumber(line:match("(%d+)%.%d%d%d%d%d%d")) > 0
            end, 0) then
                sampSendDialogResponsed(id, 0)
            end
        elseif title:find('{BFBBBA}Вывод прибыли видеокарты') then
            sampSendDialogResponsed(id, 1)
        end

    elseif work.mode == 2 then

        if title:find('{BFBBBA}Выберите видеокарту') then
            if title:find('%(дом') then 
                deactivateScript("Режим охлаждения работает только в ручном режиме. Не в /flashminer. Скрипт деактивирован.", true) 
                return 
            end            

            if not text:find("(%d+%.%d+)%%?%s*$") then
                deactivateScript("Охлаждение не нужно. 1")
                return
            end

            if not findLineAndRespond("(%d+%.%d+)%%?%s*$", function(line) return tonumber(line:match("(%d+%.%d+)%%?%s*$")) <= cfg.coolantPercents end, -1) then
                deactivateScript("Охлаждение не нужно. 2")
            end

        elseif title:gsub("%-",""):find("{BFBBBA}Стойка №%d+ | Полка №%d+") then
            if work.needSkip then
                sampSendDialogResponsed(id, 0)
                work.needSkip = false
                return
            end

            if not findLineAndRespond('Залить охлаждающую жидкость', function() return true end, 0) then
                sampSendDialogResponsed(id, 0)
            else
                work.videocardMode = ""
                if text:find("BTC") then
                    work.videocardMode = "btc"
                elseif text:find("ASC") then
                    work.videocardMode = "asc"
                end
            end

        elseif title:find('{BFBBBA}Выберите тип жидкости') then
            local fluidType = "None"
            if work.videocardMode == 'btc' then
                fluidType = "для видеокарты"
            elseif work.videocardMode == 'asc' then
                fluidType = "Охлаждающая жидкость для Arizona Video Card"
            end
            if not findLineAndRespond(fluidType, function(line) -- Охлаждающая жидкость для видеокарты	{CCCCCC}[ 15 ]
                return tonumber(line:match("%[ (%d+) %]")) > 0
            end, -1) then
                deactivateScript("Скрипт деактивирован. Нет охлаждающей жидкости.", false)
                sampSendDialogResponsed(id, 0)
                needReturnToMainWindow = true
            end
            work.needSkip = true
        end

    elseif work.mode == 3 or work.mode == 4 then

        if title:find('{BFBBBA}Выберите видеокарту') then           

            if not findLineAndRespond(work.mode==3 and "{F78181}На паузе" or "{BEF781}Работает", function(line)
                return tonumber(line:match("(%d+%.%d+)%%?%s*$")) > 0
            end, -1) then
                if allHouses.active and allHouses.mode == 3 then
                    goToHouseList(id, title)
                    return
                end
                deactivateScript("Работа не требуется, или в видеокартах нет охл. жидкости.")
            end

        elseif title:gsub("%-",""):find("{BFBBBA}Стойка №%d+ | Полка №%d+") then
            if not findLineAndRespond(work.mode==3 and "{BEF781}Запустить видеокарту" or "{F78181}Остановить видеокарту", function() return true end, 0) then
                sampSendDialogResponsed(id, 0)
            end
        end
    end
end

function onScriptTerminate(script, quitGame)
    if script == thisScript() then __msClearBusyLock() end
end

function sampev.onServerMessage(color, text)
    if not work.on then return end
    if text:find("^Вы вывели {ffffff}%d+ [BTCASC]+{ffff00}") then
        if text:find("BTC") then
            cryptoAnalysys.btc = cryptoAnalysys.btc + tonumber(text:match("Вы вывели {ffffff}(%d+)"))
        elseif text:find("ASC") then
            cryptoAnalysys.asc = cryptoAnalysys.asc + tonumber(text:match("Вы вывели {ffffff}(%d+)"))
        end
        return false
    elseif text:find("^Вам был добавлен предмет") and (text:find("BTC") or text:find("ASC")) then
        return false
    elseif text:find("^%[Ошибка%] {ffffff}Чтобы запустить видеокарту в работу") then
        if allHouses.active then resetAllHouses() end
        work.on = false
        lua_thread.create(function() wait(0) __closeWindow(true) end)
    end
end

sampSendDialogResponsed = function(dialogId, button, list, text) 
    json_timer = {true, json_timer[2], dialogId, button, list, text}
end

local function findCardIndexById(videocards, id)
    for index, card in ipairs(videocards) do
        if card[1] == id then
            return index
        end
    end
    return nil
end
function onWindowMessage(msg, wparam, lparam)
    if not work.on and imgui_windows.dialog.v and not isPauseMenuActive() then
        if msg == 0x101 or msg == 0x100 then 
            if msg == 0x101 and wparam == 0x1B then
                consumeWindowMessage(true, false)
                __closeWindow(false)
            elseif msg == 0x101 and wparam == 0x0D then
                consumeWindowMessage(true, false)
                sampSendDialogResponsed(__imDialogData.id, 1, __imDialogData.selectedVideocard)
                imgui_windows.dialog.v = false
            end
            if msg == 0x100 and (wparam == 0x26 or wparam == 0x28) then
                consumeWindowMessage(true, false)
                if wparam == 0x26 then
                    local currentIndex = findCardIndexById(__imDialogData.videocards, __imDialogData.selectedVideocard)
                    if currentIndex then
                        currentIndex = currentIndex - 1
                        if currentIndex < 1 then
                            currentIndex = #__imDialogData.videocards
                        end
                        __imDialogData.selectedVideocard = __imDialogData.videocards[currentIndex][1]
                    end
                elseif wparam == 0x28 then
                    local currentIndex = findCardIndexById(__imDialogData.videocards, __imDialogData.selectedVideocard)
                    if currentIndex then
                        currentIndex = currentIndex + 1
                        if currentIndex > #__imDialogData.videocards then
                            currentIndex = 1
                        end
                        __imDialogData.selectedVideocard = __imDialogData.videocards[currentIndex][1]
                    end
                end               
            end
        end
    end
end
