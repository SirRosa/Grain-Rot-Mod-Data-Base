-- Grain Rot Depth Keeper v0.3.0
-- Host-only UE4SS Lua mod. Requires a compatible Grain Rot UE4SS installation.
--
-- Observed schema (supplied Helden 5.7.4 .usmap):
--   HeldenGameInstance.CurrentSaveGame -> HeldenSaveGame.DungeonLevel
--   HeldenSaveGame.MetaData.GameSlot, TimePlayed, DungeonWins, DungeonFails
--   HeldenGameState.CurrentDungeonRun -> {State, Flags, DungeonActor}
--   DungeonActor.CurrentSeed -> {Seed, Level}  (Level is shown_level - 1)
--   EHeldenDungeonRunState = 0 None, 1 ElevatorRideDown, 2 Exploring,
--                            3 EndScreen
--   EHeldenDungeonRunFlags.Failed = 1
-- The exact update order of the game's autosave is NOT verified in live play.

local CONFIG = {
    POLL_SECONDS = 0.50, -- depth state is not frame-sensitive
    CLOCK_SAMPLE_EVERY = 8, -- avoid wall-clock calls on most animation updates
    MAX_DEPTH = 10000,
    -- Fallback only if the game's save level does not advance with the dungeon.
    -- 0 means CurrentSeed.Level is represented directly in save.DungeonLevel;
    -- live readings of both fields calibrate this to 0 or 1 if possible.
    SEED_TO_SAVE_FALLBACK_OFFSET = 0,
    ENABLE_FILE_BACKUP = true,
    -- Avoid importing progress from a new game reusing an older save slot.
    PLAYTIME_GRACE_SECONDS = 5,
    VERBOSE = false,
    DISPLAY_PROBE_SECONDS = 3, -- outpost UI refresh; cached instance lookup
}

local TAG = "[GrainRotDepthKeeper] "
local function log(message) print(TAG .. tostring(message) .. "\n") end
local function diag(message) if CONFIG.VERBOSE then log(message) end end

local function valid(object)
    if object == nil then return false end
    local ok, result = pcall(function() return object:IsValid() end)
    return ok and result == true
end

-- FindFirstOf scans Unreal's object registry. Stable singletons are cached
-- while their UObject remains valid, and cleared on ClientRestart/map travel.
-- This avoids thousands of repeated registry searches in a long session.
local cached = {}
local function find_cached(className)
    local object = cached[className]
    if valid(object) then return object end
    cached[className] = nil
    local ok, found = pcall(FindFirstOf, className)
    if ok and valid(found) then
        cached[className] = found
        return found
    end
    return nil
end

local function clear_cache()
    cached = {}
end

local function whole(value, lower, upper)
    local v = tonumber(value)
    if v and v == v and v ~= math.huge and v ~= -math.huge then
        v = math.floor(v)
        if v >= lower and v <= upper then return v end
    end
    return nil
end

local function read_number(object, key, lower, upper)
    local v
    pcall(function() v = object[key] end)
    return whole(v, lower, upper)
end

local function enum_number(value)
    if type(value) == "number" then return value end
    if value == nil then return nil end
    local s = tostring(value)
    local n = tonumber(s)
    if n then return n end
    if s:find("ElevatorRideDown", 1, true) then return 1 end
    if s:find("Exploring", 1, true) then return 2 end
    if s:find("EndScreen", 1, true) then return 3 end
    if s:find("Failed", 1, true) then return 1 end
    if s:find("None", 1, true) then return 0 end
    return nil
end

local function failure_flag(value)
    local number = enum_number(value)
    if number ~= nil then return number % 2 == 1 end
    return value ~= nil and tostring(value):find("Failed", 1, true) ~= nil
end

-- Not a synchronous "SaveGameToSlot": that API would need the actual slot
-- filename. We keep our own tiny, per-slot backup and patch the live SaveGame
-- when the player returns. The game's normal save lifecycle remains intact.
local function backup_path(slot)
    if not CONFIG.ENABLE_FILE_BACKUP then return nil end
    local base
    pcall(function() base = os.getenv("LOCALAPPDATA") end)
    if not base or base == "" then return nil end
    return base .. "\\Helden\\Saved\\GrainRotDepthKeeper_slot" .. slot .. ".txt"
end

