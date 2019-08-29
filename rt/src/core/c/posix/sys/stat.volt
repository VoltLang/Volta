// Copyright 2005-2009, Sean Kelly.
// SPDX-License-Identifier: BSL-1.0
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup posixbind
 */
module core.c.posix.sys.stat;

version (Posix):

private import core.c.posix.config;
private import core.c.stdint;
private import core.c.posix.time;     // for timespec
public import core.c.stddef;          // for size_t
public import core.c.posix.sys.types; // for off_t, mode_t


extern (C):

//
// Required
//
/*
struct stat
{
	dev_t   st_dev;
	ino_t   st_ino;
	mode_t  st_mode;
	nlink_t st_nlink;
	uid_t   st_uid;
	gid_t   st_gid;
	off_t   st_size;
	time_t  st_atime;
	time_t  st_mtime;
	time_t  st_ctime;
}

S_IRWXU
	S_IRUSR
	S_IWUSR
	S_IXUSR
S_IRWXG
	S_IRGRP
	S_IWGRP
	S_IXGRP
S_IRWXO
	S_IROTH
	S_IWOTH
	S_IXOTH
S_ISUID
S_ISGID
S_ISVTX

S_ISBLK(m)
S_ISCHR(m)
S_ISDIR(m)
S_ISFIFO(m)
S_ISREG(m)
S_ISLNK(m)
S_ISSOCK(m)

S_TYPEISMQ(buf)
S_TYPEISSEM(buf)
S_TYPEISSHM(buf)

int    chmod(in char*, mode_t);
int    fchmod(int, mode_t);
int    fstat(int, stat*);
int    lstat(in char*, stat*);
int    mkdir(in char*, mode_t);
int    mkfifo(in char*, mode_t);
int    stat(in char*, stat*);
mode_t umask(mode_t);
 */

alias ulong_t = u64;
alias slong_t = u64;

