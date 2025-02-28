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
        status: bool
    }
)

(define-map verifiers principal bool)
(define-map verification-timestamps { identity: principal, verifier: principal } uint)

;; Events
(define-data-var last-event-id uint u0)

(define-map events
    uint
    {
        event-type: (string-ascii 24),
        identity: principal,
        verifier: (optional principal),
        timestamp: uint
    }
)

;; Private functions
(define-private (is-owner)
    (is-eq tx-sender contract-owner)
)

(define-private (is-verifier)
    (default-to false (map-get? verifiers tx-sender))
)

(define-private (count-verifications (verifications (list 10 principal)))
    (len verifications)
)

(define-private (log-event (event-type (string-ascii 24)) (identity principal) (verifier (optional principal)))
    (let ((event-id (+ (var-get last-event-id) u1)))
        (begin
            (map-set events event-id {
                event-type: event-type,
                identity: identity,
                verifier: verifier,
                timestamp: block-height
            })
            (var-set last-event-id event-id)
            event-id
        )
    )
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
                last-update: block-height,
                status: true
            })
            (log-event "IDENTITY_REGISTERED" tx-sender none)
            (ok true)
        ))
    )
)

(define-public (update-identity-hash (hash (buff 32)))
    (let (
        (existing-identity (map-get? identities tx-sender))
    )
    (if (is-some existing-identity)
        (begin
            (map-set identities tx-sender (merge (unwrap-panic existing-identity) {
                hash: hash,
                last-update: block-height
            }))
            (log-event "HASH_UPDATED" tx-sender none)
            (ok true)
        )
        err-not-registered
    ))
)

(define-public (add-verifier (verifier principal))
    (if (is-owner)
        (begin
            (map-set verifiers verifier true)
            (log-event "VERIFIER_ADDED" verifier none)
            (ok true)
        )
        err-owner-only
    )
)

(define-public (remove-verifier (verifier principal))
    (if (is-owner)
        (begin
            (map-delete verifiers verifier)
            (log-event "VERIFIER_REMOVED" verifier none)
            (ok true)
        )
        err-owner-only
    )
)

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
                    (log-event "IDENTITY_VERIFIED" identity (some tx-sender))
                    (ok true)
                ))))
        )
        err-unauthorized
    ))
)

;; Read only functions
(define-read-only (get-identity-details (identity principal))
    (map-get? identities identity)
)

(define-read-only (get-latest-event)
    (map-get? events (var-get last-event-id))
)
