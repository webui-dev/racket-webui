#lang racket/base

(require ffi/unsafe
         ffi/unsafe/define
         racket/async-channel
         racket/runtime-path)

; ---------------------------------------------------------------------------
; Exports
; ---------------------------------------------------------------------------

(provide
 ; Constants — browsers
 WEBUI-BROWSER-NONE
 WEBUI-BROWSER-ANY
 WEBUI-BROWSER-CHROME
 WEBUI-BROWSER-FIREFOX
 WEBUI-BROWSER-EDGE
 WEBUI-BROWSER-SAFARI
 WEBUI-BROWSER-CHROMIUM
 WEBUI-BROWSER-OPERA
 WEBUI-BROWSER-BRAVE
 WEBUI-BROWSER-VIVALDI
 WEBUI-BROWSER-EPIC
 WEBUI-BROWSER-YANDEX
 WEBUI-BROWSER-CHROMIUM-BASED
 WEBUI-BROWSER-WEBVIEW
 ; Constants — runtimes
 WEBUI-RUNTIME-NONE
 WEBUI-RUNTIME-DENO
 WEBUI-RUNTIME-NODEJS
 WEBUI-RUNTIME-BUN
 ; Constants — event types
 WEBUI-EVENT-DISCONNECTED
 WEBUI-EVENT-CONNECTED
 WEBUI-EVENT-MOUSE-CLICK
 WEBUI-EVENT-NAVIGATION
 WEBUI-EVENT-CALLBACK
 ; Constants — config options
 WEBUI-CONFIG-SHOW-WAIT-CONNECTION
 WEBUI-CONFIG-UI-EVENT-BLOCKING
 WEBUI-CONFIG-FOLDER-MONITOR
 WEBUI-CONFIG-MULTI-CLIENT
 WEBUI-CONFIG-USE-COOKIES
 WEBUI-CONFIG-ASYNCHRONOUS-RESPONSE
 ; Window creation
 webui-new-window
 webui-new-window-id
 webui-get-new-window-id
 ; Show / display
 webui-show
 webui-show-browser
 webui-show-wv
 webui-start-server
 ; Wait / close / lifecycle
 webui-wait
 webui-close
 webui-destroy
 webui-exit
 webui-clean
 ; Window state
 webui-minimize
 webui-maximize
 webui-focus
 webui-is-shown
 ; Window appearance / behaviour
 webui-set-kiosk
 webui-set-resizable
 webui-set-hide
 webui-set-size
 webui-set-minimum-size
 webui-set-position
 webui-set-center
 webui-set-icon
 webui-set-public
 webui-set-event-blocking
 webui-set-frameless
 webui-set-transparent
 webui-set-high-contrast
 webui-is-high-contrast
 webui-set-custom-parameters
 webui-set-config
 webui-set-timeout
 webui-set-runtime
 ; Browser
 webui-get-best-browser
 webui-browser-exist
 webui-set-browser-folder
 ; Profile
 webui-set-profile
 webui-set-proxy
 webui-delete-all-profiles
 webui-delete-profile
 ; Root folder
 webui-set-root-folder
 webui-set-default-root-folder
 ; URL / navigation
 webui-get-url
 webui-open-url
 webui-navigate
 ; JavaScript execution
 webui-run
 webui-script
 ; Port / process info
 webui-get-port
 webui-set-port
 webui-get-free-port
 webui-get-parent-process-id
 webui-get-child-process-id
 ; Misc utilities
 webui-get-mime-type
 webui-encode
 webui-decode
 ; Binding and events
 webui-bind
 webui-event
 webui-event-window
 webui-event-type
 webui-event-element
 webui-event-number
 webui-event-bind-id
 ; Event argument getters (take an event and optional index)
 webui-event-get-string
 webui-event-get-int
 webui-event-get-float
 webui-event-get-bool
 webui-event-get-size
 ; In-event client operations (single connected client)
 webui-event-show-client
 webui-event-close-client
 webui-event-navigate-client
 webui-event-run-client)

; ---------------------------------------------------------------------------
; Constants
; ---------------------------------------------------------------------------

