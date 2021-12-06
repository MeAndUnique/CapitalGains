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
		
		addPCOriginal = CombatManager.addPC;
		CombatManager.addPC = addPC;

		addNPCOriginal = CombatManager.addNPC;
		CombatManager.addNPC = addNPC;

		DB.addHandler(CombatManager.CT_COMBATANT_PATH, "onDelete", onCombatantDeleted);
	end
end

function onClose()
	DB.removeHandler(CombatManager.CT_COMBATANT_PATH, "onDelete", onCombatantDeleted);
end

function resetHealth(nodeCT, bLong)
	resetHealthOriginal(nodeCT, bLong);
	ResourceManager.rest(ActorManager.resolveActor(nodeCT), bLong);
end

function addPC(nodePC)
	ResourceManager.addResourceHandlers(nodePC);
	addPCOriginal(nodePC);
end

function addNPC(sClass, nodeNPC, sName)
	local nodeEntry = addNPCOriginal(sClass, nodeNPC, sName);
	ResourceManager.addResourceHandlers(nodeEntry);
	return nodeEntry;
end

function onCombatantDeleted(nodeCombatant)
	ResourceManager.removeResourceHandlers(nodeCombatant.getPath());
end