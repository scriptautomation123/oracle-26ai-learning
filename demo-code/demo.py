#!/usr/bin/env python3
"""Principal-engineer Python orchestration for Oracle 26ai demo-code.

This module provides local-first workflows and keeps environment variables as
optional overrides. Container workflow does not require OCI Object Storage.
"""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time
import urllib.request
import zipfile


DEMO_ROOT = Path(__file__).resolve().parent
PROJECT_ROOT = DEMO_ROOT.parent
SETUP_DIR = DEMO_ROOT / "setup"
DATA_RAW_DIR = DEMO_ROOT / "data" / "raw"
DATA_PROCESSED_DIR = DEMO_ROOT / "data" / "processed"
VENV_DIR = PROJECT_ROOT / ".venv"
REQ_FILE = DEMO_ROOT / "requirements.txt"
REQ_HASH_FILE = VENV_DIR / ".demo_code_requirements.sha256"

CORE_SQL_FILES = [
    SETUP_DIR / "01_schema.sql",
    SETUP_DIR / "02_staging_ddl.sql",
    SETUP_DIR / "03_load_onnx_model.sql",
    SETUP_DIR / "04_copy_data.sql",
    SETUP_DIR / "05_transform.sql",
    SETUP_DIR / "06_embed_and_index.sql",
    DEMO_ROOT / "07_property_graph.sql",
    SETUP_DIR / "08_select_ai_profile.sql",
]

UC_SQL_FILES = [
    DEMO_ROOT / "09_uc1_card_view.sql",
    DEMO_ROOT / "10_uc2_abandoned_app.sql",
    DEMO_ROOT / "11_uc3_declined_txn.sql",
]


class DemoError(RuntimeError):
    """Raised for user-facing demo command failures."""