; enum webui_browser
(define WEBUI-BROWSER-NONE           0)
(define WEBUI-BROWSER-ANY            1)
(define WEBUI-BROWSER-CHROME         2)
(define WEBUI-BROWSER-FIREFOX        3)
(define WEBUI-BROWSER-EDGE           4)
(define WEBUI-BROWSER-SAFARI         5)
(define WEBUI-BROWSER-CHROMIUM       6)
(define WEBUI-BROWSER-OPERA          7)
(define WEBUI-BROWSER-BRAVE          8)
(define WEBUI-BROWSER-VIVALDI        9)
(define WEBUI-BROWSER-EPIC           10)
(define WEBUI-BROWSER-YANDEX         11)
(define WEBUI-BROWSER-CHROMIUM-BASED 12)
(define WEBUI-BROWSER-WEBVIEW        13)

; enum webui_runtime
(define WEBUI-RUNTIME-NONE   0)
(define WEBUI-RUNTIME-DENO   1)
(define WEBUI-RUNTIME-NODEJS 2)
(define WEBUI-RUNTIME-BUN    3)

; enum webui_event
(define WEBUI-EVENT-DISCONNECTED 0)
(define WEBUI-EVENT-CONNECTED    1)
(define WEBUI-EVENT-MOUSE-CLICK  2)
(define WEBUI-EVENT-NAVIGATION   3)
(define WEBUI-EVENT-CALLBACK     4)

; typedef enum webui_config
(define WEBUI-CONFIG-SHOW-WAIT-CONNECTION   0)
(define WEBUI-CONFIG-UI-EVENT-BLOCKING      1)
(define WEBUI-CONFIG-FOLDER-MONITOR         2)
(define WEBUI-CONFIG-MULTI-CLIENT           3)
(define WEBUI-CONFIG-USE-COOKIES            4)
(define WEBUI-CONFIG-ASYNCHRONOUS-RESPONSE  5)

; ---------------------------------------------------------------------------
; DLL path — resolved relative to this source file at runtime
; ---------------------------------------------------------------------------

(define-runtime-path here ".")

