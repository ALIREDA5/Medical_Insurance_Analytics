// ============================================================
// UHIP DATA ENTRY — Code.gs
// Version 2.0 | June 2025
// ============================================================

// ── ACCESS CONTROL ────────────────────────────────────────────

function checkTableAccess(tableName) {
  const access = getUserAccess();
  if (!access) throw new Error('Access denied.');
  if (access.tables === '*') return;
  const allowed = access.tables.split(',').map(t => t.trim());
  if (!allowed.includes(tableName)) throw new Error(`Access denied for table: ${tableName}`);
}

function doGet() {
  const user = Session.getActiveUser().getEmail();
  if (!isAuthorized(user)) {
    return HtmlService.createHtmlOutput(
      `<html><body style="font-family:sans-serif;padding:2rem;text-align:center">
        <h2 style="color:#c00">&#128274; Access Denied</h2>
        <p>Your account <b>${user}</b> is not authorized.</p>
        <p>Contact the system administrator to request access.</p>
      </body></html>`
    );
  }
  return HtmlService.createTemplateFromFile('Index')
    .evaluate()
    .setTitle('UHIP — Data Entry Portal')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

// ── AUTH ──────────────────────────────────────────────────────

function getUserAccess() {
  const email = Session.getActiveUser().getEmail();
  if (!email) return null;
  const sheet = getSpreadsheet().getSheetByName('Users');
  if (!sheet || sheet.getLastRow() < 2) return { email, tables: '*' };
  const data = sheet.getRange(2, 1, sheet.getLastRow() - 1, 2).getValues();
  for (const row of data) {
    if (row[0].toString().trim().toLowerCase() === email.toLowerCase()) {
      return { email, tables: row[1].toString().trim() || '*' };
    }
  }
  return null;
}

function isAuthorized(email) {
  return getUserAccess() !== null;
}

function getCurrentUser() {
  const access = getUserAccess();
  if (!access) return null;
  return { email: access.email, tables: access.tables };
}

// ── SPREADSHEET ───────────────────────────────────────────────

const SPREADSHEET_ID = '1PaXWgxmW7J-8SaVXc8lPAJIY3ZYxgebBvtjcjNrM6lc';

function getSpreadsheet() {
  return SpreadsheetApp.openById(SPREADSHEET_ID);
}

function setup() {
  PropertiesService.getScriptProperties()
    .setProperty('SPREADSHEET_ID', '1PaXWgxmW7J-8SaVXc8lPAJIY3ZYxgebBvtjcjNrM6lc');
}

// ── GENERIC HELPERS ───────────────────────────────────────────

function getSheet(name) {
  return getSpreadsheet().getSheetByName(name);
}

function getHeaders(sheetName) {
  const sheet = getSheet(sheetName);
  if (!sheet) return [];
  return sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0].map(String);
}

function getAllRows(sheetName) {
  const sheet = getSheet(sheetName);
  if (!sheet || sheet.getLastRow() < 2) return [];
  const headers = getHeaders(sheetName);
  const tz = Session.getScriptTimeZone();
  const data = sheet.getRange(2, 1, sheet.getLastRow() - 1, sheet.getLastColumn()).getValues();
  return data.map(row => {
    const obj = {};
    headers.forEach((h, i) => {
      obj[h] = row[i] instanceof Date
        ? Utilities.formatDate(row[i], tz, 'yyyy-MM-dd')
        : row[i];
    });
    return obj;
  });
}

function getNextId(sheetName, prefix, digits) {
  const sheet = getSheet(sheetName);
  if (sheet.getLastRow() < 2) return prefix + '1'.padStart(digits, '0');
  const ids = sheet.getRange(2, 1, sheet.getLastRow() - 1, 1).getValues().flat().map(String);
  const max = Math.max(0, ...ids.map(id => parseInt(id.replace(prefix, '')) || 0));
  return prefix + (max + 1).toString().padStart(digits, '0');
}

