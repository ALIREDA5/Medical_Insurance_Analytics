# UHIP Data Entry Portal — AppScript Technical Documentation
**Version 2.0 | June 2025**
Universal Health Insurance Platform — Port Said Governorate, Egypt

---

## Table of Contents

1. [Overview](#1-overview)
2. [Code.gs — Server-Side Backend](#2-codegs--server-side-backend)
3. [Index.html — UI Shell](#3-indexhtml--ui-shell)
4. [Scripts.html — Client-Side Logic](#4-scriptshtml--client-side-logic)
5. [Styles.html — CSS Styling](#5-styleshtml--css-styling)
6. [Database Schema](#6-database-schema)
7. [Access Control Reference](#7-access-control-reference)
8. [Deployment & Setup](#8-deployment--setup)

---

## 1. Overview

The **UHIP Data Entry Portal** is a Google Apps Script web application that provides a full-featured data entry and search interface on top of a Google Sheets database. It serves as the primary data management layer for the Universal Health Insurance Platform.

### 1.1 Purpose

The portal allows authorized staff to **insert**, **search**, and **update** records across 23 data tables covering:

- Patients, visits, and medical records
- Hospitals, departments, and doctors
- Prescriptions and drug management
- Insurance claims and approvals
- Patient feedback

All data is stored in a central Google Sheets spreadsheet.

### 1.2 File Structure

| File | Type | Role |
|---|---|---|
| `Code.gs` | Google Apps Script | Server-side backend: auth, CRUD operations, sheet helpers |
| `Index.html` | HTML Template | Main UI shell: navbar, sidebar layout, Bootstrap 5 wiring |
| `Scripts.html` | JavaScript | Client-side logic: table config, form building, search, FK dropdowns |
| `Styles.html` | CSS | Styling: sidebar, cards, forms, tables, responsive breakpoints |

### 1.3 Spreadsheet

**ID:** `1PaXWgxmW7J-8SaVXc8lPAJIY3ZYxgebBvtjcjNrM6lc`

### 1.4 Technology Stack

| Layer | Technology |
|---|---|
| Runtime | Google Apps Script (V8 engine) |
| UI | HTML Service — Bootstrap 5.3.2, Font Awesome 6.5 |
| Storage | Google Sheets (SpreadsheetApp) |
| Auth | `Session.getActiveUser()` + Users sheet whitelist |
| IDs | Sequential auto-generated: prefix + zero-padded integer |

---

## 2. Code.gs — Server-Side Backend

`Code.gs` is the Apps Script server that handles HTTP requests, enforces access control, and performs all spreadsheet read/write operations. It exposes named functions that the client calls via `google.script.run`.

---

### 2.1 Access Control

Every table-specific function begins by calling `checkTableAccess(tableName)`. This validates that the authenticated user exists in the **Users** sheet and that their allowed tables include the requested table.

| Function | Description |
|---|---|
| `checkTableAccess(tableName)` | Throws if the current user lacks permission for the given table |
| `getUserAccess()` | Reads Users sheet; returns `{ email, tables }` or `null` if unlisted |
| `isAuthorized(email)` | Returns `true` if `getUserAccess()` is non-null |
| `getCurrentUser()` | Returns `{ email, tables }` for the active session (called from the client) |

> **Users sheet format:** Column A = email, Column B = tables. Use `*` for full access. Comma-separate table keys to restrict (e.g. `patients,visits,claims`).

---

### 2.2 Web App Entry Point

`doGet()` is the Apps Script web app entry point. It checks authorization and either returns an access-denied HTML page or renders the `Index.html` template.

```
function doGet()         → HtmlOutput
function include(filename) → String   // injects CSS/JS partials
```

---

### 2.3 Spreadsheet Helpers

| Function | Signature | Description |
|---|---|---|
| `getSpreadsheet()` | `() → Spreadsheet` | Opens the target spreadsheet by `SPREADSHEET_ID` |
| `getSheet(name)` | `(name) → Sheet` | Returns a named sheet object |
| `getHeaders(sheetName)` | `(sheetName) → String[]` | Returns the header row as a string array |
| `getAllRows(sheetName)` | `(sheetName) → Object[]` | Returns all data rows as header-keyed objects; Dates formatted `yyyy-MM-dd` |
| `getNextId(…)` | `(sheetName, prefix, digits) → String` | Generates the next sequential ID (e.g. `PAT000042`) |
| `appendRow(…)` | `(sheetName, rowData) → {success, id}` | Appends one row mapped from headers |
| `updateRow(…)` | `(sheetName, pkField, pkValue, rowData) → {…}` | Updates columns of the matching row by primary key |
| `searchRows(…)` | `(sheetName, filters) → Object[]` | Filters `getAllRows()` by equality, substring, and `_from`/`_to` date range |

**Date range filtering:** pass filter keys with `_from` / `_to` suffixes. Example: `{ visit_date_from: '2024-01-01', visit_date_to: '2024-12-31' }`.

---

### 2.4 Dropdown Loaders

`getDropdownOptions(sheetName, idCol, labelCol)` reads a reference sheet and returns an array of `{ value, label }` objects formatted as `"ID — Name"`. Each entity has a dedicated wrapper:

| Function | Sheet | Value column | Label column |
|---|---|---|---|
| `getPatientOptions()` | `patients` | `patient_id` | `first_name` |
| `getHospitalOptions()` | `hospitals` | `hospital_id` | `hospital_name` |
| `getDoctorOptions()` | `doctors` | `doctor_id` | `first_name` |
| `getDepartmentOptions()` | `departments` | `department_id` | `department_name` |
| `getDiagnosisOptions()` | `diagnoses` | `diagnosis_code` | `diagnosis_name` |
| `getProcedureOptions()` | `procedures` | `procedure_code` | `procedure_name` |
| `getDrugOptions()` | `drugs` | `drug_id` | `drug_name` |
| `getVisitOptions()` | `visits` | `visit_id` | `visit_date` |
| `getPrescriptionOptions()` | `prescriptions` | `prescription_id` | `prescription_date` |
| `getClaimOptions()` | `claims` | `claim_id` | `claim_date` |

---

### 2.5 Entity CRUD Functions

Each entity exposes three functions: **insert**, **search**, and **update**.

#### Standard entities

| Entity | Insert function | Auto-ID prefix | Digits | Sheets written |
|---|---|---|---|---|
| Patients | `insertPatient(d)` | `PAT` | 6 | `patients` |
| Hospitals | `insertHospital(d)` | `H` | 3 | `hospitals` |
| Departments | `insertDepartment(d)` | `DEPT` | 4 | `departments` |
| Doctors | `insertDoctor(d)` | `DOC` | 4 | `doctors` |
| Doctor Schedules | `insertDoctorSchedule(d)` | `SCH` | 7 | `doctor_schedules` |
| ICU Status | `insertIcuStatus(d)` | `ICU` | 6 | `icu_status` |
| Referrals | `insertReferral(d)` | `REF` | 6 | `referrals` |
| Drug Transactions | `insertDrugTransaction(d)` | `DT` | 7 | `drug_transactions` |
| Claim Approvals | `insertClaimApproval(d)` | `APR` | 8 | `claim_approvals` |
| Patient Feedback | `insertPatientFeedback(d)` | `FB` | 8 | `patient_feedback` |

> All insert functions also call `checkTableAccess()` before writing. Patients and ICU Status auto-stamp a `created_at` / `update_time` timestamp.

#### Merged / composite entities

Three entities write to multiple sheets in a single server call:

| Function | Sheets written | Notes |
|---|---|---|
| `insertVisitFull(data)` | `visits` + `medical_records` + `visit_procedures` | Procedures is a repeatable array; medical record is always written |
| `insertPrescriptionFull(data)` | `prescriptions` + `prescription_items` | Drug items are a repeatable array |
| `insertClaimFull(data)` | `claims` + `claim_items` + `claim_approvals` (optional) | Approval written only if `apr_approval_status` is present in data |

---

### 2.6 Sheet Setup — `createSheetHeaders()`

A one-time setup function run from the Apps Script editor. It creates all 24 sheets with their headers, applies navy header styling (`#1a3a5c` background, white bold text), and freezes row 1. Existing sheets are skipped automatically.

**Sheets created:** `patients`, `visits`, `medical_records`, `visit_procedures`, `prescriptions`, `prescription_items`, `doctor_schedules`, `icu_status`, `referrals`, `drug_transactions`, `claims`, `claim_items`, `claim_approvals`, `patient_feedback`, `hospitals`, `departments`, `doctors`, `diagnoses`, `procedures`, `drugs`, `suppliers`, `drug_inventory`, `beds`, `Users`

---

## 3. Index.html — UI Shell

`Index.html` is an Apps Script `HtmlTemplate` that provides the outer page structure. It injects `Styles.html` and `Scripts.html` using the `include()` server function.

### 3.1 Layout

| Element | Description |
|---|---|
| Top Navbar | Fixed navy bar showing the portal title and the active user's email |
| Sidebar | 230 px left panel with collapsible module groups and table links |
| Main Content | Scrollable flex area where forms and search results render |
| Toast | Bootstrap toast fixed to bottom-right for success/error feedback |
| Sidebar Overlay | Semi-transparent backdrop on mobile that dismisses the sidebar on tap |

### 3.2 Dependencies

- **Bootstrap 5.3.2** (CSS + JS bundle) — from `cdn.jsdelivr.net`
- **Font Awesome 6.5.0** (icons) — from `cdnjs.cloudflare.com`
- `Styles.html` injected via `<?!= include('Styles'); ?>`
- `Scripts.html` injected via `<?!= include('Scripts'); ?>`

### 3.3 Initialization Flow

On `DOMContentLoaded`, the client calls `getCurrentUser()` on the server. On success it displays the user email, builds the sidebar filtered by that user's allowed tables, and enables navigation. On failure it renders an access-denied message.

---

## 4. Scripts.html — Client-Side Logic

`Scripts.html` is the application's JavaScript layer (~930 lines). It communicates with the server exclusively via `google.script.run` calls. The portal is a single-page application — no page reloads occur.

---

### 4.1 MODULES & TABLES Config

**MODULES** defines the five sidebar groups:

| Module | Tables |
|---|---|
| Patient Management | `patients`, `visits`, `prescriptions` |
| Hospital Resources | `hospitals`, `departments`, `doctors`, `schedules`, `icu`, `referrals` |
| Pharmacy | `transactions` |
| Insurance Claims | `claims` |
| Citizen Services | `feedback` |

**TABLES** is the central configuration map. Each key maps to a config object:

| Property | Type | Purpose |
|---|---|---|
| `label` | string | Human-readable name shown in sidebar and headings |
| `pkField` | string | Primary key column name used for edit operations |
| `insertFn` | string | Server function name for inserting a new record |
| `searchFn` | string | Server function name for searching records |
| `updateFn` | string | Server function name for updating a record |
| `isMerged` | boolean | True when the insert writes to multiple sheets |
| `fields` | Array | Form field definitions (see below) |
| `subSections` | Array | Extra sections for merged tables (static or repeatable) |
| `searchFields` | Array | Filter field definitions for the search panel |
| `displayCols` | string[] | Column keys shown as table columns in search results |

#### Field object properties

| Property | Values / Type | Description |
|---|---|---|
| `name` | string | Maps to spreadsheet column header |
| `label` | string | Display label in the form |
| `type` | `text` \| `number` \| `date` \| `select` \| `fk` \| `textarea` | Input control type |
| `required` | boolean | Adds HTML5 `required` + red asterisk |
| `autoGen` | boolean | Shown as read-only; value set by server |
| `readonly` | boolean | Non-editable field with `defaultValue` |
| `defaultValue` | string | Pre-filled value (e.g. `'Port Said'`) |
| `fkFn` | string | Server function to call for FK dropdown options |
| `options` | string[] | Static options for select fields |
| `pattern` | string | HTML5 validation regex |
| `min` / `max` | number | Numeric bounds |
| `step` | string | Decimal step for number inputs |
| `maxLength` | number | Character limit |
| `hint` | string | Helper text below the control |

---

### 4.2 State Variables

| Variable | Type | Purpose |
|---|---|---|
| `currentTable` | string | Key of the currently active TABLES entry |
| `editMode` | boolean | True when the form is in update mode |
| `editId` | string | Primary key value of the record being edited |
| `searchCache` | Object[] | Last search result set; `editRow()` indexes into this |
| `fkCache` | Object | Keyed by `fkFn` name; prevents redundant server calls |

---

### 4.3 Core Functions

| Function | Description |
|---|---|
| `renderSidebar(allowed)` | Builds sidebar HTML from MODULES; filters by user's allowed table list |
| `showTable(name)` | Switches active table: resets state, highlights nav link, renders form + search panels |
| `switchTab(tab)` | Toggles visibility of form panel vs. search panel |
| `buildFormHTML(cfg)` | Generates the Add/Edit form card including sub-sections for merged tables |
| `buildSubSectionHTML(section)` | Renders either a static sub-form or a repeatable row table |
| `buildFieldHTML(f)` | Renders a single form control (input, select, fk dropdown, textarea) |
| `buildSearchHTML(cfg)` | Generates the search filter card and empty results container |
| `loadFkDropdowns(fields, row)` | Calls server FK functions (once each, cached) and populates all select controls |
| `addItemRow(sectionId)` | Appends a new row to a repeatable sub-table using cached FK options |
| `collectRepeatableItems(…)` | Reads all rows from a repeatable sub-table into an array of objects |
| `submitForm(e)` | Collects form values, calls insert or update server function, handles response |
| `resetForm()` | Clears form fields, resets edit state, empties repeatable rows |
| `runSearch(e)` | Gathers filter values, calls search server function, renders results table |
| `clearSearch()` | Clears all search inputs and results |
| `renderResults(rows, cfg)` | Builds and inserts the results HTML table with Edit buttons |
| `editRow(idx)` | Loads a row from `searchCache` into the form and switches to edit mode |
| `showSpinner()` / `hideSpinner()` | Toggles a full-page loading overlay |
| `showToast(type, msg)` | Shows a Bootstrap toast notification (`success` / `danger` / `info`) |

---

### 4.4 FK Dropdown Caching

`loadFkDropdowns()` de-duplicates FK functions by collecting all unique `fkFn` values across the main fields and all sub-section fields, then calls each server function **only once per session**. Results are stored in `fkCache` keyed by function name and reused for all subsequent table loads and new rows in repeatable sections.

---

### 4.5 Mobile Behaviour

`showTable()` is wrapped at startup to auto-close the sidebar on viewports narrower than 768 px after a table link is tapped. The sidebar slides in from the left using a CSS transition; a semi-transparent overlay captures tap-outside-to-close events.

---

## 5. Styles.html — CSS Styling

`Styles.html` defines ~160 lines of scoped CSS injected into the page head.

### 5.1 CSS Variables

| Variable | Value | Usage |
|---|---|---|
| `--navy` | `#1a3a5c` | Primary brand colour — navbar, headers, active states, buttons |
| `--navy-light` | `#2a4d7a` | Hover state for navy elements |
| `--sidebar-w` | `230px` | Sidebar width (desktop) |

### 5.2 Key Component Styles

| Component | Notable Rules |
|---|---|
| Sidebar | Fixed 230 px; slides in from left on mobile via CSS transition; `z-index: 1000` |
| Sidebar overlay | Hidden by default; `display:block` with `.open` class; semi-transparent backdrop |
| Cards | No border; soft box-shadow; 8 px radius; navy header strip |
| Form labels | 500 weight, 0.84 rem, dark grey |
| Required star | Red (`#dc3545`) asterisk next to required field labels |
| Tables | Uppercase 0.75 rem headers; vertically-middle cells; hover row highlight |
| Tabs | Navy active colour and bold weight |
| Section titles | Uppercase 0.88 rem, navy, letter-spacing 0.5 px |
| Subsection bar | Left navy border, light grey background — groups sub-form fields visually |
| Badge ID | Monospace font, light-blue background — shows PK in edit mode header |
| Spinner overlay | Fixed full-page semi-transparent white; flex-centered spinner |
| Mobile tweaks | Below 575 px: reduced card padding, smaller font sizes for table cells |

---

## 6. Database Schema

All data is stored in a single Google Sheets spreadsheet. The columns below match the headers created by `createSheetHeaders()`.

---

### 6.1 Core Clinical Tables

#### `patients`
`patient_id` | `national_id` | `first_name` | `last_name` | `gender` | `birth_date` | `phone` | `street` | `city` | `governorate` | `blood_type` | `emergency_contact` | `created_at`

#### `visits`
`visit_id` | `patient_id` | `hospital_id` | `doctor_id` | `department_id` | `visit_date` | `visit_type` | `diagnosis_code` | `symptoms` | `visit_status` | `waiting_time` | `total_cost`

#### `medical_records`
`record_id` | `visit_id` | `procedure_code` | `diagnosis_notes` | `treatment_notes` | `follow_up_required` | `created_at`

#### `visit_procedures`
`visit_procedure_id` | `visit_id` | `procedure_code` | `procedure_cost` | `procedure_date`

#### `prescriptions`
`prescription_id` | `visit_id` | `doctor_id` | `prescription_date` | `notes`

#### `prescription_items`
`prescription_item_id` | `prescription_id` | `drug_id` | `dosage` | `frequency` | `duration_days` | `quantity`

---

### 6.2 Hospital Resources

#### `hospitals`
`hospital_id` | `hospital_name` | `hospital_type` | `governorate` | `district` | `address` | `phone` | `total_beds` | `icu_capacity` | `Longitude` | `latitude` | `manager_name` | `manager_email` | `manager_phone`

#### `departments`
`department_id` | `hospital_id` | `department_name` | `floor_number`

#### `doctors`
`doctor_id` | `department_id` | `first_name` | `last_name` | `specialty` | `years_experience` | `phone` | `employment_status`

#### `doctor_schedules`
`schedule_id` | `doctor_id` | `shift_date` | `shift_start` | `shift_end`

#### `icu_status`
`icu_status_id` | `hospital_id` | `occupied_beds` | `available_beds` | `update_time`

#### `referrals`
`referral_id` | `patient_id` | `from_hospital_id` | `to_hospital_id` | `referral_reason` | `referral_date` | `referral_status`

#### `beds`
`bed_id` | `department_id` | `bed_number` | `bed_type` | `availability_status`

---

### 6.3 Pharmacy & Inventory

#### `drugs`
`drug_id` | `drug_name` | `generic_name` | `manufacturer` | `drug_category` | `unit_price`

#### `drug_transactions`
`transaction_id` | `drug_id` | `hospital_id` | `transaction_type` | `quantity` | `transaction_date` | `performed_by`

#### `drug_inventory`
`inventory_id` | `hospital_id` | `drug_id` | `quantity_available` | `reorder_level` | `expiration_date` | `last_updated`

#### `suppliers`
`supplier_id` | `supplier_name` | `contact_person` | `phone` | `email` | `address`

---

### 6.4 Insurance & Feedback

#### `claims`
`claim_id` | `patient_id` | `visit_id` | `hospital_id` | `claim_date` | `claim_amount` | `approved_amount` | `claim_status`

#### `claim_items`
`claim_item_id` | `claim_id` | `procedure_code` | `drug_id` | `item_cost` | `quantity`

#### `claim_approvals`
`approval_id` | `claim_id` | `reviewed_by` | `approval_status` | `approval_date` | `rejection_reason`

#### `patient_feedback`
`feedback_id` | `patient_id` | `hospital_id` | `doctor_id` | `rating` | `comments` | `feedback_date`

---

### 6.5 Reference / Lookup Tables

#### `diagnoses`
`diagnosis_code` | `diagnosis_name` | `diagnosis_category` | `severity_level`

#### `procedures`
`procedure_code` | `procedure_name` | `procedure_category` | `expected_cost` | `complexity_score`

#### `Users` (Access Control)
`email` | `tables`

> Use `*` in `tables` for full access, or comma-separate table keys to restrict (e.g. `patients,visits,claims`).

---

## 7. Access Control Reference

### 7.1 Authentication Flow

| Step | What happens |
|---|---|
| 1. User opens web app URL | Apps Script calls `doGet()` |
| 2. Session email retrieved | `Session.getActiveUser().getEmail()` |
| 3. Users sheet checked | `getUserAccess()` scans col A for the email |
| 4a. Not found | `doGet()` returns an HTML access-denied page |
| 4b. Found | Template evaluated; user sees the portal |
| 5. Client-side check | `getCurrentUser()` called from JS on `DOMContentLoaded` |
| 6. Sidebar filtered | Only tables in user's `tables` column are shown |
| 7. Per-call enforcement | `checkTableAccess()` called at the start of every CRUD function |

### 7.2 Table Permission Keys

Use these exact keys in the Users sheet `tables` column:

| Key | Grants access to |
|---|---|
| `patients` | Patients table |
| `visits` | Visits + medical_records + visit_procedures |
| `prescriptions` | Prescriptions + prescription_items |
| `hospitals` | Hospitals |
| `departments` | Departments |
| `doctors` | Doctors |
| `schedules` | Doctor schedules |
| `icu` | ICU status snapshots |
| `referrals` | Patient referrals |
| `transactions` | Drug transactions |
| `claims` | Claims + claim_items + claim_approvals |
| `approvals` | Standalone claim approvals |
| `feedback` | Patient feedback |
| `*` | All tables (full admin access) |

---

## 8. Deployment & Setup

### 8.1 Initial Setup

1. Open the target Google Sheets spreadsheet.
2. Open **Extensions > Apps Script**.
3. Create four files: `Code.gs`, `Index.html`, `Scripts.html`, `Styles.html`.
4. Paste the corresponding code into each file.
5. Run `setup()` once to register the `SPREADSHEET_ID` script property.
6. Run `createSheetHeaders()` to create all sheets with headers and formatting.

### 8.2 Deploying the Web App

1. In the Apps Script editor, click **Deploy > New deployment**.
2. Select **Web app** as the deployment type.
3. Set **Execute as**: Me (or a service account).
4. Set **Who has access**: Anyone within [Your Organization] (or Anyone for public access).
5. Click **Deploy** and copy the web app URL.

### 8.3 Adding Users

1. Open the **Users** sheet in the spreadsheet.
2. Add a row with the user's Google account email in column A.
3. In column B enter `*` for full access or a comma-separated list of table keys.
4. Changes take effect on the user's next page load — no redeployment needed.

### 8.4 Adding Reference Data

Before entering clinical records, populate the reference/lookup sheets: `diagnoses`, `procedures`, `drugs`, `hospitals`, `departments`, and `doctors`. These sheets power all FK dropdown menus throughout the portal.

---

*UHIP Data Entry Portal — AppScript Documentation | Version 2.0 | June 2025*
