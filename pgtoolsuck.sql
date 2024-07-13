#!/bin/bash

# because pg_dump and pg_restore suck dingus

# Check if required arguments are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <source_db_url> <target_db_name> <schema1> [<schema2> ...]"
    exit 1
fi

SOURCE_DB=$1
TARGET_DB=$2
shift 2
WHITELIST_SCHEMAS=("$@")
schema_list=$(IFS=,; echo "'${WHITELIST_SCHEMAS[*]}'")

# Function to execute SQL and handle errors
execute_sql() {
    local sql=$1
    local error_message=$2
    if ! psql -d "$TARGET_DB" -c "$sql"; then
        echo "Error: $error_message"
        echo "SQL: $sql"
        return 1
    fi
}

# Function to print a separator with a message
print_separator() {
    local message=$1
    echo "================ $message ================"
}

# --------------------- SCHEMAS ---------------------
echo "Creating schemas..."
for schema in "${WHITELIST_SCHEMAS[@]}"; do
    if execute_sql "CREATE SCHEMA IF NOT EXISTS $schema;" "Failed to create schema $schema"; then
        echo "Created schema: $schema"
    fi
done
print_separator "Schemas Created"

# --------------------- EXTENSIONS ---------------------
echo "Fetching extensions from source database..."
extensions=$(psql "$SOURCE_DB" -t -c "SELECT extname FROM pg_extension WHERE extname != 'plpgsql';")

echo "Creating extensions in target database..."
for ext in $extensions; do
    # Trim whitespace and quote the extension name
    ext=$(echo "$ext" | xargs)
    if output=$(psql -d "$TARGET_DB" -c "CREATE EXTENSION IF NOT EXISTS \"$ext\";" 2>&1); then
        echo "Created extension: $ext"
    else
        echo "Warning: Failed to create extension \"$ext\". Error:"
        echo "$output"
        echo "Continuing with next extension..."
    fi
done
print_separator "Extensions Created"


# --------------------- TYPES ---------------------
echo "Copying custom types to target database..."
print_separator "Custom Type Copy Started"

# Dump only the custom type definitions for the specified schemas
pg_dump --schema-only "$SOURCE_DB" | awk -v schemas="$schema_list" '
    BEGIN { print_type = 0; type_def = ""; in_schemas = 0 }
    /^-- Name: .*; Type: TYPE/ {
        split($0, a, ";");
        split(a[1], b, ".");
        schema = b[2];
        if (index(schemas, schema) > 0) {
            in_schemas = 1;
            print_type = 1;
            type_def = $0 "\n";
        } else {
            in_schemas = 0;
        }
    }
    /^--/ && !in_schemas { print_type = 0; type_def = ""; }
    print_type { type_def = type_def $0 "\n" }
    /;$/ && print_type {
        print type_def;
        print_type = 0;
        type_def = "";
    }
' > custom_types.sql

# Apply custom type definitions to the target database
if psql "$TARGET_DB" < custom_types.sql; then
    echo "Custom types copied successfully."
else
    echo "Warning: Some custom type definitions may have failed to copy. Please check the output above for details."
fi

# Clean up
rm custom_types.sql

print_separator "Custom Type Copy Completed"


# --------------------- TABLES STRUCTURE ---------------------
# Get list of tables from source database for whitelisted schemas
echo "Fetching table list from source database for schemas: ${WHITELIST_SCHEMAS[*]}"
tables=$(psql "$SOURCE_DB" -t -c "SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname IN ($schema_list);")
print_separator "Table List Fetched"

