#ifndef DEBUG_H_INCLUDED
#define DEBUG_H_INCLUDED

#include <errno.h>
#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

inline void
debugf(const char *fmt, ...) __attribute__ ((format (printf, 1, 2)));

inline void
debugf(const char *fmt, ...) {
    va_list vargs;
    va_start(vargs, fmt);
    vfprintf(stderr, fmt, vargs);
    va_end(vargs);
}

#define assertb(cond, msg)				\
    if( !(cond) ) { \
	debugf("assert(%s) failed at %s:%d: ", #cond, __FILE__, __LINE__); \
	debugf msg; \
	debugf("\n");						\
	break; \
    }

#define assertb_syserr(cond, msg)			\
    if( !(cond) ) { \
	debugf("assert(%s) failed at %s:%d: errno=%d (%s): ", #cond, __FILE__, __LINE__, errno, strerror(errno)); \
	debugf msg;							\
	debugf("\n");						\
	break; \
    }

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // DEBUG_H_INCLUDED
