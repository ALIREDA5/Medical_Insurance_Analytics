<p align="center">
  <img src="Docs/banner.png" alt="UHIP Platform Banner" width="100%"/>
</p>

<h1 align="center">🏥 Unified Healthcare Intelligence Platform (UHIP)</h1>

<p align="center">
  <strong>An end-to-end healthcare analytics and fraud detection platform built for Port Said Governorate, Egypt</strong>
</p>

<p align="center">
  <a href="#-overview"><img src="https://img.shields.io/badge/Platform-BI%20%26%20Analytics-0a192f?style=for-the-badge&logo=powerbi&logoColor=F2C811" alt="Platform"/></a>
  <a href="#-tech-stack"><img src="https://img.shields.io/badge/SQL%20Server-2022-CC2927?style=for-the-badge&logo=microsoftsqlserver&logoColor=white" alt="SQL Server"/></a>
  <a href="#-data-engineering"><img src="https://img.shields.io/badge/Databricks-ELT%20Pipeline-FF3621?style=for-the-badge&logo=databricks&logoColor=white" alt="Databricks"/></a>
  <a href="#-power-bi-dashboards"><img src="https://img.shields.io/badge/Power%20BI-Dashboards-F2C811?style=for-the-badge&logo=powerbi&logoColor=black" alt="Power BI"/></a>
  <img src="https://img.shields.io/badge/ITI-Graduation%20Project-1e3a5f?style=for-the-badge" alt="ITI"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Patients-75K+-blue?style=flat-square" alt="Patients"/>
  <img src="https://img.shields.io/badge/Visits-510K+-green?style=flat-square" alt="Visits"/>
  <img src="https://img.shields.io/badge/Hospitals-8-orange?style=flat-square" alt="Hospitals"/>
  <img src="https://img.shields.io/badge/Tables-25-purple?style=flat-square" alt="Tables"/>
  <img src="https://img.shields.io/badge/Status-Complete-brightgreen?style=flat-square" alt="Status"/>
</p>

---

## 📌 Overview

**UHIP** is an end-to-end healthcare analytics and intelligence solution designed to unify fragmented healthcare data across Port Said Governorate and transform it into actionable insights.

The platform integrates healthcare operations, patient activities, insurance claims, pharmacy transactions, and fraud detection into a centralized analytical environment — built on a modern **Lakehouse Architecture** using **Databricks**, **SQL Server**, **Power BI**, and **SSRS**.

> 🎓 Built as a Graduation Project — **ITI Power BI Developer Track**

---

## 🚨 Problem Statement

Healthcare data in Port Said is distributed across **8 disconnected hospital systems**, causing:

- 📋 Fragmented patient records with no unified view
- 🔍 No centralized fraud detection mechanism
- 🏥 Inefficient hospital resource allocation
- ⏱️ Delayed decision-making due to lack of real-time insights
- 📄 Insurance claims processed manually with high rejection rates
- 💊 Pharmacy inventory mismanagement and drug theft

---

## 🎯 Project Objectives

- ✅ Create a **unified patient healthcare view** across all hospitals
- ✅ Enable **real-time resource monitoring** (ICU, beds, doctors)
- ✅ Build a **fraud detection system** for claims and pharmacy
- ✅ Support **government and executive decision-making**
- ✅ Provide **AI-powered healthcare assistance** via Telegram
- ✅ Deliver **automated reporting** through SSRS and Power BI

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Data Sources                           │
│              Azure SQL Server (UHIP Database)               │
│                    25 Tables · 6 Modules                    │
└─────────────────────┬───────────────────────────────────────┘
                      │ ELT Pipeline
                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    Databricks                               │
│   🥉 Bronze      🥈 Silver        🥇 Gold                  │
│   Raw Copy    Cleaned+Joined   Business KPIs               │
│   25 tables   visits_enriched  fraud_signals               │
└──────────────┬──────────────────────────┬───────────────────┘
               │                          │
               ▼                          ▼
