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
		EffectsManagerBCE.registerBCETag("GRANTS", EffectsManagerBCE.aBCESourceMattersOptions);
		EffectsManagerBCE.registerBCETag("SGRANTS", EffectsManagerBCE.aBCESourceMattersOptions);
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

function processEffectTurnStart(rSource)
	local aTags = {"GRANTS"};
	local tMatch = EffectsManagerBCE.getEffects(rSource, aTags, rSource);
	for _,rEffect in pairs(tMatch) do
		if (rEffect.sTag == "GRANTS") and (rEffect.sSource ~= "") then
			local rSourceEffect = ActorManager.resolveActor(rEffect.sSource);
			processGrant(rEffect.sLabel, rSourceEffect, "GRANTS");
		end
	end
	
	aTags = {"SGRANTS"};
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		local rActor = ActorManager.resolveActor(nodeCT);
		if rActor.sCTNode ~= rSource.sCTNode then
			tMatch = EffectsManagerBCE.getEffects(rActor, aTags, rSource);
			for _,rEffect in pairs(tMatch) do
				if rEffect.sTag == "SGRANTS" then
					processGrant(rEffect.sLabel, rSource, "SGRANTS");
				end
			end
		end
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
