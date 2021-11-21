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
		if bReplace then
			s = replaceStaticCurrentResource(s);
			s = replaceStaticSpentResource(s);
		else
			s = replaceDynamicCurrentResource(s);
			s = replaceDynamicSpentResource(s);
		end
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

function replaceDynamicCurrentResource(s)
	return replaceDynamicResourceValue(s, "CURRENT", ResourceManager.getCurrentResource);
end

function replaceDynamicSpentResource(s)
	return replaceDynamicResourceValue(s, "SPENT", ResourceManager.getSpentResource);
end

function replaceDynamicResourceValue(s, sValue, fGetValue)
	local foundResources = {};
	for sResource in s:gmatch(sValue .. "%(([^%)]+)%)") do
		table.insert(foundResources, sResource);
	end
	for _,sResource in ipairs(foundResources) do
		aResourceParts = StringManager.split(sResource, "%*", true);
		if #aResourceParts > 0 then
			local nValue = fGetValue(rActiveActor, StringManager.trim(aResourceParts[1]));
			if nValue then
				local nMultiplier = 1;
				if #aResourceParts == 2 then
					nMultiplier = tonumber(aResourceParts[2]) or 1;
				end
				s = s:gsub(sValue .. "%(" .. sResource:gsub("[%*%-%+]", "%%%1") .. "%)", tostring(math.floor(nValue * nMultiplier)));
			end
		end
	end
	return s;
end

function replaceStaticCurrentResource(s)
	return replaceStaticResourceValue(s, "CURRENT", ResourceManager.getCurrentResource);
end

function replaceStaticSpentResource(s)
	return replaceStaticResourceValue(s, "SPENT", ResourceManager.getSpentResource);
end

function replaceStaticResourceValue(s, sValue, fGetValue)
	local foundResources = {};
	for sMatch in s:gmatch("(%[[%+%-]?%d*%.?%d*%s?%*?%s?" .. sValue .. ":[^%]]+%])") do
		table.insert(foundResources, sMatch);
	end
	for _,sMatch in ipairs(foundResources) do
		local sSign, sMultiplier, sResource = sMatch:match("^%[([%+%-]?)(%d*%.?%d*)%s?%*?%s?" .. sValue .. ":([^%]]+)%]$");
		Debug.chat(sSign, sMultiplier, sResource);
		if sResource then
			local nValue = fGetValue(rActiveActor, StringManager.trim(sResource));
			if nValue then
				local nMultiplier = tonumber(sMultiplier) or 1;
				if sSign == "-" then
					nMultiplier = -nMultiplier;
				end
				Debug.chat(nValue, nMultiplier);
				s = s:gsub(sMatch:gsub("[%[%]%*%-%+]", "%%%1"), tostring(math.floor(nValue * nMultiplier)));
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
