module test;

import vrt.gc.slab;


fn main() int
{
	block: Slab;
	block.setup(0, null, false);

	// Allocate 511 blocks, check that one is left.
	foreach (0 .. 511) {
		block.allocate(false);
	}
	if (block.freeSlots != 1) {
		return 1;
	}

	// Allocate the last one
	block.allocate(false);
	if (block.freeSlots != 0) {
		return 2;
	}

	// Make sure that bit 5 is not free
	if (block.isFree(5) != false) {
		return 3;
	}

	// Free bit 5 and check that it becomes free
	block.free(5);
	if (block.isFree(5) != true) {
		return 4;
	}

	return 0;
}
