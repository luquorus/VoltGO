# DOC 1 — Project Overview

---

**Project Name:** VoltGO — Hệ thống Quản lý Trạm Sạc và Đổi Pin Xe Điện

**Project Name (English):** VoltGO — EV Charging & Battery Swap Station Management System

**Purpose:** VoltGO is a full-stack platform for managing electric vehicle (EV) charging and battery swap infrastructure. It connects three user groups — EV drivers, field collaborators, and administrators — through a suite of mobile/web applications backed by a RESTful API and real-time WebSocket services.

**Target Users:**
- **EV Drivers:** Vietnamese EV owners who need to locate charging stations, book slots, reserve battery swaps, and earn loyalty rewards.
- **Collaborators:** Field agents who verify station existence, GPS accuracy, and equipment status on behalf of the platform.
- **Administrators:** Platform operators who manage stations, approve changes, monitor trust scores, and govern the ecosystem.

**Core Problem It Solves:** Vietnam's EV infrastructure lacks a unified management system that can (1) help drivers find and use charging stations reliably, (2) verify station data through field agents, (3) manage battery swap operations with real-time slot availability, and (4) maintain station trust through a multi-factor scoring engine. VoltGO addresses all four dimensions.

---

## Key Features

### EV User Features (Mobile App — `ev_user_mobile`)

- **Station Map & Search:** OpenStreetMap-based interactive map showing nearby charging and battery swap stations. Filter by name, distance, power type.
- **Station Navigation:** Route calculation via OSRM to navigate drivers to stations.
- **Charging Booking:** Reserve a charging slot at a station for a specific time window. Booking enters `HOLD` state with a 15-minute expiry, then auto-converts to `CONFIRMED` or `EXPIRED`.
- **Battery Swap Reservation:** Reserve a battery and slot at a swap station. Workflow: reserve → confirm arrival → start swap (receive 6-digit swap code) → pay (mock) → complete → verify.
- **Station Availability:** Real-time charger unit status (AVAILABLE, OCCUPIED, OUT_OF_SERVICE) via API.
- **Change Request:** Submit suggested edits to station data (name, address, ports, hours) for admin review. The same workflow is also available to collaborators (see *Collaborator Features* below).
- **Issue Reporting:** Report station discrepancies (wrong address, broken charger, etc.).
- **Station Rating:** Rate a station after charging. Ratings go through admin moderation before publication.
- **Loyalty Program:** Earn points per completed booking/swap. Redeem points for vouchers. Earn badges (5 tiers: Bronze → Silver → Gold → Platinum → Diamond). Referral program with bonus points for both parties.
- **Voucher Catalog:** Browse and redeem vouchers at participating stations.
- **AI Recommendations:** Personalized station recommendations based on vehicle battery level, capacity, and target charge level.
- **Push Notifications:** Booking reminders, swap countdown, loyalty rewards (FCM stubbed in current build).
- **Profile Management:** View/edit profile, change password, manage notification preferences.

### Collaborator Features (Mobile App — `collab_mobile` / Web — `admin_web`)

- **Registration Workflow:** Submit a registration request with personal info. Admin reviews and approves → account activated with `PENDING_COLLABORATOR` status → full `COLLABORATOR` role granted.
- **GPS Check-in:** Record GPS coordinates when arriving at a verification task location. Haversine distance calculated against station location.
- **Station Verification Tasks:** Accept assigned verification tasks, photograph station evidence (exterior, charger, signage), submit verification review for admin approval.
- **Battery Swap Verification Tasks:** Verify swap station existence, availability, and operational status.
- **Change Request (NEW — 2026-06):** Propose edits to station data (charging or battery swap) after on-site verification. Workflow: DRAFT → submit → admin reviews → APPROVED/REJECTED → PUBLISHED. Includes risk assessment and the same workflow as EV User change requests. Reachable from a new "Requests" tab in the bottom navigation bar; admins are notified when a CR is submitted, approved, rejected, or published.
- **Contract Management:** View active and historical contracts with the platform.
- **Notifications:** Receive task assignments, SLA reminders, system alerts, and CR decision updates (approve / reject / publish).

