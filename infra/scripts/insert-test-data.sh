#!/bin/bash
# Script to insert test data for Admin Verification Tasks UI testing

echo "Inserting test data for Admin Verification Tasks..."

# Read database connection from .env or use defaults
POSTGRES_DB=${POSTGRES_DB:-voltgo}
POSTGRES_USER=${POSTGRES_USER:-voltgo_user}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-admin123}

# Path to SQL file
SQL_FILE="../backend/src/main/resources/db/migration/V99__insert_test_data_for_verification_tasks.sql"

# Execute SQL file using docker exec
docker exec -i voltgo-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$SQL_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Test data inserted successfully!"
    echo ""
    echo "Test accounts:"
    echo "  - Admin: admin@local / Admin@123"
    echo "  - Collaborator 1: collab1@local / Admin@123"
    echo "  - Collaborator 2: collab2@local / Admin@123"
    echo ""
    echo "Created:"
    echo "  - 4 stations with published versions"
    echo "  - 2 change requests (PENDING, APPROVED)"
    echo "  - 10 verification tasks with various statuses"
    echo "  - Checkin records, evidences, and reviews"
else
    echo "❌ Failed to insert test data"
    exit 1
fi

