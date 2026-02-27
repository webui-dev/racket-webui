#lang racket/base

; WebUI Racket - Call Racket from JavaScript Example

(require "../../main.rkt")

; JavaScript: my_function_string('Hello', 'World')
(define (my-function-string e)
  (let ([str1 (webui-event-get-string e 0)]
        [str2 (webui-event-get-string e 1)])
    (printf "my-function-string 1: ~a~n" str1)
    (printf "my-function-string 2: ~a~n" str2)
    (flush-output)))

; JavaScript: my_function_integer(123, 456, 789, 12345.6789)
(define (my-function-integer e)
  (let ([n1 (webui-event-get-int   e 0)]
        [n2 (webui-event-get-int   e 1)]
        [n3 (webui-event-get-int   e 2)]
        [f1 (webui-event-get-float e 3)])
    (printf "my-function-integer 1: ~a~n" n1)
    (printf "my-function-integer 2: ~a~n" n2)
    (printf "my-function-integer 3: ~a~n" n3)
    (printf "my-function-integer 4: ~a~n" f1)
    (flush-output)))

; JavaScript: my_function_boolean(true, false)
(define (my-function-boolean e)
  (let ([b1 (webui-event-get-bool e 0)]
        [b2 (webui-event-get-bool e 1)])
    (printf "my-function-boolean 1: ~a~n" (if b1 "True" "False"))
    (printf "my-function-boolean 2: ~a~n" (if b2 "True" "False"))
    (flush-output)))

; JavaScript: my_function_with_response(number, 2).then(...) — return value becomes the Promise result.
(define (my-function-with-response e)
  (let* ([number (webui-event-get-int e 0)]
         [times  (webui-event-get-int e 1)]
         [result (* number times)])
    (printf "my-function-with-response: ~a * ~a = ~a~n" number times result)
    (flush-output)
    result))

(define html #<<HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <script src="webui.js"></script>
    <title>Call Racket from JavaScript</title>
    <style>
      body {
        font-family: 'Arial', sans-serif;
        color: white;
        background: linear-gradient(to right, #507d91, #1c596f, #022737);
        text-align: center;
        font-size: 18px;
      }
      button, input {
        padding: 10px;
        margin: 10px;
        border-radius: 3px;
        border: 1px solid #ccc;
        box-shadow: 0 3px 5px rgba(0,0,0,0.1);
        transition: 0.2s;
      }
      button {
        background: #3498db;
        color: #fff;
        cursor: pointer;
        font-size: 16px;
      }
      h1 { text-shadow: -7px 10px 7px rgb(67 57 57 / 76%); }
      button:hover { background: #c9913d; }
      input:focus { outline: none; border-color: #3498db; }
    </style>
  </head>
  <body>
    <h1>WebUI - Call Racket from JavaScript</h1>
    <p>Call Racket functions with arguments (<em>See the logs in your terminal</em>)</p>

    <button onclick="my_function_string('Hello', 'World');">
      Call my_function_string()
    </button>
    <br>
    <button onclick="my_function_integer(123, 456, 789, 12345.6789);">
      Call my_function_integer()
    </button>
    <br>
    <button onclick="my_function_boolean(true, false);">
      Call my_function_boolean()
    </button>
    <br>
    <p>Call a Racket function that returns a response</p>
    <button onclick="MyJS();">Call my_function_with_response()</button>
    <div>Double: <input type="number" id="MyInputID" value="2"></div>

    <script>
      function MyJS() {
        const input = document.getElementById('MyInputID');
        my_function_with_response(input.value, 2).then((response) => {
          input.value = response;
        });
      }
    </script>
  </body>
</html>
HTML
)

(define win (webui-new-window))

(webui-bind win "my_function_string"        my-function-string)
(webui-bind win "my_function_integer"       my-function-integer)
(webui-bind win "my_function_boolean"       my-function-boolean)
(webui-bind win "my_function_with_response" my-function-with-response)

(webui-show win html)
(webui-wait)
(webui-clean)
