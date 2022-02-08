PHP_ARG_ENABLE([opcache],
  [whether to enable Zend OPcache support],
  [AS_HELP_STRING([--disable-opcache],
    [Disable Zend OPcache support])],
  [yes])

PHP_ARG_ENABLE([huge-code-pages],
  [whether to enable copying PHP CODE pages into HUGE PAGES],
  [AS_HELP_STRING([--disable-huge-code-pages],
    [Disable copying PHP CODE pages into HUGE PAGES])],
  [yes],
  [no])

PHP_ARG_ENABLE([opcache-jit],
  [whether to enable JIT],
  [AS_HELP_STRING([--disable-opcache-jit],
    [Disable JIT])],
  [yes],
  [no])

if test "$PHP_OPCACHE" != "no"; then

  dnl Always build as shared extension
  ext_shared=yes

  if test "$PHP_HUGE_CODE_PAGES" = "yes"; then
    AC_DEFINE(HAVE_HUGE_CODE_PAGES, 1, [Define to enable copying PHP CODE pages into HUGE PAGES (experimental)])
  fi

  if test "$PHP_OPCACHE_JIT" = "yes"; then
    case $host_cpu in
      i[[34567]]86*|x86*|aarch64)
        ;;
      *)
        AC_MSG_WARN([JIT not supported by host architecture])
        PHP_OPCACHE_JIT=no
        ;;
    esac
  fi

  if test "$PHP_OPCACHE_JIT" = "yes"; then
    AC_DEFINE(HAVE_JIT, 1, [Define to enable JIT])
    ZEND_JIT_SRC="jit/zend_jit.c jit/zend_jit_gdb.c jit/zend_jit_vm_helpers.c"

    dnl Find out which ABI we are using.
    case $host_alias in
      x86_64-*-darwin*)
        DASM_FLAGS="-D X64APPLE=1 -D X64=1"
        DASM_ARCH="x86"
        ;;
      x86_64*)
        DASM_FLAGS="-D X64=1"
        DASM_ARCH="x86"
        ;;
      i[[34567]]86*)
        DASM_ARCH="x86"
        ;;
      x86*)
        DASM_ARCH="x86"
        ;;
      aarch64*)
        DASM_FLAGS="-D ARM64=1"
        DASM_ARCH="arm64"
        ;;
    esac

    if test "$PHP_THREAD_SAFETY" = "yes"; then
      DASM_FLAGS="$DASM_FLAGS -D ZTS=1"
    fi

    PKG_CHECK_MODULES([CAPSTONE], [capstone >= 3.0.0],
        [have_capstone="yes"], [have_capstone="no"])
    if test "$have_capstone" = "yes"; then
        AC_DEFINE(HAVE_CAPSTONE, 1, [ ])
        PHP_EVAL_LIBLINE($CAPSTONE_LIBS, OPCACHE_SHARED_LIBADD)
        PHP_EVAL_INCLINE($CAPSTONE_CFLAGS)
    fi

    PHP_SUBST(DASM_FLAGS)
    PHP_SUBST(DASM_ARCH)

    AC_MSG_CHECKING(for opagent in default path)
    for i in /usr/local /usr; do
      if test -r $i/include/opagent.h; then
        OPAGENT_DIR=$i
        AC_MSG_RESULT(found in $i)
        break
      fi
    done
    if test -z "$OPAGENT_DIR"; then
      AC_MSG_RESULT(not found)
    else
      PHP_CHECK_LIBRARY(opagent, op_write_native_code,
      [
        AC_DEFINE(HAVE_OPROFILE,1,[ ])
        PHP_ADD_INCLUDE($OPAGENT_DIR/include)
        PHP_ADD_LIBRARY_WITH_PATH(opagent, $OPAGENT_DIR/$PHP_LIBDIR/oprofile, OPCACHE_SHARED_LIBADD)
        PHP_SUBST(OPCACHE_SHARED_LIBADD)
      ],[
        AC_MSG_RESULT(not found)
      ],[
        -L$OPAGENT_DIR/$PHP_LIBDIR/oprofile
      ])
    fi

  fi

  AC_CHECK_FUNCS([mprotect])

  AC_CHECK_FUNC(shmget,[
    AC_DEFINE(HAVE_SHM_IPC, 1, [Define if you have SysV IPC SHM support])
  ])
  AC_CHECK_FUNC(mmap,[
    AC_DEFINE(HAVE_SHM_MMAP_ANON, 1, [Define if you have mmap(MAP_ANON) SHM support])
  ])

  AC_CHECK_FUNC(mmap,[
    AC_DEFINE(HAVE_SHM_MMAP_POSIX, 1, [Define if you have POSIX mmap() SHM support])
  ])

  PHP_NEW_EXTENSION(opcache,
	ZendAccelerator.c \
	zend_accelerator_blacklist.c \
	zend_accelerator_debug.c \
	zend_accelerator_hash.c \
	zend_accelerator_module.c \
	zend_persist.c \
	zend_persist_calc.c \
	zend_file_cache.c \
	zend_shared_alloc.c \
	zend_accelerator_util_funcs.c \
	shared_alloc_shm.c \
	shared_alloc_mmap.c \
	shared_alloc_posix.c \
	$ZEND_JIT_SRC,
	shared,,"-Wno-implicit-fallthrough -DZEND_ENABLE_STATIC_TSRMLS_CACHE=1",,yes)

  PHP_ADD_EXTENSION_DEP(opcache, pcre)

#  if test "$have_shm_ipc" != "yes" && test "$have_shm_mmap_posix" != "yes" && test "$have_shm_mmap_anon" != "yes"; then
#    AC_MSG_ERROR([No supported shared memory caching support was found when configuring opcache. Check config.log for any errors or missing dependencies.])
# fi

  if test "$PHP_OPCACHE_JIT" = "yes"; then
    PHP_ADD_BUILD_DIR([$ext_builddir/jit], 1)
    PHP_ADD_MAKEFILE_FRAGMENT($ext_srcdir/jit/Makefile.frag)
  fi
  PHP_SUBST(OPCACHE_SHARED_LIBADD)
fi
