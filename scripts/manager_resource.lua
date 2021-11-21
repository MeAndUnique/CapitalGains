-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local aSpentResources = {};

function onInit()
	if Session.IsHost then
		CombatManager.setCustomTurnStart(onTurnStart);
		CombatManager.setCustomTurnEnd(onTurnEnd);

		for _,nodeCombatant in pairs(CombatManager.getCombatantNodes()) do
			addResourceHandlers(nodeCombatant);
		end
	end
end

function onClose()
	for _,nodeCombatant in pairs(CombatManager.getCombatantNodes()) do
		removeResourceHandlers(nodeCombatant);
	end
end

function addResourceHandlers(nodeActor)
	local sActorPath = ActorManager.getCreatureNodeName(nodeActor);
	DB.addHandler(sActorPath .. ".resources.*.current", "onUpdate", synchronizeResourceField);
	DB.addHandler(sActorPath .. ".resources.*.limit", "onUpdate", synchronizeResourceField);

	DB.addHandler(sActorPath .. ".resources.*.share.*.record", "onUpdate", onUpdateSharedResource);
	DB.addHandler(sActorPath .. ".resources.*.share.*.record", "onDelete", onDeleteSharedResource);
end

function removeResourceHandlers(nodeActor)
	local sActorPath = ActorManager.getCreatureNodeName(nodeActor);
	DB.removeHandler(sActorPath .. ".resources.*.current", "onUpdate", synchronizeResourceField);
	DB.removeHandler(sActorPath .. ".resources.*.limit", "onUpdate", synchronizeResourceField);
	
	DB.removeHandler(sActorPath .. ".resources.*.share.*.record", "onUpdate", onUpdateSharedResource);
	DB.removeHandler(sActorPath .. ".resources.*.share.*.record", "onDelete", onDeleteSharedResource);
end

local bSynchronizing = false;
function synchronizeResourceField(nodeField)
	if bSynchronizing then
		return;
	end
	bSynchronizing = true;

	local sFieldName = nodeField.getPath():match("([^%.@]+)$");
	local sFieldType = nodeField.getType();
	local fieldValue = nodeField.getValue();
	local nodeResource = nodeField.getChild("..");
	local sResource = DB.getValue(nodeResource, "name");

	for _,nodeShare in pairs(DB.getChildren(nodeResource, "share")) do
		local sRecord = DB.getValue(nodeShare, "record");
		local nodeResourceMatch = DB.findNode(sRecord);
		if nodeResourceMatch then
			DB.setValue(nodeResourceMatch, sFieldName, sFieldType, fieldValue);
		end
	end

	bSynchronizing = false;
end

function onUpdateSharedResource(nodeRecord)
	if bSynchronizing then
		return;
	end
	bSynchronizing = true;

	local nodeNewShare = nodeRecord.getChild("..");
	local nodeResource = nodeNewShare.getChild("...");
	for _,nodeShare in pairs(DB.getChildren(nodeResource, "share")) do
		if nodeShare ~= nodeNewShare then
			local sRecord = DB.getValue(nodeShare, "record");
			local nodeResourceMatch = DB.findNode(sRecord);
			if nodeResourceMatch then
				local nodeMatchShare = nodeResourceMatch.createChild("share");
				local nodeNewMatchShare = nodeMatchShare.createChild();
				DB.setValue(nodeNewMatchShare, "class", "string", DB.getValue(nodeNewShare, "class"));
				DB.setValue(nodeNewMatchShare, "record", "string", DB.getValue(nodeNewShare, "record"));
			end
		end
	end

	bSynchronizing = false;
end

function onDeleteSharedResource(nodeRecord)
	if bSynchronizing then
		return;
	end
	bSynchronizing = true;

	local sRecord = nodeRecord.getValue();
	local nodeNewShare = nodeRecord.getChild("..");
	local nodeResource = nodeNewShare.getChild("...");
	for _,nodeShare in pairs(DB.getChildren(nodeResource, "share")) do
		local sMatchRecord = DB.getValue(nodeShare, "record");
		local nodeResourceMatch = DB.findNode(sMatchRecord);
		if nodeResourceMatch then
			if nodeShare ~= nodeNewShare then
				for _,nodeMatchShareResource in pairs(DB.getChildren(nodeResourceMatch, "share")) do
					if DB.getValue(nodeMatchShareResource, "record") == sRecord then
						nodeMatchShareResource.delete();
						break;
					end
				end
			else
				DB.deleteChildren(nodeResourceMatch, "share");
			end
		end
	end

	bSynchronizing = false;
end

function onTurnStart(nodeCT)
	local rActor = ActorManager.resolveActor(nodeCT);
	calculateResourcePeriod(rActor, "Turn Start");
end

function onTurnEnd(nodeCT)
	local rActor = ActorManager.resolveActor(nodeCT);
	calculateResourcePeriod(rActor, "Turn End");
	clearSpentResources(rActor);
end

function rest(rActor, bLong)
	local sPeriod
	if ManagerPowerKw and ManagerPowerKw.isExtended() then
		sPeriod = "Extended Rest";
	elseif bLong then
		sPeriod = "Long Rest";
	else
		sPeriod = "Short Rest";
	end

	calculateResourcePeriod(rActor, sPeriod);
end

