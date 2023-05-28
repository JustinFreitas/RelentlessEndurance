-- This extension contains 5e SRD mounted combat rules.  For license details see file: Open Gaming License v1.0a.txt
USER_ISHOST = false

local UNCONSCIOUS_EFFECT_LABEL = "Unconscious"
local RELENTLESS_ENDURANCE = "Relentless Endurance"

function onInit()
    USER_ISHOST = User.isHost()

	if USER_ISHOST then
		Comm.registerSlashHandler("relentless", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
    end
end

function getCTNodeForDisplayName(sDisplayName)
	for _,nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
        if ActorManager.getDisplayName(nodeCT) == sDisplayName then
            return nodeCT
        end
    end

    return nil
end

function processChatCommand(_, sParams)
    local nodeCT = getCTNodeForDisplayName(sParams)
    if nodeCT == nil then
        displayChatMessage(sParams .. " was not found in the Combat Tracker, skipping Relentless Endurance application.")
        return
    end

    applyRelentlessEndurance(nodeCT)
end

function displayChatMessage(sFormattedText)
	if not sFormattedText then return end

	local msg = {font = "msgfont", icon = "relentlessendurance_icon", secret = false, text = sFormattedText}
    Comm.addChatMessage(msg) -- local, not broadcast
end

function applyRelentlessEndurance(nodeCT)
    local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(nodeCT)
	if not nodeTarget then
		return
	end

    local sWounds
    if sTargetNodeType == "pc" then
        sWounds = "hp.wounds"
    elseif sTargetNodeType == "ct" then
        sWounds = "wounds"
	else
		return
	end

    local sDisplayName = ActorManager.getDisplayName(nodeTarget)
    if not EffectManager5E.hasEffect(nodeTarget, UNCONSCIOUS_EFFECT_LABEL) then
        displayChatMessage(sDisplayName .. " is not an unconscious actor, skipping Relentless Endurance application.")
        return
    end

    local nWounds = DB.getValue(nodeTarget, sWounds, 0) - 1
    DB.setValue(nodeTarget, sWounds, "number", nWounds)
    EffectManager.removeEffect(nodeTarget, UNCONSCIOUS_EFFECT_LABEL)
    EffectManager.removeEffect(nodeTarget, "Prone")
    displayChatMessage("Relentless Endurance was applied to " .. sDisplayName .. ".")
end

function isClientFGU()
    return Session.VersionMajor >= 4
end