function appendRow(sheetName, rowData) {
  const sheet = getSheet(sheetName);
  const headers = getHeaders(sheetName);
  const row = headers.map(h => (rowData[h] !== undefined && rowData[h] !== null) ? rowData[h] : '');
  sheet.appendRow(row);
  return { success: true, id: rowData[headers[0]] };
}

function updateRow(sheetName, pkField, pkValue, rowData) {
  const sheet = getSheet(sheetName);
  const headers = getHeaders(sheetName);
  const pkIdx = headers.indexOf(pkField);
  if (pkIdx === -1) return { success: false, error: 'PK column not found' };
  const data = sheet.getRange(2, 1, sheet.getLastRow() - 1, sheet.getLastColumn()).getValues();
  for (let i = 0; i < data.length; i++) {
    if (data[i][pkIdx].toString() === pkValue.toString()) {
      headers.forEach((h, j) => {
        if (h !== pkField && rowData[h] !== undefined)
          sheet.getRange(i + 2, j + 1).setValue(rowData[h]);
      });
      return { success: true };
    }
  }
  return { success: false, error: 'Record not found: ' + pkValue };
}

function searchRows(sheetName, filters) {
  return getAllRows(sheetName).filter(row =>
    Object.entries(filters).every(([key, value]) => {
      if (value === null || value === undefined || value === '') return true;
      if (key.endsWith('_from')) {
        const field = key.slice(0, -5);
        return !row[field] || new Date(row[field]) >= new Date(value);
      }
      if (key.endsWith('_to')) {
        const field = key.slice(0, -3);
        return !row[field] || new Date(row[field]) <= new Date(value);
      }
      return (row[key] !== undefined) &&
        row[key].toString().toLowerCase().includes(value.toString().toLowerCase());
    })
  );
}

// ── DROPDOWN LOADERS ──────────────────────────────────────────

function getDropdownOptions(sheetName, idCol, labelCol) {
  const sheet = getSheet(sheetName);
  if (!sheet || sheet.getLastRow() < 2) return [];
  const headers = getHeaders(sheetName);
  const ii = headers.indexOf(idCol), li = headers.indexOf(labelCol);
  if (ii === -1 || li === -1) return [];
  return sheet.getRange(2, 1, sheet.getLastRow() - 1, sheet.getLastColumn())
    .getValues()
    .filter(r => r[ii])
    .map(r => ({ value: r[ii].toString(), label: `${r[ii]} — ${r[li]}` }));
}

function getPatientOptions()      { return getDropdownOptions('patients',      'patient_id',      'first_name'); }
function getHospitalOptions()     { return getDropdownOptions('hospitals',     'hospital_id',     'hospital_name'); }
function getDoctorOptions()       { return getDropdownOptions('doctors',       'doctor_id',       'first_name'); }
function getDepartmentOptions()   { return getDropdownOptions('departments',   'department_id',   'department_name'); }
function getDiagnosisOptions()    { return getDropdownOptions('diagnoses',     'diagnosis_code',  'diagnosis_name'); }
function getProcedureOptions()    { return getDropdownOptions('procedures',    'procedure_code',  'procedure_name'); }
function getDrugOptions()         { return getDropdownOptions('drugs',         'drug_id',         'drug_name'); }
function getVisitOptions()        { return getDropdownOptions('visits',        'visit_id',        'visit_date'); }
function getPrescriptionOptions() { return getDropdownOptions('prescriptions', 'prescription_id', 'prescription_date'); }
function getClaimOptions()        { return getDropdownOptions('claims',        'claim_id',        'claim_date'); }

// ── PATIENTS ──────────────────────────────────────────────────

function insertPatient(d) {
  checkTableAccess('patients');
  d.patient_id = getNextId('patients', 'PAT', 6);
  d.created_at = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');
  return appendRow('patients', d);
}
function searchPatients(f)    { checkTableAccess('patients'); return searchRows('patients', f); }
function updatePatient(id, d) { checkTableAccess('patients'); return updateRow('patients', 'patient_id', id, d); }

// ── HOSPITALS ─────────────────────────────────────────────────

