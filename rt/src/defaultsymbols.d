module defaultsymbols;

version (V_LP64) {
	alias size_t = ulong;
} else {
	alias size_t = uint;
}

alias string = char[];
