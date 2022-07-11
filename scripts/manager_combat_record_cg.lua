--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local onPCPostAddOriginal;
local onNPCPostAddOriginal;

function onInit()
	if Session.IsHost then
		onPCPostAddOriginal = CombatRecordManager.getRecordTypePostAddCallback("charsheet");
		CombatRecordManager.setRecordTypePostAddCallback("charsheet", onPCPostAdd);
		onNPCPostAddOriginal = CombatRecordManager.getRecordTypePostAddCallback("npc");
		CombatRecordManager.setRecordTypePostAddCallback("npc", onNPCPostAdd);
	end
end

function onPCPostAdd(tCustom)
	if onPCPostAddOriginal then
		onPCPostAddOriginal(tCustom);
	end
	ResourceManager.addResourceHandlers(tCustom.nodeRecord);
end

function onNPCPostAdd(tCustom)
	onNPCPostAddOriginal(tCustom);
	ResourceManager.addResourceHandlers(tCustom.nodeCT);
end