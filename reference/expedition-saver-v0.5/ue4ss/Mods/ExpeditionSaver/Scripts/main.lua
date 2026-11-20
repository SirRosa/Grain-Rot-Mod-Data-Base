-- Expedition Saver v0.5.0-alpha | Grain Rot (Helden / UE4SS 3.x)
-- Host-authoritative only. This mod is EXPERIMENTAL; back up the save.
-- The latest 2026-11-20 USMAP confirms fields and reflected signatures,
-- not the exact native save/death sequence. Every mutation is checked.
local CFG = {
    PollSeconds = 0.30,
    AnimationSample = 8,
    MaxDepth = 10000,
    EnableRespawn = true,
    EnableItemRecovery = true,
    RestoreDestroyedItems = true, -- only after native inventory reconciliation, with dedup
    MaxGearPerPlayer = 64,
    InventoryRecoveryRetryTicks = 6,
    MaxInventoryRecoveryTicks = 24,
    EnableMoneyRecovery = true,
    EnableNoPermadeath = true,
    EnablePhysicalCoins = true,
    RespawnDelaySeconds = 0.15,
    RespawnRetrySeconds = 1.5,
    MaxRespawnRequests = 3,
    EnableExistingPawnReviveFallback = true, -- after native server respawn failed
    FallbackAfterTicks = 15,
    BackupFile = true,
    MaxCoinsPerDrop = 100000,
    RewardDelaySeconds = 0.20,
    RetryHookSeconds = 8,
    HeartbeatDiagnosticsSeconds = 12,
    RecoveryRetrySeconds = 2,
    Verbose = false,
}
local TAG = "[ExpeditionSaver] "
local function log(s) print(TAG..tostring(s).."\n") end
local function diag(s) if CFG.Verbose then log(s) end end
local function get(o,k)
    if o == nil then return nil end
    local ok,r=pcall(function() return o[k] end)
    if ok then return r end
end
local function put(o,k,v)
    if o == nil then return false end
    local ok=pcall(function() o[k]=v end)
    if not ok then return false end
    return true
end
local function valid(o)
    if o==nil then return false end
    local ok,r=pcall(function() return o:IsValid() end)
    return ok and r==true
end
local function unwrap(o)
    if o==nil then return nil end
    local ok,r=pcall(function() return o:get() end)
    if ok then return r end
    return o
end
local function resolveWeak(o)
    if valid(o) then return o end
    if o==nil then return nil end
    local ok,r=pcall(function() return o:Get() end)
    if ok and valid(r) then return r end
end
local function asName(o)
    if o==nil then return nil end
    local ok,r=pcall(function() return o:ToString() end)
    if ok and r then return tostring(r) end
    return tostring(o)
end
local function number(o,lo,hi)
    local n=tonumber(o)
    if n and n==n and n~=math.huge and n~=-math.huge then
        n=math.floor(n)
        if n>=lo and n<=hi then return n end
    end
    return nil
end
local function enum(v)
    if type(v)=="number" then return v end
    if v==nil then return nil end
    local s=tostring(v)
    local n=tonumber(s)
    if n then return n end
    if s:find("Expedition",1,true) then return 1 end
    if s:find("Exploring",1,true) then return 2 end
    if s:find("EndScreen",1,true) then return 3 end
    if s:find("ElevatorRideDown",1,true) then return 1 end
    if s:find("Epic",1,true) then return 2 end
    if s:find("Failed",1,true) then return 1 end
    if s:find("Dead",1,true) then return 1 end
    if s:find("None",1,true) or s:find("Default",1,true) then return 0 end
    return nil -- important: tostring(enum(...)) must receive a value
end
local function failure(v)
    local n=enum(v)
    return n~=nil and n%2==1
end
local function path(o)
    if not valid(o) then return nil end
    local ok,r=pcall(function() return o:GetFullName() end)
    if ok and r then return tostring(r) end
    return tostring(o)
