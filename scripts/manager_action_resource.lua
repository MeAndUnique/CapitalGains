--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

OOB_MSGTYPE_APPLYRESOURCE = "applyresource";
OOB_MSGTYPE_RESOURCE_HEAL = "resourceheal";

function onInit()
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYRESOURCE, handleApplyResource);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_RESOURCE_HEAL, handleResourceHeal);

	ActionsManager.registerModHandler("resource", modResource);
	ActionsManager.registerResultHandler("resource", onResource);

	GameSystem.actions["resource"] = { sIcon = "coins", sTargeting = "all", bUseModStack = true }
	table.insert(GameSystem.targetactions, "resource");
end

function getRoll(rActor, rAction)
	local rRoll = {};
	rRoll.sType = "resource";
	rRoll.sResource = rAction.resource;
	rRoll.sOperation = rAction.operation;
	rRoll.bAll = rAction.all;
	rRoll.aDice = rAction.dice or {};
	rRoll.nMod = rAction.modifier or 0;
	rRoll.bSelfTarget = true;

	-- Build description
	rRoll.sDesc = "[RESOURCE";
	if rAction.order and rAction.order > 1 then
		rRoll.sDesc = rRoll.sDesc .. " #" .. rAction.order;
	end
	rRoll.sDesc = rRoll.sDesc .. "] " .. rAction.label;

	-- Add ability modifiers
	if rAction.stat then
		local sAbilityEffect = DataCommon.ability_ltos[rAction.stat];
		if sAbilityEffect then
			rRoll.sDesc = rRoll.sDesc .. " [MOD:" .. sAbilityEffect .. "]";
		end
	end

	return rRoll;
end

function performRoll(draginfo, rActor, rAction)
	local rRoll = getRoll(rActor, rAction);

	ActionsManager.performAction(draginfo, rActor, rRoll);
end

function modResource(rSource, rTarget, rRoll)
	local aAddDesc = {};
	local aAddDice = {};
	local nAddMod = 0;

	if rSource then
		local bEffects = false;

		-- Apply ability modifiers
		for sAbility, sAbilityMult in rRoll.sDesc:gmatch("%[MOD: (%w+) %((%w+)%)%]") do
			local nBonusStat, nBonusEffects = ActorManager5E.getAbilityEffectsBonus(rSource, DataCommon.ability_stol[sAbility]);
			if nBonusEffects > 0 then
				bEffects = true;
				local nMult = tonumber(sAbilityMult) or 1;
				if nBonusStat > 0 and nMult ~= 1 then
					nBonusStat = math.floor(nMult * nBonusStat);
				end
				nAddMod = nAddMod + nBonusStat;
			end
		end

		-- If effects happened, then add note
		if bEffects then
			local sEffects;
			local sMod = StringManager.convertDiceToString(aAddDice, nAddMod, true);
			if sMod ~= "" then
				sEffects = "[" .. Interface.getString("effects_tag") .. " " .. sMod .. "]";
			else
				sEffects = "[" .. Interface.getString("effects_tag") .. "]";
			end
			table.insert(aAddDesc, sEffects);
		end
	end

	if #aAddDesc > 0 then
		rRoll.sDesc = rRoll.sDesc .. " " .. table.concat(aAddDesc, " ");
	end
	ActionsManager2.encodeDesktopMods(rRoll);
	for _,vDie in ipairs(aAddDice) do
		if vDie:sub(1,1) == "-" then
			table.insert(rRoll.aDice, "-p" .. vDie:sub(3));
		else
			table.insert(rRoll.aDice, "p" .. vDie:sub(2));
		end
	end
	rRoll.nMod = rRoll.nMod + nAddMod;
end