function insertHospital(d) {
  checkTableAccess('hospitals');
  d.hospital_id = getNextId('hospitals', 'H', 3);
  return appendRow('hospitals', d);
}
function searchHospitals(f)    { checkTableAccess('hospitals'); return searchRows('hospitals', f); }
function updateHospital(id, d) { checkTableAccess('hospitals'); return updateRow('hospitals', 'hospital_id', id, d); }

// ── DEPARTMENTS ───────────────────────────────────────────────

function insertDepartment(d) {
  checkTableAccess('departments');
  d.department_id = getNextId('departments', 'DEPT', 4);
  return appendRow('departments', d);
}
function searchDepartments(f)    { checkTableAccess('departments'); return searchRows('departments', f); }
function updateDepartment(id, d) { checkTableAccess('departments'); return updateRow('departments', 'department_id', id, d); }

// ── DOCTORS ───────────────────────────────────────────────────

function insertDoctor(d) {
  checkTableAccess('doctors');
  d.doctor_id = getNextId('doctors', 'DOC', 4);
  return appendRow('doctors', d);
}
function searchDoctors(f)    { checkTableAccess('doctors'); return searchRows('doctors', f); }
function updateDoctor(id, d) { checkTableAccess('doctors'); return updateRow('doctors', 'doctor_id', id, d); }

// ── VISITS (merged: visit + medical_record + procedures) ──────

function insertVisitFull(data) {
  checkTableAccess('visits');
  const now = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');

  const visitId = getNextId('visits', 'VIS', 8);
  appendRow('visits', {
    visit_id: visitId,
    patient_id: data.patient_id,       hospital_id: data.hospital_id,
    doctor_id: data.doctor_id,         department_id: data.department_id,
    visit_date: data.visit_date,       visit_type: data.visit_type,
    diagnosis_code: data.diagnosis_code, symptoms: data.symptoms,
    visit_status: data.visit_status,   waiting_time: data.waiting_time,
    total_cost: data.total_cost
  });

  appendRow('medical_records', {
    record_id:          getNextId('medical_records', 'MR', 8),
    visit_id:           visitId,
    procedure_code:     data.mr_procedure_code,
    diagnosis_notes:    data.mr_diagnosis_notes,
    treatment_notes:    data.mr_treatment_notes,
    follow_up_required: data.mr_follow_up_required,
    created_at:         now
  });

  (data.procedures || []).forEach(proc => {
    if (!proc.procedure_code) return;
    appendRow('visit_procedures', {
      visit_procedure_id: getNextId('visit_procedures', 'VP', 8),
      visit_id:           visitId,
      procedure_code:     proc.procedure_code,
      procedure_cost:     proc.procedure_cost || 0,
      procedure_date:     data.visit_date
    });
  });

  return { success: true, id: visitId };
}
function searchVisits(f)    { checkTableAccess('visits'); return searchRows('visits', f); }
function updateVisit(id, d) { checkTableAccess('visits'); return updateRow('visits', 'visit_id', id, d); }

// ── PRESCRIPTIONS (merged: prescription + items) ──────────────

function insertPrescriptionFull(data) {
  checkTableAccess('prescriptions');
  const rxId = getNextId('prescriptions', 'RX', 8);
  appendRow('prescriptions', {
    prescription_id:   rxId,
    visit_id:          data.visit_id,
    doctor_id:         data.doctor_id,
    prescription_date: data.prescription_date,
    notes:             data.notes
  });
  (data.items || []).forEach(item => {
    if (!item.drug_id) return;
    appendRow('prescription_items', {
      prescription_item_id: getNextId('prescription_items', 'PI', 8),
      prescription_id:      rxId,
      drug_id:              item.drug_id,
      dosage:               item.dosage,
      frequency:            item.frequency,
      duration_days:        item.duration_days,
      quantity:             item.quantity
    });
  });
  return { success: true, id: rxId };
}
function searchPrescriptions(f)    { checkTableAccess('prescriptions'); return searchRows('prescriptions', f); }
function updatePrescription(id, d) { checkTableAccess('prescriptions'); return updateRow('prescriptions', 'prescription_id', id, d); }

