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

	if EffectsManagerBCE then
		EffectsManagerBCE.setCustomProcessTurnStart(processEffectTurnStart);
	end
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

function processEffectTurnStart(sourceNodeCT, nodeCT, nodeEffect)
	local sSourceName = sourceNodeCT.getNodeName();
	local rSource = ActorManager.resolveActor(sourceNodeCT);
	local sEffect = DB.getValue(nodeEffect, "label", "");
	local sEffectSource = DB.getValue(nodeEffect, "source_name", "");
	local rSourceEffect = ActorManager.resolveActor(sEffectSource);
	if rSourceEffect == nil then
		rSourceEffect = rSource;
	end
	if sourceNodeCT == nodeCT then
		if EffectsManagerBCE.processEffect(rSource,nodeEffect,"GRANTS") then
			processGrant(sEffect, rSourceEffect, "GRANTS");
		end
	elseif sSourceName == sEffectSource and EffectsManagerBCE.processEffect(rSource,nodeEffect,"SGRANTS") then
		processGrant(sEffect, rSourceEffect, "SGRANTS");
	end
	return true;
end

function processGrant(sEffect, rSourceEffect, sEffectType)
	local aEffectComps = EffectManager.parseEffect(sEffect);
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
		if rEffectComp.type == sEffectType then
			for _,sResource in ipairs(rEffectComp.remainder) do
				local rAction = {};
				rAction.type = "resource";
				rAction.operation = "gain";
				rAction.label = "Ongoing Resource Grant";
				rAction.resource = sResource;
				rAction.modifier = rEffectComp.mod;
				rAction.dice = rEffectComp.dice;

				rRoll = ActionResource.getRoll(rSourceEffect, rAction);
				if rRoll then
					ActionsManager.performMultiAction(nil, rSourceEffect, rRoll.sType, {rRoll});
				end
			end
		end
	end
end
