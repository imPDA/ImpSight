### 1

bad argument #1 to 'ipairs' (table/struct expected, got nil)
|rstack traceback:
[C]: in function 'ipairs'
user:/AddOns/ImpSight/main.lua:340: in function 'SourceSkills:OpenSkillLine'
	<Locals> self = [table:1]{}, skillLineId = 41, tree = [table:2]{suspendAnimations = T, autoSelectChildOnNodeOpen = F, exclusive = T, enabled = T, defaultIndent = 50, defaultSpacing = 0, width = 300}, data = [table:3]{skillPointCostMultiplier = 2, name = "Dark Magic", nextRankXP = 7, currentRank = 1, classAccessCollectibleId = 0, isNew = F, masteryCollectible = 13581, craftingGrowthType = 0, skillLineIndex = 10, currentXP = 0, isAdvised = F, isClassMastery = F, isDiscovered = F, unlockText = "", isActive = F, isInTraining = F, isProgressionAccountWide = T, orderingIndex = 4294967296, isPlayerClassSkillLine = F, classId = 2, id = 41, canMarkNew = T, lastRankXP = 0, classMasteryCost = 1, isWerewolf = F} </Locals>
user:/AddOns/ImpSight/main.lua:301: in function 'SourceSkills:Use'
	<Locals> self = [table:1], desc = [table:4]{skillLineId = 41, string = "(24595) Dark Deal", source = 3, skillIndex = 5}, skillLineId = 41 </Locals>
user:/AddOns/ImpSight/main.lua:636: in function 'addon:Use'
	<Locals> self = [table:5]{}, rowIndex = 1, desc = [table:4] </Locals>
user:/AddOns/ImpSight/main.lua:715: in function 'IMP_ImpSight_OnSearchEnter'
ImpSight_TLCSearchBox_Enter:3: in function '(main chunk)'
	<Locals> self = ud </Locals>

### 2

Does not show icons in history
