;;;; compilation-tests.lisp
;;;;
;;;; Author: Eric Peterson

(in-package #:cl-quil-tests)


(deftest su4-to-su2x2-test ()
  "Ensures that Optimal 2Q Compilation decomposes SU(2)xSU(2) matrices correctly."
  (let* ((a1 (quil::random-special-unitary 2))
         (a0 (quil::random-special-unitary 2))
         (a (magicl:multiply-complex-matrices (cl-quil::su2-on-line 1 a1)
                                              (cl-quil::su2-on-line 0 a0))))
        (multiple-value-bind (b1 b0) (cl-quil::convert-su4-to-su2x2 a)
          (fiasco-assert-matrices-are-equal a1 b1)
          (fiasco-assert-matrices-are-equal a0 b0))))

(deftest euler-compilation-test ()
  "Ensures that euler-compile correctly decomposes an element of SU(2)."
  (let* ((m (quil::random-special-unitary 2))
         (compiled-list (cl-quil::euler-compiler (build-anonymous-gate m 0)))
         (u (quil::make-matrix-from-quil compiled-list)))
    (fiasco-assert-matrices-are-equal m u)))

(deftest optimal-2q-on-su2x2 ()
  "Tests that optimal 2Q compilation can handle a gate of the form SU(2) x SU(2)."
  (let* ((m (magicl:multiply-complex-matrices
             (cl-quil::su2-on-line 0 (quil::random-special-unitary 2))
             (cl-quil::su2-on-line 1 (quil::random-special-unitary 2))))
         (compiled-list (cl-quil::optimal-2q-compiler (build-anonymous-gate m 1 0)))
         (u (quil::make-matrix-from-quil compiled-list)))
    (fiasco-assert-matrices-are-equal m u)))

(deftest test-optimal-2q-templates ()
  "Tests that optimal 2Q compilation can handle expressive gates and different architectures."
  (labels ((random-rotation (name &rest qubits)
             (apply #'quil::build-gate name (list (- (random (* 2 pi)) pi)) qubits))
           (random-local-quil ()
             (list (random-rotation "RZ" 0)
                   (random-rotation "RY" 0)
                   (random-rotation "RZ" 0)
                   (random-rotation "RZ" 1)
                   (random-rotation "RY" 1)
                   (random-rotation "RZ" 1))))
    (let ((template-list '(("I")
                           ("CZ")
                           ("CZ" "CZ")
                           ("CZ" "CZ" "CZ")
                           ("ISWAP")
                           ("ISWAP" "ISWAP")
                           ("ISWAP" "ISWAP" "ISWAP")
                           ("CZ" "ISWAP")
                           ("CPHASE")
                           ("PISWAP")
                           ("ISWAP" "PISWAP")
                           ("CZ" "PISWAP")
                           ("ISWAP" "CPHASE")
                           ("CPHASE" "PISWAP"))))
      (finish-output *debug-io*)
      (dolist (template template-list)
        (format *debug-io* "    Trying test template ~19a" template)
        (let ((random-quil (random-local-quil))
              (target-type nil))
          (dolist (operator template)
            (setf random-quil
                  (append random-quil
                          (cond
                            ((string= operator "I")
                             nil)
                            ((or (string= operator "ISWAP")
                                 (string= operator "CZ"))
                             (list (quil::build-gate operator '() 0 1)))
                            ((or (string= operator "CPHASE")
                                 (string= operator "PISWAP"))
                             (list (quil::build-gate operator
                                                     (list (- (random (* 2 pi)) pi))
                                                     0 1))))
                          (random-local-quil)))
            (unless (string= operator "I")
              (push (cond
                      ((string= operator "CZ") ':cz)
                      ((string= operator "ISWAP") ':iswap)
                      ((string= operator "CPHASE") ':cphase)
                      ((string= operator "PISWAP") ':piswap))
                    target-type)))
          (let* ((ref-mat (cl-quil::make-matrix-from-quil random-quil))
                 (processed-quil (cl-quil::optimal-2q-compiler (build-anonymous-gate ref-mat 1 0)
                                                               :target target-type))
                 (mat (cl-quil::make-matrix-from-quil processed-quil))
                 (big-gates (mapcar (alexandria:compose
                                     #'quil::operator-description-name
                                     #'application-operator)
                                    (remove-if (lambda (i) (= 1 (length (application-arguments i))))
                                               processed-quil))))
            (format *debug-io* ", got ~19a back.~%" big-gates)
            (is (cl-quil::matrix-equality ref-mat
                                          (cl-quil::scale-out-matrix-phases mat ref-mat)))
            (when (> (length big-gates) (length template))
              (format *debug-io* "    WARNING: deeper answer than expected~%"))))))))

(deftest QSD-on-4Q ()
  "Tests Quantum Shannon Compilation on a random 4Q gate."
  (let* ((m (quil::random-special-unitary 16))
         (compiled-list (quil::qs-compiler (build-anonymous-gate m 3 2 1 0))))
    (let* ((expanded-string
             (loop :for instr :in compiled-list
                   :nconc (if (typep instr 'quil::ucr-application)
                              (quil::ucr-explode-instr instr)
                              (list instr))))
           (u (quil::make-matrix-from-quil expanded-string)))
      (check-type u magicl:matrix)
      (quil::scale-out-matrix-phases u m)
      (fiasco-assert-matrices-are-equal m u))))