module main;

enum AnEnum : i16
{
	AnEntry = 0,
	ASecondEntry,
	AThirdEntry,
	AFourthEntry
}

fn main() i32
{
	if (AnEnum.AFourthEntry != 3) {
		return 7;
	}
	return (AnEnum.ASecondEntry - 1) + AnEnum.AnEntry;
}
