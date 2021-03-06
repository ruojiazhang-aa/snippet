(use-modules (ice-9 pretty-print))
;;
;; Util funcitons
;;

(define (display-line x)
  (display x)
  (newline))

(define true #t)
(define false #f)

(define apply-in-underlying-scheme apply)
(define eval-in-underlying-scheme eval)

;;
;; Start 4.1.1 The Core of the evaluator
;;

(define (eval exp env)
  (cond ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-variable-value exp env))
        ((quoted? exp) (text-of-quotation exp))
        ((assignment? exp) (eval-assignment exp env))
        ((definition? exp) (eval-definition exp env))
        ((if? exp) (eval-if exp env))
        ((lambda? exp) (make-procedure (lambda-parameters exp)
                                       (lambda-body exp)
                                       env))
        ((begin? exp)
         (eval-sequence (begin-actions exp) env))
        ((cond? exp) (eval (cond->if exp) env))
        ((application? exp)
         (apply (eval (operator exp) env)
                (list-of-values (operands exp) env)))
        (else
          (error "Unknow expression type: EVAL" exp))))

(define (apply procedure arguments)
  (cond ((primitive-procedure? procedure)
         (apply-primitive-procedure procedure arguments))
        ((compound-procedure? procedure)
         (eval-sequence
           (procedure-body procedure)
           (extend-environment
             (procedure-parameters procedure)
             arguments
             (procedure-environment procedure))))
        (else
          (error
            "Unknow procedure type: APPLY" procedure))))


(define (list-of-values exps env)
  (if (no-operands? exps)
    '()
    (cons (eval (first-operand exps) env)
          (list-of-values (rest-operands exps) env))))


(define (eval-if exp env)
  (if (true? (eval (if-predicate exp) env))
    (eval (if-consequent exp) env)
    (eval (if-alternative exp) env)))


(define (eval-sequence exps env)
  (cond ((last-exp? exps)
         (eval (first-exp exps) env))
        (else
          (eval (first-exp exps) env)
          (eval-sequence (rest-exps exps) env))))


