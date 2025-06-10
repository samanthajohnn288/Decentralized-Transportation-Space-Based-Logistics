;; Mission Coordination Contract
;; Coordinates space transportation missions and schedules

(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_MISSION_NOT_FOUND (err u301))
(define-constant ERR_INVALID_SCHEDULE (err u302))
(define-constant ERR_MISSION_CONFLICT (err u303))

;; Mission status
(define-constant STATUS_PLANNED u0)
(define-constant STATUS_SCHEDULED u1)
(define-constant STATUS_ACTIVE u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_ABORTED u4)

;; Data structures
(define-map missions
  { mission-id: uint }
  {
    coordinator: principal,
    entity-id: uint,
    mission-type: (string-ascii 20),
    launch-window-start: uint,
    launch-window-end: uint,
    duration: uint,
    priority: uint,
    status: uint,
    participants: (list 10 uint)
  }
)

(define-map mission-resources
  { mission-id: uint }
  {
    fuel-required: uint,
    crew-size: uint,
    cargo-capacity: uint,
    orbital-slots: (list 5 (string-ascii 20))
  }
)

(define-map orbital-schedule
  { time-slot: uint, orbital-zone: (string-ascii 20) }
  { reserved-by-mission: uint, entity-id: uint }
)

(define-data-var next-mission-id uint u1)

;; Create a new mission
(define-public (create-mission
  (entity-id uint)
  (mission-type (string-ascii 20))
  (launch-window-start uint)
  (launch-window-end uint)
  (duration uint)
  (priority uint)
  (fuel-required uint)
  (crew-size uint))
  (let ((mission-id (var-get next-mission-id)))

    (asserts! (> launch-window-end launch-window-start) ERR_INVALID_SCHEDULE)
    (asserts! (> launch-window-start block-height) ERR_INVALID_SCHEDULE)

    (map-set missions
      { mission-id: mission-id }
      {
        coordinator: tx-sender,
        entity-id: entity-id,
        mission-type: mission-type,
        launch-window-start: launch-window-start,
        launch-window-end: launch-window-end,
        duration: duration,
        priority: priority,
        status: STATUS_PLANNED,
        participants: (list entity-id)
      }
    )

    (map-set mission-resources
      { mission-id: mission-id }
      {
        fuel-required: fuel-required,
        crew-size: crew-size,
        cargo-capacity: u0,
        orbital-slots: (list)
      }
    )

    (var-set next-mission-id (+ mission-id u1))
    (ok mission-id)
  )
)

;; Schedule mission for specific orbital slot
(define-public (schedule-mission
  (mission-id uint)
  (time-slot uint)
  (orbital-zone (string-ascii 20)))
  (let ((mission (unwrap! (map-get? missions { mission-id: mission-id }) ERR_MISSION_NOT_FOUND)))

    (asserts! (is-eq tx-sender (get coordinator mission)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? orbital-schedule { time-slot: time-slot, orbital-zone: orbital-zone })) ERR_MISSION_CONFLICT)

    ;; Reserve orbital slot
    (map-set orbital-schedule
      { time-slot: time-slot, orbital-zone: orbital-zone }
      { reserved-by-mission: mission-id, entity-id: (get entity-id mission) }
    )

    ;; Update mission status
    (map-set missions
      { mission-id: mission-id }
      (merge mission { status: STATUS_SCHEDULED })
    )

    (ok true)
  )
)

;; Add participant to mission
(define-public (add-mission-participant (mission-id uint) (participant-entity-id uint))
  (let ((mission (unwrap! (map-get? missions { mission-id: mission-id }) ERR_MISSION_NOT_FOUND)))

    (asserts! (is-eq tx-sender (get coordinator mission)) ERR_UNAUTHORIZED)

    (map-set missions
      { mission-id: mission-id }
      (merge mission {
        participants: (unwrap-panic (as-max-len?
          (append (get participants mission) participant-entity-id) u10))
      })
    )

    (ok true)
  )
)

;; Get mission details
(define-read-only (get-mission (mission-id uint))
  (map-get? missions { mission-id: mission-id })
)

;; Get mission resources
(define-read-only (get-mission-resources (mission-id uint))
  (map-get? mission-resources { mission-id: mission-id })
)

;; Check orbital slot availability
(define-read-only (is-orbital-slot-available (time-slot uint) (orbital-zone (string-ascii 20)))
  (is-none (map-get? orbital-schedule { time-slot: time-slot, orbital-zone: orbital-zone }))
)
