from pathlib import Path
import os
from urllib.parse import quote_plus

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.exc import SQLAlchemyError


BASE_DIR = Path(__file__).resolve().parent / "UHIP_Data"
load_dotenv(Path(__file__).resolve().parent / ".env")

connection_string = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    f"SERVER={os.getenv('AZURE_SQL_SERVER', 'ali22.database.windows.net')};"
    f"DATABASE={os.getenv('AZURE_SQL_DATABASE', 'uhip_db')};"
    f"UID={os.getenv('AZURE_SQL_USERNAME', 'ali1')};"
    f"PWD={os.getenv('AZURE_SQL_PASSWORD', 'Ali@1234')};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Connection Timeout=30;"
)

engine = create_engine(
    f"mssql+pyodbc:///?odbc_connect={quote_plus(connection_string)}",
    fast_executemany=True,
    pool_pre_ping=True,
)

# ── Table → CSV map (FK-safe order) ─────────────────────────────
# Parent tables must come before their children.
# hosp.doctor_schedule & hosp.bed depend on hosp.doctor / hosp.department
# hosp.icu_status depends on hosp.hospital
# inv.drug_transaction depends on ref.drug + hosp.hospital
# clin.medical_record & clin.visit_procedure depend on clin.visit
# fin.claim_item & fin.claim_approval depend on fin.claim
# hosp.referral depends on pat.patient + hosp.hospital
files = {
    # ── ref ──────────────────────────────────────────────────────
    "diagnoses.csv":            "ref.diagnosis",
    "procedures.csv":           "ref.medical_procedure",
    "drugs.csv":                "ref.drug",
    # ── hosp (core) ──────────────────────────────────────────────
    "hospitals.csv":            "hosp.hospital",
    "departments.csv":          "hosp.department",
    "doctors.csv":              "hosp.doctor",
    # ── hosp (resources — depend on doctor / department) ─────────
    "doctor_schedules.csv":     "hosp.doctor_schedule",
    "beds.csv":                 "hosp.bed",
    "icu_status.csv":           "hosp.icu_status",
    # ── pat ──────────────────────────────────────────────────────
    "patients.csv":             "pat.patient",
    # ── hosp.referral (depends on pat.patient + hosp.hospital) ───
    "referrals.csv":            "hosp.referral",
    # ── inv ──────────────────────────────────────────────────────
    "drug_inventory.csv":       "inv.drug_inventory",
    "drug_transactions.csv":    "inv.drug_transaction",
    # ── clin ─────────────────────────────────────────────────────
    "visits.csv":               "clin.visit",
    "medical_records.csv":      "clin.medical_record",
    "visit_procedures.csv":     "clin.visit_procedure",
    "prescriptions.csv":        "clin.prescription",
    "prescription_items.csv":   "clin.prescription_item",
    # ── fin ──────────────────────────────────────────────────────
    "claims.csv":               "fin.claim",
    "claim_items.csv":          "fin.claim_item",
    "claim_approvals.csv":      "fin.claim_approval",
    # ── svc ──────────────────────────────────────────────────────
    "patient_feedback.csv":     "svc.patient_feedback",
}

PRIMARY_KEYS = {
    "ref.diagnosis":            "diagnosis_code",
    "ref.medical_procedure":    "procedure_code",
    "ref.drug":                 "drug_id",
    "hosp.hospital":            "hospital_id",
    "hosp.department":          "department_id",
    "hosp.doctor":              "doctor_id",
    "hosp.doctor_schedule":     "schedule_id",
    "hosp.bed":                 "bed_id",
    "hosp.icu_status":          "icu_status_id",
    "hosp.referral":            "referral_id",
    "pat.patient":              "patient_id",
    "inv.drug_inventory":       "inventory_id",
    "inv.drug_transaction":     "transaction_id",
    "clin.visit":               "visit_id",
    "clin.medical_record":      "record_id",
    "clin.visit_procedure":     "visit_procedure_id",
    "clin.prescription":        "prescription_id",
    "clin.prescription_item":   "prescription_item_id",
    "fin.claim":                "claim_id",
    "fin.claim_item":           "claim_item_id",
    "fin.claim_approval":       "approval_id",
    "svc.patient_feedback":     "feedback_id",
}

RENAME_COLS = {
    "ref.medical_procedure":    {"expected_cost":   "expected_amount"},
    "ref.drug":                 {"unit_price":       "unit_amount"},
    "clin.visit":               {"total_cost":       "total_amount"},
    "clin.visit_procedure":     {"procedure_cost":   "procedure_amount"},
    "fin.claim":                {"total_claim":      "claim_amount"},
    "fin.claim_item":           {"item_cost":        "item_amount",      # actual CSV col name
                                 "line_amount":      "item_amount"},     # fallback alias
}

