module vrt.string;

/**
 * Generate a hash for a string.
 * djb2 algorithm stolen from http://www.cse.yorku.ca/~oz/hash.html
 *
 * This needs to correspond with the implementation
 * in volt.util.string in the compiler.
 */
extern(C) uint vrt_hash(string s)
{
	uint h = 5381;

	for (size_t i = 0; i < s.length; i++) {
		h = ((h << 5) + h) + s[i];
	}

	return h;
}

