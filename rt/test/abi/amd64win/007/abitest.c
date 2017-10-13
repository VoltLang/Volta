// simple integer coercion

#include <stdint.h>

typedef struct {
	uint8_t a[2];
} Internal;

typedef struct {
	Internal i;
} Colour;

int32_t testColour(void* a, void* b, Colour c)
{
	return c.i.a[0] + c.i.a[1];
}
