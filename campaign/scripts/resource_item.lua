-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local nodeResource;
local rActor;
local bUpdating;
local sRegisteredName;

function onInit()
	nodeResource = getDatabaseNode();
	rActor = ActorManager.resolveActor(nodeResource.getChild("..."));
	DB.addHandler(DB.getPath(nodeResource, "name"), "onUpdate", onNameChanged);
	DB.addHandler(DB.getPath(nodeResource, "current"), "onUpdate", onCurrentChanged);
	DB.addHandler(DB.getPath(nodeResource, "limit"), "onUpdate", onLimitChanged);
	addSpecialHandlers();
	current.onValueChanged = onCurrentFieldChanged;

	onCurrentChanged();
	onLimitChanged();
end

function onClose()
	DB.removeHandler(DB.getPath(nodeResource, "name"), "onUpdate", onNameChanged);
	DB.removeHandler(DB.getPath(nodeResource, "current"), "onUpdate", onCurrentChanged);
	DB.removeHandler(DB.getPath(nodeResource, "limit"), "onUpdate", onLimitChanged);
	removeSpecialHandlers();
end

function onNameChanged()
	removeSpecialHandlers();
	addSpecialHandlers();
	onCurrentChanged();
	onLimitChanged();
end

function onCurrentChanged()
	if bUpdating then
		return;
	end

	bUpdating = true;
	local nValue = ResourceManager.getCurrentResource(rActor, name.getValue(), nodeResource);
	current.setValue(nValue);
	bUpdating = false;
end

function onCurrentFieldChanged()
	if bUpdating then
		return;
	end

	bUpdating = true;
	local nValue = ResourceManager.getCurrentResource(rActor, name.getValue(), nodeResource);
	local nNewValue = current.getValue();
	if nNewValue ~= nValue then
		ResourceManager.adjustResource(rActor, name.getValue(), nNewValue - nValue);
	end
	bUpdating = false;
end

function onLimitChanged()
	local sLimit = "∞";
	local nValue = ResourceManager.getResourceLimit(rActor, name.getValue(), nodeResource);
	if nValue ~= 0 then
		sLimit = tostring(nValue)
		current.setMaxValue(nValue)
	else
		current.setMaxValue(math.huge)
	end
	limitdisplay.setValue(sLimit);
end

function addSpecialHandlers()
	sRegisteredName = name.getValue();
	ResourceManager.addSpecialResourceChangeHandlers(rActor, sRegisteredName, onCurrentChanged, onLimitChanged);
end

function removeSpecialHandlers()
	ResourceManager.removeSpecialResourceChangeHandlers(rActor, sRegisteredName, onCurrentChanged, onLimitChanged);
end