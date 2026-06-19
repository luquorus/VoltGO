SELECT version, description, success, installed_on
FROM flyway_schema_history
ORDER BY installed_rank;
