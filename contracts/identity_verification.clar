;; ChainSecure Identity Verification Contract
;; Enhanced with security features and event tracking

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-registered (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-already-verified (err u104))
(define-constant err-insufficient-verifications (err u105))
(define-constant err-cooldown-active (err u106))
(define-constant err-expired-verification (err u107))
(define-constant err-suspended (err u108))
(define-constant err-invalid-status (err u109))

(define-constant required-verifications u2)
(define-constant verification-expiry-blocks u144) ;; ~24 hours
(define-constant verification-cooldown-blocks u6) ;; ~1 hour

;; Data Variables
(define-map identities
    principal
    {
        hash: (buff 32),
        verified: bool,
        verifications: (list 10 principal),
        timestamp: uint,
        last-update: uint,
        status: bool,
        suspended: bool
    }
)

(define-map verifiers principal bool)
(define-map verification-timestamps { identity: principal, verifier: principal } uint)
(define-map verification-attempts principal uint)

;; Events
(define-data-var last-event-id uint u0)

(define-map events
    uint
    {
        event-type: (string-ascii 24),
        identity: principal,
        verifier: (optional principal),
        timestamp: uint,
        details: (optional (string-ascii 64))
    }
)

;; Enhanced private functions
(define-private (is-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-verifier)
    (default-to false (map-get? verifiers tx-sender))
)

(define-private (count-verifications (verifications (list 10 principal)))
    (len verifications)
)

(define-private (log-event (event-type (string-ascii 24)) (identity principal) (verifier (optional principal)) (details (optional (string-ascii 64))))
    (let ((event-id (+ (var-get last-event-id) u1)))
        (begin
            (map-set events event-id {
                event-type: event-type,
                identity: identity,
                verifier: verifier,
                timestamp: block-height,
                details: details
            })
            (var-set last-event-id event-id)
            event-id
        )
    )
)

;; New functions
(define-public (suspend-identity (identity principal))
    (let ((id-data (map-get? identities identity)))
        (if (and (is-owner) (is-some id-data))
            (begin
                (map-set identities identity (merge (unwrap-panic id-data) {
                    suspended: true,
                    last-update: block-height
                }))
                (log-event "IDENTITY_SUSPENDED" identity none (some "Administrative action"))
                (ok true)
            )
            err-unauthorized
        )
    )
)

(define-public (revoke-verification (identity principal))
    (let ((id-data (map-get? identities identity)))
        (if (and (is-owner) (is-some id-data))
            (begin
                (map-set identities identity (merge (unwrap-panic id-data) {
                    verified: false,
                    verifications: (list),
                    last-update: block-height
                }))
                (log-event "VERIFICATION_REVOKED" identity none (some "Administrative action"))
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Enhanced existing functions
(define-public (verify-identity (identity principal))
    (let (
        (id-data (map-get? identities identity))
        (last-verification (map-get? verification-timestamps { identity: identity, verifier: tx-sender }))
    )
    (if (and (is-verifier) (is-some id-data))
        (let (
            (unwrapped-data (unwrap-panic id-data))
            (current-verifications (get verifications unwrapped-data))
            (cooldown-expired (>= block-height (default-to u0 last-verification)))
        )
        (if (get suspended unwrapped-data)
            err-suspended
            (if (not cooldown-expired)
                err-cooldown-active
                (if (get verified unwrapped-data)
                    err-already-verified
                    (let (
                        (updated-verifications (unwrap-panic (as-max-len? (append current-verifications tx-sender) u10)))
                        (verification-count (+ (count-verifications current-verifications) u1))
                    )
                    (begin
                        (map-set verification-timestamps { identity: identity, verifier: tx-sender } (+ block-height verification-cooldown-blocks))
                        (map-set identities identity (merge unwrapped-data {
                            verifications: updated-verifications,
                            verified: (>= verification-count required-verifications),
                            last-update: block-height
                        }))
                        (log-event "IDENTITY_VERIFIED" identity (some tx-sender) none)
                        (ok true)
                    ))))
        )
        err-unauthorized
    ))
)

;; Enhanced read-only functions
(define-read-only (get-verification-status (identity principal))
    (let ((id-data (map-get? identities identity)))
        (if (is-some id-data)
            (ok {
                verified: (get verified (unwrap-panic id-data)),
                verification-count: (count-verifications (get verifications (unwrap-panic id-data))),
                suspended: (get suspended (unwrap-panic id-data)),
                last-update: (get last-update (unwrap-panic id-data))
            })
            err-not-registered
        )
    )
)
