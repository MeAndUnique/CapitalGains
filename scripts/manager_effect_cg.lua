-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local parseEffectCompOriginal;
local evalEffectOriginal;
local getEffectsByTypeOriginal;

local rActiveActor;

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
		s = replaceCurrentResource(s);
		s = replaceSpentResource(s);
	end
	local rEffectComp = parseEffectCompOriginal(s);

	if rActiveActor then
		for i = #(rEffectComp.remainder), 1, -1 do
			local sMultiplier, sResource = rEffectComp.remainder[i]:match("^%[(%d*%.?%d*)CURRENT:([^%]]+)%]$");
			if sResource then
				local nCurrent = ResourceManager.getCurrentResource(rActiveActor, sResource);
				if nCurrent then
					local nMultiplier = 1;
					if sMultiplier and sMultiplier ~= "" then
						nMultiplier = tonumber(sMultiplier);
					end
					rEffectComp.mod = rEffectComp.mod + (nCurrent * nMultiplier);
					table.remove(rEffectComp.remainder, i);
				end
			else 
				sMultiplier, sResource = rEffectComp.remainder[i]:match("^%[(%d*%.?%d*)SPENT:([^%]]+)%]$");
				if sResource then
					local nSpent = ResourceManager.getSpentResource(rActiveActor, sResource);
					if nSpent then
						local nMultiplier = 1;
						if sMultiplier and sMultiplier ~= "" then
							nMultiplier = tonumber(sMultiplier);
						end
						rEffectComp.mod = rEffectComp.mod + (nSpent + nMultiplier);
						table.remove(rEffectComp.remainder, i);
					end
				end
			end
		end
	end

	return rEffectComp;
end

function evalEffect(rActor, s)
	setActiveActor(rActor);
	local results = evalEffectOriginal(rActor, s)
	setActiveActor(nil);
	return results;
end

function getEffectsByType(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
	setActiveActor(rActor);
	local results = getEffectsByTypeOriginal(rActor, sEffectType, aFilter, rFilterActor, bTargetedOnly)
	setActiveActor(nil)
	return results;
end

function replaceCurrentResource(s)
	local foundResources = {};
	for sResource in s:gmatch("CURRENT%(([^%)]+)%)") do
		foundResources[sResource] = true;
	end
	for sResource,_ in pairs(foundResources) do
		aResourceParts = StringManager.split(sResource, ",", true);
		if #aResourceParts > 0 then
			local nCurrent = ResourceManager.getCurrentResource(rActiveActor, sResource);
			if nCurrent then
				local nMultiplier = 1;
				if #aResourceParts == 2 then
					nMultiplier = tonumber(aResourceParts[2]);
				end
				s = s:gsub("CURRENT%(" .. sResource .. "%)", tostring(nCurrent * nMultiplier));
			end
		end
	end
	return s;
end

function replaceSpentResource(s)
	local foundResources = {};
	for sResource in s:gmatch("SPENT%(([^%)]+)%)") do
		foundResources[sResource] = true;
	end
	for sResource,_ in pairs(foundResources) do
		aResourceParts = StringManager.split(sResource, ",", true);
		if #aResourceParts > 0 then
			local nSpent = ResourceManager.getSpentResource(rActiveActor, sResource);
			if nSpent then
				local nMultiplier = 1;
				if #aResourceParts == 2 then
					nMultiplier = tonumber(aResourceParts[2]);
				end
				s = s:gsub("SPENT%(" .. sResource .. "%)", tostring(nSpent * nMultiplier));
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
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
		if rEffectComp.type == sEffectType then
			local nCount = #rEffectComp.remainder;
			local aResources;
			if nCount == 1 then
				aResources = {rEffectComp.remainder[1]};
			elseif nCount ~= 0 then
				aResources = {};
				local sComposite;
				for _,word in ipairs(rEffectComp.remainder) do
					if word:match("^%{") then
						sComposite = word:sub(2);
					elseif word:match("%}$") then
						sComposite = sComposite .. " " .. word:sub(-1);
						table.insert(aResources, sComposite);
						sComposite = nil;
					elseif not sComposite then
						table.insert(aResources, word);
					else
						sComposite = sComposite .. " " .. word;
					end
				end
			end

			for _,sResource in ipairs(aResources) do
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
