module vrt.vacuum.clazz;

import core.typeinfo: TypeInfo, ClassInfo, Type;


extern(C) fn vrt_handle_cast(obj: void*, tinfo: TypeInfo) void*
{
	if (obj is null)
		return null;

	list := **cast(ClassInfo[]**)obj;
	foreach (i, ti; list) {
		if (list[i] is tinfo) {
			return obj;
		}
		if (tinfo.type == Type.Interface) {
			cinfo := list[i];
			foreach (iface; cinfo.interfaces) {
				if (iface.info is tinfo) {
					ptr := cast(ubyte*)obj;
					return cast(void*)(ptr + iface.offset);
				}
			}
		}
	}
	return null;
}
