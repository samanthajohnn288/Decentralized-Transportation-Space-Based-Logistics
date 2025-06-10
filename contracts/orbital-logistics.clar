;; Orbital Logistics Contract
;; Manages space-based supply chains and cargo tracking

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SHIPMENT_NOT_FOUND (err u201))
(define-constant ERR_INVALID_STATUS (err u202))
(define-constant ERR_INSUFFICIENT_CAPACITY (err u203))

;; Shipment status
(define-constant STATUS_CREATED u0)
(define-constant STATUS_IN_TRANSIT u1)
(define-constant STATUS_DELIVERED u2)
(define-constant STATUS_CANCELLED u3)

;; Data structures
(define-map shipments
  { shipment-id: uint }
  {
    sender: principal,
    receiver: principal,
    carrier-entity-id: uint,
    origin: (string-ascii 30),
    destination: (string-ascii 30),
    cargo-type: (string-ascii 20),
    weight: uint,
    volume: uint,
    status: uint,
    created-at: uint,
    estimated-delivery: uint
  }
)

(define-map shipment-tracking
  { shipment-id: uint }
  {
    current-location: (string-ascii 30),
    last-update: uint,
    progress-percentage: uint,
    tracking-history: (list 20 (string-ascii 50))
  }
)

(define-data-var next-shipment-id uint u1)

;; Create a new shipment
(define-public (create-shipment
  (receiver principal)
  (carrier-entity-id uint)
  (origin (string-ascii 30))
  (destination (string-ascii 30))
  (cargo-type (string-ascii 20))
  (weight uint)
  (volume uint)
  (estimated-delivery uint))
  (let ((shipment-id (var-get next-shipment-id)))

    ;; Verify carrier entity (would call verification contract)
    (asserts! (> carrier-entity-id u0) ERR_UNAUTHORIZED)

    (map-set shipments
      { shipment-id: shipment-id }
      {
        sender: tx-sender,
        receiver: receiver,
        carrier-entity-id: carrier-entity-id,
        origin: origin,
        destination: destination,
        cargo-type: cargo-type,
        weight: weight,
        volume: volume,
        status: STATUS_CREATED,
        created-at: block-height,
        estimated-delivery: estimated-delivery
      }
    )

    (map-set shipment-tracking
      { shipment-id: shipment-id }
      {
        current-location: origin,
        last-update: block-height,
        progress-percentage: u0,
        tracking-history: (list origin)
      }
    )

    (var-set next-shipment-id (+ shipment-id u1))
    (ok shipment-id)
  )
)

;; Update shipment status
(define-public (update-shipment-status
  (shipment-id uint)
  (new-status uint)
  (current-location (string-ascii 30))
  (progress-percentage uint))
  (let ((shipment (unwrap! (map-get? shipments { shipment-id: shipment-id }) ERR_SHIPMENT_NOT_FOUND)))

    ;; Only carrier can update status
    (asserts! (is-eq tx-sender (get sender shipment)) ERR_UNAUTHORIZED)

    (map-set shipments
      { shipment-id: shipment-id }
      (merge shipment { status: new-status })
    )

    (let ((tracking (unwrap-panic (map-get? shipment-tracking { shipment-id: shipment-id }))))
      (map-set shipment-tracking
        { shipment-id: shipment-id }
        {
          current-location: current-location,
          last-update: block-height,
          progress-percentage: progress-percentage,
          tracking-history: (unwrap-panic (as-max-len?
            (append (get tracking-history tracking) current-location) u20))
        }
      )
    )

    (ok true)
  )
)

;; Get shipment details
(define-read-only (get-shipment (shipment-id uint))
  (map-get? shipments { shipment-id: shipment-id })
)

;; Get shipment tracking
(define-read-only (get-shipment-tracking (shipment-id uint))
  (map-get? shipment-tracking { shipment-id: shipment-id })
)

;; Get shipments by sender
(define-read-only (get-shipments-by-sender (sender principal))
  ;; In a real implementation, this would use a more efficient indexing method
  (ok "Use indexing service for efficient queries")
)
