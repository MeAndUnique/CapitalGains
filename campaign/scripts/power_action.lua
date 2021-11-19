-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local updateDisplayOriginal;
local onDataChangedOriginal;

function onInit()
	updateDisplayOriginal = super.updateDisplay;
	super.updateDisplay = updateDisplay;

	onDataChangedOriginal = super.onDataChanged;
	super.onDataChanged = onDataChanged;

	super.onInit();
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