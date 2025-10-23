(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_EVENT_NOT_FOUND (err u1002))
(define-constant ERR_TICKET_NOT_FOUND (err u1003))
(define-constant ERR_TICKET_NOT_FOR_SALE (err u1004))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u1005))
(define-constant ERR_EVENT_SOLD_OUT (err u1006))
(define-constant ERR_EVENT_ENDED (err u1007))
(define-constant ERR_TRANSFER_LIMIT_EXCEEDED (err u1008))
(define-constant ERR_PRICE_TOO_HIGH (err u1009))
(define-constant ERR_INVALID_EVENT_DATA (err u1010))
(define-constant ERR_COOLDOWN_ACTIVE (err u1011))
(define-constant ERR_INVALID_RECIPIENT (err u1012))
(define-constant ERR_INVALID_QUANTITY (err u1013))
(define-constant ERR_QUANTITY_EXCEEDS_AVAILABLE (err u1014))

(define-constant MAX_TRANSFERS u3)
(define-constant MAX_BULK_QUANTITY u10)
(define-constant COOLDOWN_BLOCKS u144)
(define-constant MAX_PRICE_MULTIPLIER u3)

(define-data-var next-event-id uint u1)
(define-data-var next-ticket-id uint u1)

(define-map Events uint {
  organizer: principal,
  name: (string-ascii 100),
  venue: (string-ascii 100),
  date: uint,
  price: uint,
  max-capacity: uint,
  tickets-sold: uint,
  active: bool
})

(define-map Tickets uint {
  event-id: uint,
  owner: principal,
  original-price: uint,
  transfer-count: uint,
  last-transfer-block: uint,
  for-sale: bool,
  sale-price: uint
})

(define-map OrganizerBalances principal uint)
(define-map EventRevenue uint uint)
(define-map UserTicketsByEvent { user: principal, event-id: uint } (list 50 uint))

(define-read-only (get-event (event-id uint))
  (map-get? Events event-id)
)

(define-read-only (get-ticket (ticket-id uint))
  (map-get? Tickets ticket-id)
)

(define-read-only (get-organizer-balance (organizer principal))
  (default-to u0 (map-get? OrganizerBalances organizer))
)

(define-read-only (get-event-revenue (event-id uint))
  (default-to u0 (map-get? EventRevenue event-id))
)

(define-read-only (get-next-event-id)
  (var-get next-event-id)
)

(define-read-only (get-next-ticket-id)
  (var-get next-ticket-id)
)

(define-read-only (get-user-tickets-for-event (user principal) (event-id uint))
  (default-to (list) (map-get? UserTicketsByEvent { user: user, event-id: event-id }))
)

(define-read-only (can-transfer-ticket (ticket-id uint))
  (match (map-get? Tickets ticket-id)
    ticket (let (
      (current-block stacks-block-height)
      (last-transfer (get last-transfer-block ticket))
      (transfer-count (get transfer-count ticket))
    )
      (and 
        (< transfer-count MAX_TRANSFERS)
        (>= (- current-block last-transfer) COOLDOWN_BLOCKS)
      )
    )
    false
  )
)

(define-read-only (is-event-active (event-id uint))
  (match (map-get? Events event-id)
    event (and 
      (get active event)
      (> (get date event) stacks-block-height)
    )
    false
  )
)