(define (eval-assignment exp env)
  (set-variable-value! (assignment-variable exp)
                       (eval (assignment-value exp) env)
                       env)
  'ok-eval-assignment)

(define (eval-definition exp env)
  (define-variable! (definition-variable exp)
                    (eval (definition-value exp) env)
                    env)
  'ok-eval-definition)


; Start exercise 4.1
; use nest let to force scheme eval by order
(define (list-of-value-left-to-right exps env)
  (if (no-operands? exps)
    '()
    (let ((left (eval (first-operand exps) env)))
      (let ((right (list-of-value-left-to-right (rest-operands exps) env)))
        (cons left right)))))

(define (list-of-value-right-to-left exps env)
  (if (no-operands? exps)
    '()
    (let* ((right (list-of-value-right-to-left (rest-operands exps) env))
           (left (eval (first-exp exps) env)))
      (cons left right))))

; or use just let function

(define (list-of-value-left-to-right exps env)
  (if (no-operands? exps)
    '()
    (let ((left (eval (first-operand exps) env)))
      (cons left (list-of-value-left-to-right (rest-operands exps) env)))))

; End exercise 4.1

;;
;; End The core of the evaluator
;;


;;
;; 4.1.2 Start Representing Expressions
;;

(define (self-evaluating? exp)
  (cond ((number? exp) true)
        ((string? exp) true)
        (else false)))

(define (variable? exp) (symbol? exp))

; quote has the form: (quote <text-of-quotation>)
(define (quoted? exp) (tagged-list? exp 'quote))
(define (text-of-quotation exp) (cadr exp))

(define (tagged-list? exp tag)
  (if (pair? exp)
    (eq? (car exp) tag)
    false))

; assignments have the form: (set! <var> <value>)
(define (assignment? exp) (tagged-list? exp 'set!))
(define (assignment-variable exp) (cadr exp))
(define (assignment-value exp) (caddr exp))

; Definitions have the form:
; (define <var> <value>)
; (define (<var> <parameter1> ... <parametern>)
;   <body>)
; the latter form is syntactic sugra for
; (define (<var>)
;   (lambda (<parameter1> ... <paramtern>)
;     <body>))

(define (definition? exp) (tagged-list? exp 'define))
(define (definition-variable exp)
  (if (symbol? (cadr exp))
    (cadr exp)
    (caadr exp)))
(define (definition-value exp)
  (if (symbol? (cadr exp))
    (caddr exp)
    (make-lambda (cdadr exp)        ;formal parameters
                 (cddr exp))))      ;body

(define (lambda? exp) (tagged-list? exp 'lambda))
(define (lambda-parameters exp) (cadr exp))
(define (lambda-body exp) (cddr exp))

(define (make-lambda parameters body)
  (cons 'lambda (cons parameters body)))

(define (if? exp) (tagged-list? exp 'if))
(define (if-predicate exp) (cadr exp))
(define (if-consequent exp) (caddr exp))
(define (if-alternative exp)
  (if (not (null? (cdddr exp)))
    (cadddr exp)
    'false))
(define (make-if predicate consequent alternative)
  (list 'if predicate consequent alternative))

(define (begin? exp) (tagged-list? exp 'begin))
(define (begin-actions exp) (cdr exp))
(define (last-exp? seq) (null? (cdr seq)))
(define (first-exp seq) (car seq))
(define (rest-exps seq) (cdr seq))

(define (sequence->exp seq)
  (cond ((null? seq) seq)
        ((last-exp? seq) (first-exp seq))
        (else (make-begin seq))))

(define (make-begin seq) (cons 'begin seq))

(define (application? exp) (pair? exp))
(define (operator exp) (car exp))
(define (operands exp) (cdr exp))
(define (no-operands? ops) (null? ops))
(define (first-operand ops) (car ops))
(define (rest-operands ops) (cdr ops))

; Derived expressions
(define (cond? exp) (tagged-list? exp 'cond))
(define (cond-clauses exp) (cdr exp))
(define (cond-else-clause? clause)
  (eq? (cond-predicate clause) 'else))
(define (cond-predicate clause) (car clause))
(define (cond-actions clause) (cdr clause))
(define (cond->if exp) (expand-clauses (cond-clauses exp)))

(define (expand-clauses clauses)
  (if (null? clauses)
    'false
    (let ((first (car clauses))
          (rest (cdr clauses)))
      (if (cond-else-clause? first)
        (if (null? rest)
          (sequence->exp (cond-actions first))
          (error "ELSE clause isn't last: COOND->IF"
                 clauses))
        (make-if (cond-predicate first)
                 (sequence->exp (cond-actions first))
                 (expand-clauses rest))))))


; Start exercise 4.2
; a: because all of pair expression will be regarded to application

(define (application-ex4.2? exp) (tagged-list? exp 'call))
(define (operator-ex4.2 exp) (cadr exp))
(define (operands-ex4.2 exp) (cddr exp))

; End exercise 4.2

; Start exercise 4.3

(define (make-table)
  (let ((local-table (list '*table*)))
    (define (lookup key-1 key-2)
      (let ((subtable
              (assoc key-1 (cdr local-table))))
        (if subtable
          (let ((record
                  (assoc key-2 (cdr subtable))))
            (if record (cdr record) #f))
          #f)))
    (define (insert! key-1 key-2 value)
      (let ((subtable
              (assoc key-1 (cdr local-table))))
        (if subtable
          (let ((record
                  (assoc key-2 (cdr subtable))))
            (if record
              (set-cdr! record value)
              (set-cdr! subtable
                        (cons (cons key-2 value)
                              (cdr subtable)))))
          (set-cdr! local-table
                    (cons (list key-1 (cons key-2 value))
                          (cdr local-table)))))
      'ok-insert-table)
    (define (dispatch m)
      (cond ((eq? m 'lookup-proc) lookup)
            ((eq? m 'insert-proc!) insert!)
            (else (error "Unknow operation: TABLE" m))))
    dispatch))

(define operation-table (make-table))
(define get (operation-table 'lookup-proc))
(define put (operation-table 'insert-proc!))

(put 'op 'quote (lambda (exp env) (text-of-quotation exp)))
(put 'op 'set! eval-assignment)
(put 'op 'define eval-definition)
(put 'op 'if eval-if)

(put 'op 'lambda (lambda (exp env) (make-procedure (lambda-parameters exp)
                                                   (lambda-body exp)
                                                   env)))
(put 'op 'begin (lambda (exp env) (eval-sequence (begin-actions exp) env)))
(put 'op 'cond (lambda (exp env) (eval-ex4.3 (cond->if exp) env)))

(define (eval-ex4.3 exp env)
  (cond ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-variable-value exp env))
        ((get 'op (car exp))
         (let ((proc (get 'op (car exp))))
           (apply-in-underlying-scheme proc (list exp env))))
        ((application? exp)
         (apply (eval-ex4.3 (operator exp) env)
                (list-of-values (operands exp) env)))
        (else
          (error "Unknow expressoin type: EVAL" exp))))

(define eval eval-ex4.3)

; End exercise 4.3

;(display-line (let* ((x 3) (y (+ x 2)) (z (+ x y 5)))
  ;(* x z)))

; Start exercie 4.4

(define (andor-first-condition exp) (car exp))
(define (andor-rest-conditions exp) (cdr exp))
(define (andor-conditions exp) (cdr exp))

(define (expand-and-conditions exp)
  (if (null? exp)
    'true
    (make-if (andor-first-condition exp)
             (expand-and-conditions (andor-rest-conditions exp))
             'false)))
(define (and->if exp) (expand-and-conditions (andor-conditions exp)))
(define (eval-and exp env)
  (eval-ex4.3 (and->if exp) env))

(define (expand-or-conditions exp)
  (if (null? exp)
    'false
    (make-if (andor-first-condition exp)
             'true
             (expand-or-conditions (andor-rest-conditions exp)))))
(define (or->if exp) (expand-or-conditions (andor-conditions exp)))
(define (eval-or exp env) (eval (or->if exp) env))

(put 'op 'and eval-and)
(put 'op 'or eval-or)
; TODO: eval (or =(1 2))

; End exercie 4.4

; Start exercie 4.5
(define (cond-special-clause? exp) (eq? '=> (cadr exp)))
(define (cond-special-clause-action exp) (caddr exp))
(define (expand-clauses-4.5 clauses)
  (if (null? clauses)
    'false
    (let ((first (car clauses))
          (rest (cdr clauses)))
      (if (cond-else-clause? first)
        (if (null? rest)
          (sequence->exp (cond-actions first))
          (error "ELSE clause isn't last: COOND->IF"
                 clauses))
          (make-if (cond-predicate first)
                   (if (cond-special-clause? first)
                     ; (cons a alist) will return a new list which appended a to the head of alist
                     ;(cons (cond-special-clause-action first) (list (cond-predicate first)))
                     (list (cond-special-clause-action first) (cond-predicate first))
                     (sequence->exp (cond-actions first)))
                   (expand-clauses-4.5 rest))))))
(define expand-clauses expand-clauses-4.5)
; End exercie 4.5

; Start exercie 4.6
(define (let-definitions exp) (cadr exp))
(define (let-body exp) (cddr exp))
(define (expand-let-variables vars)
  (if (null? vars)
    '()
    (cons (caar vars) (expand-let-variables (cdr vars)))))
(define (expand-let-values vars)
  (if (null? vars)
    '()
    (cons (cadar vars) (expand-let-values (cdr vars)))))
(define (let->combination exp)
  (cons (make-lambda (expand-let-variables (let-definitions exp)) (let-body exp))
        (expand-let-values (let-definitions exp))))

(define (eval-let exp env)
  (eval (let->combination exp) env))
(put 'op 'let eval-let)
; End exercie 4.6

; Start exercie 4.7
(define (let*-expands-definitions definitions body)
  (if (null? definitions)
    body
    (list (append (list 'let (list (car definitions)))
                  (let*-expands-definitions (cdr definitions) body)))))
(define (let*->nested-lets exp)
  (car (let*-expands-definitions (let-definitions exp) (let-body exp))))
(define (eval-let* exp env)
  (eval (let*->nested-lets exp) env))
(put 'op 'let* eval-let*)
; End exercie 4.7

; Start exercie 4.8
(define (let-named? exp)
  ;(not (pair? (cadr exp))))
  (symbol? (cadr exp)))
(define (let-make-inner-procedure name vars body)
  (append (list 'define
                (cons
                  name
                  (expand-let-variables vars)))
          body))
(define (let-named-name exp) (cadr exp))
(define (let-named-definitions exp) (caddr exp))
(define (let-named-body exp) (cdddr exp))
(define (let->combination-ex4.8 exp)
  (if (let-named? exp)
    (list (make-lambda '() (list (let-make-inner-procedure (let-named-name exp) (let-named-definitions exp) (let-named-body exp))
                                 (cons (let-named-name exp) (expand-let-values (caddr exp)))))
          )
    (cons (make-lambda (expand-let-variables (let-definitions exp)) (let-body exp))
          (expand-let-values (let-definitions exp)))))
(define let->combination let->combination-ex4.8)
; End exercie 4.8

; Start exercie 4.9

; We couldn't install this procedure to the primitive procedures as
; this procedure may used procedure
(define (for start end proc)
  (define (iter index end)
    (if (= index end)
      'for-end
      (begin (proc index)
             (iter (+ index 1) end))))
  (iter start end))

(define (for-start exp) (cadr exp))
(define (for-end exp) (caddr exp))
(define (for-proc exp) (cadddr exp))
(define (for->procedure-calls exp)
  (sequence->exp (list (list 'define '(iter index end) (make-if '(= index end) ''end (sequence->exp (list (list (for-proc exp) 'index)
                                                                                                          '(iter (+ index 1) end)))))
                       (list 'iter (for-start exp) (for-end exp)))))

(define (eval-for exp env)
  (eval (for->procedure-calls exp) env))
(put 'op 'for eval-for)
; End exercie 4.9

; Start exercie 4.10
; thw above exercise are examples. we not modfied eval/apply but added new grammer. We could also for example change the 
; procedure name in the last when call a procedure.
; or support list comprehension
; or support multi assignement such as: x, y = 1, 2
; End exercie 4.10


;;
;; End 4.1.2 Representing Expressions
;;


;;
;; Start 4.1.3 Evaluator Data Structures
;;
(define (true? x) (not (eq? x false)))
(define (false? x) (eq? x false))

(define (make-procedure parameters body env)
  (list 'procedure parameters body env))
(define (compound-procedure? p)
  (tagged-list? p 'procedure))
(define (procedure-parameters p) (cadr p))
(define (procedure-body p) (caddr p))
(define (procedure-environment p) (cadddr p))

(define (enclosing-enviroment env) (cdr env))
(define (first-frame env) (car env))
(define the-empty-environment '())

(define (make-frame variables values)
  (cons variables values))
(define (frame-variables frame) (car frame))
(define (frame-values frame) (cdr frame))
(define (add-binding-to-frame! var val frame)
  (set-car! frame (cons var (car frame)))
  (set-cdr! frame (cons val (cdr frame))))

(define (extend-environment vars vals base-env)
  (if (= (length vars) (length vals))
    (cons (make-frame vars vals) base-env)
    (if (< (length vars) (length vals))
      (error "Too manay arguments supplied" vars vals)
      (error "Too few arguments supplied" vars vals))))

(define (lookup-variable-value var env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
             (env-loop (enclosing-enviroment env)))
            ((eq? var (car vars)) (car vals))
            (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
      (error "Unbound variable" var)
      (let ((frame (first-frame env)))
        (scan (frame-variables frame)
              (frame-values frame)))))
  (env-loop env))

(define (set-variable-value! var val env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
             (env-loop (enclosing-enviroment env)))
            ((eq? var (car vars)) (set-car! vals val))
            (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
      (error "Unbound variable: SET!" var)
      (let ((frame (first-frame env)))
        (scan (frame-variables frame)
              (frame-values frame)))))
  (env-loop env))

(define (define-variable! var val env)
  (let ((frame (first-frame env)))
    (define (scan vars vals)
      (cond ((null? vars)
             (add-binding-to-frame! var val frame))
            ((eq? var (car vars)) (set-car! vals val))
            (else (scan (cdr vars) (cdr vals)))))
    (scan (frame-variables frame) (frame-values frame))))

; Start Exercise 4.11
(define (make-frame-ex4.11 variable values)
  (map cons variable values))

(define (frame-variables-ex4.11 frame) (map car frame))
(define (frame-values-ex4.11 frame) (map cadr frame))
(define (add-binding-to-frame-ex4.11! var val frame)
  (set-car! frame (cons (cons var val) (car frame))))

(define (extend-environment-ex4.11 vars vals base-env)
  (if (= (length vars) (length vals))
    (cons (make-frame-ex4.11 vars vals) base-env)
    (if (< (length vars) (length vals))
      (error "Too manay arguments supplied" vars vals)
      (error "Too few arguments supplied" vars vals))))

(define (lookup-variable-value-ex4.11 var env)
  (define (env-loop env)
    (define (scan bindings)
      (cond ((null? bindings)
             (env-loop (enclosing-enviroment env)))
            ((eq? var (caar bindings))
             (caadr bindings))
            (else (scan (cdr bindings)))))
    (if (eq? env the-empty-environment)
      (error "Unbound variable" var)
      (let ((frame (first-frame env)))
        (scan frame))))
  (env-loop env))

(define (set-variable-value-ex4.11! var val env)
  (define (env-loop env)
    (define (scan bindings)
      (cond ((null? bindings)
             (env-loop (enclosing-enviroment env)))
            ((eq? var (caar bindings))
             (set-cdr! (cadr bindings) val))
            (else (scan (cdr bindings)))))
    (if (eq? env the-empty-environment)
      (error "Unbound variable: SET!" var)
      (let ((frame (first-frame env)))
        (scan frame))))
  (env-loop env))

(define (define-variable-ex4.11! var val env)
  (let ((frame (first-frame env)))
    (define (scan bindings)
      (cond ((null? bindings)
             (add-binding-to-frame-ex4.11! var val frame))
            ((eq? var (caar bindings))
             (set-car! (car bindings) val))
            (else (scan (cdr bindings)))))
    (scan frame)))
; End Exercise 4.11

; Start Exercise 4.12

(define (scan-varval-pairs vars vals var)
  (cond ((null? vars)
         '())
        ((eq? var (car vars)) vals)
        (else (scan-varval-pairs (cdr vars) (cdr vals) var))))

(define (scan-env env var)
  (if (eq? env the-empty-environment)
    (error "Unbound variable" var)
    (let* ((frame (first-frame env))
           (val (scan-varval-pairs (frame-variables frame)
                                   (frame-values frame) var)))
      (if (null? val)
        (scan-env (enclosing-enviroment env) var)
        val))))

(define (lookup-variable-value-ex4.12 var env)
  (let ((vals (scan-env env var)))
    (car vals)))

(define (set-variable-value-ex4.12! var val env)
  (let ((vals (scan-env env var)))
    (set-car! vals val)))

(define (define-variable-ex4.12! var val env)
  (let* ((frame (first-frame env))
         (vals (scan-varval-pairs (frame-variables frame)
                                 (frame-values frame) var)))
    (if (null? vals)
        (add-binding-to-frame! var val frame)
        (set-car! vals val))))
; End Exercise 4.12

; Start Exercise 4.13
; Easy...
; End Exercise 4.13

;;
;; end 4.1.3  evaluator data structures
;;


;;
;; Start 4.1.4 Running the Evaluator as a Program
;;

(define primitive-procedures
  (list (list 'car car)
        (list 'cdr cdr)
        (list 'cons cons)
        (list 'list list)
        (list '+ +)
        (list '- -)
        (list '* *)
        (list '/ /)
        (list '= =)
        (list 'eq? eq?)
        (list 'assoc assoc)
        (list 'display display)
        (list 'newline newline)
        (list 'null? null?)))
(define (primitive-procedure-names)
  (map car primitive-procedures))
(define (primitive-procedure-objecs)
  (map (lambda (proc) (list 'primitive (cadr proc)))
       primitive-procedures))

(define (setup-environment)
  (let ((initial-env
          (extend-environment (primitive-procedure-names)
                              (primitive-procedure-objecs)
                              the-empty-environment)))
    (define-variable! 'true true initial-env)
    (define-variable! 'false false initial-env)
    initial-env))
;(define the-global-environment (setup-environment))

(define (primitive-procedure? proc)
  (tagged-list? proc 'primitive))
(define (primitive-implementation proc) (cadr proc))

(define (apply-primitive-procedure proc args)
  (apply-in-underlying-scheme
    (primitive-implementation proc) args))

(define input-prompt  ";;; M-Eval input:")
(define output-prompt ";;; M-Eval value:")
(define (driver-loop)
  (prompt-for-input input-prompt)
  (let ((input (read)))
    (if (eof-object? input)
      (exit)
      (pretty-print input))
    (let ((output (eval input the-global-environment)))
      ; as I often read from file, so print the input content from file.
      (announce-output output-prompt)
      (user-print output)))
  (driver-loop))

(define (prompt-for-input string)
  (newline) (newline) (display string) (newline))
(define (announce-output string)
  (newline) (display string) (newline))

(define (user-print object)
  (if (compound-procedure? object)
    (display (list 'compound-procedure
                   (procedure-parameters object)
                   (procedure-body object)
                   '<procedure-env>))
    (display object)))

(define the-global-environment (setup-environment))
;(driver-loop)

; Start Exercise 4.14
; Becase the map use the system functon but not out implemented apply
; End Exercise 4.14

;;
;; end 4.1.4  Running the Evaluator as a Program
;;


;;;
;;; Start 4.1.5 Data as Programs
;;;

(define (factorial n)
  (if (= n 1) 1 (* (factorial (- n 1) ) n)))


;(eval-in-underlying-scheme '(* 5 5) user-initial-environment)
;(eval-in-underlying-scheme (cons '* (list 5 5)) user-initial-environment)

; Start Exercise 4.15
; if the evaluating halting, then the "try" is halts, then the program should (run-forever). this is a paradox
; if the evaluating running forever, then th e"try" is not halted, then the program should ('halted), this is also a paradox
; End Exercise 4.15

;;;
;;; End 4.1.5 Data as Programs
;;;

;;
;; Start 4.1.6 Internal Definitions
;;
(define (f x)
  (define (even n) (if (= n 0) true (odd (- n 1))))
  (define (odd n) (if (= n 0) false (even (- n 1))))
  (even x))

;(display-line (f 11))


; Start Exercise 4.16
;a
(define (lookup-variable-value-4.16a var env)
  (define (env-loop env)
    (define (scan vars vals)
      (cond ((null? vars)
             (env-loop (enclosing-enviroment env)))
            ((eq? var (car vars)) (car vals))
            (else (scan (cdr vars) (cdr vals)))))
    (if (eq? env the-empty-environment)
      (error "Unbound variable" var)
      (let ((frame (first-frame env)))
        (scan (frame-variables frame)
              (frame-values frame)))))
  (let ((value (env-loop env)))
    (if (eq? value '*unassigned*)
      (error "Unassigned varable: *unassigned*")
      value)))
(define lookup-variable-value lookup-variable-value-4.16a)
;b
(define (split-body-out-defines body)
  (if (null? body)
    (let ((defines '())
          (others  '()))
      (cons defines others))
    (let ((exp (car body))
          (rest (split-body-out-defines (cdr body))))
      (if (definition? exp)
        (cons (cons exp (car rest)) (cdr rest))
        (cons (car rest) (cons exp (cdr rest)))))))
(define (defines->let-defines-body defines)
  (if (null? defines)
    (let ((let-defines '())
          (let-body    '()))
      (cons let-defines let-body))
    (let* ((rest-let-defines-body (defines->let-defines-body (cdr defines)))
           (rest-defines (car rest-let-defines-body))
           (rest-body    (cdr rest-let-defines-body))
           (name  (definition-variable (car defines)))
           (value (definition-value    (car defines)))
           (current-define (list name ''*unassigned*))
           (current-body   (list 'set! name value)))
      (cons (cons current-define rest-defines)
            (cons current-body   rest-body)))))
(define (scan-out-defines procedure-body)
  (let* ((splited-body (split-body-out-defines procedure-body))
         (defines (car splited-body))
         (others  (cdr splited-body))
         (let-defines-body (defines->let-defines-body defines)))
    (list (append (list 'let
                        (car let-defines-body))
                  (append (cdr let-defines-body)
                          others)))))
;c
(define (contain-defines exps)
  (if (null? exps)
    false
    (or (if (definition? (car exps))
          true
          false)
        (contain-defines (cdr exps)))))
(define (make-procedure-ex4.16 parameters body env)
  (if (contain-defines body)
    (list 'procedure parameters (scan-out-defines body) env)
    (list 'procedure parameters body env)))
;(define make-procedure make-procedure-ex4.16)
; Install scan-out-defines in the make-procedure is better, the call number is less
; end Exercise 4.16

; Start Exercise 4.17
; 1. Because create a let expression, the let expression has a frame
; 2. What we do is just assigne the defined variables to *unassigned*, it will never make a difference in the behavior of a correct program
; 3. We can put the "definition" in the last of the statements
; end Exercise 4.17

; Start Exercise 4.18
; 1. This procedure will not work if internal definitions are scanned out as shown in this exercise. Because when execute the set! the y and dy is not initialed
; 2. same if they are scanned out as shown in the text
; end Exercise 4.18

; Start Exercise 4.19
; lazy evaluation
; end Exercise 4.19

; Start Exercise 4.20
(define (let-define-pair-var pair)
  (car pair))
(define (let-define-pair-val pair)
  (cadr pair))
(define (let-varval-definition-define pair)
  (list (let-define-pair-var pair) ''*unassigned*))
(define (let-varval-definition-assignment pair)
  (list 'set!
        (let-define-pair-var pair)
        (let-define-pair-val pair)))
(define (letrec-definitions let-varval-definitions)
  (map let-varval-definition-define let-varval-definitions))
(define (letrec-assignments let-varval-definitions)
  (map let-varval-definition-assignment let-varval-definitions))
(define (make-let defines body)
  (append (list 'let
                defines)
          body))
(define (letrec->let exp)
  (define definitions (let-definitions exp))
  (let ((defines (letrec-definitions definitions))
        (assignments (letrec-assignments definitions)))
    (make-let defines (append assignments (let-body exp)))))

(define expr '(letrec ((<var1> <exp1>)
                      (<var2> <exp2>)
                      (<var3> <exp3>))
               <sta1>
               <sta2>
               <sta3>))
;(pretty-print expr)
;(pretty-print (letrec-definitions (let-definitions expr)))
;(pretty-print (letrec-assignments (let-definitions expr)))
;(pretty-print (letrec->let expr))
(define (eval-letrec exp env)
  (pretty-print (letrec->let exp))
  (eval (letrec->let exp) env))
(put 'op 'letrec eval-letrec)
; end Exercise 4.20

; Start Exercise 4.21
; a
;(display-line
;  ((lambda (n)
;     ((lambda (fact) (fact fact n))
;      (lambda (ft k) (if (= k 1) 1 (* k (ft ft (- k 1)))))))
;   10))
(define (fib n)
  ((lambda (fib-iter) (fib-iter fib-iter 0 1 n))
   (lambda (ft a b count)
     (if (= count 0)
       a
       (ft ft b (+ a b) (- count 1))))))

;(display-line (fib 10))

; b
; the trick is the parameter of the inner lambda expression is it self! So when it want to call it self recursivly, just need pass the 
; same parameter(it self) to the its self's next call. And when we inital call: we pass the inner lambda as parameter to it self
(define (f x)
  ((lambda (even? odd?) (even? even? odd? x))
   (lambda (ev? od? n)
     (if (= n 0) true (od? ev? od? (- n 1))))
   (lambda (ev? od? n)
     (if (= n 0) false (ev? ev? od? (- n 1))))))
;(display-line (f 10))
;(display-line (f 11))
;(display-line (f 12))
;(display-line (f 13))
; end Exercise 4.21

;;
;; End 4.1.6 Internal Definitions
;;


;;
;; Start 4.1.7 Separating Syntactic Analysis from Execution
;;

(define (eval-4.1.7 exp env) ((analyze exp) env))
(define (analyze exp)
  (cond ((self-evaluating? exp) (analyze-self-evaluating exp))
        ((quoted? exp) (analyze-quoted exp))
        ((variable? exp) (analyze-variable exp))
        ((assignment? exp) (analyze-assignment exp))
        ((definition? exp) (analyze-definition exp))
        ((if? exp) (analyze-if exp))
        ((let? exp) (analyze (let->combination exp)))
        ((let*? exp) (analyze (let*->nested-lets exp)))
        ((letrec? exp) (analyze (letrec->let exp)))
        ((for? exp) (analyze (for->procedure-calls exp)))
        ((unless? exp) (analyze (unless->if exp)))
        ((lambda? exp) (analyze-lambda exp))
        ((begin? exp) (analyze-sequence (begin-actions exp)))
        ((cond? exp) (analyze (cond->if exp)))
        ((application? exp) (analyze-application exp))
        (else (error "Unknow expression type: ANALYZE" exp))))

(define (analyze-self-evaluating exp)
  (lambda (env) exp))
(define (analyze-quoted exp)
  (let ((qval (text-of-quotation exp)))
    (lambda (env) qval)))
(define (analyze-variable exp)
  (lambda (env) (lookup-variable-value exp env)))
(define (analyze-assignment exp)
  (let ((var (assignment-variable exp))
        (vproc (analyze (assignment-value exp))))
    (lambda (env)
      (set-variable-value! var (vproc env) env)
      'ok)))
(define (analyze-definition exp)
  (let ((var (definition-variable exp))
        (vproc (analyze (definition-value exp))))
    (lambda (env)
      (define-variable! var (vproc env) env)
      'ok)))
(define (analyze-if exp)
  (let ((pproc (analyze (if-predicate exp)))
        (cproc (analyze (if-consequent exp)))
        (aproc (analyze (if-alternative exp))))
    (lambda (env) (if (true? (pproc env))
                    (cproc env)
                    (aproc env)))))
(define (analyze-lambda exp)
  (let ((vars (lambda-parameters exp))
        (bproc (analyze-sequence (lambda-body exp))))
    (lambda (env) (make-procedure vars bproc env))))
(define (analyze-sequence exps)
  (define (sequentially proc1 proc2)
    (lambda (env) (proc1 env) (proc2 env)))
  (define (loop first-proc rest-procs)
    (if (null? rest-procs)
      first-proc
      (loop (sequentially first-proc (car rest-procs))
            (cdr rest-procs))))
  (let ((procs (map analyze exps)))
    (if (null? procs) (error "Empty sequence: ANALYZE"))
    (loop (car procs) (cdr procs))))
(define (analyze-application exp)
  (let ((fproc (analyze (operator exp)))
        (aprocs (map analyze (operands exp))))
    (lambda (env)
      (execute-application
        (fproc env)
        (map (lambda (aproc) (aproc env))
             aprocs)))))
(define (execute-application proc args)
  (cond ((primitive-procedure? proc)
         (apply-primitive-procedure proc args))
        ((compound-procedure? proc)
         ((procedure-body proc)
          (extend-environment
            (procedure-parameters proc)
            args
            (procedure-environment proc))))
        (else
          (error "Unknown procedure type: EXECUTE-APPLICATION"
                 proc))))

; Start Exercise 4.22
(define (let? exp) (tagged-list? exp 'let))
; end Exercise 4.22

(define (let*? exp) (tagged-list? exp 'let*))
(define (letrec? exp) (tagged-list? exp 'letrec))
(define (for? exp) (tagged-list? exp 'for))
; to make the new eval, the make-procedure-ex4.16 is commentted as now it cannot get the body text of lambda expression
(define eval eval-4.1.7)

; Start Exercise 4.23
(define (analyze-sequence-4.23 exps)
  (define (execute-sequence procs env)
    (cond ((null? (cdr procs))
           ((car procs) env))
          (else
            ((car procs) env)
             (execute-sequence (cdr procs) env))))
  (let ((procs (map analyze exps)))
    (if (null? procs)
      (error "Empty sequence: ANALYZE")
      (lambda (env)
        (execute-sequence procs env)))))
;(define analyze-sequence analyze-sequence-4.23)
; the results shoulb be same, but the version of text is more efficient.
; Alyssa's version is run the "cond", recusively" in the runtime, the version of text unrolls the procedure
; end Exercise 4.23

; Start Exercise 4.24
; when perform a loop of 30000
; original eval: 6s
; analyze + eval: 3.5s
; end Exercise 4.24

;;
;; end 4.1.7 Separating Syntactic Analysis from Execution
;;


;;
;; start 4.2 Variations on a Scheme - Lazy Evaluation
;;

;;
;; start 4.2.1 Normal Ordr and Applicative Order
;;

; start Exercise 4.25
(define (unless condition usual-value exceptional-value)
  (if condition exceptional-value usual-value))
(define (factorial n)
  (unless (= n 1)
    (* n (factorial (- n 1)))
    1))
; will go into forever loop, will work in normal order
; end Exercise 4.25

; start Exercise 4.26
(define (unless? exp) (tagged-list? exp 'unless))
(define (unless-condition exp) (cadr exp))
(define (unless-usual-value exp) (caddr exp))
(define (unless-exceptional-value exp) (cadddr exp))
(define (unless->if exp)
  (make-if (unless-condition exp)
           (unless-exceptional-value exp)
           (unless-usual-value exp)))
; when we want to pass unless to onother procedure such as map,
; then if unless is a procedure we can do it easily but can't if it is a special form

(define (eval-unless exp env)
  (eval (unless->if exp) env))
; end Exercise 4.26

;;
;; end 4.2.1 Normal Ordr and Applicative Order
;;


;;
;; start 4.2.2 An Interpreter with Lazy Evaluation
;;
(define (eval-4.2.2-lazy-evaluation exp env)
  (cond ((self-evaluating? exp) exp)
        ((variable? exp) (lookup-variable-value exp env))
        ((quoted? exp) (text-of-quotation exp))
        ((assignment? exp) (eval-assignment exp env))
        ((definition? exp) (eval-definition exp env))
        ((if? exp) (eval-if exp env))
        ((let? exp) (eval-let exp env))
        ((let*? exp) (eval-let* exp env))
        ((letrec? exp) (eval-letrec exp env))
        ((for? exp) (eval-for exp env))
        ((unless? exp) (eval-unless exp env))
        ((lambda? exp) (make-procedure (lambda-parameters exp)
                                       (lambda-body exp)
                                       env))
        ((begin? exp)
         (eval-sequence (begin-actions exp) env))
        ((cond? exp) (eval (cond->if exp) env))
        ((application? exp)
          (apply (actual-value (operator exp) env)
                 (operands exp)
                 env))                                            ; changed
        (else
          (error "Unknow expression type: EVAL" exp))))

(define (actual-value exp env)
  (force-it (eval exp env)))

(define (apply-4.22-lazy-evaluation procedure arguments env)
  (cond ((primitive-procedure? procedure)
         (apply-primitive-procedure
           procedure
           (list-of-arg-values arguments env)))                   ; changed
        ((compound-procedure? procedure)
         (eval-sequence
           (procedure-body procedure)
           (extend-environment
             (procedure-parameters procedure)
             (list-of-delayed-args arguments env)
             (procedure-environment procedure))))                 ; changed
        (else (error "Unknow procedure type: APPLY"
                     procedure))))

(define (list-of-arg-values exps env)
  (if (no-operands? exps)
    '()
    (cons (actual-value (first-operand exps)
                        env)
          (list-of-arg-values (rest-operands exps)
                              env))))
(define (list-of-delayed-args exps env)
  (if (no-operands? exps)
    '()
    (cons (delay-it (first-operand exps)
                    env)
          (list-of-delayed-args (rest-operands exps)
                                env))))

(define (eval-if exp env)
  (if (true? (actual-value (if-predicate exp) env))
    (eval (if-consequent exp) env)
    (eval (if-alternative exp) env)))

(define (driver-loop)
  (prompt-for-input input-prompt)
  (let ((input (read)))
    (if (eof-object? input)
      (exit)
      (pretty-print input))
    (let ((output (actual-value input the-global-environment)))
      ; as I often read from file, so print the input content from file.
      (announce-output output-prompt)
      (user-print output)))
  (driver-loop))


(define (force-it obj)
  (if (thunk? obj)
    (actual-value (thunk-exp obj) (thunk-env obj))
    obj))
(define (delay-it exp env)
  (list 'thunk exp env))
(define (thunk? obj)
  (tagged-list? obj 'thunk))
(define (thunk-exp thunk) (cadr thunk))
(define (thunk-env thunk) (caddr thunk))

; Memoized the thunk
(define (evaluated-thunk? obj)
  (tagged-list? obj 'evaluated-thunk))
(define (thunk-value evaluated-thunk)
  (cadr evaluated-thunk))
(define (force-it-memoized obj)
  (cond ((thunk? obj)
         (let ((result (actual-value (thunk-exp obj)
                                     (thunk-env obj))))
           (set-car! obj 'evaluated-thunk)
           (set-car! (cdr obj)
                     result)       ; replace exp with its value
           (set-cdr! (cdr obj)
                     '())
           result))
        ((evaluated-thunk? obj) (thunk-value obj))
        (else obj)))       ; forget unneeded env
(define force-it force-it-memoized)

(define eval eval-4.2.2-lazy-evaluation)
(define apply apply-4.22-lazy-evaluation)

; start Exercise 4.27
;(define count 0)
;(define (id x) (set! count (+ count 1)) x)

;(define w (id (id 10)))

;count
;; <response> is 1 because the parameter of first id call "(id 10)" is delayed, then the count only inc 1

;w
;; <responise> is 10, and the delayed parameter was forced to eval, now count inc 1

;count
;; <respoinse> is 2

; end Exercise 4.27

; start Exercise 4.28
; if we don't force, then when use this paramter, the parameter's type is thunk, will be get error for the incorrect type
; end Exercise 4.28

; start Exercise 4.29
;(define count 0)
;(define (square x) (* x x))
;(square (id 10))
;; <response> is 100
;count
;; <response> is 1 if memoized else 2

;; if the id function is expensive function then the no-memoizatoin version will slow than the memoized one
; end Exercise 4.29

; start Exercise 4.30
; a
; because the parameter have been used by display
; b
;(define (p1 x)
;  (set! x (cons x '(2)))
;  x)
;(define (p2 x)
;  (define (p e)
;    e
;    x)
;  (p (set! x (cons x '(2)))))
; (p1 1) will return (1 2) (p2 1) will return 1,
; c
; d
; I prefer the approach in the text

; end Exercise 4.30

; start Exercise 4.31
(define (procedure-parameters-ex4.31 p)
  (define (name parameter)
    (if (pair? parameter)
      (car parameter)
      parameter))
  (define (parameter-names parameters)
    (if (null? parameters)
      '()
      (cons (name (car parameters))
            (parameter-names (cdr parameters)))))
  (parameter-names (cadr p)))
(define (procedure-raw-parameters p) (cadr p))

(define (apply-ex4.31 procedure arguments env)
  (cond ((primitive-procedure? procedure)
         (apply-primitive-procedure
           procedure
           (list-of-arg-values arguments env)))                   ; changed
        ((compound-procedure? procedure)
         (eval-sequence
           (procedure-body procedure)
           (extend-environment
             (procedure-parameters procedure)
             (list-of-delayed-args (procedure-raw-parameters procedure) arguments env)
             (procedure-environment procedure))))                 ; changed
        (else (error "Unknow procedure type: APPLY"
                     procedure))))

(define (list-of-delayed-args-ex4.31 raw_parameters exps env)
  (define (arg-value raw_parameter exp)
    (if (pair? raw_parameter)
      (cond ((eq? (cadr raw_parameter) 'lazy)
             (delay-it-no-memo exp env))
            ((eq? (cadr raw_parameter) 'lazy-memo)
             (delay-it exp env))
            (else (error "Unknow parameter type LIST-OF-DELAYED-ARGS:" (cadr raw_parameter))))
      (actual-value exp env)))
  (if (no-operands? exps)
    '()
    (cons (arg-value (car raw_parameters)
                     (first-operand exps))
          (list-of-delayed-args-ex4.31 (cdr raw_parameters)
                                (rest-operands exps)
                                env))))

(define (delay-it-no-memo exp env)
  (list 'thunk-no-memo exp env))
(define (thunk-no-memo? obj)
  (tagged-list? obj 'thunk-no-memo))

(define (force-it-ex4.31 obj)
  (cond ((thunk? obj)
         (let ((result (actual-value (thunk-exp obj)
                                     (thunk-env obj))))
           (set-car! obj 'evaluated-thunk)
           (set-car! (cdr obj)
                     result)       ; replace exp with its value
           (set-cdr! (cdr obj)
                     '())
           result))
        ((evaluated-thunk? obj) (thunk-value obj))
        ((thunk-no-memo? obj) (actual-value (thunk-exp obj)
                                            (thunk-env obj)))
        (else obj)))       ; forget unneeded env


;(define apply apply-ex4.31)
;(define force-it force-it-ex4.31)
;(define procedure-parameters procedure-parameters-ex4.31)
;(define list-of-delayed-args list-of-delayed-args-ex4.31)
; end Exercise 4.31

;;
;; end 4.2.2 An Interpreter with Lazy Ecaluation
;;

;;
;; start 4.2.3 Streams as Lazy Lists
;;

; start Exercise 4.32
; (cons a b) will not eval a but (cons-stream) in mit-scheme will
; from the text of book: The car of the list, as well as the cdr, is delayed. This permits us to create delayed versions of more general kinds of list structures,
; not just sequences. Hughes 1990 discuesses some application of "lazy trees".
; end Exercise 4.32

; start Exercise 4.33
(define (text-of-quotation-lazy exp)
  (define (quotation->cons exp)
    (if (null? exp)
      ''()
      (if (pair? exp)
        (list 'cons (quotation->cons (car exp)) (quotation->cons (cdr exp)))
        `',exp)))
  (let ((env (cons (make-frame '() '()) '())))
    (eval '(define (cons x y) (lambda (m) (m x y))) env)
    (eval '(define (car z) (z (lambda (p q) p))) env)
    (eval '(define (cdr z) (z (lambda (p q) q))) env)
    (let ((text (cadr exp)))
      (if (pair? text)
        (eval (quotation->cons text) env)
        text))))
; if do so, all of the cons will be the lazy one even if there are already have been defined
;(define text-of-quotation text-of-quotation-lazy)

  ;(eval (quotation->cons (cadr exp)) env))
; end Exercise 4.33

; start Exercise 4.34
; end Exercise 4.34

;;
;; end 4.2.3 Streams as Lazy Lists
;;


;;
;; end 4.2 Variations on a Scheme - Lazy Evaluation
;;



;(driver-loop)
