var Vnc = (function() {
    var my = {};
    var websocket;
    var messages = 0;
    var todo_list = [];

    my.init = function() {
	connect();
    }  

    function connect() {
	websocket = new WebSocket('ws://localhost:8080/vnc');
	websocket.onopen = function(evt) { onOpen(evt) }; 
	websocket.onclose = function(evt) { onClose(evt) }; 
	websocket.onmessage = function(evt) { onMessage(evt) }; 
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

    function onMessage(evt) { 
	var msg = JSON.parse(evt.data);
	if ( msg.type == 'tile' ) {
            var img = new Image();
	    var todo = addTodo();
            img.onload = function() {
		var image = this;
		readyTodo(todo, function() {
		    var canvas = $("#canvas")[0];
		    var ctx = canvas.getContext("2d");
                    ctx.drawImage(image, msg.x, msg.y);
		});
            };
            img.src = msg.file;
	}
	else if ( msg.type == 'resize' ) {
	    addTodo(function() {
		var canvas = $("#canvas")[0];
		var ctx = canvas.getContext("2d");
		ctx.canvas.width = msg.w;
		ctx.canvas.height = msg.h;
	    });
	}
	else if ( msg.type == 'copyrect' ) {
	    addTodo(function() {
		var canvas = $("#canvas")[0];
		var ctx = canvas.getContext("2d");
		var img = ctx.getImageData(msg.sx, msg.sy, msg.w, msg.h);
		ctx.putImageData(img, msg.dx, msg.dy);
	    });
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
