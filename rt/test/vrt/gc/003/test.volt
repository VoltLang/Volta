// Tests various aligmnent functions.
module test;

import vrt.gc.util;

fn main() i32
{
	aa: u32[u32] = [
		// 1 -> 2
		0U:  1U,
		1U:  1U,
		2U:  2U,

		// 4 -> 8
		3U:  4U,
		4U:  4U,
		5U:  8U,

		// 16 -> 32
		15U:16U,
		16U:16U,
		17U:32U,
	];

	count: size_t;
	foreach (k, v; aa) {
		++count;

		if (nextHighestPowerOfTwo(k) != v) {
			return cast(int)count;
		}
	}

	if (count != aa.length) {
		return 255;
	}

	return 0;
}

