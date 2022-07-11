--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local resetHealthOriginal;

function onInit()
	if Session.IsHost then
		resetHealthOriginal = CombatManager2.resetHealth;
		CombatManager2.resetHealth = resetHealth;

		CombatManager.setCustomDeleteCombatantHandler(onCombatantDeleted);
	end
end

function onClose()
	CombatManager.removeCustomDeleteCombatantHandler(onCombatantDeleted);
end

function resetHealth(nodeCT, bLong)
	resetHealthOriginal(nodeCT, bLong);
	ResourceManager.rest(ActorManager.resolveActor(nodeCT), bLong);
end

function onCombatantDeleted(nodeCombatant)
	ResourceManager.removeResourceHandlers(nodeCombatant.getPath());
end