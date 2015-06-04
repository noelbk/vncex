var Vnc = (function() {
    var my = {},
    websocket,
    messages = 0;
    
    my.init = function() {
	connect();
	//var w = $("#canvas").width();
	//var h = $("#canvas").height();
    }  

    function connect() {
	websocket = new WebSocket('ws://localhost:8080/vnc');
	websocket.onopen = function(evt) { onOpen(evt) }; 
	websocket.onclose = function(evt) { onClose(evt) }; 
	websocket.onmessage = function(evt) { onMessage(evt) }; 
    };  

    function onMessage(evt) { 
	msg = JSON.parse(evt.data);
	console.log("onMessage: msg=" + msg);
	if ( msg.type == 'tile' ) {
            var img = new Image();
	    //var todo = addTodo();
            img.onload = function() {
		//todo.setReady(function() {
		var canvas = $("#canvas")[0];
		var ctx = canvas.getContext("2d");
                ctx.drawImage(this, msg.x, msg.y);
		//});
            };
            img.src = msg.file;
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
