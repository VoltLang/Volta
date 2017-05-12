module test;

import vrt.gc.slab;
import vrt.gc.mman;
import vrt.ext.stdc;


fn allocSlab(order: u8) Slab*
{
	slotSize := orderToSize(order);
	slab := cast(Slab*)calloc(typeid(Slab).size, 1);
	memory := pages_map(null, slotSize * 512);
	slab.setup(order, memory, false, false);
	return slab;
}

fn ptr2slot(slab: Slab*, i: size_t, expectedSlot: u32) bool
{
	ptr := cast(void*)i;
	slot := slab.pointerToSlot(ptr);
	outv := cast(u32)slot == expectedSlot;
	return outv;
}

fn pointerToSlotTest(slab: Slab*) i32
{
	slotSize := orderToSize(slab.order);
	expectedSlot: u32;
	for (i: size_t = slab.extent.min; i < slab.extent.max; i += slotSize) {
		if (!ptr2slot(slab, i, expectedSlot)) {
			return 1;
		}
		if (slab.order >= 1 && i < (slab.extent.max - 1) && !ptr2slot(slab, i + 1, expectedSlot)) {
			return 1;
		}
		if (i > 0 && !ptr2slot(slab, i - 1, expectedSlot - 1)) {
			return 1;
		}
		if (i < (slab.extent.max - slotSize) && !ptr2slot(slab, i + slotSize, expectedSlot + 1)) {
			return 1;
		}
		expectedSlot++;
	}
	return 0;
}

fn main() i32
{
	result: i32;
	foreach (order; 0 .. 13) {
		slab := allocSlab(cast(u8)order);
		result += pointerToSlotTest(slab);
	}
	return result;
}

