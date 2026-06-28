# 5.2 Station Data Field Verification and Risk Assessment Mechanism

## 5.2.1 Problem Introduction

Station data reliability is a core issue in an electric vehicle service platform. Users depend on station location, charger type, operating hours, equipment status, and service availability before deciding to travel. Inaccurate data can cause wasted time, stranded vehicles, and reduced trust in the application. This problem is particularly acute for VoltGO, which serves both standard charging stations and battery swap stations across Vietnam.

The system must balance update speed and data reliability. Manual review for every change can delay useful updates and overload administrators. Automatic approval can publish incorrect data when a proposed change affects location, ports, operating conditions, or station availability. A suitable solution needs to evaluate change risk and collect field evidence when the risk is not sufficiently low.

A manual-only approval process gives administrators little support for judging the seriousness of a proposed change. A feedback-only process reacts after users have already encountered a problem. VoltGO combines station proposals, issue reports, GPS check-ins, photo evidence, risk scores, trust scores, and an explicit verification workflow so that station data can be governed before and after publication.

## 5.2.2 Solution

The solution uses two complementary layers. The **field verification layer** checks whether a collaborator physically visits the station and submits evidence. The **risk assessment layer** evaluates proposed data changes and produces explainable reasons for the administrator. These layers support different decisions but share the same objective of improving station data reliability. A third, long-running **trust scoring layer** evaluates the overall reliability of a station over time, complementing the request-level risk assessment.

### 5.2.2.1 Field Verification Layer

In the verification workflow, an administrator assigns a task to a collaborator from a candidate list. The collaborator travels to the station, performs a GPS check-in, fills out a checklist of verification questions, and uploads evidence photos. The system calculates the distance between the collaborator's GPS location and the stored station coordinates using PostGIS before accepting the check-in. The maximum allowed distance is **200 meters**. If the collaborator is farther than 200 meters from the station, the check-in is rejected, preventing verification from being submitted without genuine field presence.

The verification task lifecycle has five states:

1. **OPEN** — Task created by admin, not yet assigned.
2. **ASSIGNED** — Task assigned to a specific collaborator.
3. **CHECKED_IN** — Collaborator has performed GPS check-in within range and answered all checklist questions.
4. **SUBMITTED** — Collaborator has uploaded at least one evidence photo.
5. **REVIEWED** — Admin has reviewed the task and marked it as PASS or FAIL.

A self-assignment prevention rule ensures that a verification task cannot be assigned to the same collaborator who submitted the originating change request. If an admin attempts this, the system writes a dedicated audit log entry (`BLOCK_SELF_ASSIGN`) and returns a 409 Conflict error. This prevents bias in the verification process.

Evidence files (photos) are stored in MinIO object storage rather than in the relational database. The database retains metadata (file key, submission time, note) and a reference to the task, while MinIO keeps the actual image files. The backend generates **presigned URLs** (GET for viewing, PUT for uploading) so that collaborators can upload evidence photos directly to MinIO without routing large files through the application server. This design keeps structured data and file data separated, which is appropriate for a system that may store many verification photos and station images.

The verification checklist is generated automatically from the risk reasons of the associated change request. Each risk reason code maps to a specific verification question (e.g., `GPS_CHANGED_100M` maps to "Has the station's GPS location changed from the current data?"). If a change request has no risk reasons, the checklist falls back to three default questions: station operational status, location accuracy, and information correctness. Questions answered as "No" or "Unable to Verify" require a supplementary note from the collaborator.

For battery swap stations, the verification process captures additional operational data: total battery inventory count, available battery count, and optionally the observed average charge power. The system stores a station snapshot at task creation time, allowing the administrator to compare expected values against actual values observed in the field. Mismatches are highlighted in the admin UI.

