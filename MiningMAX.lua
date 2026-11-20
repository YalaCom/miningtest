script_name('MiningMAX')
script_author('JustFedot / @exquown')
script_version('1.1.0')

local function report(err)
    local message = '[MiningMAX] @exquown | \205\229 \231\224\227\240\243\230\229\237: ' .. tostring(err)
    print(message)
    function main()
        if type(isSampAvailable) ~= 'function' then return end
        repeat wait(100) until isSampAvailable()
        sampAddChatMessage(message, 0xFF9977)
    end
end

local ok, err = pcall(dofile, getWorkingDirectory() .. '\\MiningMAX\\core.lua')
if not ok then report(err) end
