# Oracle 26ai Banking Demo (Python-First)

This directory is the execution runbook for the Oracle 26ai banking demo.
It is intentionally demo-oriented, not a separate lab product.

## What this folder contains

- Python orchestration entrypoint: `demo.py`
- SQL setup and use-case scripts:
  - Core setup and AI build scripts under `setup/` and root SQL files
  - Use-case scripts `09_uc1_card_view.sql`, `10_uc2_abandoned_app.sql`, `11_uc3_declined_txn.sql`
- Optional self-check SQL modules:
  - `setup/lab_setup.sql`
  - `lab01_vectors.sql` through `lab06_ops.sql`
  - `lab_report.sql`

## Execution modes

Two first-class workflows are supported:

1. Container workflow (local-first)
   - Starts local Oracle container
   - Processes demo datasets locally
   - Runs core and use-case SQL
   - Does not use OCI Object Storage

2. Cloud workflow
   - Processes datasets
   - Uploads artifacts to OCI Object Storage
   - Runs core and use-case SQL against cloud database

## Quick start

From the `demo-code` directory:

```bash
python3 demo.py workflow-container
```

Cloud workflow:

```bash
python3 demo.py workflow-cloud
```

## Demo command reference

```bash
python3 demo.py --help
python3 demo.py workflow-container --help
python3 demo.py workflow-cloud --help
python3 demo.py run-sql-sequence --help
```

## Configuration model

Configuration is default-first and demo-oriented:

- Container mode works with built-in defaults for local execution.
- Cloud mode requires database credentials and usually OCI upload settings.
- Environment values are optional overrides except where secrets are required.

Typical cloud values:

- `ORACLE_USER`
- `ORACLE_PASSWORD`
- `ORACLE_DSN`
- `OCI_NAMESPACE`
- `OCI_BUCKET_NAME`

## Optional self-check modules

The `lab*.sql` scripts are optional scoring and evidence checks for training and governance validation. They can be run after core demo SQL if you want a PASS/FAIL/MANUAL report, but the primary purpose of this folder remains demo execution.
