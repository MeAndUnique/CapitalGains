-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local tSpentResources = {};

tRestPriority = {
	["Short Rest"] = 1,
	["Long Rest"] = 2,
	["Extended Rest"] = 3,
};

local tSpecialResources = {};

function onInit()
	if Session.IsHost then
		CombatManager.setCustomTurnStart(onTurnStart);
		CombatManager.setCustomTurnEnd(onTurnEnd);

		Interface.onDesktopInit = onDesktopInit;
	end
end

function onDesktopInit()
	for _,nodeCombatant in pairs(CombatManager.getCombatantNodes()) do
		addResourceHandlers(nodeCombatant);
	end
end

function onClose()
	for _,nodeCombatant in pairs(CombatManager.getCombatantNodes()) do
		removeResourceHandlers(nodeCombatant);
	end
end

function addSpecialResource(sName, rSpecialResourceFunctions)
	tSpecialResources[sName] = rSpecialResourceFunctions;
end

function removeSpecialResource(sName)
	tSpecialResources[sName] = nil;
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
			if matchPeriod(sPeriod, DB.getValue(nodeResource, "gainperiod", "")) then
				local rAction = {};
				rAction.bExcludeSpecial = true;
				rAction.type = "resource";
				rAction.operation = "recoup";
				rAction.label = "Resource Gain";
				rAction.resource = DB.getValue(nodeResource, "name", "");
				rAction.all = DB.getValue(nodeResource, "gainall", 0) == 1;
				if not rAction.all then
					rAction.modifier = DB.getValue(nodeResource, "gainmodifier", 0);
					rAction.stat = DB.getValue(nodeResource, "gainstat", "");
					rAction.statmult = DB.getValue(nodeResource, "gainstatmult", 0);
					rAction.dice = DB.getValue(nodeResource, "gaindice", {});
				end

				PowerManager.evalAction(rActor, nil, rAction);
				rRoll = ActionResource.getRoll(rActor, rAction);
				if rRoll then
					ActionsManager.performMultiAction(nil, rActor, rRoll.sType, {rRoll});
				end
			end
			if matchPeriod(sPeriod, DB.getValue(nodeResource, "lossperiod", "")) then
				local rAction = {};
				rAction.bExcludeSpecial = true;
				rAction.type = "resource";
				rAction.operation = "loss";
				rAction.label = "Resource Loss";
				rAction.resource = DB.getValue(nodeResource, "name", "");
				rAction.all = DB.getValue(nodeResource, "lossall", 0) == 1;
				if not rAction.all then
					rAction.modifier = DB.getValue(nodeResource, "lossmodifier", 0);
					rAction.stat = DB.getValue(nodeResource, "lossstat", "");
					rAction.statmult = DB.getValue(nodeResource, "lossstatmult", 0);
					rAction.dice = DB.getValue(nodeResource, "lossdice", {});
				end

				PowerManager.evalAction(rActor, nil, rAction);
				rRoll = ActionResource.getRoll(rActor, rAction);
				if rRoll then
					ActionsManager.performMultiAction(nil, rActor, rRoll.sType, {rRoll});
				end
			end
		end
	end
end

function matchPeriod(sCurrent, sExpected)
	if sExpected == sCurrent then
		return true;
	end

	local nCurrentPriority = tRestPriority[sCurrent];
	local nExpectedPriority = tRestPriority[sExpected];
	if nCurrentPriority and nExpectedPriority then
		return nCurrentPriority > nExpectedPriority;
	end

	return false;
end

function getResourceNode(rActor, sResource)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	for _,nodeResource in pairs(DB.getChildren(nodeActor, "resources")) do
		if sResource == DB.getValue(nodeResource, "name") then
			return nodeResource;
		end
	end
end

function getSpecialResourceFunctions(rActor, sResource)
	for _,rSpecialResourceFunctions in pairs(tSpecialResources) do
		if rSpecialResourceFunctions.fIsMatch(rActor, sResource) then
			return rSpecialResourceFunctions;
		end
	end
end

function getNodeAdjustmentFunction(nodeCurrent, nodeLimit, bInvert, bZeroIsUnlimited)
	return function(nValue)
		local nLimit = 0;
		if nodeLimit then
			nLimit = nodeLimit.getValue();
		end
		if bZeroIsUnlimited and (nLimit == 0) then
			nLimit = math.huge;
		end

		local nCurrent = nodeCurrent.getValue() or 0;
		if bInvert then
			nCurrent = nLimit - nCurrent; -- The current value node spends up instead of down.
		else
			nLimit = math.max(nCurrent, nLimit); -- Ensure the current value isn't reduced
		end

		local nResult = nCurrent + nValue;
		local nResult = math.max(0, math.min(nLimit, nResult));

		if bInvert then
			nodeCurrent.setValue(nLimit - nResult);
		else
			nodeCurrent.setValue(nResult);
		end

		return nResult, nValue + nCurrent - nResult;
	end
end

function getResourceLimit(rActor, sResource, nodeResource)
	if not rActor then
		return 0;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return 0;
	end

	local nResult = getSpecialLimit(rActor, sResource)
	if not nodeResource then
		for _,nodeChild in pairs(DB.getChildren(nodeActor, "resources")) do
			if sResource == DB.getValue(nodeChild, "name") then
				nodeResource = nodeChild;
			end
		end
	end
	if nodeResource then
		nResult = nResult + DB.getValue(nodeResource, "limit", 0);
	end

	return nResult;
end

function getSpecialLimit(rActor, sResource)
	local rSpecialResourceFunctions = getSpecialResourceFunctions(rActor, sResource);
	if rSpecialResourceFunctions then
		return rSpecialResourceFunctions.fGetLimit(rActor, sResource);
	end
	return 0;
