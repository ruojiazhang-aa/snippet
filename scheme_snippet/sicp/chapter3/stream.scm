
;; definition
(define the-empty-stream '())
(define stream-null? null?)

(define (memo-proc proc)
  (let ((already-run? #f) (result #f))
    (lambda ()
      (if (not already-run?)
        (begin (set! result (proc))
               (set! already-run? #t)
               result)
        result))))

;(define (delay exp)
  ;(memo-proc (lambda () exp)))


;(define (force delayed-object) (delayed-object))

;(define (cons-stream a b)
  ;(cons a (delay b)))

(define (stream-car stream) (car stream))
(define (stream-cdr stream) (force (cdr stream)))



;; util functions 
(define (stream-ref s n)
  (if (= n 0)
    (stream-car s)
    (stream-ref (stream-cdr s) (- n 1))))

(define (stream-take s n)
  (if (= n 0)
    '()
    (cons (stream-car s) (stream-take (stream-cdr s) (- n 1)))))

(define (stream-slice s n)
  (if (= n 0)
    '()
    (cons-stream (stream-car s) (stream-slice (stream-cdr s) (- n 1)))))

(define (stream-map proc s)
  (if (stream-null? s)
    the-empty-stream
    (cons-stream (proc (stream-car s))
                 (stream-map proc (stream-cdr s)))))

(define (stream-for-each proc s)
  (if (stream-null? s)
    'done
    (begin (proc (stream-car s))
           (stream-for-each proc (stream-cdr s)))))
(define (stream-filter pred stream)

  (cond ((stream-null? stream) the-empty-stream)
        ((pred (stream-car stream))
         (cons-stream (stream-car stream)
                      (stream-filter
                        pred
                        (stream-cdr stream))))
        (else (stream-filter pred (stream-cdr stream)))))

(define (stream-map proc . argstreams)
  (if (stream-null? (car argstreams))
    the-empty-stream
    (cons-stream
      (apply proc (map stream-car argstreams))
      (apply stream-map
             (cons proc (map stream-cdr argstreams))))))

(define (display-stream s)
  (stream-for-each display-line s))
(define (display-line x) (newline) (display x))

(define (display-stream10 s)
  (display-stream (stream-slice s 10)))
(define (display-stream20 s)
  (display-stream (stream-slice s 20)))
(define (display-stream30 s)
  (display-stream (stream-slice s 30)))

(define (stream-enumerate-interval low high)
  (if (> low high)
    the-empty-stream
    (cons-stream
      low
      (stream-enumerate-interval (+ low 1) high))))


;; ex 3.51
#|
(define (show x)
  (display-line x)
  x)

(define x
  (stream-map show
              (stream-enumerate-interval 0 10)))

(display "stream-ref x 5")
(stream-ref x 5)
(display "stream-ref x 7")
(stream-ref x 7)
|#
;; end ex 3.51

;; ex 3.52
(define sum 0)
;(display-line sum)
(define (accum x) (set! sum (+ x sum)) sum)
;(display-line sum)
(define seq
  (stream-map accum
              (stream-enumerate-interval 1 20)))
;(display-line sum)
(define y (stream-filter even? seq))
;(display-line sum)
(define z
  (stream-filter (lambda (x) (= (remainder x 5) 0))
                 seq))
;(display-line sum)
(stream-ref y 7)
;(display-line sum)
;(display-stream z)
;; end ex 3.52


(define (integers-starting-from n)
  (cons-stream n (integers-starting-from (+ n 1))))
(define integers (integers-starting-from 1))
(define (divisible? x y) (= (remainder x y) 0))
(define (sieve stream)
  (cons-stream
    (stream-car stream)
    (sieve (stream-filter
             (lambda (x)
               (not (divisible? x (stream-car stream))))
             (stream-cdr stream)))))
(define primes (sieve (integers-starting-from 2)))

(define ones (cons-stream 1 ones))
(define (add-streams s1 s2) (stream-map + s1 s2))
(define integers
  (cons-stream 1 (add-streams ones integers)))

(define (scale-stream stream factor)
  (stream-map (lambda (x) (* x factor))
              stream))

(define double (cons-stream 1 (scale-stream double 2)))

;(display-line (stream-ref double 10))

(define primes
  (cons-stream
    2
    (stream-filter prime? (integers-starting-from 3))))

(define (prime? n)jk
  (define (iter ps)
    (cond ((> (square (stream-car ps)) n) #t)
          ((divisible? n (stream-car ps)) #f)
          (else (iter (stream-cdr ps)))))
  (iter primes))

;(display-line (stream-take primes 3))


; ex 3.54
(define (mul-streams s1 s2) (stream-map * s1 s2))

; factorails count from 0
(define factorials
  (cons-stream 1 (mul-streams factorials integers)))

;(display (stream-take factorials 10))

; end ex 3.54
; ex 3.55
(define (partial-sums s)
  (add-streams s (cons-stream 0 (partial-sums s))))

;(display-line (stream-take integers 10))
;(display-line (stream-take (partial-sums integers) 10))


; ex 3.56
; merge that combines two ordered streams into one ordered result stream, eliminating repetitions:
(define (merge s1 s2)
  (cond ((stream-null? s1) s2)
        ((stream-null? s2) s1)
        (else
          (let ((s1car (stream-car s1))
                (s2car (stream-car s2)))
            (cond ((< s1car s2car)
                   (cons-stream
                     s1car
                     (merge (stream-cdr s1) s2)))
                  ((> s1car s2car)
                   (cons-stream
                     s2car
                     (merge s1 (stream-cdr s2))))
                  (else
                    (cons-stream
                      s1car
                      (merge (stream-cdr s1)
                             (stream-cdr s2)))))))))

(define S (cons-stream 1 (merge (scale-stream S 2) (merge (scale-stream S 3) (scale-stream S 5)))))

;(display-line (stream-take S 10))
; end ex 3.56


; ex 3.58
(define (expand num den radix)
  (cons-stream
    (quotient (* num radix) den)
    (expand (remainder (* num radix) den) den radix)))
;(display-line (stream-take (expand 1 7 10) 10))
;(display-line (stream-take (expand 3 8 10) 10))
; end ex 3.58

;; ex 3.59
(define (integrate-series s)
  (stream-map (lambda (x y) (* x (/ 1 y))) s integers))

(define exp-series
  (cons-stream 1 (integrate-series exp-series)))

;(display-line (stream-take exp-series 10))
(define cosine-series (cons-stream 1 (scale-stream (integrate-series sine-series) -1)))
(define sine-series (cons-stream 0 (integrate-series cosine-series)))

;(display-line (stream-take cosine-series 10))
;(display-line (stream-take sine-series 10))
;; end ex 3.59

;; ex 3.60
(define (mul-series s1 s2)
  (cons-stream
    (* (stream-car s1) (stream-car s2))
    (add-streams (add-streams (scale-stream (stream-cdr s1) (stream-car s2)) 
                              (scale-stream (stream-cdr s2) (stream-car s1)))
                 (cons-stream 0 (mul-series (stream-cdr s1) (stream-cdr s2))))))

; A shorter version:
(define (mul-series s1 s2)
  (cons-stream (* (stream-car s1) (stream-car s2))
               (add-streams (scale-stream (stream-cdr s2) (stream-car s1))
                            (mul-series (stream-cdr s1) s2))))

(define S (add-streams (mul-series sine-series sine-series) (mul-series cosine-series cosine-series)))
;(display-line (stream-take S 10))
;; end ex 3.60

;; ex 3.61
(define (invert-unit-series s)
  (define x
    (cons-stream 1 (scale-stream (mul-series (stream-cdr s) x) -1)))
  x)

; bellow version is not memorized
;(define (invert-unit-series s)
    ;(cons-stream 1 (scale-stream (mul-series (stream-cdr s) (invert-unit-series s)) -1)))
;; end ex 3.61

;; ex 3.62

(define (div-series s1 s2)
  (mul-series s1 (invert-unit-series s2)))
(define tangent (div-series sine-series cosine-series))
;(display-line (stream-take tangent 10))
;; end ex 3.62

(define (average a b)
  (/ (+ a b) 2))

(define (sqrt-improve guess x)
  (average guess (/ x guess)))

(define (sqrt-stream x)
  (define guesses
    (cons-stream
      1.0
      (stream-map (lambda (guess) (sqrt-improve guess x))
                  guesses)))
  guesses)

;(display-stream (stream-slice (sqrt-stream 2) 10))


(define (pi-summands n)
  (cons-stream (/ 1.0 n)
               (stream-map - (pi-summands (+ n 2)))))

(define pi-stream
  (scale-stream (partial-sums (pi-summands 1)) 4))

;(display-stream (stream-slice pi-stream 10))

(define (euler-transform s)
  (let ((s0 (stream-ref s 0))
        (s1 (stream-ref s 1))
        (s2 (stream-ref s 2)))
    (cons-stream (- s2 (/ (square (- s2 s1))
                          (+ s0 (* s1 -2) s2)))
                 (euler-transform (stream-cdr s)))))

;(display-stream (stream-slice (euler-transform pi-stream) 10))




; Infinite streams of pairs

(define (interleave s1 s2)
  (if (stream-null? s1)
    s2
    (cons-stream (stream-car s1)
                 (interleave s2 (stream-cdr s1)))))


(define (pairs s t)
  (cons-stream
    (list (stream-car s) (stream-car t))
    (interleave
      (stream-map (lambda (x) (list (stream-car s) x))
                  (stream-cdr t))
      (pairs (stream-cdr s) (stream-cdr t)))))

(define naturenumbers
  (cons-stream 0 (add-streams ones naturenumbers)))

;(display-stream (stream-slice (pairs naturenumbers naturenumbers) 30))

; end of Infinite streams of pairs


; Exercise 3.67
(define (rect_pair s t)
  (cons-stream
    (list (stream-car s) (stream-car t))
    (interleave
      (interleave
        (stream-map (lambda (x) (list (stream-car s) x))
                    (stream-cdr t))
        (stream-map (lambda (x) (list x (stream-car s)))
                    (stream-cdr t)))
      (rect_pair (stream-cdr s) (stream-cdr t)))))

;(display-stream (stream-slice (rect_pair naturenumbers naturenumbers) 30))



; ex 3.68: Louis Reasouner thinks that building a stream of pair from three parts is unnecessarily complicated.
; Instead of separating the pair(S0, T0) from the rest of the pairs in the first row, he proposes to work with
; the whole first row, as follows:
(define (pairs-ex3.68 s t)
  (interleave
    (stream-map (lambda (x) (list (stream-car s) x))
                t)
    (pairs-ex3.68 (stream-cdr s) (stream-cdr t))))
; Does this work? Consider what happens if we evaluate (pairs integers integers) using Louis's definition of pairs. 

;(display-stream30 (pairs-ex3.68 integers integers))
; answer: This will lead to infinite recursion


; Exercise 3.69

(define (triples s t u)
  (cons-stream
    (list (stream-car s) (stream-car t) (stream-car u))
    (interleave
      (stream-map (lambda (x) (list (stream-car s) (car x) (car (cdr x))))
                  (stream-cdr (pairs t u)))
      (triples (stream-cdr s) (stream-cdr t) (stream-cdr u))))
  )

;(display-stream30 (triples integers integers integers))

(define (pythagorean-tripes)
  (define (square x) (* x x))
  (stream-filter (lambda (x)
                   (= (+ (square (car x)) (square (cadr x))) (square (caddr x))))
                 (triples integers integers integers)))

;(display-line "pythagorean-tripes:")

;(display-stream (stream-slice (pythagorean-tripes) 3))

; end exercise 3.69


; exercise 3.70

; merge that combines two streams into one ordered result stream acooding with the weighting function:
(define (merge_weighted s1 s2 weighting)
  (cond ((stream-null? s1) s2)
        ((stream-null? s2) s1)
        (else
          (let ((s1car (stream-car s1))
                (s2car (stream-car s2))
                (s1weight (weighting (stream-car s1)))
                (s2weight (weighting (stream-car s2))))
            (cond ((< s1weight s2weight)
                   (cons-stream
                     s1car
                     (merge_weighted (stream-cdr s1) s2 weighting)))
                  ((> s1weight s2weight)
                   (cons-stream
                     s2car
                     (merge_weighted s1 (stream-cdr s2) weighting)))
                  (else
                    (cons-stream
                      s1car
                      (merge_weighted
                        (stream-cdr s1)
                        s2
                        weighting))))))))

(define (weighted-pair s t weighting)
  (cons-stream
    (list (stream-car s) (stream-car t))
    (merge_weighted
      (stream-map (lambda (x) (list (stream-car s) x))
                  (stream-cdr t))
      (weighted-pair (stream-cdr s) (stream-cdr t) weighting)
      weighting)))

;(display-stream30 (weighted-pair integers integers (lambda (x) (+ (car x) (cadr x)))))

(define _235stream
  (let ((weight (lambda (x)
                  (let ((i (car x))
                        (j (cadr x)))
                    (+ (* 2 i) (* 3 j) (* 5 i j)))))
        (divide235 (lambda (x)
                     (or (= 0 (modulo x 2)) (= 0 (modulo x 3)) (= 0 (modulo x 5))))))
    (stream-filter (lambda (x)
                     (not (or (divide235 (car x)) (divide235 (cadr x)))))
                   (weighted-pair integers integers weight))))
;(display-stream30 _235stream)

; end exercise 3.70

; Exercise 3.71
(define cubes
  (weighted-pair integers integers (lambda (x)
                                     (let ((i (car x))
                                           (j (cadr x)))
                                       (+ (* i i i) (* j j j))))))

; Actually we don't need use the stream-zip as we can use the genral stream-map procedure
(define (stream-zip s t)
  (cons-stream (cons (stream-car s) (stream-car t))
               (stream-zip (stream-cdr s) (stream-cdr t))))
(define (ramanujan-numbers)
  (define weight (lambda (x)
                   (let ((i (car x))
                         (j (cadr x)))
                     (+ (* i i i ) (* j j j)))))
  (define s (stream-filter
              (lambda (x)
                (= (weight (car x)) (weight (cdr x))))
              (stream-zip cubes (stream-cdr cubes))))
  (stream-map (lambda (x)
                  (let ((i (caar x))
                        (j (cadar x)))
                    (+ (* i i i) (* j j j)))) s))

;(display-stream30 (ramanujan-numbers))

; end Exercise 3.71

; Streams as signals
(define (integral integrand initial-value dt)
  (define int
    (cons-stream initial-value
                 (add-streams (scale-stream integrand dt)
                              int)))
  int)

;(display-stream30 (integral integers 0 1))

; Exercise 3.73
(define (RC R C dt)
  (define (proc i v0)
    (add-streams
      (scale-stream i R)
      (scale-stream
        (integral i v0 dt)
        (/ 1 C))))
  proc)

(define RC1 (RC 5 1 0.5))

;(display-stream30 (RC1 ones 0))
; End exercise 3.73

; Exercise 3.74

(define (make-zero-crossings input-stream last-value)
  (cons-stream
    (sign-chage-detector
      (stream-car input-stream)
      last-value)
    (make-zero-crossings
      (stream-cdr input-stream)
      (stream-car input-stream))))

;(define zero-crossings
  ;(make-zero-crossings sense-data 0))

;(define zero-crossings
  ;(stream-map sign-change-detector
              ;sense-data
              ;(cons-stream 0 sense-data)))

; end Exercise 3.74

; Exercise 3.75
(define (make-zero-crossings input-stream last-avpt last-value)
  (let ((avpt (/ (+ (stream-car input-stream)
                    last-value)
                 2)))
    (cons-stream
      (sign-change-detector avpt last-avpt)
      (make-zero-crossings
        (stream-cdr input-stream)
        avpt
        (stream-car input-stream)))))
; end Exercise 3.75

; Exercise 3.76

(define (smooth s)
  (cons-stream (stream-car s)
               (stream-map (lambda (x1 x2)
                             (/ (+ x1
                                   x2)
                                2))
                           s
                           (stream-cdr s))))

; end exercise 3.76


; Streams and Delayed Evaluation

(define (integral-delayed delayed-integrand initial-value dt)
  (define int
    (cons-stream
      initial-value
      (let ((integrand (force delayed-integrand)))
        (add-streams (scale-stream integrand dt) int))))
  int)

(define (solve f y0 dt)
  (define y (integral-delayed (delay dy) y0 dt))
  (define dy (stream-map f y))
  y)

;(display-line (stream-ref (solve (lambda (y) y)
                   ;1
                   ;0.001)
            ;1000))

; Exercise 3.77
(define (integral integrand initial-value dt)
  (cons-stream
    initial-value
    (if (stream-null? integrand)
      the-empty-stream
      (integral (stream-cdr integrand)
                (+ (* dt (stream-car integrand))
                   initial-value)
                dt))))


(define (integral delayed-integrand initial-value dt)
  (cons-stream
    initial-value
    (if (stream-null? (force delayed-integrand))
      the-empty-stream
      (integral (delay (stream-cdr (force delayed-integrand)))
                (+ (* dt (stream-car (force delayed-integrand)))
                   initial-value)
                dt))))

(define (solve f y0 dt)
  (define y (integral (delay dy) y0 dt))
  (define dy (stream-map f y))
  y)

;(display-line (stream-ref (solve (lambda (y) y)
                                 ;1
                                 ;0.001)
                          ;1000))
; End Exercise 3.77


; Exercise 3.78
(define (solve-2nd a b dt y0 dy0)
  (define y (integral (delay dy) y0 dt))
  (define dy (integral (delay ddy) dy0 dt))
  (define ddy (add-streams (scale-stream dy a)
                           (scale-stream y b)))
  y)

; when a = 0, b = 1 then the solution of this homogeneous second-order linear differential equation is the exp(e, x)
;(display-line (stream-ref (solve-2nd 0 1 0.001 1 1) 1000))
; End Exercise 3.78

; Exercise 3.79
(define (solve-2nd-general f dt y0 dy0)
  (define y (integral (delay dy) y0 dt))
  (define dy (integral (delay ddy) dy0 dt))
  (define ddy (stream-map f dy y))
  y)

;(display-line (stream-ref (solve-2nd-general (lambda (x y) y)
;                                             0.001
;                                             1
;                                             1)
;                          1000))
; End exercise 3.79

; Exercise 3.80


; bellow is http://community.schemewiki.org/?sicp-ex-3.80
(define (RLC R L C dt)
         (define (rcl vc0 il0)
                 (define vc (integral (delay dvc) vc0  dt))
                 (define il (integral (delay dil) il0 dt))
                 (define dvc (scale-stream il (- (/ 1 C))))
                 (define dil (add-streams (scale-stream vc (/ 1 L))
                                                                 (scale-stream il (- (/ R L)))))
                 (define (merge-stream s1 s2)
                         (cons-stream (cons (stream-car s1) (stream-car s2))
                                                  (merge-stream (stream-cdr s1) (stream-cdr s2))))
                 (merge-stream vc il))
         rcl)

; bellow is mine
(define (RLC R L C dt)
  (define (proc vc0 il0)
    (define vc (scale-stream (integral (delay il) (* (- C) vc0) dt) (/ -1 C)))
    (define il (integral (delay dil) il0 dt))
    (define dil (add-streams (scale-stream il (/ (- R) L))
                             (scale-stream vc (/ 1 L))))
    ;(stream-zip vc il))
    (stream-map cons vc il))
  proc)

(define RLCcircut (RLC 1 1 0.2 0.1))

(display-stream30 (RLCcircut 10 0))
; End Exercise 3.80
