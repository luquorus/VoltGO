# DOC 5 — Tech Stack & Justification

---

## 5.1 Layer Overview

| Layer | Technology | Version | Role |
|---|---|---|---|
| **Frontend Mobile** | Flutter | 3.x (stable) | Cross-platform mobile and web apps |
| **Frontend State Management** | flutter_riverpod | ^2.4 | Reactive state management with compile-time safety |
| **Frontend Routing** | go_router | ^13.x | Declarative, deep-linkable routing with guards |
| **Frontend Networking** | dio | ^5.4 | HTTP client with interceptors, retry, timeout |
| **Frontend Maps** | flutter_map + latlong2 | latest | OpenStreetMap-based map rendering |
| **Frontend Charts** | fl_chart | ^0.66 | Admin dashboard charts and graphs |
| **Frontend Geolocation** | geolocator | ^11.x | GPS location access |
| **Backend** | Spring Boot | 3.2.0 | REST API framework |
| **Backend Language** | Java | 17 (LTS) | Primary programming language |
| **Database** | PostgreSQL + PostGIS | 16 / 3.4 | Relational + geospatial |
| **ORM** | Spring Data JPA (Hibernate) | 6.x | Object-relational mapping |
| **Migrations** | Flyway | 9.x | Versioned SQL migrations |
| **Caching** | Redis | 7.x | Session cache, rate limiting, pub/sub |
| **Object Storage** | MinIO | latest | S3-compatible file storage |
| **Authentication** | Spring Security + JWT (jjwt) | 6.x / 0.12 | Stateless Bearer token auth |
| **Real-time** | Spring WebSocket | 6.x | Hardware simulator display updates |
| **API Docs** | SpringDoc OpenAPI | 2.x | Auto-generated Swagger UI |
| **Scheduling** | Spring @Scheduled | built-in | Cron-based background jobs |
| **Async** | Spring @Async | built-in | Email sending |
| **Email** | Spring JavaMailSender | built-in | Email delivery (stubbed) |
| **Build Tool (Backend)** | Gradle | 8.x | Dependency management and build |
| **Build Tool (Frontend)** | Flutter/Dart | SDK | Native compilation |
| **Containerization** | Docker + Docker Compose | latest | Local dev and deployment |
| **Routing Service** | OSRM | public demo | Turn-by-turn route calculation |

---

## 5.2 Detailed Justification by Layer

### Frontend Mobile — Flutter

**Why Flutter over other options:**
- Single codebase targeting Android, iOS, Web, and Desktop (hardware simulator).
- Dart language is easy to learn, strongly typed, and compiles to native code.
- Hot-reload dramatically accelerates development iteration.
- Rich widget library with Material 3 support enables polished UI without heavy custom coding.
- `flutter_map` provides free, no-API-key map rendering via OpenStreetMap — critical for a thesis budget.
- Riverpod integrates naturally with Flutter's widget tree and supports code-splitting per route.

**Alternatives considered and rejected:**
- **React Native:** Requires separate web bundler, weaker performance for custom animations, JavaScript's runtime type errors.
- **Kotlin Multiplatform (KMP):** Younger ecosystem, smaller community in 2024, less Flutter-style hot-reload.
- **Swift/Obj-C (iOS) + Kotlin (Android):** Two separate codebases doubles maintenance effort.

---

### State Management — Riverpod (flutter_riverpod)

**Why Riverpod over other options:**
- Compile-time safe: provider dependency errors are caught at compile time, not runtime.
- Testable: providers can be overridden with mock implementations for unit testing.
- No code generation: unlike `riverpod_generator` (code-gen) or `freezed` (serialization), the base package uses pure Dart.
- First-class support for async data (`AsyncValue`), streams, and computed state.
- Works identically on mobile, web, and desktop.

