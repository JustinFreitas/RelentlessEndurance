local BUTTON_POSITION_INDEX = 7

function onInit()
	if super and super.onInit then
		super.onInit();
	end

    registerMenuItem("Apply Relentless Endurance to Unconscious Actor", "white_relentlessendurance_icon", BUTTON_POSITION_INDEX)
end

function onMenuSelection(selection, subselection)
    local nodeCT = getDatabaseNode()
    if not nodeCT then return end

    if selection == BUTTON_POSITION_INDEX then
        applyRelentlessEndurance(nodeCT)
        return
    end

    if super and super.onMenuSelection then
        super.onMenuSelection(selection, subselection)
    end
end

function applyRelentlessEndurance(nodeCT)
    RelentlessEndurance.applyRelentlessEndurance(nodeCT)
end
