--Xaos automatic questing written by Noax.
--Comically refered to by: Now you're questing with Noax.
--Created July 2019, MSDP'd October 2020, Muddled Febuary 2022.

--Updater code based on Jor'Mox's Generic Map Script,
--I opted to check for updates only when a character is
--connected or reconnected to the server to save on complexity.
--I do this by handling a IAC AYT signal with sysTelnetEvent.

--Requires the msdp protocol.

--Setup global table for msdp, the client will put things here automatically.
--Keep in mind other packages will work with this table.
--Table should always be created as seen below, so you don't overwrite.
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

--formatting for standardized echos
local questTag = "<DarkViolet>[<ansiMagenta>QUEST <DarkViolet>]  - <reset>"

--echo function for style points
function qwn.echo(text)
    cecho(questTag .. text .. "\n")
end

local function saveConfigs()
  local configs = {}
  local path = profilePath .. "/questing with noax"
  configs.downloadPath = qwn.downloadPath
  configs.neverQuest = qwn.neverQuest
  table.save(path.."/configs.lua",configs)
  qwn.saveTimer = tempTimer(60, [[saveConfigs()]])
end

local function config()
  local configs = {}
  local path = profilePath .. "/questing with noax"
  if not io.exists(path) then
    lfs.mkdir(path)
  end
  --load stored configs from file if it exists
  if io.exists(path.."/configs.lua") then
    table.load(path.."/configs.lua",configs)
    --there should be a better way to do this
    qwn.downloadPath = configs.downloadPath
    qwn.neverQuest = configs.neverQuest
  end
  --configure the msdp we need for questing
  sendMSDP("REPORT","QUEST_LIST")
  qwn.echo("Now You're Questing With Noax has been registered.")
end

local function compareVersion()
  local path = profilePath .. "/questing downloads/versions.lua"
  local versions = {}
  table.load(path, versions)
  local pos = table.index_of(versions, qwn.version) or 0
  if pos ~= #versions then
    enableAlias("Questing Update Alias")
    qwn.echo(string.format("Questing With Noax Script is currently %d versions behind.",#versions - pos))
    qwn.echo("To update now, please type: questing update")
  end
end

function qwn.downloadVersions()
  if qwn.downloadPath ~= "" then
    local path, file = profilePath .. "/questing downloads", "/versions.lua"
    qwn.downloading = true
    downloadFile(path .. file, qwn.downloadPath .. file)
  end
end

local function updatePackage()
  local path = profilePath .. "/questing downloads/QuestingWithNoax.xml"
  disableAlias("Questing Update Alias")
  qwn.updating = true
  uninstallPackage("QuestingWithNoax")
  installPackage(path)
  qwn.updating = nil
  qwn.echo("Now You're Questing With Noax Script updated successfully!")
  config()
end

function qwn.downloadPackage()
  local path, file = profilePath .. "/questing downloads", "/QuestingWithNoax.xml"
  qwn.downloading = true
  downloadFile(path .. file, qwn.downloadPath .. file)
end

--This function fires on the msdp.QUEST_LIST event
--msdp.QUEST_LIST is a table of comma delimited strings
--each string is a list of quests from a questmaster
--msdp.QUEST_LIST happens when you walk into a room with a questmaster
--Values are formatted like this, questName:action
--questName contains the string the game expects for the quest
--action contains complete/incomplete/request
local function processQUEST_LIST()
  --cecho("<yellow>[ DEBUG ] - <grey>QUEST_LIST:\n")
  --check if we got a empty table, if so we are done
  if msdp.QUEST_LIST == "" then
    return
  end
  --A table for us to turn our string into a table
  --all questmasters will be processed by this
  local quests = {}
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
    end
    if tostring(action) == "completed" then
      send("quest completed " .. tostring(quest))
    end
  end
end

function qwn.eventHandler(event, ...)
  if event == "sysDownloadDone" and qwn.downloading then
    local file = arg[1]
    if string.ends(file,"/versions.lua") then
      qwn.downloading = false
      compareVersion()
    elseif string.ends(file,"/QuestingWithNoax.xml") then
      qwn.downloading = false
      updatePackage()
    end
  elseif event == "sysDownloadError" and qwn.downloading then
    local file = arg[1]
    if string.ends(file,"/versions.lua") then
      qwn.echo("qwn failed to download file versions.lua")
    elseif string.ends(file,"/QuestingWithNoax.xml") then
      qwn.echo("qwn failed to download file QuestingWithNoax.xml")
    end
  elseif event == "sysUninstallPackage" and not qwn.updating and arg[1] == "QuestingWithNoax" then
    for _,id in ipairs(qwn.registeredEvents) do
      killAnonymousEventHandler(id)
    end
  --the mudserver has been coded to send IAC AYT on connect and reconnect
  elseif event == "sysTelnetEvent" then
    if tonumber(arg[1]) == 246 then --246 is AYT
      qwn.downloading = false
      config()
      qwn.downloadVersions()
    end
  end
end

qwn.registeredEvents = { --all of the events we will need to trigger on
  registerAnonymousEventHandler("sysDownloadDone", "qwn.eventHandler"),
  registerAnonymousEventHandler("sysDownloadError", "qwn.eventHandler"),
  registerAnonymousEventHandler("sysUninstallPackage", "qwn.eventHandler"),
  registerAnonymousEventHandler("sysTelnetEvent", "qwn.eventHandler"),
  registerNamedEventHandler("noax","questingMSDP","msdp.QUEST_LIST",processQUEST_LIST)
  }