┌──────────────────────┐    ┌─────────────────────────────────┐
│        SSRS          │    │            Power BI             │
│  Operational Reports │    │     Interactive Dashboards      │
│  PDF · Excel · Email │    │     Direct Lake Connection      │
└──────────────────────┘    └─────────────────────────────────┘
```

![Architecture](lakehouse/Data-Architecture.png)

---

## 🗄️ Database Design

### Core Modules (25 Tables)

| Module | Tables | Description |
|:---|:---:|:---|
| 🏥 Patient Management | 6 | Patients, Visits, Diagnoses, Records, Procedures, Prescriptions |
| 🏨 Hospital Resources | 8 | Hospitals, Departments, Doctors, Schedules, Beds, ICU, Referrals |
| 💊 Pharmacy & Inventory | 4 | Drugs, Inventory, Transactions, Suppliers |
| 📄 Insurance Claims | 3 | Claims, Claim Items, Claim Approvals |
| 📋 Procedures Reference | 1 | Medical Procedures Catalog |
| ⭐ Citizen Services | 1 | Patient Feedback |

### Database Quality Assurance

✔ Primary Key Integrity  
✔ Foreign Key Validation  
✔ Referential Integrity  
✔ 3NF Normalization  
✔ Relationship Cardinality Verification  

![ERD](Database/Conceptual-Design/System-ERD.png)

---

## ⚙️ Data Engineering Pipeline

### ELT Workflow (Databricks + PySpark)

```
1. Data Ingestion    → Azure SQL Database → Databricks
2. Data Validation   → NULL detection, type checks, duplicates
3. Bronze Layer      → Raw copy of all 25 tables
4. Silver Layer      → Cleaned, joined, enriched tables
5. Gold Layer        → Business-ready KPIs & aggregations
6. Consumption Layer → Power BI + SSRS
```

### Medallion Architecture

#### 🥉 Bronze — Raw Data
```python
# Direct copy from SQL Server
df_visits = spark.read.jdbc(url=jdbc_url, table="visits")
df_visits.write.format("delta").save("/bronze/visits")
```

#### 🥈 Silver — Cleaned & Joined
```python
# visits_enriched: joins visits with patients, hospitals, doctors, diagnoses
visits_enriched = df_visits \
    .join(df_patients, "patient_id") \
    .join(df_hospitals, "hospital_id") \
    .join(df_doctors, "doctor_id") \
    .join(df_diagnoses, "diagnosis_code")
