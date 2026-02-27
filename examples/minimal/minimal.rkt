#lang racket/base

; WebUI Racket - Minimal Example

(require "../../main.rkt")

(define win (webui-new-window))
(webui-show win "<html><head><script src=\"webui.js\"></script></head><body><h1>Hello World!</h1></body></html>")
(webui-wait)
