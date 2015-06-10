#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <poll.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <png.h>
#include <rfb/rfbclient.h>
#include <rfb/rfbproto.h>

#include "debug.h"

#define CLIENT_DATA_KEY "CLIENT_DATA"

#ifndef MAX_PATH
#define MAX_PATH 8192
#endif // MAX_PATH

#define OUT_MAX_SIZE 100000000 

typedef struct client_data_s {
    char *out_prefix;
    FILE *out_fp;
    char out_path[MAX_PATH];
    int out_index;
    int out_max_size;
} client_data_t;

void
client_data_init(client_data_t *client_data) {
    memset(client_data, 0, sizeof(*client_data));
    client_data->out_max_size = OUT_MAX_SIZE;
}

void
client_data_free(client_data_t *client_data) {
    if( client_data->out_fp ) {
	fclose(client_data->out_fp);
	client_data->out_fp = 0;
    }
}

int
client_data_open(client_data_t *client_data) {
    int err=0;
    int fd=-1;

    do {
	if( client_data->out_fp ) {
	    if( ftell(client_data->out_fp) < client_data->out_max_size ) {
		err = 0;
		break;
	    }
	    fclose(client_data->out_fp);
	    client_data->out_fp = 0;
	}
	
	while(1) {
	    client_data->out_index++;
	    snprintf(client_data->out_path, sizeof(client_data->out_path), "%s%04d.png", client_data->out_prefix, client_data->out_index);
	    fd = open(client_data->out_path, O_RDWR|O_CREAT|O_EXCL, 0644);
	    if( fd < 0 ) {
		assertb_syserr(errno == EEXIST, ("Couldn't create writable file at %s", client_data->out_path));
		continue;
	    }
	    client_data->out_fp = fdopen(fd, "w+b");
	    assertb_syserr(client_data->out_fp, ("fdopen"));
	    fd = -1;
	    err = 0;
	    break;
	}
    } while(0);
    if( fd >= 0 ) {
	close(fd);
    }
    return err;
}


