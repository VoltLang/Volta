// Copyright © 2005-2009, Sean Kelly.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup stdcbind
 */
module core.c.stdio;

version (CRuntime_All):


private
{
	import core.c.config;
	import core.c.stddef; // for size_t
	import core.c.stdarg; // for va_list

	/+version (FreeBSD) {
		import core.sys.posix.sys.types;
	}+/
}


extern(C):
@system:
nothrow:

version (Windows) {

	enum
	{
		BUFSIZ       = 0x4000,
		EOF          = -1,
		FOPEN_MAX    = 20,
		FILENAME_MAX = 256, // 255 plus NULL
		TMP_MAX      = 32767,
		SYS_OPEN     = 20,      // non-standard
	}

	enum i32     _NFILE     = 60;       // non-standard
	enum string  _P_tmpdir  = "\\"; // non-standard
//	enum string _wP_tmpdir = "\\"; // non-standard
//	enum i32     L_tmpnam   = _P_tmpdir.length + 12;

} else version (Linux) {

	enum {
		BUFSIZ       = 8192,
		EOF          = -1,
		FOPEN_MAX    = 16,
		FILENAME_MAX = 4095,
		TMP_MAX      = 238328,
		L_tmpnam     = 20,
	}

} else version (OSX) {

	enum
	{
		BUFSIZ       = 1024,
		EOF          = -1,
		FOPEN_MAX    = 20,
		FILENAME_MAX = 1024,
		TMP_MAX      = 308915776,
		L_tmpnam     = 1024,
	}

	private
	{
		struct __sbuf
		{
			_base:  i8*;
			_size:  i32;
		}

		struct __sFILEX
		{

		}
	}

} else {

	static assert( false, "Unsupported platform" );

}

enum
{
	SEEK_SET,
	SEEK_CUR,
	SEEK_END
}

version (Windows) {

	struct _iobuf
	{
		_ptr:     char*;
		_cnt:     i32;
		_base:    char*;
		_flag:    i32;
		_file:    i32;
		_charbuf: i32;
		_bufsiz:  i32;
		__tmpnum: char*;
	}

} else version (Linux) {

	align(1) struct _iobuf
	{
		_flags:         i32;
		_read_ptr:      char*;
		_read_end:      char*;
		_read_base:     char*;
		_write_base:    char*;
		_write_ptr:     char*;
		_write_end:     char*;
		_buf_base:      char*;
		_buf_end:       char*;
		_save_base:     char*;
		_backup_base:   char*;
		_save_end:      char*;
		_markers:       void*;
		_chain:         _iobuf*;
		_fileno:        i32;
		_blksize:       i32;
		_old_offset:    i32;
		_cur_column:    i32;
		_vtable_offset: i8;
		_shortbuf:      char[1];
		_lock:          void*;
	}


} else version (OSX) {

	align (1) struct _iobuf
	{
		_p:       i8*;
		_r:       i32;
		_w:       i32;
		_flags:   i16;
		_file:    i16;
		_bf:      __sbuf;
		_lbfsize: i32;

		_close:   fn(void*) (i32*);
		_read:    fn(void*, char*, i32) (i32*);
		_seek:    fn(void*, fpos_t, i32) (fpos_t*);
		_write:   fn(void*, char*, i32) (i32*);

		_ub:      __sbuf;
		_extra:   __sFILEX*;
		_ur:      i32;

		_ubuf:    u8[3];
		_nbuf:    u8[1];

		_lib:     __sbuf;

		_blksize: i32;
		_offset:  fpos_t;
	}

} else {

	static assert( false, "Unsupported platform" );

}


alias FILE = _iobuf;

enum
{
	_F_RDWR = 0x0003, // non-standard
	_F_READ = 0x0001, // non-standard
	_F_WRIT = 0x0002, // non-standard
	_F_BUF  = 0x0004, // non-standard
	_F_LBUF = 0x0008, // non-standard
	_F_ERR  = 0x0010, // non-standard
	_F_EOF  = 0x0020, // non-standard
	_F_BIN  = 0x0040, // non-standard
	_F_IN   = 0x0080, // non-standard
	_F_OUT  = 0x0100, // non-standard
	_F_TERM = 0x0200, // non-standard
}

version (Windows) {

	enum {
		_IOFBF   = 0,
		_IOLBF   = 0x40,
		_IONBF   = 4,
		_IOREAD  = 1,     // non-standard
		_IOWRT   = 2,     // non-standard
		_IOMYBUF = 8,     // non-standard
		_IOEOF   = 0x10,  // non-standard
		_IOERR   = 0x20,  // non-standard
		_IOSTRG  = 0x40,  // non-standard
		_IORW    = 0x80,  // non-standard
		_IOTRAN  = 0x100, // non-standard
		_IOAPP   = 0x200, // non-standard
	}

	extern global _fcloseallp: fn();

	version (MSVC) {

		extern(Windows) fn __acrt_iob_func(i32) FILE*;

		extern(Volt) {
			@property fn stdin() FILE* { return __acrt_iob_func(0); }
			@property fn stdout() FILE* { return __acrt_iob_func(1); }
			@property fn stderr() FILE* { return __acrt_iob_func(2); }
		}

	} else {

		private extern global _iob: FILE[/*_NFILE*/60];

		extern(Volt) {
			@property fn stdin() FILE*  { return cast(FILE*) &_iob[0]; }
			@property fn stdout() FILE* { return cast(FILE*) &_iob[1]; }
			@property fn stderr() FILE* { return cast(FILE*) &_iob[2]; }
		}
	}

} else version (Linux) {

	enum
	{
		_IOFBF = 0,
		_IOLBF = 1,
		_IONBF = 2,
	}

	extern global stdin: FILE*;
	extern global stdout: FILE*;
	extern global stderr: FILE*;

} else version (OSX) {

	enum
	{
		_IOFBF = 0,
		_IOLBF = 1,
		_IONBF = 2,
	}

	extern global /*shared*/ __stdinp: FILE*;
	extern global /*shared*/ __stdoutp: FILE*;
	extern global /*shared*/ __stderrp: FILE*;

	alias stdin = __stdinp;
	alias stdout = __stdoutp;
	alias stderr = __stderrp;

} else {

	static assert( false, "Unsupported platform" );

}