local function read_backup(slot, playtime, wins, fails)
    local path = backup_path(slot)
    if not path or not playtime or not wins or not fails then return nil end
    local file = io.open(path, "r")
    if not file then return nil end
    local line = file:read("*l")
    file:close()
    if not line then return nil end
    local ver, fs, flevel, ft, fw, ff = line:match("^(%S+) (%d+) (%d+) (%d+) (%d+) (%d+)$")
    if ver ~= "GRDK1" or tonumber(fs) ~= slot then return nil end
    local depth = whole(flevel, 0, CONFIG.MAX_DEPTH)
    local old_time = whole(ft, 0, 1000000000)
    local old_wins = whole(fw, 0, 1000000000)
    local old_fails = whole(ff, 0, 1000000000)
    if not depth or not old_time or not old_wins or not old_fails then return nil end
    if playtime + CONFIG.PLAYTIME_GRACE_SECONDS < old_time or
       wins < old_wins or fails < old_fails then
        log("backup rejected for slot " .. slot .. " (possible new/rewound save)")
        return nil
    end
    return depth
end

local function write_backup(slot, depth, playtime, wins, fails)
    local path = backup_path(slot)
    if not path or not playtime or not wins or not fails then return false end
    local file, err = io.open(path, "w")
    if not file then diag("backup not writable: " .. tostring(err)); return false end
    file:write(string.format("GRDK1 %d %d %d %d %d\n",
        slot, depth, playtime, wins, fails))
    file:close()
    return true
end

local state = {
    lastCheck = -1,
    lastSaveKey = nil,
    slot = nil,
    lastTimePlayed = nil,
    protected = 0,
    highestSeed = nil,
    levelOffset = nil,
    runSeen = false,
    failureSeen = false,
    lastRunState = nil,
    lastBackupDepth = nil,
    lastBackupTime = -1,
    applied = 0,
    warned = false,
    displayOffset = nil,
    nextDisplayProbe = 0,
    lastDisplaySnapshot = nil,
    seedWarningIssued = false,
}

local function reset_for_save(save, saveKey, slot, playtime, wins, fails)
    state.lastSaveKey = saveKey
    state.slot = slot
    state.lastTimePlayed = playtime
    state.protected = read_number(save, "DungeonLevel", 0, CONFIG.MAX_DEPTH) or 0
    state.highestSeed = nil
    state.levelOffset = nil
    state.runSeen = false
    state.failureSeen = false
    state.lastRunState = nil
    state.lastBackupDepth = nil
    state.lastBackupTime = -1
    state.applied = 0
    state.displayOffset = nil
    state.nextDisplayProbe = 0
    state.lastDisplaySnapshot = nil
    state.seedWarningIssued = false
    local fromBackup = read_backup(slot, playtime, wins, fails)
    if fromBackup and fromBackup > state.protected then
        state.protected = fromBackup
        log("slot " .. slot .. ": recovered depth " .. fromBackup .. " from backup")
    else
        log("slot " .. slot .. ": tracking saved depth " .. state.protected)
    end
end

-- The shipped .usmap shows AHeldenDungeonLevelDisplay.DisplayLevel as
-- a second, independent field. We cannot assume it drives generation; patch
-- only this known display field, NEVER the dungeon seed or elevator movement.
-- Observing the display before failure calibrates 0/1-based semantics.
-- The machine has no reflected 'CurrentFloor' property in this build.
local function probe_display(raw, runState)
    if runState ~= 0 or state.protected <= 0 then return end
    local now = os.clock()
    if now < state.nextDisplayProbe then return end
    state.nextDisplayProbe = now + CONFIG.DISPLAY_PROBE_SECONDS

    local display = find_cached("HeldenDungeonLevelDisplay")
    local shown = display and read_number(display, "DisplayLevel", 0, CONFIG.MAX_DEPTH) or nil
    if shown and not state.failureSeen and (shown == raw or shown == raw + 1) then
        state.displayOffset = shown - raw
    end
    -- Deep elevator diagnostics are disabled on the hot path. In a normal
    -- session only the one actual display object is inspected.
    local snapshot = string.format("outpost: save=%d kept=%d display=%s offset=%s fail=%s",
        raw, state.protected, tostring(shown), tostring(state.displayOffset),
        tostring(state.failureSeen))
    if snapshot ~= state.lastDisplaySnapshot then
        state.lastDisplaySnapshot = snapshot
        log(snapshot)
    end

    -- Refresh the concrete in-world level display, which may have been
    -- initialized with level 1 before the SaveGame field was restored.
    -- Only repair low/stale displays after a confirmed failed run.
    -- This cannot guarantee that the machine uses DisplayLevel internally.
    if state.failureSeen and shown and shown < state.protected then
        local target = state.protected + (state.displayOffset or 1)
        if target > shown and target <= CONFIG.MAX_DEPTH then
            local ok, err = pcall(function() display.DisplayLevel = target end)
            if ok then
                local readback = read_number(display, "DisplayLevel", 0, CONFIG.MAX_DEPTH)
                log(string.format("display refresh: %d -> %d, readback=%s",
                    shown, target, tostring(readback)))
                -- Don't repeatedly hammer the object if the setter sticks.
                state.nextDisplayProbe = now + CONFIG.DISPLAY_PROBE_SECONDS
            else
                log("display refresh failed: " .. tostring(err))
            end
        end
    end