version (Linux) {

	version (X86) {

		struct stat_t
		{
			st_dev: dev_t;
			__pad1: u16;
//			static if (__USE_FILE_OFFSET64)
//			{
//				uint        __st_ino;
//			}
//			else
//			{
				st_ino: ino_t;
//			}
			st_mode: mode_t;
			st_nlink: nlink_t;
			st_uid: uid_t;
			st_gid: gid_t;
			st_rdev: dev_t;
			__pad2: u16;
			st_size: off_t;
			st_blksize: blksize_t;
			st_blocks: blkcnt_t;
	//		static if (__USE_MISC || __USE_XOPEN2K8)
//			{
//				timespec    st_atim;
//				timespec    st_mtim;
//				timespec    st_ctim;
//				extern(Volt) {
//					@property /*ref */time_t st_atime() { return st_atim.tv_sec; }
//					@property /*ref */time_t st_mtime() { return st_mtim.tv_sec; }
//					@property /*ref */time_t st_ctime() { return st_ctim.tv_sec; }
//				}
//			}
//			else
//			{
				st_atime: time_t;
				st_atimensec: c_ulong;
				st_mtime: time_t;
				st_mtimensec: c_ulong;
				st_ctime: time_t;
				st_ctimensec: c_ulong;
//			}
//			static if (__USE_FILE_OFFSET64)
//			{
//				ino_t       st_ino;
//			}
//			else
//			{
				__unused4: ulong_t;
				__unused5: ulong_t;
//			}
		}

	} else version (X86_64) {

		struct stat_t
		{
			st_dev: dev_t;
			st_ino: ino_t;
			st_nlink: nlink_t;
			st_mode: mode_t;
			st_uid: uid_t;
			st_gid: gid_t;
			__pad0: u32;
			st_rdev: dev_t;
			st_size: off_t;
			st_blksize: blksize_t;
			st_blocks: blkcnt_t;
			//{
				st_atime: time_t;
				st_atimensec: ulong_t;
				st_mtime: time_t;
				st_mtimensec: ulong_t;
				st_ctime: time_t;
				st_ctimensec: ulong_t;
			//}
			__unused: slong_t[3];
		}

	} else version (ARMHF) {

		struct stat_t
		{
			st_dev: dev_t;
			__pad0: u16;
			st_ino: ino_t;
			st_mode: mode_t;
			st_nlink: nlink_t;
			st_uid: uid_t;
			st_gid: gid_t;
			st_rdev: dev_t;
			__pad1: u32;
			st_size: off_t;
			st_blksize: blksize_t;
			st_blocks: blkcnt_t;
			//{
				st_atime: time_t;
				st_atimensec: c_ulong;
				st_mtime: time_t;
				st_mtimensec: c_ulong;
				st_ctime: time_t;
				st_ctimensec: c_ulong;
			//}
			__unused: i32[1];
		}

	} else version (AArch64) {

		struct stat_t
		{
			st_dev: dev_t;
			st_ino: ino_t;
			st_mode: mode_t;
			st_nlink: nlink_t;
			st_uid: uid_t;
			st_gid: gid_t;
			st_rdev: dev_t;
			__pad3: u32;
			st_size: off_t;
			st_blksize: blksize_t;
			st_blocks: blkcnt_t;
			//{
				st_atime: time_t;
				st_atimensec: ulong_t;
				st_mtime: time_t;
				st_mtimensec: ulong_t;
				st_ctime: time_t;
				st_ctimensec: ulong_t;
			//}
			__unused: i32[1];
		}

	} else {

		static assert(false, "unsupported arch");

	}

	enum S_IRUSR    = 0x100; // octal 0400
	enum S_IWUSR    = 0x080; // octal 0200
	enum S_IXUSR    = 0x040; // octal 0100
	enum S_IRWXU    = S_IRUSR | S_IWUSR | S_IXUSR;

	//enum S_IRGRP    = S_IRUSR >> 3;
	enum S_IRGRP    = 0x020;
	//enum S_IWGRP    = S_IWUSR >> 3;
	//enum S_IXGRP    = S_IXUSR >> 3;
	//enum S_IRWXG    = S_IRWXU >> 3;
	enum S_IRWXG    = 0x038;

//	enum S_IROTH    = S_IRGRP >> 3;
//	enum S_IWOTH    = S_IWGRP >> 3;
//	enum S_IXOTH    = S_IXGRP >> 3;
//	enum S_IRWXO    = S_IRWXG >> 3;
	enum S_IRWXO    = 0x7;

	enum S_ISUID    = 0x800; // octal 04000
	enum S_ISGID    = 0x400; // octal 02000
	enum S_ISVTX    = 0x200; // octal 01000

	private {

		extern (Volt) fn S_ISTYPE( mode: mode_t, mask: u32 ) bool
		{
			return ( mode & S_IFMT ) == mask;
		}

	}

	extern (Volt) fn S_ISBLK( mode: mode_t )  bool { return S_ISTYPE( mode, S_IFBLK );  }
	extern (Volt) fn S_ISCHR( mode: mode_t )  bool { return S_ISTYPE( mode, S_IFCHR );  }
	extern (Volt) fn S_ISDIR( mode: mode_t )  bool { return S_ISTYPE( mode, S_IFDIR );  }
	extern (Volt) fn S_ISFIFO( mode: mode_t ) bool { return S_ISTYPE( mode, S_IFIFO );  }
	extern (Volt) fn S_ISREG( mode: mode_t )  bool { return S_ISTYPE( mode, S_IFREG );  }
	extern (Volt) fn S_ISLNK( mode: mode_t )  bool { return S_ISTYPE( mode, S_IFLNK );  }
	extern (Volt) fn S_ISSOCK( mode: mode_t ) bool { return S_ISTYPE( mode, S_IFSOCK ); }

	//static if( true /*__USE_POSIX199309*/ )
	//{
		fn S_TYPEISMQ( buf: stat_t* ) bool  { return false; }
		fn S_TYPEISSEM( buf: stat_t* ) bool { return false; }
		fn S_TYPEISSHM( buf: stat_t* ) bool { return false; }
	//}

} else version (OSX) {

	struct stat_t
	{
		st_dev: dev_t;
		st_ino: ino_t;
		st_mode: mode_t;
		st_nlink: nlink_t;
		st_uid: uid_t;
		st_gid: gid_t;
		st_rdev: dev_t;
	  //static if( false /*!_POSIX_C_SOURCE || _DARWIN_C_SOURCE*/ )
	  //{
		  //timespec  st_atimespec;
		  //timespec  st_mtimespec;
		  //timespec  st_ctimespec;
	  //}
	  //else
	  //{
		st_atime: time_t;
		st_atimensec: c_long;
		st_mtime: time_t;
		st_mtimensec: c_long;
		st_ctime: time_t;
		st_ctimensec: c_long;
	  //}
		st_size: off_t;
		st_blocks: blkcnt_t;
		st_blksize: blksize_t;
		st_flags: u32;
		st_gen: u32;
		st_lspare: i32;
		st_qspare: i64[2];
	}

	enum S_IRUSR    = 0x100; // octal 0400
	enum S_IWUSR    = 0x080; // octal 0200
	enum S_IXUSR    = 0x040; // octal 0100
	enum S_IRWXU    = S_IRUSR | S_IWUSR | S_IXUSR;

	//enum S_IRGRP    = S_IRUSR >> 3;
	enum S_IRGRP    = 0x020;
	//enum S_IWGRP    = S_IWUSR >> 3;
	//enum S_IXGRP    = S_IXUSR >> 3;
	//enum S_IRWXG    = S_IRWXU >> 3;
	enum S_IRWXG    = 0x038;

//	enum S_IROTH    = S_IRGRP >> 3;
//	enum S_IWOTH    = S_IWGRP >> 3;
//	enum S_IXOTH    = S_IXGRP >> 3;
//	enum S_IRWXO    = S_IRWXG >> 3;
	enum S_IRWXO    = 0x7;

	enum S_ISUID    = 0x800; // octal 04000
	enum S_ISGID    = 0x400; // octal 02000
	enum S_ISVTX    = 0x200; // octal 01000

	private {
//		extern (Volt) bool S_ISTYPE( mode_t mode, uint mask )
	//	{
		//	return ( mode & S_IFMT ) == mask;
		//}
	}

//	extern (Volt) bool S_ISBLK( mode_t mode )  { return S_ISTYPE( mode, S_IFBLK );  }
	//extern (Volt) bool S_ISCHR( mode_t mode )  { return S_ISTYPE( mode, S_IFCHR );  }
//	extern (Volt) bool S_ISDIR( mode_t mode )  { return S_ISTYPE( mode, S_IFDIR );  }
	//extern (Volt) bool S_ISFIFO( mode_t mode ) { return S_ISTYPE( mode, S_IFIFO );  }
	//extern (Volt) bool S_ISREG( mode_t mode )  { return S_ISTYPE( mode, S_IFREG );  }
	//extern (Volt) bool S_ISLNK( mode_t mode )  { return S_ISTYPE( mode, S_IFLNK );  }
	//extern (Volt) bool S_ISSOCK( mode_t mode ) { return S_ISTYPE( mode, S_IFSOCK ); }

}

