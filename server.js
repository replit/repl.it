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

function genRandomString() {
  return Math.random().toString(36).replace(/[^a-z]+/g, '').substring(0,5);
}

function restoreFakeSession(pieceName, res) {
  fs.readFile('index.html', String, function (err, file) {
    if (err) {
      textResponse(res, 500, err + '\n');
      return;
    }

    var savedData = inMemorySaved[pieceName]
    var sessionReturnData = {session_id: pieceName,
                             revision_id: "1",
                             eval_history: JSON.parse(savedData.eval_history),
                             editor_text: savedData.editor_text,
                             language: savedData.language,
                             console_dump: savedData.console_dump };

    file = String(file).replace('SESSION_PLACEHOLDER', 'REPLIT_DATA='+JSON.stringify(sessionReturnData));

    res.writeHead(200, {'Content-Type': CONTENT_TYPES['html'], 'max-age': '0'});
    res.write(file);

    res.end();
  });
}


var waiting = {};
var inMemorySaved = {};

var httpCb = function (req, res) {
  var uri = url.parse(req.url).pathname;
  var uriFirstPiece = uri.split('/')[1]
  if (uriFirstPiece in {
      languages: 1
    , help: 1
    , about: 1
    , examples: 1
    , workspace: 1
    }) { uri = '/index.html'; }

  if(inMemorySaved[uriFirstPiece]) {
    restoreFakeSession(uriFirstPiece, res);
    return;
  }
  var filename = path.join(process.cwd(), uri);;
      
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

  if(m = uri.match(/save/)) {
    var thisRandom = genRandomString();
    var dataParts = [];
    req.on('data', function(data){
      dataParts.push(data);
    });
    req.on('end', function(){
      inMemorySaved[thisRandom] = queryString.parse(dataParts.join(''));
      res.writeHead(200, {'Content-Type': CONTENT_TYPES.json, 'max-age': '0'});
      var responseString = JSON.stringify({ session_id: String(thisRandom),
                                            // not attempting to support multiple revisions
                                            revision_id: '1'
                                          });
      res.end(responseString);
    });
    return;
  };

  fs.exists(filename, function (exists) {
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
      res.writeHead(200, {'Content-Type': CONTENT_TYPES[ext] || 'text/plain', 'max-age': '0'});
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

