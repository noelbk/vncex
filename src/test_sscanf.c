#include <stdio.h>

#include "debug.h"

#define BUFSIZE 4096
#define SSCANF_BUFSIZE "%4095s"

int
main(int argc, char **argv) {
    int ret, n, err=-1;
    char *buf = "mouse 461 5.828125 0 down";
    char *p = buf;
    char msg_type[BUFSIZE];

    do {
	ret = sscanf(p, SSCANF_BUFSIZE "%n", msg_type, &n);
	assertb(ret==1 && n>0, ("sscanf(%s) for msg_type ret=%d n=%d msg_type=%s fmt=[%s]", p, ret, n, msg_type, SSCANF_BUFSIZE "%n"));
	err = 0;
    } while(0);
    return err;
}
