module test;

import core.rt.gc;

fn main() i32
{
	tmp: u8[128];
	arr := new u8[](64);
	arr  = new u8[](64);

	/* `arr` should now be in the second slot of the 64 slabs.
	 * The collection frees the first slot of the slab.
	 */
	vrt_gc_collect();
	arr[0] = 1;

	// This is allocated in the first slot.
	notImportant := new tmp[1 .. 65];

	return arr[0] - 1;
}
