-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local sNameNode;

function onInit()
	local node = getDatabaseNode();
	DB.addHandler(DB.getPath(node, "class"), "onUpdate", onNodeUpdated);
	DB.addHandler(DB.getPath(node, "record"), "onUpdate", onNodeUpdated);
	update();
end

function onClose()
	local node = getDatabaseNode();
	DB.removeHandler(DB.getPath(node, "class"), "onUpdate", onNodeUpdated);
	DB.removeHandler(DB.getPath(node, "record"), "onUpdate", onNodeUpdated);
	if sNameNode then
		DB.removeHandler(sNameNode, "onUpdate", onNameUpdated);
	end
end

function setTarget(nodeOtherResource, sClass)
	local node = getDatabaseNode();
	local sPath = nodeOtherResource.getPath();
	DB.setValue(node, "class", "string", sClass);
	DB.setValue(node, "record", "string", sPath);

	local nodeOtherActor = nodeOtherResource.getChild("...");
	update(nodeOtherActor);
end

function update(nodeOtherActor, sClass)
	if sNameNode then
		DB.removeHandler(sNameNode, "onUpdate", onNameUpdated);
	end

	if not nodeOtherActor then
		local sRecord = DB.getValue(getDatabaseNode(), "record");
		if sRecord then
			local nodeOtherResource = DB.findNode(sRecord);
			if nodeOtherResource then
				nodeOtherActor = nodeOtherResource.getChild("...");
			end
		end
	end
	if not sClass then
		sClass = DB.getValue(getDatabaseNode(), "class");
	end

	if nodeOtherActor and sClass then
		shortcut.setValue(sClass, nodeOtherActor.getPath());
		local sName = DB.getValue(nodeOtherActor, "name");
		if not sName or sName == "" then
			sName = Interface.getString("library_recordtype_empty_npc");
		end
		name.setValue(sName);

		sNameNode = DB.getPath(nodeOtherActor, "name");
		DB.addHandler(sNameNode, "onUpdate", onNameUpdated);
	end
end

function onNodeUpdated()
	update();
end

function onNameUpdated(nodeName)
	local sName = nodeName.getValue();
	if not sName or sName == "" then
		sName = Interface.getString("library_recordtype_empty_npc");
	end
	name.setValue(sName);
end