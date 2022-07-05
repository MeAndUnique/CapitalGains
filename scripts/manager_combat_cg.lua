--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local resetHealthOriginal;
local addPCOriginal;
local addNPCOriginal;

function onInit()
	if Session.IsHost then
		resetHealthOriginal = CombatManager2.resetHealth;
		CombatManager2.resetHealth = resetHealth;

		CombatRecordManager.setRecordTypePostAddCallback("charsheet", onPCPostAdd);
		onNPCPostAdd_old = CombatRecordManager.getRecordTypePostAddCallback("npc");
		CombatRecordManager.setRecordTypePostAddCallback("npc", onNPCPostAdd);

		CombatManager.setCustomDeleteCombatantHandler(onCombatantDeleted);
	end
end

function onClose()
	DB.removeHandler(CombatManager.CT_COMBATANT_PATH, "onDelete", onCombatantDeleted);
end

function resetHealth(nodeCT, bLong)
	resetHealthOriginal(nodeCT, bLong);
	ResourceManager.rest(ActorManager.resolveActor(nodeCT), bLong);
end

function onPCPostAdd(tCustom)
	ResourceManager.addResourceHandlers(tCustom.nodeRecord);
end

function onNPCPostAdd(tCustom)
	addNPCOriginal(tCustom);
	ResourceManager.addResourceHandlers(tCustom.nodeCT);
end

function onCombatantDeleted(nodeCombatant)
	ResourceManager.removeResourceHandlers(nodeCombatant.getPath());
end