// ── DOCTOR SCHEDULES ──────────────────────────────────────────

function insertDoctorSchedule(d) {
  checkTableAccess('schedules');
  d.schedule_id = getNextId('doctor_schedules', 'SCH', 7);
  return appendRow('doctor_schedules', d);
}
function searchDoctorSchedules(f)    { checkTableAccess('schedules'); return searchRows('doctor_schedules', f); }
function updateDoctorSchedule(id, d) { checkTableAccess('schedules'); return updateRow('doctor_schedules', 'schedule_id', id, d); }

// ── ICU STATUS ────────────────────────────────────────────────

function insertIcuStatus(d) {
  checkTableAccess('icu');
  d.icu_status_id = getNextId('icu_status', 'ICU', 6);
  d.update_time = Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');
  return appendRow('icu_status', d);
}
function searchIcuStatus(f)     { checkTableAccess('icu'); return searchRows('icu_status', f); }
function updateIcuStatus(id, d) { checkTableAccess('icu'); return updateRow('icu_status', 'icu_status_id', id, d); }

// ── REFERRALS ─────────────────────────────────────────────────

function insertReferral(d) {
  checkTableAccess('referrals');
  d.referral_id = getNextId('referrals', 'REF', 6);
  return appendRow('referrals', d);
}
function searchReferrals(f)    { checkTableAccess('referrals'); return searchRows('referrals', f); }
function updateReferral(id, d) { checkTableAccess('referrals'); return updateRow('referrals', 'referral_id', id, d); }

// ── DRUG TRANSACTIONS ─────────────────────────────────────────

function insertDrugTransaction(d) {
  checkTableAccess('transactions');
  d.transaction_id = getNextId('drug_transactions', 'DT', 7);
  return appendRow('drug_transactions', d);
}
function searchDrugTransactions(f)    { checkTableAccess('transactions'); return searchRows('drug_transactions', f); }
function updateDrugTransaction(id, d) { checkTableAccess('transactions'); return updateRow('drug_transactions', 'transaction_id', id, d); }

// ── CLAIMS (merged: claim + items) ────────────────────────────

function insertClaimFull(data) {
  checkTableAccess('claims');
  const claimId = getNextId('claims', 'CLM', 8);
  appendRow('claims', {
    claim_id:        claimId,
    patient_id:      data.patient_id,
    visit_id:        data.visit_id,
    hospital_id:     data.hospital_id,
    claim_date:      data.claim_date,
    claim_amount:    data.claim_amount,
    approved_amount: data.approved_amount,
    claim_status:    data.claim_status
  });
  (data.items || []).forEach(item => {
    if (!item.procedure_code && !item.drug_id) return;
    appendRow('claim_items', {
      claim_item_id:  getNextId('claim_items', 'CI', 9),
      claim_id:       claimId,
      procedure_code: item.procedure_code || '',
      drug_id:        item.drug_id        || '',
      item_cost:      item.item_cost      || 0,
      quantity:       item.quantity       || 1
    });
  });
  return { success: true, id: claimId };
}
function searchClaims(f)    { checkTableAccess('claims'); return searchRows('claims', f); }
function updateClaim(id, d) { checkTableAccess('claims'); return updateRow('claims', 'claim_id', id, d); }

// ── CLAIM APPROVALS ───────────────────────────────────────────

function insertClaimApproval(d) {
  checkTableAccess('approvals');
  d.approval_id = getNextId('claim_approvals', 'APR', 8);
  return appendRow('claim_approvals', d);
}
function searchClaimApprovals(f)    { checkTableAccess('approvals'); return searchRows('claim_approvals', f); }
function updateClaimApproval(id, d) { checkTableAccess('approvals'); return updateRow('claim_approvals', 'approval_id', id, d); }

// ── PATIENT FEEDBACK ──────────────────────────────────────────

