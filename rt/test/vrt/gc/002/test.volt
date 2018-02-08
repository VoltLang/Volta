module test;

import vrt.gc.slab;
import vrt.ext.stdc;


fn alignMemory(memory: void*, alignment: size_t) void*
{
	value := cast(size_t) memory;
	return cast(void*) ((value + alignment-1) & ~(alignment-1));
}

fn main() i32
{
	/*
	 * Make the tests be as close to what will happen in the GC so we must
	 * allocate memory for the Slab to use. Also make sure that the memory
	 * is properly aligned.
	 */
	order := sizeToOrder(16);
	size := orderToSize(order) * Slab.MaxSlots + Slab.Alignment;
	memory := calloc(1, size);
	if (memory is null) {
		return 5;
	}

	block: Slab;
	block.setup(order, alignMemory(memory, Slab.Alignment), false, false, false);

	// Allocate 511 blocks, check that one is left.
	foreach (0 .. 511) {
		block.allocate();
	}
	if (block.freeSlots != 1) {
		return 1;
	}

	// Allocate the last one
	block.allocate();
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

	free(memory);

	return 0;
}

