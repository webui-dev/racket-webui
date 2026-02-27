#lang racket/base

; WebUI Racket - Custom Web Server Example
;
; Port 8080 — your web server serves the HTML/CSS/JS files
; Port 8081 — WebUI serves webui.js and the WebSocket connection
;
; HTML files include: <script src="http://localhost:8081/webui.js"></script>
;
; Usage:
;   1. python -m http.server 8080   (in this directory)
;   2. racket custom-web-server.rkt

(require "../../main.rkt")

(define (my-backend-func e)
  (let ([n1 (webui-event-get-int e 0)]
        [n2 (webui-event-get-int e 1)]
        [n3 (webui-event-get-int e 2)])
    (printf "my-backend-func 1: ~a~n" n1)
    (printf "my-backend-func 2: ~a~n" n2)
    (printf "my-backend-func 3: ~a~n" n3)
    (flush-output)))

(define (events e)
  (case (webui-event-type e)
    [(0) (printf "Disconnected.~n") (flush-output)]
    [(1) (printf "Connected.~n")    (flush-output)]
    [(3) (webui-navigate (webui-event-window e) (webui-event-get-string e 0))]))

(define win (webui-new-window))

(webui-bind win "" events)
(webui-bind win "my_backend_func" my-backend-func)

; webui.js is served from 8081; HTML files reference http://localhost:8081/webui.js
(webui-set-port win 8081)
(webui-show win "http://localhost:8080/")

(webui-wait)
(webui-clean)
