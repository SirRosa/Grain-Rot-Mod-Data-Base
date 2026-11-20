-- Expedition Mapper: read-only UE4SS diagnostics for current Grain Rot build.
-- This is NOT the gameplay mod; it only dumps the game's reflection metadata.
-- Launch an Expedition save, then press F8 for an auto-named Helden-*.usmap and F9 for
-- UE4SS_ObjectDump.txt. Each action is explicitly user-triggered.
local prefix = "[ExpeditionMapper] "
local function info(msg)
    print(prefix .. msg .. "\n")
end

local function perform(label, functionName)
    if type(_G[functionName]) ~= "function" then
        info("ERROR: "..functionName.." not available in installed UE4SS; "..label.." skipped.")
        return
    end
    info("Starting "..label.."; game may pause while the dumper runs.")
    local ok,err = pcall(_G[functionName])
    if ok then
        info(label.." completed. Look in ue4ss working directory or Helden/Binaries/Win64.")
    else
        info("ERROR in "..label..": "..tostring(err))
    end
end

local function bind(key, label, action)
    if not RegisterKeyBind or not Key or not Key[key] then
        info("ERROR: keybinding API unavailable: "..key)
        return false
    end
    local ok,err=pcall(RegisterKeyBind,Key[key],action)
    if not ok then
        info("ERROR binding "..label..": "..tostring(err))
        return false
    end
    info(label.." ready")
    return true
end

bind("F8","F8 -> dump CURRENT Helden-*.usmap (automatic filename)", function()
    perform("USMAP (automatically named Helden-*.usmap)", "DumpUSMAP")
end)
bind("F9","F9 -> dump UE4SS_ObjectDump.txt (loaded objects/functions)", function()
    perform("UE4SS_ObjectDump.txt", "DumpAllObjects")
end)
info("Read-only diagnostic collector loaded. Enter Expedition, then press F8 and F9.")
