ToyBox = ToyBox or {}
ToyBox.Mounted = ToyBox.Mounted or {}
if not engine.oGetAddons then engine.oGetAddons = engine.GetAddons end
if CLIENT then
    function engine.GetAddons()
        local a = engine.oGetAddons()
        for k,v in pairs(ToyBox.Mounted) do
            table.insert(a,v)
        end
        return a
    end
end

local function log(s)
    print(s)
end

local function ply_auth(ply)
    return ply:IsAdmin()
end

local function LoadWeapon(f,c,loaded_weps)
    SWEP = {
        Primary = {},
        Secondary = {},
        folder = "weapons/" .. f
    }
    include(f)
    weapons.Register(SWEP,c)
    loaded_weps[c] = SWEP
    print("Registered weapon: " .. c .. " (" .. f ..")")
    SWEP = nil
end

local function LoadEffect(f,c) 
    EFFECT = {}
    include(f)
    effects.Register(EFFECT,c)
    print("Registered effect: " .. c)
    EFFECT = nil
end

local function LoadEntity(f,c,entities)
    ENT = {}
    include(f)
    scripted_ents.Register(ENT,c)
    entities[c] = ENT
    ENT = nil
    print("Registered entity: " .. c)
end

local function LoadStools()
    SWEP = {
        Primary = {},
        Secondary = {},
        Folder = "weapons/gmod_tool"
    }
    include("weapons/gmod_tool/shared.lua")
end