# Columns that must be non-null — rows missing any of these are dropped with a warning.
# Covers NOT NULL FK columns and PKs that the DB will reject outright.
NOTNULL_COLS = {
    "ref.diagnosis":            ["diagnosis_code"],
    "ref.medical_procedure":    ["procedure_code"],
    "ref.drug":                 ["drug_id"],
    "hosp.hospital":            ["hospital_id"],
    "hosp.department":          ["department_id", "hospital_id"],
    "hosp.doctor":              ["doctor_id", "hospital_id", "department_id"],
    "hosp.doctor_schedule":     ["schedule_id", "doctor_id"],
    "hosp.bed":                 ["bed_id", "hospital_id", "department_id"],
    "hosp.icu_status":          ["icu_status_id", "hospital_id"],
    "hosp.referral":            ["referral_id", "patient_id", "from_hospital_id", "to_hospital_id"],
    "pat.patient":              ["patient_id", "national_id"],
    "inv.drug_inventory":       ["inventory_id", "hospital_id", "drug_id"],
    "inv.drug_transaction":     ["transaction_id", "drug_id", "hospital_id"],
    "clin.visit":               ["visit_id", "patient_id", "hospital_id", "doctor_id",
                                 "department_id", "diagnosis_code"],
    "clin.medical_record":      ["record_id", "visit_id"],
    "clin.visit_procedure":     ["visit_procedure_id", "visit_id", "procedure_code"],
    "clin.prescription":        ["prescription_id", "visit_id", "doctor_id"],
    "clin.prescription_item":   ["prescription_item_id", "prescription_id", "drug_id"],
    "fin.claim":                ["claim_id", "patient_id", "visit_id", "hospital_id"],
    "fin.claim_item":           ["claim_item_id", "claim_id"],
    "fin.claim_approval":       ["approval_id", "claim_id"],
    "svc.patient_feedback":     ["feedback_id", "patient_id", "hospital_id", "doctor_id"],
}

DROP_COLS = {
    "clin.visit": ["row_version"],
}

FORCE_STR_COLS = {
    "pat.patient": ["national_id", "phone", "emergency_contact"],
}

# Date columns that need explicit parsing per table
DATE_COLS = {
    "pat.patient":              ["birth_date"],
    "hosp.doctor_schedule":     ["shift_date"],
    "hosp.icu_status":          ["update_time"],
    "hosp.referral":            ["referral_date"],
    "inv.drug_inventory":       ["expiry_date"],
    "inv.drug_transaction":     ["transaction_date"],
    "clin.visit":               ["visit_date"],
    "clin.visit_procedure":     ["procedure_date"],
    "clin.prescription":        ["prescription_date"],
    "fin.claim":                ["claim_date"],
    "fin.claim_approval":       ["approval_date"],
    "svc.patient_feedback":     ["feedback_date"],
}

# hosp.icu_status.update_time is DATETIME2 — keep full timestamp, not date-only
DATETIME_COLS = {
    "hosp.icu_status": ["update_time"],
}

CHUNK_SIZE = 1000


# ── Helpers ──────────────────────────────────────────────────────
def fix_patient_cols(df: pd.DataFrame) -> pd.DataFrame:
    df["national_id"] = df["national_id"].apply(
        lambda v: str(int(float(v)))[-14:] if pd.notna(v) and v not in ("", "nan") else None
    )
    for col in ["phone", "emergency_contact"]:
        df[col] = df[col].apply(
            lambda v: str(int(float(v))) if pd.notna(v) and v not in ("", "nan") else None
        )
    return df


def fix_dates(df: pd.DataFrame, table: str) -> pd.DataFrame:
    """
    Parse date columns to proper Python date objects.
    DATETIME2 columns (e.g. icu_status.update_time) are kept as datetime.
    SQL Server rejects pandas Timestamps with timezone or NaT as strings —
    converting to date/datetime/None avoids the 22018 cast error.
    """
    datetime_cols = set(DATETIME_COLS.get(table, []))

    for col in DATE_COLS.get(table, []):
        if col not in df.columns:
            continue

        if col in datetime_cols:
            # Keep full timestamp for DATETIME2 columns
            df[col] = pd.to_datetime(df[col], errors="coerce")
            df[col] = df[col].apply(
                lambda v: v.to_pydatetime() if pd.notna(v) else None
            )
        else:
            # Date-only for DATE columns
            df[col] = pd.to_datetime(df[col], errors="coerce").dt.date
            df[col] = df[col].where(df[col].notna(), None)

    return df


