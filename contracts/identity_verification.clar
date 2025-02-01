;; ChainSecure Identity Verification Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-registered (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-already-verified (err u104))
(define-constant err-insufficient-verifications (err u105))
(define-constant required-verifications u2)

;; Data Variables
(define-map identities
    principal
    {
        hash: (buff 32),
        verified: bool,
        verifications: (list 10 principal),
        timestamp: uint,
        status: bool
    }
)

(define-map verifiers principal bool)

;; Authorization check
(define-private (is-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-verifier)
    (default-to false (map-get? verifiers tx-sender))
)

(define-private (count-verifications (verifications (list 10 principal)))
    (len verifications)
)

;; Public functions
(define-public (register-identity (hash (buff 32)))
    (let (
        (existing-identity (map-get? identities tx-sender))
    )
    (if (is-some existing-identity)
        err-already-registered
        (begin
            (map-set identities tx-sender {
                hash: hash,
                verified: false,
                verifications: (list),
                timestamp: block-height,
                status: true
            })
            (ok true)
        ))
    )
)

(define-public (add-verifier (verifier principal))
    (if (is-owner)
        (begin
            (map-set verifiers verifier true)
            (ok true)
        )
        err-owner-only
    )
)

(define-public (verify-identity (identity principal))
    (let (
        (id-data (map-get? identities identity))
    )
    (if (and (is-verifier) (is-some id-data))
        (let (
            (unwrapped-data (unwrap-panic id-data))
            (current-verifications (get verifications unwrapped-data))
        )
        (if (get verified unwrapped-data)
            err-already-verified
            (let (
                (updated-verifications (unwrap-panic (as-max-len? (append current-verifications tx-sender) u10)))
                (verification-count (+ (count-verifications current-verifications) u1))
            )
            (begin
                (map-set identities identity (merge unwrapped-data {
                    verifications: updated-verifications,
                    verified: (>= verification-count required-verifications)
                }))
                (ok true)
            )))
        )
        err-unauthorized
    ))
)

(define-public (revoke-identity (identity principal))
    (let (
        (id-data (map-get? identities identity))
    )
    (if (and (is-owner) (is-some id-data))
        (begin
            (map-set identities identity (merge (unwrap-panic id-data) {
                status: false
            }))
            (ok true)
        )
        err-unauthorized
    ))
)

;; Read only functions
(define-read-only (get-identity-status (identity principal))
    (let (
        (id-data (map-get? identities identity))
    )
    (if (is-some id-data)
        (ok (get status (unwrap-panic id-data)))
        err-not-registered
    ))
)

(define-read-only (is-identity-verified (identity principal))
    (let (
        (id-data (map-get? identities identity))
    )
    (if (is-some id-data)
        (ok (get verified (unwrap-panic id-data)))
        err-not-registered
    ))
)

(define-read-only (get-verification-count (identity principal))
    (let (
        (id-data (map-get? identities identity))
    )
    (if (is-some id-data)
        (ok (count-verifications (get verifications (unwrap-panic id-data))))
        err-not-registered
    ))
)