end

local function scan()
    -- GameMode exists only on a server/listen host; client-only writes would
    -- not be authoritative and might desync multiplayer sessions.
    local gm = find_cached("GameModeBase")
    if not gm then return end

    local gi = find_cached("HeldenGameInstance")
    if not gi then return end
    local save
    pcall(function() save = gi.CurrentSaveGame end)
    if not valid(save) then
        state.lastSaveKey = nil
        return
    end

    local slot, playtime, wins, fails
    pcall(function() slot = save.MetaData.GameSlot end)
    slot = whole(slot, 0, 100)
    playtime = read_number(save, "TimePlayed", 0, 1000000000)
    wins = read_number(save, "DungeonWins", 0, 1000000000)
    fails = read_number(save, "DungeonFails", 0, 1000000000)
    if not slot then
        if not state.warned then
            log("GameSlot unavailable; no progress changes will be made")
            state.warned = true
        end
        return
    end

    -- Compare the UE object path, not the transient Lua userdata wrapper.
    local saveKey
    pcall(function() saveKey = save:GetFullName() end)
    if saveKey == nil then saveKey = tostring(save) end

    -- New SaveGame object, different slot, or clear new-game signal.
    if state.lastSaveKey ~= saveKey or state.slot ~= slot or
       (playtime and state.lastTimePlayed and playtime + 120 < state.lastTimePlayed) then
        reset_for_save(save, saveKey, slot, playtime, wins, fails)
    end
    if playtime then state.lastTimePlayed = playtime end

    local raw = read_number(save, "DungeonLevel", 0, CONFIG.MAX_DEPTH)
    if raw == nil then return end
    local runState, flags, seedLevel
    local gs = find_cached("HeldenGameState")
    if gs then
        pcall(function()
            local run = gs.CurrentDungeonRun
            runState = enum_number(run.State)
            flags = run.Flags
            local dungeon = run.DungeonActor
            if valid(dungeon) then
                seedLevel = whole(dungeon.CurrentSeed.Level, 0, CONFIG.MAX_DEPTH)
            end
        end)
    end

    if runState == 1 or runState == 2 then
        -- The elevator/UI actor may be replaced when travelling. Never retain
        -- a cached display across a new dungeon instance.
        cached["HeldenDungeonLevelDisplay"] = nil
        state.runSeen = true
        if state.failureSeen then
            log("next dungeon run started; failure recovery completed")
            state.failureSeen = false
            state.seedWarningIssued = false
        end
        if seedLevel then
            if not state.highestSeed or seedLevel > state.highestSeed then
                state.highestSeed = seedLevel
            end
            -- This is safe to calibrate only when fields describe the same
            -- stage: a delta in {0,1}. Never force a guess into a live run.
            if raw >= seedLevel and raw <= seedLevel + 1 then
                state.levelOffset = raw - seedLevel
            end
        end
    end

    if raw > state.protected then
        state.protected = raw
        log("slot " .. slot .. ": new saved depth " .. raw)
    end
    if state.highestSeed then
        local rawFromSeed = state.highestSeed +
            (state.levelOffset or CONFIG.SEED_TO_SAVE_FALLBACK_OFFSET)
        if rawFromSeed > state.protected then
            state.protected = rawFromSeed
            log("slot " .. slot .. ": reached depth " .. rawFromSeed .. " (run seed)")
        end
    end

    -- Failure is an authoritative run result, NOT the death of an individual
    -- vessel (a teammate can still rescue you). Only failed runs are recovered.
    if state.runSeen and failure_flag(flags) and (runState == 3 or runState == 0) then
        if not state.failureSeen then
            state.failureSeen = true
            log("failed dungeon run observed; preserving depth " .. state.protected)
        end
    end
    -- Restore as soon as the game resets depth during the end screen,
    -- rather than waiting until the outpost UI has already cached level 1.
    -- The outpost fallback also recovers depth after loading an older backup.
    local canRestore = (state.failureSeen and (runState == 3 or runState == 0))
        or (runState == 0 and not state.runSeen)
    if canRestore and raw < state.protected then
        local success, err = pcall(function() save.DungeonLevel = state.protected end)
        if success then
            state.applied = state.applied + 1
            log(string.format("slot %d: restored DungeonLevel %d -> %d (%d)",
                slot, raw, state.protected, state.applied))
        else
            log("depth restore FAILED: " .. tostring(err))
        end
    end

    if state.lastRunState ~= runState then
        log(string.format("run state %s -> %s; save=%d kept=%d seed=%s failed=%s",
            tostring(state.lastRunState), tostring(runState), raw, state.protected,
            tostring(seedLevel), tostring(state.failureSeen)))
    end
    -- Detect whether a restored level is actually used for the new map.
    -- A mismatch is logged, NOT forcibly patched into a generated map.
    if runState == 2 and seedLevel and
       seedLevel + 1 < state.protected and not state.seedWarningIssued then
        state.seedWarningIssued = true
        log(string.format("WARNING: generated dungeon seed level=%d, saved target=%d; next run may be shallow",
            seedLevel, state.protected))
    end
    probe_display(raw, runState)

    if state.protected > 0 and playtime and wins and fails and
       (state.lastBackupDepth ~= state.protected or
        (state.failureSeen and state.lastBackupTime < 0)) then
        local done = write_backup(slot, state.protected, playtime, wins, fails)
        if done then
            state.lastBackupDepth = state.protected
            state.lastBackupTime = os.clock()
        end
    end
    state.lastRunState = runState
    if CONFIG.VERBOSE then
        diag(string.format("slot=%d run=%s failed=%s save=%d kept=%d seed=%s offset=%s",
            slot, tostring(runState), tostring(state.failureSeen), raw,
            state.protected, tostring(seedLevel), tostring(state.levelOffset)))
    end