> **Figure 5.4** — *Station data contribution and field verification workflow.* The flow begins with an EV user or collaborator submitting a station proposal. The risk engine evaluates the proposal and assigns a risk score. If the risk is high, the admin creates a verification task. The task is assigned to a collaborator who travels to the station, performs GPS check-in, fills the checklist, and uploads evidence. The admin reviews the verification and makes a publish decision. Meanwhile, the trust score is continuously recalculated based on verification results, issue reports, and change request history. (See PlantUML source: `figures/Figure5_4_Station_Verification_Workflow.puml`)

### 5.2.2.2 Risk Assessment Layer

The risk assessment layer compares proposed station data with the current published version. It operates at two levels: **charging station risk assessment** and **battery swap risk assessment**.

#### Charging Station Risk Assessment

For standard charging stations, the system considers factors grouped by their impact severity. The risk engine evaluates each triggered factor and accumulates a total score capped at 100. Table 5.2 summarizes the risk codes, their score contributions, and the conditions that trigger them.

**Table 5.2.** Charging station risk codes and score contributions.

| Risk Code | Score | Trigger Condition |
|-----------|------:|-------------------|
| `GPS_CHANGED_100M` | +50 | Distance between proposed and published GPS coordinates exceeds 100 meters |
| `PORTS_CHANGED` | +30 | Charging port multiset (power type, power kW, count) differs between versions |
| `SWAP_CONFIG_CHANGED` | +30 | Battery swap total batteries or average charge power changed (applies to stations with BATTERY_SWAP service) |
| `PRICE_CHANGED` | +20 | Reserved for future pricing field comparison |
| `SWAP_AVG_POWER_OUT_OF_RANGE` | +20 | Average charge power outside range 10–200 kW |
| `HOURS_CHANGED` | +10 | Operating hours string differs (case-insensitive, trimmed) |
| `ACCESS_CHANGED` | +10 | Visibility or public status flag changed |
| `NEW_STATION` | +10 | Change request type is CREATE_STATION |

After scoring, the risk level is classified as:
- **HIGH** — score >= 50
- **MEDIUM** — score >= 30 and < 50
- **LOW** — score < 30

#### Battery Swap Risk Assessment

Battery swap station assessment uses a broader six-category framework because the service includes inventory, slot configuration, operational availability, financial information, and safety-related information. The `BatterySwapRiskAssessor` implements these categories:

1. **Location Risk** — New station creation, GPS location change, GPS mismatch with declared address, sensitive area flag.
2. **Data Accuracy Risk** — Battery count change (>20%), charge power change (>25%), pile/slot configuration change, operating hours change, parking fee change (>5,000 VND or >50%).
3. **Operation Risk** — Low battery inventory (<5 batteries), abnormal charge power (outside 10–200 kW), limited availability, configuration issues.
4. **Financial Risk** — Missing price information, significant price change, price deviation from market average.
5. **Safety Risk** — Potential safety concern, missing safety equipment, environmental risk. These factors are foundations for later implementation rather than complete production checks in the current thesis scope. This limitation is stated to avoid overclaiming the maturity of the risk engine.
6. **Provider Trust Risk** — Low trust score (<30), high rejection rate, pending verifications, new provider (<30 days).

> **Figure 5.5** — *Risk assessment flow for station data changes.* The proposed station data is parsed and compared against the currently published version. For battery swap stations, six risk categories are evaluated in sequence. The accumulated score is capped at 100 and classified into HIGH / MEDIUM / LOW levels. (See PlantUML source: `figures/Figure5_5_Risk_Assessment_Flow.puml`)

The following listing shows the Java implementation of the GPS change detection and distance calculation from `RiskEngineService.java`.

```java
private double calculateDistanceInMeters(double lat1, double lng1, double lat2, double lng2) {
    final double R = 6371000; // Earth's radius in meters

    double dLat = Math.toRadians(lat2 - lat1);
    double dLng = Math.toRadians(lng2 - lng1);

    double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
            + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
            * Math.sin(dLng / 2) * Math.sin(dLng / 2);

    double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
}

private boolean isGpsChanged(Point published, Point proposed) {
    if (published == null || proposed == null) {
        return published != proposed;
    }
    double distance = calculateDistanceInMeters(
            published.getY(), published.getX(),  // lat, lng
            proposed.getY(), proposed.getX());
    return distance > GPS_CHANGE_THRESHOLD_METERS;  // 100m threshold
}
```

