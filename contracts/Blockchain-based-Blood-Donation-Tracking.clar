(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-invalid-blood-type (err u103))
(define-constant err-expired-blood (err u104))
(define-constant err-insufficient-quantity (err u105))
(define-constant err-unauthorized (err u106))

(define-data-var donation-id-nonce uint u0)
(define-data-var request-id-nonce uint u0)

(define-map donors
    { donor-address: principal }
    {
        name: (string-ascii 50),
        blood-type: (string-ascii 3),
        age: uint,
        last-donation: uint,
        total-donations: uint,
        is-eligible: bool,
    }
)

(define-map donations
    { donation-id: uint }
    {
        donor: principal,
        blood-type: (string-ascii 3),
        quantity: uint,
        donation-date: uint,
        expiry-date: uint,
        hospital: (optional principal),
        is-used: bool,
        location: (string-ascii 100),
    }
)

(define-map blood-inventory
    { blood-type: (string-ascii 3) }
    { available-units: uint }
)

(define-map hospitals
    { hospital-address: principal }
    {
        name: (string-ascii 100),
        location: (string-ascii 100),
        is-verified: bool,
    }
)

(define-map blood-requests
    { request-id: uint }
    {
        hospital: principal,
        blood-type: (string-ascii 3),
        quantity: uint,
        urgency: (string-ascii 10),
        request-date: uint,
        is-fulfilled: bool,
    }
)

(define-map donation-history
    {
        donor: principal,
        donation-id: uint,
    }
    { timestamp: uint }
)

(define-read-only (get-donor (donor-address principal))
    (map-get? donors { donor-address: donor-address })
)

(define-read-only (get-donation (donation-id uint))
    (map-get? donations { donation-id: donation-id })
)

(define-read-only (get-blood-inventory (blood-type (string-ascii 3)))
    (default-to { available-units: u0 }
        (map-get? blood-inventory { blood-type: blood-type })
    )
)

(define-read-only (get-hospital (hospital-address principal))
    (map-get? hospitals { hospital-address: hospital-address })
)

(define-read-only (get-blood-request (request-id uint))
    (map-get? blood-requests { request-id: request-id })
)

(define-read-only (is-valid-blood-type (blood-type (string-ascii 3)))
    (or
        (is-eq blood-type "A+")
        (is-eq blood-type "A-")
        (is-eq blood-type "B+")
        (is-eq blood-type "B-")
        (is-eq blood-type "AB+")
        (is-eq blood-type "AB-")
        (is-eq blood-type "O+")
        (is-eq blood-type "O-")
    )
)

(define-read-only (is-blood-expired (expiry-date uint))
    (> stacks-block-height expiry-date)
)

(define-read-only (can-donate (donor-address principal))
    (let ((donor-info (get-donor donor-address)))
        (match donor-info
            donor (and
                (get is-eligible donor)
                (>= (- stacks-block-height (get last-donation donor)) u4320)
            )
            false
        )
    )
)

(define-public (register-donor
        (name (string-ascii 50))
        (blood-type (string-ascii 3))
        (age uint)
    )
    (begin
        (asserts! (is-valid-blood-type blood-type) err-invalid-blood-type)
        (asserts! (>= age u18) (err u107))
        (asserts! (is-none (get-donor tx-sender)) err-already-exists)
        (ok (map-set donors { donor-address: tx-sender } {
            name: name,
            blood-type: blood-type,
            age: age,
            last-donation: u0,
            total-donations: u0,
            is-eligible: true,
        }))
    )
)

(define-public (register-hospital
        (name (string-ascii 100))
        (location (string-ascii 100))
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set hospitals { hospital-address: tx-sender } {
            name: name,
            location: location,
            is-verified: true,
        }))
    )
)

(define-public (donate-blood
        (blood-type (string-ascii 3))
        (quantity uint)
        (location (string-ascii 100))
    )
    (let (
            (donation-id (+ (var-get donation-id-nonce) u1))
            (donor-info (get-donor tx-sender))
        )
        (asserts! (is-valid-blood-type blood-type) err-invalid-blood-type)
        (asserts! (> quantity u0) (err u108))
        (asserts! (is-some donor-info) err-not-found)
        (asserts! (can-donate tx-sender) (err u109))
        (let (
                (donor (unwrap-panic donor-info))
                (expiry-date (+ stacks-block-height u8640))
            )
            (unwrap-panic (update-donor-after-donation tx-sender))
            (unwrap-panic (update-blood-inventory blood-type quantity true))
            (map-set donations { donation-id: donation-id } {
                donor: tx-sender,
                blood-type: blood-type,
                quantity: quantity,
                donation-date: stacks-block-height,
                expiry-date: expiry-date,
                hospital: none,
                is-used: false,
                location: location,
            })
            (map-set donation-history {
                donor: tx-sender,
                donation-id: donation-id,
            } { timestamp: stacks-block-height }
            )
            (var-set donation-id-nonce donation-id)
            (ok donation-id)
        )
    )
)