**Alternatives considered and rejected:**
- **Provider (flutter_bloc's top-of-stack):** No compile-time safety. Missing a provider causes silent `null` returns at runtime.
- **BLoC:** Very verbose (separate events, states, blocs). Steep learning curve. Overkill for this project's complexity.
- **GetX:** "Magic" under the hood — hidden dependency injection, automatic disposal, no explicit contracts. Hard to unit-test.

---

### Backend — Spring Boot 3

**Why Spring Boot:**
- Industry-standard enterprise Java framework with a vast, mature ecosystem.
- Native integrations for Security, JPA, WebSocket, Scheduling, and Async — all used in this project.
- `@PreAuthorize` annotations make role-based access control declarative and auditable.
- Spring Data JPA generates repository implementations automatically, reducing boilerplate.
- `@Transactional` declarative transaction boundaries reduce accidental DB inconsistency.
- SpringDoc OpenAPI auto-generates Swagger docs from annotations — keeps docs in sync with code.

**Alternatives considered and rejected:**
- **Quarkus:** Lighter and faster startup, but smaller community and fewer Stack Overflow answers.
- **Micronaut:** Excellent performance, but less Spring ecosystem compatibility (different DI, different conventions).
- **Raw Java EE / Jakarta EE:** Excessive boilerplate for a single-application system.

---

### Database — PostgreSQL 16 + PostGIS 3.4

**Why PostgreSQL:**
- ACID-compliant, handles concurrent writes well via MVCC.
- Strong indexing: B-tree for equality/range, GiST for PostGIS spatial.
- JSON/JSONB columns for flexible data (`proposed_data`, `risk_factors`, `details`).
- Excellent Vietnamese character support (`UTF8`).

**Why PostGIS:**
- `GEOGRAPHY(POINT, 4326)` column stores lat/lng directly with SRID metadata.
- Native SQL functions: `ST_DWithin`, `ST_Distance` for Haversine-equivalent geo-queries without post-processing.
- PostGIS index (`GIST`) makes nearby-station queries O(log n) instead of O(n).
- Used in `AvailabilityService.getAvailability`, `RecommendationQueryService.getRecommendations`, and collaborator location tracking.

**Alternatives considered and rejected:**
- **MySQL 8:** No PostGIS equivalent (MySQL Spatial is limited). Weaker JSONB support.
- **MongoDB:** No native geo-queries without a separate geospatial service.
- **SQLite:** Not production-scalable, no concurrent write support.

---

### ORM — Spring Data JPA (Hibernate)

**Why JPA:**
- Repository pattern: `CrudRepository<UserAccount, UUID>` gives `findAll()`, `findById()`, `save()`, `delete()` with zero implementation.
- Method naming convention: `findByEmail(String email)` auto-generates JPQL — no boilerplate DAO.
- `@Query` for native SQL (used for PostGIS spatial queries).
- Entity lifecycle callbacks (`@PrePersist`, `@PreUpdate`) for `createdAt`/`updatedAt` auto-fill.
- Optimistic locking via `@Version` prevents concurrent update race conditions on `battery_slot` and `swap_session`.

**Alternatives considered and rejected:**
- **MyBatis:** More SQL control but breaks domain model encapsulation. More boilerplate.
- **Spring Data JDBC:** Stripped-down, less feature-rich for complex relationships.
- **jOOQ:** Requires code generation from DB schema. Overkill for this project scale.

---

### Migrations — Flyway

**Why Flyway:**
- Versioned SQL scripts in `src/main/resources/db/migration/` — full version history in source control.
- Auto-runs on startup (`spring.flyway.enabled=true`).
- Supports `baseline`, `repair`, and `clean` for schema recovery.
- 47 migration files document the full schema evolution from scratch.
- Native Spring Boot integration.

**Alternatives considered and rejected:**
- **Liquibase:** XML/JSON configs less SQL-native. Harder to read than plain SQL.
- **Manual SQL:** No version tracking, no rollback support, error-prone.

---

### Authentication — Spring Security + JWT (jjwt)

**Why JWT:**
- Stateless: server stores no session. Scales horizontally without sticky sessions.
- Token carries all auth info: `userId`, `email`, `role`, `status`. No extra DB lookup per request.
- Mobile-friendly: works across Android, iOS, and web without cookie issues.
- `PENDING_COLLABORATOR` status encoded in token — allows collaborators to access limited endpoints before full activation.
- 24-hour expiry balances security and UX (no frequent re-login).

**Why NOT OAuth2/OIDC:**
- Adds complexity (authorization server, token exchange, PKCE for mobile).
- Overkill for a single-application system with one identity provider.
- Would require a separate OAuth provider (e.g., Auth0, Keycloak).

**Alternatives considered and rejected:**
- **Session cookies:** Stateful, requires Redis for distributed sessions, harder for mobile apps.
- **PASETO:** Newer, simpler, but less library support in Java.

---

### Caching — Redis 7

**Why Redis:**
- Sub-millisecond read latency for session and rate-limit data.
- Spring Data Redis provides `RedisTemplate` with built-in serialization (JSON for objects, strings for tokens).
- Pub/Sub channels (`swap-code-broadcast`) used by `BatterySwapBroadcastService` for real-time WebSocket fan-out.
- TTL-based expiry for booking holds (`HOLD` status with 15-minute TTL) and swap codes.
- Docker Compose makes Redis a one-line service addition.

**Alternatives considered and rejected:**
- **EhCache (in-memory):** No persistence, no distributed support across multiple app instances.
- **Memcached:** Simpler feature set, no pub/sub, no TTL support for atomic ops.

---

### Object Storage — MinIO (S3-compatible)

**Why MinIO:**
- Self-hosted S3-compatible storage — deploys in Docker, no cloud dependency.
- Presigned URL pattern: API generates a short-lived upload/download URL; client uploads directly to MinIO, bypassing the app server. Reduces server load for large files.
- Used for verification photos, ID card scans, station images.
- Supports multipart upload for large files.

**Alternatives considered and rejected:**
- **AWS S3 directly:** Vendor lock-in, egress costs, requires AWS account.
- **Local filesystem:** No scalability, no presigned URLs, files served through app server.
- **Cloudinary:** Good for image optimization, but not a generic object store.

---

### Real-time — Spring WebSocket

**Why Spring WebSocket:**
- Native Spring integration — no extra dependencies for basic WebSocket support.
- `SimulatorDisplayWebSocketHandler` (extends `TextWebSocketHandler`) handles hardware simulator connections.
- Device authentication via `deviceKey` query parameter.
- Broadcasts swap codes and slot status changes to all connected simulator clients.

**Alternatives considered and rejected:**
- **Server-Sent Events (SSE):** One-way only (server → client). Cannot receive messages from simulator.
- **Socket.IO:** Requires JavaScript client library. Adds protocol overhead.
- **Raw WebSocket (JSR-356):** Requires manual routing logic that Spring WebSocket handles automatically.

---

### Routing — OSRM (Open Source Routing Machine)

**Why OSRM:**
- Open-source, free public demo at `router.project-osrm.org`.
- Returns turn-by-turn routes as GeoJSON for map rendering.
- HTTP API — simple to call from `RoutingService`.
- Server-side routing (not client-side) so API can estimate travel time for recommendations.

**Alternatives considered and rejected:**
- **Google Maps Directions API:** Requires paid API key, billing per request.
- **Mapbox Directions API:** Paid, requires API key.
- **Self-hosted OSRM:** More control, but requires separate Docker container and map data tile downloads.

---

### Deployment — Docker Compose

**Why Docker Compose:**
- All services (Spring Boot, PostgreSQL, Redis, MinIO, Nginx) defined in `docker-compose.yml`.
- Reproducible environment for development, testing, and CI.
- No manual installation on developer machines.
- `docker-compose up` starts the entire stack in seconds.

**Alternatives considered and rejected:**
- **Kubernetes:** Significant operational overhead. Overkill for a thesis project.
- **Bare VM / bare metal:** Manual installation, no version control of infrastructure.
- **Heroku / Render / Railway:** Limited PostgreSQL + PostGIS support. Vendor lock-in.

---

### Map Rendering — flutter_map (OpenStreetMap)

**Why flutter_map:**
- Open-source, no API key required.
- Highly customizable: custom markers, polygons, polylines, clustering.
- Works offline with cached tiles.
- `latlong2` for Haversine distance calculations and coordinate handling.

**Alternatives considered and rejected:**
- **Google Maps Flutter:** Requires paid API key. Per-load charges for map tiles. Restrictive licensing for commercial use.
- **Apple Maps:** iOS only, not cross-platform.
