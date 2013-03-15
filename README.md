repl.it
=======

An online environment for interactively exploring programming languages, based
on [jsREPL](https://github.com/replit/jsrepl).

Current Languages
-----------------

* JavaScript Variants
  * JavaScript
  * CoffeeScript
  * Kaffeine
  * Move
  * JavaScript.next

* Esoteric
  * Bloop
  * Brainfuck
  * LOLCODE
  * Unlambda
  * Emoticon

* Classic
  * Quick Basic
  * Forth

* Serious
  * Scheme
  * Lua
  * Python
  * Ruby (beta)

Getting the Code
----------------

    git clone git://github.com/replit/repl.it.git
    cd repl.it
    git submodule update --init --recursive

Dependencies
------------

#### [node.js](http://nodejs.org/)  

#### [npm](http://npmjs.org/)

    curl https://npmjs.org/install.sh | sh
   
#### [CoffeeScript](http://jashkenas.github.com/coffee-script/)
  
  Using npm:
  
    npm install -g coffee-script

#### [Pygments](http://pygments.org/)

  Using easy_install:
  
    easy_install Pygments
    
  Using pip:
  
    pip install Pygments

Running repl.it
---------------

repl.it comes bundled with a static node HTTP file server and a CoffeeScript file watcher & (re)-compiler:

    ./server.js 8888
    
repl.it can then be opened at http://localhost:8888/index.html.

Documentation
-------------

There is some documentation on the [wiki page](https://github.com/replit/repl.it/wiki)
and we will be adding some more soon.  
Until then if you need any help try going to the #repl.it IRC channel at
irc.freenode.net or messaging [@max99x](https://github.com/max99x) or
[@amasad](https://github.com/amasad).


License
-------

repl.it is available under the MIT license. External libraries used in repl.it
may use other licenses. Please check each library for its specific license.
