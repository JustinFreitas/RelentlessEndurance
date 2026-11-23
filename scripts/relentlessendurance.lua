-- This extension contains 5e SRD Half-Orc racial trait rules.  For license details see file: Open Gaming License v1.0a.txt
local USER_ISHOST = false

local ActionDamage_applyDamage
local CT = "ct"
local HP_TEMPORARY = "hp.temporary"
local HP_TOTAL = "hp.total"
local HP_WOUNDS = "hp.wounds"
local HPTEMP = "hptemp"
local HPTOTAL = "hptotal"
local NAME = "name"
local PC = "pc"
local RELENTLESS_ENDURANCE = "Relentless Endurance"
local RELENTLESS_ENDURANCE_LOWER = RELENTLESS_ENDURANCE:lower()
local UNCONSCIOUS_EFFECT_LABEL = "Unconscious"
local WOUNDS = "wounds"



-- Helper to safely check if a string is blank, preferring the modern StringManager method.
local function isBlankSafe(s)
    if StringManager.isBlank then
        return StringManager.isBlank(s)
    end
    if type(s) ~= "string" then
        return false
    end
    return (string.gsub(s, "%s+", "") == "")
end

-- Helper to safely get an actor from a node/string, preferring the modern getActor method.
local function getActorSafe(v)
    if ActorManager.getActor then
        return ActorManager.getActor(v)
    end
    return ActorManager.resolveActor(v)
end

-- Helper to safely get the target node type and node, preferring modern non-deprecated methods.
local function getTypeAndNodeSafe(v)
    if ActorManager.isPC and ActorManager.getCreatureNode and ActorManager.getCTNode then
        local bIsPC = ActorManager.isPC(v)
        if bIsPC then
            return PC, ActorManager.getCreatureNode(v)
        else
            return CT, ActorManager.getCTNode(v) or ActorManager.getCreatureNode(v)
        end
    end
    if ActorManager.getTypeAndNode then
        return ActorManager.getTypeAndNode(v)
    end
    return ActorManager.getActorTypeAndNode(v)
end

-- Helper to safely check for effects, preferring the modern CoreRPG or 5E-specific EffectManager if available.
local function hasEffectSafe(rActor, sEffect, rTarget, bTargetedOnly)
    if EffectManager.hasEffect then
        return EffectManager.hasEffect(rActor, sEffect, rTarget, bTargetedOnly)
    end
    if EffectManager5E and EffectManager5E.hasEffect then
        return EffectManager5E.hasEffect(rActor, sEffect, rTarget, bTargetedOnly)
    end
    return EffectManager.hasEffect(rActor, sEffect)
end

-- Helper to safely call the ruleset's damage application function.
local function applyDamageFinal(rSource, rTarget, rRoll, bSecret, sDamage, nTotal)
    if type(ActionDamage_applyDamage) == "function" then
        ActionDamage_applyDamage(rSource, rTarget, rRoll)
    elseif ActionHealthD20 and type(ActionHealthD20.apply) == "function" then
         ActionHealthD20.apply(rSource, rTarget, rRoll)
    elseif ActionDamage then
        if type(ActionDamage.applyDamage) == "function" then
            ActionDamage.applyDamage(rSource, rTarget, rRoll)
        elseif type(ActionDamage.apply) == "function" then
            ActionDamage.apply(rSource, rTarget, rRoll)
        end
    end
end

-- Helper to distribute capped damage across [TYPE: ... (...=N)] clauses without breaking ActionHealthD20.applyDecodeDamage sum validation.
function capDamageDescClauses(sDamage, nDamageToApply)
    if not sDamage then
        return ""
    end
    local bHasTypeClauses = false
    local nRemaining = math.max(0, tonumber(nDamageToApply) or 0)
    local sResult = string.gsub(sDamage, "(%[TYPE: [^(]* %([^=]+%=)(%-?%d+)(%)%])", function(sPrefix, sVal, sSuffix)
        bHasTypeClauses = true
        local nClauseVal = math.max(0, tonumber(sVal) or 0)
        local nAlloc = math.min(nClauseVal, nRemaining)
        nRemaining = nRemaining - nAlloc
        return sPrefix .. tostring(nAlloc) .. sSuffix
    end)
    if bHasTypeClauses then
        if nRemaining > 0 then
            local bAdded = false
            sResult = string.gsub(sResult, "(%[TYPE: [^(]* %([^=]+%=)(%-?%d+)(%)%])", function(sPrefix, sVal, sSuffix)
                if not bAdded then
                    bAdded = true
                    local nClauseVal = tonumber(sVal) or 0
                    return sPrefix .. tostring(nClauseVal + nRemaining) .. sSuffix
                end
                return sPrefix .. sVal .. sSuffix
            end)
        end
        return sResult
    end
    return string.gsub(sDamage, "=%-?%d+", "=" .. tostring(nDamageToApply))