end

local hookIsRegistered = false
local errorCount = 0
local hookSample = CONFIG.CLOCK_SAMPLE_EVERY - 1 -- first callback runs immediately
local function heartbeat()
    -- BlueprintUpdateAnimation may run for hundreds of anim instances each
    -- second. Lua callbacks still happen, but 7/8 return without os.clock,
    -- reflection, allocations or any other observable side effect.
    hookSample = hookSample + 1
    if hookSample < CONFIG.CLOCK_SAMPLE_EVERY then return end
    hookSample = 0
    local now = os.clock()
    if state.lastCheck >= 0 and now >= state.lastCheck and
       now - state.lastCheck < CONFIG.POLL_SECONDS then return end
    state.lastCheck = now
    local ok, err = pcall(scan)
    if not ok and errorCount < 8 then
        errorCount = errorCount + 1
        log("poll error (" .. errorCount .. "/8): " .. tostring(err))
    end
end

local function ensure_hook()
    if hookIsRegistered then return end
    local ok, err = pcall(function()
        RegisterHook("/Game/Animation/ABP_HeldenPlayer.ABP_HeldenPlayer_C:BlueprintUpdateAnimation",
            function() heartbeat() end)
    end)
    if ok then
        hookIsRegistered = true
        log("animation heartbeat registered; sampled and cached lookups active")
    else
        log("could not register heartbeat hook: " .. tostring(err))
    end
end

ensure_hook()
pcall(function()
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
        state.lastCheck = -1
        hookSample = CONFIG.CLOCK_SAMPLE_EVERY - 1
        clear_cache()
        ensure_hook()
    end)
end)
log("loaded v0.3.0 (8x lighter clock checks; 0.5s poll; UObject lookup cache)")
