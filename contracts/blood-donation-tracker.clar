;; Blood Donation Tracking Smart Contract
;; A comprehensive system for tracking blood donations, donor eligibility, and inventory management

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-DONOR-NOT-FOUND (err u404))
(define-constant ERR-DONATION-NOT-FOUND (err u405))
(define-constant ERR-INVALID-BLOOD-TYPE (err u406))
(define-constant ERR-DONOR-NOT-ELIGIBLE (err u407))
(define-constant ERR-INSUFFICIENT-INVENTORY (err u408))
(define-constant ERR-INVALID-QUANTITY (err u409))

;; Contract owner
(define-constant contract-owner tx-sender)

;; Blood types
(define-constant BLOOD-TYPE-O-POS u1)
(define-constant BLOOD-TYPE-O-NEG u2)
(define-constant BLOOD-TYPE-A-POS u3)
(define-constant BLOOD-TYPE-A-NEG u4)
(define-constant BLOOD-TYPE-B-POS u5)
(define-constant BLOOD-TYPE-B-NEG u6)
(define-constant BLOOD-TYPE-AB-POS u7)
(define-constant BLOOD-TYPE-AB-NEG u8)

;; Donation status constants
(define-constant STATUS-COLLECTED u1)
(define-constant STATUS-TESTED u2)
(define-constant STATUS-APPROVED u3)
(define-constant STATUS-USED u4)
(define-constant STATUS-EXPIRED u5)

;; Data variables
(define-data-var donation-id-counter uint u0)
(define-data-var donor-id-counter uint u0)

;; Donor information map
(define-map donors
  { donor-id: uint }
  {
    donor-address: principal,
    blood-type: uint,
    last-donation-block: uint,
    total-donations: uint,
    is-eligible: bool,
    registration-block: uint,
  }
)

;; Donation records map
(define-map donations
  { donation-id: uint }
  {
    donor-id: uint,
    blood-type: uint,
    quantity-ml: uint,
    donation-block: uint,
    status: uint,
    hospital-address: (optional principal),
    expiry-block: uint,
  }
)

;; Blood inventory map by blood type
(define-map blood-inventory
  { blood-type: uint }
  {
    available-ml: uint,
    reserved-ml: uint,
  }
)

;; Donor address to donor-id mapping
(define-map donor-address-to-id
  principal
  uint
)

;; Hospital authorization map
(define-map authorized-hospitals
  principal
  bool
)

;; Initialize blood inventory for all blood types
(map-set blood-inventory { blood-type: BLOOD-TYPE-O-POS } {
  available-ml: u0,
  reserved-ml: u0,
})
(map-set blood-inventory { blood-type: BLOOD-TYPE-O-NEG } {
  available-ml: u0,
  reserved-ml: u0,
})
(map-set blood-inventory { blood-type: BLOOD-TYPE-A-POS } {
  available-ml: u0,
  reserved-ml: u0,
})
(map-set blood-inventory { blood-type: BLOOD-TYPE-A-NEG } {
  available-ml: u0,
  reserved-ml: u0,
})
(map-set blood-inventory { blood-type: BLOOD-TYPE-B-POS } {
  available-ml: u0,
  reserved-ml: u0,
})
(map-set blood-inventory { blood-type: BLOOD-TYPE-B-NEG } {
  available-ml: u0,
  reserved-ml: u0,
})
(map-set blood-inventory { blood-type: BLOOD-TYPE-AB-POS } {
  available-ml: u0,
  reserved-ml: u0,
})
(map-set blood-inventory { blood-type: BLOOD-TYPE-AB-NEG } {
  available-ml: u0,
  reserved-ml: u0,
})

;; Private functions

;; Check if blood type is valid
(define-private (is-valid-blood-type (blood-type uint))
  (and
    (>= blood-type u1)
    (<= blood-type u8)
  )
)

;; Check if donor is eligible (56 days = ~8000 blocks between donations)
(define-private (is-donor-eligible (last-donation-block uint))
  (or
    (is-eq last-donation-block u0)
    (> (- block-height last-donation-block) u8000)
  )
)

;; Calculate expiry block (blood expires after ~30 days = ~4200 blocks)
(define-private (calculate-expiry-block)
  (+ block-height u4200)
)

;; Public functions

;; Register a new donor
(define-public (register-donor (blood-type uint))
  (let (
      (new-donor-id (+ (var-get donor-id-counter) u1))
      (existing-donor (map-get? donor-address-to-id tx-sender))
    )
    (asserts! (is-valid-blood-type blood-type) ERR-INVALID-BLOOD-TYPE)
    (asserts! (is-none existing-donor) ERR-UNAUTHORIZED)

    (map-set donors { donor-id: new-donor-id } {
      donor-address: tx-sender,
      blood-type: blood-type,
      last-donation-block: u0,
      total-donations: u0,
      is-eligible: true,
      registration-block: block-height,
    })

    (map-set donor-address-to-id tx-sender new-donor-id)
    (var-set donor-id-counter new-donor-id)

    (ok new-donor-id)
  )
)

