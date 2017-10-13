// simple integer coercion

#include <stdint.h>

typedef struct {
	uint8_t r, g, b, a;
} Colour;

int32_t testColour(void* a, void* b, Colour colour)
{
	if (colour.r != 32 || colour.g != 64 || colour.b != 16 || colour.a != 128) {
		return 1;
	} else {
		return colour.g - 64;
	}
}