function calculateResourcePeriod(rActor, sPeriod)
	-- todo resolve on owners instance?
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if nodeActor then
		for _,nodeResource in pairs(DB.getChildren(nodeActor, "resources")) do
			if DB.getValue(nodeResource, "gainperiod", "") == sPeriod then
				local rAction = {};
				rAction.type = "resource";
				rAction.operation = "gain";
				rAction.label = "Resource Gain";
				rAction.resource = DB.getValue(nodeResource, "name", "");
				rAction.modifier = DB.getValue(nodeResource, "gainmodifier", 0);
				rAction.stat = DB.getValue(nodeResource, "gainstat", "");
				rAction.statmult = DB.getValue(nodeResource, "gainstatmult", 0);
				rAction.dice = DB.getValue(nodeResource, "gaindice", {});

				PowerManager.evalAction(rActor, nil, rAction);
				rRoll = ActionResource.getRoll(rActor, rAction);
				if rRoll then
					ActionsManager.performMultiAction(nil, rActor, rRoll.sType, {rRoll});
				end
			end
			if DB.getValue(nodeResource, "lossperiod", "") == sPeriod then
				local rAction = {};
				rAction.type = "resource";
				rAction.operation = "loss";
				rAction.label = "Resource Loss";
				rAction.resource = DB.getValue(nodeResource, "name", "");
				rAction.modifier = DB.getValue(nodeResource, "lossmodifier", 0);
				rAction.stat = DB.getValue(nodeResource, "lossstat", "");
				rAction.statmult = DB.getValue(nodeResource, "lossstatmult", 0);
				rAction.dice = DB.getValue(nodeResource, "lossdice", {});

				PowerManager.evalAction(rActor, nil, rAction);
				rRoll = ActionResource.getRoll(rActor, rAction);
				if rRoll then
					ActionsManager.performMultiAction(nil, rActor, rRoll.sType, {rRoll});
				end
			end
		end
	end
end

function getCurrentResource(rActor, sResource)
	if not rActor then
		return 0;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return 0;
	end

	for _,nodeResource in pairs(DB.getChildren(nodeActor, "resources")) do
		if sResource == DB.getValue(nodeResource, "name") then
			return DB.getValue(nodeResource, "current", 0);
		end
	end

	return 0;
end

function getSpentResource(rActor, sResource)
	local sActor = ActorManager.getCreatureNodeName(rActor);
	if sActor == "" then
		return 0;
	end

	if aSpentResources[sActor] then
		if aSpentResources[sActor][sResource] then
			local nSpent = aSpentResources[sActor][sResource];
			return nSpent;
		end
	end

	return 0;
end

function setSpentResource(rActor, sResource, nSpent)
	local sActor = ActorManager.getCreatureNodeName(rActor);
	if sActor == "" then
		return;
	end

	if not aSpentResources[sActor] then
		aSpentResources[sActor] = {};
	end
	aSpentResources[sActor][sResource] = nSpent;
end

function clearSpentResources(rActor)
	local sActor = ActorManager.getCreatureNodeName(rActor);
	if sActor == "" then
		return;
	end

	aSpentResources[sActor] = {};
end

function adjustResource(rActor, sResource, sOperation, nAdjust, bAll)
	if not rActor then
		return;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end

	for _,nodeResource in pairs(DB.getChildren(nodeActor, "resources")) do
		if sResource == DB.getValue(nodeResource, "name") then
			if sOperation == "loss" then
				return loseResource(nodeResource, nAdjust, bAll);
			elseif sOperation == "gain" then
				return gainResource(sResource, nodeResource, nAdjust, bAll);
			else
				return spendResource(rActor, sResource, nodeResource, nAdjust, bAll);
			end
		end
	end

	return;
end

function gainResource(sResource, nodeResource, nAdjust, bAll)
	local nCurrent = DB.getValue(nodeResource, "current", 0);
	local nLimit = DB.getValue(nodeResource, "limit", 0);

	if bAll then
		if nLimit > 0 then
			DB.setValue(nodeResource, "current", "number", nLimit);
			nCurrent = nLimit;
		end
		return nLimit - nCurrent, nCurrent;
	else
		local nTarget = nCurrent + nAdjust;
		local nResult = nTarget;
		if nLimit > 0 then
			nResult = math.min(nLimit, nTarget);
		end

		DB.setValue(nodeResource, "current", "number", nResult);
		return nTarget - nResult, nResult;
	end
end

function spendResource(rActor, sResource, nodeResource, nAdjust, bAll)
	local nCurrent = DB.getValue(nodeResource, "current", 0);
	if bAll then
		setSpentResource(rActor, sResource, nCurrent);
		DB.setValue(nodeResource, "current", "number", 0);
		return nCurrent, 0;
	else
		local nTarget = nCurrent + nAdjust;
		if nTarget >= 0 then
			setSpentResource(rActor, sResource, -nAdjust);
			DB.setValue(nodeResource, "current", "number", nTarget);
			return 0, nTarget;
		else
			return -nTarget, nCurrent;
		end
	end
end

function loseResource(nodeResource, nAdjust, bAll)
	local nCurrent = DB.getValue(nodeResource, "current", 0);
	if bAll then
		DB.setValue(nodeResource, "current", "number", 0);
		return nCurrent, 0;
	else
		local nTarget = nCurrent + nAdjust;
		local nResult = math.max(0, nTarget);
		DB.setValue(nodeResource, "current", "number", nResult);
		return nResult - nTarget, nResult;
	end
end