-- 
-- Please see the license.txt file included with this distribution for 
-- attribution and copyright information.
--

local restOriginal;

function onInit()
	restOriginal = CharManager.rest;
	CharManager.rest = rest;
end

function rest(nodeChar, bLong)
	restOriginal(nodeChar, bLong);
	ResourceManager.rest(ActorManager.resolveActor(nodeChar), bLong);
end