(define webui-dll-path
  (let ([os   (system-type 'os)]
        [arch (system-type 'arch)])
    (cond
      [(eq? os 'windows)
       (build-path here "webui-windows-msvc-x64" "webui-2.dll")]
      [(eq? os 'macosx)
       (if (eq? arch 'aarch64)
           (build-path here "webui-macos-clang-arm64" "libwebui-2.dylib")
           (build-path here "webui-macos-clang-x64"   "libwebui-2.dylib"))]
      [else ; Linux
       (cond
         [(eq? arch 'aarch64) (build-path here "webui-linux-gcc-arm64" "libwebui-2.so")]
         [(eq? arch 'arm)     (build-path here "webui-linux-gcc-arm"   "libwebui-2.so")]
         [else                (build-path here "webui-linux-gcc-x64"   "libwebui-2.so")])])))

; ---------------------------------------------------------------------------
; Thread-safe queue — dispatches C callbacks onto a Racket thread
; async-channel is safe to put to from any OS thread (including WebUI's
; WebSocket threads) and never allocates inside a GC atomic section.
; ---------------------------------------------------------------------------

(define callback-queue (make-async-channel))

(define (enqueue thunk)
  (async-channel-put callback-queue thunk))

; Any C callback created from a Racket procedure via (_fun #:keep callback-store ...)
; is stored here, making it a permanent GC root. Without this, Racket CS's moving
; GC can collect/relocate the trampoline between webui_interface_bind and invocation.
(define callback-store (box '()))

(void
  (thread (lambda ()
            (let loop ()
              ((async-channel-get callback-queue))
              (loop)))))

; ---------------------------------------------------------------------------
; Internal state — maps element IDs to user Racket functions
; ---------------------------------------------------------------------------

(define bound-functions (make-hash))

; ---------------------------------------------------------------------------
; Event struct
; Fields mirror the webui_interface_bind callback parameters:
;   (size_t window, size_t event_type, char* element,
;    size_t event_number, size_t bind_id)
; ---------------------------------------------------------------------------

(struct webui-event (window type element number bind-id) #:transparent)

; ---------------------------------------------------------------------------
; C FFI bindings
; ---------------------------------------------------------------------------

(define-ffi-definer define-webui (ffi-lib webui-dll-path))

; -- Window creation --
(define-webui webui_new_window     (_fun -> _size))
(define-webui webui_new_window_id  (_fun _size -> _size))
(define-webui webui_get_new_window_id (_fun -> _size))

; -- Show / display --
(define-webui webui_show         (_fun _size _string/utf-8 -> _bool))
(define-webui webui_show_browser (_fun _size _string/utf-8 _size -> _bool))
(define-webui webui_show_wv      (_fun _size _string/utf-8 -> _bool))
(define-webui webui_start_server (_fun _size _string/utf-8 -> _string/utf-8))

; -- Wait / lifecycle --
(define-webui webui_wait_async            (_fun -> _bool))
(define-webui webui_close                 (_fun _size -> _void))
(define-webui webui_minimize              (_fun _size -> _void))
(define-webui webui_maximize              (_fun _size -> _void))
(define-webui webui_focus                 (_fun _size -> _void))
(define-webui webui_destroy               (_fun _size -> _void))
(define-webui webui_exit                  (_fun -> _void))
(define-webui webui_clean                 (_fun -> _void))
(define-webui webui_is_shown              (_fun _size -> _bool))

; -- Window appearance / behaviour --
(define-webui webui_set_kiosk             (_fun _size _bool -> _void))
(define-webui webui_set_resizable         (_fun _size _bool -> _void))
(define-webui webui_set_hide              (_fun _size _bool -> _void))
(define-webui webui_set_size              (_fun _size _uint _uint -> _void))
(define-webui webui_set_minimum_size      (_fun _size _uint _uint -> _void))
(define-webui webui_set_position          (_fun _size _uint _uint -> _void))
(define-webui webui_set_center            (_fun _size -> _void))
(define-webui webui_set_icon              (_fun _size _string/utf-8 _string/utf-8 -> _void))
(define-webui webui_set_public            (_fun _size _bool -> _void))
(define-webui webui_set_event_blocking    (_fun _size _bool -> _void))
(define-webui webui_set_frameless         (_fun _size _bool -> _void))
(define-webui webui_set_transparent       (_fun _size _bool -> _void))
(define-webui webui_set_high_contrast     (_fun _size _bool -> _void))
(define-webui webui_is_high_contrast      (_fun -> _bool))
(define-webui webui_set_custom_parameters (_fun _size _string/utf-8 -> _void))
(define-webui webui_set_config            (_fun _int _bool -> _void))
(define-webui webui_set_timeout           (_fun _size -> _void))
(define-webui webui_set_runtime           (_fun _size _size -> _void))

; -- Browser --
(define-webui webui_get_best_browser      (_fun _size -> _size))
(define-webui webui_browser_exist         (_fun _size -> _bool))
(define-webui webui_set_browser_folder    (_fun _string/utf-8 -> _void))

; -- Profile --
(define-webui webui_set_profile           (_fun _size _string/utf-8 _string/utf-8 -> _void))
(define-webui webui_set_proxy             (_fun _size _string/utf-8 -> _void))
(define-webui webui_delete_all_profiles   (_fun -> _void))
(define-webui webui_delete_profile        (_fun _size -> _void))

; -- Root folder --
(define-webui webui_set_root_folder         (_fun _size _string/utf-8 -> _bool))
(define-webui webui_set_default_root_folder (_fun _string/utf-8 -> _bool))

; -- URL / navigation --
(define-webui webui_get_url    (_fun _size -> _string/utf-8))
(define-webui webui_open_url   (_fun _string/utf-8 -> _void))
(define-webui webui_navigate   (_fun _size _string/utf-8 -> _void))

; -- JavaScript execution --
(define-webui webui_run    (_fun _size _string/utf-8 -> _void))
(define-webui webui_script (_fun _size _string/utf-8 _size _bytes _size -> _bool))

; -- Port / process info --
(define-webui webui_get_port              (_fun _size -> _size))
(define-webui webui_set_port              (_fun _size _size -> _bool))
(define-webui webui_get_free_port         (_fun -> _size))
(define-webui webui_get_parent_process_id (_fun _size -> _size))
(define-webui webui_get_child_process_id  (_fun _size -> _size))

; -- Utilities --
(define-webui webui_get_mime_type (_fun _string/utf-8 -> _string/utf-8))
(define-webui webui_encode        (_fun _string/utf-8 -> _string/utf-8))
(define-webui webui_decode        (_fun _string/utf-8 -> _string/utf-8))

; -- Interface API (used internally and for per-client event operations) --
(define-webui webui_interface_is_app_running (_fun -> _bool))
(define-webui webui_interface_bind
  (_fun _size _string/utf-8
        (_fun #:keep callback-store #:async-apply enqueue
              _size _size _string/utf-8 _size _size -> _void)
        -> _size))
(define-webui webui_interface_set_response
  (_fun _size _size _string/utf-8 -> _void))
(define-webui webui_interface_get_string_at
  (_fun _size _size _size -> _string/utf-8))
(define-webui webui_interface_get_int_at
  (_fun _size _size _size -> _int64))
(define-webui webui_interface_get_float_at
  (_fun _size _size _size -> _double))
(define-webui webui_interface_get_bool_at
  (_fun _size _size _size -> _bool))
(define-webui webui_interface_get_size_at
  (_fun _size _size _size -> _size))
(define-webui webui_interface_show_client
  (_fun _size _size _string/utf-8 -> _bool))
(define-webui webui_interface_close_client
  (_fun _size _size -> _void))
(define-webui webui_interface_navigate_client
  (_fun _size _size _string/utf-8 -> _void))
(define-webui webui_interface_run_client
  (_fun _size _size _string/utf-8 -> _void))

; ---------------------------------------------------------------------------
; Internal event handler — called from C via webui_interface_bind
; ---------------------------------------------------------------------------

(define (internal-event-handler window event-type element event-number bind-id)
  (let* ([user-func (hash-ref bound-functions element #f)]
         [response  (if user-func
                        (user-func (webui-event window event-type element event-number bind-id))
                        (void))])
    ; Always signal completion — WebUI (with asynchronous_response=true) blocks
    ; until webui_interface_set_response is called, regardless of return value.
    ; Use "" for void/no-response callbacks (fire-and-forget), or the actual value
    ; for callbacks that return data to a JS Promise.
    (webui_interface_set_response
     window event-number
     (if (and response (not (void? response)))
         (format "~a" response)
         ""))))

; ---------------------------------------------------------------------------
; Public Racket API
; ---------------------------------------------------------------------------

; -- Window creation --

(define (webui-new-window)
  (webui_new_window))

(define (webui-new-window-id window-number)
  (webui_new_window_id window-number))

(define (webui-get-new-window-id)
  (webui_get_new_window_id))

; -- Show / display --

(define (webui-show window content)
  (webui_show window content))

(define (webui-show-browser window content browser)
  (webui_show_browser window content browser))

(define (webui-show-wv window content)
  (webui_show_wv window content))

; Returns the URL of the running server, or #f on failure.
(define (webui-start-server window content)
  (webui_start_server window content))

; -- Wait / lifecycle --

; Blocks until all windows are closed, yielding to other Racket threads.
(define (webui-wait)
  (let loop ()
    (when (webui_wait_async)
      (sleep 0)
      (loop))))

(define (webui-close window)
  (webui_close window))

(define (webui-minimize window)
  (webui_minimize window))

(define (webui-maximize window)
  (webui_maximize window))

(define (webui-focus window)
  (webui_focus window))

(define (webui-destroy window)
  (webui_destroy window))

(define (webui-exit)
  (webui_exit))

(define (webui-clean)
  (webui_clean))

(define (webui-is-shown window)
  (webui_is_shown window))

; -- Window appearance / behaviour --

(define (webui-set-kiosk window status)
  (webui_set_kiosk window status))

(define (webui-set-resizable window status)
  (webui_set_resizable window status))

(define (webui-set-hide window status)
  (webui_set_hide window status))

(define (webui-set-size window width height)
  (webui_set_size window width height))

(define (webui-set-minimum-size window width height)
  (webui_set_minimum_size window width height))

(define (webui-set-position window x y)
  (webui_set_position window x y))

(define (webui-set-center window)
  (webui_set_center window))

; icon is SVG/HTML string; icon-type is MIME string e.g. "image/svg+xml"
(define (webui-set-icon window icon icon-type)
  (webui_set_icon window icon icon-type))

(define (webui-set-public window status)
  (webui_set_public window status))

(define (webui-set-event-blocking window status)
  (webui_set_event_blocking window status))

(define (webui-set-frameless window status)
  (webui_set_frameless window status))

(define (webui-set-transparent window status)
  (webui_set_transparent window status))

(define (webui-set-high-contrast window status)
  (webui_set_high_contrast window status))

(define (webui-is-high-contrast)
  (webui_is_high_contrast))

(define (webui-set-custom-parameters window params)
  (webui_set_custom_parameters window params))

; option is one of the WEBUI-CONFIG-* constants
(define (webui-set-config option status)
  (webui_set_config option status))

; timeout in seconds (0 = wait forever)
(define (webui-set-timeout seconds)
  (webui_set_timeout seconds))

; runtime is one of the WEBUI-RUNTIME-* constants
(define (webui-set-runtime window runtime)
  (webui_set_runtime window runtime))

; -- Browser --

; Returns a WEBUI-BROWSER-* constant
(define (webui-get-best-browser window)
  (webui_get_best_browser window))

; browser is a WEBUI-BROWSER-* constant
(define (webui-browser-exist browser)
  (webui_browser_exist browser))

(define (webui-set-browser-folder path)
  (webui_set_browser_folder path))

; -- Profile --

(define (webui-set-profile window name path)
  (webui_set_profile window name path))

(define (webui-set-proxy window proxy-server)
  (webui_set_proxy window proxy-server))

(define (webui-delete-all-profiles)
  (webui_delete_all_profiles))

(define (webui-delete-profile window)
  (webui_delete_profile window))

; -- Root folder --

(define (webui-set-root-folder window path)
  (webui_set_root_folder window path))

(define (webui-set-default-root-folder path)
  (webui_set_default_root_folder path))

; -- URL / navigation --

(define (webui-get-url window)
  (webui_get_url window))

(define (webui-open-url url)
  (webui_open_url url))

(define (webui-navigate window url)
  (webui_navigate window url))

; -- JavaScript execution --

; Fire-and-forget: run JS in all clients of this window.
(define (webui-run window script)
  (webui_run window script))

; Run JS and return the result string, or #f on error.
; timeout is in seconds (0 = no timeout); buffer-size is the max response bytes.
(define (webui-script window script [timeout 0] [buffer-size 4096])
  (let* ([buf (make-bytes buffer-size 0)]
         [ok  (webui_script window script timeout buf buffer-size)])
    (if ok
        (let ([end (let loop ([i 0])
                     (if (or (= i buffer-size) (= (bytes-ref buf i) 0))
                         i
                         (loop (+ i 1))))])
          (bytes->string/utf-8 buf #f 0 end))
        #f)))

; -- Port / process info --

(define (webui-get-port window)
  (webui_get_port window))

(define (webui-set-port window port)
  (webui_set_port window port))

(define (webui-get-free-port)
  (webui_get_free_port))

(define (webui-get-parent-process-id window)
  (webui_get_parent_process_id window))

(define (webui-get-child-process-id window)
  (webui_get_child_process_id window))

; -- Utilities --

(define (webui-get-mime-type file)
  (webui_get_mime_type file))

(define (webui-encode str)
  (webui_encode str))

(define (webui-decode str)
  (webui_decode str))

; -- Binding --

(define (webui-bind window element user-func)
  (hash-set! bound-functions element user-func)
  (webui_interface_bind window element internal-event-handler))

; -- Event argument getters --

(define (webui-event-get-string event [index 0])
  (webui_interface_get_string_at
   (webui-event-window event) (webui-event-number event) index))

(define (webui-event-get-int event [index 0])
  (webui_interface_get_int_at
   (webui-event-window event) (webui-event-number event) index))

(define (webui-event-get-float event [index 0])
  (webui_interface_get_float_at
   (webui-event-window event) (webui-event-number event) index))

(define (webui-event-get-bool event [index 0])
  (webui_interface_get_bool_at
   (webui-event-window event) (webui-event-number event) index))

; Returns the byte-size of the argument at index (useful for raw data).
(define (webui-event-get-size event [index 0])
  (webui_interface_get_size_at
   (webui-event-window event) (webui-event-number event) index))

; -- In-event client operations --

; Refresh the UI for only the client that triggered this event.
(define (webui-event-show-client event content)
  (webui_interface_show_client
   (webui-event-window event) (webui-event-number event) content))

; Close only the client that triggered this event.
(define (webui-event-close-client event)
  (webui_interface_close_client
   (webui-event-window event) (webui-event-number event)))

; Navigate only the client that triggered this event.
(define (webui-event-navigate-client event url)
  (webui_interface_navigate_client
   (webui-event-window event) (webui-event-number event) url))

; Run JS in only the client that triggered this event.
(define (webui-event-run-client event script)
  (webui_interface_run_client
   (webui-event-window event) (webui-event-number event) script))

; ---------------------------------------------------------------------------
; Module initialisation — set required config options on load
; ---------------------------------------------------------------------------

; asynchronous_response (5): let webui wait for webui_interface_set_response
; ui_event_blocking (1): process one event at a time so responses are in-order
(webui_set_config WEBUI-CONFIG-ASYNCHRONOUS-RESPONSE #t)
(webui_set_config WEBUI-CONFIG-UI-EVENT-BLOCKING #t)
