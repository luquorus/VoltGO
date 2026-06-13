# DOC 3 — Database Schema

---

## 3.1 Entity Overview

The database consists of **46 JPA entity classes** organized into 11 functional domains, persisted via **Spring Data JPA** to **PostgreSQL 16** with **PostGIS** extension. All tables have `created_at` / `updated_at` timestamps managed by JPA `@CreationTimestamp` / `@UpdateTimestamp` annotations.

---

## 3.2 Full DBML Schema (dbdiagram.io format)

```dbml
// VoltGO — Full Database Schema
// Engine: PostgreSQL 16 + PostGIS

// ─────────────────────────────────────────────
// ENUMS (defined as PostgreSQL enum types)
// ─────────────────────────────────────────────

Enum user_account_role {
  EV_USER
  COLLABORATOR
  ADMIN
}

Enum user_account_status {
  ACTIVE
  PENDING_COLLABORATOR
  BANNED
}

Enum station_status {
  PENDING
  PUBLISHED
  REJECTED
}

Enum station_visibility {
  PUBLIC
  PRIVATE
  HIDDEN
}

Enum change_request_status {
  PENDING
  APPROVED
  REJECTED
  PUBLISHED
}

Enum change_request_type {
  CREATE_STATION
  UPDATE_STATION
  DELETE_STATION
}

Enum booking_status {
  HOLD
  CONFIRMED
  CANCELLED
  EXPIRED
}

Enum payment_intent_status {
  CREATED
  SUCCEEDED
  FAILED
}

Enum swap_reservation_status {
  RESERVED
  CONFIRMED
  SWAPPING
  COMPLETED
  CANCELLED
  EXPIRED
}

Enum swap_payment_status {
  PENDING
  PAID
  REFUNDED
  FAILED
}

Enum swap_session_status {
  PENDING
  ACTIVE
  COMPLETED
  EXPIRED
}

Enum slot_status {
  AVAILABLE
  OCCUPIED
  MAINTENANCE
}

Enum verification_task_status {
  PENDING
  ASSIGNED
  COMPLETED
  EXPIRED
  CANCELLED
}

Enum verification_review_result {
  VERIFIED
  REJECTED
  REQUIRES_RESUBMISSION
}

Enum notification_type {
  PUSH
  EMAIL
  IN_APP
}

Enum referral_status {
  PENDING
  COMPLETED
  CANCELLED
}

Enum contract_status {
  ACTIVE
  EXPIRED
  TERMINATED
}

Enum collaborator_registration_status {
  PENDING
  APPROVED
  REJECTED
}

Enum charger_unit_status {
  AVAILABLE
  OCCUPIED
  OUT_OF_SERVICE
}

Enum battery_swap_trust_level {
  MINIMAL
  LOW
  MEDIUM
  HIGH
}

Enum voucher_definition_type {
  BOOKING_DISCOUNT
  SWAP_DISCOUNT
  FREE_MINUTES
  CASHBACK
}

Enum voucher_redemption_status {
  ACTIVE
  USED
  EXPIRED
}

// ─────────────────────────────────────────────
// DOMAIN: Authentication & User Management
// ─────────────────────────────────────────────

Table user_account {
  id UUID [pk, default: gen_random_uuid()]
  email VARCHAR(255) [unique, not null]
  name VARCHAR(255)
  phone VARCHAR(20)
  password_hash VARCHAR(255) [not null]
  role user_account_role [not null]
  status user_account_status [not null, default: 'ACTIVE']
  fcm_token TEXT
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
  last_login_at TIMESTAMPTZ
}

Table push_token {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  token TEXT [not null]
  platform VARCHAR(20) [not null] // 'android', 'ios', 'web'
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table notification_preference {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null, unique]
  push_enabled BOOLEAN [default: true]
  email_enabled BOOLEAN [default: true]
  booking_reminders BOOLEAN [default: true]
  loyalty_alerts BOOLEAN [default: true]
}

Table ev_user_notification {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  type notification_type [not null]
  title VARCHAR(255) [not null]
  body TEXT
  data JSONB
  read BOOLEAN [default: false, not null]
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table collaborator_notification {
  id UUID [pk, default: gen_random_uuid()]
  recipient_id UUID [ref: > user_account.id, not null]
  type notification_type [not null]
  title VARCHAR(255) [not null]
  body TEXT
  data JSONB
  read BOOLEAN [default: false, not null]
  created_at TIMESTAMPTZ [not null, default: now()]
}

// ─────────────────────────────────────────────
// DOMAIN: Station Management
// ─────────────────────────────────────────────

Table station {
  id UUID [pk, default: gen_random_uuid()]
  provider_id UUID [ref: > user_account.id, not null]
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table station_version {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  version INT [not null]
  name VARCHAR(255) [not null]
  address VARCHAR(500)
  latitude DOUBLE [not null]
  longitude DOUBLE [not null]
  location GEOGRAPHY(POINT, 4326) [not null] // PostGIS geography column
  visibility station_visibility [default: 'PUBLIC']
  operating_hours VARCHAR(100)
  parking_fee BIGINT // VND, nullable
  status station_status [default: 'PENDING']
  published_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table station_service {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  service_type VARCHAR(50) [not null] // 'AC_NORMAL', 'AC_FAST', 'DC_FAST', 'BATTERY_SWAP'
  power_kw DOUBLE
  price_per_kwh BIGINT // VND per kWh
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table charging_port {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  power_type VARCHAR(30) [not null] // 'AC', 'DC'
  connector_type VARCHAR(30) [not null] // 'Type2', 'CCS', 'CHAdeMO', 'GB/T'
  power_kw DOUBLE [not null]
  status VARCHAR(20) [default: 'AVAILABLE']
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table charger_unit {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  name VARCHAR(100)
  power_kw DOUBLE [not null]
  price_per_slot BIGINT [not null] // VND per 30-min slot
  status charger_unit_status [default: 'AVAILABLE']
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

// ─────────────────────────────────────────────
// DOMAIN: Booking & Payment
// ─────────────────────────────────────────────

Table booking {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  station_id UUID [ref: > station.id, not null]
  charger_unit_id UUID [ref: > charger_unit.id, not null]
  start_time TIMESTAMPTZ [not null]
  end_time TIMESTAMPTZ [not null]
  status booking_status [default: 'HOLD', not null]
  hold_expires_at TIMESTAMPTZ
  price_snapshot BIGINT [not null] // VND, frozen at booking time
  voucher_redemption_id UUID [ref: > voucher_redemption.id]
  payment_intent_id UUID [ref: > payment_intent.id]
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table payment_intent {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  amount BIGINT [not null] // VND
  currency VARCHAR(3) [default: 'VND']
  status payment_intent_status [default: 'CREATED', not null]
  voucher_redemption_id UUID [ref: > voucher_redemption.id]
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

// ─────────────────────────────────────────────
// DOMAIN: Battery Swap
// ─────────────────────────────────────────────

Table battery_swap_station_state {
  station_id UUID [pk, ref: > station.id, not null]
  total_batteries INT [not null, default: 0]
  available_batteries INT [not null, default: 0]
  avg_charge_power_kw DOUBLE [not null]
  operating_hours VARCHAR(100) [default: '06:00-22:00']
  parking_fee BIGINT // VND
  base_price_vnd BIGINT [not null, default: 5000]
  last_updated_at TIMESTAMPTZ [not null, default: now()]
}

Table swap_pile {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  name VARCHAR(100) [not null]
  type VARCHAR(50) [not null] // 'STANDARD', 'FAST', 'ULTRA'
  status VARCHAR(20) [default: 'ACTIVE']
  slot_count INT [not null]
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table battery_slot {
  id UUID [pk, default: gen_random_uuid()]
  pile_id UUID [ref: > swap_pile.id, not null]
  slot_index INT [not null] // 1-based index within pile
  status slot_status [default: 'AVAILABLE', not null]
  battery_charge_percent INT [default: 0] // 0-100
  battery_capacity_kwh DOUBLE [default: 0.0]
  estimated_full_at TIMESTAMPTZ
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table battery_swap_reservation {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  station_id UUID [ref: > station.id, not null]
  slot_id UUID [ref: > battery_slot.id]
  status swap_reservation_status [default: 'RESERVED', not null]
  swap_code VARCHAR(6) // 6-digit numeric code, generated at START
  base_price_vnd BIGINT [not null]
  payment_status swap_payment_status [default: 'PENDING', not null]
  payment_id UUID [ref: > swap_payment.id]
  reserved_at TIMESTAMPTZ [not null, default: now()]
  confirmed_arrival_at TIMESTAMPTZ
  started_at TIMESTAMPTZ
  completed_at TIMESTAMPTZ
  expires_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table swap_payment {
  id UUID [pk, default: gen_random_uuid()]
  reservation_id UUID [ref: > battery_swap_reservation.id, not null]
  amount BIGINT [not null] // VND
  status swap_payment_status [default: 'PENDING', not null]
  payment_method VARCHAR(50) // 'WALLET', 'CASH', 'VNPAY', etc.
  paid_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table swap_session {
  id UUID [pk, default: gen_random_uuid()]
  reservation_id UUID [ref: > battery_swap_reservation.id, not null]
  swap_code VARCHAR(6) [not null]
  status swap_session_status [default: 'PENDING', not null]
  expires_at TIMESTAMPTZ [not null]
  started_at TIMESTAMPTZ
  completed_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table charging_session {
  id UUID [pk, default: gen_random_uuid()]
  slot_id UUID [ref: > battery_slot.id, not null]
  status VARCHAR(20) [default: 'ACTIVE', not null]
  charge_start_percent INT [not null]
  charge_end_percent INT
  started_at TIMESTAMPTZ [not null, default: now()]
  completed_at TIMESTAMPTZ
}

Table battery_event {
  id UUID [pk, default: gen_random_uuid()]
  slot_id UUID [ref: > battery_slot.id, not null]
  event_type VARCHAR(50) [not null] // 'INSERTED', 'REMOVED', 'CHARGE_START', 'CHARGE_COMPLETE', 'RESERVED'
  charge_percent INT
  timestamp TIMESTAMPTZ [not null, default: now()]
}

Table battery_swap_station_device {
  station_id UUID [pk, ref: > station.id, not null]
  device_key VARCHAR(64) [unique, not null]
  device_name VARCHAR(100)
  created_at TIMESTAMPTZ [not null, default: now()]
  last_seen_at TIMESTAMPTZ
}

Table battery_swap_station_version {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  version INT [not null]
  name VARCHAR(255) [not null]
  address VARCHAR(500)
  latitude DOUBLE [not null]
  longitude DOUBLE [not null]
  operating_hours VARCHAR(100)
  total_batteries INT [not null]
  avg_charge_power_kw DOUBLE [not null]
  base_price_vnd BIGINT [not null]
  status station_status [default: 'PENDING']
  published_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table battery_swap_pile_template {
  id UUID [pk, default: gen_random_uuid()]
  station_version_id UUID [ref: > battery_swap_station_version.id, not null]
  name VARCHAR(100) [not null]
  type VARCHAR(50) [not null]
  slot_count INT [not null]
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table battery_swap_slot_template {
  id UUID [pk, default: gen_random_uuid()]
  pile_template_id UUID [ref: > battery_swap_pile_template.id, not null]
  slot_index INT [not null]
  capacity_kwh DOUBLE [not null]
}

// ─────────────────────────────────────────────
// DOMAIN: Change Requests & Governance
// ─────────────────────────────────────────────

Table change_request {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  submitted_by UUID [ref: > user_account.id, not null]
  change_type change_request_type [not null]
  status change_request_status [default: 'PENDING', not null]
  proposed_data JSONB [not null] // Snapshot of proposed station data
  risk_score INT
  risk_level VARCHAR(20)
  risk_factors JSONB
  reviewed_by UUID [ref: > user_account.id]
  reviewed_at TIMESTAMPTZ
  rejection_reason TEXT
  published_version_id UUID [ref: > station_version.id]
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table report_issue {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  reporter_id UUID [ref: > user_account.id, not null]
  category VARCHAR(50) [not null] // 'WRONG_LOCATION', 'BROKEN_CHARGER', 'WRONG_INFO', 'OTHER'
  description TEXT
  status VARCHAR(20) [default: 'OPEN']
  resolution TEXT
  resolved_by UUID [ref: > user_account.id]
  resolved_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table audit_log {
  id UUID [pk, default: gen_random_uuid()]
  entity_type VARCHAR(100) [not null] // e.g., 'Station', 'Booking'
  entity_id UUID [not null]
  action VARCHAR(50) [not null] // 'CREATE', 'UPDATE', 'DELETE', 'APPROVE', 'REJECT'
  actor_id UUID [ref: > user_account.id]
  details JSONB
  ip_address VARCHAR(45)
  created_at TIMESTAMPTZ [not null, default: now()]
}

// ─────────────────────────────────────────────
// DOMAIN: Trust & Risk
// ─────────────────────────────────────────────

Table station_trust {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null, unique]
  score DOUBLE [default: 50.0] // 0-100
  accuracy_factor DOUBLE [default: 0.0]
  uptime_factor DOUBLE [default: 0.0]
  issue_factor DOUBLE [default: 0.0]
  rating_factor DOUBLE [default: 0.0]
  verification_factor DOUBLE [default: 0.0]
  last_calculated_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table battery_swap_trust {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null, unique]
  score DOUBLE [default: 50.0] // 0-100
  risk_level battery_swap_trust_level [default: 'MEDIUM']
  location_risk DOUBLE [default: 0.0]
  data_accuracy_risk DOUBLE [default: 0.0]
  operation_risk DOUBLE [default: 0.0]
  financial_risk DOUBLE [default: 0.0]
  safety_risk DOUBLE [default: 0.0]
  provider_trust_risk DOUBLE [default: 0.0]
  triggered_reasons JSONB // Array of BatterySwapRiskReason
  last_calculated_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

// ─────────────────────────────────────────────
// DOMAIN: Collaborator Management
// ─────────────────────────────────────────────

Table collaborator_profile {
  id UUID [pk, default: gen_random_uuid()]
  user_account_id UUID [ref: > user_account.id, not null, unique]
  full_name VARCHAR(255) [not null]
  id_card_number VARCHAR(20)
  id_card_front_image_key VARCHAR(500)
  id_card_back_image_key VARCHAR(500)
  avatar_image_key VARCHAR(500)
  latitude DOUBLE
  longitude DOUBLE
  current_location GEOGRAPHY(POINT, 4326)
  last_checkin_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table contract {
  id UUID [pk, default: gen_random_uuid()]
  collaborator_id UUID [ref: > collaborator_profile.id, not null]
  contract_type VARCHAR(50) [not null] // 'STATION_VERIFICATION', 'BATTERY_SWAP_VERIFICATION'
  status contract_status [default: 'ACTIVE']
  start_date DATE [not null]
  end_date DATE [not null]
  terms TEXT
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table collaborator_registration_request {
  id UUID [pk, default: gen_random_uuid()]
  user_account_id UUID [ref: > user_account.id, not null, unique]
  full_name VARCHAR(255) [not null]
  email VARCHAR(255) [not null]
  phone VARCHAR(20) [not null]
  id_card_number VARCHAR(20) [not null]
  id_card_front_key VARCHAR(500)
  id_card_back_key VARCHAR(500)
  address VARCHAR(500)
  status collaborator_registration_status [default: 'PENDING']
  reviewed_by UUID [ref: > user_account.id]
  reviewed_at TIMESTAMPTZ
  rejection_reason TEXT
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table referral {
  id UUID [pk, default: gen_random_uuid()]
  referrer_id UUID [ref: > user_account.id, not null]
  referee_id UUID [ref: > user_account.id, not null]
  referral_code VARCHAR(20) [not null]
  status referral_status [default: 'PENDING']
  bonus_points_awarded INT [default: 0]
  referred_at TIMESTAMPTZ [not null, default: now()]
  completed_at TIMESTAMPTZ
}

// ─────────────────────────────────────────────
// DOMAIN: Verification
// ─────────────────────────────────────────────

Table verification_task {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  assigned_to UUID [ref: > collaborator_profile.id]
  task_type VARCHAR(50) [not null] // 'STATION_VERIFICATION', 'BATTERY_SWAP_VERIFICATION'
  status verification_task_status [default: 'PENDING']
  sla_due_at TIMESTAMPTZ [not null]
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table verification_checkin {
  id UUID [pk, default: gen_random_uuid()]
  task_id UUID [ref: > verification_task.id, not null]
  collaborator_id UUID [ref: > collaborator_profile.id, not null]
  checked_in_at TIMESTAMPTZ [not null, default: now()]
  latitude DOUBLE [not null]
  longitude DOUBLE [not null]
  distance_meters DOUBLE [not null] // Haversine distance to station
}

Table verification_evidence {
  id UUID [pk, default: gen_random_uuid()]
  task_id UUID [ref: > verification_task.id, not null]
  photo_type VARCHAR(50) [not null] // 'EXTERIOR', 'CHARGER', 'SIGNAGE', 'PANORAMA'
  file_key VARCHAR(500) [not null] // MinIO object key
  uploaded_at TIMESTAMPTZ [not null, default: now()]
}

Table verification_review {
  id UUID [pk, default: gen_random_uuid()]
  task_id UUID [ref: > verification_task.id, not null, unique]
  result verification_review_result [not null]
  notes TEXT
  reviewed_by UUID [ref: > user_account.id]
  reviewed_at TIMESTAMPTZ [not null, default: now()]
}

// ─────────────────────────────────────────────
// DOMAIN: Loyalty & Rewards
// ─────────────────────────────────────────────

Table loyalty_user_profile {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null, unique]
  total_points INT [default: 0, not null]
  tier VARCHAR(20) [default: 'BRONZE'] // BRONZE, SILVER, GOLD, PLATINUM, DIAMOND
  created_at TIMESTAMPTZ [not null, default: now()]
  updated_at TIMESTAMPTZ [not null, default: now()]
}

Table loyalty_point_transaction {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  points INT [not null] // Positive for earn, negative for redeem
  source VARCHAR(50) [not null] // 'BOOKING_COMPLETE', 'REFERRAL_SIGNUP', 'REFERRAL_COMPLETE', 'RATING_BONUS', 'VOUCHER_REDEEM', 'ADMIN_ADJUSTMENT'
  reference_id UUID // booking_id, referral_id, etc.
  description TEXT
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table loyalty_badge {
  id UUID [pk, default: gen_random_uuid()]
  code VARCHAR(50) [unique, not null]
  name VARCHAR(100) [not null]
  description TEXT
  icon_url VARCHAR(500)
  tier VARCHAR(20) [not null] // BRONZE, SILVER, GOLD, PLATINUM, DIAMOND
  points_threshold INT [not null]
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table user_badge {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  badge_id UUID [ref: > loyalty_badge.id, not null]
  earned_at TIMESTAMPTZ [not null, default: now()]
}

Table station_rating {
  id UUID [pk, default: gen_random_uuid()]
  station_id UUID [ref: > station.id, not null]
  user_id UUID [ref: > user_account.id, not null]
  rating INT [not null] // 1-5
  comment TEXT
  status VARCHAR(20) [default: 'PENDING'] // PENDING, PUBLISHED, REJECTED
  moderated_by UUID [ref: > user_account.id]
  moderated_at TIMESTAMPTZ
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table rating_eligibility {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  station_id UUID [ref: > station.id, not null]
  eligible BOOLEAN [default: false, not null]
  reason VARCHAR(100)
  last_checked_at TIMESTAMPTZ [not null, default: now()]
}

Table voucher_definition {
  id UUID [pk, default: gen_random_uuid()]
  code VARCHAR(50) [unique, not null]
  name VARCHAR(255) [not null]
  description TEXT
  voucher_type voucher_definition_type [not null]
  point_cost INT [not null]
  discount_percent INT
  discount_amount_vnd BIGINT
  min_booking_amount_vnd BIGINT
  max_discount_vnd BIGINT
  valid_from TIMESTAMPTZ
  valid_until TIMESTAMPTZ
  total_quantity INT
  redeemed_count INT [default: 0]
  active BOOLEAN [default: true]
  created_at TIMESTAMPTZ [not null, default: now()]
}

Table voucher_redemption {
  id UUID [pk, default: gen_random_uuid()]
  user_id UUID [ref: > user_account.id, not null]
  voucher_definition_id UUID [ref: > voucher_definition.id, not null]
  points_spent INT [not null]
  status voucher_redemption_status [default: 'ACTIVE']
  redeemed_at TIMESTAMPTZ [not null, default: now()]
  expires_at TIMESTAMPTZ
  used_at TIMESTAMPTZ
  booking_id UUID [ref: > booking.id]
}
```

