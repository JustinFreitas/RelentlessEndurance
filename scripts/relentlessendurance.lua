-- This extension contains 5e SRD Half-Orc racial trait rules.  For license details see file: Open Gaming License v1.0a.txt
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
local USER_ISHOST = false
local WOUNDS = "wounds"

function onInit()
    USER_ISHOST = User.isHost()
-- TODO: Option for usesperiod when creating RE power, default to Daily/''.  Other's are Rest/'enc' and Once/'once'
-- TODO: Option for prepared count when creating RE power, default to 1.
-- TODO: Option for Automatically setting the RE effect on the actor so that it's enabled on combat start (vs not there and player has to enable if they want to use it), default to On.  Automatic mode should add/remove effect based on available uses on each actor's turn.
	if USER_ISHOST then
		Comm.registerSlashHandler("relentless", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
        ActionDamage_applyDamage = ActionDamage.applyDamage
        if isClientFGU() then
            ActionDamage.applyDamage = applyDamage_FGU
        else
            ActionDamage.applyDamage = applyDamage_FGC
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
            bRelentlessEnduranceTriggered = processRelentlessEndurance(aRelentlessEnduranceData, nTotal, sDamage, rSource, rTarget, bSecret, nil)
    end

    if not bRelentlessEnduranceTriggered then
        ActionDamage_applyDamage(rSource, rTarget, bSecret, sDamage, nTotal)
    end
end

function applyDamage_FGU(rSource, rTarget, rRoll)
    local aRelentlessEnduranceData = hasRelentlessEnduranceTrait(rTarget, rRoll)
    local bRelentlessEnduranceTriggered
    if hasAvailableRelentlessEndurance(aRelentlessEnduranceData) then
        bRelentlessEnduranceTriggered = processRelentlessEndurance(aRelentlessEnduranceData, rRoll.nTotal, rRoll.sDesc, rSource, rTarget, false, rRoll)
    end

    if not bRelentlessEnduranceTriggered then
        ActionDamage_applyDamage(rSource, rTarget, rRoll)
    end
end

function displayChatMessage(sFormattedText)
	if not sFormattedText then return end

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

function getOrCreateRelentlessEndurancePower(vActor)
    if not vActor or not ActorManager.isPC(vActor) then return nil end

    local rCurrentActor = ActorManager.resolveActor(vActor)
    local nodeCharSheet = DB.findNode(rCurrentActor.sCreatureNode)
    for _,vPower in pairs(DB.getChildren(nodeCharSheet, "powers")) do
        if DB.getValue(vPower, NAME, ""):lower() == RELENTLESS_ENDURANCE_LOWER then
            return vPower
        end
    end

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
    DB.setValue(nodeNewPower, "cast", "number", 1)
    DB.setValue(nodeNewPower, "locked", "number", 1)
    DB.setValue(nodeNewPower, "shortdescription", "string", "When you are reduced to 0 hit points but not killed outright, you can drop to 1 hit point instead. You can't use this feature again until you finish a long rest.")
    return nodeNewPower
end

function getPreparedAndCastFromRelentlessEndurancePower(vPower)
    return DB.getValue(vPower, "prepared", 0), DB.getValue(vPower, "cast", 0)
end

function getRelentlessEnduranceData(aTraits, sTargetNodeType, nodeTarget, rRoll)
    local vPower = getOrCreateRelentlessEndurancePower(nodeTarget)
    local nPrepared, nCast = getPreparedAndCastFromRelentlessEndurancePower(vPower)
    local aTargetHealthData
    if isClientFGU() then
        aTargetHealthData = getTargetHealthData_FGU(sTargetNodeType, nodeTarget, rRoll)
    else
        aTargetHealthData = getTargetHealthData_FGC(sTargetNodeType, nodeTarget)
    end

    return {
        nTotalHP = aTargetHealthData.nTotalHP,
        nTempHP = aTargetHealthData.nTempHP,
        nWounds = aTargetHealthData.nWounds,
        aTraits = aTraits,
        nPrepared = nPrepared,
        nCast = nCast
    }
end

function getTargetHealthData_FGC(sTargetNodeType, nodeTarget)
    local nTotalHP = DB.getValue(nodeTarget, HP_TOTAL, 0)
    local nTempHP = DB.getValue(nodeTarget, HP_TEMPORARY, 0)
    local nWounds = DB.getValue(nodeTarget, HP_WOUNDS, 0)
	if sTargetNodeType == PC then
		nTotalHP = DB.getValue(nodeTarget, HP_TOTAL, 0)
		nTempHP = DB.getValue(nodeTarget, HP_TEMPORARY, 0)
		nWounds = DB.getValue(nodeTarget, HP_WOUNDS, 0)
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

function getTargetHealthData_FGU(sTargetNodeType, nodeTarget, rRoll)
    local nTotalHP = DB.getValue(nodeTarget, HP_TOTAL, 0)
    local nTempHP = DB.getValue(nodeTarget, HP_TEMPORARY, 0)
    local nWounds = DB.getValue(nodeTarget, HP_WOUNDS, 0)
	if sTargetNodeType == PC then
		nTotalHP = DB.getValue(nodeTarget, HP_TOTAL, 0)
		nTempHP = DB.getValue(nodeTarget, HP_TEMPORARY, 0)
		nWounds = DB.getValue(nodeTarget, HP_WOUNDS, 0)
    elseif sTargetNodeType == CT then
		nTotalHP = DB.getValue(nodeTarget, HPTOTAL, 0)
		nTempHP = DB.getValue(nodeTarget, HPTEMP, 0)
		nWounds = DB.getValue(nodeTarget, WOUNDS, 0)
	elseif sTargetNodeType == CT and ActorManager.isRecordType(nodeTarget, "vehicle") then
		if (rRoll.sSubtargetPath or "") ~= "" then
			nTotalHP = DB.getValue(DB.getPath(rRoll.sSubtargetPath, "hp"), 0)
			nWounds = DB.getValue(DB.getPath(rRoll.sSubtargetPath, WOUNDS), 0)
			nTempHP = 0
		else
			nTotalHP = DB.getValue(nodeTarget, HPTOTAL, 0)
			nTempHP = DB.getValue(nodeTarget, HPTEMP, 0)
			nWounds = DB.getValue(nodeTarget, WOUNDS, 0)
		end
	end

    return {
        nTotalHP = nTotalHP,
        nTempHP = nTempHP,
        nWounds = nWounds
    }
end

function hasRelentlessEnduranceTrait(vActor, rRoll)
    local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(vActor)
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

function isClientFGU()
    return Session.VersionMajor >= 4
end

function processChatCommand(_, sParams)
    if sParams == nil or sParams == "" then
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

function processRelentlessEndurance(aRelentlessEnduranceData, nTotal, sDamage, rSource, rTarget, bSecret, rDamageRoll)
    local nAllHP = aRelentlessEnduranceData.nTotalHP + aRelentlessEnduranceData.nTempHP
    if aRelentlessEnduranceData.nWounds + nTotal >= nAllHP
    and not EffectManager5E.hasEffect(rTarget, UNCONSCIOUS_EFFECT_LABEL) then
    --and EffectManager5E.hasEffect(rTarget, "Relentless Endurance") then  -- TODO: Do we need this effect at all?
        local sDisplayName = ActorManager.getDisplayName(rTarget)
        local vPower = getOrCreateRelentlessEndurancePower(rTarget)
        local nPrepared, nCast = getPreparedAndCastFromRelentlessEndurancePower(vPower)
        -- TODO: Mark the Power as used.
        if nCast >= nPrepared then
            displayChatMessage(sDisplayName .. " has used all of their Relentless Endurance for the day.")
            return
        end

        setCastValueOnPower(vPower, nCast + 1)
        nTotal = nAllHP - aRelentlessEnduranceData.nWounds - 1
        sDamage = string.gsub(sDamage, "=%-?%d+", "=" .. nTotal)
        if isClientFGU() then
            rDamageRoll.nTotal = tonumber(nTotal)
            rDamageRoll.sDesc = sDamage
            ActionDamage_applyDamage(rSource, rTarget, rDamageRoll)
        else
            ActionDamage_applyDamage(rSource, rTarget, bSecret, sDamage, nTotal)
        end

        displayChatMessage("Relentless Endurance was applied to " .. sDisplayName .. ".")
        return true
    end
end

function setCastValueOnPower(vPower, nCast)
    DB.setValue(vPower, "cast", "number", nCast)
end

function applyRelentlessEndurance(nodeCT)
    local sNodeType = ActorManager.getTypeAndNode(nodeCT)
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

    if not EffectManager5E.hasEffect(nodeCT, UNCONSCIOUS_EFFECT_LABEL) then
        displayChatMessage(sDisplayName .. " is not an unconscious actor, skipping Relentless Endurance application.")
        return
    end

    local nodeTarget = select(2, ActorManager.getTypeAndNode(nodeCT))
    local vPower = getOrCreateRelentlessEndurancePower(nodeTarget)
    local nPrepared, nCast = getPreparedAndCastFromRelentlessEndurancePower(vPower)
    if nCast < nPrepared then
        setCastValueOnPower(vPower, nCast + 1)
    else
        displayChatMessage(sDisplayName .. " has used all of their Relentless Endurance and none are available.")
        return
    end

    DB.setValue(nodeTarget, sWounds, "number", aRelentlessEnduranceData.nTotalHP - 1)
    EffectManager.removeEffect(nodeCT, UNCONSCIOUS_EFFECT_LABEL)
    EffectManager.removeEffect(nodeCT, "Prone")
    displayChatMessage("Relentless Endurance was applied to " .. sDisplayName .. ".")
end
