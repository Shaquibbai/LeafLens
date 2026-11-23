-- ============================================================================
-- LeafLense Database – Master Runner Script
-- File: 00_run_all.sql
-- ============================================================================
--
-- PURPOSE:
--   Executes all LeafLense database setup scripts in the correct order.
--   This creates the complete database schema, functions, triggers, and
--   loads sample data for the crop leaf disease detection system.
--
-- HOW TO RUN:
--   From the command line (navigate to this file's directory first):
--
--     psql -U postgres -f 00_run_all.sql
--
--   Or if connecting to a specific host/database:
--
--     psql -h localhost -U postgres -d leaflense_db -f 00_run_all.sql
--
-- PREREQUISITES:
--   • PostgreSQL 12+ installed and running
--   • Superuser or CREATE DATABASE privileges
--   • All SQL files in the same directory as this script
--
-- FILE EXECUTION ORDER:
--   1. 01_schema.sql              – Schema, types, roles, tables, permissions
--   2. 02_functions_procedures.sql – Admin functions & application procedures
--   3. 03_triggers.sql            – Validation & audit triggers
--   4. 05_seed_data.sql           – Sample/test data
--   5. 04_queries.sql             – Reference queries (run manually)
--
-- ============================================================================

\echo '============================================================'
\echo ' LeafLense Database Setup'
\echo '============================================================'
\echo ''

-- ---- Step 1: Schema, Types, Roles, Tables, Indexes, Permissions ----
\echo '[1/4] Creating schema, tables, and permissions...'
\i 01_schema.sql
\echo '      ✓ Schema created successfully.'
\echo ''

-- ---- Step 2: Functions & Procedures ----
\echo '[2/4] Creating functions and procedures...'
\i 02_functions_procedures.sql
\echo '      ✓ Functions and procedures created successfully.'
\echo ''

-- ---- Step 3: Triggers ----
\echo '[3/4] Creating triggers...'
\i 03_triggers.sql
\echo '      ✓ Triggers created successfully.'
\echo ''

-- ---- Step 4: Seed Data ----
\echo '[4/4] Loading seed data...'
\i 05_seed_data.sql
\echo '      ✓ Seed data loaded successfully.'
\echo ''

-- ---- Queries (reference only – uncomment to run) ----
-- \echo '[Optional] Running reference queries...'
-- \i 04_queries.sql

\echo '============================================================'
\echo ' LeafLense Database Setup Complete!'
\echo ''
\echo ' Tables created:  11'
\echo ' Functions:       3  (admin-restricted)'
\echo ' Procedures:      3'
\echo ' Triggers:        5'
\echo ''
\echo ' To run reference queries:'
\echo '   psql -U postgres -d leaflense_db -f 04_queries.sql'
\echo ''
\echo ' Roles created:'
\echo '   leaflense_admin    (full access)'
\echo '   leaflense_app      (application DML)'
\echo '   leaflense_readonly (read-only)'
\echo '============================================================'