end

function onInit()
    USER_ISHOST = (Session and Session.IsHost) or (User and User.isHost and User.isHost()) or false

    -- Initialize upvalues on all instances (Host and Client) with idempotency guards
    if ActionHealthD20 and ActionHealthD20.apply then
        if ActionHealthD20.apply ~= applyDamage_v2 then
            ActionDamage_applyDamage = ActionHealthD20.apply
        end
    elseif ActionDamage then
        if ActionDamage.applyDamage then
            if ActionDamage.applyDamage ~= applyDamage_FGU then
                ActionDamage_applyDamage = ActionDamage.applyDamage
            end
        elseif ActionDamage.apply then
            if ActionDamage.apply ~= applyDamage_FGU then
                ActionDamage_applyDamage = ActionDamage.apply
            end
        end
    end

	if USER_ISHOST then
		Comm.registerSlashHandler("relentless", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).

        -- Hook damage functions to intercept damage rolls
        if ActionHealthD20 and ActionHealthD20.apply then
            if ActionHealthD20.apply ~= applyDamage_v2 then
                ActionHealthD20.apply = applyDamage_v2
            end
        elseif ActionDamage then
            if ActionDamage.applyDamage then
                if ActionDamage.applyDamage ~= applyDamage_FGU then
                    ActionDamage.applyDamage = applyDamage_FGU
                end
            elseif ActionDamage.apply then
                if ActionDamage.apply ~= applyDamage_FGU then
                    ActionDamage.apply = applyDamage_FGU
                end
            end
        end
    end
end

function hasAvailableRelentlessEndurance(aRelentlessEnduranceData)
    return aRelentlessEnduranceData
           and aRelentlessEnduranceData.nPrepared > 0
           and aRelentlessEnduranceData.nCast < aRelentlessEnduranceData.nPrepared
end

function applyDamage_FGC(rSource, rTarget, bSecret, sDamage, nTotal)
    local aRelentlessEnduranceData = hasRelentlessEnduranceTrait(rTarget, nil)
    local bRelentlessEnduranceTriggered
    if hasAvailableRelentlessEndurance(aRelentlessEnduranceData) then
            bRelentlessEnduranceTriggered = processRelentlessEndurance(aRelentlessEnduranceData, nTotal, sDamage, rSource, rTarget, bSecret)
    end

    if not bRelentlessEnduranceTriggered then
        applyDamageFinal(rSource, rTarget, nil, bSecret, sDamage, nTotal)
    end
end

function applyDamage_FGU(rSource, rTarget, rRoll)
    local aRelentlessEnduranceData = hasRelentlessEnduranceTrait(rTarget, rRoll)
    local bRelentlessEnduranceTriggered
    if hasAvailableRelentlessEndurance(aRelentlessEnduranceData) then
        bRelentlessEnduranceTriggered = processRelentlessEndurance(aRelentlessEnduranceData, rRoll.nTotal, rRoll.sDesc, rSource, rTarget, false)
    end

    if not bRelentlessEnduranceTriggered then
        applyDamageFinal(rSource, rTarget, rRoll)
    end
end