```

#### 🥇 Gold — Business Ready
```
- monthly_visits_summary
- hospital_performance_kpis
- fraud_signals_aggregated
- drug_consumption_monthly
- claims_financial_summary
```

### Data Quality Checks

| Check | Description |
|:---|:---|
| NULL Detection | Flags missing values in critical columns |
| Type Validation | Ensures correct data types per column |
| Duplicate Detection | Removes duplicate records |
| Outlier Checks | Flags abnormal values (e.g. inflated costs) |
| Referential Integrity | Validates all FK relationships |
| String Cleaning | Trims and standardizes text fields |

---

## 🛠️ Tech Stack

| Category | Technology | Purpose |
|:---:|:---:|:---|
| 🗄️ | **SQL Server / Azure SQL** | Source OLTP Database |
| ⚡ | **Databricks + PySpark** | ELT Pipeline & Lakehouse |
| 📦 | **Delta Lake** | Data Storage (Medallion) |
| 📊 | **Power BI** | Interactive Dashboards |
| 📑 | **SSRS** | Operational Reports |
| 📝 | **T-SQL** | 18 Stored Procedures |
| 🤖 | **SQL Agent (RAG)** | AI-powered SQL queries |
| 💬 | **Telegram Bot** | Appointments & Feedback |
| 📱 | **Google Apps Script** | Data Entry Application |

---

## 📝 Stored Procedures (18)

Built on SQL Server covering all business operations:

| Category | Procedures |
|:---|:---|
| 👤 Patient Management | `GetPatientByNationalID`, `GetPatientFullHistory`, `GetHighRiskPatients`, `RegisterNewVisit` |
| 🏥 Hospital Resources | `GetHospitalCapacityReport`, `GetICUAlertHospitals`, `GetDoctorWorkload`, `GetReferralSummary` |
| 💊 Pharmacy | `GetLowStockAlert`, `GetExpiringSoonDrugs`, `DispenseDrug`, `GetDrugConsumptionReport` |
| 📄 Insurance Claims | `SubmitNewClaim`, `ReviewClaim`, `GetClaimsByStatus`, `GetRejectionReasonsAnalysis` |
| ⚠️ Fraud Detection | `DetectInflatedProcedureCosts`, `DetectDrugsDispensedWithoutPrescription`, `DetectDuplicateClaims`, `DetectAbnormalPrescriptionQuantity`, `GetFraudSummaryByDoctor` |
| 📊 Analytics | `GetMonthlyVisitsTrend`, `GetHospitalPerformanceScore`, `GetTopDiagnosesByHospital` |

---

## 📊 Power BI Dashboards

### Dashboard Categories (20 Dashboards)

---

#### 🗂️ Overview (3 Dashboards)

![Executive Overview]
<img Dashboards/Dashboards Screenshots/Overview Dashboards/Excutive Overview.png />

<details>
<summary><strong>📂 View All Overview Dashboards (2 more)</strong></summary>

![Hospital-Type & Resource Allocation](Dashboards/Dashboards Screenshots/Overview Dashboards/Hospitals types.png)
![Network Decision Support](Dashboards/Dashboards Screenshots/Overview Dashboards/Network Decission Support.png)

</details>

---

#### 👤 Patients (4 Dashboards)

![Patient Behavior & Retention](Dashboards/Dashboards Screenshots/Patients Dashboards/2.png)

<details>
<summary><strong>📂 View All Patient Dashboards (3 more)</strong></summary>

![Patient Population Profile](Dashboards/Dashboards Screenshots/Patients Dashboards/1.png)
![Disease Burden & Diagnosis Analysis](Dashboards/Dashboards Screenshots/Patients Dashboards/3.png)
![Chronic & High-Risk Population Health](Dashboards/Dashboards Screenshots/Patients Dashboards/4.png)

</details>

---

#### ⚙️ Operations (4 Dashboards)

![Operations & Access](Dashboards/Dashboards Screenshots/Operationas Dashboards/1.png)

<details>
<summary><strong>📂 View All Operations Dashboards (3 more)</strong></summary>

![Doctor & Department Performance](Dashboards/Dashboards Screenshots/Operationas Dashboards/2.png)
![Hospital Capacity & Bed Utilization](Dashboards/Dashboards Screenshots/Operationas Dashboards/3.png)
![Patient Satisfaction & Service Quality](Dashboards/Dashboards Screenshots/Operationas Dashboards/4.png)

</details>

---

#### 💰 Financial (4 Dashboards)

![Revenue & Leakage Analysis](Dashboards/Dashboards Screenshots/Financial Dashoards/2.png)

<details>
<summary><strong>📂 View All Financial Dashboards (3 more)</strong></summary>

![Healthcare Cost & Financial Impact](Dashboards/Dashboards Screenshots/Financial Dashoards/1.png)
![Claims Performance & Approval Funnel](Dashboards/Dashboards Screenshots/Financial Dashoards/3.png)
![Claims Deep Dive — Procedures & Drugs](Dashboards/Dashboards Screenshots/Financial Dashoards/4.png)

</details>

---

#### 🛡️ Fraud Detection (3 Dashboards)

![Overbilling & Upcoding Signals](Dashboards/Dashboards Screenshots/Fraud Dashboards/1.png)

<details>
<summary><strong>📂 View All Fraud Dashboards (2 more)</strong></summary>

![Fraud & Risk Scorecard](Dashboards/Dashboards Screenshots/Fraud Dashboards/2.png)
![Pharmacy Risk & Dispensing Integrity](Dashboards/Dashboards Screenshots/Fraud Dashboards/3.png)

</details>

---

#### 💊 Pharmacy (2 Dashboards)

![Pharmacy Stock & Inventory Health](Dashboards/Dashboards Screenshots/Pharmacy Dashbaords/1.png)

<details>
<summary><strong>📂 View All Pharmacy Dashboards (1 more)</strong></summary>

![Referrals & Patient Flow Network](Dashboards/Dashboards Screenshots/Pharmacy Dashbaords/2.png)

</details>
## 📑 SSRS Reports

8 operational reports built with SSRS, covering fraud, capacity, claims, inventory, and patient analytics — all with conditional formatting, drill-down support, and automated scheduling.

### ⭐ Key Reports

---

#### 🚨 Fraud Signals Report *(Weekly)*

Detects and surfaces suspicious billing and prescription behavior across all hospitals.

| KPI | Value |
|:---|:---|
| Total Fraud Signals | 1,212 |
| Inflated Procedures | 94 |
| Total Unprescribed Dispensing | 344 |

**Top Flagged Doctors (by inflated procedure count):**

| Doctor | Hospital | Procedure | Expected | Actual | Inflation % |
|:---|:---|:---|---:|---:|:---:|
| Yahia El Sherbaby | El Zohour Private | Glycosylated Hb | 208 | 232.96 | 12% 🔴 |
| Rozan Bayoumi | Suez Canal University | Dual Mobility (Tripoli) | 1,789 | 1,996.96 | 12% 🔴 |
| Salah Farghaly | El Manakh Private | Thyroid Function Tests | 320 | 358.40 | 12% 🔴 |
| Marwan Shehata | Port Said General | Bronchial Fluid Culture | 412 | 461.44 | 12% 🔴 |

> All flagged signals are classified as **Inflated Procedure** with 12% inflation PCT, highlighted in red for immediate review.

---

#### 🏥 Hospitals Capacity Report *(On-Demand)*

Real-time bed and ICU occupancy monitoring across all 8 hospitals.

| KPI | Value |
|:---|:---|
| Total Beds | 2,280 |
| Avg Occupancy % | 55.9% |
| Avg ICU Occupancy % | 59.2% |

**Per-Hospital Breakdown:**

| Hospital | Type | Total Beds | Occupied | Occupancy % | ICU % |
|:---|:---|---:|---:|:---:|:---:|
| Port Fouad Central | Government | 350 | 215 | 62.7% 🟡 | 63.3% |
| El Arab District | Government | 280 | 164 | 61.4% 🟡 | 55.0% |
| Suez Canal University | Teaching | 500 | 287 | 58.0% 🟡 | **72.0%** 🔴 |
| El Zohour Private | Private | 150 | 83 | 56.5% 🟡 | **40.0%** 🟢 |
| Port Said General | Government | 600 | 323 | 54.9% 🟡 | 60.0% |
| Mubarak District | Government | 200 | 108 | 54.3% 🟡 | 66.7% |
| El Manakh Private | Private | 120 | 63 | 52.5% 🟡 | 50.0% |
| Port Said Heart Center | Specialized | 80 | 33 | **47.1%** 🟢 | 66.7% |

> ⚠️ Suez Canal University Hospital has the highest ICU load at **72%** — flagged for capacity planning.

---

#### 📋 Claims Performance Report *(Monthly)*

End-to-end claims processing analytics with rejection root-cause breakdown.

| KPI | Value |
|:---|:---|
| Total Claims | 101,375 |
| Total Rejected Claims | 15,488 |
| Rejection Rate | 15.3% |
| Most Common Rejection Reason | Coding error in claim submission |

**Claims Distribution:**
- ✅ Approved: **54.80%**
- 🟡 Partially Approved: **19.40%**
- 🔵 Pending Review: **10.53%**
- 🔴 Rejected: **15.28%**

**Top Hospitals by Rejections:**

| Hospital | Rejections |
|:---|---:|
| Port Said General Hospital | 3,760 |
| Port Fouad Central Hospital | 3,067 |
| El Arab District Hospital | 2,497 |
| Suez Canal University Hospital | 2,466 |

---

<details>
<summary><strong>📂 View All Reports (5 more)</strong></summary>

---

#### 📊 Executive Dashboard *(On-Demand)*

High-level KPIs for government and executive decision-makers.

| KPI | Value |
|:---|:---|
| Total Visits | 433,737 |
| Avg Waiting Time | 74.7 min |
| Avg Hospital Rating | 3.5 / 5 |
| Avg Rejection Rate | 15.4% |

**Monthly Visits Trend (2024–2025):**  
Peak at **35,548** (Jun 2024) → Sharp drop to **10,856** (May 2025)

**Hospital Performance Ratings:**

| Hospital | Avg Rating | Avg Wait (min) | Total Claims | Rejected | Rejection % |
|:---|:---:|---:|---:|---:|:---:|
| Suez Canal University | 3.9 | 24.8 | 38,888 | 5,920 | 15.2% |
| El Zohour Private | 3.8 | 24.8 | 19,434 | 2,966 | 15.3% |
| El Manakh Private | 3.8 | 24.8 | 19,643 | 3,092 | 15.7% |
| Port Said Heart Center | 3.8 | 24.8 | 19,453 | 3,038 | 15.6% |
| Port Fouad Central | 3.1 | 104.5 | 48,432 | 7,389 | 15.3% |
| El Arab District | 3.1 | 104.3 | 39,265 | 6,086 | 15.5% |
| Mubarak District | 3.1 | 104.3 | 29,059 | 4,390 | 15.1% |
| Port Said General | 3.1 | 103.9 | 59,082 | 9,124 | 15.4% |

> Private hospitals average **24.8 min** wait vs government hospitals at **104+ min** — a 4x gap.

---

#### 👨‍⚕️ Doctor Workload Report *(On-Demand)*

Identifies overloaded doctors using visits-per-shift as the primary stress indicator.

**Top Doctors by Visits/Shift (color-coded):**

| Doctor | Specialty | Total Visits | Shifts | Visits/Shift |
|:---|:---|---:|---:|:---:|
| Maged Farag | Emergency Medicine | 424 | 70 | **6.1** 🔴 |
| Mamdouh Hanafy | Internal Medicine | 397 | 66 | **6.0** 🔴 |
| Esraa Khalifa | Gastroenterology | 433 | 79 | **5.5** 🔴 |
| Nashaat El-Diwany | Emergency Medicine | 395 | 74 | **5.3** 🔴 |
| Marwan Ramadan | Emergency Medicine | 408 | 79 | **5.2** 🔴 |
| Doaa Qasem | Pediatrics | 414 | 79 | **5.2** 🔴 |
| Nashaat Lotfy | Cardiology | 407 | 75 | **5.4** 🔴 |
| Sherief Qasem | Endocrinology | 420 | 84 | **5.0** 🔴 |
| Maha Helal | Internal Medicine | 404 | 83 | **4.9** 🟠 |
| Nader Nofal | Orthopedics | 414 | 95 | **4.4** 🟠 |

> 🔴 Red = High overload (5.0+) · 🟠 Orange = Moderate (4.5–4.9)

---

#### 💊 Inventory Health Report — Low Stock & Expiring Soon *(Daily)*

Proactive drug inventory alerts split into two views:

**Summary KPIs:**

| KPI | Value |
|:---|:---|
| Total Low Stock Items | 131 |
| Low Stock Items | 114 |
| Out of Stock Items | 17 |
| Expiring in 30 Days | 64 |

**🔴 Out of Stock Examples:**

| Hospital | Drug | Category | Reorder Level |
|:---|:---|:---|:---:|
| Mubarak District | XARELTO 20 mg 28 tab | Anticoagulant | 49 |
| Port Fouad Central | UNICTAM 375 mg 6 tab | Antibiotic | 46 |
| El Zohour Private | Ursofalk 250 mg 20 cap | General | 46 |
| Port Said Heart Center | Talopram 40 mg 30 tab | Psychotropic/CNS | 46 |
| Port Said General | URINEX 24 cap | General | 43 |

**⏳ Expiring Soon (within 7 days):**

| Hospital | Drug | Qty Available | Expiry Date | Days Left |
|:---|:---|---:|:---:|:---:|
| Port Said Heart Center | Triflutect 14 mg 28 tab | 384 | 24/06/2026 | 1 |
| El Zohour Private | Xtandi 40 mg 112 cap | 236 | 24/06/2026 | 1 |
| Port Said Heart Center | Vasalmol 0.1mg Inhaler | 441 | 26/06/2026 | 3 |
| El Arab District | Visceralqine 50 mg 20 tab | 281 | 26/06/2026 | 3 |
| Port Said General | Synjardy 12.5/1000 mg | 492 | 27/06/2026 | 4 |

---

#### 🩺 Selected Patient Full History *(On-Demand)*

Drill-down patient-level view showing complete visit history, diagnoses, and prescriptions.

**Example — Patient with Psoriasis (Moderate):**

| Visit Date | Type | Hospital | Severity | Amount |
|:---|:---|:---|:---:|---:|
| 24-06-2024 | Follow-up | Port Fouad Central | Moderate | 544.89 |
| 10-07-2024 | Emergency | Port Fouad Central | Moderate | 4,098.11 |
| 29-07-2024 | Follow-up | Port Fouad Central | Moderate | 450.96 |
| 08-08-2024 | Follow-up | Port Fouad Central | Moderate | 343.90 |
| 26-08-2024 | Outpatient | Port Fouad Central | Moderate | 731.86 |

**Active Prescriptions (Jun 2024 visit):**

| Drug | Dosage | Frequency | Duration | Qty |
|:---|:---:|:---:|:---:|:---:|
| Treczimus 0.1% 30 GM OINT | 1g | Twice daily | 60 days | 120 |
| Unitrexate 50mg/2ml vial | 25mg | Once daily | 21 days | 21 |

---

#### ⚠️ High-Risk Patient Report *(On-Demand)*

Identifies patients with 3+ visits at Moderate or higher severity for proactive intervention.

**Sample High-Risk Patients:**

| Patient ID | Name | Age | Total Visits | Last Visit |
|:---|:---|:---:|:---:|:---|
| PAT040203 | Essam El-Deeb | 22 | 18 | 04/05/2025 |
| PAT052454 | Hendy Sobhi Abdel-Hameed | 13 | 18 | 05/05/2025 |
| PAT006301 | Atef El-Gezawy | 36 | 18 | 03/05/2025 |
| PAT015875 | Morsy Wahdan | 31 | 18 | 07/05/2025 |
| PAT049391 | Abdelfattah Akram Mostafa | 28 | 17 | 08/04/2025 |
| PAT006378 | Suzan Mahrous | 45 | 17 | 20/04/2025 |

> Filter by severity level and minimum visit count. Supports outreach and care management workflows.

---

</details>

### SSRS Features
- ✅ Multi-value parameters (hospital selector, severity filter, date range)
- ✅ Conditional color coding (🔴🟡🟢) on all KPI columns
- ✅ Automated email subscriptions (Daily / Weekly / Monthly)
- ✅ Export to PDF / Excel
- ✅ Drill-down capabilities (hospital → doctor → patient level)

---

## 📱 Data Entry Application

Built using **Google Apps Script + Google Sheets**:

- 📋 Dynamic forms for patient registration
- 🏥 Visit and claims entry
- 💊 Pharmacy records management
- 🔍 Search & edit existing records
- ✅ Automated validation rules

---

## 🤖 AI Features

### UHIP SQL Agent (RAG System)
Natural language interface allowing users to:
- Ask healthcare questions in Arabic or English
- Generate SQL queries automatically
- Retrieve business insights without SQL knowledge
- Interact through Telegram

### Telegram Chatbot (n8n Workflow)
- 📅 Schedule, reschedule, cancel appointments
- ⭐ Collect patient feedback
- 🔔 ICU and stock alerts
- 📊 On-demand report summaries

![Workflow](AI-Agents/workflow.png)

---

## 📈 Key Insights

| Metric | Value | Insight |
|:---|:---:|:---|
| Total Patients | 75K+ | Strong population coverage |
| Total Visits | 510K+ | High platform utilization |
| Returning Patient Rate | **90.9%** | Strong patient retention |
| Avg Waiting Time | **76 min** | Major operational challenge |
| No-Show Rate | **8%** | Needs appointment optimization |
| Cancellation Rate | **7%** | Workflow improvement needed |
| Govt vs Private Rating | **2.7 vs 3.8** | Quality gap requires attention |
| ICU Winter Peak | **1.7x summer** | Seasonal capacity planning needed |
| Stockout Rate | **7%** | Inventory management gap |
| Claims Approval Rate | **55%** | Room for process improvement |

---

## 🗂️ Project Structure

```
📦 UHIP/
├── 📂 Database/
│   ├── Conceptual-Design/
│   │   └── System-ERD.png
│   ├── Logical-Design/
│   │   └── UHIP_Database_Logical_Design.pdf
│   └── Scripts/
│       └── UHIP_StoredProcedures.sql        # 18 Stored Procedures
├── 📂 lakehouse/
│   ├── Data-Architecture.png
│   ├── DWH-Design.png
│   └── Notebooks/
│       ├── 01_bronze_ingestion.py
│       ├── 02_silver_transformation.py
│       └── 03_gold_aggregation.py
├── 📂 PowerBI/
│   └── UHIP_Dashboards.pbix                # 19 Dashboards
├── 📂 SSRS/
│   ├── HospitalCapacityReport.rdl
│   └── ICUAlertDashboard.rdl
├── 📂 AI-Agents/
│   ├── workflow.png                         # n8n Telegram workflow
│   ├── sql_agent.py                         # RAG SQL Agent
│   └── prompt_builder.py
├── 📂 DataEntry/
│   └── UHIP_DataEntry.gs                    # Google Apps Script
├── 📂 Docs/
│   ├── banner.png
│   └── UHIP_Documentation.pdf
└── 📄 README.md
```

---

## 🚀 Getting Started

### Prerequisites

| Tool | Version | Purpose |
|:---|:---|:---|
| SQL Server | 2019+ | Source database |
| SSMS | Latest | Database management |
| Databricks | Latest | ELT pipeline |
| Power BI Desktop | Latest | Dashboard viewing |
| Visual Studio | 2019+ | SSRS development |
| Python | 3.10+ | AI Agent backend |

### Setup Steps

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/UHIP.git

# 2. Restore the SQL Server database
# Open SSMS → Right-click Databases → Restore Database
# Select: UHIP_Database.bak

# 3. Run Stored Procedures
# Open UHIP_StoredProcedures.sql in SSMS → Execute

# 4. Configure Databricks
# Upload notebooks from /lakehouse/Notebooks/
# Update JDBC connection string to your SQL Server

# 5. Run ELT Pipeline
# Execute notebooks in order: 01 → 02 → 03

# 6. Open Power BI Dashboard
# Open UHIP_Dashboards.pbix in Power BI Desktop
# Update data source to your Databricks Gold Layer

# 7. Deploy SSRS Reports
# Open .rdl files in Visual Studio
# Deploy to your Report Server

# 8. Configure AI Agent
cp .env.example .env
# Fill in: SQL Server connection, Telegram Bot Token, API keys

python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python sql_agent.py
```

