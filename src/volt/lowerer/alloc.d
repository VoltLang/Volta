/*#D*/
// Copyright © 2012-2013, Bernard Helyer.  All rights reserved.
// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.alloc;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.interfaces;
import volt.token.location;


/*!
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
		countConst.loc = loc;
		countConst.u._ulong = cast(ulong)-2;
		countConst.type = buildSizeT(/*#ref*/loc, lp.target);
		countArg = countConst;
	}

	auto adRef = new ir.ExpReference();
	adRef.loc = loc;
	adRef.idents ~= "allocDg";
	adRef.decl = lp.gcAllocDgVariable;

	auto _tidExp = new ir.Typeid();
	_tidExp.loc = loc;
	_tidExp.type = copyTypeSmart(/*#ref*/loc, type);
	auto tidExp = buildCastSmart(/*#ref*/loc, lp.tiTypeInfo, _tidExp);

	auto pfixCall = new ir.Postfix();
	pfixCall.loc = loc;
	pfixCall.op = ir.Postfix.Op.Call;
	pfixCall.child = adRef;
	pfixCall.arguments = [tidExp, countArg];

	return pfixCall;
}

/*!
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

	auto result = new ir.PointerType(copyTypeSmart(/*#ref*/loc, type));
	result.loc = loc;
	auto resultCast = new ir.Unary(result, pfixCall);
	resultCast.loc = loc;
	return resultCast;
}
