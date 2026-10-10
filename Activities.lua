local ADDON, ns = ...

-- Activities: categories, activities, how well the player's level fits, and
-- the level-range switch. Built on the read-only Finder accessors.

local Activities = {}
ns.Activities = Activities

local Finder = ns.Finder

-- The categories the client knows in the Classic group finder, in display order.
local CATEGORY_ORDER = { 2, 114, 116, 118, 120 }

local cache = {}

local function clear() cache = {} end
Finder.On("AVAILABILITY", clear)
ns.On("PLAYER_LEVEL_UP", clear)

function Activities.Categories()
    local available = {}
    for _, id in ipairs(Finder.Categories()) do available[id] = true end
    local out = {}
    for _, id in ipairs(CATEGORY_ORDER) do
        if available[id] then
            local info = Finder.CategoryInfo(id)
            local name = info and info.name
            if type(name) ~= "string" or name == "" then name = ns.L["CATEGORY_" .. id] end
            out[#out + 1] = { id = id, name = name }
        end
    end
    return out
end

-- nil when the client does not know the activity.
function Activities.Info(id)
    local c = cache[id]
    if c ~= nil then return c or nil end
    local a = Finder.ActivityInfo(id)
    if not a then
        cache[id] = false
        return nil
    end
    local name = a.fullName or ""   -- plain: Finder.ActivityInfo converted it
    local short = a.shortName
    if type(short) ~= "string" or short == "" then short = name end
    c = {
        id = id, name = name, shortName = short, categoryID = a.categoryID,
        minLevel = a.minLevelSuggestion or 0, maxLevel = a.maxLevelSuggestion or 0,
        maxPlayers = a.maxNumPlayers or 0,
        groupID = a.groupFinderActivityGroupID,
        groupName = a.groupFinderActivityGroupID and Finder.ActivityGroupName(a.groupFinderActivityGroupID) or nil,
    }
    cache[id] = c
    return c
end

function Activities.Name(id)
    local a = Activities.Info(id)
    return a and a.name or nil   -- plain: our own cache entry
end

-- Blizzard's rule (LFGUtil_GetFilteredActivities): a bound of 0 means "no bound".
function Activities.Fit(info, level)
    if info.minLevel > 0 and level < info.minLevel then return "HIGH" end
    if info.maxLevel > 0 and level > info.maxLevel then return "LOW" end
    return "FITS"
end

local FIT_RANK = { FITS = 0, LOW = 1, HIGH = 1 }

-- opts = { levelRangeOnly = bool, text = string }
function Activities.List(categoryID, opts)
    opts = opts or {}
    local level = UnitLevel("player")
    local text = opts.text and opts.text ~= "" and opts.text:lower() or nil
    local out = {}
    for _, id in ipairs(Finder.Activities(categoryID)) do
        local a = Activities.Info(id)
        if a then
            local fit = Activities.Fit(a, level)
            local keep = not (opts.levelRangeOnly and fit ~= "FITS")
            if keep and text then
                keep = a.name:lower():find(text, 1, true) ~= nil or a.shortName:lower():find(text, 1, true) ~= nil
            end
            if keep then
                out[#out + 1] = {
                    id = id, name = a.name, shortName = a.shortName, minLevel = a.minLevel, maxLevel = a.maxLevel,
                    maxPlayers = a.maxPlayers, groupName = a.groupName, fit = fit,
                }
            end
        end
    end
    table.sort(out, function(x, y)
        if x.fit ~= y.fit and (x.fit == "FITS" or y.fit == "FITS") then return x.fit == "FITS" end
        if x.minLevel ~= y.minLevel then return x.minLevel < y.minLevel end
        local nx, ny = x.name:lower(), y.name:lower()
        if nx ~= ny then return nx < ny end
        return x.id < y.id
    end)
    return out
end
