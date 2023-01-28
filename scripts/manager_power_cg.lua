--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local getPCPowerActionOriginal;
local evalActionOriginal;
local performActionOriginal;
local getActionButtonIconsOriginal;
local getActionTextOriginal;
local getActionTooltipOriginal;
local resetIntriguePowersOriginal;

function onInit()
	getPCPowerActionOriginal = PowerManager.getPCPowerAction;
	PowerManager.getPCPowerAction = getPCPowerAction;

	evalActionOriginal = PowerManager.evalAction;
	PowerManager.evalAction = evalAction;

	performActionOriginal = PowerManager.performAction;
	PowerManager.performAction = performAction;

	getActionButtonIconsOriginal = PowerManager5E.getActionButtonIcons;
	PowerManager5E.getActionButtonIcons = getActionButtonIcons;

	getActionTextOriginal = PowerManager5E.getActionText;
	PowerManager5E.getActionText = getActionText;

	getActionTooltipOriginal = PowerManager5E.getActionTooltip;
	PowerManager5E.getActionTooltip = getActionTooltip;

	if PowerManagerKw then
		resetIntriguePowersOriginal = PowerManagerKw.resetIntriguePowers;
		PowerManagerKw.resetIntriguePowers = resetIntriguePowers;
	end

	PowerActionManagerCore.registerActionTypes({ "resource" });
	local tPowerActionHandlers = {
		fnGetButtonIcons = getActionButtonIcons,
		fnGetText = getActionText,
		fnGetTooltip = getActionTooltip,
		fnPerform = PowerManager5E.performAction,
	};
	PowerActionManagerCore.registerActionHandlers(tPowerActionHandlers);
end

function getPCPowerAction(nodeAction, sSubRoll)
	local rAction, rActor = getPCPowerActionOriginal(nodeAction, sSubRoll);

	if rAction and rAction.type == "resource" then
		rAction.resource  = DB.getValue(nodeAction, "resource", "");
		rAction.operation = DB.getValue(nodeAction, "operation", "");
		rAction.all = DB.getValue(nodeAction, "all", 0) == 1;
		if not rAction.all then
			rAction.modifier = DB.getValue(nodeAction, "modifier", 0);
			if rAction.operation == "gain" then
				rAction.dice = DB.getValue(nodeAction, "dice", {});
				rAction.stat = DB.getValue(nodeAction, "stat", "");
				rAction.statmult = DB.getValue(nodeAction, "statmult", 1);
			else
				rAction.variable = DB.getValue(nodeAction, "variable", 0) == 1;
				if rAction.variable then
					rAction.min = DB.getValue(nodeAction, "min", 1);
					rAction.max = DB.getValue(nodeAction, "max", 1);
					rAction.increment = DB.getValue(nodeAction, "increment", 1);
				end
			end
		end
	end

	return rAction, rActor
end

function getPCPowerResourceActionText(nodeAction)
	local text = "";
	local rAction, rActor = PowerManager.getPCPowerAction(nodeAction);
	if rAction and rAction.type == "resource" then
		PowerManager.evalAction(rActor, nodeAction.getChild("..."), rAction);

		local sValue;
		if rAction.all then
			sValue = Interface.getString("resource_action_text_all");
		elseif not rAction.variable then
			sValue = StringManager.convertDiceToString(rAction.dice, rAction.modifier);
		else
			if rAction.max > rAction.min then
				sValue = string.format(Interface.getString("resource_action_text_full_range"), rAction.modifier, rAction.min, rAction.max);
			else
				sValue = string.format(Interface.getString("resource_action_text_half_range"), rAction.modifier, rAction.min);
			end
		end

		if rAction.operation == "" then
			local nCurrent = ResourceManager.getCurrentResource(rActor, rAction.resource);
			if nCurrent >= (rAction.modifier or 0) then
				text = string.format(Interface.getString("resource_action_text_spend"), sValue, rAction.resource);
			else
				text = string.format(Interface.getString("resource_action_text_insufficient"), rAction.resource, rAction.modifier, nCurrent);
			end
		else
			text = string.format(Interface.getString("resource_action_text_gain"), sValue, rAction.resource);
		end
	end
	return text;
end

function evalAction(rActor, nodePower, rAction)
	evalActionOriginal(rActor, nodePower, rAction);

	if rAction.type == "resource" then
		if (rAction.stat or "") ~= "" then
			if rAction.stat == "base" then
				if not aPowerGroup then
					aPowerGroup = PowerManager.getPowerGroupRecord(rActor, nodePower);
				end
				if aPowerGroup then
					local nAbilityBonus = ActorManager5E.getAbilityBonus(rActor, aPowerGroup.sStat);
					local nMult = rAction.statmult or 1;
					if nAbilityBonus > 0 and nMult ~= 1 then
						nAbilityBonus = math.floor(nMult * nAbilityBonus);
					end
					rAction.modifier = rAction.modifier + nAbilityBonus;
					rAction.stat = aPowerGroup.sStat;
				end
			else
				local nAbilityBonus = ActorManager5E.getAbilityBonus(rActor, rAction.stat);
				local nMult = rAction.statmult or 1;
				if nAbilityBonus > 0 and nMult ~= 1 then
					nAbilityBonus = math.floor(nMult * nAbilityBonus);
				end
				rAction.modifier = rAction.modifier + nAbilityBonus;
			end
		end
	end
end

function performAction(draginfo, rActor, rAction, nodePower)
	if not rActor or not rAction then
		return false;
	end

	if rAction.type == "resource" then
		evalAction(rActor, nodePower, rAction);
		rRoll = ActionResource.getRoll(rActor, rAction);
		if rRoll then
			ActionsManager.performMultiAction(draginfo, rActor, rRoll.sType, {rRoll});
		end
	else
		return performActionOriginal(draginfo, rActor, rAction, nodePower);
	end
end

function getActionButtonIcons(node, tData)
	local sType = DB.getValue(node, "type", "");
	if sType == "resource" then
		return "button_action_resource", "button_action_resource_down";
	end
	return getActionButtonIconsOriginal(node, tData);
end

function getActionText(node, tData)
	local sType = DB.getValue(node, "type", "");
	if sType == "resource" then
		return getPCPowerResourceActionText(node);
	end
	return getActionTextOriginal(node, tData);
end

function getActionTooltip(node, tData)
	local sType = DB.getValue(node, "type", "");
	if sType == "resource" then
		local sResource = getPCPowerResourceActionText(node);
		return string.format("%s: %s", Interface.getString("power_tooltip_resource"), sResource);
	end
	return getActionTooltipOriginal(node, tData);
end

function resetIntriguePowers(nodeCaster)
	resetIntriguePowersOriginal(nodeCaster);
	ResourceManager.calculateResourcePeriod(ActionsManager.resolveActor(nodeCaster), "Intrigue");
end