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

#define BUFSIZE 4096
#define SSCANF_BUFSIZE "%4095s"

#define OUT_MAX_SIZE 100000000 
#define KEYFRAME_MAX 5000000

typedef struct client_data_s {
    char *out_prefix;
    FILE *out_fp;
    char out_path[MAX_PATH];
    int out_index;
    int out_max_size;
    off_t keyframe_last;
    off_t keyframe_max;
} client_data_t;

void
client_data_init(client_data_t *client_data) {
    memset(client_data, 0, sizeof(*client_data));
    client_data->out_max_size = OUT_MAX_SIZE;
    client_data->keyframe_max = KEYFRAME_MAX;
    client_data->keyframe_last = -1;
}

void
client_data_free(client_data_t *client_data) {
    if( client_data->out_fp ) {
	fclose(client_data->out_fp);
	client_data->out_fp = 0;
    }
}

int
client_data_open(rfbClient* rfb_client) {
    int ret, err=0;
    int fd=-1;
    off_t pos=0;
    client_data_t *client_data = rfbClientGetClientData(rfb_client, CLIENT_DATA_KEY);
    
    do {
	if( client_data->out_fp ) {
	    pos = ftell(client_data->out_fp);

	    /* add a keyframe every few bytes */
	    if( client_data->keyframe_last == -1 || pos - client_data->keyframe_last > client_data->keyframe_max ) {
		ret = SendFramebufferUpdateRequest(rfb_client, 0, 0, rfb_client->width, rfb_client->height, 0);
		assertb(ret, ("SendFramebufferUpdateRequest"));
		printf("keyframe\n");
		client_data->keyframe_last = pos;
	    }

	    if( pos < client_data->out_max_size ) {
		err = 0;
		break;
	    }
	    fclose(client_data->out_fp);
	    client_data->out_fp = 0;
	    pos = 0;
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

# define WRITE_PNG_ALPHA 0x1

int
write_png(FILE *fp, png_bytep fb, int x, int y, int w, int h, int stride, int bpp, int flags) {
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
	if( !(flags & WRITE_PNG_ALPHA) ) {
	    png_set_invert_alpha(png_ptr);
	    png_set_strip_alpha(png_ptr);
	}
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

int
save_png(rfbClient* rfb_client, char **file, off_t *off, off_t *len, uint8_t *buf, 
	 int x, int y, int w, int h, int stride, int bpp, int flags) {
    int ret, err = -1;
    client_data_t *client_data = rfbClientGetClientData(rfb_client, CLIENT_DATA_KEY);

    do {
	ret = client_data_open(rfb_client);
	assertb(!ret && client_data->out_fp, ("client_data_open"));
	*file = client_data->out_path;
	*off = ftell(client_data->out_fp);
	ret = write_png(client_data->out_fp, buf, x, y, w, h, stride, bpp, flags);
	assertb_syserr(off>=0, ("ftell"));
	fflush(client_data->out_fp);
	*len = ftell(client_data->out_fp);
	assertb_syserr(*len>*off, ("end=ftell"));
	*len -= *off;
	err = 0;
    } while(0);
    return err;
}


void
vnc_update(rfbClient* rfb_client, int x, int y, int w, int h) {
    char *file;
    off_t off, len;
    int ret;
    int bpp, stride;

    do {
	bpp = rfb_client->format.bitsPerPixel/8;
	stride = bpp * rfb_client->width;
	ret = save_png(rfb_client, &file, &off, &len, rfb_client->frameBuffer, x, y, w, h, stride, bpp, 0);
	assertb_syserr(!ret, ("save_png"));
	printf("tile %d %d %d %d %s %lu %lu\n", x, y, w, h, file, off, len);
    } while(0);
}

void
vnc_copyrect(rfbClient* client, int sx, int sy, int w, int h, int dx, int dy) {
    printf("copyrect %d %d %d %d %d %d\n", sx, sy, w, h, dx, dy);
}

char*
vnc_get_password(rfbClient* client) {
    char buf[BUFSIZE], *p;
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
	rfb_client->appData.useRemoteCursor = TRUE;
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

void
vnc_cursor_shape(rfbClient* rfb_client, int x, int y, int w, int h, int bytesPerPixel) {
    int i, ret;
    char *file;
    off_t off, len;
    uint8_t *src, *mask;
    do {
	assertb(bytesPerPixel==4, ("unexpected bytesPerPixel=%d", bytesPerPixel));
	assertb(rfb_client->rcSource, ("client->rcSource"));
	assertb(rfb_client->rcMask, ("client->rcMask"));
	src = rfb_client->rcSource;
	mask = rfb_client->rcMask;
	for(i=0; i<w*h; i++) {
	    src[3] = mask[0] ? 0xff : 0x00;
	    src += bytesPerPixel;
	    mask += 1;
	}
	ret = save_png(rfb_client, &file, &off, &len, rfb_client->rcSource, 0, 0, w, h, w*bytesPerPixel, bytesPerPixel, WRITE_PNG_ALPHA);
	assertb_syserr(!ret, ("save_png"));
	printf("cursor_shape %d %d %d %d %s %lu %lu\n", x, y, w, h, file, off, len);
   } while(0);
}

rfbBool
vnc_cursor_pos(rfbClient* rfb_client, int x, int y) {
    printf("cursor_pos %d %d\n", x, y);
    return TRUE;
}

void
vnc_cursor_lock(rfbClient* rfb_client, int x, int y, int w, int h) {
    printf("cursor_lock %d %d %d %d\n", x, y, w, h);
}

void
vnc_cursor_unlock(rfbClient* rfb_client) {
    printf("cursor_unlock\n");
}

int
handle_input(rfbClient* rfb_client) {
    char buf[BUFSIZE], *p;
    int ret, n, err=-1;
    char msg_type[BUFSIZE], event[BUFSIZE];
    int x, y, buttons;

    do {
	p = fgets(buf, sizeof(buf), stdin);
	if( p == 0 ) {
	    break;
	}
	ret = strlen(buf)-1;
	assertb(buf[ret] == '\n', ("read incomplete line: maxlen=%lu buf=%s", sizeof(buf), buf));
	buf[ret] = 0;
	p = buf;
	ret = sscanf(p, SSCANF_BUFSIZE "%n", msg_type, &n);
	assertb(ret>=1 && n>0, ("sscanf(%s) for msg_type ret=%d n=%d", p, ret, n));
	p += n;

	if( strcmp(msg_type, "mouse") == 0 ) {
	    ret = sscanf(p, "%d %d %d " SSCANF_BUFSIZE "%n", &x, &y, &buttons, event, &n);
	    assertb(ret==4, ("sscanf(%s) for mouse ret=%d x=%d y=%d buttons=%d event=%s n=%d", p, ret, x, y, buttons, event, n));
	    ret = SendPointerEvent(rfb_client, x, y, buttons);
	    assertb(ret, ("SendPointerEvent(%d, %d, %d)", x, y, buttons));
	}
	else {
	    assertb(0, ("couldn't parse message: msg_type=%s params=%s", msg_type, p));
	}
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
	    fprintf(stderr, "usage: vnc_client host port out_prefix\n");
	    exit(1);
	}
	host = argv[1];
	port = strtoul(argv[2], &p, 0);
	assertb(p>argv[2], ("Invalid port: %s", argv[3]));
	client_data.out_prefix = argv[3];

	rfb_client = rfbGetClient(8, 3, 4); /* 32-bpp client */
	rfbClientSetClientData(rfb_client, CLIENT_DATA_KEY, &client_data);
	rfb_client->serverHost = host;
	rfb_client->serverPort = port;
	rfb_client->MallocFrameBuffer = vnc_resize;
	rfb_client->canHandleNewFBSize = 1;
	rfb_client->GotFrameBufferUpdate = vnc_update;
	rfb_client->GotCopyRect = vnc_copyrect;
	rfb_client->GetPassword = vnc_get_password;

	rfb_client->appData.useRemoteCursor = TRUE;
	rfb_client->GotCursorShape = vnc_cursor_shape;
	rfb_client->HandleCursorPos = vnc_cursor_pos;
	//rfb_client->SoftCursorLockArea = vnc_cursor_lock;
	//rfb_client->SoftCursorUnlockScreen = vnc_cursor_unlock;

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
