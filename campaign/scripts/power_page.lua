-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	super.onInit();
	
	local node = getDatabaseNode();
	DB.addHandler(DB.getPath(node, "resources.*.current"), "onUpdate", super.onAbilityChanged);
end

function onClose()
	local node = getDatabaseNode();
	DB.removeHandler(DB.getPath(node, "resources.*.current"), "onUpdate", super.onAbilityChanged);
end