---

## 3.3 Entity-Relationship Diagram (PlantUML)

```plantuml
@startuml
skinparam packageStyle rectangle

' ── User & Auth ──
entity "user_account\n(user_account)" as ua {
  * id : UUID [PK]
  --
  email : VARCHAR(255) [UNIQUE, NOT NULL]
  name : VARCHAR(255)
  phone : VARCHAR(20)
  password_hash : VARCHAR(255) [NOT NULL]
  * role : user_account_role [NOT NULL]
  * status : user_account_status [NOT NULL]
  fcm_token : TEXT
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
  last_login_at : TIMESTAMPTZ
}

entity "push_token" as pt {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * token : TEXT [NOT NULL]
  * platform : VARCHAR(20) [NOT NULL]
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "notification_preference" as np {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account, UNIQUE]
  push_enabled : BOOLEAN
  email_enabled : BOOLEAN
  booking_reminders : BOOLEAN
  loyalty_alerts : BOOLEAN
}

entity "ev_user_notification" as eun {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * type : notification_type
  * title : VARCHAR(255)
  body : TEXT
  data : JSONB
  read : BOOLEAN [DEFAULT false]
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "collaborator_notification" as cn {
  * id : UUID [PK]
  --
  * recipient_id : UUID [FK → user_account]
  * type : notification_type
  * title : VARCHAR(255)
  body : TEXT
  data : JSONB
  read : BOOLEAN [DEFAULT false]
  created_at : TIMESTAMPTZ [NOT NULL]
}

' ── Station Core ──
entity "station" as st {
  * id : UUID [PK]
  --
  * provider_id : UUID [FK → user_account]
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "station_version" as sv {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * version : INT [NOT NULL]
  * name : VARCHAR(255)
  address : VARCHAR(500)
  latitude : DOUBLE [NOT NULL]
  longitude : DOUBLE [NOT NULL]
  * location : GEOGRAPHY(POINT, 4326)
  visibility : station_visibility
  operating_hours : VARCHAR(100)
  parking_fee : BIGINT
  status : station_status
  published_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "station_service" as ss {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * service_type : VARCHAR(50)
  power_kw : DOUBLE
  price_per_kwh : BIGINT
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "charging_port" as cp {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * power_type : VARCHAR(30)
  * connector_type : VARCHAR(30)
  * power_kw : DOUBLE
  status : VARCHAR(20)
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "charger_unit" as cu {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  name : VARCHAR(100)
  * power_kw : DOUBLE
  * price_per_slot : BIGINT
  status : charger_unit_status
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

' ── Booking & Payment ──
entity "booking" as bk {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * station_id : UUID [FK → station]
  * charger_unit_id : UUID [FK → charger_unit]
  * start_time : TIMESTAMPTZ
  * end_time : TIMESTAMPTZ
  * status : booking_status
  hold_expires_at : TIMESTAMPTZ
  * price_snapshot : BIGINT
  voucher_redemption_id : UUID [FK → voucher_redemption]
  payment_intent_id : UUID [FK → payment_intent]
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "payment_intent" as pi {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * amount : BIGINT
  currency : VARCHAR(3)
  * status : payment_intent_status
  voucher_redemption_id : UUID [FK → voucher_redemption]
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

' ── Battery Swap ──
entity "battery_swap_station_state" as bsss {
  * station_id : UUID [PK, FK → station]
  --
  * total_batteries : INT
  * available_batteries : INT
  * avg_charge_power_kw : DOUBLE
  operating_hours : VARCHAR(100)
  parking_fee : BIGINT
  * base_price_vnd : BIGINT
  last_updated_at : TIMESTAMPTZ
}

entity "swap_pile" as sp {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * name : VARCHAR(100)
  * type : VARCHAR(50)
  status : VARCHAR(20)
  * slot_count : INT
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "battery_slot" as bsl {
  * id : UUID [PK]
  --
  * pile_id : UUID [FK → swap_pile]
  * slot_index : INT
  * status : slot_status
  battery_charge_percent : INT
  battery_capacity_kwh : DOUBLE
  estimated_full_at : TIMESTAMPTZ
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "battery_swap_reservation" as bsr {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * station_id : UUID [FK → station]
  slot_id : UUID [FK → battery_slot]
  * status : swap_reservation_status
  swap_code : VARCHAR(6)
  * base_price_vnd : BIGINT
  payment_status : swap_payment_status
  payment_id : UUID [FK → swap_payment]
  reserved_at : TIMESTAMPTZ
  confirmed_arrival_at : TIMESTAMPTZ
  started_at : TIMESTAMPTZ
  completed_at : TIMESTAMPTZ
  expires_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "swap_payment" as spp {
  * id : UUID [PK]
  --
  * reservation_id : UUID [FK → battery_swap_reservation]
  * amount : BIGINT
  * status : swap_payment_status
  payment_method : VARCHAR(50)
  paid_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "swap_session" as sss {
  * id : UUID [PK]
  --
  * reservation_id : UUID [FK → battery_swap_reservation]
  * swap_code : VARCHAR(6)
  * status : swap_session_status
  * expires_at : TIMESTAMPTZ
  started_at : TIMESTAMPTZ
  completed_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "charging_session" as css {
  * id : UUID [PK]
  --
  * slot_id : UUID [FK → battery_slot]
  status : VARCHAR(20)
  * charge_start_percent : INT
  charge_end_percent : INT
  started_at : TIMESTAMPTZ [NOT NULL]
  completed_at : TIMESTAMPTZ
}

entity "battery_event" as be {
  * id : UUID [PK]
  --
  * slot_id : UUID [FK → battery_slot]
  * event_type : VARCHAR(50)
  charge_percent : INT
  * timestamp : TIMESTAMPTZ [NOT NULL]
}

entity "battery_swap_station_device" as bssd {
  * station_id : UUID [PK, FK → station]
  --
  * device_key : VARCHAR(64) [UNIQUE]
  device_name : VARCHAR(100)
  created_at : TIMESTAMPTZ [NOT NULL]
  last_seen_at : TIMESTAMPTZ
}

entity "battery_swap_station_version" as bssv {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * version : INT
  * name : VARCHAR(255)
  address : VARCHAR(500)
  latitude : DOUBLE
  longitude : DOUBLE
  operating_hours : VARCHAR(100)
  * total_batteries : INT
  * avg_charge_power_kw : DOUBLE
  * base_price_vnd : BIGINT
  status : station_status
  published_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "battery_swap_pile_template" as bspt {
  * id : UUID [PK]
  --
  * station_version_id : UUID [FK → battery_swap_station_version]
  * name : VARCHAR(100)
  * type : VARCHAR(50)
  * slot_count : INT
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "battery_swap_slot_template" as bsst {
  * id : UUID [PK]
  --
  * pile_template_id : UUID [FK → battery_swap_pile_template]
  * slot_index : INT
  * capacity_kwh : DOUBLE
}

' ── Change Requests ──
entity "change_request" as cr {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * submitted_by : UUID [FK → user_account]
  * change_type : change_request_type
  * status : change_request_status
  * proposed_data : JSONB
  risk_score : INT
  risk_level : VARCHAR(20)
  risk_factors : JSONB
  reviewed_by : UUID [FK → user_account]
  reviewed_at : TIMESTAMPTZ
  rejection_reason : TEXT
  published_version_id : UUID [FK → station_version]
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

' ── Trust & Governance ──
entity "station_trust" as stt {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station, UNIQUE]
  score : DOUBLE
  accuracy_factor : DOUBLE
  uptime_factor : DOUBLE
  issue_factor : DOUBLE
  rating_factor : DOUBLE
  verification_factor : DOUBLE
  last_calculated_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "battery_swap_trust" as bstt {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station, UNIQUE]
  score : DOUBLE
  risk_level : battery_swap_trust_level
  location_risk : DOUBLE
  data_accuracy_risk : DOUBLE
  operation_risk : DOUBLE
  financial_risk : DOUBLE
  safety_risk : DOUBLE
  provider_trust_risk : DOUBLE
  triggered_reasons : JSONB
  last_calculated_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "report_issue" as ri {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * reporter_id : UUID [FK → user_account]
  * category : VARCHAR(50)
  description : TEXT
  status : VARCHAR(20)
  resolution : TEXT
  resolved_by : UUID [FK → user_account]
  resolved_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "audit_log" as al {
  * id : UUID [PK]
  --
  * entity_type : VARCHAR(100)
  * entity_id : UUID
  * action : VARCHAR(50)
  actor_id : UUID [FK → user_account]
  details : JSONB
  ip_address : VARCHAR(45)
  created_at : TIMESTAMPTZ [NOT NULL]
}

' ── Collaborator ──
entity "collaborator_profile" as cp2 {
  * id : UUID [PK]
  --
  * user_account_id : UUID [FK → user_account, UNIQUE]
  * full_name : VARCHAR(255)
  id_card_number : VARCHAR(20)
  id_card_front_image_key : VARCHAR(500)
  id_card_back_image_key : VARCHAR(500)
  avatar_image_key : VARCHAR(500)
  latitude : DOUBLE
  longitude : DOUBLE
  current_location : GEOGRAPHY(POINT, 4326)
  last_checkin_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "contract" as ct {
  * id : UUID [PK]
  --
  * collaborator_id : UUID [FK → collaborator_profile]
  * contract_type : VARCHAR(50)
  status : contract_status
  * start_date : DATE
  * end_date : DATE
  terms : TEXT
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "collaborator_registration_request" as crr {
  * id : UUID [PK]
  --
  * user_account_id : UUID [FK → user_account, UNIQUE]
  * full_name : VARCHAR(255)
  email : VARCHAR(255)
  * phone : VARCHAR(20)
  * id_card_number : VARCHAR(20)
  id_card_front_key : VARCHAR(500)
  id_card_back_key : VARCHAR(500)
  address : VARCHAR(500)
  status : collaborator_registration_status
  reviewed_by : UUID [FK → user_account]
  reviewed_at : TIMESTAMPTZ
  rejection_reason : TEXT
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "referral" as ref {
  * id : UUID [PK]
  --
  * referrer_id : UUID [FK → user_account]
  * referee_id : UUID [FK → user_account]
  * referral_code : VARCHAR(20)
  status : referral_status
  bonus_points_awarded : INT
  referred_at : TIMESTAMPTZ [NOT NULL]
  completed_at : TIMESTAMPTZ
}

' ── Verification ──
entity "verification_task" as vt {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  assigned_to : UUID [FK → collaborator_profile]
  task_type : VARCHAR(50)
  status : verification_task_status
  * sla_due_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "verification_checkin" as vc {
  * id : UUID [PK]
  --
  * task_id : UUID [FK → verification_task]
  * collaborator_id : UUID [FK → collaborator_profile]
  * checked_in_at : TIMESTAMPTZ [NOT NULL]
  * latitude : DOUBLE
  * longitude : DOUBLE
  * distance_meters : DOUBLE
}

entity "verification_evidence" as ve {
  * id : UUID [PK]
  --
  * task_id : UUID [FK → verification_task]
  * photo_type : VARCHAR(50)
  * file_key : VARCHAR(500)
  uploaded_at : TIMESTAMPTZ [NOT NULL]
}

entity "verification_review" as vr {
  * id : UUID [PK]
  --
  * task_id : UUID [FK → verification_task, UNIQUE]
  * result : verification_review_result
  notes : TEXT
  reviewed_by : UUID [FK → user_account]
  * reviewed_at : TIMESTAMPTZ [NOT NULL]
}

' ── Loyalty ──
entity "loyalty_user_profile" as lup {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account, UNIQUE]
  * total_points : INT
  tier : VARCHAR(20)
  created_at : TIMESTAMPTZ [NOT NULL]
  updated_at : TIMESTAMPTZ [NOT NULL]
}

entity "loyalty_point_transaction" as lpt {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * points : INT
  * source : VARCHAR(50)
  reference_id : UUID
  description : TEXT
  * created_at : TIMESTAMPTZ [NOT NULL]
}

entity "loyalty_badge" as lb {
  * id : UUID [PK]
  --
  code : VARCHAR(50) [UNIQUE]
  * name : VARCHAR(100)
  description : TEXT
  icon_url : VARCHAR(500)
  * tier : VARCHAR(20)
  * points_threshold : INT
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "user_badge" as ub {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * badge_id : UUID [FK → loyalty_badge]
  * earned_at : TIMESTAMPTZ [NOT NULL]
}

entity "station_rating" as srt {
  * id : UUID [PK]
  --
  * station_id : UUID [FK → station]
  * user_id : UUID [FK → user_account]
  * rating : INT
  comment : TEXT
  status : VARCHAR(20)
  moderated_by : UUID [FK → user_account]
  moderated_at : TIMESTAMPTZ
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "rating_eligibility" as rel {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * station_id : UUID [FK → station]
  * eligible : BOOLEAN
  reason : VARCHAR(100)
  * last_checked_at : TIMESTAMPTZ [NOT NULL]
}

entity "voucher_definition" as vd {
  * id : UUID [PK]
  --
  code : VARCHAR(50) [UNIQUE]
  * name : VARCHAR(255)
  description : TEXT
  * voucher_type : voucher_definition_type
  * point_cost : INT
  discount_percent : INT
  discount_amount_vnd : BIGINT
  min_booking_amount_vnd : BIGINT
  max_discount_vnd : BIGINT
  valid_from : TIMESTAMPTZ
  valid_until : TIMESTAMPTZ
  total_quantity : INT
  redeemed_count : INT
  active : BOOLEAN
  created_at : TIMESTAMPTZ [NOT NULL]
}

entity "voucher_redemption" as vr2 {
  * id : UUID [PK]
  --
  * user_id : UUID [FK → user_account]
  * voucher_definition_id : UUID [FK → voucher_definition]
  * points_spent : INT
  status : voucher_redemption_status
  * redeemed_at : TIMESTAMPTZ [NOT NULL]
  expires_at : TIMESTAMPTZ
  used_at : TIMESTAMPTZ
  booking_id : UUID [FK → booking]
}

' ── Relationships ──
ua ||--o{ pt : "1 user → many push tokens"
ua ||--o{ np : "1 user → 1 preference"
ua ||--o{ eun : "1 user → many notifications"
ua ||--o{ cn : "1 user → many notifications"
ua ||--o{ bk : "1 user → many bookings"
ua ||--o{ bsr : "1 user → many reservations"
ua ||--o{ lup : "1 user → 1 loyalty profile"
ua ||--o{ lpt : "1 user → many point txns"
ua ||--o{ ub : "1 user → many badges"
ua ||--o{ srt : "1 user → many ratings"
ua ||--o{ vr2 : "1 user → many redemptions"
ua ||--o{ ref : "1 user → many referrals (referrer)"
ua ||--|| ref : "1 user → 1 referral (referee)"

st ||--o{ sv : "1 station → many versions"
st ||--o{ ss : "1 station → many services"
st ||--o{ cp : "1 station → many ports"
st ||--o{ cu : "1 station → many charger units"
st ||--|| bsss : "1 station → 1 swap state"
st ||--o{ sp : "1 station → many swap piles"
st ||--o{ bsr : "1 station → many reservations"
st ||--o{ cr : "1 station → many change requests"
st ||--o{ ri : "1 station → many issues"
st ||--|| stt : "1 station → 1 trust record"
st ||--|| bstt : "1 station → 1 swap trust"
st ||--|| bssd : "1 station → 1 device"
st ||--o{ bssv : "1 station → many versions"
st ||--o{ vt : "1 station → many tasks"

sv ||--|| stt : "1 version → 1 trust"
sv ||--o{ cr : "1 version → many change requests"

ss ||--o{ bsss : "1 service → swap state"
ss ||--o{ bssv : "1 service → swap version"

cu ||--o{ bk : "1 charger unit → many bookings"

bk ||--o| pi : "1 booking → 1 payment intent"
bk ||--o{ vr2 : "1 booking → many redemptions"

sp ||--o{ bsl : "1 pile → many slots"
bsl ||--o{ bsr : "1 slot → many reservations"
bsl ||--o{ css : "1 slot → many charging sessions"
bsl ||--o{ be : "1 slot → many battery events"

bsr ||--o| spp : "1 reservation → 1 payment"
bsr ||--o{ sss : "1 reservation → 1 session"

bssv ||--o{ bspt : "1 version → many pile templates"
bspt ||--o{ bsst : "1 pile template → many slot templates"

cp2 ||--o{ ct : "1 profile → many contracts"
cp2 ||--o{ vt : "1 profile → many tasks"
cp2 ||--o{ vc : "1 profile → many check-ins"

crr ||--o{ cp2 : "1 registration → 1 profile"

vr2 ||--o{ vd : "1 redemption → 1 voucher"
vr2 ||--o{ bk : "1 redemption → 1 booking"

vt ||--o{ vc : "1 task → many check-ins"
vt ||--o{ ve : "1 task → many evidence"
vt ||--|| vr : "1 task → 1 review"

lb ||--o{ ub : "1 badge → many user badges"

@enduml
```

