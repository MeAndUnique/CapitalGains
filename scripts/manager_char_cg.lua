-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local restOriginal;

function onInit()
	restOriginal = CharManager.rest;
	CharManager.rest = rest;

	ResourceManager.addSpecialResource("Hit Dice", isHitDieResource, getCurrentHitDice, getHitDiceLimit, getHitDiceSetters);
end

function rest(nodeChar, bLong)
	restOriginal(nodeChar, bLong);
	ResourceManager.rest(ActorManager.resolveActor(nodeChar), bLong);
end

function getHitDice(rActor, sResource)
	local aHitDice = {};
	local sTargetClass, bMatch = sResource:lower():match("(.*) ?(hit dice)");
	sTargetClass = StringManager.trim(sTargetClass);
	Debug.chat("getHitDice", sTargetClass, bMatch);
	if not bMatch then
		return aHitDice;
	end

	local nodeActor = ActorManager.getCreatureNode(rActor);
	for _,nodeClass in pairs(DB.getChildren(nodeActor, "classes")) do
		local aClassDice = DB.getValue(nodeClass, "hddie", {});
		if #aClassDice > 0 then
			local nClassHDSides = tonumber(aClassDice[1]:sub(2)) or 0;
			local sClass = DB.getValue(nodeClass, "name", ""):lower();
			Debug.chat("getHitDice - inner", nClassHDSides, sTargetClass, sClass)
			Debug.chat("getHitDice - inner2", nClassHDSides > 0, (sTargetClass or "") == "", sTargetClass == sClass)
			if (nClassHDSides > 0)
			and (((sTargetClass or "") == "")
			or (sTargetClass == sClass)) then
				table.insert(aHitDice, {nSides = nClassHDSides, nodeClass = nodeClass});
			end
		end
	end
	table.sort(aHitDice, sortHitDice);
	return aHitDice;
end

function sortHitDice(rLeft, rRight)
	return rLeft.nSides < rRight.nSides;
end

function isHitDieResource(rActor, sResource)
	local aHitDice = getHitDice(rActor, sResource);
	Debug.chat("isHitDieResource", rActor, sResource, aHitDice);
	return #aHitDice > 0;
end

function getCurrentHitDice(rActor, sResource)
	local aHitDice = getHitDice(rActor, sResource);
	local nTotal = 0;
	for _,rHitDie in ipairs(aHitDice) do
		local nUsed = DB.getValue(rHitDie.nodeClass, "hdused", 0);
		local nLimit = DB.getValue(rHitDie.nodeClass, "level", 0);
		nTotal = nTotal + nLimit - nUsed;
	end
	return nTotal;
end

function getHitDiceLimit(rActor, sResource)
	local aHitDice = getHitDice(rActor, sResource);
	local nTotal = 0;
	for _,rHitDie in ipairs(aHitDice) do
		nTotal = nTotal + DB.getValue(rHitDie.nodeClass, "level", 0);
	end
	return nTotal;
end

function getHitDiceSetters(rActor, sResource)
	local aHitDice = getHitDice(rActor, sResource);
	local aValueSetters = {}
	for _,rHitDie in ipairs(aHitDice) do
		local nodeCurrent = DB.createChild(rHitDie.nodeClass, "hdused", "number");
		local nodeLimit = DB.createChild(rHitDie.nodeClass, "level", "number");
		table.insert(aValueSetters, ResourceManager.getNodeAdjustmentFunction(nodeCurrent, nodeLimit, true));
	end
	return aValueSetters;
end