module volt.visitor.iexpreplace;

import volt.visitor.visitor;

class IdentifierExpReplacer : NullVisitor
{
public:
	this(string from, string to)
	{
		this.from = from;
		this.to = to;
	}

public:
	string from;
	string to;

public:
	override Status visit(ref ir.Exp exp, ir.IdentifierExp iexp)
	{
		if (iexp.value == from) {
			iexp.value = to;
		}
		return Continue;
	}
}

