o=.o
CFLAGS = -g -Wall

all: vnc_client

vnc_client_objs = vnc_client$o
vnc_client_libs = $(shell pkg-config --libs libvncclient libpng)
vnc_client_cflags = $(shell pkg-config --cflags libvncclient libpng)
vnc_client: $(vnc_client_objs) Makefile debug.h
	$(CC) $(CFLAGS) $(vnc_client_cflags) -o $@ $(vnc_client_objs) $(vnc_client_libs)

test_progs = test_sscanf
test: $(test_progs)
	for i in $(test_progs); do $$i; done

test_sscanf_objs = test_sscanf$o
test_sscanf: $(test_sscanf_objs) Makefile debug.h
	$(CC) $(CFLAGS) $(test_sscanf_cflags) -o $@ $(test_sscanf_objs) $(test_sscanf_libs)

all_exes = vnc_client $(test_progs)
clean:
	$(RM) *.o
	$(RM) $(all_exes)
