#lang racket/base

; WebUI Racket - ChatGPT HTTPS API Example
;
; Uses a hidden Chromium window as an HTTP client — no native HTTP library needed.
; Usage: racket chatgpt-api.rkt What is the capital of Canada?

(require "../../main.rkt")

(define USER-KEY       "sk-proj-xxx-xxxxxxxxxxxxxxxxxxxxxxx_xxx")
(define USER-MODEL     "gpt-4o")
(define USER-ASSISTANT "You are an assistant, answer with very short messages.")

(define html #<<HTML
<!DOCTYPE html>
<html>
  <head>
    <script src="webui.js"></script>
  </head>
  <body>
    <script>
      function run_gpt_api(userKey, userModel, userAssistant, userContent) {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", "https://api.openai.com/v1/chat/completions", false);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.setRequestHeader("Authorization", "Bearer " + userKey);
        xhr.send(JSON.stringify({
          model: userModel,
          messages: [
            { role: "developer", content: userAssistant },
            { role: "user",      content: userContent  }
          ]
        }));
        const json = JSON.parse(xhr.responseText);
        if (json.error) {
          return "Error: " + json.error.message;
        }
        return json.choices[0].message.content.trim();
      }
    </script>
  </body>
</html>
HTML
)

(define args (vector->list (current-command-line-arguments)))

(when (null? args)
  (printf "Usage: racket chatgpt-api.rkt <your question>~n")
  (printf "Example: racket chatgpt-api.rkt What is the capital of Canada?~n")
  (exit 0))

(define user-query (string-join args " "))

; Chromium is used as a headless HTTP client — no window shown.
(define win (webui-new-window))
(webui-set-hide win #t)
(webui-show-browser win html WEBUI-BROWSER-CHROMIUM-BASED)

(define js (format "return run_gpt_api('~a', '~a', '~a', '~a');"
                   USER-KEY USER-MODEL USER-ASSISTANT user-query))

(define result (webui-script win js 30 1024))
(if result
    (printf "AI Response: ~a~n" result)
    (printf "Error: no response received (check your API key and network).~n"))

(webui-exit)
(webui-clean)