local function Mount(s,wsid)    
    local loaded_weps = {}
    local entities = {}
    local models = {}
    local a,b = game.MountGMA(s)
    print("Mounted addon: ", a)
    if not a then ErrorNoHalt("Could not mount addon: " .. s) return end
    for k,v in pairs(b) do
        if v:match("lua/autorun") then
            if v:match("autorun/client") and CLIENT and (not v:gsub("(.*)lua/autorun/client/",""):match("%/")) then
                print("Running clientside file: " .. v .. " [include(" .. "autorun/" .. v:gsub("(.*)lua/autorun/","") .. ")]")
                include("autorun/" .. v:gsub("(.*)lua/autorun/",""))
            elseif v:match("autorun/server") and SERVER and (not v:gsub("(.*)lua/autorun/server/",""):match("%/")) then
                print("Running serverside file: " .. v .. " [include(" .. "autorun/" .. v:gsub("(.*)lua/autorun/","") .. ")]")
                include("autorun/" .. v:gsub("(.*)lua/autorun/",""))
            elseif (not v:gsub("(.*)lua/autorun/",""):match("%/")) then
                print("Running shared file: " .. v .. " [include(" .. "autorun/" .. v:gsub("(.*)lua/autorun/","") .. ")]")
                include("autorun/" .. v:gsub("(.*)lua/autorun/",""))
            end
        end
        if v:match("mdl$") then
            table.insert(models,v)
        end
        if string.GetPathFromFilename(v) == "lua/weapons/" then
            local a = string.GetFileFromFilename(v)
            LoadWeapon("weapons/" .. a,a:gsub(".lua$",""),loaded_weps)
        end
        
        if v:match("lua/weapons/(.*)/shared.lua$") then
            local a = string.GetFileFromFilename(v)
            local b = v:gsub("lua/weapons/",""):gsub(a,""):gsub("/","")
            LoadWeapon("weapons/" .. b .. "/" .. a,b,loaded_weps)
        end

        if v:match("lua/weapons/(.*)/init.lua$") and SERVER then
            local a = string.GetFileFromFilename(v)
            local b = v:gsub("lua/weapons/",""):gsub(a,""):gsub("/","")
            LoadWeapon("weapons/" .. b .. "/" .. a,b,loaded_weps)
        end

        if v:match("lua/weapons/(.*)/cl_init.lua$") and CLIENT then
            local a = string.GetFileFromFilename(v)
            local b = v:gsub("lua/weapons/",""):gsub(a,""):gsub("/","")
            LoadWeapon("weapons/" .. b .. "/" .. a,b,loaded_weps)
        end

        --[[
            Entities
        ]]

        if string.GetPathFromFilename(v) == "lua/entities/" then
            local a = string.GetFileFromFilename(v)
            LoadEntity("entities/" .. a,a:gsub(".lua$",""),entities)
        end

        if v:match("lua/entities/(.*)/init.lua$") and SERVER then
            local a = string.GetFileFromFilename(v)
            local b = v:gsub("lua/entities/",""):gsub(a,""):gsub("/","")
            LoadEntity("entities/" .. b .. "/" .. a,b,entities)
        end

        if v:match("lua/entities/(.*)/cl_init.lua$") and CLIENT then
            local a = string.GetFileFromFilename(v)
            local b = v:gsub("lua/entities/",""):gsub(a,""):gsub("/","")
            LoadEntity("entities/" .. b .. "/" .. a,b,entities)
        end

        if string.GetPathFromFilename(v) == "lua/effects/" and CLIENT then
            local a = string.GetFileFromFilename(v)
            LoadEffect("effects/" .. a,a:gsub(".lua$",""),entities)
        end

        if v:match("stools") then
            LoadStools()
        end

    end
    print("Reloading entities..")
    if CLIENT then 
        print("Reloading spawn menu..")
        --RunConsoleCommand("spawnmenu_reload") -- Can't just reload gamemode????
    end
    print("Done! files loaded: ")
    for k,v in pairs(b) do
        print("\t->" .. v)
    end
    print("Loaded weapons: ")
    for k,v in pairs(loaded_weps) do
        print("\t->" .. k)
    end
    print("Loaded entitiess: ")
    for k,v in pairs(entities) do
        print("\t->" .. k)
    end
    print(#models)

    if SERVER then
        net.Start("ToyBox.AddonLoaded")
        net.WriteString(wsid)
        net.Broadcast()
    end

    return models,loaded_weps,entities
end

local A_P, HTML

function ToyBox.isMounted(id)
    for k,v in pairs(engine.GetAddons()) do
        if tostring(v.wsid) == tostring(id) then
            return true
        end
    end
    return false
end
ToyBox.Downloading = false
local function LoadAddon_cl(fileid)
    if ToyBox.isMounted(fileid) then return end
    steamworks.FileInfo( fileid, function( result )
        if not result.fileid then ErrorNoHalt("Could not find addon with FileID: " .. fileid .. "!") return end
        print("Downloading file: " .. fileid .. "(" .. result.title .. ")")
        ToyBox.Downloading = result.title
        if ToyBox.DoLoad then ToyBox.DoLoad() end
        steamworks.Download( result.fileid, true, function( name )
                ToyBox.Downloading = false
                -- Cache is handled internally
                ToyBox.LastTitle = result.title
                print("Downloaded " .. fileid .. ", mounting..")
                local models, weapons, entities = Mount(name)
                if LocalPlayer().Host then
                    print("Sending addon to server")
                    net.Start("ToyBox.Load")
                    net.WriteString(name)
                    net.WriteString(fileid)
                    net.SendToServer()
                end
                table.insert(ToyBox.Mounted,{
                    downloaded = true,
                    file = name,
                    mounted = true,
                    models = #models or 0,
                    tags = "",
                    title = result.title,
                    wsid = fileid,
                    _models = models,
                    weapons = weapons,
                    entities = entities
                })
        end )
    end )
end

ToyBox.Waiting = nil

if SERVER then
    listen_server = false
    hook.Add("InitPostEntity","ListenServer",function()
        print(774)
        print(v)
        for k,v in pairs(player.GetAll()) do
            if v:IsListenServerHost() then
                listen_server = true
                timer.Simple(2.5,function() -- have to wait ofr network string
                    net.Start("ToyBox.Listen")
                    net.WriteBool(true)
                    net.Send(v)
                end)
            end
        end
    end)
    for k,v in pairs(player.GetAll()) do
        if v:IsListenServerHost() then
            listen_server = true
            timer.Simple(2.5,function() -- have to wait ofr network string
                net.Start("ToyBox.Listen")
                net.WriteBool(true)
                net.Send(v)
            end)
        end
    end
    util.AddNetworkString("ToyBox.Load")
    util.AddNetworkString("ToyBox.Listen")
    util.AddNetworkString("ToyBox.AddonLoaded")
    util.AddNetworkString("ToyBox.StartLoad")
    net.Receive("ToyBox.Load",function(l,ply)
        if ply:IsListenServerHost() and listen_server then
            local name = net.ReadString()
            local wsid = net.ReadString()
            print("Mounting addon serverside: " .. name)
            Mount(name,wsid)
        elseif listen_server then
            local wsid = net.ReadString()
            net.Start("ToyBox.StartLoad")
            net.WriteString(wsid)
            net.Broadcast()
        end
    end)
    hook.Add("PlayerInitialSpawn","Listen",function(ply)
        net.Start("ToyBox.Listen")
        net.WriteBool(listen_server)
        net.Send(ply)
    end)
else
	net.Receive("ToyBox.StartLoad",function()
        local wsid = net.ReadString()
        local host = net.ReadBool()
        ToyBox.Loading = true
        if host then
            LocalPlayer().Host = true
            LoadAddon_cl(wsid)
        end
    end)
    listen_server = false
	net.Receive("ToyBox.Listen",function()
        LocalPlayer().Host = net.ReadBool()
    end)
    net.Receive("ToyBox.AddonLoaded",function()
        local wsid = net.ReadString()
        if ToyBox.FinishLoad then ToyBox.FinishLoad() end
        print("REceive Loaded")
        if ToyBox.Waiting then
            for k,v in pairs(ToyBox.Mounted) do
                if tostring(v.wsid) == tostring(wsid) then
                    print(1336)
                    for i,o in pairs(v.weapons) do
                        if i == ToyBox.Waiting then
                            RunConsoleCommand("gm_giveswep",i)
                            surface.PlaySound("garrysmod/content_downloaded.wav")
                            ToyBox.Waiting = nil
                            print("Swep",i)
                            return
                        end
                    end
                    for i,o in pairs(v.entities) do
                        if i == ToyBox.Waiting then
                            RunConsoleCommand("gm_spawnsent",i)
                            surface.PlaySound("garrysmod/content_downloaded.wav")
                            print("Sent",i)
                            ToyBox.Waiting = nil
                            return
                        end
                    end
                end
            end
            ToyBox.Waiting = nil
        end
    end)
    concommand.Add("toybox_load",function(ply,cmd,args)
        for k,v in pairs(args) do
            LoadAddon_cl(v)
        end
    end)
end

if SERVER then return end

ToyBox.Cache = ToyBox.Cache or {}
spawnmenu.AddCreationTab( "Toyshop", function()
    local A_B = vgui.Create("DPanel")
    A_P = vgui.Create("DHTML",A_B)
    function A_B:Paint() end
    A_P:Dock(FILL)
    A_P:OpenURL("http://glua.tmp.bz/")
    function ToyBox.DoLoad() 
        A_P:Hide()
        function A_B:Paint(w,h)
            draw.SimpleTextOutlined("DOWNLOADING","DermaLarge",w/2,h*0.3,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,Color(0,0,0))
            draw.SimpleTextOutlined(ToyBox.Downloading,"DermaLarge",w/2,h*0.6,Color(255,255,255),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,Color(0,0,0))
        end
    end
    function ToyBox.FinishLoad()
        function A_B:Paint() end
        A_P:Show()
    end
	function A_P:OnDocumentReady()
		A_P:AddFunction("console","buildid",function(wsid)
            if ToyBox.Downloading then return end
            if ToyBox.Waiting then return end
            ToyBox.TempID = wsid
            print(wsid)
        end)
		A_P:AddFunction("console","buildclass",function(class)
            if ToyBox.Waiting then return end
            if ToyBox.Downloading then return end
			if not ToyBox.TempID then return end

            if ToyBox.isMounted(ToyBox.TempID) then
                ToyBox.Waiting = class
                local wsid = tostring(ToyBox.TempID)
                print("Spawning already mounted addon: " .. wsid,class)
                for k,v in pairs(ToyBox.Mounted) do
                    if tostring(v.wsid) == wsid then
                        for i,o in pairs(v.weapons) do
                            if i == ToyBox.Waiting then
                                RunConsoleCommand("gm_giveswep",i)
                                surface.PlaySound("garrysmod/content_downloaded.wav")
                                print("Swep",i)
                                ToyBox.Waiting = nil
                                return
                            end
                        end
                        for i,o in pairs(v.entities) do
                            if i == ToyBox.Waiting then
                                RunConsoleCommand("gm_spawnsent",i)
                                surface.PlaySound("garrysmod/content_downloaded.wav")
                                print("Sent",i)
                                ToyBox.Waiting = nil
                                return
                            end
                        end
                    end
                end
                ToyBox.Waiting = nil
                return
			end
			if LocalPlayer().Host then
                ToyBox.Waiting = class
                LoadAddon_cl(ToyBox.TempID)
                print(ToyBox.TempID,class)
            end
        end)
        A_P:Call([[
        function trySpawn(wsids,classname) {
            console.buildid(wsids);
            console.buildclass(classname);
        }
        ]])
    end
	return A_B

end, "icon16/plugin.png", 500 )