The charging port comparison uses a **multiset representation** where each port is encoded as the string `"powerType|powerKw|portCount"`. The two sets are compared as a whole, so added, removed, or changed ports all trigger `PORTS_CHANGED`.

### 5.2.2.3 Trust Scoring Layer

The long-term **trust score** complements request-level risk assessment. A risk score evaluates one proposed modification, while a trust score reflects accumulated station quality after publication. User ratings, issue history, verification results, and operational signals contribute to this longer-term view. This distinction helps the administrator treat a single change request and the overall reliability of a station as separate but related concerns.

The trust score for charging stations is calculated from four components:

| Component | Value | Condition |
|-----------|------:|-----------|
| Base | +50 | Assigned at station publication |
| Verification bonus | +20 | Most recent verification within 30 days was PASS |
| Verification penalty | -20 | Most recent verification within 30 days was FAIL |
| Issues penalty | -5 each (max -30) | Per OPEN or ACKNOWLEDGED issue |
| High-risk CR penalty | -10 | Any published CR within 30 days had risk_score >= 60 |

The final score is clamped to the range [0, 100]. Trust levels are classified as Good (>= 80), Fair (>= 60), Poor (>= 40), or Very Poor (< 40).

Trust scores are **cached** using Spring's `@Cacheable` annotation backed by Redis. The cache is evicted and recalculated when:
- A verification task is reviewed (PASS or FAIL)
- An issue is created, acknowledged, resolved, or rejected
- A change request is published with a high risk score

Battery swap trust uses a **weighted component model**: Verification (30%), Completion (25%), Quality (25%), Satisfaction (20%). Both scoring systems share the same `TrustScoringService` infrastructure with separate repository paths for charging and battery swap trust entities.

### 5.2.2.4 Integration: Publish Enforcement

The risk assessment and field verification layers are enforced together at publish time. The `AdminChangeRequestService.publishChangeRequest()` method enforces a hard rule: if a change request's risk score is **>= 60**, the system checks whether a verification task linked to that change request has been reviewed with a **PASS** result. If not, publishing is blocked with the message: *"High-risk change request (risk_score >= 60) requires verification PASS before publishing."* This enforces that high-risk changes cannot go live without field confirmation, regardless of administrative approval.

The publish operation itself performs an atomic database update: the old published station version is archived, the new version is published with a timestamp, charger units are created from charging ports, battery swap configuration is applied, the change request status is set to PUBLISHED, and the trust score is recalculated — all within a single transaction with pessimistic locking on the station row to prevent concurrent publish operations.

### 5.2.2.5 Notification System

Throughout the verification and approval lifecycle, in-app notifications are sent to relevant actors:

- When a verification task is assigned to a collaborator, they receive a notification with the station name, priority, and SLA deadline.
- When an admin approves, rejects, or publishes a change request submitted by a collaborator, the collaborator receives a notification.
- When an admin reviews a verification task (PASS or FAIL), the collaborator receives a notification with the result and admin note.

The notification service integrates with Spring's `@TransactionalEventListener` to ensure notifications are sent only after the triggering transaction commits successfully, preventing users from receiving notifications for operations that later rolled back.

## 5.2.3 Achieved Results

The verification and risk assessment solution gives VoltGO a structured station data lifecycle. A station update can be proposed, assessed, verified, reviewed, approved, rejected, and later reflected in trust evaluation. The system records not only the final station data but also the reasons and evidence behind every decision.

This contribution improves explainability in administrative decisions. The administrator can review the proposed data, current data, risk reasons, GPS check-in result, evidence files, and historical trust information. High-risk change requests cannot be published without a passing field verification, providing a meaningful gate between data submission and public availability. The trust score provides an at-a-glance reliability signal that accumulates over time, allowing administrators to identify stations that repeatedly generate issues or fail verifications.