def fix_numerics(df: pd.DataFrame) -> pd.DataFrame:
    """
    Cast numeric columns: replace NaN with None, fix any accidental
    string-encoded floats (e.g. "1.0" in an INT column).
    """
    for col in df.select_dtypes(include=["float64"]).columns:
        non_null = df[col].dropna()
        if not non_null.empty and (non_null % 1 == 0).all():
            df[col] = df[col].apply(
                lambda v: int(v) if pd.notna(v) else None
            )
        else:
            df[col] = df[col].apply(
                lambda v: float(v) if pd.notna(v) else None
            )
    return df


def clean_nans(df: pd.DataFrame) -> pd.DataFrame:
    """Final sweep: any remaining NaN/NaT → None."""
    return df.where(pd.notnull(df), None)


def drop_bad_rows(df: pd.DataFrame, table: str) -> pd.DataFrame:
    """
    Drop rows with NULL/None in any NOT NULL column.
    Works on both numeric (NaN) and object-dtype (None) columns —
    isnull() alone misses Python None in object columns after clean_nans().
    Runs BEFORE clean_nans so NaN values are still detectable via isnull().
    """
    required = [c for c in NOTNULL_COLS.get(table, []) if c in df.columns]
    if not required:
        return df
    # isnull() catches NaN/NaT; explicit None check covers object dtype
    null_mask = df[required].apply(
        lambda col: col.isnull() | col.apply(lambda v: v is None)
    )
    mask = null_mask.any(axis=1)
    bad  = mask.sum()
    if bad:
        offenders = {c: int(n) for c, n in null_mask[mask].sum().items() if n > 0}
        print(f"  [WARN] dropping {bad:,} row(s) with NULL in: {offenders}")
        df = df[~mask].reset_index(drop=True)
    return df


def get_existing_pks(table: str, pk: str) -> set:
    schema, tbl = table.split(".")
    with engine.connect() as conn:
        rows = conn.execute(text(f"SELECT [{pk}] FROM [{schema}].[{tbl}]")).fetchall()
    return {r[0] for r in rows}


def upsert(df: pd.DataFrame, table: str, pk: str) -> tuple[int, int]:
    existing = get_existing_pks(table, pk)
    new_rows = df[~df[pk].isin(existing)].copy()
    skipped  = len(df) - len(new_rows)

    if new_rows.empty:
        return 0, skipped

    schema, tbl = table.split(".")
    new_rows.to_sql(
        tbl, engine,
        schema=schema,
        if_exists="append",
        index=False,
        chunksize=CHUNK_SIZE,
    )
    return len(new_rows), skipped


# ── Load loop ────────────────────────────────────────────────────
failed = []

for file, table in files.items():
    path = BASE_DIR / file
    if not path.exists():
        print(f"[SKIP] {file}")
        continue

    print(f"[....] {file} → {table}")
    try:
        dtype = {c: str for c in FORCE_STR_COLS.get(table, [])}
        df    = pd.read_csv(path, dtype=dtype)

        # Renames
        renames = {k: v for k, v in RENAME_COLS.get(table, {}).items() if k in df.columns}
        if renames:
            df.rename(columns=renames, inplace=True)

        # Drop server-generated cols
        drops = [c for c in DROP_COLS.get(table, []) if c in df.columns]
        if drops:
            df.drop(columns=drops, inplace=True)

        # Table-specific fixes
        if table == "pat.patient":
            df = fix_patient_cols(df)

        # Fix dates → Python date/datetime objects (prevents 22018 cast error)
        df = fix_dates(df, table)

        # Fix float columns → int where possible, None for nulls
        df = fix_numerics(df)

        # Drop rows with NULLs in NOT NULL columns BEFORE clean_nans,
        # while NaN is still detectable via isnull()
        df = drop_bad_rows(df, table)

        # Final NaN sweep (None replaces NaN for SQL Server compat)
        df = clean_nans(df)

        if df.empty:
            print(f"[SKIP] {file} — all rows invalid after null check")
            continue

        inserted, skipped = upsert(df, table, PRIMARY_KEYS[table])
        print(f"[OK]   inserted={inserted:,}  skipped={skipped:,}")

    except Exception as exc:
        print(f"[FAIL] {str(exc).split(chr(10))[0]}")
        failed.append((file, table))

# ── Summary ──────────────────────────────────────────────────────
print("\n" + "=" * 60)
if failed:
    print(f"DONE with {len(failed)} failure(s):")
    for f, t in failed:
        print(f"  • {f} → {t}")
else:
    print("DONE — all tables loaded successfully.")
print("=" * 60)
