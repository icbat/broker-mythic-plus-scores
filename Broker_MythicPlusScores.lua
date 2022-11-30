-------------
--- View Code
-------------
local function set_color(self, row, col, color_obj)
    self:SetCellTextColor(row, col, color_obj.r, color_obj.g, color_obj.b, 1)
end

local function build_one_map_entry(map_info)
    local map_id = map_info["mapChallengeModeID"]
    local map_name, second_id, time_limit, texture = C_ChallengeMode.GetMapUIInfo(map_id)

    local dungeon_affix_info, best_overall_score = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(map_id)
    if best_overall_score == nil then
        best_overall_score = 0
    end

    local tyranical_best = 0
    local fortified_best = 0

    if dungeon_affix_info == nil then
        return {
            map_name = map_name,
            tyranical_best = tyranical_best,
            fortified_best = fortified_best,
            best_overall_score = best_overall_score
        }
    end

    for i, affix_info in ipairs(dungeon_affix_info) do
        if affix_info["level"] ~= nil then
            if affix_info["name"] == "Tyrannical" then
                tyranical_best = affix_info["level"]
            elseif affix_info["name"] == "Fortified" then
                fortified_best = affix_info["level"]
            else
                print("Not sure what to do with ", affix_info["name"], ". Please submit a bug report to",
                    "https://github.com/icbat/broker-mythic-plus-scores/issues")
            end
        end
    end

    return {
        map_name = map_name,
        tyranical_best = tyranical_best,
        fortified_best = fortified_best,
        best_overall_score = best_overall_score
    }

end

--- goal is to get [{Name, Tyranical Key, Fortified Key, Best Score}]
--- and then sort it before going out
local function build_run_table()
    local output = {}

    for index, map_info in pairs(C_ChallengeMode.GetMapScoreInfo()) do
        output[index] = build_one_map_entry(map_info)
    end

    table.sort(output, function(obj1, obj2)
        return obj1["best_overall_score"] > obj2["best_overall_score"]
    end)

    return output
end

local function build_tooltip(self)
    local affixes = C_MythicPlus.GetCurrentAffixes()
    if affixes[1] == nil then
        self:AddLine("No active season")
        return
    end

    local total_score = C_ChallengeMode.GetOverallDungeonScore()
    self:AddHeader(total_score)
    self:SetCell(1, 1, total_score, "CENTER", 4)
    set_color(self, 1, 1, C_ChallengeMode.GetDungeonScoreRarityColor(total_score))

    -- TODO look up the global const for Tyranical and Fort so we can grab short strings
    self:AddLine("Dungeon", "T", "F", "Score")

    local first_affix = affixes[1]
    local id = first_affix["id"]
    local name = C_ChallengeMode.GetAffixInfo(id)

    if id == 10 then -- 10 is Fortified
        self:SetCellColor(self:GetLineCount(), 3, 0, 1, 0, 0.5)
    else
        self:SetCellColor(self:GetLineCount(), 2, 0, 1, 0, 0.5)
    end
    self:AddSeparator()

    for _index, map_info in ipairs(build_run_table()) do
        local map_name = map_info["map_name"]
        local tyranical_best = map_info["tyranical_best"]
        local fortified_best = map_info["fortified_best"]
        local best_overall_score = map_info["best_overall_score"]

        self:AddLine(map_name, tyranical_best, fortified_best, best_overall_score)

        set_color(self, self:GetLineCount(), 2, C_ChallengeMode.GetKeystoneLevelRarityColor(tyranical_best))
        set_color(self, self:GetLineCount(), 3, C_ChallengeMode.GetKeystoneLevelRarityColor(fortified_best))
        set_color(self, self:GetLineCount(), 4,
            C_ChallengeMode.GetSpecificDungeonOverallScoreRarityColor(best_overall_score))
    end
end

--------------------
--- Wiring/LDB/QTip
--------------------

local ADDON, namespace = ...
local LibQTip = LibStub('LibQTip-1.0')
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local dataobj = ldb:NewDataObject(ADDON, {
    type = "data source",
    text = "Mythic Plus Scores"
})

local function OnRelease(self)
    LibQTip:Release(self.tooltip)
    self.tooltip = nil
end

local function anchor_OnEnter(self)
    C_MythicPlus.RequestCurrentAffixes()
    if self.tooltip then
        LibQTip:Release(self.tooltip)
        self.tooltip = nil
    end

    local tooltip = LibQTip:Acquire(ADDON, 4, "LEFT", "CENTER", "CENTER", "RIGHT")
    self.tooltip = tooltip
    tooltip.OnRelease = OnRelease
    tooltip.OnLeave = OnLeave
    tooltip:SetAutoHideDelay(.1, self)

    build_tooltip(tooltip)

    tooltip:SmartAnchorTo(self)

    tooltip:Show()
end

function dataobj:OnEnter()
    anchor_OnEnter(self)
end

--- Nothing to do. Needs to be defined for some display addons apparently
function dataobj:OnLeave()
end