### Admin Features (Web Portal — `admin_web`)

- **Dashboard:** Overview stats (total stations, bookings, issues, trust scores), booking trends over time, issue breakdown by category, collaborator performance summary.
- **Station Management:** Full CRUD for charging stations. Version-controlled edits. CSV bulk import. Publishing workflow.
- **Change Request Workflow:** Review submitted change requests. Approve → auto-publish. Reject with reason. Publish directly. Full audit trail.
- **Trust Score Management:** View and manually recalculate station trust scores (multi-factor breakdown: accuracy, uptime, issue rate, user ratings).
- **Collaborator Management:** View collaborator profiles, contracts, GPS locations, performance metrics (total bookings, verifications, avg response time).
- **Verification Task Management:** Create, assign, and review verification tasks. SLA deadline tracking. Evidence photo review.
- **Issue Management:** View and resolve user-reported station issues. Categorize by type.
- **Battery Swap Station Management:** Full CRUD for swap stations. CSV bulk import. Change request workflow.
- **Battery Swap Trust Scoring:** Trust score for swap stations with breakdown by location, data accuracy, operations, financial, safety, and provider factors.
- **Loyalty Administration:** Manage badge definitions and tiers, create/manage vouchers, moderate user ratings, view loyalty leaderboard.
- **Audit Log:** Full-text search across all admin actions (entity type, action type, actor, timestamp, details).
- **Registration Request Approval:** Review and approve/decline collaborator registration requests.

### Hardware Simulator (`hardware_simulator`)

- **Station Display:** Real-time display showing available batteries, slot occupancy, active swap codes. Connects via WebSocket.
- **Swap Flow Simulation:** Full battery swap flow from reservation confirmation to swap completion.
- **Device Authentication:** Authenticate with station `deviceKey` obtained from public API.

### System-wide Features

- **JWT Authentication:** 24-hour Bearer token. Role-based access control (RBAC): `EV_USER`, `COLLABORATOR`, `ADMIN`.
- **WebSocket Real-time Updates:** Live broadcast of swap codes, slot status, and battery availability to hardware displays.
- **Scheduled Jobs:** Booking expiration (every 60s), battery charging simulation (every 30s), SLA notification reminders, voucher expiration.
- **File Storage:** MinIO object storage for verification photos, station images, documents. Presigned URL generation.
- **Two Risk Engines:** Standard station (8 risk factors, max score 100) and battery swap (24 risk factors across 6 categories, max score 100). Drives auto-approval vs. admin review decisions.
- **Audit Logging:** All admin actions logged with entity type, action, actor, timestamp, and JSON details.

---

## Out of Scope

The following were intentionally excluded from the current implementation:

- **Real payment gateway integration** — Payment is fully mocked via `simulate-success` / `simulate-fail` endpoints. Integration with VNPay, MoMo, Stripe, or another provider is not implemented.
- **Production push notifications** — `FCMService` is a stub that logs notifications. No Firebase project, `google-services.json`, or FCM dependency is configured.
- **Production email delivery** — `EmailService` logs emails to console. No SMTP provider is configured for production use.
- **Real-time hardware integration** — The hardware simulator is a Flutter desktop/web app. Real OCPP (Open Charge Point Protocol) integration with physical charging hardware is not implemented.
- **iOS app builds** — No iOS-specific code (Swift/Objective-C) or App Store deployment configuration.
- **Machine learning model deployment** — AI recommendations exist as a service but the underlying model/training pipeline is not present in the codebase.
- **Multi-tenancy** — All data is in a single schema. No multi-operator or white-label support.
- **CI/CD pipelines** — No GitHub Actions, GitLab CI, Jenkins, or Kubernetes manifests.
- **End-to-end encrypted messaging** — No user-to-user or user-to-support chat.
- **OTA firmware updates** — Not applicable to current scope.
- **Fleet management** — No corporate accounts or fleet operator dashboard.
