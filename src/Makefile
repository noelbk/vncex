o=.o
CFLAGS = -g -Wall

all: vnc_client

vnc_client_objs = vnc_client$o
vnc_client_libs = $(shell pkg-config --libs libvncclient libpng)
vnc_client_cflags = $(shell pkg-config --cflags libvncclient libpng)
vnc_client: $(vnc_client_objs) Makefile debug.h
	$(CC) $(CFLAGS) $(vnc_client_cflags) -o $@ $(vnc_client_objs) $(vnc_client_libs)