int
write_png(FILE *fp, png_bytep fb, int x, int y, int w, int h, int stride, int bpp) {
    png_structp png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop info_ptr = png_create_info_struct(png_ptr);
    png_bytep rowp=0;
    int err = 0;
    int yi;

    do {
	png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
	assertb(png_ptr, ("png_create_write_struct"));
	if (setjmp(png_jmpbuf(png_ptr))) {
	    assertb(0, ("png_jmpbuf"));
	}
	info_ptr = png_create_info_struct(png_ptr);
	assertb(info_ptr, ("png_create_info_struct"));
	png_init_io(png_ptr, fp);
	png_set_IHDR(png_ptr, info_ptr, w, h,
		     8, PNG_COLOR_TYPE_RGB_ALPHA, PNG_INTERLACE_NONE,
		     PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
	png_set_invert_alpha(png_ptr);
	png_set_strip_alpha(png_ptr);
	png_write_info(png_ptr, info_ptr);
	rowp = fb + y * stride + x * bpp;
	for(yi=0; yi<h; yi++) {
	    png_write_row(png_ptr, rowp);
	    rowp += stride;
	}
	png_write_end(png_ptr, NULL);
	err = 0;
    } while(0);
    if (info_ptr != NULL) png_free_data(png_ptr, info_ptr, PNG_FREE_ALL, -1);
    if (png_ptr != NULL) png_destroy_write_struct(&png_ptr, (png_infopp)NULL);
    return err;
}

void
vnc_update(rfbClient* client, int x, int y, int w, int h) {
    off_t off, end;
    int bpp, stride;
    client_data_t* client_data = rfbClientGetClientData(client, CLIENT_DATA_KEY);
    int ret;

    do {
	ret = client_data_open(client_data);
	assertb(!ret, ("client_data_open"));
	off = ftell(client_data->out_fp);
	assertb_syserr(off>=0, ("ftell"));
	bpp = client->format.bitsPerPixel/8;
	stride = bpp * client->width;
	ret = write_png(client_data->out_fp, client->frameBuffer, x, y, w, h, stride, bpp);
	assertb_syserr(!ret, ("write_png"));
	fflush(client_data->out_fp);
	end = ftell(client_data->out_fp);
	assertb_syserr(end>off, ("end=ftell"));
	printf("tile %d %d %d %d %s %lu %lu\n", x, y, w, h, client_data->out_path, off, end-off);
    } while(0);
}

void
vnc_copyrect(rfbClient* client, int sx, int sy, int w, int h, int dx, int dy) {
    printf("copyrect %d %d %d %d %d %d\n", sx, sy, w, h, dx, dy);
}

char*
vnc_get_password(rfbClient* client) {
    char buf[8192], *p;
    int ret;

    // debug
    return strdup("123456");

    do {
	printf("password?\n");
	p = fgets(buf, sizeof(buf), stdin);
	assertb_syserr(p, ("failed to read password"));
	ret = strlen(buf)-1;
	assertb(buf[ret] == '\n', ("read incomplete password. max chars %lu buf=%s", sizeof(buf), buf));
	buf[ret] = 0;
	return strdup(buf);
    } while(0);
    return 0;
}

rfbBool
vnc_resize(rfbClient* rfb_client) {
    int w = rfb_client->width;
    int h = rfb_client->height;
    int depth = rfb_client->format.bitsPerPixel;
    int ret, err = -1;
    do {
	//rfb_client->updateRect.x = 0;
	//rfb_client->updateRect.y = 0;
	//rfb_client->updateRect.w = w;
	//rfb_client->updateRect.h = h;
	rfb_client->format.bitsPerPixel = depth;
	rfb_client->format.redShift = 0;
	rfb_client->format.greenShift = 8;
	rfb_client->format.blueShift = 16;
	rfb_client->format.redMax = 0xff;
	rfb_client->format.greenMax = 0xff;
	rfb_client->format.blueMax = 0xff;
	if( rfb_client->frameBuffer ) {
	    free(rfb_client->frameBuffer);
	    rfb_client->frameBuffer = 0;
	}
	rfb_client->frameBuffer = (unsigned char*)malloc(w * h * depth/8);
	assertb_syserr(rfb_client->frameBuffer, ("malloc"));
	ret = SetFormatAndEncodings(rfb_client);
	assertb(ret, ("SetFormatAndEncodings"));
	printf("resize %d %d\n", w, h);
	printf("keyframe\n");
	ret = SendFramebufferUpdateRequest(rfb_client, 0, 0, rfb_client->width, rfb_client->height, 0);
	assertb(ret, ("SendFramebufferUpdateRequest"));
	err = 0;
    } while(0);
    return !err;
}

int
handle_input(rfbClient* rfb_client) {
    char buf[8192], *p;
    int ret, err=-1;
    do {
	p = fgets(buf, sizeof(buf), stdin);
	if( p == 0 ) {
	    break;
	}
	ret = strlen(buf)-1;
	assertb(buf[ret] == '\n', ("read incomplete line: maxlen=%lu buf=%s", sizeof(buf), buf));
	buf[ret] = 0;
	// TODO: process buf
	printf("read: %s", buf);
	err = 0;
    } while(0);
    return err;
}

int
main(int argc, char **argv) {
    client_data_t client_data;
    rfbClient* rfb_client=0;
    char *p;
    int ret, err=-1;
    char *host;
    int port;

    setbuf(stdout, NULL);
    client_data_init(&client_data);
    do {
	if( argc != 4 ) {
	    fprintf(stderr, "usage: vnc_client out_prefix host port\n");
	    exit(1);
	}
	client_data.out_prefix = argv[1];
	host = argv[2];
	port = strtoul(argv[3], &p, 0);
	assertb(p>argv[3], ("Invalid port: %s", argv[3]));

	rfb_client = rfbGetClient(8, 3, 4); /* 32-bpp client */
	rfbClientSetClientData(rfb_client, CLIENT_DATA_KEY, &client_data);
	rfb_client->serverHost = host;
	rfb_client->serverPort = port;
	rfb_client->MallocFrameBuffer = vnc_resize;
	rfb_client->canHandleNewFBSize = 1;
	rfb_client->GotFrameBufferUpdate = vnc_update;
	rfb_client->GotCopyRect = vnc_copyrect;
	rfb_client->GetPassword = vnc_get_password;

	/* Connect */
	ret = rfbInitClient(rfb_client, NULL, NULL);
	assertb(ret, ("rfbInitClient"));

	/* input loop */
	assertb(rfb_client->sock >= 0, ("rfb_client->sock"));
	while(1) {
	    struct pollfd pollfds[2];
	    pollfds[0].fd = 0;
	    pollfds[0].events = POLLIN;
	    pollfds[1].fd = rfb_client->sock;
	    pollfds[1].events = POLLIN;
	    ret = poll(pollfds, 2, -1);
	    assertb_syserr(ret >= 0, ("poll"));
		
	    if( pollfds[0].revents ) {
		assertb_syserr(pollfds[0].revents==POLLIN, ("poll error on stdin"));
		ret = handle_input(rfb_client);
		assertb(!ret, ("handle_input"));
	    }

	    if( pollfds[1].revents ) {
		assertb_syserr(pollfds[1].revents==POLLIN, ("poll error on RFB sock=%d revents=%d != POLLIN=%d", rfb_client->sock, pollfds[1].revents, POLLIN));
		if( WaitForMessage(rfb_client, 0) ) {
		    ret = HandleRFBServerMessage(rfb_client);
		    assertb(ret, ("HandleRFBServerMessage"));
		}
	    }
	}
    } while(0);

    if( rfb_client ) {
	rfbClientCleanup(rfb_client);
    }
    client_data_free(&client_data);

    return !err;
}
