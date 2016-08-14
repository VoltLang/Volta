/**
 * This file is included all modules (this module).
 */
module core.compiler.defaultsymbols;


/**
 * These are two types are aliases to integer types that are large enough to
 * offset the entire available address space.
 * @{
 */
version (V_P64) {
	alias size_t = u64;
	alias ptrdiff_t = i64;
} else {
	alias size_t = u32;
	alias ptrdiff_t = i32;
}
/**
 * @}
 */

/// The string type.
alias string = immutable(char)[];
