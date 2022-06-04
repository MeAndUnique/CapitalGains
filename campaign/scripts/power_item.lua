--
-- Please see the license.txt file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	if super and super.onInit then
		super.onInit();
	end
	if not windowlist.isReadOnly() then
		if StrainManager then
			registerMenuItem(Interface.getString("power_menu_addresource"), "coins", 3, 6, 4);
		else
			registerMenuItem(Interface.getString("power_menu_addresource"), "coins", 3, 6);
		end
	end
end

function onMenuSelection(selection, subselection, subsubselection)
	if super and super.onMenuSelection then
		super.onMenuSelection(selection, subselection, subsubselection);
	end
	if selection == 3 and subselection == 6 then
		if (not StrainManager) or (subsubselection == 4) then
			createAction("resource");
			activatedetail.setValue(1);
		end
	end
end