function applyDamage_v2(rSource, rTarget, rRoll)
    local isDamageRoll = true
    if rRoll and rRoll.sDesc then
        if rRoll.sDesc:match("%[HEAL") or rRoll.sDesc:match("%[RECOVERY") or rRoll.sDesc:match("%[FHEAL") or rRoll.sDesc:match("%[REGEN") then
            isDamageRoll = false
        elseif (rRoll.nTotal or 0) < 0 then
            isDamageRoll = false
        end
    end

    local aRelentlessEnduranceData = hasRelentlessEnduranceTrait(rTarget, rRoll)
    local bRelentlessEnduranceTriggered
    if hasAvailableRelentlessEndurance(aRelentlessEnduranceData) and isDamageRoll then
        bRelentlessEnduranceTriggered = processRelentlessEndurance(aRelentlessEnduranceData, rRoll.nTotal, rRoll.sDesc, rSource, rTarget, rRoll.bSecret)
    end

    if not bRelentlessEnduranceTriggered then
        applyDamageFinal(rSource, rTarget, rRoll)
    end
end

function displayChatMessage(sFormattedText)
	if isBlankSafe(sFormattedText) then return end

	local msg = {font = "msgfont", icon = "relentlessendurance_icon", secret = false, text = sFormattedText}
    Comm.addChatMessage(msg) -- local, not broadcast
end

function getCTNodeForDisplayName(sDisplayName)
	for _,nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
        if ActorManager.getDisplayName(nodeCT) == sDisplayName then
            return nodeCT
        end
    end

    return nil
end

function getDecomposedTraitName(aTrait)
    local sTraitName = DB.getText(aTrait, "name")
    local sTraitNameLower = sTraitName:lower()
    local nRelentlessEnduranceStart, nRelentlessEnduranceEnd = sTraitNameLower:find(RELENTLESS_ENDURANCE_LOWER)
    local sRelentlessEnduranceTraitSuffix
    if nRelentlessEnduranceStart ~= nil and nRelentlessEnduranceEnd ~= nil then
        sRelentlessEnduranceTraitSuffix = sTraitName:sub(nRelentlessEnduranceEnd + 1)
    end

    return {
        sTraitName = sTraitName,
        sTraitNameLower = sTraitNameLower,
        nRelentlessEnduranceStart = nRelentlessEnduranceStart,
        nRelentlessEnduranceEnd = nRelentlessEnduranceEnd,
        sRelentlessEnduranceTraitSuffix = sRelentlessEnduranceTraitSuffix
    }
end

-- Pure lookup: returns the existing Relentless Endurance power node, or nil. Never mutates the sheet.
function findRelentlessEndurancePower(vActor)
    if not vActor or not ActorManager.isPC(vActor) then return nil end

    local rCurrentActor = getActorSafe(vActor)
    if not rCurrentActor then return nil end
    local nodeCharSheet = DB.findNode(rCurrentActor.sCreatureNode)
    if not nodeCharSheet then return nil end
    for _,vPower in pairs(DB.getChildren(nodeCharSheet, "powers")) do
        if DB.getValue(vPower, NAME, ""):lower() == RELENTLESS_ENDURANCE_LOWER then
            return vPower
        end
    end

    return nil
end

function getOrCreateRelentlessEndurancePower(vActor)
    if not vActor or not ActorManager.isPC(vActor) then return nil end

    local vExisting = findRelentlessEndurancePower(vActor)
    if vExisting then return vExisting end

    local rCurrentActor = getActorSafe(vActor)
    if not rCurrentActor then return nil end
    local nodeCharSheet = DB.findNode(rCurrentActor.sCreatureNode)
    if not nodeCharSheet then return nil end
    local nodePowers = nodeCharSheet.createChild("powers")
    if not nodePowers then
        return nil;
    end

    local nodeNewPower = nodePowers.createChild()
    if not nodeNewPower then
        return nil
    end

    DB.setValue(nodeNewPower, NAME, "string", "Relentless Endurance")
    DB.setValue(nodeNewPower, "prepared", "number", 1)
    DB.setValue(nodeNewPower, "cast", "number", 0)
    DB.setValue(nodeNewPower, "locked", "number", 1)
    DB.setValue(nodeNewPower, "shortdescription", "string", "When you are reduced to 0 hit points but not killed outright, you can drop to 1 hit point instead. You can't use this feature again until you finish a long rest.")
    return nodeNewPower
end

function getPreparedAndCastFromRelentlessEndurancePower(vPower)
    if not vPower then return 0, 0 end
    return DB.getValue(vPower, "prepared", 0), DB.getValue(vPower, "cast", 0)