The admin web application provides a comprehensive interface for managing the entire workflow: a unified change requests screen with subtabs for charging stations and battery swap stations, showing risk scores with color-coded badges (green < 30, orange 30–59, red >= 60); a change request detail screen with risk breakdown, verification status indicator, station data comparison, and full audit log; a verification tasks management screen with status filtering, SLA tracking, priority indicators, and pagination; and a verification task detail screen with a status timeline, GPS check-in data including distance, a checklist with answer highlighting (yellow warning for "No" or "Unable to Verify" answers), evidence photo gallery with full-size lightbox viewer, battery swap snapshot comparison table, and a review dialog with PASS/FAIL result selection.

The collaborator mobile application provides task list and task detail screens where collaborators can view assigned tasks with SLA urgency highlighting, complete a verification checklist with yes/no/unable options (supplementary notes required for negative answers), perform GPS check-in (validated server-side against 200-meter radius), capture and upload evidence photos directly from the device camera, and for battery swap stations, additionally record total battery inventory, available batteries, and observed average charge power.

Table 5.3 summarizes the main data types used in the decision process.

**Table 5.3.** Verification and risk assessment data used for administrator decisions.

| Data Type | Produced By | Stored or Represented As | Decision Support Role |
|-----------|-----------|-------------------------|---------------------|
| Station proposal or change request | EV User, Collaborator, or Admin workflow | `ChangeRequestEntity` and proposed station version snapshot | Shows what data is being added or modified |
| Risk score and reasons | `RiskEngineService` (charging) / `BatterySwapRiskAssessor` (swap) | `riskScore` (0–100), `riskLevel` (HIGH/MEDIUM/LOW), `riskReasons` list | Explains why a change requires attention; triggers mandatory verification if score >= 60 |
| GPS check-in | Collaborator Mobile | `VerificationCheckinEntity` with coordinates, timestamp, and `distanceM` | Confirms whether the collaborator is within 200 meters of the station |
| Evidence photos | Collaborator Mobile | File keys in `VerificationEvidenceEntity`, actual files in MinIO | Supports visual validation of location and equipment |
| Verification checklist answers | Collaborator Mobile | JSONB in `VerificationCheckinEntity.checklistAnswersJson` | Maps each risk reason to a field confirmation or flag |
| Verification review | Admin Web | `VerificationReviewEntity` with PASS/FAIL result and admin note | Passes or blocks high-risk change request publication |
| Trust score and breakdown | `TrustScoringService` | `StationTrustEntity` (charging) / `BatterySwapTrustEntity` (swap) with JSON breakdown | Provides a long-term reliability signal per station |
| Issue reports | EV User Mobile | `ReportIssueEntity` with category, description, and status | Contributes to trust score penalty; informs operational decisions |
| Audit information | Admin workflow, Collaborator workflow | `AuditLogEntity` with actor, action, entity, timestamp, and JSON metadata | Records who made the final decision and when; traces self-assignment blocks |

## 5.2.4 Limitations

Several areas of the battery swap risk assessment framework are implemented structurally but not fully exercised in the current thesis scope:

- **Safety Risk** (Section 5.2.2.2, category 5): The `BatterySwapRiskAssessor` declares `SAFETY_CONCERN`, `MISSING_SAFETY_EQUIPMENT`, and `ENVIRONMENTAL_RISK` risk codes, but the station entity does not yet carry safety-relevant fields (indoor/outdoor setup, fire safety equipment, flood zone designation) that would trigger them. Including these codes in the enum establishes the framework for future data collection.
- **Financial Risk** (Section 5.2.2.2, category 4): `PRICE_DEVIATION` requires market-average price data that is not yet available in the system. The code is present and will activate once pricing reference data is integrated.
- **Provider Trust Risk** (Section 5.2.2.2, category 6): `HIGH_REJECTION_RATE` and `PENDING_VERIFICATIONS` are declared in the enum but not yet computed from historical data in the current implementation.

These limitations are acknowledged to avoid overclaiming the maturity of the risk engine and to clearly delineate what is scaffolded versus what is production-complete.
