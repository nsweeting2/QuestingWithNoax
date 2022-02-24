------------------------------------------------------------------------
--  Xaos automatic questing written by Noax.                          --
--  Comically refered to by: Now you're questing with Noax.           --
--  Created July 2019, MSDP'd October 2020.                           --
--                                                                    --
--  Updater code based on Jor'Mox's Generic Map Script,               --
--  I opted to check for updates only when a character is             --
--  connected or reconnected to the server to save on complexity.     --
--  I do this by handling a IAC AYT signal with sysTelnetEvent.       --
--                                                                    --
--  Requires the msdp protocol.                                       --
------------------------------------------------------------------------

--setup global table for msdp, the client will put things here automatically.
--keep in mind other packages will work with this table.
--table should always be created as seen below, so you don't overwrite.
msdp = msdp or {}

local profilePath = getMudletHomeDir() --setup profilePath so we can use in in functions below.
profilePath = profilePath:gsub("\\","/") --fix the path for windows folks

--Setup global table for QuestingWithNoax.
qwn = qwn or {
    neverQuests = {}, --table of quests the user never wants
    version = 2.1, --version we compare for updating
    downloading = false, --if we are downloading an update
    downloadPath = "https://raw.githubusercontent.com/nsweeting2/Xaos-UI/main/QuestingWithNoax/", --path we download files from
    updating = false, --if we are installing an update
    }

--formatting for stylized echos
local questTag = "<DarkViolet>[QUESTR<DarkViolet>]  - <reset>"

--echo function for style points
function qwn.echo(text)

    cecho(questTag .. text .. "\n")

end

--will save needed values into config.lua
function qwn.saveConfigs()

    local configs = {}
    local path = profilePath .. "/questingwithnoax"

    --this is where we would save stuff
    table.save(path.."/configs.lua",configs)
    qwn.saveTimer = tempTimer(60, [[qwn.saveConfigs()]])

end

--will load needed values from config.lua
--will setup MSDP and check it
local function config()

    local configs = {}
    local path = profilePath .. "/questingwithnoax"

    --if our subdir doesn't exist make it
    if not io.exists(path) then
        lfs.mkdir(path)
    end

    --load stored configs from file if it exists
    if io.exists(path.."/configs.lua") then
        table.load(path.."/configs.lua",configs)
        --this is where we would load stuff
    end

    --configure the msdp we need for questing
    sendMSDP("REPORT","QUEST_LIST")

    --and we are done configuring QuestingWithNoax
    qwn.echo("Now You're Questing With Noax has been configured.")

end

--will compare ct.version to highest version is version.lua
--versions.lua must be downloaded by qwn.downloadVersions first
local function compareVersion()

    local path = profilePath .."/questingwithnoax/versions.lua"
    local versions = {}

    --load versions.lua into versions table
    table.load(path, versions)

    --set pos to the index of value of ct.version
    local pos = table.index_of(versions, qwn.version) or 0

    --if pos isn't the top side of versions then we are out of date by the difference
    --enable the update alias and echo that we are out of date
    if pos ~= #versions then
        enableAlias("QuestingUpdate")
        qwn.echo(string.format("Questing With Noax Script is currently %d versions behind.",#versions - pos))
        qwn.echo("To update now, please type: questing update")
    end
end

--will download the versions.lua file from the web
function qwn.downloadVersions()

    if qwn.downloadPath ~= "" then
        local path, file = profilePath .. "/questingwithnoax", "/versions.lua"
        qwn.downloading = true
        downloadFile(path .. file, qwn.downloadPath .. file)
    end

end

--will uninstall QuestingWithNoax and reinstall QuestingWithNoax
local function updatePackage()

    local path = profilePath .. "/questingwithnoax/QuestingWithNoax.xml"

    disableAlias("QuestingUpdate")
    qwn.updating = true
    uninstallPackage("QuestingWithNoax")
    installPackage(path)
    qwn.updating = nil
    qwn.echo("Now You're Questing With Noax Script updated successfully!")
    config()

end

--will download the QuestingWithNoax.xml file from the web
function qwn.downloadPackage()

    local path, file = profilePath .. "/questingwithnoax", "/QuestingWithNoax.xml"
    qwn.downloading = true
    downloadFile(path .. file, qwn.downloadPath .. file)

end

--This function fires on the msdp.QUEST_LIST event by handle_QUEST_LIST
--msdp.QUEST_LIST is a table of questmaster names with comma delimited strings
--msdp.QUEST_LIST happens when you walk into a room with a questmaster
--Values are formatted like this, [questnamer] = questName:action,
--questName contains the string the game expects for the quest command
--action contains what argument you should send complete/incomplete/request
local function on_QUEST_LIST()

    --if we have an empty variable we can abort, no questmaster here
    if msdp.QUEST_LIST == "" then
        return
    end

    --make a quests table to divide up our msdp.QUEST_LIST into
    local quests = {}

    --loop the msdp.QUEST_LIST table 
    --we will add each quest and it argument to the table
    for qm, q in pairs(msdp.QUEST_LIST) do
        for quest in rex.gmatch(tostring(q), [[(.+?\:\w+),]]) do
            table.insert(quests, quest)
        end
    end

    --Now we loop the quests table and send commands
    for k, v in pairs(quests) do
        local quest = ""
        local action = ""
        quest, action = rex.match(tostring(v), [[(.+?):(\w+)]])
        if tostring(action) == "request" then
            send("quest request " .. tostring(quest))
        elseif tostring(action) == "completed" then
            send("quest completed " .. tostring(quest))
        end
    end

end

--handles out annonymus events
function qwn.eventHandler(event, ...)

    --download done, if this package was downloading, check the file name and launch a function
    if event == "sysDownloadDone" and qwn.downloading then
        local file = arg[1]
        if string.ends(file,"/versions.lua") then
            qwn.downloading = false
            compareVersion()
        elseif string.ends(file,"/QuestingWithNoax.xml") then
            qwn.downloading = false
            updatePackage()
        end
    --download error, if this package was downloading, toss a error to screen
    elseif event == "sysDownloadError" and qwn.downloading then
        local file = arg[1]
        if string.ends(file,"/versions.lua") then
            qwn.echo("qwn failed to download file versions.lua")
        elseif string.ends(file,"/QuestingWithNoax.xml") then
            qwn.echo("qwn failed to download file QuestingWithNoax.xml")
        end
    --package is being uninstalled, unregister our events
    elseif event == "sysUninstallPackage" and not qwn.updating and arg[1] == "QuestingWithNoax" then
        for _,id in ipairs(qwn.registeredEvents) do
            killAnonymousEventHandler(id)
        end
    --the server has been coded to send IAC AYT on connect and reconnect, use this to kick into config()
    elseif event == "sysTelnetEvent" then
        if tonumber(arg[1]) == 246 then --246 is AYT
            qwn.downloading = false
            config()
            qwn.downloadVersions()
        end
    end

end

qwn.annonEvents = { --all of the events we will need to trigger on
    registerAnonymousEventHandler("sysDownloadDone", "qwn.eventHandler"),
    registerAnonymousEventHandler("sysDownloadError", "qwn.eventHandler"),
    registerAnonymousEventHandler("sysUninstallPackage", "qwn.eventHandler"),
    registerAnonymousEventHandler("sysTelnetEvent", "qwn.eventHandler"),
    }

qwn.namedEvents = { --all of the events we will need to trigger on
    registerNamedEventHandler("noax","handle_QUEST_LIST","msdp.QUEST_LIST",on_QUEST_LIST),
    }