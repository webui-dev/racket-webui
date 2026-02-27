#lang racket/base

; WebUI Racket - Serve a Folder Example
;
; Run from this directory: racket serve-a-folder.rkt

(require "../../main.rkt")

(define MY-WINDOW        1)
(define MY-SECOND-WINDOW 2)

; Binding "" catches all unbound events: connect/disconnect, clicks, navigation.
; Navigation events arrive here instead of following the href.
(define (events e)
  (case (webui-event-type e)
    [(0) (printf "Disconnected.~n")]  ; WEBUI-EVENT-DISCONNECTED
    [(1) (printf "Connected.~n")]     ; WEBUI-EVENT-CONNECTED
    [(2) (printf "Click.~n")]         ; WEBUI-EVENT-MOUSE-CLICK
    [(3)
     (let ([url (webui-event-get-string e 0)])
       (printf "Navigating to: ~a~n" url)
       (webui-navigate (webui-event-window e) url))])
  (flush-output))

(define (switch-to-second-page e)
  (webui-show (webui-event-window e) "second.html"))

(define (show-second-window e)
  (webui-show MY-SECOND-WINDOW "second.html"))

(define (exit-app e)
  (webui-exit))

(webui-new-window-id MY-WINDOW)
(webui-new-window-id MY-SECOND-WINDOW)

(webui-bind MY-WINDOW "" events)
(webui-bind MY-WINDOW "SwitchToSecondPage" switch-to-second-page)
(webui-bind MY-WINDOW "OpenNewWindow"       show-second-window)
(webui-bind MY-WINDOW "Exit"               exit-app)
(webui-bind MY-SECOND-WINDOW "Exit" exit-app)

(webui-set-size     MY-WINDOW 800 600)
(webui-set-position MY-WINDOW 200 200)

(webui-show MY-WINDOW "index.html")
(webui-wait)
(webui-clean)
