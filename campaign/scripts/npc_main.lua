-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local updateOriginal;

function onInit()
	updateOriginal = super.update;
	super.update = update;

	super.onInit();
end

function update()
	updateOriginal();

	local nodeRecord = getDatabaseNode();
	local bReadOnly = WindowManager.getReadOnlyState(nodeRecord);
	if bReadOnly then
		if resources_iedit then
			resources_iedit.setValue(0);
			resources_iedit.setVisible(false);
			resources_iadd.setVisible(false);
		end
		
		local bShow = (resources.getWindowCount() ~= 0);
		header_resources.setVisible(bShow);
		resources.setVisible(bShow);
	else
		if resources_iedit then
			resources_iedit.setVisible(true);
			resources_iadd.setVisible(true);
		end
		header_resources.setVisible(true);
		resources.setVisible(true);
	end
end