// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.alloc;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.token.location;


/**
 * Creates a call to the allocDg delegate.
 *
 * The type of the returned expression is 'void*'. If countArg is not given,
 * zero is assumed (not a array or class).
 *
 * @param[in] loc       Location to tag expressions and types with.
 * @param[in] lp        LanguagePass
 * @param[in] type      Type to be alloced, copied smartly.
 * @param[in] countArg  A expression returning a value of size_t, not copied.
 */
ir.Exp buildAllocVoidPtr(in Location loc, LanguagePass lp, ir.Type type,
                         ir.Exp countArg = null)
{
	if (countArg is null) {
		auto countConst = new ir.Constant();
		countConst.location = loc;
		countConst.u._ulong = 0;
		countConst.type = buildSizeT(loc, lp);
		countArg = countConst;
	}

	auto adRef = new ir.ExpReference();
	adRef.location = loc;
	adRef.idents ~= "allocDg";
	adRef.decl = lp.allocDgVariable;

	auto _tidExp = new ir.Typeid();
	_tidExp.location = loc;
	_tidExp.type = copyTypeSmart(loc, type);
	auto tidExp = buildCastSmart(loc, lp.typeInfoClass, _tidExp);

	auto pfixCall = new ir.Postfix();
	pfixCall.location = loc;
	pfixCall.op = ir.Postfix.Op.Call;
	pfixCall.child = adRef;
	pfixCall.arguments = [tidExp, countArg];

	return pfixCall;
}

/**
 * Creates a call to the allocDg delegate.
 *
 * The type of the returned expression is 'type*'. If countArg is not given,
 * zero is assumed (not a array or class).
 *
 * @param[in] loc       Location to tag expressions and types with.
 * @param[in] lp        LanguagePass
 * @param[in] type      Type to be alloced, copied smartly.
 * @param[in] countArg  A expression returning a value of size_t, not copied.
 */
ir.Exp buildAllocTypePtr(in Location loc, LanguagePass lp, ir.Type type,
                         ir.Exp countArg = null)
{
	auto pfixCall = buildAllocVoidPtr(loc, lp, type, countArg);

	auto result = new ir.PointerType(copyTypeSmart(loc, type));
	result.location = loc;
	auto resultCast = new ir.Unary(result, pfixCall);
	resultCast.location = loc;
	return resultCast;
}
