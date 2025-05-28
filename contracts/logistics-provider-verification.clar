;; logistics-provider-verification.clar
;; This contract validates transportation companies

(define-data-var admin principal tx-sender)

;; Map to store verified logistics providers
(define-map verified-providers principal
  {
    name: (string-utf8 100),
    registration-number: (string-utf8 50),
    verified: bool,
    verification-date: uint
  }
)

;; Public function to register a new logistics provider
(define-public (register-provider (name (string-utf8 100)) (registration-number (string-utf8 50)))
  (let ((provider tx-sender))
    (asserts! (not (is-some (map-get? verified-providers provider))) (err u1)) ;; Error if already registered
    (ok (map-set verified-providers provider
      {
        name: name,
        registration-number: registration-number,
        verified: false,
        verification-date: u0
      }
    ))
  )
)

;; Admin function to verify a logistics provider
(define-public (verify-provider (provider principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403)) ;; Only admin can verify
    (asserts! (is-some (map-get? verified-providers provider)) (err u404)) ;; Provider must exist
    (ok (map-set verified-providers provider
      (merge (unwrap-panic (map-get? verified-providers provider))
        {
          verified: true,
          verification-date: block-height
        }
      )
    ))
  )
)

;; Read-only function to check if a provider is verified
(define-read-only (is-verified (provider principal))
  (default-to false (get verified: (map-get? verified-providers provider)))
)

;; Read-only function to get provider details
(define-read-only (get-provider-details (provider principal))
  (map-get? verified-providers provider)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (var-set admin new-admin))
  )
)