end

function getRelentlessEnduranceData(aTraits, sTargetNodeType, nodeTarget, rRoll)
    -- Read-only path: do not create the power here. Creation is deferred until RE actually triggers.
    local vPower = findRelentlessEndurancePower(nodeTarget)
    local nPrepared, nCast = getPreparedAndCastFromRelentlessEndurancePower(vPower)
    -- A PC with the trait but no power node yet still has one available use by default
    -- (matching the power that getOrCreateRelentlessEndurancePower would create on trigger).
    if not vPower and sTargetNodeType == PC then
        nPrepared = 1
    end
    local aTargetHealthData = getTargetHealthData(sTargetNodeType, nodeTarget, rRoll)

    return {
        nTotalHP = aTargetHealthData.nTotalHP,
        nTempHP = aTargetHealthData.nTempHP,
        nWounds = aTargetHealthData.nWounds,
        aTraits = aTraits,
        nPrepared = nPrepared,
        nCast = nCast
    }
end



function getTargetHealthData_FGU(sTargetNodeType, nodeTarget, rRoll)
    -- Default to the PC-style hp paths.
    local nTotalHP = DB.getValue(nodeTarget, HP_TOTAL, 0)
    local nTempHP = DB.getValue(nodeTarget, HP_TEMPORARY, 0)
    local nWounds = DB.getValue(nodeTarget, HP_WOUNDS, 0)
    if sTargetNodeType == CT and ActorManager.isRecordType(nodeTarget, "vehicle") then
		if (rRoll and (rRoll.sSubtargetPath or "") ~= "") then
			nTotalHP = DB.getValue(DB.getPath(rRoll.sSubtargetPath, "hp"), 0)
			nWounds = DB.getValue(DB.getPath(rRoll.sSubtargetPath, WOUNDS), 0)
			nTempHP = 0
		else
			nTotalHP = DB.getValue(nodeTarget, HPTOTAL, 0)
			nTempHP = DB.getValue(nodeTarget, HPTEMP, 0)
			nWounds = DB.getValue(nodeTarget, WOUNDS, 0)
		end
    elseif sTargetNodeType == CT then
		nTotalHP = DB.getValue(nodeTarget, HPTOTAL, 0)
		nTempHP = DB.getValue(nodeTarget, HPTEMP, 0)
		nWounds = DB.getValue(nodeTarget, WOUNDS, 0)
	end

    return {
        nTotalHP = nTotalHP,
        nTempHP = nTempHP,
        nWounds = nWounds
    }
end

function getTargetHealthData(sTargetNodeType, nodeTarget, rRoll)
    return getTargetHealthData_FGU(sTargetNodeType, nodeTarget, rRoll)
end

function hasRelentlessEnduranceTrait(vActor, rRoll)
    local sTargetNodeType, nodeTarget = getTypeAndNodeSafe(vActor)
	if not nodeTarget then return end

    local aTraits
	if sTargetNodeType == PC then
        aTraits = DB.getChildren(nodeTarget, "traitlist")
    elseif sTargetNodeType == CT then
        aTraits = DB.getChildren(nodeTarget, "traits")
	else
		return
	end

    for _, aTrait in pairs(aTraits) do
        local aDecomposedTraitName = getDecomposedTraitName(aTrait)
        if aDecomposedTraitName.nRelentlessEnduranceStart ~= nil then
            return getRelentlessEnduranceData(aTraits, sTargetNodeType, nodeTarget, rRoll)
        end
    end
end

function processChatCommand(_, sParams)
    if isBlankSafe(sParams) then
        displayChatMessage("Usage: /relentless CT_Actor_Display_Name_Case_Sensitive")
        return
    end

    local nodeCT = getCTNodeForDisplayName(sParams)
    if nodeCT == nil then
        displayChatMessage(sParams .. " was not found in the Combat Tracker, skipping Relentless Endurance application.")
        return
    end

    applyRelentlessEndurance(nodeCT)
end

