-- Mock the UE4SS key binding API; this test never launches Grain Rot.
local code="ue4ss/Mods/ExpeditionMapper/Scripts/main.lua"
local messages={}
local callbacks={}
local calls={maps=0,objects=0}
local env=setmetatable({
    print=function(line) messages[#messages+1]=line end,
    Key={F8=119,F9=120},
    RegisterKeyBind=function(key,fn)
        assert(not callbacks[key],"duplicate key")
        callbacks[key]=fn
    end,
    DumpUSMAP=function() calls.maps=calls.maps+1 end,
    DumpAllObjects=function() calls.objects=calls.objects+1 end,
},{__index=_G})
env._G=env
assert(loadfile(code,"t",env))()
assert(type(callbacks[119])=="function")
assert(type(callbacks[120])=="function")
assert(calls.maps==0 and calls.objects==0, "dump must not run automatically")
callbacks[119]()
assert(calls.maps==1 and calls.objects==0, "F8 must dump USMAP only")
callbacks[120]()
assert(calls.maps==1 and calls.objects==1, "F9 must dump objects only")
assert(#messages>=4)
print("PASS: collector registers manual keys, runs only requested dumpers")

local failed=false
local errors={}
local env2=setmetatable({
    Key={F8=119,F9=120},
    RegisterKeyBind=function(_,_) end,
    print=function(message) errors[#errors+1]=message end,
    DumpUSMAP=function() failed=true;error("unavailable data") end,
    DumpAllObjects=function() end,
},{__index=_G})
env2._G=env2
local binds={}
env2.RegisterKeyBind=function(key,fn) binds[key]=fn end
assert(loadfile(code,"t",env2))()
binds[119]()
assert(failed, "dumper should attempt selected key")
assert(table.concat(errors):find("ERROR in USMAP (automatically named Helden-*.usmap)",1,true),"must log dumper failures")
print("PASS: dumper failure is contained and reported")
