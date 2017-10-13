// simple integer coercion

#include <stdint.h>

typedef struct {
	uint16_t a, b;
	uint8_t c;
} Colour;

int32_t testColour(void* a, void* b, Colour colour)
{
	if (colour.a != 32 || colour.b != 64 || colour.c != 16) {
		return 1;
	} else {
		return colour.b - 64;
	}
}
