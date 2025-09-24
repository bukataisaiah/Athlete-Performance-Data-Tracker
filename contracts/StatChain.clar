(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-ATHLETE-NOT-FOUND (err u1002))
(define-constant ERR-SEASON-NOT-FOUND (err u1003))
(define-constant ERR-SEASON-CLOSED (err u1004))
(define-constant ERR-ALREADY-VERIFIED (err u1005))
(define-constant ERR-INVALID-STATS (err u1006))
(define-constant ERR-SEASON-ACTIVE (err u1007))
(define-constant ERR-ATHLETE-EXISTS (err u1008))
(define-constant ERR-PERFORMANCE-NOT-FOUND (err u1009))
(define-constant ERR-INVALID-SEASON (err u1010))

(define-data-var next-athlete-id uint u1)
(define-data-var next-season-id uint u1)
(define-data-var next-performance-id uint u1)

(define-map athletes
  uint
  {
    principal: principal,
    name: (string-ascii 50),
    sport: (string-ascii 20),
    team: (string-ascii 30),
    position: (string-ascii 20),
    registered-at: uint
  }
)

(define-map athlete-principals
  principal
  uint
)

(define-map seasons
  uint
  {
    name: (string-ascii 30),
    start-height: uint,
    end-height: (optional uint),
    sport: (string-ascii 20),
    is-active: bool,
    created-at: uint
  }
)

(define-map performances
  uint
  {
    athlete-id: uint,
    season-id: uint,
    game-date: uint,
    opponent: (string-ascii 30),
    goals: uint,
    assists: uint,
    points: uint,
    games-played: uint,
    minutes-played: uint,
    verified: bool,
    verified-by: (optional principal),
    recorded-at: uint
  }
)

(define-map season-stats
  {athlete-id: uint, season-id: uint}
  {
    total-goals: uint,
    total-assists: uint,
    total-points: uint,
    total-games: uint,
    total-minutes: uint,
    last-updated: uint
  }
)

(define-map authorized-scorers
  principal
  bool
)

(define-map athlete-season-performances
  {athlete-id: uint, season-id: uint}
  (list 100 uint)
)

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-scorer)
  (or (is-contract-owner) (default-to false (map-get? authorized-scorers tx-sender)))
)

(define-read-only (get-athlete (athlete-id uint))
  (map-get? athletes athlete-id)
)

(define-read-only (get-athlete-by-principal (athlete-principal principal))
  (match (map-get? athlete-principals athlete-principal)
    athlete-id (map-get? athletes athlete-id)
    none
  )
)

(define-read-only (get-season (season-id uint))
  (map-get? seasons season-id)
)

(define-read-only (get-performance (performance-id uint))
  (map-get? performances performance-id)
)

(define-read-only (get-season-stats (athlete-id uint) (season-id uint))
  (map-get? season-stats {athlete-id: athlete-id, season-id: season-id})
)

(define-read-only (get-athlete-season-performances (athlete-id uint) (season-id uint))
  (default-to (list) (map-get? athlete-season-performances {athlete-id: athlete-id, season-id: season-id}))
)

(define-read-only (is-season-active (season-id uint))
  (match (map-get? seasons season-id)
    season-data (get is-active season-data)
    false
  )
)

(define-read-only (get-current-block-height)
  stacks-block-height
)

(define-public (add-authorized-scorer (scorer principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-scorers scorer true))
  )
)

(define-public (remove-authorized-scorer (scorer principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-scorers scorer))
  )
)

(define-public (register-athlete (name (string-ascii 50)) (sport (string-ascii 20)) (team (string-ascii 30)) (position (string-ascii 20)))
  (let
    (
      (athlete-id (var-get next-athlete-id))
      (current-height stacks-block-height)
    )
    (asserts! (is-none (map-get? athlete-principals tx-sender)) ERR-ATHLETE-EXISTS)
    (map-set athletes athlete-id {
      principal: tx-sender,
      name: name,
      sport: sport,
      team: team,
      position: position,
      registered-at: current-height
    })
    (map-set athlete-principals tx-sender athlete-id)
    (var-set next-athlete-id (+ athlete-id u1))
    (ok athlete-id)
  )
)

