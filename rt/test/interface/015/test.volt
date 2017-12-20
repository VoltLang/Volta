//T macro:import
module test;

import impl;
import iface;

class AnObject
{
	i: Impl;

	this(i: Impl)
	{
		this.i = i;
	}

	fn getValue() i32
	{
		return retrieveValue(i);
	}
}

fn retrieveValue(i: IFace) i32
{
	return i.getValue();
}

fn main() i32
{
	aobj := new AnObject(new Impl());
	return aobj.getValue() - 12;
}
