#lang racket/base

; WebUI Racket - Call JavaScript from Racket Example

(require "../../main.rkt")

(define count 0)

(define (my-function-count e)
  (set! count (+ count 1))
  (webui-run (webui-event-window e) (format "SetCount(~a);" count)))

(define (my-function-exit e)
  (webui-exit))

(define html #<<HTML
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <script src="webui.js"></script>
    <title>Call JavaScript from Racket</title>
    <style>
      body {
        font-family: 'Arial', sans-serif;
        color: white;
        background: linear-gradient(to right, #507d91, #1c596f, #022737);
        text-align: center;
        font-size: 18px;
      }
      button {
        padding: 10px;
        margin: 10px;
        border-radius: 3px;
        border: 1px solid #ccc;
        box-shadow: 0 3px 5px rgba(0,0,0,0.1);
        transition: 0.2s;
        background: #3498db;
        color: #fff;
        cursor: pointer;
        font-size: 16px;
      }
      h1 { text-shadow: -7px 10px 7px rgb(67 57 57 / 76%); }
      button:hover { background: #c9913d; }
      button:disabled {
        opacity: 0.6;
        cursor: not-allowed;
        box-shadow: none;
        filter: grayscale(30%);
      }
      button:disabled:hover { background: #3498db; }
    </style>
  </head>
  <body>
    <h1>WebUI - Call JavaScript from Racket</h1>
    <br>
    <h1 id="count">0</h1>
    <br>
    <button id="ManualBtn" onclick="my_function_count();">Manual Count</button>
    <br>
    <button id="AutoBtn" onclick="AutoTest();">Auto Count (Every 10ms)</button>
    <br>
    <button id="ExitBtn" onclick="this.disabled=true; my_function_exit();">Exit</button>

    <script>
      let count = 0;
      let auto_running = false;

      function SetCount(number) {
        document.getElementById('count').innerHTML = number;
        count = number;
      }

      function AutoTest() {
        if (auto_running) return;
        auto_running = true;
        document.getElementById('AutoBtn').disabled = true;
        document.getElementById('ManualBtn').disabled = true;
        setInterval(function() { my_function_count(); }, 10);
      }
    </script>
  </body>
</html>
HTML
)

(define win (webui-new-window))

(webui-bind win "my_function_count" my-function-count)
(webui-bind win "my_function_exit"  my-function-exit)

(webui-show win html)
(webui-wait)
(webui-clean)
