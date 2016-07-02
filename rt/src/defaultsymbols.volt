/**
 * This file is included all modules (except object and this module).
 */
module defaultsymbols;

version (V_P64) {
	alias size_t = ulong;
	alias ptrdiff_t = long;
} else {
	alias size_t = uint;
	alias ptrdiff_t = int;
}

alias string = immutable(char)[];
