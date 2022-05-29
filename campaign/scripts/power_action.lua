--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

local updateDisplayOriginal;
local onDataChangedOriginal;

local rActor;
local sRegisteredName;

function onInit()
	local nodeAction = getDatabaseNode();
	rActor = ActorManager.resolveActor(nodeAction.getChild("....."));

	updateDisplayOriginal = super.updateDisplay;
	super.updateDisplay = updateDisplay;

	onDataChangedOriginal = super.onDataChanged;
	super.onDataChanged = onDataChanged;

	DB.addHandler(DB.getPath(nodeAction, "resource"), "onUpdate", onResourceNameChanged);
	addSpecialHandlers();

	super.onInit();
end

function onClose()
	if super and super.onClose then
		super.onClose();
	end

	local nodeAction = getDatabaseNode();
	DB.removeHandler(DB.getPath(nodeAction, "resource"), "onUpdate", onResourceNameChanged);
	removeSpecialHandlers();
end

function updateDisplay()
	updateDisplayOriginal();

	local node = getDatabaseNode();
	local sType = DB.getValue(node, "type", "");
	local bShowResource = (sType == "resource");

	resourcebutton.setVisible(bShowResource);
	resourcelabel.setVisible(bShowResource);
	resourceview.setVisible(bShowResource);
	resourcedetail.setVisible(bShowResource);
end

function onDataChanged()
	onDataChangedOriginal();

	local sType = DB.getValue(getDatabaseNode(), "type", "");
	if sType == "resource" then
		onResourceChanged();
	end
end

function onResourceChanged()
	local sResource = PowerManagerCg.getPCPowerResourceActionText(getDatabaseNode());
	resourceview.setValue(sResource);
end

function onResourceNameChanged()
	removeSpecialHandlers();
	addSpecialHandlers();
	onResourceChanged();
end

function addSpecialHandlers()
	sRegisteredName = DB.getValue(getDatabaseNode(), "resource", "");
	ResourceManager.addSpecialResourceChangeHandlers(rActor, sRegisteredName, onResourceChanged, nil);
end

function removeSpecialHandlers()
	ResourceManager.removeSpecialResourceChangeHandlers(rActor, sRegisteredName, onResourceChanged, nil);
end