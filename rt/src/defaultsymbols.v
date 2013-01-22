module defaultsymbols;

version (V_P64) {
	alias size_t = ulong;
} else {
	alias size_t = uint;
}

alias string = immutable(char)[];