alias fpos_t = i32;

fn remove(in filename: char*) i32;
fn rename(in from: char*, in to: char*) i32;

@trusted fn tmpfile() FILE*; // No unsafe pointer manipulation.
fn tmpnam(s: char*) char*;

fn fclose(stream: FILE*) i32;

// No unsafe pointer manipulation.
@trusted fn fflush(stream: FILE*) i32;

fn fopen(in filename: char*, in mode: char*) FILE*;
fn freopen(in filename: char*, in mode: char*, stream: FILE*) FILE*;

fn setbuf(stream: FILE*, buf: char*);
fn setvbuf(stream: FILE*, buf: char*, mode: i32, size: size_t) i32;

fn fprintf(stream: FILE*, in format: const(char)*, ...) i32;
fn fscanf(stream: FILE*, in format: const(char)*, ...) i32;
fn sprintf(s: char*, in format: const(char)*, ...) i32;
fn sscanf(s: const(char)*, in format: const(char)*, ...) i32;
fn vfprintf(stream: FILE*, format: const(char)*, arg: va_list) i32;
fn vfscanf(stream: FILE*, in format: const(char)*, arg: va_list) i32;
fn vsprintf(s: char*, in format: const(char)*, arg: va_list) i32;
fn vsscanf(in s: const(char)*, in format: const(char)*, arg: va_list) i32;
fn vprintf(in format: const(char)*, arg: va_list) i32;
fn vscanf(in format: const(char)*, arg: va_list) i32;
fn printf(in format: const(char)*, ...) i32;
fn scanf(in format: const(char)*, ...) i32;

// No unsafe pointer manipulation.
@trusted
{
	fn fgetc(stream: FILE*) i32;
	fn fputc(c: i32, stream: FILE*) i32;
}

fn fgets(s: char*, n: i32, stream: FILE*) char*;
fn fputs(in s: char*, stream: FILE*) i32;
fn gets(s: char*) char*;
fn puts(in s: char*) i32;

// No unsafe pointer manipulation.
extern(Volt) @trusted
{
	fn getchar() i32                   { return getc(stdin);     }
	fn putchar(c: i32) i32             { return putc(c, stdout);  }
	fn getc(stream: FILE*) i32         { return fgetc(stream);   }
	fn putc(c: i32, stream: FILE*) i32 { return fputc(c, stream); }
}

@trusted fn ungetc(c: i32, stream: FILE*) i32;// No unsafe pointer manipulation.

fn fread(ptr: void*, size: size_t, nmemb: size_t, stream: FILE*) size_t;
fn fwrite(in ptr: void*, size: size_t, nmemb: size_t, stream: FILE*) size_t;

// No unsafe pointer manipulation.
@trusted
{
	fn fgetpos(stream: FILE*, pos: fpos_t*) i32;
	fn fsetpos(stream: FILE*, in pos: fpos_t*) i32;

	fn    fseek(stream: FILE*, offset: c_long, whence: i32) i32;
	fn ftell(stream: FILE*) c_long;
}

version (Windows) {

	/+
	// No unsafe pointer manipulation.
	extern(D) @trusted
	{
		void rewind(FILE* stream)   { fseek(stream,0L,SEEK_SET); stream._flag&=~_IOERR; }
		pure void clearerr(FILE* stream) { stream._flag &= ~(_IOERR|_IOEOF);                 }
		pure int  ferror(FILE* stream)   { return stream._flag&_IOERR;                       }
	}+/

	fn feof(stream: FILE*) i32;

	version (MSVC) {
		fn   snprintf(s: char*, n: size_t, in fmt: char*, ...) i32;
	} else {
		fn   _snprintf(s: char*, n: size_t, in fmt: char*, ...) i32;
		alias snprintf = _snprintf;
	}

	fn   _vsnprintf(s: char*, n: size_t, in format: char*, arg: va_list) i32;
	alias vsnprintf = _vsnprintf;

} else version (Linux) {

	fn popen(const(char)*, const(char)*) FILE*;
	fn pclose(FILE*) i32;

	// No unsafe pointer manipulation.
	@trusted
	{
		fn rewind(stream: FILE*);
		pure fn clearerr(stream: FILE*);
		pure fn  feof(stream: FILE*) i32;
		pure fn  ferror(stream: FILE*) i32;
		fn  fileno(FILE*) i32;
	}

	fn  snprintf(s: char*, n: size_t, in format: char*, ...) i32;
	fn  vsnprintf(s: char*, n: size_t, in format: char*, arg: va_list) i32;

} else version (OSX) {

	fn popen(const(char)*, const(char)*) FILE*;
	fn pclose(FILE*) i32;

	// No unsafe pointer manipulation.
	@trusted
	{
		fn rewind(FILE*);
		pure fn clearerr(FILE*);
		pure fn  feof(FILE*) i32;
		pure fn  ferror(FILE*) i32;
		fn  fileno(FILE*) i32;
	}

	fn  snprintf(s: char*, n: size_t, in format: char*, ...) i32;
	fn  vsnprintf(s: char*, n: size_t, in format: char*, arg: va_list) i32;

} else {

    static assert( false, "Unsupported platform" );

}

fn perror(in s: char*);
fn unlink(s: const char*) i32;
