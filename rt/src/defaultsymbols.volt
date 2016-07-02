/**
 * This file is included all modules (except object and this module).
 */
module defaultsymbols;


/**
 * These are two types are aliases to integer types that are large enough to
 * offset the entire available address space.
 * @{
 */
version (V_P64) {
	alias size_t = ulong;
	alias ptrdiff_t = long;
} else {
	alias size_t = uint;
	alias ptrdiff_t = int;
}
/**
 * @}
 */

/// The string type.
alias string = immutable(char)[];
