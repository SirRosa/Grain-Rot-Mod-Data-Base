-- Expedition Saver UE4SS mock suite. The native game is NOT running here.
local MAIN="ue4ss/Mods/ExpeditionSaver/Scripts/main.lua"
local function actor(fields)
    local a=fields or {}
    function a:IsValid() return self._valid~=false end
    function a:GetFullName() return self._name or tostring(self) end
    return a
end
local function fixture()
    local now=0
    local registry,hooks,keys,files,logs,spawned={},{},{},{},{},{}
    local counts={clock=0,first=0,all=0,respawn=0,teleport=0}
    local gm=actor({_name="GameMode /Game/GM"})
    local md={GameSlot=0,GameMode=1,bHasFailed=false}
    local save=actor({_name="SaveGame /Game/S0",MetaData=md,GameMode=1,
        DungeonLevel=2,TimePlayed=30,DungeonFails=0})
    local gi=actor({_name="HeldenGameInstance /Game/Instance",CurrentSaveGame=save})
    local lift=actor({_name="HeldenDungeonElevator /Game/Lift",InteriorCollisionBox=actor(),
        HomeStationIdx=0,CurrentStationIdx=0,bInteractionLocked=false})
    local machine=actor({_name="HeldenElevatorMachine /Game/Machine",bInteractionLocked=true})
    lift.ElevatorMachine=machine
    local function component()
        local c=actor()
        function c:SetCollisionEnabled(v) self.collision=v end
        function c:SetVisibility(v) self.visible=v end
        return c
    end
    local barrier=actor({_name="BP_ExpeditionFailed_Actor_C /Game/Maps/Helden_Expedition.Helden_Expedition:PersistentLevel.BP_ExpeditionFailed_Actor_C_1",
        bFailedExpedition=true,Box=component(),SM_SM_Door_Lock=component(),Cube=component()})
    function barrier:OnRep_bFailedExpedition() self.onrep=true end
    function barrier:UpdateCollisionSate() self.updated=true end
    function barrier:SetActorEnableCollision(v) self.collision=v end
    function machine:SetCanBeInteracted_Auth(value) self.interactionEnabled=value end
    function machine:OnRequirementSysUpdate_Auth() end
    function machine:OnDungeonRunStateChanged(r) self.lastRun=r.State end
    function lift.InteriorCollisionBox:K2_GetComponentLocation()
        return {X=1000,Y=2000,Z=300}
    end
    local dungeon=actor({CurrentSeed={Level=1}})
    local run={State=2,Flags=0,DungeonActor=dungeon}
    local gs=actor({_name="HeldenGameState /Game/GS",GameModeType=1,bExpeditionFailed=false,
        CurrentDungeonRun=run})
    function gs:OnRep_DungeonRunState() self.repCount=(self.repCount or 0)+1 end
    local stats=actor({CurrentHealth=0,TotalStats={MaxHealth=120}})
    local corpse=actor({_name="HeldenCharacter /Game/Old",EquipedItems={},CharacterStats=stats,
        Money={Gold=80,Artifacts=4,Scraps=17},ItemSlots={}})
    local newPawn=actor({_name="HeldenPlayerCharacter /Game/New",CharacterStats=
        actor({CurrentHealth=1,TotalStats={MaxHealth=120}}),
        Money={Gold=0,Artifacts=0,Scraps=0},
        ItemSlots={actor({_name="NewPlayerSlot 1"}),actor({_name="NewPlayerSlot 2"})},
        EquipedItems={}})
    function newPawn:K2_TeleportTo(at,rot)
        counts.teleport=counts.teleport+1
        self.location=at
        return true
    end
    local pc=actor({_name="HeldenPlayerController /Game/PC",LastPlayerChar=corpse})
    function corpse:GetController() return pc end
    function corpse:K2_GetActorLocation() return {X=1000,Y=2000,Z=300} end
    function pc:GetPawn() return self._pawn end
    pc._pawn=corpse
    function pc:IsLocalController() return true end
    function pc:RespawnCharacter_Server()
        counts.respawn=counts.respawn+1
        self._pawn=newPawn
    end
    local gearClass=actor({_name="Class /Game/BP_TestSword"})
    local item=actor({_name="HeldenEquipableItem /Game/A",CurrentInventorySlot=0,
        PreviousOwner=corpse,CurrentSlot=actor({_name="ItemSlot"})})
    function item:GetClass() return gearClass end
    function item:DetachFromAll() self.detached=true;self.CurrentSlot=nil end
    function item:SetSimulatePhysics(v) self.simulates=v end
    function item:Interact(player)
        self.PreviousOwner=player
        for i,slot in ipairs(player.ItemSlots or {}) do
            if not slot.CurrentItemInSlot then
                slot.CurrentItemInSlot=self
                self.CurrentSlot=slot
                self.CurrentInventorySlot=i-1
                return
            end
        end
    end
    corpse.ItemSlots={actor({CurrentItemInSlot=item})}
    function item:K2_TeleportTo(at,rot)
        self.location=at
        self.wasMoved=true
        return true
    end
    corpse.EquipedItems={item}
    registry.GameModeBase=gm;registry.HeldenGameInstance=gi
    registry.HeldenGameState=gs;registry.HeldenDungeonElevator=lift
    registry.HeldenElevatorMachine=machine
    registry.HeldenGameMode=gm
    local data=actor({_name="DataSingleton /Game/DS"})
    local coinClass=actor({_name="Class /Game/BP_ArtifactCoin"})
    local goldClass=actor({_name="Class /Game/BP_GoldCoin"})
    data.ArtifactCoinActorClass=coinClass
    data.GoldCoinActorClass=goldClass
    local physTable=actor()
    function physTable:FindRow(key)
        if tostring(key)=="RustyJunk" then
            return {Parsed_ScrapReward={Gold=45,Artifacts=2,Scraps=1}}
        end
    end
    data.PhysActorDataTable=physTable
    registry.HeldenDataSingleton=data
    local loot=actor({_name="HeldenConstructActor /Game/EpicLoot",ConstructQuality=2,
        OwningDungeon=dungeon,StatsComponent=actor({CurrentHealth=0})})
    function loot:K2_GetActorLocation() return {X=1000,Y=1980,Z=300} end
    function loot:GetInspectData() return {bIsInDungeon=true,Value={Gold=20,Artifacts=6,Scraps=5}} end
    function loot:K2_DestroyActor() self._valid=false end
    local itComp=actor()
    function itComp:GetOwner() return loot end
    pc.CurrentInteractTarget=itComp
    function newPawn:K2_GetActorLocation() return {X=1000,Y=2000,Z=300} end
    local world=actor({_name="World /Game/World"})
    function loot:GetWorld() return world end
    function newPawn:GetWorld() return world end
    function lift:GetWorld() return world end
    function world:SpawnActor(cls,loc,rot)
        assert(cls==coinClass or cls==goldClass or cls==gearClass)
        local coin=actor(cls==gearClass and {ItemDurability=0,ItemDataAsset=nil} or
            {Money={Artifacts=0,Gold=0,Scraps=0}})
        coin._coinClass=cls
        if cls==gearClass then
            function coin:Interact(player)
                self.PreviousOwner=player
                for i,slot in ipairs(player.ItemSlots or {}) do
                    if not slot.CurrentItemInSlot then
                        slot.CurrentItemInSlot=self
                        self.CurrentSlot=slot
                        self.CurrentInventorySlot=i-1
                        return
                    end
                end
            end
            function coin:DetachFromAll() end
            function coin:K2_TeleportTo(v) self._position=v;return true end
        else
            local root=actor()
            function root:SetMobility(m) self.mobility=m end
            function root:SetVisibility(v) self.visible=v end
            function root:SetCollisionEnabled(v) self.collision=v end
            function root:SetSimulatePhysics(v) self.simulates=v end
            function root:SetEnableGravity(v) self.gravity=v end
            function root:WakeAllRigidBodies() self.awake=true end
            function root:IsSimulatingPhysics() return self.simulates end
            function root:IsGravityEnabled() return self.gravity end
            function root:IsVisible() return self.visible end
            coin.RootMesh=root
        end
        coin._position={X=loc.X,Y=loc.Y,Z=loc.Z}
        function coin:K2_DestroyActor() self._valid=false end
        function coin:SetReplicates(v) self.replicates=v end
        function coin:SetActorHiddenInGame(v) self.hidden=v end
        function coin:SetActorEnableCollision(v) self.collision=v end
        function coin:K2_SetActorLocation(v) self._position=v;return true end
        function coin:K2_GetActorLocation() return self._position end
        function coin:GetClass() return self._coinClass end
        spawned[#spawned+1]={coin=coin,loc=loc}
        return coin
    end
    local listing={HeldenPlayerController={pc},HeldenEquipableItem={item},
        BP_ExpeditionFailed_Actor_C={barrier}}
    local clockcb
    local fakeio={open=function(fname,mode)
        if mode=="r" then
            local v=files[fname]
            if not v then return nil end
            return {read=function() return v:match("([^\r\n]+)") end,
                    close=function() end}
        end
        assert(mode=="w")
        return {write=function(_,text) files[fname]=text end,
                close=function() end}
    end}
    local env=setmetatable({
        os={clock=function() counts.clock=counts.clock+1;return now end,
            getenv=function() return "C:\\Users\\Tester\\AppData\\Local" end},
        io=fakeio,
        print=function(msg) logs[#logs+1]=msg end,
        FindFirstOf=function(cls) counts.first=counts.first+1;return registry[cls] end,
        FindAllOf=function(cls) counts.all=counts.all+1;return listing[cls] or {} end,
        RegisterHook=function(name,pre,post)
            hooks[name]={pre=pre,post=post}
            return 100,101
        end,
        RegisterKeyBind=function(key,callback) keys[key]=callback end,
        Key={F7=118},
        LoopInGameThreadWithDelay=function(ms,callback)
            assert(ms==300);clockcb=callback;return 1
        end,
        ExecuteInGameThread=function(callback) callback() end,
    },{__index=_G})
    env._G=env
    assert(loadfile(MAIN,"t",env))()
    assert(clockcb,"game-thread timer not registered")
    local test={
        gm=gm,save=save,md=md,gi=gi,gs=gs,run=run,
        lift=lift,machine=machine,barrier=barrier,
        pc=pc,corpse=corpse,newPawn=newPawn,item=item,loot=loot,
        world=world,registry=registry,listing=listing,spawned=spawned,
        hooks=hooks,keys=keys,logs=logs,files=files,counts=counts,
        tick=function(dt) now=now+(dt or 0.7);clockcb() end,
        killed=function()
            local h=hooks["/Script/Helden.HeldenCharacter:Die_Auth"]
            assert(h and h.pre)
            h.pre(corpse)
        end,
        destroyLoot=function()
            local h=hooks["/Script/Helden.HeldenPhysicsActor:OnHealthModifed"]
            local d=hooks["/Script/Helden.HeldenPhysicsActor:PlayDestructionEffect_Mulitcast"]
            assert(h and d,"destruction hooks not registered")
            h.pre(loot)
            d.pre(loot)
        end,
        switchMode=function(mode)
            gs.GameModeType=mode;save.GameMode=mode;md.GameMode=mode
        end
    }
    return test
end
local passed=0
local function test(title,callback)
    callback()
    passed=passed+1
    print("PASS: "..title)
end
test("in expedition, depth and permadeath markers survive party wipe",function()
    local t=fixture()
    t.save.DungeonLevel=10;t.run.DungeonActor.CurrentSeed.Level=9
    t.tick()
    t.run.State=3;t.run.Flags=1;t.save.DungeonLevel=0
    t.md.bHasFailed=true;t.gs.bExpeditionFailed=true
    t.tick()
    assert(t.save.DungeonLevel==10,"depth must be restored")
    assert(t.md.bHasFailed==false and t.gs.bExpeditionFailed==false,
        "permadeath marker must clear on failed run")
end)
test("normal game is completely unchanged",function()
    local t=fixture()
    t.switchMode(0)
    t.md.bHasFailed=true
    t.gs.bExpeditionFailed=true
    t.run.State=3;t.run.Flags=1
    t.save.DungeonLevel=0
    t.tick()
    assert(t.save.DungeonLevel==0 and t.md.bHasFailed and t.gs.bExpeditionFailed)
    assert(t.counts.respawn==0)
end)
test("saved depth backup remains per-slot and never compounds",function()
    local t=fixture()
    t.save.DungeonLevel=5
    t.run.DungeonActor.CurrentSeed.Level=4
    t.tick()
    local count=0 for _ in pairs(t.files) do count=count+1 end
    assert(count==1 and t.files["C:\\Users\\Tester\\AppData\\Local\\Helden\\Saved\\ExpeditionSaver_slot0.txt"])
    t.tick()
    local count2=0 for _ in pairs(t.files) do count2=count2+1 end
    assert(count2==1)
end)
test("death of player uses native server respawn, then teleports to lift",function()
    local t=fixture()
    t.tick()
    t.killed()
    t.tick(1.5)
    assert(t.counts.respawn==1,"native server respawn should be requested")
    t.tick()
    assert(t.newPawn.location and t.newPawn.location.Z==380,"should respawn inside lift")
    assert(t.newPawn.CharacterStats.CurrentHealth==120,"health should restore")
    assert(t.counts.respawn==1,"no duplicate respawn")
end)
test("existing equipped item is picked into new pawn inventory, not left on elevator floor",function()
    local t=fixture();t.tick();t.killed();t.tick(1.5)
    for i=1,4 do t.tick(0) end
    assert(t.item.wasMoved and t.item.detached)
    assert(#t.spawned==0)
    assert(t.newPawn.ItemSlots[1].CurrentItemInSlot==t.item)
    assert(t.item.PreviousOwner==t.newPawn)
end)
test("respawn request still happens when the game prematurely ends the expedition",function()
    local t=fixture();t.tick();t.killed()
    t.run.State=3;t.run.Flags=1
    t.tick(2)
    assert(t.counts.respawn==1,"post-wipe recovery should not silently cancel death")
end)
test("AI character death is ignored",function()
    local t=fixture();t.tick()
    local npc=actor({_name="NPC /Game/Enemy"})
    local ai=actor({_name="AIController /Game/AI"})
    function npc:GetController() return ai end
    t.hooks["/Script/Helden.HeldenCharacter:Die_Auth"].pre(npc)
    t.tick(2)
    assert(t.counts.respawn==0)
end)
test("hammer destruction automatically emits the original extraction values",function()
    local t=fixture();t.tick()
    t.destroyLoot()
    t.tick(1)
    assert(#t.spawned==2,"should drop gold and artifact coin actors")
    assert(t.spawned[1].coin.Money.Gold==20)
    assert(t.spawned[2].coin.Money.Artifacts==6)
    assert(t.loot._valid~=false,"mod must not destroy loot itself")
    assert(t.keys[118]==nil,"F7 must not be registered")
end)
test("two destruction signals never double-pay the same loot",function()
    local t=fixture();t.tick()
    t.destroyLoot();t.destroyLoot();t.tick(1)
    assert(#t.spawned==2)
    t.tick(1);assert(#t.spawned==2)
end)
test("scrap/resource payout remains native, no added scrap coin",function()
    local t=fixture();t.tick();t.destroyLoot();t.tick(1)
    assert(#t.spawned==2)
    assert(t.spawned[1].coin.Money.Scraps==0)
    assert(t.spawned[2].coin.Money.Scraps==0)
end)
test("no rewards for actor outside dungeon",function()
    local t=fixture();t.tick()
    t.loot.OwningDungeon=nil
    t.loot.GetInspectData=function() return {bIsInDungeon=false,Value={Gold=40,Artifacts=8}} end
    t.destroyLoot();t.tick(1)
    assert(#t.spawned==0)
end)
test("no payout for zero coin value",function()
    local t=fixture();t.tick()
    t.loot.GetInspectData=function() return {bIsInDungeon=true,Value={Gold=0,Artifacts=0,Scraps=10}} end
    t.destroyLoot();t.tick(1)
    assert(#t.spawned==0)
end)
test("missing physical currency asset cannot invent the reward",function()
    local t=fixture();t.tick()
    t.registry.HeldenDataSingleton.ArtifactCoinActorClass=nil
    t.destroyLoot();t.tick(10)
    assert(#t.spawned==1,"Gold may succeed, but Artifact Coins must not be invented")
end)
test("PhysActorData fallback reads already patched QOL reward, without multiplying",function()
    local t=fixture();t.tick()
    t.loot.GetInspectData=nil
    t.loot.ConstructDataName="RustyJunk"
    t.destroyLoot();t.tick(1)
    assert(#t.spawned==2)
    assert(t.spawned[1].coin.Money.Gold==45)
    assert(t.spawned[2].coin.Money.Artifacts==2)
end)
test("hammer destruction below health zero is required for health trigger",function()
    local t=fixture();t.tick()
    t.loot.StatsComponent.CurrentHealth=10
    local h=t.hooks["/Script/Helden.HeldenPhysicsActor:OnHealthModifed"]
    h.pre(t.loot);t.tick(1)
    assert(#t.spawned==0)
    t.loot.StatsComponent.CurrentHealth=0
    h.pre(t.loot);t.tick(1)
    assert(#t.spawned==2)
end)
test("elevator machine is unlocked after expedition wipe at home station",function()
    local t=fixture();t.tick()
    t.run.State=3;t.run.Flags=1;t.md.bHasFailed=true
    t.tick(2)
    assert(t.run.State==0,"run must leave EndScreen")
    assert(t.run.Flags==0,"stale failure must be cleared")
    assert(t.machine.interactionEnabled==true)
    assert(t.machine.bInteractionLocked==false)
end)
test("elevator recovery defers if elevator has not reached home station",function()
    local t=fixture();t.tick()
    t.lift.CurrentStationIdx=1
    t.run.State=3;t.run.Flags=1;t.md.bHasFailed=true
    t.tick(2)
    assert(t.run.State==3)
    assert(not t.machine.interactionEnabled)
end)
test("client-only mode never changes save or coins",function()
    local t=fixture();t.tick()
    t.gm._valid=false;t.registry.GameModeBase=nil
    t.run.State=3;t.run.Flags=1
    t.md.bHasFailed=true;t.gs.bExpeditionFailed=true
    t.tick()
    assert(t.md.bHasFailed and t.gs.bExpeditionFailed)
    t.destroyLoot();t.tick(1);assert(#t.spawned==0)
end)
test("a timer is independent of animation callback after all players die",function()
    local t=fixture()
    assert(t.hooks["/Game/Animation/ABP_HeldenPlayer.ABP_HeldenPlayer_C:BlueprintUpdateAnimation"]==nil,
        "timer should replace hot animation hook")
    t.run.State=3;t.run.Flags=1;t.md.bHasFailed=true
    t.tick()
    assert(t.md.bHasFailed==false)
end)
test("do not detach items the game already equipped on respawn",function()
    local t=fixture();t.tick();t.killed()
    t.newPawn.EquipedItems={t.item}
    t.item.PreviousOwner=t.newPawn
    t.tick(1.5);t.tick()
    assert(t.item.detached~=true and not t.item.wasMoved,
        "native equipped items must remain in native inventory")
end)
test("do not convert Epic quest artifacts",function()
    local t=fixture();t.tick()
    t.loot.bIsQuestObjective=true
    t.destroyLoot();t.tick(1)
    assert(#t.spawned==0 and t.loot._valid~=false)
end)

test("HasFailedExpedition overridden only on authoritative Expedition",function()
    local t=fixture();t.tick()
    local cb=t.hooks["/Script/Helden.HeldenGameState:HasFailedExpedition"]
    assert(cb and type(cb.post)=="function","native post-hook missing")
    assert(cb.post(t.gs)==false,"must suppress permadeath in Expedition")
    t.switchMode(0)
    assert(cb.post(t.gs)==nil,"normal mode must be unaffected")
    t.switchMode(1)
    t.gm._valid=false;t.registry.GameModeBase=nil
    assert(cb.post(t.gs)==nil,"client may not override server failure")
end)
test("permadeath markers cleared during exploration, not only at end screen",function()
    local t=fixture();t.tick()
    t.md.bHasFailed=true;t.gs.bExpeditionFailed=true
    t.tick(1)
    assert(t.md.bHasFailed==false and t.gs.bExpeditionFailed==false)
end)

test("destroyed equipped item is reconstructed at most once and picked up",function()
    local t=fixture();t.tick();t.killed()
    t.item._valid=false
    for i=1,8 do t.tick(0) end
    assert(#t.spawned==1,"must spawn only one replacement")
    assert(t.newPawn.ItemSlots[1].CurrentItemInSlot==t.spawned[1].coin)
    for i=1,6 do t.tick(0) end
    assert(#t.spawned==1,"no second replacement after delivery")
end)

test("OnPlayerKilled post requests respawn in the same engine event",function()
    local t=fixture();t.tick();t.killed()
    local event=t.hooks["/Script/Helden.HeldenPlayerController:OnPlayerKilled"]
    assert(event and event.post)
    event.post(t.pc)
    assert(t.counts.respawn==1,"must not wait for wipe/end screen")
    t.tick(1)
    assert(t.newPawn.location and t.newPawn.location.Z==380)
    assert(t.counts.respawn==1,"no double native respawn")
end)
test("Expedition mode recovery accepts metadata after runtime mode resets",function()
    local t=fixture();t.tick()
    t.gs.GameModeType=0
    t.save.GameMode=1;t.md.GameMode=1
    t.md.bHasFailed=true
    t.tick(1)
    assert(t.md.bHasFailed==false)
end)

test("real HeldenConstructActor getter and weak dungeon pointer produce QOL payout",function()
    local t=fixture();t.tick(0)
    t.loot.GetInspectData=nil
    t.loot.OwningDungeon={Get=function() return t.run.DungeonActor end}
    function t.loot:GetConstructAssetData()
        return {Parsed_ScrapValue_Epic={Gold=60,Artifacts=4,Scraps=5}}
    end
    t.destroyLoot();t.tick(0)
    assert(#t.spawned==2)
    assert(t.spawned[1].coin.Money.Gold==60)
    assert(t.spawned[2].coin.Money.Artifacts==4)
    assert(t.spawned[1].coin.Money.Scraps==0)
end)
test("physics loot with no GetInspectData uses patched PhysActorData and weak ownership",function()
    local t=fixture();t.tick(0)
    t.loot.GetInspectData=nil
    t.loot.OwningDungeon={Get=function() return t.run.DungeonActor end}
    t.loot.StatsDataName="RustyJunk"
    t.destroyLoot();t.tick(0)
    assert(#t.spawned==2)
    assert(t.spawned[1].coin.Money.Gold==45)
    assert(t.spawned[2].coin.Money.Artifacts==2)
end)
test("respawn and loot payout do not wait for os.clock CPU time",function()
    local t=fixture();t.tick(0);t.killed()
    t.tick(0)
    assert(t.counts.respawn==1,"respawn should start on next engine tick")
    t.tick(0)
    assert(t.newPawn.location and t.newPawn.location.Z==380)
    t.destroyLoot();t.tick(0)
    assert(#t.spawned==2,"coin payout should not need CPU-time to elapse")
end)
test("run recovery starts on failed EndScreen even without earlier exploring heartbeat",function()
    local t=fixture()
    t.run.State=3;t.run.Flags=1;t.md.bHasFailed=true
    t.tick(0)
    assert(t.run.State==0 and not t.md.bHasFailed)
    assert(t.machine.interactionEnabled==true)
end)
test("same-slot save instance swap retains depth and recovery",function()
    local t=fixture();t.save.DungeonLevel=8;t.tick(0)
    local newSave=actor({_name="SaveGame /Game/S0_new",MetaData={GameSlot=0,GameMode=1,bHasFailed=true},
        GameMode=1,DungeonLevel=0,TimePlayed=30,DungeonFails=0})
    t.gi.CurrentSaveGame=newSave
    t.run.State=3;t.run.Flags=1;t.tick(0)
    assert(newSave.DungeonLevel==8,"depth should survive save object rotation")
    assert(newSave.MetaData.bHasFailed==false)
end)

test("the physical Expedition Failed door is actually disabled",function()
    local t=fixture();t.tick()
    t.run.State=3;t.run.Flags=1;t.md.bHasFailed=true
    t.tick(2)
    assert(t.barrier.bFailedExpedition==false)
    assert(t.barrier.onrep and t.barrier.updated)
    assert(t.barrier.collision==false)
    assert(t.barrier.Box.collision==0)
    assert(t.barrier.SM_SM_Door_Lock.visible==false)
end)
test("poll detects player death without Die_Auth or OnPlayerKilled callbacks",function()
    local t=fixture()
    t.corpse.CharacterState=0;t.corpse.CharacterStats.CurrentHealth=120
    t.tick(0)
    t.corpse.CharacterState=1;t.corpse.CharacterStats.CurrentHealth=0
    t.tick(0)
    assert(t.counts.respawn==1,"must respawn on observed Dead character state")
    t.tick(0)
    assert(t.newPawn.location and t.newPawn.location.Z==380)
end)
test("coin payout reports physical position above item, with visibility and replication",function()
    local t=fixture();t.tick(0);t.destroyLoot();t.tick(0)
    assert(#t.spawned==2)
    for _,record in ipairs(t.spawned) do
        assert(record.coin.replicates==true)
        assert(record.coin.hidden==false)
        assert(record.coin.collision==true)
        assert(record.coin._position.Z>=355, "coin must spawn above furniture pivot")
        assert(record.coin.RootMesh.simulates==true and
            record.coin.RootMesh.gravity==true,
            "coin must simulate physical gravity")
    end
end)
test("zero inspect payout falls back to patched live table",function()
    local t=fixture();t.tick(0)
    t.loot.StatsDataName="RustyJunk"
    t.loot.GetInspectData=function()
        return {bIsInDungeon=true,Value={Gold=0,Artifacts=0,Scraps=1}}
    end
    t.destroyLoot();t.tick(0)
    assert(#t.spawned==2)
    assert(t.spawned[1].coin.Money.Gold==45)
    assert(t.spawned[2].coin.Money.Artifacts==2)
end)
test("nil game mode is safely stringified in diagnostic heartbeat",function()
    local t=fixture()
    t.gs.GameModeType=nil
    t.save.GameMode=nil;t.md.GameMode=nil
    t.tick(0)
    for _,line in ipairs(t.logs) do assert(not line:find("poll error",1,true)) end
end)

test("after native respawn RPC is ignored, revive original pawn instead of soul",function()
    local t=fixture()
    t.corpse.CharacterState=0;t.corpse.CharacterStats.CurrentHealth=120
    function t.corpse:K2_TeleportTo(at) self.location=at;return true end
    function t.pc:Possess(pawn) self._pawn=pawn end
    function t.pc:ClientRestart(pawn) self._clientRestarted=true end
    function t.corpse:OnRep_CharacterState() self.replicatedState=true end
    t.tick(0)
    t.corpse.CharacterState=1;t.corpse.CharacterStats.CurrentHealth=0
    t.pc.RespawnCharacter_Server=function(self)
        t.counts.respawn=t.counts.respawn+1
        -- Simulates server rejecting native respawn in Expedition EndScreen
    end
    for i=1,18 do t.tick(0) end
    assert(t.counts.respawn==3,"must try native respawn first")
    assert(t.pc:GetPawn()==t.corpse,"must possess original pawn after failed RPCs")
    assert(t.corpse.CharacterState==0 and t.corpse.CharacterStats.CurrentHealth==120)
    assert(t.corpse.location.Z==380 and t.pc._clientRestarted)
end)
test("possessed soul is never mistaken for a successfully respawned player",function()
    local t=fixture()
    t.corpse.CharacterState=0;t.corpse.CharacterStats.CurrentHealth=120
    t.tick(0)
    t.corpse.CharacterState=1;t.corpse.CharacterStats.CurrentHealth=0
    local soul=actor({_name="HeldenSoul /Game/Soul",CharacterStats=
        actor({CurrentHealth=5,TotalStats={MaxHealth=10}})})
    t.pc.SoulCharacter=soul
    t.pc._pawn=soul
    t.pc.RespawnCharacter_Server=function(self)
        t.counts.respawn=t.counts.respawn+1
    end
    t.tick(0)
    assert(t.counts.respawn==1,"soul should not count as native respawn")
    assert(not soul.location,"soul must not be teleported to lift as player")
end)

test("OnRep Dead hook catches player death without native Die_Auth callback",function()
    local t=fixture()
    t.corpse.CharacterState=0;t.corpse.CharacterStats.CurrentHealth=120
    t.tick(0)
    local h=t.hooks["/Script/Helden.HeldenCharacter:OnRep_CharacterState"]
    assert(h and h.pre,"replicated dead-state hook must be registered")
    t.corpse.CharacterState=1;t.corpse.CharacterStats.CurrentHealth=0
    h.pre(t.corpse)
    t.tick(0)
    assert(t.counts.respawn==1)
end)
test("end-of-run failure queues a tracked player even when original actor vanished",function()
    local t=fixture()
    t.corpse.CharacterState=0;t.corpse.CharacterStats.CurrentHealth=120
    t.tick(0)
    t.corpse._valid=false
    t.run.State=3;t.run.Flags=1
    t.tick(0)
    assert(t.counts.respawn==1,"failed run must not require old Pawn still existing")
end)

test("all three carried currencies survive a normal native respawn",function()
    local t=fixture();t.tick(0);t.killed()
    for i=1,6 do t.tick(0) end
    assert(t.newPawn.Money.Gold==80)
    assert(t.newPawn.Money.Artifacts==4)
    assert(t.newPawn.Money.Scraps==17)
    for i=1,5 do t.tick(0) end
    assert(t.newPawn.Money.Gold==80 and t.newPawn.Money.Artifacts==4,
        "restoring money twice must not duplicate currency")
end)
test("native respawn keeps higher balances while recovering missing currencies",function()
    local t=fixture();t.newPawn.Money.Gold=150;t.newPawn.Money.Artifacts=2
    t.tick(0);t.killed()
    for i=1,5 do t.tick(0) end
    assert(t.newPawn.Money.Gold==150)
    assert(t.newPawn.Money.Artifacts==4)
    assert(t.newPawn.Money.Scraps==17)
end)
test("inventory slots not listed under EquipedItems are also recovered",function()
    local t=fixture()
    local item2=actor({_name="HeldenEquipableItem /Game/B",CurrentInventorySlot=1,
        PreviousOwner=t.corpse,CurrentSlot=actor({_name="OldSlot2"})})
    function item2:GetClass() return t.item:GetClass() end
    function item2:DetachFromAll() self.CurrentSlot=nil end
    function item2:SetSimulatePhysics(v) end
    function item2:K2_TeleportTo(v) self.location=v;return true end
    item2.Interact=t.item.Interact
    t.corpse.ItemSlots[2]=actor({CurrentItemInSlot=item2})
    t.listing.HeldenEquipableItem[2]=item2
    t.corpse.CharacterState=0;t.corpse.CharacterStats.CurrentHealth=120
    t.tick(0)
    t.corpse.CharacterState=1;t.corpse.CharacterStats.CurrentHealth=0
    for i=1,8 do t.tick(0) end
    assert(t.newPawn.ItemSlots[1].CurrentItemInSlot==t.item)
    assert(t.newPawn.ItemSlots[2].CurrentItemInSlot==item2)
    assert(item2.PreviousOwner==t.newPawn)
end)
test("default physics treasure uses mesh-matched live QOL PhysActorData reward",function()
    local t=fixture();t.tick(0)
    t.loot.GetInspectData=function()
        return {bIsInDungeon=true,Value={Gold=0,Artifacts=0,Scraps=0}}
    end
    t.loot.GetConstructAssetData=function()
        return {Parsed_ScrapValue_Epic={Gold=0,Artifacts=0}}
    end
    local m=actor({_name="StaticMesh /Game/TreasureMesh"})
    t.loot.RootMesh=actor({StaticMesh=m})
    t.registry.HeldenDataSingleton.PhysTreasureContainer=
        actor({TreasureData={{DataName="RustyJunk",StaticMesh=m}}})
    t.destroyLoot();t.tick(0)
    assert(#t.spawned==2,"generic treasure should not stop at zero ConstructAsset value")
    assert(t.spawned[1].coin.Money.Gold==45)
    assert(t.spawned[2].coin.Money.Artifacts==2)
end)
test("failed native pickup never destroys the only surviving item",function()
    local t=fixture()
    t.item.Interact=function() error("game rejected pickup") end
    t.tick(0);t.killed()
    for i=1,30 do t.tick(0) end
    assert(t.item:IsValid())
    assert(t.item.location and t.item.location.Z>=380,
        "unrecovered object must still be at elevator")
    assert(t.newPawn.ItemSlots[1].CurrentItemInSlot==nil)
    local warned=false
    for _,line in ipairs(t.logs) do
        if line:find("floor_or_missing=1",1,true) then warned=true end
    end
    assert(warned,"must not falsely report fully restored inventory")
end)

print("ALL TESTS PASSED ("..passed..")")
