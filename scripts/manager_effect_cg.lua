-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local parseEffectCompOriginal;
local evalEffectOriginal;
local getEffectsByTypeOriginal;

local rActiveActor;
local bReplace = false;

function onInit()
	parseEffectCompOriginal = EffectManager5E.parseEffectComp;
	EffectManager5E.parseEffectComp = parseEffectComp;

	evalEffectOriginal = EffectManager5E.evalEffect;
	EffectManager5E.evalEffect = evalEffect;

	getEffectsByTypeOriginal = EffectManager5E.getEffectsByType;
	EffectManager5E.getEffectsByType = getEffectsByType;

	CombatManager.setCustomInitChange(handleInitChange);
end

function setActiveActor(rActor)
	rActiveActor = rActor;
end

function parseEffectComp(s)
	if rActiveActor then
		s = replaceResourceValue(s, "CURRENT", bReplace, ResourceManager.getCurrentResource);
		s = replaceResourceValue(s, "SPENT", bReplace, ResourceManager.getSpentResource);
	end
	return parseEffectCompOriginal(s);
end

function evalEffect(rActor, s)
	setActiveActor(rActor);
	bReplace = true;
	local results = evalEffectOriginal(rActor, s)
	bReplace = false;
	setActiveActor(nil);
	return results;
end

function getEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
	setActiveActor(rActor);
	local results = getEffectsByTypeOriginal(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
	setActiveActor(nil)
	return results;
end

function replaceResourceValue(s, sValue, bStatic, fGetValue)
	local foundResources = {};
	for sMatch in s:gmatch("(%[?" .. sValue .. "%([%+%-]?%d*%.?%d*%s?%*?%s?[^%]]+%)%]?)") do
		table.insert(foundResources, sMatch);
	end

	local sPrefix = "";
	local sPostfix = "";
	if bStatic then
		sPrefix = "%[";
		sPostfix = "%]";
	end

	for _,sMatch in ipairs(foundResources) do
		local sSign, sMultiplier, sResource = sMatch:match("^" .. sPrefix .. sValue .. "%(([%+%-]?)(%d*%.?%d*)%s?%*?%s?([^%]]+)%)" .. sPostfix .. "$");
		if sResource then
			local nValue = fGetValue(rActiveActor, StringManager.trim(sResource));
			if nValue then
				local nMultiplier = tonumber(sMultiplier) or 1;
				if sSign == "-" then
					nMultiplier = -nMultiplier;
				end
				s = s:gsub(sMatch:gsub("[%[%]%(%)%*%-%+]", "%%%1"), tostring(math.floor(nValue * nMultiplier)));
			end
		end
	end
	return s;
end

function handleInitChange(nodeOldCT, nodeNewCT)
	local aEntries = CombatManager.getSortedCombatantList();
	for i = 1,#aEntries do
		local nodeActor = aEntries[i];
		for _,nodeEffect in pairs(DB.getChildren(nodeActor, "effects")) do
			local nActive = DB.getValue(nodeEffect, "isactive", 0);
			if nActive ~= 0 then
				local rSource = ActorManager.resolveActor(DB.getValue(nodeEffect, "source_name"));
				local nodeSource = ActorManager.getCTNode(rSource);
				if not nodeSource then
					break;
				end

				local sEffect;
				if nodeActor == nodeNewCT then
					sEffect = "GRANTS";
				elseif nodeSource == nodeNewCT then
					sEffect = "SGRANTS";
				else
					break;
				end

				local sEffName = DB.getValue(nodeEffect, "label", "");
				local aEffectComps = EffectManager.parseEffect(sEffName);
				for _,sEffectComp in ipairs(aEffectComps) do
					local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
					if rEffectComp.type == "IFT" then
						break;
					elseif rEffectComp.type == "IF" then
						local rActor = ActorManager.resolveActor(nodeActor);
						if not EffectManager5E.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
							break;
						end
					elseif rEffectComp.type == sEffect then
						if nActive == 2 then
							DB.setValue(nodeEffect, "isactive", "number", 1);
						else
							processGrant(rSource, rEffectComp)
						end
					end
				end
			end
		end
	end
end

function processGrant(rSource, rEffectComp)
	for _,sResource in ipairs(rEffectComp.remainder) do
		local rAction = {};
		rAction.type = "resource";
		rAction.operation = "gain";
		rAction.label = "Ongoing Resource Grant";
		rAction.resource = sResource;
		rAction.modifier = rEffectComp.mod;
		rAction.dice = rEffectComp.dice;

		rRoll = ActionResource.getRoll(rSource, rAction);
		if rRoll then
			ActionsManager.performMultiAction(nil, rSource, rRoll.sType, {rRoll});
		end
	end
end
