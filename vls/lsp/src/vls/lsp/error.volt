module vls.lsp.error;

import vls.lsp.constants;

class Error
{
public:
	code: ErrorCode;
	message: string;

public:
	global fn invalidParams(msg: string) Error
	{
		err := new Error();
		err.code = ErrorCode.InvalidParams;
		err.message = msg;
		return err;
	}
}