(define-public (create-season (name (string-ascii 30)) (sport (string-ascii 20)) (duration-blocks uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (let
      (
        (season-id (var-get next-season-id))
        (current-height stacks-block-height)
        (end-height (+ current-height duration-blocks))
      )
      (map-set seasons season-id {
        name: name,
        start-height: current-height,
        end-height: (some end-height),
        sport: sport,
        is-active: true,
        created-at: current-height
      })
      (var-set next-season-id (+ season-id u1))
      (ok season-id)
    )
  )
)

(define-public (close-season (season-id uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (match (map-get? seasons season-id)
      season-data
      (begin
        (asserts! (get is-active season-data) ERR-SEASON-CLOSED)
        (map-set seasons season-id (merge season-data {
          is-active: false,
          end-height: (some stacks-block-height)
        }))
        (ok true)
      )
      ERR-SEASON-NOT-FOUND
    )
  )
)

(define-public (record-performance
    (athlete-id uint)
    (season-id uint)
    (opponent (string-ascii 30))
    (goals uint)
    (assists uint)
    (points uint)
    (games-played uint)
    (minutes-played uint)
  )
  (begin
    (asserts! (is-authorized-scorer) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? athletes athlete-id)) ERR-ATHLETE-NOT-FOUND)
    (asserts! (is-season-active season-id) ERR-SEASON-CLOSED)
    (asserts! (> games-played u0) ERR-INVALID-STATS)
    (let
      (
        (performance-id (var-get next-performance-id))
        (current-height stacks-block-height)
        (current-stats (default-to
          {total-goals: u0, total-assists: u0, total-points: u0, total-games: u0, total-minutes: u0, last-updated: u0}
          (map-get? season-stats {athlete-id: athlete-id, season-id: season-id})
        ))
        (current-performances (default-to (list) (map-get? athlete-season-performances {athlete-id: athlete-id, season-id: season-id})))
      )
      (map-set performances performance-id {
        athlete-id: athlete-id,
        season-id: season-id,
        game-date: current-height,
        opponent: opponent,
        goals: goals,
        assists: assists,
        points: points,
        games-played: games-played,
        minutes-played: minutes-played,
        verified: false,
        verified-by: none,
        recorded-at: current-height
      })
      (map-set season-stats {athlete-id: athlete-id, season-id: season-id} {
        total-goals: (+ (get total-goals current-stats) goals),
        total-assists: (+ (get total-assists current-stats) assists),
        total-points: (+ (get total-points current-stats) points),
        total-games: (+ (get total-games current-stats) games-played),
        total-minutes: (+ (get total-minutes current-stats) minutes-played),
        last-updated: current-height
      })
      (map-set athlete-season-performances {athlete-id: athlete-id, season-id: season-id}
        (unwrap! (as-max-len? (append current-performances performance-id) u100) ERR-INVALID-STATS)
      )
      (var-set next-performance-id (+ performance-id u1))
      (ok performance-id)
    )
  )
)

(define-public (verify-performance (performance-id uint))
  (begin
    (asserts! (is-authorized-scorer) ERR-NOT-AUTHORIZED)
    (match (map-get? performances performance-id)
      performance-data
      (begin
        (asserts! (not (get verified performance-data)) ERR-ALREADY-VERIFIED)
        (map-set performances performance-id (merge performance-data {
          verified: true,
          verified-by: (some tx-sender)
        }))
        (ok true)
      )
      ERR-PERFORMANCE-NOT-FOUND
    )
  )
)

(define-public (update-athlete-info (name (string-ascii 50)) (team (string-ascii 30)) (position (string-ascii 20)))
  (match (map-get? athlete-principals tx-sender)
    athlete-id
    (match (map-get? athletes athlete-id)
      athlete-data
      (begin
        (map-set athletes athlete-id (merge athlete-data {
          name: name,
          team: team,
          position: position
        }))
        (ok true)
      )
      ERR-ATHLETE-NOT-FOUND
    )
    ERR-ATHLETE-NOT-FOUND
  )
)