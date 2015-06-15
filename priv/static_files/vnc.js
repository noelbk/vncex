var Vnc = (function() {
    var my = {};
    var websocket;
    var messages = 0;
    var todo_list = [];
    var canvas;
    var pointer;
    var ctx;
    var last_msg;

    var cursor_image;
    var cursor_hot_x;
    var cursor_hot_y;
    
    my.init = function() {
	connect();
    }  

    function connect() {
	websocket = new WebSocket('ws://localhost:8080/vnc');
	websocket.binaryType = "arraybuffer";
	websocket.onopen = function(evt) { onOpen(evt) }; 
	websocket.onclose = function(evt) { onClose(evt) }; 
	websocket.onmessage = function(evt) { onMessage(evt) }; 
	canvas = $("#canvas")[0];
	ctx = canvas.getContext("2d");
	canvas.addEventListener("mousedown", function(e) { return onMouse(e) });
	canvas.addEventListener("mouseup", function(e) { return onMouse(e) });
	canvas.addEventListener("mousemove", function(e) { return onMouse(e) });
	canvas.addEventListener("ondblclick", function(e) { return onMouse(e) });
	canvas.addEventListener("onclick", function(e) { return onMouse(e) });
	pointer = $("#pointer")[0];
    };  

    function getScreenCtx() {
	return ctx;
    }

    function addTodo(readyFunc) {
	todo = {ready: readyFunc};
	todo_list.push(todo);
	return todo;
    }

    function readyTodo(todo, readyFunc) {
	todo.ready = readyFunc;
	runTodo();
    }

    function runTodo() {
	var i;
	for (i=0; i<todo_list.length; i++) {
	    if( !todo_list[i].ready ) {
		break;
	    }
	    todo_list[i].ready();
	}	
	todo_list.splice(0, i);
    }

    function send(data) {
	websocket.send(JSON.stringify(data));
    }

    function onMouse(e) { 
	var rect = canvas.getBoundingClientRect();
	var x = Math.round(e.clientX - rect.left);
	var y = Math.round(e.clientY - rect.top);
	movePointer(x, y);
	send({type: "mouse", event: "down", buttons: e.buttons, x: x, y: y});
	e.returnValue = false;
	return false;
    }

    function loadImage(evt, img) {
	var b64;
	if( evt.data instanceof ArrayBuffer ) {
	    var binary = '';
	    var bytes = new Uint8Array(evt.data);
	    var len = bytes.byteLength;
	    for (var i = 0; i < len; i++) {
		binary += String.fromCharCode(bytes[i]);
	    }
	    b64 = window.btoa(binary);
	}
	else {
	    b64 = evt.data;
	}
	if( !img ) {
	    img = new Image();
	}
	img.src = "data:image/png;base64," + b64;
	return img;
    }

    function movePointer(x, y) {
	pointer.style.left = (x - cursor_hot_x);
	pointer.style.top = (y - cursor_hot_y);
    }

    function onMessage(evt) { 
	var ctx = getScreenCtx();
	if( last_msg ) {
	    if( last_msg.type == 'tile' ) {
		ctx.drawImage(loadImage(evt), last_msg.x, last_msg.y);
	    }
	    else if( last_msg.type == 'cursor_shape' ) {
		loadImage(evt, pointer);
	    }
	    last_msg = null;
	}
	else {
	    var msg = JSON.parse(evt.data);
	    if ( msg.type == 'tile' ) {
		// the image data is coming in the next message
		last_msg = msg;
	    }
	    else if ( msg.type == 'resize' ) {
		ctx.canvas.width = msg.w;
		ctx.canvas.height = msg.h;
	    }
	    else if ( msg.type == 'copyrect' ) {
		var img = ctx.getImageData(msg.sx, msg.sy, msg.w, msg.h);
		ctx.putImageData(img, msg.dx, msg.dy);
	    }
	    else if ( msg.type == 'cursor_shape' ) {
		last_msg = msg;
		cursor_hot_x = msg.x;
		cursor_hot_y = msg.y;
	    }
	    else if ( msg.type == 'cursor_pos' ) {
		movePointer(msg.x, msg.y);
	    }
	    else if ( msg.type == 'cursor_lock' ) {
		// cursor_lock_x = msg.x;
		// cursor_lock_y = msg.y;
		// cursor_lock_img = ctx.getImageData(msg.x, msg.y, msg.w, msg.h);
	    }
	    else if ( msg.type == 'cursor_unlock' ) {
		// ctx.putImageData(cursor_lock_img, cursor_lock_x, cursor_lock_y);
	    }
	}
    };  

    function disconnect() {
	websocket.close();
    }; 

    function onOpen(evt) { 
	updateStatus('<span style="color: green;">CONNECTED </span>'); 
    };  

    function onClose(evt) { 
	updateStatus('<span style="color: red;">DISCONNECTED </span>');
    };  

    function updateStatus(txt) { 
	$('#status').html(txt);
    };

    return my;
}());
