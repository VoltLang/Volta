module test;

fn main() i32
{
	arr1 := "hello";
	arr2: string;
	arr3: i32[] = null;
	arr4 := arr1[0 .. 0];
	arr5 := arr1[1 .. 1];

	if (arr2) {
		return 2;
	}
	if (arr3) {
		return 3;
	}
	if (arr4) {
		return 4;
	}
	if (arr5) {
		return 5;
	}

	if (arr1) {
		return 0;
	} else {
		return 1;
	}
}
