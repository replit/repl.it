#!/usr/bin/env node

var fs = require('fs'),
    http = require('http'),
    path = require('path'),
    url = require('url'),
    spawn = require('child_process').spawn,
    queryString = require('querystring'),
    port = process.argv[2] || 8888;

var CONTENT_TYPES = {
  'js': 'application/javascript; charset=utf-8',
  'css': 'text/css; charset=utf-8',
  'json': 'application/json; charset=utf-8',
  'html': 'text/html; charset=utf-8',
  'htm': 'text/html; charset=utf-8',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'ico': 'image/x-icon',
  'gif': 'image/gif',
  'txt': 'text/plain; charset=utf-8'
};

function textResponse(res, code, txt) {
  txt = txt || '';
  res.writeHead(code, {"Content-Type": "text/plain"});
  res.end(txt);
}

var waiting = {};

var httpCb = function (req, res) {
  var uri = url.parse(req.url).pathname,
      filename = path.join(process.cwd(), uri);
      
  var m;
  if (m = uri.match(/(?:\/jsrepl)?\/emscripten\/input\/(\d+)/)) {
    if (req.method === 'GET') {
      waiting[m[1]] = {
        req: req,
        res: res
      };
      req.on('close', function () {
        delete waiting[m[1]];
      });
    } else  {
      var body = [];
      req.on('data', function (data) {
        body.push(data);
      });
      req.on('end', function () {
        var d = queryString.parse(body.join('')),
            waiterRes = waiting[m[1]] && waiting[m[1]].res;

        if (waiterRes) {
          waiterRes.writeHead(200, {'Content-Type': 'text/plain'});
          waiterRes.end(d.input);
          res.writeHead(200, {'Content-Type': 'text/plain'});
          delete waiting[m[1]];
          res.end('success');
        } else {
          res.writeHead(200, {'Content-Type': 'text/plain'});
          res.end('fail');
        }
      });
    }
    return;
  }

  // HACK: Mobile browsers get special treatment!
  if (req.headers['user-agent'] &&
      req.headers['user-agent'].match(/iPhone|iPad|iPod|Android/i)) {
    if (uri === '/css/style.css') {
      // Automatically switch styles.
      uri = '/css/mobile.css';
    } else if (uri.indexOf('/lib/ace/') === 0) {
      // Ace has no content for mobile.
      textResponse(res, 204);
      return;
    }
  }
  // END HACK
  
  path.exists(filename, function (exists) {
    if (!exists) {
      textResponse(res, 404, "Page Not Found!\n");
      return;
    }
    
    if (fs.statSync(filename).isDirectory()) filename += '/index.html';
    
    fs.readFile(filename, 'binary', function (err, file) {
      if (err) {
        textResponse(res, 500, err + '\n');
        return;
      }
      var ext = path.extname(filename).slice(1);
      res.writeHead(200, {'Content-Type': CONTENT_TYPES[ext] || 'text/plain'});
      res.write(file, 'binary');
      res.end();
    });
  }); 
};

var watcher = spawn('cake', ['watch']);
watcher.stdout.pipe(process.stdout);
watcher.stderr.pipe(process.stderr);

var server_started = false,
    start_timer;
watcher.stdout.on('data', function () {
  if (server_started) return;
  clearTimeout(start_timer);
  start_timer = setTimeout(function () {
    http.createServer(httpCb).listen(port, '0.0.0.0');
    console.log('repl.it server started at http://localhost:' + port + '/');
    server_started = true;
  }, 3000);
});