end

function getCurrentResource(rActor, sResource, nodeResource)
	if not rActor then
		return 0;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return 0;
	end

	local nResult = getCurrentSpecial(rActor, sResource)
	if not nodeResource then
		for _,nodeChild in pairs(DB.getChildren(nodeActor, "resources")) do
			if sResource == DB.getValue(nodeChild, "name") then
				nodeResource = nodeChild;
			end
		end
	end
	if nodeResource then
		nResult = nResult + DB.getValue(nodeResource, "current", 0);
	end

	return nResult;
end

function getCurrentSpecial(rActor, sResource)
	local rSpecialResourceFunctions = getSpecialResourceFunctions(rActor, sResource);
	if rSpecialResourceFunctions then
		return rSpecialResourceFunctions.fGetValue(rActor, sResource);
	end
	return 0;
end

function getSpentResource(rActor, sResource)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return 0;
	end

	for _,nodeResource in pairs(DB.getChildren(nodeActor, "resources")) do
		if DB.getValue(nodeResource, "name") == sResource then
			return DB.getValue(nodeResource, "spent", 0);
		end
	end

	return 0;
end

function setSpentResource(rActor, sResource, nSpent)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end

	for _,nodeResource in pairs(DB.getChildren(nodeActor, "resources")) do
		if DB.getValue(nodeResource, "name") == sResource then
			DB.setValue(nodeResource, "spent", "number", nSpent);
			break;
		end
	end
end

function clearSpentResources(rActor)
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end

	for _,nodeResource in pairs(DB.getChildren(nodeActor, "resources")) do
		if DB.getValue(nodeResource, "name") == sResource then
			DB.deleteChild(nodeResource, "spent");
			break;
		end
	end
end

-- Returns two numbers, or nil if the resource couldn't be found.
-- The first number represents the amount of the resource that remains after adjustment.
-- The second number is extra information that varies based on the operation,
-- how must is being adjusted, and how much is there to begin with
function adjustResource(rActor, sResource, nAdjust, sOperation, bAll)
	if not rActor then
		return;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return;
	end

	local nRemaining, nOverflow;
	local bAllowOverSpend = true;
	local bExcludeSpecial = (sOperation == "loss") or (sOperation == "recoup");
	if bAll then
		if (sOperation == "gain") or (sOperation == "recoup") then
			nAdjust = math.huge;
		else
			nAdjust = -math.huge;
		end
	elseif sOperation == "" then
		bAllowOverSpend = false;
	end
	local bTrackSpent = sOperation == "";

	nRemaining, nOverflow = spendResource(rActor, sResource, nAdjust, bAllowOverSpend, bTrackSpent, bExcludeSpecial);
	return nRemaining, nOverflow;
end

-- The first return value represents the amount of the resource that remains after adjustment.
-- The second return value is the amount spent if bAll is true,
-- otherwise it is the amount by which the adjustment exceeds the resource, if any.
function spendResource(rActor, sResource, nAdjust, bAllowOverSpend, bTrackSpent, bExcludeSpecial)
	local nRemaining = 0;
	local nOverflow = 0;

	local nodeResource = getResourceNode(rActor, sResource);
	local rSpecialResourceFunctions;
	if not bExcludeSpecial then
		rSpecialResourceFunctions = getSpecialResourceFunctions(rActor, sResource);
	end

	local aValueSetters = {};
	if nodeResource then
		local nodeCurrent = DB.createChild(nodeResource, "current", "number");
		local nodeLimit = DB.getChild(nodeResource, "limit");
		table.insert(aValueSetters, getNodeAdjustmentFunction(nodeCurrent, nodeLimit, false, true));
	end
	if rSpecialResourceFunctions then
		local aSpecialValueSetters = rSpecialResourceFunctions.fGetValueSetters(rActor, sResource);
		for i=1,#aSpecialValueSetters do
			local index = i;
			if nAdjust > 0 then
				-- Reverse iteration when gaining resources for symmetry.
				index = #aSpecialValueSetters + 1 - i;
			end
			table.insert(aValueSetters, aSpecialValueSetters[index]);
		end
	end

	if #aValueSetters == 0 then
		return;
	end

	local nTotal = getCurrentResource(rActor, sResource, nodeResource);
	if bAllowOverSpend or (nTotal >= -nAdjust) then
		local nCurrent;
		local nNewTotal = 0;
		for _,fValueSetter in ipairs(aValueSetters) do
			nCurrent, nAdjust = fValueSetter(nAdjust);
			nNewTotal = nNewTotal + nCurrent;
		end

		nRemaining = nNewTotal;
		nOverflow = math.abs(nAdjust);
		
		if bTrackSpent then
			setSpentResource(rActor, sResource, nTotal - nNewTotal);
		end
	else
		nRemaining = nTotal;
		nOverflow = math.abs(nAdjust) - nTotal;
	end

	
	return nRemaining, nOverflow;
end

function addSpecialResourceChangeHandlers(rActor, sResource, fCurrentHandler, fLimitHandler)
	local rSpecialResourceFunctions = getSpecialResourceFunctions(rActor, sResource);
	if rSpecialResourceFunctions then
		return rSpecialResourceFunctions.fAddHandlers(rActor, sResource, fCurrentHandler, fLimitHandler);
	end
end

function removeSpecialResourceChangeHandlers(rActor, sResource, fCurrentHandler, fLimitHandler)
	local rSpecialResourceFunctions = getSpecialResourceFunctions(rActor, sResource);
	if rSpecialResourceFunctions then
		return rSpecialResourceFunctions.fRemoveHandlers(rActor, sResource, fCurrentHandler, fLimitHandler);
	end
end