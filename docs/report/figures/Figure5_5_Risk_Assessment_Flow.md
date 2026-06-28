@startuml Figure5_5_Risk_Assessment_Flow
!theme plain

title "Figure 5.5: Risk Assessment Flow for Station Data Changes"

|#LightYellow|START|
start

|==Load Data==|
:Load proposed Station Version\n(from changeRequest.proposedStationVersionId);
:Load published Station Version\n(from station_id, workflow_status = PUBLISHED);
note right
  For CREATE_STATION:
  published version = null
end note

|==Determine CR Type==|
if (ChangeRequest.type == CREATE_STATION?) then (Yes)
  :Add risk reason: NEW_STATION (+10);
  :Assess BATTERY_SWAP services\n(if applicable);
  → go to Scoring;
else (UPDATE_STATION)
  :Compare proposed vs published;
  if (published version exists?) then (Yes)
    :Proceed with comparison;
  else (No)
    :Treat as CREATE → add NEW_STATION;
    :Assess BATTERY_SWAP services;
    → go to Scoring;
  endif
endif

|==Charging Station Checks==|
if (GPS distance > 100m?) then (Yes)
  :GPS_CHANGED_100M (+50);
else (No)
  :No GPS risk;
endif

if (Port multiset changed?) then (Yes)
  :PORTS_CHANGED (+30);
else (No)
  :No port risk;
endif

if (Operating hours changed?) then (Yes)
  :HOURS_CHANGED (+10);
else (No)
  :No hours risk;
endif

if (Visibility or public status changed?) then (Yes)
  :ACCESS_CHANGED (+10);
else (No)
  :No access risk;
endif

|==Battery Swap Checks (if applicable)==|
if (BATTERY_SWAP service exists?) then (Yes)
  if (totalBatteries < 5?) then (Yes)
    :SWAP_LOW_INVENTORY (+30);
  endif

  if (avgChargePower < 10 OR > 200 kW?) then (Yes)
    :SWAP_AVG_POWER_OUT_OF_RANGE (+20);
  endif

  if (published BATTERY_SWAP exists?) then (Yes)
    if (Config changed?) then (Yes)
      :SWAP_CONFIG_CHANGED (+30);
    endif
  else (No — new swap service)
    :SWAP_CONFIG_CHANGED (+30);
  endif
else (No BATTERY_SWAP)
  :Skip battery swap checks;
endif

|==Scoring==|
#LightGreen:Sum all triggered scores;
:cap score = min(total, 100);
if (score >= 50?) then (Yes)
  :Risk Level = HIGH;
else (No, score >= 30?)
  if (Yes) then
    :Risk Level = MEDIUM;
  else
    :Risk Level = LOW;
  endif
endif

|==Save Result==|
:Save to ChangeRequestEntity:\n• riskScore\n• riskReasons (list of codes)\n• riskLevel;
:Audit log: SUBMIT_CHANGE_REQUEST\n(with risk metadata);

|==Post-Assessment==|
if (riskScore >= 60?) then (Yes)
  :System flags CR as HIGH RISK\n→ Publish blocked without verification PASS;
  note right
    This gate is enforced in
    AdminChangeRequestService.
    publishChangeRequest()
  end note
else (No)
  :CR can be published\nwithout field verification;
endif

stop

legend right
  **Score Caps:**
  Total score capped at 100

  **Thresholds:**
  HIGH: score >= 50
  MEDIUM: 30 <= score < 50
  LOW: score < 30

  **Publish Gate:**
  riskScore >= 60
  → requires verification PASS
end legend

|#LightYellow|END|

@enduml
