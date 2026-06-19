SELECT
    s.id AS station_id,
    s.name,
    bs.operating_hours,
    bs.total_batteries,
    bs.avg_charge_power_kw,
    bs.parking_fee,
    bs.note,
    bs.workflow_status::text AS workflow_status,
    sv.location IS NOT NULL AS has_location,
    sv.parking::text AS parking,
    ss.service_type::text AS service_type,
    ss.total_batteries AS svc_total_batteries,
    ss.avg_charge_power_kw AS svc_avg_power,
    bs.created_at
FROM battery_swap_station_version bs
JOIN station s ON s.id = bs.station_id
LEFT JOIN station_version sv ON sv.station_id = s.id AND sv.workflow_status = 'PUBLISHED'
LEFT JOIN station_service ss ON ss.station_version_id = sv.id
WHERE bs.created_at > NOW() - INTERVAL '30 minutes'
ORDER BY bs.created_at DESC;
