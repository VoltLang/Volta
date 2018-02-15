module vls.lsp.error;

import vls.lsp.constants;

class Error
{
public:
	code: i32;
	message: string;

public:
	global fn invalidParams(msg: string) Error
	{
		err := new Error();
		err.code = ERROR_INVALID_PARAMS;
		err.message = msg;
		return err;
	}
}
