/*#D*/
// Copyright 2018, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module volta.util.stack;

import ir = volta.ir;
import watt.containers.stack;

alias FunctionStack = Stack!(ir.Function);
alias ExpStack = Stack!(ir.Exp);
alias ClassStack = Stack!(ir.Class);
alias BinOpOpStack = Stack!(ir.BinOp.Op);
alias BoolStack = Stack!bool;
alias StringStack = Stack!string;