(define-public (create-event (name (string-ascii 100)) (venue (string-ascii 100)) (date uint) (price uint) (max-capacity uint))
  (let (
    (event-id (var-get next-event-id))
  )
    (asserts! (> (len name) u0) ERR_INVALID_EVENT_DATA)
    (asserts! (> (len venue) u0) ERR_INVALID_EVENT_DATA)
    (asserts! (> date stacks-block-height) ERR_INVALID_EVENT_DATA)
    (asserts! (> price u0) ERR_INVALID_EVENT_DATA)
    (asserts! (> max-capacity u0) ERR_INVALID_EVENT_DATA)
    
    (map-set Events event-id {
      organizer: tx-sender,
      name: name,
      venue: venue,
      date: date,
      price: price,
      max-capacity: max-capacity,
      tickets-sold: u0,
      active: true
    })
    
    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

(define-public (update-event-status (event-id uint) (active bool))
  (match (map-get? Events event-id)
    event (begin
      (asserts! (is-eq tx-sender (get organizer event)) ERR_NOT_AUTHORIZED)
      (map-set Events event-id (merge event { active: active }))
      (ok true)
    )
    ERR_EVENT_NOT_FOUND
  )
)

(define-public (buy-ticket (event-id uint))
  (match (map-get? Events event-id)
    event (let (
      (ticket-id (var-get next-ticket-id))
      (ticket-price (get price event))
      (tickets-sold (get tickets-sold event))
      (max-capacity (get max-capacity event))
    )
      (asserts! (is-event-active event-id) ERR_EVENT_ENDED)
      (asserts! (< tickets-sold max-capacity) ERR_EVENT_SOLD_OUT)
      (asserts! (>= (stx-get-balance tx-sender) ticket-price) ERR_INSUFFICIENT_PAYMENT)
      
      (try! (stx-transfer? ticket-price tx-sender (as-contract tx-sender)))
      
      (map-set Tickets ticket-id {
        event-id: event-id,
        owner: tx-sender,
        original-price: ticket-price,
        transfer-count: u0,
        last-transfer-block: stacks-block-height,
        for-sale: false,
        sale-price: u0
      })
      
      (map-set Events event-id (merge event { tickets-sold: (+ tickets-sold u1) }))
      (map-set EventRevenue event-id (+ (get-event-revenue event-id) ticket-price))
      (map-set OrganizerBalances (get organizer event) (+ (get-organizer-balance (get organizer event)) ticket-price))
      
      (let (
        (user-tickets (get-user-tickets-for-event tx-sender event-id))
      )
        (map-set UserTicketsByEvent { user: tx-sender, event-id: event-id } (unwrap-panic (as-max-len? (append user-tickets ticket-id) u50)))
      )
      
      (var-set next-ticket-id (+ ticket-id u1))
      (ok ticket-id)
    )
    ERR_EVENT_NOT_FOUND
  )
)

(define-public (list-ticket-for-sale (ticket-id uint) (sale-price uint))
  (match (map-get? Tickets ticket-id)
    ticket (begin
      (asserts! (is-eq tx-sender (get owner ticket)) ERR_NOT_AUTHORIZED)
      (asserts! (is-event-active (get event-id ticket)) ERR_EVENT_ENDED)
      (asserts! (<= sale-price (* (get original-price ticket) MAX_PRICE_MULTIPLIER)) ERR_PRICE_TOO_HIGH)
      (asserts! (> sale-price u0) ERR_INVALID_EVENT_DATA)
      
      (map-set Tickets ticket-id (merge ticket { 
        for-sale: true, 
        sale-price: sale-price 
      }))
      (ok true)
    )
    ERR_TICKET_NOT_FOUND
  )
)

(define-public (remove-ticket-from-sale (ticket-id uint))
  (match (map-get? Tickets ticket-id)
    ticket (begin
      (asserts! (is-eq tx-sender (get owner ticket)) ERR_NOT_AUTHORIZED)
      
      (map-set Tickets ticket-id (merge ticket { 
        for-sale: false, 
        sale-price: u0 
      }))
      (ok true)
    )
    ERR_TICKET_NOT_FOUND
  )
)

(define-public (buy-ticket-from-user (ticket-id uint))
  (match (map-get? Tickets ticket-id)
    ticket (let (
      (sale-price (get sale-price ticket))
      (current-owner (get owner ticket))
      (transfer-count (get transfer-count ticket))
    )
      (asserts! (get for-sale ticket) ERR_TICKET_NOT_FOR_SALE)
      (asserts! (is-event-active (get event-id ticket)) ERR_EVENT_ENDED)
      (asserts! (can-transfer-ticket ticket-id) ERR_TRANSFER_LIMIT_EXCEEDED)
      (asserts! (>= (stx-get-balance tx-sender) sale-price) ERR_INSUFFICIENT_PAYMENT)
      (asserts! (not (is-eq tx-sender current-owner)) ERR_INVALID_RECIPIENT)
      
      (try! (stx-transfer? sale-price tx-sender current-owner))
      
      (map-set Tickets ticket-id (merge ticket {
        owner: tx-sender,
        transfer-count: (+ transfer-count u1),
        last-transfer-block: stacks-block-height,
        for-sale: false,
        sale-price: u0
      }))
      
      (ok true)
    )
    ERR_TICKET_NOT_FOUND
  )
)

(define-public (transfer-ticket (ticket-id uint) (recipient principal))
  (match (map-get? Tickets ticket-id)
    ticket (begin
      (asserts! (is-eq tx-sender (get owner ticket)) ERR_NOT_AUTHORIZED)
      (asserts! (is-event-active (get event-id ticket)) ERR_EVENT_ENDED)
      (asserts! (can-transfer-ticket ticket-id) ERR_TRANSFER_LIMIT_EXCEEDED)
      (asserts! (not (is-eq tx-sender recipient)) ERR_INVALID_RECIPIENT)
      
      (map-set Tickets ticket-id (merge ticket {
        owner: recipient,
        transfer-count: (+ (get transfer-count ticket) u1),
        last-transfer-block: stacks-block-height,
        for-sale: false,
        sale-price: u0
      }))
      
      (ok true)
    )
    ERR_TICKET_NOT_FOUND
  )
)

(define-public (withdraw-revenue (event-id uint))
  (match (map-get? Events event-id)
    event (let (
      (organizer (get organizer event))
      (balance (get-organizer-balance organizer))
    )
      (asserts! (is-eq tx-sender organizer) ERR_NOT_AUTHORIZED)
      (asserts! (> balance u0) ERR_INSUFFICIENT_PAYMENT)
      
      (try! (as-contract (stx-transfer? balance tx-sender organizer)))
      (map-set OrganizerBalances organizer u0)
      
      (ok balance)
    )
    ERR_EVENT_NOT_FOUND
  )
)

(define-public (buy-tickets-bulk (event-id uint) (quantity uint))
  (match (map-get? Events event-id)
    event (let (
      (ticket-price (get price event))
      (tickets-sold (get tickets-sold event))
      (max-capacity (get max-capacity event))
      (total-cost (* ticket-price quantity))
      (available-tickets (- max-capacity tickets-sold))
    )
      (asserts! (is-event-active event-id) ERR_EVENT_ENDED)
      (asserts! (and (> quantity u0) (<= quantity MAX_BULK_QUANTITY)) ERR_INVALID_QUANTITY)
      (asserts! (<= quantity available-tickets) ERR_QUANTITY_EXCEEDS_AVAILABLE)
      (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR_INSUFFICIENT_PAYMENT)
      
      (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
      
      (map-set Events event-id (merge event { tickets-sold: (+ tickets-sold quantity) }))
      (map-set EventRevenue event-id (+ (get-event-revenue event-id) total-cost))
      (map-set OrganizerBalances (get organizer event) (+ (get-organizer-balance (get organizer event)) total-cost))
      
      (let (
        (result (fold create-ticket-fold (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) { event-id: event-id, price: ticket-price, buyer: tx-sender, count: u0, quantity: quantity, tickets: (list) }))
      )
        (ok (get tickets result))
      )
    )
    ERR_EVENT_NOT_FOUND
  )
)

(define-private (create-ticket-fold (index uint) (state { event-id: uint, price: uint, buyer: principal, count: uint, quantity: uint, tickets: (list 10 uint) }))
  (let (
    (current-count (get count state))
    (target-quantity (get quantity state))
  )
    (if (< current-count target-quantity)
      (let (
        (ticket-id (var-get next-ticket-id))
        (event-id (get event-id state))
        (ticket-price (get price state))
        (buyer (get buyer state))
      )
        (map-set Tickets ticket-id {
          event-id: event-id,
          owner: buyer,
          original-price: ticket-price,
          transfer-count: u0,
          last-transfer-block: stacks-block-height,
          for-sale: false,
          sale-price: u0
        })
        
        (let (
          (user-tickets (get-user-tickets-for-event buyer event-id))
        )
          (map-set UserTicketsByEvent { user: buyer, event-id: event-id } (unwrap-panic (as-max-len? (append user-tickets ticket-id) u50)))
        )
        
        (var-set next-ticket-id (+ ticket-id u1))
        
        (merge state {
          count: (+ current-count u1),
          tickets: (unwrap-panic (as-max-len? (append (get tickets state) ticket-id) u10))
        })
      )
      state
    )
  )
)

(define-public (emergency-withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
    (ok true)
  )
)