---

## 3.4 Key Indexes

The following indexes are defined via Flyway migrations and JPA entity annotations:

```sql
-- Spatial index for nearby station search (PostGIS)
CREATE INDEX idx_station_version_location ON station_version USING GIST (location);

-- Station version lookup
CREATE INDEX idx_station_version_station ON station_version(station_id);
CREATE INDEX idx_station_version_status ON station_version(status);

-- Booking lookups
CREATE INDEX idx_booking_user ON booking(user_id);
CREATE INDEX idx_booking_station ON booking(station_id);
CREATE INDEX idx_booking_status ON booking(status);
CREATE INDEX idx_booking_hold_expires ON booking(hold_expires_at) WHERE status = 'HOLD';

-- Booking exclusion constraint (prevents double-booking)
ALTER TABLE booking ADD CONSTRAINT ck_booking_no_overlap_active
  EXCLUDE USING gist (
    charger_unit_id WITH =,
    tstzrange(start_time, end_time) WITH &&
  ) WHERE (status IN ('HOLD', 'CONFIRMED'));

-- Battery swap indexes
CREATE INDEX idx_bsr_user ON battery_swap_reservation(user_id);
CREATE INDEX idx_bsr_station ON battery_swap_reservation(station_id);
CREATE INDEX idx_bsr_status ON battery_swap_reservation(status);
CREATE INDEX idx_bsr_swap_code ON battery_swap_reservation(swap_code);

CREATE INDEX idx_slot_pile ON battery_slot(pile_id);
CREATE INDEX idx_slot_status ON battery_slot(status);

CREATE INDEX idx_swap_session_code ON swap_session(swap_code);
CREATE INDEX idx_swap_session_expires ON swap_session(expires_at) WHERE status = 'PENDING';

-- Collaborator location
CREATE INDEX idx_collaborator_location ON collaborator_profile USING GIST (current_location);

-- Verification SLA
CREATE INDEX idx_verification_task_sla ON verification_task(sla_due_at) WHERE status = 'ASSIGNED';

-- Audit log search
CREATE INDEX idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id);
CREATE INDEX idx_audit_log_created ON audit_log(created_at DESC);

-- Trust score lookup
CREATE INDEX idx_station_trust_station ON station_trust(station_id);
CREATE INDEX idx_battery_swap_trust_station ON battery_swap_trust(station_id);

-- Loyalty
CREATE INDEX idx_loyalty_profile_user ON loyalty_user_profile(user_id);
CREATE INDEX idx_point_txn_user ON loyalty_point_transaction(user_id);
CREATE INDEX idx_voucher_code ON voucher_definition(code);
```