# Create tables in target database
echo "Creating table structures in target database..."
for table in $tables; do
    echo "Processing table: $table"
    create_table_sql=$(psql "$SOURCE_DB" -t -c "
        SELECT 'CREATE TABLE IF NOT EXISTS ' || '$table' || ' (' ||
            string_agg(column_name || ' ' || data_type ||
                CASE WHEN character_maximum_length IS NOT NULL
                     THEN '(' || character_maximum_length || ')'
                     ELSE '' END,
                ', ') ||
        ');'
        FROM information_schema.columns
        WHERE table_schema || '.' || table_name = '$table'
        GROUP BY table_schema, table_name;
    ")

    if ! execute_sql "$create_table_sql" "Failed to create table $table"; then
        echo "Warning: Failed to create table $table. Continuing with next table..."
    else
        echo "Created table: $table"
    fi
done

print_separator "Table Structures Created"


# --------------------- DATA ---------------------
echo "Dumping and restoring data for all tables..."
print_separator "Data Dump and Restore Started"

# Get the list of tables to dump
tables=$(psql "$SOURCE_DB" -t -c "SELECT schemaname || '.' || tablename FROM pg_tables WHERE schemaname IN ($schema_list);")

# Convert the list of tables into a space-separated string
table_list=$(echo "$tables" | tr '\n' ' ')

# Loop through each table to dump and restore individually
for table in $table_list; do
    # Trim leading and trailing whitespace
    table=$(echo "$table" | xargs)

    # Dump the table data
    if ! pg_dump --data-only --table="$table" "$SOURCE_DB" > "${table}_data.sql"; then
        echo "Error: Failed to dump data for table $table. Exiting."
        exit 1
    fi

    # Restore the table data
    if ! psql "$TARGET_DB" < "${table}_data.sql"; then
        echo "Error: Failed to restore data for table $table. Exiting."
        exit 1
    else
        echo "Data restored for table $table successfully."
    fi

    # Clean up dump file
    rm "${table}_data.sql"
done

print_separator "Data Dump and Restore Completed"


# --------------------- FUNCTIONS ---------------------
echo "Copying functions to target database..."
print_separator "Function Copy Started"

# Dump only the functions
pg_dump --schema-only --section=pre-data --no-owner --no-privileges --no-tablespaces --exclude-table='*' "$SOURCE_DB" > functions.sql

# Remove CREATE SCHEMA statements if they exist
sed -i '/CREATE SCHEMA/d' functions.sql

# Apply functions to the target database
if psql "$TARGET_DB" < functions.sql; then
    echo "Functions copied successfully."
else
    echo "Warning: Some functions may have failed to copy. Please check the output above for details."
fi

# Clean up
rm functions.sql

print_separator "Function Copy Completed"


# --------------------- CONSTRAINTS ---------------------
# Now proceed with adding constraints (previous section)
echo "Adding constraints to tables..."
print_separator "Constraint Addition Started"

# Dump only the constraint definitions
pg_dump --schema-only --section=post-data "$SOURCE_DB" > constraints.sql

# Apply constraints to the target database
if psql "$TARGET_DB" < constraints.sql; then
    echo "Constraints added successfully."
else
    echo "Warning: Some constraints may have failed to apply. Please check the output above for details."
fi

# Clean up
rm constraints.sql

# --------------------- VIEWS ---------------------
echo "Copying views to target database..."
print_separator "View Copy Started"

# Dump only the view definitions for the specified schemas
pg_dump --schema-only "$SOURCE_DB" | awk -v schemas="$schema_list" '
    BEGIN { print_view = 0; view_def = ""; in_schemas = 0 }
    /^-- Name: .*; Type: VIEW/ {
        split($0, a, ";");
        split(a[1], b, ".");
        schema = b[2];
        if (index(schemas, schema) > 0) {
            in_schemas = 1;
            print_view = 1;
            view_def = $0 "\n";
        } else {
            in_schemas = 0;
        }
    }
    /^--/ && !in_schemas { print_view = 0; view_def = ""; }
    print_view { view_def = view_def $0 "\n" }
    /;$/ && print_view {
        print view_def;
        print_view = 0;
        view_def = "";
    }
' > views.sql

# Apply view definitions to the target database
if psql "$TARGET_DB" < views.sql; then
    echo "Views copied successfully."
else
    echo "Warning: Some view definitions may have failed to copy. Please check the output above for details."
fi

# Clean up
rm views.sql

print_separator "View Copy Completed"