;; Record a blood donation
(define-public (record-donation (quantity-ml uint))
  (let (
      (donor-id-opt (map-get? donor-address-to-id tx-sender))
      (new-donation-id (+ (var-get donation-id-counter) u1))
    )
    (asserts! (> quantity-ml u0) ERR-INVALID-QUANTITY)
    (asserts! (is-some donor-id-opt) ERR-DONOR-NOT-FOUND)

    (let (
        (donor-id (unwrap-panic donor-id-opt))
        (donor-info (unwrap! (map-get? donors { donor-id: donor-id }) ERR-DONOR-NOT-FOUND))
      )
      (asserts! (get is-eligible donor-info) ERR-DONOR-NOT-ELIGIBLE)
      (asserts! (is-donor-eligible (get last-donation-block donor-info))
        ERR-DONOR-NOT-ELIGIBLE
      )

      ;; Create donation record
      (map-set donations { donation-id: new-donation-id } {
        donor-id: donor-id,
        blood-type: (get blood-type donor-info),
        quantity-ml: quantity-ml,
        donation-block: block-height,
        status: STATUS-COLLECTED,
        hospital-address: none,
        expiry-block: (calculate-expiry-block),
      })

      ;; Update donor information
      (map-set donors { donor-id: donor-id }
        (merge donor-info {
          last-donation-block: block-height,
          total-donations: (+ (get total-donations donor-info) u1),
        })
      )

      (var-set donation-id-counter new-donation-id)
      (ok new-donation-id)
    )
  )
)

;; Approve donation and add to inventory (hospital/admin only)
(define-public (approve-donation (donation-id uint))
  (let (
      (donation-info (unwrap! (map-get? donations { donation-id: donation-id })
        ERR-DONATION-NOT-FOUND
      ))
      (blood-type (get blood-type donation-info))
      (quantity (get quantity-ml donation-info))
      (current-inventory (unwrap! (map-get? blood-inventory { blood-type: blood-type })
        ERR-INVALID-BLOOD-TYPE
      ))
    )
    (asserts! (is-eq (get status donation-info) STATUS-TESTED) ERR-UNAUTHORIZED)
    (asserts! (< block-height (get expiry-block donation-info)) ERR-UNAUTHORIZED)

    ;; Update donation status
    (map-set donations { donation-id: donation-id }
      (merge donation-info { status: STATUS-APPROVED })
    )

    ;; Add to inventory
    (map-set blood-inventory { blood-type: blood-type } {
      available-ml: (+ (get available-ml current-inventory) quantity),
      reserved-ml: (get reserved-ml current-inventory),
    })

    (ok true)
  )
)

;; Update donation status (testing complete)
(define-public (update-donation-status
    (donation-id uint)
    (new-status uint)
  )
  (let ((donation-info (unwrap! (map-get? donations { donation-id: donation-id })
      ERR-DONATION-NOT-FOUND
    )))
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED)
    (asserts! (<= new-status STATUS-EXPIRED) ERR-UNAUTHORIZED)

    (map-set donations { donation-id: donation-id }
      (merge donation-info { status: new-status })
    )

    (ok true)
  )
)

;; Reserve blood for hospital use
(define-public (reserve-blood
    (blood-type uint)
    (quantity-ml uint)
    (hospital-address principal)
  )
  (let ((current-inventory (unwrap! (map-get? blood-inventory { blood-type: blood-type })
      ERR-INVALID-BLOOD-TYPE
    )))
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED)
    (asserts! (>= (get available-ml current-inventory) quantity-ml)
      ERR-INSUFFICIENT-INVENTORY
    )

    (map-set blood-inventory { blood-type: blood-type } {
      available-ml: (- (get available-ml current-inventory) quantity-ml),
      reserved-ml: (+ (get reserved-ml current-inventory) quantity-ml),
    })

    (ok true)
  )
)

;; Authorize hospital
(define-public (authorize-hospital (hospital-address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED)
    (map-set authorized-hospitals hospital-address true)
    (ok true)
  )
)

;; Read-only functions

;; Get donor information
(define-read-only (get-donor-info (donor-id uint))
  (map-get? donors { donor-id: donor-id })
)

;; Get donor info by address
(define-read-only (get-donor-by-address (donor-address principal))
  (match (map-get? donor-address-to-id donor-address)
    donor-id (map-get? donors { donor-id: donor-id })
    none
  )
)

;; Get donation information
(define-read-only (get-donation-info (donation-id uint))
  (map-get? donations { donation-id: donation-id })
)

