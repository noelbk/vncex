var Vnc = (function() {
    var my = {};
    var websocket;
    var messages = 0;
    var todo_list = [];
    var canvas;
    var ctx;
    var last_msg;

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
	canvas.addEventListener("mousedown", function(e) { return onMouse(e) }, false);
	canvas.addEventListener("mouseup", function(e) { return onMouse(e) }, false);
	canvas.addEventListener("mousemove", function(e) { return onMouse(e) }, false);
	canvas.addEventListener("ondblclick", function(e) { return onMouse(e) }, false);
	canvas.addEventListener("onclick", function(e) { return onMouse(e) }, false);
    };  

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
	send({type: "mouse", event: "down", buttons: e.buttons, x: Math.round(e.clientX - rect.left), y: Math.round(e.clientY - rect.top)});
	return false;
    }

    function onMessage(evt) { 
	if( last_msg ) {
	    if( last_msg.type == 'tile' ) {
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
		var img = new Image();
		img.src = "data:image/png;base64," + b64;
		ctx.drawImage(img, last_msg.x, last_msg.y);
	    }
	    last_msg = null;
	}
	else {
	    var msg = JSON.parse(evt.data);
	    if ( msg.type == 'tile' ) {
		if( !msg.file ) {
		    // (faster) the image data is coming in the next message
		    last_msg = msg;
		}
		else {
		    // (slower) I must fetch the image data in a new request
		    var img = new Image();
		    var todo = addTodo();
		    img.onload = function() {
			var image = this;
			var canvas = $("#canvas")[0];
			var ctx = canvas.getContext("2d");
			ctx.drawImage(image, msg.x, msg.y);
		    };
		    img.src = msg.file;
		}
	    }
	    else if ( msg.type == 'resize' ) {
		ctx.canvas.width = msg.w;
		ctx.canvas.height = msg.h;
	    }
	    else if ( msg.type == 'copyrect' ) {
		var img = ctx.getImageData(msg.sx, msg.sy, msg.w, msg.h);
		ctx.putImageData(img, msg.dx, msg.dy);
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
