module main;

import vrt.gc.util;
import vrt.gc.util.buddy;

import core.c.stdlib;
import core.c.stdio;


struct TestBuddy = mixin BuddyDefinition!(3, 5, u8);

alias DumpBuddy = TestBuddy;

fn dump(ref b: DumpBuddy)
{
	foreach (i; DumpBuddy.MinOrder .. DumpBuddy.MaxOrder+1) {
		printf("%i: (% 5i) ", i, b.mNumFree[i-DumpBuddy.MinOrder]);
		start := DumpBuddy.offsetOfOrder(i);
		end := start + DumpBuddy.numBitsInOrder(i);
		foreach (j; start .. end) {
			printf(b.getBit(j) ? "1".ptr : "0".ptr);
			foreach (k; 1 .. 1 << (DumpBuddy.MaxOrder - i)) {
				printf(" ");
			}
		}
		printf("\n");
	}
}

global testNum: i32;

fn testAlloc(ref b: TestBuddy, order: size_t, expect: size_t)
{
	testNum++;
	ret := b.alloc(order);
	printf("alloc(%i) -> %i\n", cast(i32)order, cast(i32)ret);
	if (ret == expect) {
		return;
	}
	printf("FAIL ret: %i, expect: %i\n", cast(i32)ret, cast(i32)expect);
	exit(testNum);
}

fn testFree(ref b: TestBuddy, order: size_t, n: size_t)
{
	testNum++;
	printf("free(%i, %i)\n", cast(i32)order, cast(i32)n);
	b.free(order, n);
}

extern(C) fn main() i32
{
	b: TestBuddy;
	b.setup();

	b.dump();
	b.testAlloc(5, 0); // Test 1
	b.testAlloc(5, 1); // Test 2
	b.testAlloc(5, 2); // Test ...
	b.testAlloc(5, 3);
	b.dump();
	b.testFree(5, 0);
	b.testFree(5, 1);
	b.testFree(5, 3);
	b.dump();
	b.testAlloc(4, 0);
	b.testAlloc(4, 2);
	b.dump();
	return 0;
}
