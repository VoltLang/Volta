// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.object;

static import object;


/+
alias string = immutable(char)[];
alias wstring = immutable(wchar)[];
alias dstring = immutable(dchar)[];

version (V_P64) {
	alias size_t = ulong;
	alias ptrdiff_t = long;
} else {
	alias size_t = uint;
	alias ptrdiff_t = int;
}
+/

alias ModuleInfo = object.ModuleInfo;
alias moduleInfoRoot = object.moduleInfoRoot;
alias Object = object.Object;
alias Attribute = object.Attribute;
