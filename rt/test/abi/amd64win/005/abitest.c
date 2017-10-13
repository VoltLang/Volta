#include <stdint.h>

typedef struct {
	uint64_t a;
} ColourA;

typedef struct {
	uint8_t a;
} ColourB;

typedef struct {
	uint8_t a, b;
} ColourC;

int32_t testColour(void* a, void* b, ColourA colour, ColourB cb, ColourC cc)
{
	if (colour.a != 34908) {
		return 1;
	}
	if (cb.a != 45) {
		return 2;
	}
	if (cc.a != 12 || cc.b != 34) {
		return 3;
	}
	return 0;
}
