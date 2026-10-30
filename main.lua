local DEBUG = HashString(GetDisplayName()) == 1558608849
local df = DEBUG and df or function(...) end

local sub    = string.sub
local concat = table.concat

local ADDON_NAME = 'ImpSight'
local ADDON_VERSION = 'X'
local EVENT_NAMESPACE = ADDON_NAME..'_EVENT_NAMESPACE'

local SOURCE_SETTINGS = 1
local SOURCE_ZONES = 2
local SOURCE_SKILLS = 3
local SOURCE_KEYBINDINGS = 4
local SOURCE_SETS = 5
local SOURCE_SLASH_COMMANDS = 6

local function trim(s)
   return s:match('^%s*(.-)%s*$')
end

--- Colorize one or more contiguous ranges of a string.
--- @param sourceString string Original text.
--- @param parts table Array of {startIndex, endIndex} (1-based, inclusive).
--- @param colorHex string 6-digit hex color, e.g. 'FFA500'.
--- @return string
local function ColorizeParts(sourceString, parts, colorHex)
    local tmp = {}
    local cursor = 1

	for i = 1, #parts, 2 do
        local first, last = parts[i], parts[i+1]

        tmp[#tmp+1] = sub(sourceString, cursor, first - 1)
        tmp[#tmp+1] = '|c'..colorHex..sub(sourceString, first, last)..'|r'

        cursor = last + 1
    end

    tmp[#tmp+1] = sub(sourceString, cursor)

    return concat(tmp)
end


local function GetTexturePositions(str)
    local positions = {}
    local init = 1
    while true do
        local s, e = str:find('|t.-|t', init)
        if not s then break end
        for i = s, e do
            positions[i] = true
        end
        init = e + 1
    end
    return positions
end

--- @param sourceString string
--- @param indices table Flat ascending 1-based indices.
--- @param colorHex string 6-digit hex color.
--- @return string
local function ColorizeIndices(sourceString, indices, colorHex)
    if not indices or #indices == 0 then
        return sourceString
    end

    local texPositions = GetTexturePositions(sourceString)

    local n          = #indices
    local temp        = {}
    local count      = 0
    local cursor     = 1
    local i          = 1
    local colorStart = '|c'..colorHex
    local reset      = '|r'

    while i <= n do
        local first = indices[i]

        if texPositions[first] then
            i = i + 1
        else
            local last = first

            while i + 1 <= n
                  and indices[i+1] == last + 1
                  and not texPositions[indices[i+1]] do
                i    = i + 1
                last = indices[i]
            end

            count = count + 1; temp[count] = sub(sourceString, cursor, first-1)
            count = count + 1; temp[count] = colorStart
            count = count + 1; temp[count] = sub(sourceString, first, last)
            count = count + 1; temp[count] = reset

            cursor = last + 1
            i      = i + 1
        end
    end

    count = count + 1; temp[count] = sub(sourceString, cursor)

    return concat(temp)
end


local Highlight = {}
Highlight.__index = Highlight

function Highlight:__init(ctrl)
	self.control = ctrl
	self.maxAlpha = 0.2  -- self.control:GetAlpha()

	self.fadeAnim = ZO_AlphaAnimation:New(self.control)
	self.fadeAnim:SetMinMaxAlpha(0, self.maxAlpha)

	self.stayDuration = 1000
	self.fadeDuration = 1000

	self.hideCallback = function()
		-- TODO: remove `/ self.maxAlpha` if ZO_AlphaAnimation fixed
		self.fadeAnim:FadeOut(0, self.fadeDuration / self.maxAlpha)
	end
end

function Highlight:AddTo(control)
	if self.hideTaskId then
		zo_removeCallLater(self.hideTaskId)
		self.hideTaskId = nil
	end

	self.control:SetParent(control)
	self.control:SetAnchorFill()

	self.control:SetColor(0, 1, 0, 0)
	self.fadeAnim:FadeIn(0, self.fadeDuration)

	self.hideTaskId = zo_callLater(self.hideCallback, self.stayDuration)
end

-- ----------------------------------------------------------------------------

local function GetSettingsSubcategoryNodeData(subcategoryName)
	local SETTINGS_CATEGORY_NAME = GetString(SI_GAME_MENU_SETTINGS)
	for i, entry in ipairs(ZO_GameMenuManager_GetSubcategoriesEntries()) do
		if entry.categoryName == SETTINGS_CATEGORY_NAME and entry.name == subcategoryName then
			return entry
		end
	end
end

local SourceSettings = {}
SourceSettings.__index = SourceSettings

function SourceSettings:Gather()
	-- TODO: add top setting categories, like Audio, Video, ...
	-- can just walk node tree, it includes not leaf nodes too - NO, tree si not built until panel opened
	-- just add them from any source with `control = nil` and adjust `Use` method to not scroll if control is empty
	local strings = {}

	local function _addString(text, data, control)
		strings[text:lower()] = {
			data = data,
			control = control,
			string = text,
			source = SOURCE_SETTINGS,
		}
	end

	local function _extractText(control)
		-- skips guild names, for example
		if not control.data.text then return end

		local text = control.data.text
		if type(text) == 'function' then
			text = text(control)
		elseif type(text) == 'number' then
			text = GetString(text)
		end

		-- df('Text is: %s (%s)', tostring(control.data.text), tostring(text))

		-- strings[text:lower()] = {
		-- 	data = control.data,
		-- 	control = control,
		-- 	string = text,
		-- 	source = SOURCE_SETTINGS,
		-- }

		_addString(text, control.data, control)
	end

	-- all different settings (and headers) 
	for panelIndex, controls in pairs(KEYBOARD_OPTIONS.controlTable) do
		for i = 1, #controls do
			local control = controls[i]
			local data = control.data

			_extractText(control)
		end
	end

	-- setting categories (video, audio, etc.)
	for i, entry in ipairs(ZO_GameMenuManager_GetSubcategoriesEntries()) do
		local text = entry.name

		-- strings[text:lower()] = {
		-- 	data = entry,
		-- 	string = text,
		-- 	source = SOURCE_SETTINGS,
		-- }

		_addString(text, entry)
	end

	return strings
end

-- ZO_SceneManager_ToggleGameMenuBinding
-- SCENE_MANAGER:OnToggleGameMenuBinding() (SCENE_MANAGER -> ZO_IngameSceneManager)
-- if IsGameCoreUI() ? self:OnToggleUIModeBinding() : SCENE_MANAGER:Toggle('gameMenuInGame')
local CALLBACK_ADDED = false
function SourceSettings:Use(desc)
	if not desc then return end

	local data = desc.data
	local control = desc.control

	-- local settingsList

	-- local function d_scroll()
	-- 	if not settingsList then return end
	-- 	-- df('%s %s', tostring(settingsList.scroll.m_ScrollPosition), tostring(settingsList.scroll.m_RowCount))
	-- 	if Zgoo then Zgoo:Main(nil, nil, {settingsList.scroll:GetScrollExtents()}) end
	-- end

	-- local start

	-- local function _scroll(oldState, newState)
	-- 	local diff = GetGameTimeSeconds() - start
	-- 	df('%d %s -> %s', diff * 1000, tostring(oldState), tostring(newState))

	-- 	d_scroll()
	-- end

	if not CALLBACK_ADDED then
		CALLBACK_ADDED = true
		-- GAME_MENU_SCENE:RegisterCallback('StateChange', _scroll)
	end

	-- start = GetGameTimeSeconds()
	SCENE_MANAGER:Show(GAME_MENU_SCENE.name)

	local tree = ZO_GameMenu_InGame.gameMenu.navigationTree  --[[@diagnostic disable-line: undefined-field]]

	local nodeData, shouldScroll
	if data.panel then
		-- if panel in data, it is usual setting
		nodeData = GetSettingsSubcategoryNodeData(KEYBOARD_OPTIONS.panelNames[data.panel])
		shouldScroll = true
	else
		-- if not, it is panel itself, no need to scroll
		nodeData = data
		shouldScroll = false
	end
	local node = tree:GetTreeNodeByData(nodeData)
	tree:SelectNode(node, false, false)

	if not shouldScroll then return end

	local settingsList = ZO_OptionsWindow:GetNamedChild('Settings')

	-- have to wait for vertical extents to be calculated, otherwise `verticalExtents > 0` check in
	-- `ZO_Scroll_ScrollAbsolute` will fail (subcall after `ZO_Scroll_ScrollControlIntoCentralView`)

	local function scrollAndHighlight()
		-- TODO: scroll first and only then highlight -> use ZO_ScrollList_ScrollDataToCenter
		ZO_Scroll_ScrollControlIntoCentralView(settingsList, control)
		Highlight:AddTo(control)
	end

	local eventNamespaceWaitForScrollExtents = EVENT_NAMESPACE..'SourceSettingsWaitForScrollExtents'
	EVENT_MANAGER:RegisterForUpdate(eventNamespaceWaitForScrollExtents, 0, function()
		if select(2, settingsList.scroll:GetScrollExtents()) <= 0 then return end
		EVENT_MANAGER:UnregisterForUpdate(eventNamespaceWaitForScrollExtents)

		scrollAndHighlight()
	end)
end

-- ----------------------------------------------------------------------------

-- TODO: WORLD_MAP_LOCATIONS_DATA, GetNumMaps probably better?
-- it does not contain all maps and locations, but all of them are 100% available

local SourceZones = {}
SourceZones.__index = SourceZones

function SourceZones:Gather()
	local strings = {}

	for zoneIndex = 1, GetNumZones() do
		local zoneName = GetZoneNameByIndex(zoneIndex)
		local zoneId = GetZoneId(zoneIndex)

		local mapId = GetMapIdByZoneId(zoneId)
		-- local mapIndex = GetMapIndexByZoneId(zoneId)

		if mapId ~= 0 then  -- TODO: #mapAvailability
			strings[zoneName:lower()] = {
				zoneId = zoneId,
				string = zoneName,
				source = SOURCE_ZONES,
			}
		end
	end

	return strings
end

function SourceZones:Use(desc)
	local mapId = GetMapIdByZoneId(desc.zoneId)

	if mapId == 0 then return end
	-- TODO: can't open some maps? Multiple maps available so that is why it fails?
	-- TODO: check what Wayfinder have #mapAvailability

	MAIN_MENU_KEYBOARD:ShowCategory(MENU_CATEGORY_MAP)
	WORLD_MAP_MANAGER:SetMapById(mapId)
end

-- ----------------------------------------------------------------------------

local SourceSkills = {}
SourceSkills.__index = SourceSkills

local MAX_PASSIVE_RANK = 2

function SourceSkills:Gather()
	local strings = {}

	local function _gatherSkillLine(skillType, skillLineIndex)
		local skillLineId = GetSkillLineId(skillType, skillLineIndex)
		local skillLineName = GetSkillLineNameById(skillLineId)

		strings[skillLineName:lower()] = {
			skillLineId = skillLineId,
			string = skillLineName,
			source = SOURCE_SKILLS,
		}

		for skillIndex = 1, GetNumSkillAbilities(skillType, skillLineIndex) do
			if IsSkillAbilityPassive(skillType, skillLineIndex, skillIndex) then
				local skillId = GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, 0, MAX_PASSIVE_RANK)
				local skillName = GetAbilityName(skillId, 'player')
				strings[skillName:lower()] = {
					skillLineId = skillLineId,
					skillIndex = skillIndex,
					string = skillName,
					source = SOURCE_SKILLS,
				}
			else
				for morphChoice = 0, 2 do
					local skillId = GetSpecificSkillAbilityInfo(skillType, skillLineIndex, skillIndex, morphChoice, MAX_RANKS_PER_ABILITY)
					local skillName = GetAbilityName(skillId, 'player')

					strings[skillName:lower()] = {
						skillLineId = skillLineId,
						skillIndex = skillIndex,
						string = skillName,
						source = SOURCE_SKILLS,
					}
				end
			end
		end
	end

	for skillType = 1, GetNumSkillTypes() do
		if skillType == SKILL_TYPE_RACIAL then
			-- -- 'The current active race is always processed first' (esoui\ingame\skills\skillsdatamanager.lua > ZO_SkillsDataManager.MapAbilityIdToProgression)
			_gatherSkillLine(skillType, 1)
		else
			for skillLineIndex = 1, GetNumSkillLines(skillType) do
				_gatherSkillLine(skillType, skillLineIndex)
			end
		end
	end

	return strings
end

function SourceSkills:Use(desc)
	if desc.skillLineId then
		local skillLineId = desc.skillLineId
		if self:OpenSkillLine(skillLineId) then
			if desc.skillIndex then
				self:HighlightSkill(desc.skillIndex)
			else
				self:HighlightSkillLineHeader()
			end
		end
	end
end

-- can be used to detect if skill line is on subclassing panel
local function _isSkillLineActive(skillLineId)
	local data = SKILLS_DATA_MANAGER:GetSkillLineDataById(skillLineId)
	return data.isActive
end

function SourceSkills:OpenSkillLine(skillLineId)
	SCENE_MANAGER:Show(KEYBOARD_SKILLS_SCENE.name)  -- TODO: console?

	local tree = SKILLS_WINDOW.skillLinesTree
	local node = SKILLS_WINDOW.skillLineIdToNode[skillLineId]

	if node then  -- TODO: see #subclassing
		-- df('There is a skill line node')

		-- if subclassing is opened - close it
		local selectedData = SKILLS_WINDOW.skillLinesTree:GetSelectedData()
		if selectedData.isSubclassingNode and SKILLS_WINDOW.skillLinesContainer:IsHidden() then
			-- df('Subclassing is opened, have to close first')
			SKILLS_WINDOW.subclassingPanel:RefreshClassSkillLinesView()

			-- SKILLS_WINDOW.subclassingPanel:MarkRefreshGroupDirty('ResetToClassSkillLines')
			-- self.skillListRefreshGroup:TryClean()
		end

		tree:SelectNode(node)
	else
		-- df('There is no skill line node :(')

		local data = SKILLS_DATA_MANAGER:GetSkillLineDataById(skillLineId)

		if data:IsClassSkillLine() then
			-- TODO: FIX: bad argument #1 to 'ipairs' (table/struct expected, got nil)
			for _, child in ipairs(tree.rootNode.children) do
				if child.data.skillType == SKILL_TYPE_CLASS then
					for _, subChild in ipairs(child.children) do
						if subChild.data.isSubclassingNode then
							node = subChild
							break
						end
					end
					break
				end
			end

			tree:SelectNode(node)  -- opens subclassing

			local subclassingPanel = SKILLS_WINDOW.subclassingPanel
			subclassingPanel:ShowSkillsListView(data)
		else
			-- TODO: detect if skill line not reachable early and show error instead of navigate attempt
			ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.GENERAL_ALERT_ERROR, 'Can\'t open skill line')
			return
		end
	end

	return true
end

function SourceSkills:HighlightSkill(skillIndex)
	local data

	-- TODO: better way to distinct subclassing and usual skills #subclassing
	if SKILLS_WINDOW.subclassingPanel.control:IsHidden() then
		data = SKILLS_WINDOW.skillList.data
	else
		data = SKILLS_WINDOW.subclassingPanel.skillsList.data
	end

	for i = 1, #data do
		if data[i].typeId == 1 then  -- 1 - skill, 2 - header
			local skillIndex_ = data[i].data.skillData.skillIndex
			if skillIndex_ == skillIndex then
				Highlight:AddTo(data[i].control)
			end
		end
	end
end

function SourceSkills:HighlightSkillLineHeader()
	local infoControl

	local subclassingPanelControl = SKILLS_WINDOW.subclassingPanel.control
	if subclassingPanelControl:IsHidden() then
		infoControl = ZO_SkillsSkillInfo
	else
		infoControl = subclassingPanelControl:GetNamedChild('SkillsListContainerSkillInfo')
	end

	Highlight:AddTo(infoControl)
end

-- ----------------------------------------------------------------------------

local SourceKeybindings = {}
SourceKeybindings.__index = SourceKeybindings

function SourceKeybindings:Gather()
	local strings = {}

	local list = KEYBOARD_KEYBINDING_MANAGER.list
	list:BuildMasterList()  -- TODO: can avoid? don't want game to force to do some stuff, but it is the easiest way

	for i = 1, #list.masterList do
		local kb = list.masterList[i]
		if kb.typeId == 3 then  -- only actual bindings
			local string = kb.data.dataSource.localizedActionName
			local data = kb.data

			-- df('String %s, data: %s', string, tostring(data))

			strings[string:lower()] = {
				string = string,
				data = data,
				index = i,
				source = SOURCE_KEYBINDINGS,
			}
		end
	end

	return strings
end

function SourceKeybindings:Use(desc)
	SCENE_MANAGER:Show(GAME_MENU_SCENE.name)

	local tree = ZO_GameMenu_InGame.gameMenu.navigationTree  --[[@diagnostic disable-line: undefined-field]]

	for _, child in ipairs(tree.rootNode.children) do
		if child.data.name == GetString(SI_GAME_MENU_CONTROLS) then  -- TODO: better to find 'keybindings' node
			tree:SelectFirstChild(child, false, false)
			break
		end
	end

	local function onScrollCompleteCallback()
		Highlight:AddTo(KEYBOARD_KEYBINDING_MANAGER.list.list.data[desc.index].control)
	end

	-- TODO: is `index` fragile? Check data is the same as requested
	ZO_ScrollList_ScrollDataToCenter(KEYBOARD_KEYBINDING_MANAGER.list.list, desc.index, onScrollCompleteCallback)
end

-- ----------------------------------------------------------------------------

local SourceSets = {}
SourceSets.__index = SourceSets

function SourceSets:Gather()
	local strings = {}

	for _, setCollection in pairs(ITEM_SET_COLLECTIONS_DATA_MANAGER.itemSetCollections) do
		local name = GetItemSetName(setCollection.itemSetId)

		strings[name:lower()] = {
			data = setCollection,
			string = name,
			source = SOURCE_SETS,
		}
	end

	return strings
end

function SourceSets:Use(desc)
	SCENE_MANAGER:Show(ITEM_SETS_BOOK_SCENE.name)

	-- NavigateToItemSetCollectionData  -- not implemented in vanilla
	-- ITEM_SET_COLLECTIONS_BOOK_KEYBOARD:NavigateToItemSetCollectionCategoryData(desc.data:GetCategoryData())

	local itemSetCollectionCategoryData = desc.data:GetCategoryData()

	local treeNode = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.categoryTree:GetTreeNodeByData(itemSetCollectionCategoryData)
	if not treeNode then return end

	ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.categoryTree:SelectNode(treeNode)

	local scrollList = ITEM_SET_COLLECTIONS_BOOK_KEYBOARD.gridListPanelList.list
	local data = ZO_ScrollList_GetDataList(scrollList)
	for i = 1, #data do
		local row = data[i]  --[[@diagnostic disable-line: need-check-nil]]
		if row.typeId == 2 then
			if row.data.header.dataSource.itemSetId == desc.data.itemSetId then
				ZO_ScrollList_ScrollDataToCenter(scrollList, i, function()
					Highlight:AddTo(ZO_ScrollList_GetDataControl(scrollList, row.data))
				end)
				break
			end
		end
	end
end

-- ----------------------------------------------------------------------------

local SourceSlashCommands = {}
SourceSlashCommands.__index = SourceSlashCommands

function SourceSlashCommands:Gather()
	local strings = {}

	for command in pairs(SLASH_COMMANDS) do
		strings[command] = {
			string = command,
			source = SOURCE_SLASH_COMMANDS,
		}
	end

	return strings
end

function SourceSlashCommands:Use(desc)
	-- the problem is slash commands can have arguments
	-- as soon as any argument added search string will no longer treat it as valid command
	-- because it will not match any
	-- there should be separate "command" mode, can leave this simple
	-- but handle commands with arguments by addon itself

	DoCommand(desc.string)
end

-- ----------------------------------------------------------------------------

-- TODO: setting?
local MAX_ROWS = 10
local MAX_CACHE_SIZE = 100
local MIN_QUERY_TIME_TO_CACHE = 0.001 * 5  -- cache requests longer than N ms
local MIN_QUERY_LENGTH_TO_CACHE = 2  -- short queries are heavy

local addon = {}

function addon:Initialize()
	self.strings = {}

	self.sources = {
		[SOURCE_SETS] = SourceSets,
		[SOURCE_ZONES] = SourceZones,
		[SOURCE_SKILLS] = SourceSkills,
		[SOURCE_SETTINGS] = SourceSettings,
		[SOURCE_KEYBINDINGS] = SourceKeybindings,
		[SOURCE_SLASH_COMMANDS] = SourceSlashCommands,
	}

	self:CreateResultTableControl()

	self:GatherSources()

	local haystack = {}
	local sourceRef = {}
	for sourceId, strings in pairs(self.strings) do
		for s, desc in pairs(strings) do
			haystack[#haystack+1] = s
			sourceRef[s] = desc  -- TODO: FIX: can't handle duplicates from different sources #duplicates
		end
	end

	self.haystack = haystack
	self.sourceRef = sourceRef  -- TODO: reimplement #duplicates

	self.cache = {}
	self.cacheIndicies = {}
	self.cacheCurrentIndex = 0
end

function addon:CreateResultTableControl()
	local Column = LibScrollList.Column
	local Table = LibScrollList.Table

	local defaultStyle = {
		SetFont = {'ZoFontGameLargeBold'},
		SetVerticalAlignment = {TEXT_ALIGN_CENTER},
		SetHorizontalAlignment = {TEXT_ALIGN_LEFT},
		SetWrapMode = {TEXT_WRAP_MODE_ELLIPSIS},
		SetMaxLineCount = {1},
	}

    local SearchResultRow = LibScrollList.Label(defaultStyle)

	local SORTABLE = true
	local columns = {
		Column('Row', 450, 0, SearchResultRow, nil, nil, not SORTABLE),
    }

	local WITHOUT_HEADERS = false
    local myList = Table(WITHOUT_HEADERS)

	--[=[
    local function showTooltip(ctrl)
        self:ShowTooltip(ctrl)
    end

    local function onMouseDown(rowControl, button)
        local scrollList = rowControl:GetParent():GetParent()
        ZO_ScrollList_MouseClick(scrollList, rowControl)
    end

    local function LayoutMatchRow(previouslySelectedData, selectedData, selectingDuringRebuild)
		if not selectedData then
			IMP_STATS_VIEWER:OnDeselect()
		elseif selectedData then
			local match = IMP_STATS_MATCHES_MANAGER.matches[selectedData[1]]
            if #match.rounds[1].players < 2 then
                local FULL = true
                match = IMP_STATS_MATCHES_MANAGER.UnpackMatch(IMP_STATS_MATCHES_MANAGER.savedMatches[selectedData[1]], FULL)
            end
			IMP_STATS_VIEWER:LayoutMatch(match)
		end
	end

	local postCreateCallback = function(rowControl)
		local background = CreateControlFromVirtual('$(parent)Background', rowControl, 'IMP_TallListSelectedHighlight')
        background:SetAlpha(0.6)

        rowControl:SetHandler('OnMouseEnter', showTooltip)
        rowControl:SetHandler('OnMouseExit', ZO_Tooltips_HideTextTooltip)

        rowControl:SetHandler('OnMouseDown', onMouseDown)

        local scrollList = rowControl:GetParent():GetParent()

        ZO_ScrollList_EnableSelection(scrollList, 'ZO_ThinListHighlight', LayoutMatchRow)
	    ZO_ScrollList_SetDeselectOnReselect(scrollList, true)
	end
	local postSetupCallback = function(rowControl, dataEntryData, scrollList)
        local result = dataEntryData[13]
        if result then
            GetControl(rowControl, 'Background'):SetHidden(false)
            GetControl(rowControl, 'Background'):SetColor(unpack(COLOR_OF_RESULT[result]))
        else
            GetControl(rowControl, 'Background'):SetHidden(true)
        end
	end
	--]=]

	local postCreateCallback, postSetupCallback = function() end, function() end

    myList:AddDataType(1, columns, 32, postCreateCallback, postSetupCallback)
	myList.defaultSortingCriteria = nil  -- TODO: add featute to turn sorting off for LibScrollList

	local TLC = ImpSight_TLC
	local container = TLC:GetNamedChild('SearchResultsContainer')

	local REPLACE = true
    local listControl = myList:Create('List', container, REPLACE)

	self.resultsList = myList
	self.resultsListControl = listControl
end

function addon:LayoutSearchResults(rows)
	local nothingToLayout = #rows == 0

	if nothingToLayout then
		self:HideSearchResultsTable()
		return
	end
	-- TODO: nothing found, hide only if nothing in search bar

	local N = math.min(#rows, MAX_ROWS)

	local data = {}  -- TODO: reuse existing table instead, clear it
	local qResults = self.qResults  -- TODO: need to organize it somehow better :/
	for i = 1, N do
		data[i] = {ColorizeIndices(rows[i], qResults[i][2], 'FFA500')}
	end

	self.resultsList:ResizeToFitNRows(1, N)
	self.resultsList:Update(1, data)

	self.resultsListControl:SetAnchorOffsets(0, 8, 1)
end

function addon:HideSearchResultsTable()
	-- self.resultsListControl:SetHidden(nothingToLayout)
	self.resultsListControl:SetHeight(0)
	self.resultsListControl:SetAnchorOffsets(0, 0, 1)
end

function addon:GatherSources()
	for sourceId, source in pairs(self.sources) do  -- TODO: potentially async
		self.strings[sourceId] = source:Gather()
		-- TODO: do I need to split them into source categories? There is category in descriptor
	end
end

-- function addon:Query(q)
-- 	-- TODO: replace special characters? in `coup de grAce` for example
-- 	local results = {}

-- 	local start = GetGameTimeSeconds()

-- 	for sourceId, strings in pairs(self.strings) do
-- 		for str, desc in pairs(strings) do
-- 			if string.find(str, q, 1, true) then
-- 				results[#results+1] = desc
-- 			end
-- 		end
-- 	end

-- 	local filtered = GetGameTimeSeconds()

-- 	table.sort(results, function(left, right) return left.string < right.string end)

-- 	local queryTime = GetGameTimeSeconds() - start
-- 	local filterTime = filtered - start
-- 	ImpSight_TLCHint2:SetText(('%.2fms (%d%%)'):format(queryTime * 1000, filterTime / queryTime * 100))

-- 	-- TODO: reimplement?
-- 	self.results = results

-- 	return results
-- end

local function starts_with(str, start)
    return str:sub(1, #start) == start
end

local function longest_prefix(dict, s)
    local best

    for i = 1, #s do
        local prefix = s:sub(1, i)
        if dict[prefix] then best = prefix end
    end

    return best
end

local FZY = GLOBAL_FZY; GLOBAL_FZY = nil
local CASE_SENSITIVE = true
function addon:Query(q)
	-- TODO: replace special characters? in `coup de grAce` for example
	local start = GetGameTimeSeconds()

	local filterResults, straws, out = nil, nil, {}
	local cachedQuery = self.cache[q]
	if cachedQuery then
		df('cache hit: %s', q)
		straws = cachedQuery[1]
		for i = 1, #straws do
			local straw = straws[i]
			out[i] = self.sourceRef[straw]
		end

		filterResults = cachedQuery[2]
	else
		local cachedPrefix = longest_prefix(self.cache, q)
		local followUp = self.previousQuery and starts_with(q, self.previousQuery)

		local haystack
		if followUp and cachedPrefix then
			if #self.previousQuery >= #cachedPrefix then
				df('follow-up: %s +%s', self.previousQuery, q:sub(#self.previousQuery+1))
				haystack = self.straws
			else
				df('cached prefix: %s', cachedPrefix)
				haystack = self.cache[cachedPrefix][1]
			end
		elseif followUp then
			df('follow-up: %s +%s', self.previousQuery, q:sub(#self.previousQuery+1))
			haystack = self.straws
		elseif cachedPrefix then
			df('cached prefix: %s', cachedPrefix)
			haystack = self.cache[cachedPrefix][1]
		else
			df('cache miss: %s', q)
			haystack = self.haystack
		end

		filterResults = FZY.filter(q:lower(), haystack, CASE_SENSITIVE)

		-- local filtered = GetGameTimeSeconds()

		table.sort(filterResults, function(left, right) return left[3] > right[3] end)

		straws = {}
		for i = 1, #filterResults do
			local straw = haystack[filterResults[i][1]]
			straws[#straws+1] = straw
			out[i] = self.sourceRef[straw]
		end
	end
	-- TODO: there is third possibility: cache can contain substring of new query

	local totalQueryTime = GetGameTimeSeconds() - start

	if not cachedQuery and totalQueryTime > MIN_QUERY_TIME_TO_CACHE and #q >= MIN_QUERY_LENGTH_TO_CACHE then
		if self.cacheCurrentIndex >= MAX_CACHE_SIZE then
			self.cacheCurrentIndex = 1
		else
			self.cacheCurrentIndex = self.cacheCurrentIndex + 1
		end

		local oldCache = self.cacheIndicies[self.cacheCurrentIndex]
		if oldCache then
			self.cache[oldCache] = nil
		end
		self.cacheIndicies[self.cacheCurrentIndex] = q
		self.cache[q] = {straws, filterResults}

		-- df('Cache now at %.1fKB', ApproxCacheMemory(self.cache) / 1024)
	end

	-- local filterTime = filtered - start
	-- ImpSight_TLCSearchBoxContainerHint2:SetText(('%.2fms (%d%%)'):format(queryTime * 1000, filterTime / queryTime * 100))
	-- ImpSight_TLCSearchBoxContainerHint2:SetText(('%.2fms'):format(totalQueryTime * 1000))
	ImpSight_TLCSearchBoxContainerHint2:SetText(('%.2fms (%dKB)'):format(totalQueryTime * 1000, ApproxCacheMemory(self.cache) / 1024))
	ImpSight_TLCSearchBoxContainerHint2:SetHidden(false)

	self.previousQuery = q
	self.qResults = filterResults
	self.straws = straws
	self.results = out  -- TODO: reimplement?

	return out
end

function addon:Use(rowIndex)
	rowIndex = rowIndex or 1

	local desc = self.results[rowIndex]
	if desc then
		self.sources[desc.source]:Use(desc)
	else
		local text = trim(ImpSight_TLCSearchBoxContainerSearchBox:GetText())
		if text and text ~= '' and text:sub(1, 1) == '/' then  -- treat as slash command
			DoCommand(text)
		end
	end
end

-- ----------------------------------------------------------------------------

local function OnAddonLoad(_, addonName)
	if addonName ~= ADDON_NAME then return end
	EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)

    addon:Initialize()

	if DEBUG then
		GLOBAL_IMP_SIGHT = addon
		if Zgoo then Zgoo:Main(nil, nil, addon) end
	end
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddonLoad)

-- ----------------------------------------------------------------------------

local DEBOUNCE_TIME = 200  -- TODO: settings?

local function debouncer(duration)
	local taskId

	return function(fn, ...)
		if taskId then
			zo_removeCallLater(taskId)
			taskId = nil
		end

		local args = {...}

		-- not setting taskId to nil should not be a problem?
		-- since zo_removeCallLater for unexistent id will not produce any error
		taskId = zo_callLater(function() fn(unpack(args)) end, duration)
	end
end

local searchDebouncer = debouncer(DEBOUNCE_TIME)
local previousQuery = ''

local function searchFunction(text)
	-- df('Search text: %s, previous: %s', text, previousQuery)

	local q = text:lower()

	if previousQuery == q then return end
	previousQuery = q

	-- after previous check on purpose to reset when cleared
	if q == '' then return end

	local results = addon:Query(q)
	local qResults = addon.qResults  -- TODO: it is debug for fuzzy, delete

	local temp = {}
	for i = 1, #results do
		temp[i] = results[i].string..' ('..qResults[i][3]..')'
	end

	-- df('Result: %s', concat(temp, ', '))

	addon:LayoutSearchResults(temp)
end

function IMP_ImpSight_OnSearchTextChanged(text)
	-- TODO: it immediatelly hides results, but search function is called anyway
	-- even if it does nothing because of `text == ''` check, refactor to avoid it

	-- TODO: do not search if search bar is hidden

	text = trim(text)

	if text == '' then
		-- it makes search box results disappear immediately
		-- but it is not quite good ide to set previousQuery from two sources
		-- TODO: fix to follow single responsibility principle
		addon:HideSearchResultsTable()
		previousQuery = ''

		-- TODO: same SRP note above
		ImpSight_TLCSearchBoxContainerHint2:SetHidden(true)
	end

	searchDebouncer(searchFunction, text)
end

function IMP_ImpSight_OnSearchEnter()
	-- TODO: move lose focus here, and lose focus only if any result selected
	addon:Use(addon.selectedRowIndex)
end

function IMP_ImpSight_ToggleSearchBox()
	ImpSight_TLC:SetHidden(not ImpSight_TLC:IsHidden())
end

function IMP_ImpSight_InitializeHighlight(ctrl)
	Highlight:__init(ctrl)
end