end
local function each(arr,callback)
    if not arr then return end
    local ok,n=pcall(function() return #arr end)
    if not ok or type(n)~="number" then return end
    for i=1,math.min(n,128) do
        local success,o=pcall(function() return unwrap(arr[i]) end)
        if success and o then callback(o,i) end
    end
end
local cache={}
local function first(cls)
    if valid(cache[cls]) then return cache[cls] end
    cache[cls]=nil
    local function live(obj)
        if not valid(obj) then return false end
        local id=path(obj)
        return id and not id:find("Default__",1,true)
    end
    local ok,obj=pcall(FindFirstOf,cls)
    if ok and live(obj) then cache[cls]=obj;return obj end
    -- FindFirstOf may return a Class Default Object before an actual actor.
    local good,items=pcall(FindAllOf,cls)
    if good and type(items)=="table" then
        for _,candidate in ipairs(items) do
            if live(candidate) then cache[cls]=candidate;return candidate end
        end
    end
end
local function all(cls)
    local ok,objects=pcall(FindAllOf,cls)
    if ok and type(objects)=="table" then return objects end
    return {}
end
local function vec(v)
    if not v then return nil end
    local x,y,z=tonumber(get(v,"X")),tonumber(get(v,"Y")),tonumber(get(v,"Z"))
    if x and y and z then return {X=x,Y=y,Z=z} end
end
local function distance2(a,b)
    if not a or not b then return math.huge end
    return (a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2
end
local function location(a)
    if not valid(a) then return nil end
    local ok,r=pcall(function() return a:K2_GetComponentLocation() end)
    if ok and r then return vec(r) end
    ok,r=pcall(function() return a:K2_GetActorLocation() end)
    if ok and r then return vec(r) end
end
local function teleport(obj,dest)
    if not valid(obj) or not dest then return false end
    local rot={Pitch=0,Yaw=0,Roll=0}
    local ok,result=pcall(function() return obj:K2_TeleportTo(dest,rot) end)
    if ok and result~=false then return true end
    ok,result=pcall(function()
        return obj:K2_SetActorLocation(dest,false,{},true)
    end)
    return ok and result~=false
end
local function onHost()
    return valid(first("HeldenGameMode")) or valid(first("GameModeBase"))
end
local function game()
    local gi=first("HeldenGameInstance")
    local gs=first("HeldenGameState")
    local save=gi and get(gi,"CurrentSaveGame")
    if not valid(gs) or not valid(save) then return nil end
    -- Do not touch the normal game. GameModeType is the authoritative check.
    local gm=enum(get(gs,"GameModeType"))
    local sg=enum(get(save,"GameMode"))
    local metadataMode=enum(get(get(save,"MetaData"),"GameMode"))
    -- Some transitions leave GameState.GameModeType unset while the
    -- underlying SaveGame still identifies a valid Expedition. Require two
    -- independent saved indicators if the live GameState disagrees.
    if gm~=1 and (sg==1 or metadataMode==1) then
        -- FindFirstOf may point to a stale GameState from the menu or prior
        -- level. Prefer an actually live Expedition state when one exists.
        for _,candidate in ipairs(all("HeldenGameState")) do
            if valid(candidate) and enum(get(candidate,"GameModeType"))==1 then
                gs=candidate;cache.HeldenGameState=candidate;gm=1;break
            end
        end
    end
    if gm~=1 and not (sg==1 and metadataMode==1) then return nil end
    local run=get(gs,"CurrentDungeonRun")
    if not run then return nil end
    return {gi=gi,gs=gs,save=save,run=run,
        phase=enum(get(run,"State")) or 0,
        failed=failure(get(run,"Flags"))}
end
local S={
    slot=nil,saveKey=nil,depth=0,highestSeed=0,offset=nil,
    active=false,failed=false,phase=nil,pending={},
    sample=0,lastPoll=-1,nextBackupDepth=-1,
    nextBackupTime=-1,coinLedger={},respawned=0,
    lastMode="unknown",lastDisplay=nil,warned=false,
    lastHeartbeat=-1000,lastGuard=nil,recoveryRequired=false,
    nextMachineRepair=0,machineRepairAttempts=0,
    dropQueue={},destructionSeen={},dropAttempt=0,
    deathEvents=0,newPawnEvents=0,rewardEvents=0,rawDeathEvents=0,rawDestroyEvents=0,heartbeatTicks=1000,machineRepairCycle=1000,
    players={},recoveries={},observedDeaths=0,failedBarriers=0,coinsLocated=0,
    unresolvedTreasureLogs=0,
    failureChecks=0
}
local function backupFile(slot)
    if not CFG.BackupFile then return nil end
    local base
    pcall(function() base=os.getenv("LOCALAPPDATA") end)
    if not base or base=="" then return nil end
    return base.."\\Helden\\Saved\\ExpeditionSaver_slot"..slot..".txt"
end
local function readBackup(slot,played,fails)
    local fname=backupFile(slot)
    if not fname or played==nil or fails==nil then return nil end
    local f=io.open(fname,"r")
    if not f then return nil end
    local line=f:read("*l");f:close()
    if not line then return nil end
    local ver,sl,d,t,ff=line:match("^(%S+) (%d+) (%d+) (%d+) (%d+)$")
    if ver~="EXPS1" or tonumber(sl)~=slot then return nil end
    local depth=number(d,0,CFG.MaxDepth)
    local oldTime=number(t,0,1000000000)
    local oldFails=number(ff,0,1000000000)
    if not depth or not oldTime or not oldFails then return nil end
    -- Never restore older progress to a brand-new game on the same slot.
    if played+5<oldTime or fails<oldFails then return nil end
    return depth
end
local function backupDepth(ctx,depth)
    if not CFG.BackupFile or depth<1 then return end
    if S.nextBackupDepth==depth then return end
    local slot=S.slot
    local time=number(get(ctx.save,"TimePlayed"),0,1000000000)
    local fails=number(get(ctx.save,"DungeonFails"),0,1000000000)
    local fname=slot and backupFile(slot)
    if not fname or time==nil or fails==nil then return end
    local f=io.open(fname,"w")
    if not f then return end
    f:write(string.format("EXPS1 %d %d %d %d\n",slot,depth,time,fails))
    f:close()
    S.nextBackupDepth=depth
end
local function resetForSave(ctx,key,slot)
    local oldSlot=S.slot
    local oldPending=S.pending
    local oldPlayers=S.players
    local oldRecoveries=S.recoveries
    local preserve=oldSlot==slot and (S.recoveryRequired or S.active or next(oldPending)~=nil)
    local oldDepth,oldSeed,oldOffset,oldActive,oldFailed=
        S.depth,S.highestSeed,S.offset,S.active,S.failed
    S.slot=slot;S.saveKey=key
    S.depth=number(get(ctx.save,"DungeonLevel"),0,CFG.MaxDepth) or 0
    if preserve and oldDepth>S.depth then S.depth=oldDepth end
    S.highestSeed=preserve and oldSeed or 0
    S.offset=preserve and oldOffset or nil
    S.active=preserve and oldActive or false
    S.failed=preserve and oldFailed or false
    S.phase=nil;S.pending=preserve and oldPending or {};S.coinLedger={}
    S.players=preserve and oldPlayers or {}
    S.recoveries=preserve and oldRecoveries or {}
    S.nextBackupDepth=-1
    S.dropQueue={};S.destructionSeen={}
    S.nextMachineRepair=0;S.machineRepairAttempts=0
    local time=number(get(ctx.save,"TimePlayed"),0,1000000000)
    local fails=number(get(ctx.save,"DungeonFails"),0,1000000000)
    local recovered=readBackup(slot,time,fails)
    if recovered and recovered>S.depth then S.depth=recovered end
    log("Expedition slot "..slot.." loaded; protected depth "..S.depth..
        " retainedRunState="..tostring(preserve))
end
local function keepExpedition(ctx)
    if not CFG.EnableNoPermadeath then return end
    -- EndScreen+Failed is sufficient even when no previous Exploring poll ran.
    if ctx.phase==3 and ctx.failed then
        if not S.recoveryRequired then log("RECOVERY detected directly from EndScreen/Failed") end
        S.active=true;S.failed=true;S.recoveryRequired=true
    end
    local raw=number(get(ctx.save,"DungeonLevel"),0,CFG.MaxDepth)
    if not raw then return end
    if raw>S.depth then S.depth=raw;diag("reached save depth "..raw) end
    local dungeon=get(ctx.run,"DungeonActor")
    local seed=get(dungeon,"CurrentSeed")
    local lv=number(get(seed,"Level"),0,CFG.MaxDepth)
    if ctx.phase==1 or ctx.phase==2 then
        if ctx.phase==1 and S.phase~=1 and S.recoveryRequired then
            S.recoveryRequired=false;S.machineRepairAttempts=0
            log("new expedition ride started; recovery finished")
        end
        S.active=true
        if lv then
            if raw>=lv and raw<=lv+1 then S.offset=raw-lv end
            if lv>S.highestSeed then S.highestSeed=lv end
        end
    end
    if S.highestSeed>0 then
        local goal=S.highestSeed+(S.offset or 0)
        if goal>S.depth then S.depth=goal end
    end
    if (ctx.phase==3 or ctx.phase==0) and S.active and ctx.failed then
        if not S.failed then
            S.failed=true;S.recoveryRequired=true
            log("failed Expedition run; keeping dungeon depth "..S.depth)
        end
    end
    -- Clear permanent flags even during Exploration: the native game may
    -- set them at the instant the last party member dies.
    local md=get(ctx.save,"MetaData")
    if md and get(md,"bHasFailed")==true then
        if put(md,"bHasFailed",false) then
            S.recoveryRequired=true
            log("suppressed permanent failure in SaveGame metadata")
        end
    end
    if get(ctx.gs,"bExpeditionFailed")==true then
        if put(ctx.gs,"bExpeditionFailed",false) then
            S.recoveryRequired=true
            log("cleared expedition failure in runtime")
        end
    end
    if ctx.phase==3 or ctx.phase==0 then
        -- Do not clear CurrentDungeonRun.Flags.Failed: the end screen uses it.
        if raw<S.depth and (S.failed or (ctx.phase==0 and not S.active)) then
            if put(ctx.save,"DungeonLevel",S.depth) then
                log("restored Expedition depth "..raw.." -> "..S.depth)
            end
        end
    end
    backupDepth(ctx,S.depth)
end

-- Record *existing* item actors, not classes or copies. No destructive array
-- operations on the new pawn; we never create duplicated item instances.
local function snapshotMoney(char)
    if not valid(char) then return nil end
    local money=get(char,"Money")
    if not money then return nil end
    local record={}
    for _,currency in ipairs({"Gold","Artifacts","Scraps"}) do
        record[currency]=number(get(money,currency),0,100000000) or 0
    end
    return record
end
local function recoverMoney(pawn,entry)
    if not CFG.EnableMoneyRecovery or not entry.money or not valid(pawn) then return false end
    local money=get(pawn,"Money")
    if not money then log("MONEY: new pawn has no Money struct");return false end
    local changed={}
    local verified=true
    for _,currency in ipairs({"Gold","Artifacts","Scraps"}) do
        local expected=entry.money[currency] or 0
        local current=number(get(money,currency),0,100000000)
        if current~=nil and current<expected then
            local ok=put(money,currency,expected)
            local actual=get(pawn,"Money")
            local after=number(get(actual,currency),0,100000000)
            changed[#changed+1]=currency..":"..current.."->"..tostring(after)
            verified=verified and ok and after~=nil and after>=expected
        end
    end
    if #changed>0 then
        log("MONEY RESTORE "..table.concat(changed,",")..
            " verified="..tostring(verified))
    else
        diag("MONEY RESTORE none required")
    end
    return verified
end
local function gearOf(char)
    if not valid(char) then return {} end
    local result,seen={},{}
    local function add(item,source,slotIndex)
        item=unwrap(item)
        if not valid(item) or #result>=CFG.MaxGearPerPlayer then return end
        local id=path(item)
        if not id or seen[id] then return end
        seen[id]=true
        local cls
        pcall(function() cls=item:GetClass() end)
        if not valid(cls) then return end
        local asset=get(item,"ItemDataAsset")
        result[#result+1]={ref=item,key=id,klass=cls,
            dynamicSaveName=asName(get(item,"DynamicSaveName")),
            classPath=path(cls),
            asset=asset,assetPath=valid(asset) and path(asset) or nil,
            durability=tonumber(get(item,"ItemDurability")),
            enchant=get(item,"ItemEnchantment"),
            slotIdx=number(get(item,"CurrentInventorySlot"),0,128) or slotIndex,
            source=source}
    end
    -- The game stores inventory items in BOTH EquipedItems and ItemSlots.
    -- Previously the latter was missing, explaining 1 retained item in log.
    each(get(char,"EquipedItems"),function(item,i) add(item,"EquipedItems",i-1) end)
    each(get(char,"ItemSlots"),function(slot,i)
        if valid(slot) then add(get(slot,"CurrentItemInSlot"),"ItemSlots",i-1) end
    end)
    local owner=path(char)
    for _,item in ipairs(all("HeldenEquipableItem")) do
        if valid(item) and path(get(item,"PreviousOwner"))==owner and
           valid(get(item,"CurrentSlot")) then
            add(item,"PreviousOwner")
        end
    end
    table.sort(result,function(a,b)
        return (a.slotIdx or 999)<(b.slotIdx or 999)
    end)
    return result
end
local function currentPawn(pc)
    if not valid(pc) then return nil end
    local ok,pawn=pcall(function() return pc:GetPawn() end)
    if ok and valid(pawn) then return pawn end
end
-- In real Expedition runs the native Die_Auth and Blueprint
-- OnPlayerKilled hook were NEVER called (observed v0.3 log).
-- Monitor actual controller/pawn state and preserve inventory BEFORE death.
local function queuePlayerDeath(pc,char,snapshot,reason)
    if not CFG.EnableRespawn or not onHost() then return false end
    local ctx=game()
    if not ctx or not (ctx.phase==2 or (ctx.phase==3 and (S.active or ctx.failed))) then return false end
    if not valid(pc) or (not valid(char) and snapshot==nil) then return false end
    local key=path(pc)
    if not key or S.pending[key] then return false end
    local player=false
    for _,candidate in ipairs(all("HeldenPlayerController")) do
        if path(candidate)==key then player=true;break end
    end
    if not player then return false end
    local inv=snapshot or gearOf(char)
    local tracked=S.players[key]
    local cash=(tracked and tracked.money) or snapshotMoney(char)
    S.pending[key]={controller=pc,oldChar=char,gear=inv,money=cash,
        started=os.clock(),ageTicks=0,attempts=0,nextRequestTick=0,
        spawned=nil,delivered=false}
    S.deathEvents=S.deathEvents+1
    log("PLAYER DEATH queued from "..tostring(reason).." controller="..key..
        " oldPawn="..tostring(path(char)).." retained="..#inv..
        " cash="..(cash and (cash.Gold.."/"..cash.Artifacts.."/"..cash.Scraps) or "nil")..
        " phase="..ctx.phase)
    return true
end
local function captureDeath(char)
    if not valid(char) then return end
    local pc
    pcall(function() pc=char:GetController() end)
    if valid(pc) then queuePlayerDeath(pc,char,nil,"Die_Auth") end
end
local function monitorPlayers(ctx)
    if not CFG.EnableRespawn or not (ctx.phase==2 or
        (ctx.phase==3 and (ctx.failed or S.active))) then return end
    for _,pc in ipairs(all("HeldenPlayerController")) do
        if valid(pc) then
            local key=path(pc)
            local tracking=S.players[key]
            if not tracking then
                tracking={alive=false,dead=false,lastPawn=nil,gear={},money=nil,
                    snapshotCycle=0,lastState=nil,lastHealth=nil}
                S.players[key]=tracking
            end
            local pawn=currentPawn(pc)
            local soul=get(pc,"SoulCharacter")
            local last=get(pc,"LastPlayerChar")
            local char
            if valid(soul) and valid(pawn) and path(soul)==path(pawn) and
               valid(last) and valid(get(last,"CharacterStats")) then
                char=last
            elseif valid(pawn) and valid(get(pawn,"CharacterStats")) then
                char=pawn
            elseif valid(last) and valid(get(last,"CharacterStats")) then
                char=last
            elseif valid(tracking.lastPawn) then
                char=tracking.lastPawn
            end
            local stats=char and get(char,"CharacterStats")
            local health=tonumber(get(stats,"CurrentHealth"))
            local state=enum(get(char,"CharacterState"))
            local isSoul=valid(soul) and valid(pawn) and path(soul)==path(pawn)
            local dead=(state==1 or (health and health<=0) or isSoul or
                (tracking.alive and ctx.phase==3 and ctx.failed))
            local activeCharacter=valid(char) and not dead and health and health>0
            if tracking.lastState~=state or tracking.lastHealth~=nil and
                    health and ((tracking.lastHealth>0)~=(health>0)) then
                log("PLAYER STATE controller="..tostring(key)..
                    " state="..tostring(state).." hp="..tostring(health)..
                    " soulPawn="..tostring(isSoul).." run="..ctx.phase)
            end
            tracking.lastState=state
            tracking.lastHealth=health
            if activeCharacter then
                tracking.lastPawn=char
                tracking.money=snapshotMoney(char) or tracking.money
                tracking.alive=true
                tracking.dead=false
                tracking.snapshotCycle=tracking.snapshotCycle+1
                if tracking.snapshotCycle>=4 or #tracking.gear==0 then
                    tracking.gear=gearOf(char)
                    tracking.snapshotCycle=0
                end
            elseif dead and not tracking.dead then
                tracking.dead=true
                if tracking.alive then
                    local ok=queuePlayerDeath(pc,tracking.lastPawn,
                        tracking.gear,"poll: CharacterState/Health/Soul/failed run")
                    if ok then S.observedDeaths=S.observedDeaths+1 end
                else
                    log("PLAYER DEAD but no prior alive snapshot; waiting for native event")
                end
            end
        end
    end
end

local function respawnLocation()
    local lift=first("HeldenDungeonElevator")
    if not valid(lift) then return nil end
    local comp=get(lift,"InteriorCollisionBox")
    local loc=location(comp) or location(lift)
    if not loc then return nil end
    return {X=loc.X,Y=loc.Y,Z=loc.Z+80}
end
local function heal(pawn)
    local stats=get(pawn,"CharacterStats")
    if not valid(stats) then return false end
    local max=tonumber(get(get(stats,"TotalStats"),"MaxHealth"))
    if not max or max<=0 or max>1000000 then return false end
    return put(stats,"CurrentHealth",max)
end
-- Item ownership must be transferred by the native Interact path. Moving
-- items to the lift ground (v0.4) only kept them in the world, not inventory.
-- Recover over multiple game-thread ticks to allow native equip replication.
local function snapshotNativeGear(pawn)
    local refs,byClass={},{ }
    local function track(item)
        item=unwrap(item)
        if not valid(item) then return end
        refs[path(item)]=true
        local klass
        pcall(function() klass=item:GetClass() end)
        local key=path(klass)
        if key then byClass[key]=(byClass[key] or 0)+1 end
    end
    each(get(pawn,"EquipedItems"),track)
    each(get(pawn,"ItemSlots"),function(slot)
        track(get(slot,"CurrentItemInSlot"))
    end)
    return refs,byClass
end
local function ownsItem(pawn,item)
    if not valid(pawn) or not valid(item) then return false end
    local refs=snapshotNativeGear(pawn)
    if refs[path(item)] then return true end
    local owner=get(item,"PreviousOwner")
    return valid(owner) and path(owner)==path(pawn) and
        valid(get(item,"CurrentSlot"))
end
local function collectAtElevator(entry,dest,pawn)
    if not CFG.EnableItemRecovery then return end
    local key=path(entry.controller)
    if not key then return end
    S.recoveries[key]={entry=entry,dest=dest,pawn=pawn,tick=0,
        done={},attempts={},recreated={},warnings={}}
    recoverMoney(pawn,entry)
    log("INVENTORY RECOVERY queued items="..#entry.gear..
        " cash="..(entry.money and
            entry.money.Gold.."/"..entry.money.Artifacts.."/"..entry.money.Scraps or "unknown"))
end
local function isOriginalItemAlreadyPresent(pawn,rec)
    if not valid(pawn) then return false end
    local refs=snapshotNativeGear(pawn)
    if refs[rec.key] then return true end
    -- Do not scan all world items for every saved item. Only the receiving
    -- pawn's inventory can prove that an item was actually restored.
    local dynamic=rec.dynamicSaveName
    if dynamic and dynamic~="None" and dynamic~="" then
        local found=false
        local function match(item)
            if valid(item) and asName(get(item,"DynamicSaveName"))==dynamic then
                found=true
            end
        end
        each(get(pawn,"EquipedItems"),match)
        each(get(pawn,"ItemSlots"),function(slot)
            match(get(slot,"CurrentItemInSlot"))
        end)
        if found then return true end
    end
    if rec.slotIdx~=nil and rec.classPath then
        -- If the native engine rebuilt the same slot with the same class,
        -- prefer that actor rather than creating a second instance.
        local items=get(pawn,"ItemSlots")
        local native
        pcall(function() native=get(items[rec.slotIdx+1],"CurrentItemInSlot") end)
        if valid(native) then
            local cls
            pcall(function() cls=native:GetClass() end)
            if path(cls)==rec.classPath then return true end
        end
    end
    return false
end
local function processInventoryRecoveries()
    if not CFG.EnableItemRecovery or not onHost() then return end
    for key,job in pairs(S.recoveries) do
        job.tick=job.tick+1
        local pawn=job.pawn
        if not valid(pawn) then
            log("INVENTORY RECOVERY aborted: pawn invalid")
            S.recoveries[key]=nil
        else
            local total=#job.entry.gear
            local retained=0
            -- Identity and native slot checks precede any spawns. A
            -- generic class-count match is unsafe: two swords of the same
            -- class are not one sword.
            for _,rec in ipairs(job.entry.gear) do
                if ownsItem(pawn,rec.ref) or
                   isOriginalItemAlreadyPresent(pawn,rec) then
                    job.done[rec.key]=true
                end
            end
            local unowned=0
            for i,rec in ipairs(job.entry.gear) do
                if job.done[rec.key] then
                    retained=retained+1
                else
                    unowned=unowned+1
                    local item=rec.ref
                    local tries=job.attempts[rec.key] or 0
                    local dest={X=job.dest.X+(i%5)*48-96,
                        Y=job.dest.Y+math.floor((i-1)/5)*48,
                        Z=job.dest.Z+25}
                    if not valid(item) and CFG.RestoreDestroyedItems and
                        not job.recreated[rec.key] and job.tick>=3 then
                        local klass=rec.klass
                        local world
                        pcall(function() world=pawn:GetWorld() end)
                        if not valid(world) then
                            local lift=first("HeldenDungeonElevator")
                            pcall(function() world=lift:GetWorld() end)
                        end
                        if valid(klass) and valid(world) then
                            local ok,new=pcall(function()
                                return world:SpawnActor(klass,dest,{Pitch=0,Yaw=0,Roll=0})
                            end)
                            job.recreated[rec.key]=true -- no repeat spawns
                            if ok and valid(new) then
                                rec.ref=new;item=new
                                if valid(rec.asset) then put(new,"ItemDataAsset",rec.asset) end
                                if rec.durability~=nil then
                                    put(new,"ItemDurability",rec.durability)
                                    pcall(function() new:OnRep_ItemDurability() end)
                                end
                                if rec.enchant~=nil then
                                    -- Preserve the original FName userdata,
                                    -- not an unsafe string->FName conversion.
                                    if put(new,"ItemEnchantment",rec.enchant) then
                                        pcall(function() new:OnRep_ItemEnchantment() end)
                                    end
                                end
                                -- Keep native unique ID generated by the engine.
                                log("INVENTORY recreated missing "..rec.key..
                                    " class="..tostring(rec.classPath))
                            else
                                log("INVENTORY cannot recreate "..rec.key)
                            end
                        end
                    end
                    if valid(item) and tries<CFG.InventoryRecoveryRetryTicks and
                        job.tick%2==1 then
                        job.attempts[rec.key]=tries+1
                        -- Don't destroy this actor: if native pickup rejects,
                        -- leaving it at the lift is better than losing it.
                        pcall(function() item:DetachFromAll() end)
                        pcall(function() item:SetSimulatePhysics(true) end)
                        local move=teleport(item,dest)
                        local pick,err=pcall(function() item:Interact(pawn) end)
                        if not ownsItem(pawn,item) then
                            local interact=get(item,"InteractComponent")
                            if valid(interact) then
                                local ok=pcall(function()
                                    job.entry.controller:Interact_Server(pawn,interact)
                                end)
                                pick=pick or ok
                            end
                        end
                        log("INVENTORY pickup "..rec.source..
                            " key="..rec.key.." move="..tostring(move)..
                            " nativeCall="..tostring(pick)..
                            " owned="..tostring(ownsItem(pawn,item))..
                            (pick and "" or " err="..tostring(err)))
                    end
                    if valid(item) and ownsItem(pawn,item) then
                        job.done[rec.key]=true
                    end
                end
            end
            -- Native pickup can be asynchronous; allow rep updates. After a
            -- bounded number of attempts, keep remaining actors on elevator
            -- floor, never claim full success.
            local allDone=true
            for _,rec in ipairs(job.entry.gear) do
                if not job.done[rec.key] then allDone=false;break end
            end
            if allDone or job.tick>=CFG.MaxInventoryRecoveryTicks then
                local recovered,failed=0,0
                for _,rec in ipairs(job.entry.gear) do
                    if job.done[rec.key] then recovered=recovered+1
                    else failed=failed+1 end
                end
                log("INVENTORY RESULT inventory="..recovered..
                    " floor_or_missing="..failed.." total="..total..
                    " fullyRestored="..tostring(failed==0))
                S.recoveries[key]=nil
            end
        end
    end
end

local function reviveOldPawn(entry)
    if not CFG.EnableExistingPawnReviveFallback then return false end
    local char,pc=entry.oldChar,entry.controller
    if not valid(char) or not valid(pc) then return false end
    local at=respawnLocation()
    if not at then
        log("REVIVE FALLBACK: elevator location unavailable")
        return false
    end
    -- A native respawn is always attempted first. After it fails, re-enable
    -- the *existing* character (and existing inventory) rather than cloning
    -- players or silently abandoning the expedition.
    local write=put(char,"CharacterState",0)
    put(char,"bCollisionAndMovementDisable",false)
    local hp=heal(char)
    local moved=teleport(char,at)
    if not write or not hp or not moved then
        log("REVIVE FALLBACK skipped possession: state/health/teleport verification failed")
        return false
    end
    pcall(function() char:SetActorEnableCollision(true) end)
    pcall(function() char:OnRep_CharacterState() end)
    pcall(function() char:OnRep_bCollisionAndMovementDisable() end)
    local possessed,why=pcall(function() pc:Possess(char) end)
    local owns=path(currentPawn(pc))==path(char)
    if possessed and owns then
        pcall(function() pc:ClientRestart(char) end)
    end
    log("REVIVE FALLBACK stateSet="..tostring(write)..
        " healed="..tostring(hp).." moved="..tostring(moved)..
        " possess="..tostring(possessed).." owned="..tostring(owns)..
        (possessed and "" or " error="..tostring(why)))
    if write and hp and moved and owns then
        collectAtElevator(entry,at,char)
        return true
    end
    return false
end
local function processDeaths(ctx)
    if not CFG.EnableRespawn then return end
    for key,entry in pairs(S.pending) do
        -- LoopAsync/LoopInGameThread use wall time. os.clock() is process CPU
        -- time on Windows; previously a "35-second" timeout could last minutes.
        entry.ageTicks=(entry.ageTicks or 0)+1
        if entry.ageTicks>120 then
            log("respawn timed out for "..key)
            S.pending[key]=nil
        else
            local pawn=currentPawn(entry.controller)
            if entry.spawned and valid(entry.spawned) then pawn=entry.spawned end
            local soul=get(entry.controller,"SoulCharacter")
            local isSoul=valid(soul) and valid(pawn) and path(soul)==path(pawn)
            if pawn and not isSoul and path(pawn)~=path(entry.oldChar) and
               valid(get(pawn,"CharacterStats")) then
                local at=respawnLocation()
                if at and teleport(pawn,at) then
                    local healed=heal(pawn)
                    collectAtElevator(entry,at,pawn)
                    log("respawn in elevator "..key.."; healed="..tostring(healed))
                    S.pending[key]=nil
                    S.respawned=S.respawned+1
                end
            elseif entry.attempts<CFG.MaxRespawnRequests and
                   entry.ageTicks>=(entry.nextRequestTick or 1) then
                entry.attempts=entry.attempts+1
                entry.nextRequestTick=entry.ageTicks+5
                local ok,err=pcall(function()
                    entry.controller:RespawnCharacter_Server()
                end)
                log("NATIVE RESPAWN request "..entry.attempts.." -> "..tostring(ok)..
                    (ok and "" or (": "..tostring(err))))
            elseif entry.attempts>=CFG.MaxRespawnRequests and
                   entry.ageTicks>=CFG.FallbackAfterTicks and
                   not entry.fallbackDone then
                entry.fallbackDone=true
                if reviveOldPawn(entry) then
                    log("REVIVE FALLBACK succeeded, recovered existing player pawn")
                    S.pending[key]=nil
                    S.respawned=S.respawned+1
                end
            end
        end
    end
end
-- Automatic payout on physical destruction. There is no hotkey.
-- The game still handles its native scrap/resource drops; we add only
-- the Gold/Artifacts that the *same actor* would pay at extraction.
-- IMPORTANT: Read live structs/tables, which also sees QOL's edited values.
local function rowOf(tableObject,rowName)
    if not valid(tableObject) or not rowName then return nil end
    local key=asName(rowName)
    local ok,row=pcall(function() return tableObject:FindRow(key) end)
    if ok and row then return unwrap(row) end
    ok,row=pcall(function() return tableObject:GetRowMap() end)
    if ok and type(row)=="table" then
        return unwrap(row[key])
    end
end
local function getDataSingleton()
    local ds=first("HeldenDataSingleton")
    if valid(ds) then return ds end
    -- The game's singleton may initially exist only through a CDO. Unlike
    -- generic actor searches, we can use its reflected static Get().
    local ok,list=pcall(FindAllOf,"HeldenDataSingleton")
    if ok and type(list)=="table" then
        for _,entry in ipairs(list) do
            if valid(entry) then
                local good,instance=pcall(function() return entry:Get() end)
                if good and valid(instance) then return instance end
            end
        end
    end
end
local function treasureDataKey(actor,ds)
    if not ds then return nil end
    local container=get(ds,"PhysTreasureContainer")
    if not valid(container) then return nil end
    local root=get(actor,"RootMesh")
    local mesh=get(root,"StaticMesh")
    if not valid(mesh) and valid(root) then
        pcall(function() mesh=root:GetStaticMesh() end)
    end
    if not valid(mesh) then return nil end
    local match=path(mesh)
    local key
    each(get(container,"TreasureData"),function(row)
        local rowMesh=get(row,"StaticMesh")
        if not key and valid(rowMesh) and path(rowMesh)==match then
            key=get(row,"DataName")
        end
    end)
    return key
end
local function lootValue(actor)
    if not valid(actor) then return nil end
    local id=path(actor) or ""
    local normalized=id:lower()
    -- Coin/pickup destruction must never recursively create currency.
    if normalized:find("coin",1,true) or normalized:find("pickup",1,true) then return nil end
    local ds=getDataSingleton()
    local inspected
    local inspectedZero
    pcall(function() inspected=actor:GetInspectData() end)
    if inspected and get(inspected,"bIsInDungeon")==true then
        local value=get(inspected,"Value")
        if value then
            local gold=number(get(value,"Gold"),0,CFG.MaxCoinsPerDrop) or 0
            local artifacts=number(get(value,"Artifacts"),0,CFG.MaxCoinsPerDrop) or 0
            if gold>0 or artifacts>0 then
                return {gold=gold,artifacts=artifacts,source="inspect"}
            end
            -- Some native physical treasure objects expose an inspect value
            -- of zero while their DataTable extraction value is nonzero.
            -- Try the actual data row before declaring no payout.
            inspectedZero={gold=0,artifacts=0,source="inspect-zero"}
        end
    end
    if not ds then return inspectedZero end
    -- Reflected actor DataName fields are used as keys; never infer rewards
    -- from an object's color or from an unrelated player's inventory.
    -- These are the actual reflected HeldenConstructActor methods.
    local struct
    pcall(function() struct=actor:GetConstructAssetData() end)
    local construct
    pcall(function() construct=actor:GetConstructAsset() end)
    if not struct and valid(construct) then
        struct=rowOf(get(ds,"ConstructAssetDataTable"),get(construct,"DataName"))
    end
    if struct then
        local quality=enum(get(actor,"ConstructQuality"))
        local key=quality==2 and "Parsed_ScrapValue_Epic"
            or quality==1 and "Parsed_ScrapValue_Rare"
            or "Parsed_ScrapValue_Common"
        local value=get(struct,key)
        if value then
            local gold=number(get(value,"Gold"),0,CFG.MaxCoinsPerDrop) or 0
            local artifacts=number(get(value,"Artifacts"),0,CFG.MaxCoinsPerDrop) or 0
            if gold>0 or artifacts>0 then
                return {gold=gold,artifacts=artifacts,
                    source="construct-asset-data",row=asName(get(struct,"DataName"))}
            end
            inspectedZero={gold=0,artifacts=0,source="construct-zero"}
        end
    end
    -- IMPORTANT: generic BP_DefaultPhysTreasure often has zero Construct
    -- scrap value. The actual reward lives in PhysActorData or in
    -- PhysTreasureContainer.TreasureData keyed by its current mesh.
    local candidates={}
    local seen={}
    local function candidate(value,source)
        local n=asName(value)
        if n and n~="None" and n~="" and not seen[n] then
            seen[n]=true
            candidates[#candidates+1]={key=value,name=n,source=source}
        end
    end
    candidate(get(actor,"StatsDataName"),"StatsDataName")
    candidate(get(actor,"ConstructDataName"),"ConstructDataName")
    candidate(get(get(actor,"InitConAsset"),"DataName"),"InitConAsset")
    candidate(get(get(actor,"SetupConstructAsset"),"DataName"),"SetupConstructAsset")
    candidate(get(construct,"DataName"),"GetConstructAsset")
    candidate(treasureDataKey(actor,ds),"TreasureData.StaticMesh")
    local tableObject=get(ds,"PhysActorDataTable")
    for _,entry in ipairs(candidates) do
        local row=rowOf(tableObject,entry.key)
        local value=row and get(row,"Parsed_ScrapReward")
        if value then
            local gold=number(get(value,"Gold"),0,CFG.MaxCoinsPerDrop) or 0
            local artifacts=number(get(value,"Artifacts"),0,CFG.MaxCoinsPerDrop) or 0
            if gold>0 or artifacts>0 then
                return {gold=gold,artifacts=artifacts,
                    source="physical-table:"..entry.source,row=entry.name}
            end
        end
    end
    if normalized:find("treasure",1,true) and
        S.unresolvedTreasureLogs<16 then
        S.unresolvedTreasureLogs=S.unresolvedTreasureLogs+1
        local names={}
        for _,entry in ipairs(candidates) do names[#names+1]=entry.name end
        log("TREASURE REWARD UNRESOLVED actor="..id..
            " quality="..tostring(enum(get(actor,"ConstructQuality")))..
            " candidates="..table.concat(names,",")..
            " inspect="..tostring(inspectedZero~=nil))
    end
    return inspectedZero
end
local function destructionEvent(ctx,origin)
    S.rawDestroyEvents=S.rawDestroyEvents+1
    local a=unwrap(ctx)
    if S.rawDestroyEvents<=10 then
        log("RAW DESTRUCTION "..origin.." actor="..tostring(path(a))..
            " host="..tostring(onHost()))
    end
    if not onHost() then return end
    local gameCtx=game()
    if not gameCtx or gameCtx.phase~=2 then
        if S.rawDestroyEvents<=10 then log("DROP SKIP: Expedition not recognized") end
        return
    end
    if not valid(a) or not valid(get(a,"StatsComponent")) then return end
    if get(a,"bIsQuestObjective")==true or
       get(a,"bRequireQuestObjectiveToKill")==true then return end
    -- Require an actual in-dungeon loot actor; never pay for built furniture.
    local owning=resolveWeak(get(a,"OwningDungeon"))
    local inspecting
    pcall(function() inspecting=a:GetInspectData() end)
    local inDungeon=inspecting and get(inspecting,"bIsInDungeon")==true
    if not inDungeon and not valid(owning) then
        if S.rawDestroyEvents<=10 then
            log("DROP SKIP: no valid dungeon origin for "..tostring(path(a)))
        end
        return
    end
    if origin=="health" then
        local hp=tonumber(get(get(a,"StatsComponent"),"CurrentHealth"))
        if not hp or hp>0 then return end
    end
    local key=path(a)
    if not key or S.destructionSeen[key] then return end
    S.rewardEvents=S.rewardEvents+1
    local value=lootValue(a)
    if not value then
        if S.rewardEvents<=15 then log("DESTRUCTION "..origin.." "..key.." (no reward data)") end
        return
    end
    if value.gold<=0 and value.artifacts<=0 then
        if S.rewardEvents<=15 then log("DESTRUCTION "..origin.." "..key.." (no coin payout)") end
        return
    end
    local at=location(a)
    local world
    pcall(function() world=a:GetWorld() end)
    if not at or not valid(world) then
        log("DESTRUCTION "..origin.." cannot resolve world/position; no payout")
        return
    end
    S.destructionSeen[key]=true
    S.dropQueue[#S.dropQueue+1]={world=world,at=at,key=key,
        gold=value.gold,artifacts=value.artifacts,source=value.source,
        queued=os.clock(),goldDone=false,artifactDone=false}
    log("DESTRUCTION queued "..key.." gold="..value.gold.." artifacts="..
        value.artifacts.." source="..value.source.." from="..origin)
end
local function spawnMoney(world,position,actorClass,amount,currency)
    if not valid(world) or not valid(actorClass) or amount<=0 then return false end
    -- Spawn above destroyed furniture so collision/physics can't bury the
    -- item inside the floor. v0.3 spawned at the old actor's pivot.
    local coinPosition={X=position.X,Y=position.Y,Z=position.Z+55}
    local ok,coin=pcall(function()
        return world:SpawnActor(actorClass,coinPosition,{Pitch=0,Yaw=0,Roll=0})
    end)
    if not ok or not valid(coin) then
        log("COIN SPAWN FAILED "..currency.." x"..amount.." error="..tostring(coin))
        return false
    end
    local money=get(coin,"Money")
    if not money then
        pcall(function() coin:K2_DestroyActor() end)
        return false
    end
    local success=put(money,"Gold",currency=="Gold" and amount or 0)
        and put(money,"Artifacts",currency=="Artifacts" and amount or 0)
        and put(money,"Scraps",0)
    -- Check the *actor's own* struct again; success on a Lua copy isn't enough.
    local actual=get(coin,"Money")
    success=success and number(get(actual,currency),0,CFG.MaxCoinsPerDrop)==amount
        and number(get(actual,"Scraps"),0,CFG.MaxCoinsPerDrop)==0
        and number(get(actual,currency=="Gold" and "Artifacts" or "Gold"),
            0,CFG.MaxCoinsPerDrop)==0
    if not success then
        -- Fallback for UScriptStruct wrappers returned as detached copies.
        pcall(function()
            coin.Money={
                Gold=currency=="Gold" and amount or 0,
                Artifacts=currency=="Artifacts" and amount or 0,
                Scraps=0
            }
        end)
        local actual2=get(coin,"Money")
        success=number(get(actual2,currency),0,CFG.MaxCoinsPerDrop)==amount
            and number(get(actual2,"Scraps"),0,CFG.MaxCoinsPerDrop)==0
            and number(get(actual2,currency=="Gold" and "Artifacts" or "Gold"),
                0,CFG.MaxCoinsPerDrop)==0
        if not success then
            pcall(function() coin:K2_DestroyActor() end)
            log("COIN INITIALIZATION FAILED "..currency.." x"..amount)
            return false
        end
    end
    -- Validating a UStruct does not prove the actor is visible/pickable.
    -- Enable standard Actor visibility, collision and replication, then
    -- read its final position back for evidence in a real UE4SS log.
    local replicated=pcall(function() coin:SetReplicates(true) end)
    local visible=pcall(function() coin:SetActorHiddenInGame(false) end)
    local collision=pcall(function() coin:SetActorEnableCollision(true) end)
    pcall(function() coin:K2_SetActorLocation(coinPosition,false,{},true) end)
    local actualPosition=location(coin)
    local mesh=get(coin,"RootMesh")
    local meshVisible,simulatesPhysics,hasGravity
    if valid(mesh) then
        -- A visible collidable actor without simulating mesh is static. v0.4
        -- forgot SetSimulatePhysics/SetEnableGravity, so coins hung in air.
        put(coin,"bCanSimulatePhysics",true)
        pcall(function() mesh:SetMobility(2) end) -- Movable
        pcall(function() mesh:SetVisibility(true,true) end)
        pcall(function() mesh:SetCollisionEnabled(3) end)
        local physicsOk,physicsErr=pcall(function() mesh:SetSimulatePhysics(true) end)
        local gravityOk,gravityErr=pcall(function() mesh:SetEnableGravity(true) end)
        pcall(function() mesh:WakeAllRigidBodies() end)
        pcall(function() coin:ForceNetUpdate() end)
        pcall(function() meshVisible=mesh:IsVisible() end)
        pcall(function() simulatesPhysics=mesh:IsSimulatingPhysics() end)
        pcall(function() hasGravity=mesh:IsGravityEnabled() end)
        if not physicsOk or not gravityOk or simulatesPhysics==false then
            log("COIN PHYSICS ERROR "..currency.." simulateCall="..tostring(physicsOk)..
                " gravityCall="..tostring(gravityOk)..
                " simulated="..tostring(simulatesPhysics)..
                " simulateError="..tostring(physicsErr)..
                " gravityError="..tostring(gravityErr))
        end
    end
    S.coinsLocated=S.coinsLocated+1
    if S.coinsLocated<=25 then
        local klass
        pcall(function() klass=coin:GetClass() end)
        log("COIN PHYSICAL "..currency.." x"..amount..
            " class="..tostring(path(klass))..
            " pos="..(actualPosition and
                (string.format("%.0f,%.0f,%.0f",
                    actualPosition.X,actualPosition.Y,actualPosition.Z)) or "UNKNOWN")..
            " replicatedCall="..tostring(replicated)..
            " unhiddenCall="..tostring(visible)..
            " collisionCall="..tostring(collision)..
            " meshVisible="..tostring(meshVisible)..
            " simulatesPhysics="..tostring(simulatesPhysics)..
            " gravity="..tostring(hasGravity))
    end
    return true
end
local function processDropQueue()
    if #S.dropQueue==0 or not onHost() then return end
    local ds=getDataSingleton()
    if not ds then return end
    local goldClass=get(ds,"GoldCoinActorClass")
    local artifactClass=get(ds,"ArtifactCoinActorClass")
    for i=#S.dropQueue,1,-1 do
        local job=S.dropQueue[i]
        job.attempts=(job.attempts or 0)+1
        -- This runs on the *next* 300ms engine-thread tick. No CPU-time
        -- delay: the v0.2 delay used os.clock and could stall drops.
        if true then
            local done=true
            if job.gold>0 and not job.goldDone then
                job.goldDone=spawnMoney(job.world,job.at,goldClass,job.gold,"Gold")
                if job.goldDone then
                    log("DROP gold="..job.gold.." "..job.key)
                else done=false end
            end
            if job.artifacts>0 and not job.artifactDone then
                local offset={X=job.at.X+65,Y=job.at.Y,Z=job.at.Z+25}
                job.artifactDone=spawnMoney(job.world,offset,artifactClass,
                    job.artifacts,"Artifacts")
                if job.artifactDone then
                    log("DROP artifacts="..job.artifacts.." "..job.key)
                else done=false end
            end
            if done or job.attempts>=10 then
                if not done then
                    log("WARNING partial/unpaid extraction reward: "..job.key..
                        " goldDone="..tostring(job.goldDone)..
                        " artifactsDone="..tostring(job.artifactDone))
                end
                table.remove(S.dropQueue,i)
            end
        end
    end
end

-- Game preserves an EndScreen/Failed state after the final death. Updating
-- DungeonLevel alone does NOT unlock the machine; repair the run AND its
-- interaction gate only after the elevator is back at the home station.
-- Expedition's door is a separate Blueprint actor, not the elevator
-- machine. v0.3 never touched BP_ExpeditionFailed_Actor_C; it remained solid
-- even after GameState flags were cleared (confirmed by live object dump).
local function repairFailedDoor(ctx)
    if not CFG.EnableNoPermadeath or not S.recoveryRequired then return end
    if ctx.phase==1 or ctx.phase==2 then return end
    local observed=0
    for _,barrier in ipairs(all("BP_ExpeditionFailed_Actor_C")) do
        local key=path(barrier)
        if valid(barrier) and key and
            key:find("PersistentLevel",1,true) and
            not key:find("Default__",1,true) then
            observed=observed+1
            local failed=get(barrier,"bFailedExpedition")
            if failed~=false then
                put(barrier,"bFailedExpedition",false)
                pcall(function() barrier:OnRep_bFailedExpedition() end)
                pcall(function() barrier:UpdateCollisionSate() end)
            end
            -- Regardless of BP flag, remove the physical door collision
            -- on the authoritative host. Never destroy the actor, which may
            -- have other OnObjetEvent handlers needed for the next run.
            pcall(function() barrier:SetActorEnableCollision(false) end)
            for _,component in ipairs({
                    get(barrier,"Box"),
                    get(barrier,"SM_SM_Door_Lock"),
                    get(barrier,"Cube")}) do
                if valid(component) then
                    pcall(function() component:SetCollisionEnabled(0) end)
                    pcall(function() component:SetVisibility(false,true) end)
                end
            end
            if S.failedBarriers<5 then
                local boxCollision
                local lockVisibility
                local c=get(barrier,"Box")
                local lock=get(barrier,"SM_SM_Door_Lock")
                if valid(c) then pcall(function() boxCollision=c:GetCollisionEnabled() end) end
                if valid(lock) then pcall(function() lockVisibility=lock:IsVisible() end) end
                log("FAILURE DOOR disabled actor="..key..
                    " wasFailed="..tostring(failed)..
                    " nowFailed="..tostring(get(barrier,"bFailedExpedition"))..
                    " boxCollision="..tostring(boxCollision)..
                    " lockVisible="..tostring(lockVisibility))
                S.failedBarriers=S.failedBarriers+1
            end
        end
    end
    if observed==0 and S.failedBarriers==0 then
        S.failedBarriers=-1
        log("FAILURE DOOR: no live BP_ExpeditionFailed_Actor_C found")
    end
end

local function repairElevator(ctx)
    if not CFG.EnableNoPermadeath or not S.recoveryRequired then return end
    if ctx.phase==1 or ctx.phase==2 then return end
    local now=os.clock()
    S.machineRepairCycle=S.machineRepairCycle+1
    if S.machineRepairCycle<5 or S.machineRepairAttempts>=10 then return end
    S.machineRepairCycle=0
    S.machineRepairAttempts=S.machineRepairAttempts+1
    local lift=first("HeldenDungeonElevator")
    local machine=valid(lift) and get(lift,"ElevatorMachine") or nil
    if not valid(machine) then machine=first("HeldenElevatorMachine") end
    if valid(lift) then
        local home=number(get(lift,"HomeStationIdx"),0,256)
        local station=number(get(lift,"CurrentStationIdx"),0,256)
        if home~=nil and station~=nil and home~=station then
            log("RECOVERY waiting for elevator at home; station="..station.." home="..home)
            return
        end
    elseif ctx.phase~=0 then
        log("RECOVERY waiting for home elevator (run="..ctx.phase..")")
        return
    end
    local run=get(ctx.gs,"CurrentDungeonRun")
    local before=enum(get(run,"State"))
    local flagsBefore=enum(get(run,"Flags"))
    local changed=true
    if before==3 then changed=put(run,"State",0) end
    if get(run,"Flags")~=nil then put(run,"Flags",0) end
    -- A reflected UStruct might be copy-on-read. Write it back to its
    -- GameState owner and verify that the actual source changed.
    if before==3 and enum(get(get(ctx.gs,"CurrentDungeonRun"),"State"))~=0 then
        put(ctx.gs,"CurrentDungeonRun",run)
    end
    local after=enum(get(get(ctx.gs,"CurrentDungeonRun"),"State"))
    local clear=after==0
    local interaction="not found"
    if valid(machine) then
        if get(machine,"bInteractionLocked")==true then
            put(machine,"bInteractionLocked",false)
        end
        -- The machine has a second, independent requirement gate.
        if get(machine,"bUseInteractRequirement")==true then
            put(machine,"bUseInteractRequirement",false)
        end
        local ok,why=pcall(function() machine:SetCanBeInteracted_Auth(true) end)
        if ok then interaction="unlocked" else interaction="error:"..tostring(why) end
        pcall(function() machine:OnRequirementSysUpdate_Auth() end)
        -- Recompute native elevator-button state using the restored run.
        if clear then
            pcall(function() machine:OnDungeonRunStateChanged(get(ctx.gs,"CurrentDungeonRun")) end)
        end
        -- Blueprint recomputation can reinstate these gate fields.
        put(machine,"bInteractionLocked",false)
        put(machine,"bUseInteractRequirement",false)
    end
    if valid(lift) and get(lift,"bInteractionLocked")==true then
        put(lift,"bInteractionLocked",false)
    end
    if clear then
        pcall(function() ctx.gs:OnRep_DungeonRunState() end)
    end
    log("RECOVERY run="..tostring(before).." -> "..tostring(after)..
        " flags="..tostring(flagsBefore).." -> "..
        tostring(enum(get(get(ctx.gs,"CurrentDungeonRun"),"Flags")))..
        " machine="..interaction.." attempt="..S.machineRepairAttempts)
    if after~=0 and S.machineRepairAttempts==10 then
        log("WARNING: cannot reset ended run; elevator may stay locked")
    end
end

local function poll()
    local now=os.clock()
    local host=onHost()
    local ctx=host and game()
    S.heartbeatTicks=S.heartbeatTicks+1
    if S.heartbeatTicks>=20 then
        S.heartbeatTicks=0
        local gs=first("HeldenGameState")
        local gi=first("HeldenGameInstance")
        local save=gi and get(gi,"CurrentSaveGame")
        log("HEARTBEAT host="..tostring(host)..
            " GS="..tostring(path(gs))..
            " mode="..tostring(enum(get(gs,"GameModeType")))..
            " save="..tostring(valid(save))..
            " saveMode="..tostring(enum(get(save,"GameMode")))..
            " phase="..tostring(ctx and ctx.phase)..
            " rawPhase="..tostring(enum(get(get(gs,"CurrentDungeonRun"),"State")))..
            " flags="..tostring(enum(get(get(gs,"CurrentDungeonRun"),"Flags")))..
            " expeditionFailed="..tostring(get(gs,"bExpeditionFailed"))..
            " savedFailed="..tostring(get(get(save,"MetaData"),"bHasFailed"))..
            " recovery="..tostring(S.recoveryRequired)..
            " deaths="..S.deathEvents.." rawDeaths="..S.rawDeathEvents..
            " destructionEvents="..S.rewardEvents..
            " rawDestructions="..S.rawDestroyEvents..
            " playerControllers="..#all("HeldenPlayerController")..
            " failureDoors="..#all("BP_ExpeditionFailed_Actor_C")..
            " failureChecks="..S.failureChecks)
    end
    if not ctx then
        if S.lastMode~="nonexpedition" then
            S.lastMode="nonexpedition"
            log("inactive: missing authoritative Expedition context")
        end
        return
    end
    S.lastMode="expedition"
    local md=get(ctx.save,"MetaData")
    local slot=number(get(md,"GameSlot"),0,100)
    if not slot then return end
    local key=path(ctx.save)
    if S.slot~=slot or S.saveKey~=key then resetForSave(ctx,key,slot) end
    keepExpedition(ctx)
    monitorPlayers(ctx)
    processDeaths(ctx)
    processInventoryRecoveries()
    repairElevator(ctx)
    repairFailedDoor(ctx)
    processDropQueue()
    if ctx.phase==1 or ctx.phase==2 then
        if S.phase==0 or S.phase==3 then
            cache["HeldenDungeonElevator"]=nil
        end
    end
    if S.phase~=ctx.phase then
        log("run state "..tostring(S.phase).." -> "..ctx.phase.."; depth="..S.depth)
    end
    S.phase=ctx.phase
end

local function isExpeditionDeath()
    if not onHost() then return false end
    local ctx=game()
    return ctx and (ctx.phase==2 or (ctx.phase==3 and (S.active or ctx.failed)))
end
local function watchDeath(context)
    S.rawDeathEvents=S.rawDeathEvents+1
    local character=unwrap(context)
    if S.rawDeathEvents<=12 then
        local ctx=game()
        log("RAW DIE_Auth actor="..tostring(path(character))..
            " host="..tostring(onHost())..
            " phase="..tostring(ctx and ctx.phase)..
            " accepted="..tostring(isExpeditionDeath()))
    end
    if not valid(character) or not isExpeditionDeath() then return end
    captureDeath(character)
end
local function watchControllerKilled(context)
    local pc=unwrap(context)
    if valid(pc) then
        log("RAW OnPlayerKilled controller="..tostring(path(pc))..
            " accepted="..tostring(isExpeditionDeath()))
    end
    if not valid(pc) or not isExpeditionDeath() then return end
    local old=get(pc,"LastPlayerChar")
    if valid(old) then captureDeath(old) end
end
local function immediatelyRequestRespawn(context)
    local pc=unwrap(context)
    if not valid(pc) or not onHost() then return end
    local entry=S.pending[path(pc)]
    if not entry or entry.attempts>0 then return end
    entry.attempts=1
    entry.nextRequestTick=(entry.ageTicks or 0)+5
    local ok,err=pcall(function() pc:RespawnCharacter_Server() end)
    log("IMMEDIATE RESPAWN on OnPlayerKilled post -> "..tostring(ok)..
        (ok and "" or ": "..tostring(err)))
end
local function watchReplicatedDeadState(context)
    local character=unwrap(context)
    if not valid(character) or enum(get(character,"CharacterState"))~=1 then return end
    for _,pc in ipairs(all("HeldenPlayerController")) do
        if valid(pc) then
            local key=path(pc)
            local record=S.players[key]
            local old=record and record.lastPawn
            if record and record.alive and valid(old) and
               path(old)==path(character) then
                queuePlayerDeath(pc,character,record.gear,
                    "OnRep_CharacterState Dead")
                return
            end
        end
    end
end
local function watchNewPawn(context,oldPawn,newPawn)
    local pc=unwrap(context)
    local pawn=unwrap(newPawn)
    if not valid(pc) or not valid(pawn) then return end
    S.newPawnEvents=S.newPawnEvents+1
    local entry=S.pending[path(pc)]
    if entry then entry.spawned=pawn;log("NEWPAWN event for pending death") end
end
local registered={}
local retries={}
local knownHooks={}
local function hook(f,pre,post)
    if not knownHooks[f] then knownHooks[f]={pre=pre,post=post} end
    if registered[f] then return end
    local now=os.clock()
    if retries[f] and now<retries[f] then return end
    retries[f]=now+CFG.RetryHookSeconds
    local ok,a,b=pcall(function() return RegisterHook(f,pre,post) end)
    if ok and a~=nil then
        registered[f]=true
        log("HOOK ACTIVE "..f)
    else
        log("HOOK NOT READY "..f.." (will retry): "..tostring(a))
    end
end
local function safePre(label,cb)
    return function(...)
        local ok,err=pcall(cb,...)
        if not ok then log("HOOK "..label.." callback failed: "..tostring(err)) end
    end
end
local function safePostBool(cb)
    return function(...)
        local ok,result=pcall(cb,...)
        if ok then return result end
        log("HOOK return override failed: "..tostring(result))
    end
end
local function retryHooks()
    for f,spec in pairs(knownHooks) do
        if not registered[f] then hook(f,spec.pre,spec.post) end
    end
end
-- Native hooks run on the engine thread; no worker threads modify UObjects.
hook("/Script/Helden.HeldenCharacter:Die_Auth",
     safePre("Die_Auth",watchDeath))
hook("/Script/Helden.HeldenCharacter:OnRep_CharacterState",
     safePre("OnRep_CharacterState",watchReplicatedDeadState))
hook("/Script/Helden.HeldenPlayerController:OnPlayerKilled",
     safePre("OnPlayerKilled",watchControllerKilled),
     safePre("OnPlayerKilledPost",function(context,...)
         watchControllerKilled(context,...)
         immediatelyRequestRespawn(context)
     end))
hook("/Script/Helden.HeldenPlayerController:OnNewPawn",
     function() end,safePre("OnNewPawn",watchNewPawn))
if CFG.EnableNoPermadeath then
    -- Native post-hook return override, documented in UE4SS RegisterHook.
    -- A false result is intentionally restricted to the Expedition game
    -- mode and authoritative host; it does not touch normal saves.
    hook("/Script/Helden.HeldenGameState:HasFailedExpedition",
        function() end,
        safePostBool(function(context)
            S.failureChecks=S.failureChecks+1
            local gs=unwrap(context)
            local ctx=onHost() and game()
            if S.failureChecks<=5 then
                log("HAS FAILED check event host="..tostring(onHost())..
                    " ctx="..tostring(ctx and ctx.phase))
            end
            if valid(gs) and ctx and path(ctx.gs)==path(gs) then
                return false
            end
        end))
    hook("/Script/Helden.HeldenGameState:EndDungeonRunSequence_Multicast",
        safePre("EndDungeonRunSequence",function(context,statsArg)
            local gs=unwrap(context)
            local ctx=onHost() and game()
            if not ctx or path(ctx.gs)~=path(gs) then return end
            local stats=unwrap(statsArg)
            if get(stats,"bHaveFailed")==true then
                S.failed=true;S.recoveryRequired=true
                local depth=number(get(stats,"DungeonLevel"),0,CFG.MaxDepth)
                if depth and depth>S.depth then S.depth=depth end
                log("END RUN failure event; protected depth="..S.depth)
            end
        end))
    hook("/Script/Helden.HeldenInteractableObject:CanBeInteracted",
        function() end,
        safePostBool(function(context)
            if not S.recoveryRequired or not onHost() then return end
            local ctx=game()
            if not ctx or (ctx.phase~=0 and ctx.phase~=3) then return end
            local machine=first("HeldenElevatorMachine")
            if valid(machine) and path(machine)==path(unwrap(context)) then return true end
        end))
end
-- Capture the destruction signal from the engine, not keyboard actions.
-- Health==0 handles direct damage. Multicast catches non-health-based breakage.
hook("/Script/Helden.HeldenPhysicsActor:OnHealthModifed",
     safePre("health pre",function(context) destructionEvent(context,"health") end),
     safePre("health post",function(context) destructionEvent(context,"health") end))
hook("/Script/Helden.HeldenPhysicsActor:PlayDestructionEffect_Mulitcast",
     safePre("destruction",function(context) destructionEvent(context,"effect") end))
local function safePoll(onTimer)
    local now=os.clock()
    -- The engine-thread delayed loop already throttles callbacks. os.clock
    -- measures CPU time on Windows and must NOT gate that loop; otherwise
    -- pauses/slow frames can postpone a respawn until after party wipe.
    if not onTimer then
        if S.lastPoll>=0 and now>=S.lastPoll and
            now-S.lastPoll<CFG.PollSeconds then return end
    end
    S.lastPoll=now
    retryHooks()
    local ok,err=pcall(poll)
    if not ok and not S.warned then
        S.warned=true;log("poll error: "..tostring(err))
    end
end
local function heartbeat()
    S.sample=S.sample+1
    if S.sample<CFG.AnimationSample then return end
    S.sample=0
    safePoll()
end
-- Persistent game-thread polling is crucial: when the final player dies,
-- BlueprintUpdateAnimation may stop entirely. UE4SS v3 has LoopAsync and
-- ExecuteInGameThread; v4 also has a direct game-thread timer.
local scheduled=false
if type(LoopInGameThreadWithDelay)=="function" then
    local ok=pcall(function()
        LoopInGameThreadWithDelay(300,function() safePoll(true) end)
    end)
    if ok then scheduled=true;log("game-thread timer active (300 ms)") end
elseif type(LoopAsync)=="function" and type(ExecuteInGameThread)=="function" then
    local ok=pcall(function()
        LoopAsync(300,function()
            pcall(function() ExecuteInGameThread(function() safePoll(true) end) end)
            return false
        end)
    end)
    if ok then scheduled=true;log("UE4SS v3 async timer -> game-thread queue active") end
end
if not scheduled then
    log("WARNING: no independent timer; animation-hook fallback may stop during party wipe")
    hook("/Game/Animation/ABP_HeldenPlayer.ABP_HeldenPlayer_C:BlueprintUpdateAnimation",
         function() heartbeat() end)
end
hook("/Script/Engine.PlayerController:ClientRestart",
     function()
         cache={};S.lastPoll=-1;S.sample=CFG.AnimationSample-1
         S.coinLedger={}
         S.dropQueue={};S.destructionSeen={}
     end)
log("v0.3.0-alpha loaded: live hook diagnostics and verified-reflection fixes")
