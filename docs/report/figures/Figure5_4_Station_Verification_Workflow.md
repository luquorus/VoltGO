@startuml Figure5_4_Station_Verification_Workflow
!theme plain

title "Hình 5.4: Station Data Contribution & Field Verification Workflow"

|==Actor==|
note top
  **Actor tham gia:**
  • EV User / Collaborator
  • Admin
  • Collaborator (field)
  • System (Risk Engine)
end note

|==1. Station Proposal Submission==|
:EV User hoặc Collaborator\nsubmit station proposal\n(CREATE_STATION hoặc UPDATE_STATION);
:System tạo **Change Request**\nvới status = DRAFT\n+ tạo Station Version (DRAFT);
:User gọi API submitChangeRequest();
:**Risk Engine** assessChangeRequest()\n→ tính riskScore + riskReasons;
:Change Request status = PENDING\n+ Station Version status = PENDING;
:Audit log: SUBMIT_CHANGE_REQUEST\n(ghi riskScore, riskLevel, riskReasons);

|==2. Risk-Based Decision Gate==|
if (riskScore >= 60?) then (Yes\nHIGH RISK)
  :Tạo **Verification Task** (OPEN)\n+ generate checklist từ riskReasons\n+ lưu station snapshot;
  :Admin gán task cho Collaborator;
  :Collaborator nhận notification\n"TASK_ASSIGNED";
  note right
    **Collaborator đi đến trạm**
    GPS check-in: ST_Distance(collaborator, station) <= 200m
    Nếu > 200m → REJECT
  end note
  :Collaborator thực hiện\n**GPS Check-in** tại site;
  if (distance <= 200m?) then (No)
    :System reject check-in\n"Too far from station";
  endif
  :Collaborator trả lời **Checklist**\n(Yes/No/Unable to Verify\n+ supplementary note bắt buộc\nnếu No/Unable);
  :Collaborator upload\n**Evidence Photos** lên MinIO;
  :Verification Task status = SUBMITTED;
  :Admin nhận notification;
  :Admin **Review Task**\n→ PASS hoặc FAIL;
  if (Result = PASS?) then (Yes)
    :Trust score recalculate (+20);
    :Admin **Approve** Change Request;
  else (No)
    :Trust score recalculate (-20);
    :Admin **Reject** Change Request\n→ Station Version = REJECTED;
    stop
  endif
else (No\nLOW/MEDIUM RISK)
  :Admin **Approve** Change Request\n(không cần verification);
endif

|==3. Publish Decision==|
if (CR status = APPROVED?) then (Yes)
  if (riskScore >= 60 AND\nverification PASS?) then (Yes)
    :Admin **Publish** Change Request;
  else (No)
    :System BLOCKS publish\n"High-risk CR requires\nverification PASS first";
    stop
  endif
else (No\nREJECTED)
  :Station Version = REJECTED;
  stop
endif

|==4. Publish Execution==|
note right
  **Atomic publish operation**
  Pessimistic lock on station row
  (prevents concurrent publish)
end note
:System **Archive** old published version\n→ status = ARCHIVED;
:System **Publish** new version\n→ status = PUBLISHED + publishedAt;
:System **Create Charger Units**\ntừ charging ports;
:System **Apply Battery Swap config**\nnếu có BATTERY_SWAP service;
:Change Request status = PUBLISHED;
:Audit log: PUBLISH_STATION_VERSION;
:**Trust score recalculate**\n(base + penalties);
:Submitter nhận notification\n"CR is live";
stop

|==5. Trust Score Recalculation (Background)==|
note right
  Trust score cũng được trigger
  khi có Issue report từ users
end note
if (Issue created?) then (Yes)
  :System recalculate trust\n→ issuesPenalty = -5 per OPEN issue (max -30);
endif
if (Issue resolved/rejected?) then (Yes)
  :System recalculate trust\n→ penalty removed;
endif

legend right
  **Màu sắc trạng thái:**
  * DRAFT, PENDING, APPROVED, REJECTED, PUBLISHED = Change Request statuses
  * OPEN, ASSIGNED, CHECKED_IN, SUBMITTED, REVIEWED = Verification Task statuses
  * riskScore >= 60 → HIGH RISK → mandatory field verification
  * GPS check-in max distance: 200m (PostGIS ST_Distance)
  * Trust base: 50, Verification PASS: +20, FAIL: -20
end legend

@enduml