def load_dotenv(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values

    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        values[key] = val
    return values


def merged_env() -> dict[str, str]:
    env = load_dotenv(PROJECT_ROOT / ".env")
    env.update({k: v for k, v in os.environ.items() if isinstance(v, str)})
    return env


def run_cmd(cmd: list[str], *, cwd: Path | None = None, env: dict[str, str] | None = None) -> None:
    print(f"$ {' '.join(cmd)}")
    subprocess.run(cmd, check=True, cwd=str(cwd) if cwd else None, env=env)


def hash_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def python_in_venv() -> Path:
    if os.name == "nt":
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def ensure_venv() -> None:
    if not VENV_DIR.exists():
        print(f"Creating virtual environment at {VENV_DIR}")
        run_cmd([sys.executable, "-m", "venv", str(VENV_DIR)])

    py = python_in_venv()
    if not py.exists():
        raise DemoError(f"Python executable not found in venv: {py}")

    run_cmd([str(py), "-m", "pip", "install", "--upgrade", "pip"])

    if not REQ_FILE.exists():
        print(f"No requirements file at {REQ_FILE}; skipping dependency install.")
        return

    current_hash = hash_file(REQ_FILE)
    previous_hash = REQ_HASH_FILE.read_text(encoding="utf-8").strip() if REQ_HASH_FILE.exists() else ""
    if current_hash == previous_hash:
        print("requirements.txt unchanged; skipping reinstall.")
        return

    run_cmd([str(py), "-m", "pip", "install", "-r", str(REQ_FILE)])
    REQ_HASH_FILE.write_text(current_hash, encoding="utf-8")
    print("Dependency install complete.")


def require_command(command: str) -> None:
    if shutil.which(command) is None:
        raise DemoError(f"Required command not found in PATH: {command}")


def setup_kaggle() -> None:
    ensure_venv()
    py = python_in_venv()
    run_cmd([str(py), "-m", "pip", "install", "kaggle"])

    kaggle_json = Path.home() / ".kaggle" / "kaggle.json"
    print("Ensure Kaggle API key exists at ~/.kaggle/kaggle.json")
    print("1) Create API token in Kaggle account settings")
    print("2) Save to ~/.kaggle/kaggle.json")
    print("3) Run: chmod 600 ~/.kaggle/kaggle.json")
    if kaggle_json.exists():
        kaggle_json.chmod(0o600)
        print("kaggle.json found and permissions set to 600")
    else:
        print(f"WARNING: {kaggle_json} not found")


def download_data() -> None:
    ensure_venv()
    require_command("kaggle")
    require_command("unzip")

    (DATA_RAW_DIR / "paysim").mkdir(parents=True, exist_ok=True)
    (DATA_RAW_DIR / "lendingclub").mkdir(parents=True, exist_ok=True)
    (DATA_RAW_DIR / "banking77").mkdir(parents=True, exist_ok=True)
    (DATA_RAW_DIR / "uci").mkdir(parents=True, exist_ok=True)
    DATA_PROCESSED_DIR.mkdir(parents=True, exist_ok=True)

    run_cmd(["kaggle", "datasets", "download", "-d", "ealaxi/paysim1", "-p", str(DATA_RAW_DIR / "paysim"), "--unzip"])
    run_cmd(["kaggle", "datasets", "download", "-d", "wordsforthewise/lending-club", "-p", str(DATA_RAW_DIR / "lendingclub"), "--unzip"])
    run_cmd(["kaggle", "datasets", "download", "-d", "hwassner/banking77", "-p", str(DATA_RAW_DIR / "banking77"), "--unzip"])

    uci_zip = DATA_RAW_DIR / "uci" / "bank_marketing.zip"
    print("Downloading UCI Bank Marketing...")
    urllib.request.urlretrieve(
        "https://archive.ics.uci.edu/static/public/222/bank+marketing.zip",
        uci_zip,
    )
    with zipfile.ZipFile(uci_zip, "r") as archive:
        archive.extractall(DATA_RAW_DIR / "uci")

    print("Download complete.")


def trim_lending(input_path: Path, output_path: Path, rows: int = 5000) -> None:
    ensure_venv()
    py = python_in_venv()
    run_cmd(
        [
            str(py),
            str(SETUP_DIR / "02_trim_lending.py"),
            "--input",
            str(input_path),
            "--output",
            str(output_path),
            "--rows",
            str(rows),
        ]
    )


def generate_conversations(input_path: Path, output_path: Path) -> None:
    ensure_venv()
    py = python_in_venv()
    run_cmd(
        [
            str(py),
            str(SETUP_DIR / "03_gen_conversations.py"),
            "--input",
            str(input_path),
            "--output",
            str(output_path),
        ]
    )


def upload_to_oci(namespace: str | None, bucket: str | None) -> None:
    env = merged_env()
    namespace = namespace or env.get("OCI_NAMESPACE")
    bucket = bucket or env.get("OCI_BUCKET_NAME")

    if not namespace or not bucket:
        raise DemoError("Cloud upload requires OCI_NAMESPACE and OCI_BUCKET_NAME (args or env/.env).")

    require_command("oci")

    files = [
        DATA_RAW_DIR / "paysim" / "PS_20174392719_1491204439457_log.csv",
        DATA_PROCESSED_DIR / "lendingclub_5k.csv",
        DATA_PROCESSED_DIR / "banking77_conversations.csv",
        DATA_RAW_DIR / "uci" / "bank-additional" / "bank-additional-full.csv",
    ]

    for file_path in files:
        if not file_path.exists():
            print(f"Skipping missing file: {file_path}")
            continue
        run_cmd(
            [
                "oci",
                "os",
                "object",
                "put",
                "--namespace-name",
                namespace,
                "--bucket-name",
                bucket,
                "--name",
                file_path.name,
                "--file",
                str(file_path),
                "--force",
            ]
        )

    print("OCI upload complete.")


def start_oracle_container(runtime: str | None = None) -> None:
    env = merged_env()
    runtime = runtime or env.get("ORACLE_CONTAINER_RUNTIME", "docker")
    require_command(runtime)

    container_name = env.get("ORACLE_CONTAINER_NAME", "oracle-26ai-nudges")
    container_image = env.get("ORACLE_CONTAINER_IMAGE", "container-registry.oracle.com/database/free:latest")
    container_password = env.get("ORACLE_CONTAINER_PASSWORD", "Welcome12345#")
    host_port = int(env.get("ORACLE_CONTAINER_PORT", "1521"))
    db_port = 1521
    app_user = env.get("ORACLE_LOCAL_USER", "testuser")
    app_password = env.get("ORACLE_LOCAL_PASSWORD", "TestPass123")

    ps_cmd = [runtime, "ps", "-a", "--format", "{{.Names}}"]
    result = subprocess.run(ps_cmd, check=True, capture_output=True, text=True)
    existing = {line.strip() for line in result.stdout.splitlines() if line.strip()}

    if container_name in existing:
        status = subprocess.run(
            [runtime, "inspect", "-f", "{{.State.Status}}", container_name],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        if status != "running":
            run_cmd([runtime, "start", container_name])
        else:
            print(f"Container {container_name} already running.")
    else:
        run_cmd(
            [
                runtime,
                "run",
                "-d",
                "--name",
                container_name,
                "-p",
                f"{host_port}:{db_port}",
                "-e",
                f"ORACLE_PWD={container_password}",
                "-e",
                f"APP_USER={app_user}",
                "-e",
                f"APP_USER_PASSWORD={app_password}",
                container_image,
            ]
        )

    print(f"Waiting for Oracle listener on localhost:{host_port}...")
    deadline = time.time() + 600
    while time.time() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", host_port), timeout=2):
                print("Oracle listener is reachable.")
                return
        except OSError:
            time.sleep(5)

    raise DemoError(f"Timed out waiting for Oracle listener on port {host_port}.")


def resolve_sql_client(preferred: str) -> str:
    if preferred in {"sql", "sqlplus"}:
        require_command(preferred)
        return preferred
    if preferred != "auto":
        raise DemoError("--sql-client must be one of: auto, sql, sqlplus")

    if shutil.which("sql"):
        return "sql"
    if shutil.which("sqlplus"):
        return "sqlplus"
    raise DemoError("No SQL client found. Install SQLcl (sql) or SQL*Plus (sqlplus).")


def run_sql_sequence(connect: str, files: list[Path], sql_client: str = "auto", tns_admin: str | None = None) -> None:
    client = resolve_sql_client(sql_client)

    env = os.environ.copy()
    if tns_admin:
        env["TNS_ADMIN"] = tns_admin

    for file_path in files:
        if not file_path.exists():
            raise DemoError(f"SQL file not found: {file_path}")
        print(f"Running {file_path}")
        if client == "sql":
            run_cmd(["sql", "-S", connect, f"@{file_path}"], env=env)
        else:
            run_cmd(["sqlplus", "-L", "-S", connect, f"@{file_path}"], env=env)

    print("SQL sequence completed.")


def build_connect_string(mode: str, connect_override: str | None) -> str:
    if connect_override:
        return connect_override

    env = merged_env()
    if mode == "container":
        user = env.get("ORACLE_LOCAL_USER", "testuser")
        password = env.get("ORACLE_LOCAL_PASSWORD", "TestPass123")
        dsn = env.get("ORACLE_LOCAL_DSN", "localhost:1521/FREEPDB1")
        return f"{user}/{password}@{dsn}"

    user = env.get("ORACLE_USER")
    password = env.get("ORACLE_PASSWORD")
    dsn = env.get("ORACLE_DSN")
    if not user or not password or not dsn:
        raise DemoError(
            "Cloud workflow needs ORACLE_USER, ORACLE_PASSWORD, ORACLE_DSN "
            "(or pass --connect user/password@dsn)."
        )
    return f"{user}/{password}@{dsn}"


def workflow_container(sql_client: str, connect_override: str | None, skip_download: bool, skip_kaggle_setup: bool, skip_container_start: bool) -> None:
    ensure_venv()

    if not skip_kaggle_setup:
        setup_kaggle()
    if not skip_download:
        download_data()

    trim_lending(
        DATA_RAW_DIR / "lendingclub" / "accepted_2007_to_2018Q4.csv",
        DATA_PROCESSED_DIR / "lendingclub_5k.csv",
    )
    generate_conversations(
        DATA_RAW_DIR / "banking77" / "banking77.csv",
        DATA_PROCESSED_DIR / "banking77_conversations.csv",
    )

    if not skip_container_start:
        start_oracle_container()

    connect = build_connect_string("container", connect_override)
    run_sql_sequence(connect, CORE_SQL_FILES, sql_client=sql_client)
    run_sql_sequence(connect, UC_SQL_FILES, sql_client=sql_client)


def workflow_cloud(sql_client: str, connect_override: str | None, skip_download: bool, skip_kaggle_setup: bool, skip_upload: bool, oci_namespace: str | None, oci_bucket: str | None) -> None:
    ensure_venv()

    if not skip_kaggle_setup:
        setup_kaggle()
    if not skip_download:
        download_data()

    trim_lending(
        DATA_RAW_DIR / "lendingclub" / "accepted_2007_to_2018Q4.csv",
        DATA_PROCESSED_DIR / "lendingclub_5k.csv",
    )
    generate_conversations(
        DATA_RAW_DIR / "banking77" / "banking77.csv",
        DATA_PROCESSED_DIR / "banking77_conversations.csv",
    )

    if not skip_upload:
        upload_to_oci(oci_namespace, oci_bucket)

    connect = build_connect_string("cloud", connect_override)
    tns_admin = merged_env().get("TNS_ADMIN")
    run_sql_sequence(connect, CORE_SQL_FILES, sql_client=sql_client, tns_admin=tns_admin)
    run_sql_sequence(connect, UC_SQL_FILES, sql_client=sql_client, tns_admin=tns_admin)


def add_common_workflow_flags(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--sql-client", default="auto", choices=["auto", "sql", "sqlplus"])
    parser.add_argument("--connect", default=None, help="Explicit connect override: user/password@dsn")
    parser.add_argument("--skip-kaggle-setup", action="store_true")
    parser.add_argument("--skip-download", action="store_true")


def main() -> int:
    parser = argparse.ArgumentParser(description="Oracle 26ai demo-code Python orchestration")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("bootstrap-venv", help="Create/update .venv and install requirements")
    sub.add_parser("setup-kaggle", help="Install kaggle and verify kaggle.json permissions")
    sub.add_parser("download-data", help="Download demo datasets")

    trim = sub.add_parser("trim-lending", help="Trim LendingClub dataset")
    trim.add_argument("--input", required=True)
    trim.add_argument("--output", required=True)
    trim.add_argument("--rows", type=int, default=5000)

    conv = sub.add_parser("gen-conversations", help="Generate conversation dataset")
    conv.add_argument("--input", required=True)
    conv.add_argument("--output", required=True)

    upload = sub.add_parser("upload-oci", help="Upload demo assets to OCI Object Storage")
    upload.add_argument("--oci-namespace", default=None)
    upload.add_argument("--oci-bucket", default=None)

    start = sub.add_parser("start-container", help="Start local Oracle container")
    start.add_argument("--runtime", default=None, help="Container runtime: docker or podman")

    sql = sub.add_parser("run-sql-sequence", help="Run one or more SQL files")
    sql.add_argument("--sql-client", default="auto", choices=["auto", "sql", "sqlplus"])
    sql.add_argument("--connect", required=True)
    sql.add_argument("--tns-admin", default=None)
    sql.add_argument("files", nargs="+", help="SQL files to execute in order")

    wf_container = sub.add_parser(
        "workflow-container",
        help="Local-first setup: no OCI upload, container + SQL execution",
    )
    add_common_workflow_flags(wf_container)
    wf_container.add_argument("--skip-container-start", action="store_true")

    wf_cloud = sub.add_parser(
        "workflow-cloud",
        help="Cloud setup: includes OCI upload + cloud SQL execution",
    )
    add_common_workflow_flags(wf_cloud)
    wf_cloud.add_argument("--skip-upload", action="store_true")
    wf_cloud.add_argument("--oci-namespace", default=None)
    wf_cloud.add_argument("--oci-bucket", default=None)

    legacy = sub.add_parser("orchestrate", help="Legacy compatibility command")
    legacy.add_argument("--mode", default="cloud", choices=["cloud", "container"])
    legacy.add_argument("--stage", default="all", choices=["data", "upload", "container", "sql-core", "sql-uc", "all"])
    legacy.add_argument("--sql-client", default="auto", choices=["auto", "sql", "sqlplus"])
    legacy.add_argument("--skip-kaggle-setup", action="store_true")
    legacy.add_argument("--skip-download", action="store_true")
    legacy.add_argument("--skip-upload", action="store_true")
    legacy.add_argument("--connect", default=None)

    args = parser.parse_args()

    try:
        if args.command == "bootstrap-venv":
            ensure_venv()
        elif args.command == "setup-kaggle":
            setup_kaggle()
        elif args.command == "download-data":
            download_data()
        elif args.command == "trim-lending":
            trim_lending(Path(args.input), Path(args.output), rows=args.rows)
        elif args.command == "gen-conversations":
            generate_conversations(Path(args.input), Path(args.output))
        elif args.command == "upload-oci":
            upload_to_oci(args.oci_namespace, args.oci_bucket)
        elif args.command == "start-container":
            start_oracle_container(runtime=args.runtime)
        elif args.command == "run-sql-sequence":
            run_sql_sequence(args.connect, [Path(p) for p in args.files], sql_client=args.sql_client, tns_admin=args.tns_admin)
        elif args.command == "workflow-container":
            workflow_container(
                sql_client=args.sql_client,
                connect_override=args.connect,
                skip_download=args.skip_download,
                skip_kaggle_setup=args.skip_kaggle_setup,
                skip_container_start=args.skip_container_start,
            )
        elif args.command == "workflow-cloud":
            workflow_cloud(
                sql_client=args.sql_client,
                connect_override=args.connect,
                skip_download=args.skip_download,
                skip_kaggle_setup=args.skip_kaggle_setup,
                skip_upload=args.skip_upload,
                oci_namespace=args.oci_namespace,
                oci_bucket=args.oci_bucket,
            )
        elif args.command == "orchestrate":
            if args.mode == "container" and args.stage == "all":
                workflow_container(
                    sql_client=args.sql_client,
                    connect_override=args.connect,
                    skip_download=args.skip_download,
                    skip_kaggle_setup=args.skip_kaggle_setup,
                    skip_container_start=False,
                )
            elif args.mode == "cloud" and args.stage == "all":
                workflow_cloud(
                    sql_client=args.sql_client,
                    connect_override=args.connect,
                    skip_download=args.skip_download,
                    skip_kaggle_setup=args.skip_kaggle_setup,
                    skip_upload=args.skip_upload,
                    oci_namespace=None,
                    oci_bucket=None,
                )
            else:
                connect = build_connect_string(args.mode, args.connect)
                if args.stage == "data":
                    if not args.skip_kaggle_setup:
                        setup_kaggle()
                    if not args.skip_download:
                        download_data()
                    trim_lending(
                        DATA_RAW_DIR / "lendingclub" / "accepted_2007_to_2018Q4.csv",
                        DATA_PROCESSED_DIR / "lendingclub_5k.csv",
                    )
                    generate_conversations(
                        DATA_RAW_DIR / "banking77" / "banking77.csv",
                        DATA_PROCESSED_DIR / "banking77_conversations.csv",
                    )
                elif args.stage == "upload":
                    if args.mode == "container":
                        print("Skipping upload in container mode.")
                    elif not args.skip_upload:
                        upload_to_oci(None, None)
                elif args.stage == "container":
                    if args.mode == "container":
                        start_oracle_container()
                    else:
                        print("Skipping container stage in cloud mode.")
                elif args.stage == "sql-core":
                    run_sql_sequence(connect, CORE_SQL_FILES, sql_client=args.sql_client)
                elif args.stage == "sql-uc":
                    run_sql_sequence(connect, UC_SQL_FILES, sql_client=args.sql_client)
                else:
                    raise DemoError(f"Unsupported orchestrate stage: {args.stage}")
        else:
            raise DemoError(f"Unknown command: {args.command}")
    except DemoError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    except subprocess.CalledProcessError as exc:
        print(f"ERROR: command failed with exit code {exc.returncode}", file=sys.stderr)
        return exc.returncode

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
