# portfolio-wbr-dbt

dbt Core project (Databricks adapter) that transforms a synthetic US mortgage
lead funnel into a star schema for a Weekly Business Review (WBR) in Power BI,
later exposed through Unity Catalog metric views and a Genie Agent.
Portfolio project: code, tests and docs must be production-quality and in English.

## Architecture
Azure SQL (simulated CRM/LOS, repo `portfolio-wbr-source-data`)
  â†’ Fivetran (Change Tracking, daily ~08:30 UTC)
  â†’ Bronze: `wbr_raw.azure_sql_db_crm.*`   (written by Fivetran, never modified)
  â†’ Silver: `wbr_analytics.silver`      (models/staging + models/intermediate)
  â†’ Gold:   `wbr_analytics.gold`        (models/marts, star schema)
  â†’ Power BI, then UC metric views + Genie (phase 2)

## Environment
- Windows 11, PowerShell (no `&&`; use `;` or separate lines), VS Code
- Python venv `.venv`, dbt-core 1.12 + dbt-databricks 1.12, Databricks Free Edition
  (serverless SQL warehouse only, restricted outbound network)
- `profiles.yml` lives in `~/.dbt/` (outside the repo, holds the token). Profile `wbr_dbt`,
  target `dev`: catalog `wbr_analytics`, schema `dbt_dev`, threads 4
- dbt Core is the engine (not Fusion); keep the project Fusion-compatible where easy

## Conventions
- Folders: staging (`stg_`), intermediate (`int_`), marts (`fct_`, `dim_`)
- Schemas: `+schema: silver` for staging/intermediate, `+schema: gold` for marts
- Custom `generate_schema_name`: target `prod` â†’ exact `silver`/`gold`;
  any other target â†’ `<target.schema>_<custom>` (e.g. `dbt_dev_silver`)
- staging/intermediate materialized as views, marts as tables (incremental later)
- Use `dbt build` (not `run`) in CI/prod; every model gets at least PK tests

## Source tables (`wbr_raw.azure_sql_db_crm`), all timestamps UTC
Fivetran adds `_fivetran_synced` and `_fivetran_deleted` (soft deletes: filter them out in staging).
- teams(team_id PK, team_name, region, covered_states, updated_at): 7 teams
- loan_officers(lo_id PK, first_name, last_name, email, team_id, hire_date,
  termination_date, is_active, updated_at): CURRENT STATE ONLY; team transfers
  overwrite team_id â†’ rebuild history with a dbt snapshot (SCD2)
- leads(lead_id PK, created_at, first_name, last_name, email, phone, channel,
  loan_purpose, property_state, property_zip, est_loan_amount, credit_band,
  current_stage, status[open|funded|closed_lost], lost_reason, assigned_lo_id,
  closed_at, updated_at)
- lead_assignments(assignment_id PK, lead_id, lo_id, assigned_at, unassigned_at,
  assignment_reason[initial|rebalance|lo_departure], updated_at)
- lead_stage_events(event_id PK, lead_id, stage, event_ts, lo_id, source_system[crm|los],
  recorded_at): append-only; stages lead_created â†’ assigned â†’ pre_approved â†’
  rate_locked â†’ funded, plus closed_lost
- rate_locks(lock_id PK, lead_id, locked_at, lock_period_days, interest_rate,
  loan_amount, expires_at, extension_days, status[active|extended|funded|expired|cancelled], updated_at)
- fundings(funding_id PK, lead_id, lock_id, funded_at, funded_amount, recorded_at)

## Deliberate data-quality issues (silver must handle them)
- ~2% duplicate leads (same person within 72h, email casing/whitespace and phone
  formats differ); most closed with lost_reason='duplicate', not all
- Late LOS events: recorded_at can be hours to 10 days after event_ts (order by event_ts)
- Double-posted LOS events: same lead_id + stage + event_ts, different event_id
- Re-locks: a lead can have 2 rate_locks (first expired) and 2 rate_locked events
- Messy contacts: phone formats "(212) 555-0147" / "212-555-0147" / "+12125550147",
  uppercase emails, trailing spaces; some null email/phone/est_loan_amount/credit_band
- ~30% of dead leads auto-closed after 90 days (lost_reason='stale_auto_closed')

## Planted stories (WBR commentary + Genie benchmark)
1. Paid search campaign 2025-05-05 â†’ 2025-06-14: paid_search volume +~70%,
   pre-approval rate ~13% â†’ ~5%
2. Southeast team (team_id 6) crunch Feb 2026: 4 LOs leave, median speed-to-assign
   ~10 min â†’ ~4 h, assignment rate 91% â†’ 83%, recovers in March

## Target model (gold)
- fct_lead_funnel: accumulating snapshot, 1 row per lead, one timestamp per stage,
  stage-to-stage durations, final status
- fct_stage_events (1 row per transition), fct_rate_locks (1 row per lock)
- dim_date, dim_loan_officer (SCD2 from snapshot), dim_channel, dim_geography, dim_loan_product

## Next tasks
1. dbt_project.yml schema config + macros/generate_schema_name.sql
2. models/staging/_sources.yml (database wbr_raw, schema azure_sql_db_crm,
   freshness on _fivetran_synced) + 7 stg_ models + tests
3. int_ models (dedup leads and events, lock chains), snapshot on loan_officers
4. Gold star schema + tests, then GitHub Actions CI (dbt build on a per-PR schema)