(define-public (request-blood
        (blood-type (string-ascii 3))
        (quantity uint)
        (urgency (string-ascii 10))
    )
    (let (
            (request-id (+ (var-get request-id-nonce) u1))
            (hospital-info (get-hospital tx-sender))
        )
        (asserts! (is-valid-blood-type blood-type) err-invalid-blood-type)
        (asserts! (> quantity u0) (err u108))
        (asserts! (is-some hospital-info) err-unauthorized)
        (map-set blood-requests { request-id: request-id } {
            hospital: tx-sender,
            blood-type: blood-type,
            quantity: quantity,
            urgency: urgency,
            request-date: stacks-block-height,
            is-fulfilled: false,
        })
        (var-set request-id-nonce request-id)
        (ok request-id)
    )
)

(define-public (fulfill-blood-request
        (request-id uint)
        (donation-id uint)
    )
    (let (
            (request-info (get-blood-request request-id))
            (donation-info (get-donation donation-id))
        )
        (asserts! (is-some request-info) err-not-found)
        (asserts! (is-some donation-info) err-not-found)
        (let (
                (request (unwrap-panic request-info))
                (donation (unwrap-panic donation-info))
            )
            (asserts! (is-eq tx-sender (get hospital request)) err-unauthorized)
            (asserts! (not (get is-fulfilled request)) (err u110))
            (asserts! (not (get is-used donation)) (err u111))
            (asserts! (is-eq (get blood-type request) (get blood-type donation))
                (err u112)
            )
            (asserts! (<= (get quantity request) (get quantity donation))
                err-insufficient-quantity
            )
            (asserts! (not (is-blood-expired (get expiry-date donation)))
                err-expired-blood
            )
            (map-set blood-requests { request-id: request-id }
                (merge request { is-fulfilled: true })
            )
            (map-set donations { donation-id: donation-id }
                (merge donation {
                    is-used: true,
                    hospital: (some tx-sender),
                })
            )
            (unwrap-panic (update-blood-inventory (get blood-type donation)
                (get quantity request) false
            ))
            (ok true)
        )
    )
)

(define-public (update-donor-eligibility
        (donor-address principal)
        (eligible bool)
    )
    (let ((donor-info (get-donor donor-address)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some donor-info) err-not-found)
        (let ((donor (unwrap-panic donor-info)))
            (ok (map-set donors { donor-address: donor-address }
                (merge donor { is-eligible: eligible })
            ))
        )
    )
)

(define-private (update-donor-after-donation (donor-address principal))
    (let ((donor-info (get-donor donor-address)))
        (match donor-info
            donor (ok (map-set donors { donor-address: donor-address }
                (merge donor {
                    last-donation: stacks-block-height,
                    total-donations: (+ (get total-donations donor) u1),
                })
            ))
            err-not-found
        )
    )
)

(define-private (update-blood-inventory
        (blood-type (string-ascii 3))
        (quantity uint)
        (is-addition bool)
    )
    (let ((current-inventory (get-blood-inventory blood-type)))
        (let ((current-units (get available-units current-inventory)))
            (let ((new-units (if is-addition
                    (+ current-units quantity)
                    (if (>= current-units quantity)
                        (- current-units quantity)
                        u0
                    )
                )))
                (ok (map-set blood-inventory { blood-type: blood-type } { available-units: new-units }))
            )
        )
    )
)

(define-read-only (get-compatible-donors (blood-type (string-ascii 3)))
    (if (is-eq blood-type "AB+")
        (list "A+" "A-" "B+" "B-" "AB+" "AB-" "O+" "O-")
        (if (is-eq blood-type "AB-")
            (list "A-" "B-" "AB-" "O-")
            (if (is-eq blood-type "A+")
                (list "A+" "A-" "O+" "O-")
                (if (is-eq blood-type "A-")
                    (list "A-" "O-")
                    (if (is-eq blood-type "B+")
                        (list "B+" "B-" "O+" "O-")
                        (if (is-eq blood-type "B-")
                            (list "B-" "O-")
                            (if (is-eq blood-type "O+")
                                (list "O+" "O-")
                                (if (is-eq blood-type "O-")
                                    (list "O-")
                                    (list)
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

(define-read-only (get-total-donations-by-donor (donor-address principal))
    (match (get-donor donor-address)
        donor (get total-donations donor)
        u0
    )
)

(define-read-only (get-current-donation-id)
    (var-get donation-id-nonce)
)

(define-read-only (get-current-request-id)
    (var-get request-id-nonce)
)