version (Posix) {

	fn chmod(in char*, mode_t) i32;
	fn fchmod(i32, mode_t) i32;
	//int    fstat(int, stat_t*);
	//int    lstat(in char*, stat_t*);
	fn mkdir(in char*, mode_t) i32;
	fn mkfifo(in char*, mode_t) i32;
	//int    stat(in char*, stat_t*);
	fn umask(mode_t) mode_t;
	fn fstat(i32, stat_t*) i32;
	fn lstat(in char*, stat_t*) i32;
	fn stat(in char*, stat_t*) i32;

}

//
// Typed Memory Objects (TYM)
//
/*
S_TYPEISTMO(buf)
*/

//
// XOpen (XSI)
//
/*
S_IFMT
S_IFBLK
S_IFCHR
S_IFIFO
S_IFREG
S_IFDIR
S_IFLNK
S_IFSOCK

int mknod(in 3char*, mode_t, dev_t);
*/

version (Linux) {

	enum S_IFMT     = 0xF000; // octal 0170000
	enum S_IFBLK    = 0x6000; // octal 0060000
	enum S_IFCHR    = 0x2000; // octal 0020000
	enum S_IFIFO    = 0x1000; // octal 0010000
	enum S_IFREG    = 0x8000; // octal 0100000
	enum S_IFDIR    = 0x4000; // octal 0040000
	enum S_IFLNK    = 0xA000; // octal 0120000
	enum S_IFSOCK   = 0xC000; // octal 0140000

	fn mknod(in char*, mode_t, dev_t) i32;

} else version (OSX) {

	enum S_IFMT     = 0xF000; // octal 0170000
	enum S_IFBLK    = 0x6000; // octal 0060000
	enum S_IFCHR    = 0x2000; // octal 0020000
	enum S_IFIFO    = 0x1000; // octal 0010000
	enum S_IFREG    = 0x8000; // octal 0100000
	enum S_IFDIR    = 0x4000; // octal 0040000
	enum S_IFLNK    = 0xA000; // octal 0120000
	enum S_IFSOCK   = 0xC000; // octal 0140000

	fn mknod(in char*, mode_t, dev_t) i32;

}
