#lang racket/base

; Import WebUI
(require "../../main.rkt")

; A simple callback function that can be called from JavaScript
(define (myRacketFunction e)
  (let* ([a (webui-event-get-int e 0)]
         [b (webui-event-get-int e 1)]
         [res (* a b)])
    (printf "~a * ~a = ~a\n" a b res)
    (flush-output)
    (format "~a" res)))

; Create a Window
(define win (webui-new-window))

; Bind our callback function
(webui-bind win "myRacketFunction" myRacketFunction)

; Show the window
(webui-show win "index.html")

; Wait until all windows get closed
(webui-wait)
(webui-clean)
