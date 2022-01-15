# Capital Gains
A Fantasy Grounds extension that adds support for managing custom resources.

A new Resources section has been added to both that character sheet and NPC sheet. Resources can be configured to have an upper limit or be left limitless. They may also be configured to gain and/or lose value periodically, such as on the start of the turn or after a long rest, for example. Resource definitions may also be shared amongst multiple characters by dropping a reference to the "Share with" list in the resource editor. (Resource sharing requires all participants to be in the CT for full automation.)

There is also a new Resource action type, which may be configured to spend or gain the associated resource. A resource spending action may be configured as variable to specific a minimum and (optional) maximum value to spend when using the action, enabling the value to be changed on the fly via Ctrl+Mouse Wheel on either the action text or mini-action button.

The following syntax additions have been made for effect processing:
* **[CURRENT(n\*Resource Name)]** - When the effect is applied this notation will be replaced with the current value of the named resource, multiplied by n. n is optional.
* **[SPENT(n\*Resource Name)]** - When the effect is applied this notation will be replaced with the amount of the named resource that has been spent this turn, multiplied by n. n is optional.
* **CURRENT(n\*Resource Name)** - When the effect is evaluated this notation will be replaced with the value of the named resource, multiplied by n. n is optional.
* **SPENT(n\*Resource Name)** - When the effect is evaluated this notation will be replaced with the amount of the named resource that has been spent this turn, multiplied by n. n is optional.

The following effects have been added:
* **RSRCHEAL: d, Resource Name** - While this effect is active any time the named resource is spent by the bearer of this effect, the target(s) of the effect is/are healed by d (which can be any dice string). If no target is specified then the bearer is healed.
* **GRANTS: d, Resource Name** - While this effect is active on the start of the bearer's turn, the applier of the effect will gain d (which can be any dice string) of the named resource.
* **SGRANTS: d, Resource Name** - While this effect is active on the start of the applier's turn, the applier of the effect will gain d (which can be any dice string) of the named resource.

## Installation
Download [CapitalGains.ext](https://github.com/MeAndUnique/CapitalGains/releases) and place in the extensions subfolder of the Fantasy Grounds data folder.

## Attribution
SmiteWorks owns rights to code sections copied from their rulesets by permission for Fantasy Grounds community development.
'Fantasy Grounds' is a trademark of SmiteWorks USA, LLC.
'Fantasy Grounds' is Copyright 2004-2021 SmiteWorks USA LLC.

<div>Icons made by <a href="https://www.flaticon.com/authors/wanicon" title="wanicon">wanicon</a> from <a href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a></div>