#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         ffi/unsafe/atomic
         racket/hash
         racket/path)

(provide webui-new-window
         webui-show
         webui-wait
         webui-clean
         webui-bind
         webui-event
         webui-event-window
         webui-event-event-number
         webui-event-get-string
         webui-event-get-int
         webui-event-get-float
         webui-event-get-bool)

; WebUI Path
; TODO: Support Linux and macOS paths
; TODO: Use current-module-path
;(define webui-dll-path (build-path (path-only (current-module-path)) "webui-windows-msvc-x64" "webui-2.dll"))
(define webui-dll-path "../../webui-windows-msvc-x64/webui-2.dll")

; WebUI API configurations
(define WEBUI_OPTION_ASYNCHRONOUS_RESPONSE 1)
(define WEBUI_OPTION_UI_EVENT_BLOCKING 2)

; Internal thread-safe queue for handling C callbacks
(define sema (make-semaphore))
(define queue null)

(define (enqueue applyer)
  (start-atomic)
  (set! queue (append queue (list applyer)))
  (end-atomic)
  (semaphore-post sema))

(define (dequeue)
  (semaphore-wait sema)
  (start-atomic)
  (let ([v (car queue)])
    (set! queue (cdr queue))
    (end-atomic)
    v))

(void
  (thread (lambda ()
            (let loop ()
              (let ([thunk (dequeue)])
                (thunk))
              (loop)))))

; Internal hash table to store user's bound functions
(define bound-functions (make-hash))

; Define the webui-event struct
(struct webui-event (window event-number) #:transparent)

; C FFI Bindings
(define-ffi-definer define-webui (ffi-lib webui-dll-path))

(define-webui webui_new_window (_fun -> _size))
(define-webui webui_show (_fun _size _string/utf-8 -> _bool))
(define-webui webui_clean (_fun -> _void))
(define-webui webui_set_config (_fun _int _bool -> _void))

; Corrected bindings to use the webui_interface APIs
(define-webui webui_interface_is_app_running (_fun -> _int))
(define-webui webui_interface_bind (_fun _size _string/utf-8 (_fun #:async-apply enqueue _size _size _string/utf-8 _size _size -> _void) -> _size))
(define-webui webui_interface_set_response (_fun _size _size _string/utf-8 -> _void))

; User-friendly Racket API to retrieve data using interface APIs
(define-webui webui_interface_get_string_at (_fun _size _size _size -> _string/utf-8))
(define-webui webui_interface_get_int_at (_fun _size _size _size -> _int64))
(define-webui webui_interface_get_float_at (_fun _size _size _size -> _double))
(define-webui webui_interface_get_bool_at (_fun _size _size _size -> _bool))

; Wrapper functions that take the webui-event struct
(define (webui-event-get-string event [index 0])
  (webui_interface_get_string_at (webui-event-window event) (webui-event-event-number event) index))

(define (webui-event-get-int event [index 0])
  (webui_interface_get_int_at (webui-event-window event) (webui-event-event-number event) index))

(define (webui-event-get-float event [index 0])
  (webui_interface_get_float_at (webui-event-window event) (webui-event-event-number event) index))

(define (webui-event-get-bool event [index 0])
  (webui_interface_get_bool_at (webui-event-window event) (webui-event-event-number event) index))

; The internal event handler that receives all events from WebUI
(define (internal-event-handler window event-type element event-number bind-id)
  (let ([user-func (hash-ref bound-functions element #f)])
    (when user-func
      (let* ([event-obj (webui-event window event-number)]
             [response (user-func event-obj)])
        (webui_interface_set_response window event-number (format "~a" response))))))

; Racket API for users
(define (webui-new-window)
  (webui_new_window))

(define (webui-show window html)
  (webui_show window html))

(define (webui-clean)
  (webui_clean))

(define (webui-wait)
  (let loop ()
    (when (not (zero? (webui_interface_is_app_running)))
      (sleep 0.1)
      (loop))))

(define (webui-bind window element user-func)
  (hash-set! bound-functions element user-func)
  (webui_interface_bind window element internal-event-handler))

; Initialize WebUI with the correct configuration on module load
(webui_set_config WEBUI_OPTION_ASYNCHRONOUS_RESPONSE #t)
(webui_set_config WEBUI_OPTION_UI_EVENT_BLOCKING #t)
