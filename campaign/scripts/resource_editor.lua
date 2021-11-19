-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	addPeriodOptions(gainperiod);
	addPeriodOptions(lossperiod);
	limit.onValueChanged = onLimitChanged;
	gainperiod.onValueChanged = refreshGainValues;
	gainall.onValueChanged = refreshGainValues;
	lossall.onValueChanged = refreshLossValues;
	lossperiod.onValueChanged = refreshLossValues;

	onLimitChanged();
end

function addPeriodOptions(control)
	control.unsorted = true;
	control.add("Never");
	control.add("Turn Start");
	control.add("Turn End");
	control.add("Short Rest");
	control.add("Long Rest");

	if PowerManagerKw then
		control.add("Extended Rest");
	end

	if (control.getValue() or "") == "" then
		control.setValue("Never");
	end
end

function onDrop(x, y, draginfo)
	if draginfo.isType("shortcut") then
		local sClass, sRecord = draginfo.getShortcutData();
		local nodeTarget = DB.findNode(sRecord);
		if nodeTarget and StringManager.contains({"charsheet", "npc"}, sClass) then
			local node = getDatabaseNode();
			local sName = DB.getValue(node, "name");
			local nodeMatch;
			for _,nodeResource in pairs(DB.getChildren(nodeTarget, "resources")) do
				if sName == DB.getValue(nodeResource, "name") then
					nodeMatch = nodeResource;
					break;
				end
			end

			if not nodeMatch then
				local nodeResources = DB.createChild(nodeTarget, "resources");
				nodeMatch = DB.createChild(nodeResources);
			end
			DB.copyNode(node, nodeMatch);

			local nodeList = DB.createChild(nodeMatch, "share");
			local nodeShareOther = DB.createChild(nodeList);

			local sPath = node.getPath();
			DB.setValue(nodeShareOther, "class", "string", ActorManager.getActorRecordTypeFromPath(sPath));
			DB.setValue(nodeShareOther, "record", "string", sPath);

			local win = sharelist.createWindow();
			win.setTarget(nodeMatch, sClass);
		end
	end
end

function onLockChanged()
	if header.subwindow then
		header.subwindow.update();
	end
	local bReadOnly = WindowManager.getReadOnlyState(getDatabaseNode());
	limit.setReadOnly(bReadOnly);
	gainperiod.setComboBoxReadOnly(bReadOnly);
end

function onLimitChanged()
	refreshGainValues();
	refreshLossValues();
end

function refreshGainValues()
	local bHasLimit = limit.getValue() ~= 0
	if  not bHasLimit then
		gainall.setValue(0);
	end

	local bCanGain = gainperiod.getValue() ~= "Never";
	label_gainall.setVisible(bHasLimit and bCanGain);
	gainall.setVisible(bHasLimit and bCanGain);

	local bShowValue = bCanGain and (gainall.getValue() == 0);
	gaindice.setVisible(bShowValue);
	gainlabel_plus.setVisible(bShowValue);
	gainstatmult.setVisible(bShowValue);
	gainlabel_statmultx.setVisible(bShowValue);
	gainstat.setVisible(bShowValue);
	gainlabel_plus2.setVisible(bShowValue);
	gainmodifier.setVisible(bShowValue);
end

function refreshLossValues()
	local bCanLose = lossperiod.getValue() ~= "Never";
	label_lossall.setVisible(bCanLose);
	lossall.setVisible(bCanLose);

	local bShowValue = bCanLose and (lossall.getValue() == 0);
	lossdice.setVisible(bShowValue);
	losslabel_plus.setVisible(bShowValue);
	lossstatmult.setVisible(bShowValue);
	losslabel_statmultx.setVisible(bShowValue);
	lossstat.setVisible(bShowValue);
	losslabel_plus2.setVisible(bShowValue);
	lossmodifier.setVisible(bShowValue);
end