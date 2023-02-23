--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local rActor;
local sRegisteredName;

function onInit()
	local nodeAction = getDatabaseNode();
	rActor = ActorManager.resolveActor(nodeAction.getChild("....."));

	DB.addHandler(nodeAction.getPath(), "onChildUpdate", onDataChanged);
	self.onDataChanged();

	DB.addHandler(DB.getPath(nodeAction, "resource"), "onUpdate", onResourceNameChanged);
	addSpecialHandlers();
end

function onClose()
	local nodeAction = getDatabaseNode();
	DB.removeHandler(nodeAction.getPath(), "onChildUpdate", onDataChanged);
	DB.removeHandler(DB.getPath(nodeAction, "resource"), "onUpdate", onResourceNameChanged);
	removeSpecialHandlers();
end

function onDataChanged()
	local sResource = PowerManagerCG.getPCPowerResourceActionText(getDatabaseNode());
	resourceview.setValue(sResource);
end

function onResourceNameChanged()
	removeSpecialHandlers();
	addSpecialHandlers();
	onDataChanged();
end

function addSpecialHandlers()
	sRegisteredName = DB.getValue(getDatabaseNode(), "resource", "");
	ResourceManager.addSpecialResourceChangeHandlers(rActor, sRegisteredName, onDataChanged, nil);
end

function removeSpecialHandlers()
	ResourceManager.removeSpecialResourceChangeHandlers(rActor, sRegisteredName, onDataChanged, nil);
end

function performAction(draginfo, sSubRoll)
	PowerActionManagerCore.performAction(draginfo, getDatabaseNode(), { sSubRoll = sSubRoll });
end