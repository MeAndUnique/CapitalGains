-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local nodeResource;
local rActor;
local sRegisteredName;

function onInit()
	nodeResource = getDatabaseNode();
	rActor = ActorManager.resolveActor(nodeResource.getChild("..."));
	addPeriodOptions(gainperiod);
	addPeriodOptions(lossperiod);
	DB.addHandler(DB.getPath(nodeResource, "name"), "onUpdate", onNameChanged);
	limit.onValueChanged = onLimitChanged;
	gainperiod.onValueChanged = refreshGainValues;
	gainall.onValueChanged = refreshGainValues;
	lossall.onValueChanged = refreshLossValues;
	lossperiod.onValueChanged = refreshLossValues;
	addSpecialHandlers();

	onLimitChanged();
	update();
end

function onClose()
	DB.removeHandler(DB.getPath(nodeResource, "name"), "onUpdate", onNameChanged);
	removeSpecialHandlers();
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
		control.add("Intrigue");
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
			local sName = DB.getValue(nodeResource, "name");
			local nodeMatch;
			for _,nodeOtherResource in pairs(DB.getChildren(nodeTarget, "resources")) do
				if sName == DB.getValue(nodeOtherResource, "name") then
					nodeMatch = nodeOtherResource;
					break;
				end
			end

			if not nodeMatch then
				local nodeResources = DB.createChild(nodeTarget, "resources");
				nodeMatch = DB.createChild(nodeResources);
			end
			DB.copyNode(nodeResource, nodeMatch);

			local nodeList = DB.createChild(nodeMatch, "share");
			local nodeShareOther = DB.createChild(nodeList);

			local sPath = nodeResource.getPath();
			DB.setValue(nodeShareOther, "class", "string", ActorManager.getActorRecordTypeFromPath(sPath));
			DB.setValue(nodeShareOther, "record", "string", sPath);

			local win = sharelist.createWindow();
			win.setTarget(nodeMatch, sClass);
		end
	end
end

function update()
	local bReadOnly = WindowManager.getReadOnlyState(nodeResource);
	limit.setReadOnly(bReadOnly);

	gainperiod.setComboBoxReadOnly(bReadOnly);
	gainall.setReadOnly(bReadOnly);
	gaindice.setReadOnly(bReadOnly);
	gainstat.setReadOnly(bReadOnly);
	gainstatmult.setReadOnly(bReadOnly);
	gainmodifier.setReadOnly(bReadOnly);

	lossperiod.setComboBoxReadOnly(bReadOnly);
	lossall.setReadOnly(bReadOnly);
	lossdice.setReadOnly(bReadOnly);
	lossstat.setReadOnly(bReadOnly);
	lossstatmult.setReadOnly(bReadOnly);
	lossmodifier.setReadOnly(bReadOnly);

	if bReadOnly then
		limit.setFrame(nil);

		gainperiod.setFrame(nil);
		gaindice.setFrame(nil);
		gainstat.setFrame(nil);
		gainstatmult.setFrame(nil);
		gainmodifier.setFrame(nil);

		lossperiod.setFrame(nil);
		lossdice.setFrame(nil);
		lossstat.setFrame(nil);
		lossstatmult.setFrame(nil);
		lossmodifier.setFrame(nil);
	else
		limit.setFrame("fielddark", 7, 5, 7, 5);

		gainperiod.setFrame("fieldlight", 7, 5, 7, 5);
		gaindice.onValueChanged(); -- basicdice sets the frame when the value changes.
		gainstat.setFrame("fielddark", 7, 5, 7, 5);
		gainstatmult.setFrame("fielddark", 7, 5, 7, 5);
		gainmodifier.setFrame("fielddark", 7, 5, 7, 5);

		lossperiod.setFrame("fieldlight", 7, 5, 7, 5);
		lossdice.onValueChanged(); -- basicdice sets the frame when the value changes.
		lossstat.setFrame("fielddark", 7, 5, 7, 5);
		lossstatmult.setFrame("fielddark", 7, 5, 7, 5);
		lossmodifier.setFrame("fielddark", 7, 5, 7, 5);
	end
end

function onNameChanged()
	removeSpecialHandlers();
	addSpecialHandlers();
	onLimitChanged();
end

function addSpecialHandlers()
	sRegisteredName = DB.getValue(nodeResource, "name", "");
	ResourceManager.addSpecialResourceChangeHandlers(rActor, sRegisteredName, nil, onLimitChanged);
end

function removeSpecialHandlers()
	ResourceManager.removeSpecialResourceChangeHandlers(rActor, sRegisteredName, nil, onLimitChanged);
end

function onLimitChanged()
	refreshGainValues();
	refreshLossValues();
end

function refreshGainValues()
	local nLimit = ResourceManager.getResourceLimit(rActor, DB.getValue(nodeResource, "name", ""), nodeResource);
	speciallimitlabel.setVisible(nLimit ~= limit.getValue());
	if nLimit ~= limit.getValue() then
		speciallimitlabel.setValue((nLimit - limit.getValue()) .. " +");
	end

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