;; Get blood inventory for specific type
(define-read-only (get-blood-inventory (blood-type uint))
  (map-get? blood-inventory { blood-type: blood-type })
)

;; Get total available blood of all types
(define-read-only (get-total-inventory)
  (let (
      (o-pos (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-O-POS })
      ))
      (o-neg (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-O-NEG })
      ))
      (a-pos (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-A-POS })
      ))
      (a-neg (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-A-NEG })
      ))
      (b-pos (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-B-POS })
      ))
      (b-neg (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-B-NEG })
      ))
      (ab-pos (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-AB-POS })
      ))
      (ab-neg (default-to {
        available-ml: u0,
        reserved-ml: u0,
      }
        (map-get? blood-inventory { blood-type: BLOOD-TYPE-AB-NEG })
      ))
    )
    {
      total-available-ml: (+ (get available-ml o-pos) (get available-ml o-neg)
        (get available-ml a-pos) (get available-ml a-neg)
        (get available-ml b-pos) (get available-ml b-neg)
        (get available-ml ab-pos) (get available-ml ab-neg)
      ),
      total-reserved-ml: (+ (get reserved-ml o-pos) (get reserved-ml o-neg) (get reserved-ml a-pos)
        (get reserved-ml a-neg) (get reserved-ml b-pos)
        (get reserved-ml b-neg) (get reserved-ml ab-pos)
        (get reserved-ml ab-neg)
      ),
    }
  )
)

;; Check if hospital is authorized
(define-read-only (is-hospital-authorized (hospital-address principal))
  (default-to false (map-get? authorized-hospitals hospital-address))
)

;; Get current counters
(define-read-only (get-counters)
  {
    total-donors: (var-get donor-id-counter),
    total-donations: (var-get donation-id-counter),
  }
)

(define-map hospital-reservations
  {
    hospital: principal,
    blood-type: uint,
  }
  { reserved-ml: uint }
)

(define-public (reserve-blood-for-hospital
    (hospital principal)
    (blood-type uint)
    (quantity-ml uint)
  )
  (let (
      (current-inventory (unwrap! (map-get? blood-inventory { blood-type: blood-type })
        ERR-INVALID-BLOOD-TYPE
      ))
      (current-hospital-reservation (default-to { reserved-ml: u0 }
        (map-get? hospital-reservations {
          hospital: hospital,
          blood-type: blood-type,
        })
      ))
    )
    (asserts! (is-eq tx-sender contract-owner) ERR-UNAUTHORIZED)
    (asserts! (is-valid-blood-type blood-type) ERR-INVALID-BLOOD-TYPE)
    (asserts! (> quantity-ml u0) ERR-INVALID-QUANTITY)
    (asserts! (>= (get available-ml current-inventory) quantity-ml)
      ERR-INSUFFICIENT-INVENTORY
    )

    (map-set blood-inventory { blood-type: blood-type } {
      available-ml: (- (get available-ml current-inventory) quantity-ml),
      reserved-ml: (+ (get reserved-ml current-inventory) quantity-ml),
    })

    (map-set hospital-reservations {
      hospital: hospital,
      blood-type: blood-type,
    } { reserved-ml: (+ (get reserved-ml current-hospital-reservation) quantity-ml) }
    )

    (ok true)
  )
)

(define-public (consume-reservation
    (blood-type uint)
    (quantity-ml uint)
  )
  (let (
      (current-inventory (unwrap! (map-get? blood-inventory { blood-type: blood-type })
        ERR-INVALID-BLOOD-TYPE
      ))
      (current-hospital-reservation (unwrap!
        (map-get? hospital-reservations {
          hospital: tx-sender,
          blood-type: blood-type,
        })
        ERR-INSUFFICIENT-INVENTORY
      ))
    )
    (asserts! (is-hospital-authorized tx-sender) ERR-UNAUTHORIZED)
    (asserts! (is-valid-blood-type blood-type) ERR-INVALID-BLOOD-TYPE)
    (asserts! (> quantity-ml u0) ERR-INVALID-QUANTITY)
    (asserts! (>= (get reserved-ml current-hospital-reservation) quantity-ml)
      ERR-INSUFFICIENT-INVENTORY
    )

    (map-set hospital-reservations {
      hospital: tx-sender,
      blood-type: blood-type,
    } { reserved-ml: (- (get reserved-ml current-hospital-reservation) quantity-ml) }
    )

    (map-set blood-inventory { blood-type: blood-type } {
      available-ml: (get available-ml current-inventory),
      reserved-ml: (- (get reserved-ml current-inventory) quantity-ml),
    })

    (ok true)
  )
)

(define-read-only (get-hospital-reservation
    (hospital principal)
    (blood-type uint)
  )
  (default-to { reserved-ml: u0 }
    (map-get? hospital-reservations {
      hospital: hospital,
      blood-type: blood-type,
    })
  )
)