---

## 👥 Team

<table>
<tr>
<td align="center" width="25%">
<h4>BI Developer</h4>
<img src="https://img.shields.io/badge/Role-BI%20Developer-F2C811?style=flat-square&logo=powerbi" alt="BI Developer"/>
</td>
<td align="center" width="25%">
<h4>BI Developer</h4>
<img src="https://img.shields.io/badge/Role-BI%20Developer-F2C811?style=flat-square&logo=powerbi" alt="BI Developer"/>
</td>
<td align="center" width="25%">
<h4>BI Developer</h4>
<img src="https://img.shields.io/badge/Role-BI%20Developer-F2C811?style=flat-square&logo=powerbi" alt="BI Developer"/>
</td>
<td align="center" width="25%">
<h4>Data Engineer / AI</h4>
<img src="https://img.shields.io/badge/Role-Data%20Engineer-FF3621?style=flat-square&logo=databricks" alt="Data Engineer"/>
</td>
</tr>
<tr>
<td align="center">Basma Zakaria</td>
<td align="center">Saifallah Tharwat</td>
<td align="center">Mayar Ashraf</td>
<td align="center">Ali Reda</td>
</tr>
</table>

<p align="center">
  <strong>🎓 ITI — Information Technology Institute</strong><br/>
  <em>Power BI Developer Track — Graduation Project 2025</em>
</p>

---

## 📬 Contact

For inquiries or collaboration:

- 🔗 LinkedIn: [Ali Reda](https://www.linkedin.com/in/ali-reda)
- 📧 Email: alireda.elec@gmail.com

---

## 📜 License

This project is licensed under the **MIT License**.

---

<p align="center">
  <img src="https://img.shields.io/badge/Built%20with-❤️%20at%20ITI-1e3a5f?style=for-the-badge" alt="Built with love at ITI"/>
  <img src="https://img.shields.io/badge/Port%20Said-Egypt%20🇪🇬-red?style=for-the-badge" alt="Port Said Egypt"/>
</p>