function onResource(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	rMessage.text = string.gsub(rMessage.text, " %[MOD:[^]]*%]", "");
	Comm.deliverChatMessage(rMessage);

	local nTotal = ActionsManager.total(rRoll);
	notifyApplyResource(rSource, rTarget, rMessage.secret, nTotal, rRoll.sOperation, rRoll.sResource, rRoll.bAll);
end

function notifyApplyResource(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYRESOURCE;

	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end

	msgOOB.nTotal = nTotal;
	msgOOB.sOperation = sOperation;
	msgOOB.sResource = sResource;

	if (bAll == true) or (bAll == "true") then
		msgOOB.nAll = 1;
	else
		msgOOB.nAll = 0;
	end

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);

	Comm.deliverOOBMessage(msgOOB, "");
end

function handleApplyResource(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);

	local nTotal = tonumber(msgOOB.nTotal) or 0;
	applyResource(rSource, rTarget, (tonumber(msgOOB.nSecret) == 1), nTotal, msgOOB.sOperation, msgOOB.sResource, tonumber(msgOOB.nAll) == 1);
end

function applyResource(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
	if rSource then
		if sOperation == "loss" then
			applyResourceLoss(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
		elseif (sOperation == "gain") or (sOperation == "recoup") then
			applyResourceGain(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
		else
			applyResourceSpend(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
		end
	end
end

function applyResourceSpend(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
	local nRemaining, nOverflow = ResourceManager.adjustResource(rSource, sResource, -nTotal, sOperation, bAll);
	if not nOverflow then
		local msgMissing = {
			font = "msgfont",
			icon = "roll_resource",
			text = string.format(Interface.getString("resource_action_result_missing"), sResource)
		};
		ActionsManager.outputResult(bSecret, rSource, nil, msgMissing, msgMissing);
		return;
	end

	local msgShort = {
		font = "msgfont",
		icon = "roll_resource",
		text = string.format(Interface.getString("resource_action_result_spend_short"), sResource)
	};
	local msgLong = {
		font = "msgfont",
		icon = "roll_resource"
	};

	local bSuccess = false;
	if not bAll and nOverflow > 0 then
		msgLong.text = string.format(Interface.getString("resource_action_result_insufficient"), sResource, nTotal, nRemaining);
	else
		bSuccess = true;
		local sSpend;
		if bAll then
			sSpend = Interface.getString("resource_action_result_all");
		else
			sSpend = tostring(nTotal);
		end
		msgLong.text = string.format(Interface.getString("resource_action_result_spend_long"), sResource, sSpend, nRemaining);
	end

	ActionsManager.outputResult(bSecret, rSource, nil, msgLong, msgShort);

	if bSuccess then
		local nSpend = nTotal;
		if bAll then
			nSpend = nOverflow;
		end
		handleSpendEffects(rSource, rTarget, bSecret, nSpend, sResource);
	end
end

function applyResourceGain(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
	local nRemaining, nOverflow = ResourceManager.adjustResource(rSource, sResource, nTotal, sOperation, bAll);
	if not nOverflow then
		local msgMissing = {
			font = "msgfont",
			icon = "roll_resource",
			text = string.format(Interface.getString("resource_action_result_missing"), sResource)
		};
		ActionsManager.outputResult(bSecret, rSource, nil, msgMissing, msgMissing);
		return;
	end

	local msgShort = {
		font = "msgfont",
		icon = "coinroll_resources",
		text = string.format(Interface.getString("resource_action_result_gain_short"), sResource)
	};
	local msgLong = {
		font = "msgfont",
		icon = "roll_resource"
	};

	if bAll and nOverflow < 0 then
		msgLong.text = string.format(Interface.getString("resource_action_result_no_limit"), sResource, nRemaining);
	else
		local sGain;
		if bAll then
			sGain = Interface.getString("resource_action_result_all");
		else
			sGain = tostring(nTotal);
		end
		msgLong.text = string.format(Interface.getString("resource_action_result_gain_long"), sResource, sGain, nRemaining);
	end

	ActionsManager.outputResult(bSecret, rSource, nil, msgLong, msgShort);
end

function applyResourceLoss(rSource, rTarget, bSecret, nTotal, sOperation, sResource, bAll)
	local nRemaining, nOverflow = ResourceManager.adjustResource(rSource, sResource, -nTotal, sOperation, bAll);
	if not nOverflow then
		local msgMissing = {
			font = "msgfont",
			icon = "roll_resource",
			text = string.format(Interface.getString("resource_action_result_missing"), sResource)
		};
		ActionsManager.outputResult(bSecret, rSource, nil, msgMissing, msgMissing);
		return;
	end

	local msgShort = {
		font = "msgfont",
		icon = "roll_resource",
		text = string.format(Interface.getString("resource_action_result_loss_short"), sResource)
	};
	local msgLong = {
		font = "msgfont",
		icon = "roll_resource"
	};

	local sLoss;
	if bAll then
		sLoss = Interface.getString("resource_action_result_all");
	else
		sLoss = tostring(nTotal);
	end
	msgLong.text = string.format(Interface.getString("resource_action_result_loss_long"), sResource, sLoss, nRemaining);

	ActionsManager.outputResult(bSecret, rSource, nil, msgLong, msgShort);
end

function handleSpendEffects(rSource, rTarget, bSecret, nSpend, sResource)
	EffectManagerCG.setActiveActor(rSource);
	local nodeCT = ActorManager.getCTNode(rSource);
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		-- Check active
		local nActive = DB.getValue(nodeEffect, "isactive", 0);
		if (nActive ~= 0) then
			local sLabel = DB.getValue(nodeEffect, "label", "");
			local sApply = DB.getValue(nodeEffect, "apply", "");
			local aEffectComps = EffectManager.parseEffect(sLabel);
			local nMatch = 0;
			for kEffectComp,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = EffectManager5E.parseEffectComp(sEffectComp);
				-- Handle conditionals
				if rEffectComp.type == "IF" then
					if not EffectManager5E.checkConditional(rSource, nodeEffect, rEffectComp.remainder) then
						break;
					end
				elseif rEffectComp.type == "IFT" then
					if not rTarget then
						break;
					end
					if not EffectManager5E.checkConditional(rTarget, nodeEffect, rEffectComp.remainder, rSource) then
						break;
					end
					bTargeted = true;
				elseif StringManager.contains(rEffectComp.remainder, sResource) then
					if StringManager.contains({"RSRCHEALS", "RSRCHEALT"}, rEffectComp.type) then
						notifyResourceHeal(rSource, rTarget, sEffectComp, bSecret, nSpend, sResource)
						nMatch = nMatch + 1;
					end
				end
			end

			-- Remove one shot effects
			if nMatch > 0 then
				if nActive == 2 then
					DB.setValue(v, "isactive", "number", 1);
				else
					if sApply == "action" then
						EffectManager.notifyExpire(v, 0);
					elseif sApply == "roll" then
						EffectManager.notifyExpire(v, 0, true);
					elseif sApply == "single" then
						EffectManager.notifyExpire(v, nMatch, true);
					end
				end
			end
		end  -- END ACTIVE CHECK
	end  -- END EFFECT LOOP
	EffectManagerCG.setActiveActor(nil);
end

function notifyResourceHeal(rSource, rTarget, sEffectComp, bSecret, nSpend, sResource)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_RESOURCE_HEAL;

	if bSecret then
		msgOOB.nSecret = 1;
	else
		msgOOB.nSecret = 0;
	end

	msgOOB.nSpend = nSpend;
	msgOOB.sResource = sResource;
	msgOOB.sEffectComp = sEffectComp;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCreatureNodeName(rTarget);

	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget);
	if nodeTarget and (sTargetNodeType == "pc") then
		if Session.IsHost then
			local sOwner = DB.getOwner(nodeTarget);
			if sOwner ~= "" then
				for _,vUser in ipairs(User.getActiveUsers()) do
					if vUser == sOwner then
						for _,vIdentity in ipairs(User.getActiveIdentities(vUser)) do
							if nodeTarget.getName() == vIdentity then
								Comm.deliverOOBMessage(msgOOB, sOwner);
								return;
							end
						end
					end
				end
			end
		else
			if DB.isOwner(nodeTarget) then
				handleResourceHeal(msgOOB);
				return;
			end
		end
	end

	Comm.deliverOOBMessage(msgOOB, "");
end

function handleResourceHeal(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	local rEffectComp = EffectManager5E.parseEffectComp(msgOOB.sEffectComp);
	local bSecret = tonumber(msgOOB.nSecret) == 1;

	local rAction = {};
	rAction.label = msgOOB.sResource;
	rAction.clauses = {};

	local rClause = {};
	rClause.dice = rEffectComp.dice;
	rClause.modifier = rEffectComp.mod;
	if #rClause.dice == 0 and rClause.modifier == 0 then
		rClause.modifier = msgOOB.nSpend
	end
	-- The modifier has already been accounted for in the resource expenditure.
	rClause.modifier = rClause.modifier - ModifierStack.getSum();
	table.insert(rAction.clauses, rClause);

	local aTargets = {};
	if "RSRCHEALS" == rEffectComp.type then
		table.insert(aTargets, rSource);
	elseif rTarget and rTarget.sCTNode ~= rSource.sCTNode then
		table.insert(aTargets, rTarget);
	else
		local nodeCT = ActorManager.getCTNode(rSource);
		for _,nodeTarget in pairs(DB.getChildren(nodeCT, "targets")) do
			local rEffectTarget = ActorManager.resolveActor(DB.getValue(nodeTarget, "noderef"));
			table.insert(aTargets, rEffectTarget);
		end
	end
	if #aTargets == 0 and bSecret == false then
		table.insert(aTargets, rSource);
	end

	local rRoll = ActionHeal.getRoll(rSource, rAction);
	if rRoll then
		rRoll.bSecret = bSecret;
		ActionsManager.actionDirect(rSource, rRoll.sType, {rRoll}, {aTargets});
	end
end