function insertPatientFeedback(d) {
  checkTableAccess('feedback');
  d.feedback_id = getNextId('patient_feedback', 'FB', 8);
  return appendRow('patient_feedback', d);
}
function searchPatientFeedback(f)    { checkTableAccess('feedback'); return searchRows('patient_feedback', f); }
function updatePatientFeedback(id, d){ checkTableAccess('feedback'); return updateRow('patient_feedback', 'feedback_id', id, d); }

// ── SHEET SETUP ───────────────────────────────────────────────

function createSheetHeaders() {
  const ss = getSpreadsheet();
  const HEADERS = {
    patients:           ['patient_id','national_id','first_name','last_name','gender','birth_date','phone','street','city','governorate','blood_type','emergency_contact','created_at'],
    visits:             ['visit_id','patient_id','hospital_id','doctor_id','department_id','visit_date','visit_type','diagnosis_code','symptoms','visit_status','waiting_time','total_cost'],
    medical_records:    ['record_id','visit_id','procedure_code','diagnosis_notes','treatment_notes','follow_up_required','created_at'],
    visit_procedures:   ['visit_procedure_id','visit_id','procedure_code','procedure_cost','procedure_date'],
    prescriptions:      ['prescription_id','visit_id','doctor_id','prescription_date','notes'],
    prescription_items: ['prescription_item_id','prescription_id','drug_id','dosage','frequency','duration_days','quantity'],
    doctor_schedules:   ['schedule_id','doctor_id','shift_date','shift_start','shift_end'],
    icu_status:         ['icu_status_id','hospital_id','occupied_beds','available_beds','update_time'],
    referrals:          ['referral_id','patient_id','from_hospital_id','to_hospital_id','referral_reason','referral_date','referral_status'],
    drug_transactions:  ['transaction_id','drug_id','hospital_id','transaction_type','quantity','transaction_date','performed_by'],
    claims:             ['claim_id','patient_id','visit_id','hospital_id','claim_date','claim_amount','approved_amount','claim_status'],
    claim_items:        ['claim_item_id','claim_id','procedure_code','drug_id','item_cost','quantity'],
    claim_approvals:    ['approval_id','claim_id','reviewed_by','approval_status','approval_date','rejection_reason'],
    patient_feedback:   ['feedback_id','patient_id','hospital_id','doctor_id','rating','comments','feedback_date'],
    hospitals:          ['hospital_id','hospital_name','hospital_type','governorate','district','address','phone','total_beds','icu_capacity','Longitude','latitude','manager_name','manager_email','manager_phone'],
    departments:        ['department_id','hospital_id','department_name','floor_number'],
    doctors:            ['doctor_id','department_id','first_name','last_name','specialty','years_experience','phone','employment_status'],
    diagnoses:          ['diagnosis_code','diagnosis_name','diagnosis_category','severity_level'],
    procedures:         ['procedure_code','procedure_name','procedure_category','expected_cost','complexity_score'],
    drugs:              ['drug_id','drug_name','generic_name','manufacturer','drug_category','unit_price'],
    suppliers:          ['supplier_id','supplier_name','contact_person','phone','email','address'],
    drug_inventory:     ['inventory_id','hospital_id','drug_id','quantity_available','reorder_level','expiration_date','last_updated'],
    beds:               ['bed_id','department_id','bed_number','bed_type','availability_status'],
    Users:              ['email','tables']
  };

  let created = 0, skipped = 0;
  Object.entries(HEADERS).forEach(([sheetName, headers]) => {
    let sheet = ss.getSheetByName(sheetName);
    if (!sheet) {
      sheet = ss.insertSheet(sheetName);
      created++;
    } else {
      Logger.log('Skipping existing sheet: ' + sheetName);
      skipped++;
      return;
    }
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.getRange(1, 1, 1, headers.length)
      .setBackground('#1a3a5c').setFontColor('#ffffff')
      .setFontWeight('bold').setFontSize(10);
    sheet.setFrozenRows(1);
    sheet.autoResizeColumns(1, headers.length);
    Logger.log('Created: ' + sheetName);
  });
  Logger.log(`Done! Created: ${created} | Skipped: ${skipped}`);
}
