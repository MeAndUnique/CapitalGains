-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	updateValueHeader();
	operation.onValueChanged = updateValueHeader;
	all.onValueChanged = updateValueHeader;
	variable.onValueChanged = updateValueHeader;
end

function updateValueHeader()
	local node = getDatabaseNode();
	local bShowValue = all.getValue() ~= 1;
	local bShowDice = bShowValue and (operation.getStringValue() == "gain");
	local bShowRange = bShowValue and not bShowDice and (variable.getValue() == 1);

	header_value.setVisible(bShowValue);
	if bShowDice then
		header_value.setValue(Interface.getString("power_header_fixed_value"));
	else
		header_value.setValue(Interface.getString("power_header_variable_value"));
	end

	dice.setVisible(bShowDice);
	label_plus.setVisible(bShowDice);
	statmult.setVisible(bShowDice);
	label_statmultx.setVisible(bShowDice);
	stat.setVisible(bShowDice);
	label_plus2.setVisible(bShowDice);

	modifier.setVisible(bShowValue);
	label_variable.setVisible(bShowValue and not bShowDice);
	variable.setVisible(bShowValue and not bShowDice);

	header_range.setVisible(bShowRange);
	min.setVisible(bShowRange);
	max.setVisible(bShowRange);
	interval.setVisible(bShowRange);
end