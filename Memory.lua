local ADDON, ns = ...

-- Memory: which groups the player has looked at or hidden (both expire after
-- "memoryMinutes") and whose listings are never shown (permanent). Stored
-- account wide, outside the profiles, so it is neither switched with a profile
-- nor part of a profile export.

local Memory = {}
ns.Memory = Memory

-- The time source; tests replace it.
Memory.now = time

local function store()
    local db = ns.AccountDB()
    local m = db.memory
    if not m then
        m = {}
        db.memory = m
    end
    m.seen = m.seen or {}
    m.hidden = m.hidden or {}
    m.ignore = m.ignore or {}
    return m
end

-- nil when the leader's name is unknown (Finder turned a secret into nil).
function Memory.Key(result)
    local name = result.leaderName
    if type(name) ~= "string" then return nil end
    local ids = {}
    if type(result.activityIDs) == "table" then
        for _, id in ipairs(result.activityIDs) do
            if type(id) == "number" then ids[#ids + 1] = id end
        end
    end
    table.sort(ids)
    return name .. "|" .. table.concat(ids, ",")
end

local function mark(kind, key)
    if type(key) ~= "string" then return end
    store()[kind][key] = Memory.now()
end

-- True while the entry is younger than the limit; an old one is removed.
local function holds(kind, key)
    if type(key) ~= "string" then return false end
    local list = store()[kind]
    local at = list[key]
    if not at then return false end
    if Memory.now() - at < ns.Settings.Get("memoryMinutes") * 60 then return true end
    list[key] = nil
    return false
end

function Memory.MarkSeen(key) mark("seen", key) end
function Memory.Hide(key) mark("hidden", key) end
function Memory.IsSeen(key) return holds("seen", key) end
function Memory.IsHidden(key) return holds("hidden", key) end

function Memory.Ignore(name)
    if type(name) == "string" and name ~= "" then store().ignore[name] = true end
end

function Memory.Unignore(name)
    if type(name) == "string" then store().ignore[name] = nil end
end

function Memory.IsIgnored(name)
    return type(name) == "string" and store().ignore[name] == true
end

function Memory.IgnoreList()
    local list = {}
    for name in pairs(store().ignore) do list[#list + 1] = name end
    table.sort(list)
    return list
end