function processRelentlessEndurance(aRelentlessEnduranceData, nTotal, sDamage, rSource, rTarget, bSecret)
    local nDamageTotal = tonumber(nTotal or 0)
    local nMaxHP = tonumber(aRelentlessEnduranceData.nTotalHP or 0)
    local nWounds = tonumber(aRelentlessEnduranceData.nWounds or 0)
    local nTempHP = tonumber(aRelentlessEnduranceData.nTempHP or 0)

    -- Temporary HP absorbs damage before real HP; only the remainder reduces actual HP.
    local nDamageToHP = math.max(0, nDamageTotal - nTempHP)
    local nHPRemainingAfter = (nMaxHP - nWounds) - nDamageToHP

    -- RE only matters if this would reduce the actor to 0 or fewer hit points.
    if nHPRemainingAfter > 0 then return end

    -- "but not killed outright": if leftover damage past 0 meets or exceeds the HP maximum,
    -- the creature dies instantly and Relentless Endurance cannot save them.
    if (-nHPRemainingAfter) >= nMaxHP then return end

    if hasEffectSafe(rTarget, UNCONSCIOUS_EFFECT_LABEL) then return end

    local sDisplayName = ActorManager.getDisplayName(rTarget)
    -- Use tracking is power-based, which only exists for PCs. NPC half-orcs are intentionally
    -- not auto-saved (use the /relentless command or radial menu to apply manually).
    local vPower = getOrCreateRelentlessEndurancePower(rTarget)
    if not vPower then return end

    local nPrepared, nCast = getPreparedAndCastFromRelentlessEndurancePower(vPower)
    if nCast >= nPrepared then
        displayChatMessage(sDisplayName .. " has used all of their Relentless Endurance for the day.")
        return
    end

    setCastValueOnPower(vPower, nCast + 1)
    -- Cap the damage so the actor is left at exactly 1 hit point (against real HP, ignoring temp HP).
    local nDamageToApply = (nMaxHP - 1) - nWounds
    sDamage = capDamageDescClauses(sDamage or "", nDamageToApply)

    local rNewDamageRoll = {
        sType = "damage",
        sDesc = sDamage,
        nTotal = tonumber(nDamageToApply),
        aDice = {},
        bSecret = bSecret
    }
    applyDamageFinal(rSource, rTarget, rNewDamageRoll, bSecret, sDamage, nDamageToApply)

    displayChatMessage("Relentless Endurance was applied to " .. sDisplayName .. ".")
    return true
end

function setCastValueOnPower(vPower, nCast)
    DB.setValue(vPower, "cast", "number", nCast)
end

function applyRelentlessEndurance(nodeCT)
    local sNodeType, nodeTarget = getTypeAndNodeSafe(nodeCT)
    local sWounds
    if sNodeType == PC then
        sWounds = HP_WOUNDS
    elseif sNodeType == CT then
        sWounds = WOUNDS
	else
		return
	end

    local sDisplayName = ActorManager.getDisplayName(nodeCT)
    local aRelentlessEnduranceData = hasRelentlessEnduranceTrait(nodeCT, {})
    if not aRelentlessEnduranceData then
        displayChatMessage(sDisplayName .. " does not have the Relentless Endurance trait, skipping Relentless Endurance application.")
        return
    end

    if not hasEffectSafe(nodeCT, UNCONSCIOUS_EFFECT_LABEL) then
        displayChatMessage(sDisplayName .. " is not an unconscious actor, skipping Relentless Endurance application.")
        return
    end

    -- Use tracking is power-based and only exists for PCs. For NPCs there is no power to
    -- check, so the manual (GM-invoked) application simply proceeds.
    local vPower = getOrCreateRelentlessEndurancePower(nodeTarget)
    if vPower then
        local nPrepared, nCast = getPreparedAndCastFromRelentlessEndurancePower(vPower)
        if nCast < nPrepared then
            setCastValueOnPower(vPower, nCast + 1)
        else
            displayChatMessage(sDisplayName .. " has used all of their Relentless Endurance and none are available.")
            return
        end
    end

    DB.setValue(nodeTarget, sWounds, "number", aRelentlessEnduranceData.nTotalHP - 1)
    EffectManager.removeEffect(nodeCT, UNCONSCIOUS_EFFECT_LABEL)
    EffectManager.removeEffect(nodeCT, "Prone")
    displayChatMessage("Relentless Endurance was applied to " .. sDisplayName .. ".")
end
