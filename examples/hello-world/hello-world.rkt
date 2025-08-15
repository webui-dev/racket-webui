#lang racket/base

(require "../../main.rkt")
(require racket/file)

(define (myRacketFunction e)
  (let* ([a (webui-event-get-int e 0)]
         [b (webui-event-get-int e 1)]
         [res (* a b)])
    (printf "~a * ~a = ~a\n" a b res)
    (flush-output)
    (format "~a" res)))

(define html-content (file->string "index.html"))
(define my-window (webui-new-window))

(webui-bind my-window "myRacketFunction" myRacketFunction)

(webui-show my-window html-content)

(webui-wait)
(webui-clean)