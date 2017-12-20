module impl;

import iface;

class Impl : IFace
{
	override fn getValue() i32
	{
		return 12;
	}
}
