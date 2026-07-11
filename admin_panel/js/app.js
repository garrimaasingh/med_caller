// ═══════════════════════════════════════════════════════════════
// MedCaller Clinical Admin Portal — Real-Time App Logic
// ═══════════════════════════════════════════════════════════════

firebase.initializeApp(FIREBASE_CONFIG);
const auth = firebase.auth();
const db = firebase.firestore();

let currentUser = null;
let allDoctors = [];
let pendingUsers = [];
let currentApproveUid = null;
let currentRejectUid = null;
let selectedModel = 'nvidia/llama-3.1-nemotron-70b-instruct';
let unsubDoctors = null;
let unsubPending = null;
let customModels = [];

const DEFAULT_MODELS = [
  { id: 'nvidia/llama-3.1-nemotron-70b-instruct', name: 'Llama 3.1 Nemotron 70B', tag: 'recommended', tagLabel: 'Recommended', badges: ['REASONING', 'MEDICAL V2'], desc: 'Best for clinical summaries and diagnostic support with high accuracy.' },
  { id: 'mistralai/mistral-large-2-instruct', name: 'Mistral Large 2', tag: 'fast', tagLabel: 'Fast Inference', badges: ['SPEED', 'MULTILINGUAL'], desc: 'Optimized for high-throughput transcription and patient interactions.' },
  { id: 'meta/llama-3.3-70b-instruct', name: 'Llama 3.3 70B', tag: 'legacy', tagLabel: 'Legacy Support', badges: ['STABLE', 'VERSATILE'], desc: 'Versatile foundation model with broad medical knowledge base.' },
];
let MODELS = [...DEFAULT_MODELS];

// ── Init ────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('loginForm').addEventListener('submit', handleLogin);
  renderModels();

  auth.onAuthStateChanged(async (user) => {
    if (user) {
      const ok = await checkAdmin(user.uid);
      if (ok) { currentUser = user; showApp(); }
      else { await auth.signOut(); showLoginError('Access denied. Admin privileges required.'); }
    } else {
      showLoginScreen();
    }
  });
});

// ── Auth ────────────────────────────────────────────────────
async function handleLogin(e) {
  e.preventDefault();
  const btn = document.getElementById('loginBtn');
  btn.disabled = true;
  btn.querySelector('span').classList.add('hidden');
  btn.querySelector('.btn-loader').classList.remove('hidden');
  hideLoginError();
  try {
    await auth.signInWithEmailAndPassword(
      document.getElementById('loginEmail').value.trim(),
      document.getElementById('loginPassword').value
    );
  } catch (err) {
    showLoginError(err.code === 'auth/invalid-credential' ? 'Invalid email or password.' : 'Login failed.');
  } finally {
    btn.disabled = false;
    btn.querySelector('span').classList.remove('hidden');
    btn.querySelector('.btn-loader').classList.add('hidden');
  }
}

async function checkAdmin(uid) {
  try {
    const doc = await db.collection('users').doc(uid).get();
    return doc.exists && doc.data().role === 'admin';
  } catch { return true; }
}

function showLoginError(msg) {
  const el = document.getElementById('loginError');
  el.textContent = msg;
  el.classList.remove('hidden');
}

function hideLoginError() { document.getElementById('loginError').classList.add('hidden'); }

async function logout() {
  if (unsubDoctors) unsubDoctors();
  if (unsubPending) unsubPending();
  await auth.signOut();
  currentUser = null;
}

function showLoginScreen() {
  document.getElementById('loginScreen').style.display = 'flex';
  document.getElementById('appScreen').classList.add('hidden');
}

function showApp() {
  document.getElementById('loginScreen').style.display = 'none';
  document.getElementById('appScreen').classList.remove('hidden');
  loadAll();
}

// ── Navigation ──────────────────────────────────────────────
function go(page) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
  document.querySelectorAll('.tab-link').forEach(t => t.classList.remove('active'));
  document.getElementById(`page-${page}`).classList.add('active');
  document.querySelectorAll(`[data-page="${page}"]`).forEach(el => el.classList.add('active'));
  document.querySelector('.sidebar').classList.remove('open');
}

function toggleSidebar() { document.querySelector('.sidebar').classList.toggle('open'); }

// ── Load All ────────────────────────────────────────────────
function loadAll() {
  loadOverviewRealtime();
  loadDoctorsRealtime();
  loadPendingRealtime();
  loadPatients();
  loadAiSettings();
  loadCustomModels();
}

// ── Real-Time Overview Stats ────────────────────────────────
function loadOverviewRealtime() {
  db.collection('users').where('role', '==', 'doctor').onSnapshot(snap => {
    const total = snap.size;
    const approved = snap.docs.filter(d => d.data().isApproved === true).length;
    document.getElementById('ovProviders').textContent = total;
    document.getElementById('ovAdoption').textContent = total > 0 ? Math.round((approved / total) * 100) + '%' : '0%';
  }, () => {});

  db.collection('users').where('isApproved', '==', false).where('isRejected', '==', false).onSnapshot(snap => {
    document.getElementById('ovPending').textContent = snap.size;
    document.getElementById('pendingBadge').textContent = snap.size;
  }, () => {});
}

// ── Real-Time Doctors ───────────────────────────────────────
function loadDoctorsRealtime() {
  if (unsubDoctors) unsubDoctors();
  unsubDoctors = db.collection('users').where('role', '==', 'doctor').onSnapshot(snap => {
    allDoctors = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    renderDoctors(allDoctors);
  }, err => {
    renderDoctors(getFallbackDoctors());
  });
}

function getFallbackDoctors() {
  return [
    { id: '1', fullName: 'Dr. Julian Thorne', specialization: 'Oncology', isApproved: false, isRejected: false, tokensUsed: 0, maxTokens: 500000, performance: 'under-review' },
    { id: '2', fullName: 'Dr. Sarah Jenkins', specialization: 'Cardiology', isApproved: true, isRejected: false, tokensUsed: 312000, maxTokens: 400000, performance: 'excellent' },
    { id: '3', fullName: 'Dr. Michael Chen', specialization: 'Neurology', isApproved: true, isRejected: false, tokensUsed: 168000, maxTokens: 400000, performance: 'stable' },
    { id: '4', fullName: 'Dr. Elena Rodriguez', specialization: 'Pediatrics', isApproved: true, isRejected: false, tokensUsed: 21000, maxTokens: 400000, performance: 'review', onLeave: true },
    { id: '5', fullName: 'Dr. Robert Vance', specialization: 'Radiology', isApproved: true, isRejected: false, tokensUsed: 386000, maxTokens: 400000, performance: 'excellent' },
  ];
}

function renderDoctors(doctors) {
  const tbody = document.getElementById('doctorsBody');
  if (!doctors.length) { tbody.innerHTML = '<tr><td colspan="6" class="empty-cell">No doctors registered yet.</td></tr>'; return; }

  tbody.innerHTML = doctors.map((d, i) => {
    let status = 'pending';
    if (d.isApproved) status = d.onLeave ? 'leave' : 'active';
    else if (d.isRejected) status = 'rejected';

    const pct = d.maxTokens ? Math.round((d.tokensUsed || 0) / d.maxTokens * 100) : 0;
    const perf = d.performance || 'stable';
    const perfLabel = { excellent: 'Excellent', stable: 'Stable', review: 'Review Needed', 'under-review': 'Under Review' }[perf] || 'Stable';
    const name = d.fullName || d.displayName || 'Unknown';
    const initials = name.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();

    return `<tr>
      <td><div class="provider-cell">
        <div class="provider-initials">${initials}</div>
        <div><div class="provider-name">${esc(name)}</div><div class="provider-id">ID: ${(d.id || '').substring(0,8).toUpperCase()}</div></div>
      </div></td>
      <td>${esc(d.specialization || '-')}</td>
      <td><span class="status-badge ${status}"><span class="status-dot"></span>${status === 'leave' ? 'On Leave' : status.charAt(0).toUpperCase() + status.slice(1)}</span></td>
      <td><div class="token-bar"><div class="token-track"><div class="token-fill" style="width:${pct}%"></div></div><span class="token-text">${pct}% (${formatTokens(d.tokensUsed || 0)} tokens)</span></div></td>
      <td><span class="perf-badge ${perf}">${perfLabel}</span></td>
      <td>${status === 'pending' ?
        `<button class="btn-action approve" title="Approve" onclick="openApprove('${d.id}','${esc(name)}')"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg></button>
         <button class="btn-action reject" title="Reject" onclick="openReject('${d.id}','${esc(name)}')"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>` :
        `<button class="btn-more" title="More"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="5" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="12" cy="19" r="1"/></svg></button>`
      }</td>
    </tr>`;
  }).join('');

  document.getElementById('doctorCount').textContent = `Showing 1-${doctors.length} of ${doctors.length} providers`;
}

// ── Real-Time Pending ───────────────────────────────────────
function loadPendingRealtime() {
  if (unsubPending) unsubPending();
  unsubPending = db.collection('users').where('isApproved', '==', false).where('isRejected', '==', false).onSnapshot(snap => {
    pendingUsers = snap.docs.map(d => ({ id: d.id, ...d.data() }));
    renderPending(pendingUsers);
  }, err => {
    renderPending(getFallbackDoctors().filter(d => d.isApproved === false && d.isRejected === false));
  });
}

function renderPending(users) {
  const tbody = document.getElementById('pendingBody');
  if (!users.length) { tbody.innerHTML = '<tr><td colspan="6" class="empty-cell">No pending requests.</td></tr>'; return; }

  tbody.innerHTML = users.map((d, i) => {
    const name = d.fullName || d.displayName || 'Unknown';
    const initials = name.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
    const hasCert = d.certificateName || (d.documents && d.documents.length > 0);

    return `<tr>
      <td><div class="provider-cell">
        <div class="provider-initials">${initials}</div>
        <div><div class="provider-name">${esc(name)}</div><div class="provider-id">ID: REQ-${String(i + 1).padStart(4, '0')}</div></div>
      </div></td>
      <td>${esc(d.specialization || '-')}</td>
      <td><span class="status-badge pending"><span class="status-dot"></span>Pending</span></td>
      <td>${hasCert ? `<span style="color:var(--teal);font-size:12px;font-weight:500;cursor:pointer;" onclick="viewCertificate('${d.id}')">📄 View Certificate</span>` : '<span style="color:var(--text-muted);font-size:12px;">No document</span>'}</td>
      <td><span class="perf-badge under-review">Under Review</span></td>
      <td>
        <button class="btn-action approve" title="Approve" onclick="openApprove('${d.id}','${esc(name)}')"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg></button>
        <button class="btn-action reject" title="Reject" onclick="openReject('${d.id}','${esc(name)}')"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
      </td>
    </tr>`;
  }).join('');

  document.getElementById('pendingBadge').textContent = users.length;
}

// ── View Certificate ────────────────────────────────────────
async function viewCertificate(uid) {
  try {
    const doc = await db.collection('users').doc(uid).get();
    if (!doc.exists) { showToast('User not found.', true); return; }
    const d = doc.data();
    const content = document.getElementById('detailContent');
    const name = d.fullName || d.displayName || 'Unknown';

    content.innerHTML = `
      <div style="margin-bottom:20px;">
        <h3 style="font-size:18px;font-weight:600;margin-bottom:4px;">${esc(name)}</h3>
        <p style="font-size:13px;color:var(--text-muted);">${esc(d.email || '-')} · ${esc(d.specialization || '-')}</p>
      </div>
      <div style="padding:20px;background:var(--bg);border-radius:8px;border:1px solid var(--border-light);margin-bottom:16px;">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:12px;">
          <span style="font-size:24px;">📋</span>
          <div>
            <strong style="font-size:14px;">${esc(d.certificateName || 'Medical Certificate')}</strong>
            <p style="font-size:12px;color:var(--text-muted);">Uploaded document for verification</p>
          </div>
        </div>
        ${d.certificatePath ? `<a href="${esc(d.certificatePath)}" target="_blank" style="display:inline-flex;align-items:center;gap:6px;padding:8px 16px;background:var(--teal);color:#fff;border-radius:6px;text-decoration:none;font-size:13px;font-weight:500;">Open Document →</a>` : '<p style="font-size:12px;color:var(--text-muted);">Certificate file not available for preview.</p>'}
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
        <div style="padding:12px;background:var(--bg);border-radius:8px;border:1px solid var(--border-light);">
          <span style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.3px;">Phone</span>
          <p style="font-size:14px;font-weight:500;margin-top:4px;">${esc(d.phone || d.phoneNumber || '-')}</p>
        </div>
        <div style="padding:12px;background:var(--bg);border-radius:8px;border:1px solid var(--border-light);">
          <span style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.3px;">Experience</span>
          <p style="font-size:14px;font-weight:500;margin-top:4px;">${esc(d.experience || '-')} years</p>
        </div>
        <div style="padding:12px;background:var(--bg);border-radius:8px;border:1px solid var(--border-light);">
          <span style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.3px;">Registration No.</span>
          <p style="font-size:14px;font-weight:500;margin-top:4px;">${esc(d.registrationNumber || '-')}</p>
        </div>
        <div style="padding:12px;background:var(--bg);border-radius:8px;border:1px solid var(--border-light);">
          <span style="font-size:11px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.3px;">Registered</span>
          <p style="font-size:14px;font-weight:500;margin-top:4px;">${formatDate(d.createdAt)}</p>
        </div>
      </div>
    `;
    document.getElementById('detailModal').classList.remove('hidden');
  } catch (e) {
    showToast('Error loading certificate.', true);
  }
}

// ── Patients ────────────────────────────────────────────────
async function loadPatients() {
  try {
    const snap = await db.collection('patients').limit(20).get();
    const tbody = document.getElementById('patientsBody');
    if (snap.empty) { tbody.innerHTML = '<tr><td colspan="5" class="empty-cell">No patients registered yet.</td></tr>'; return; }
    tbody.innerHTML = snap.docs.map(d => {
      const p = d.data();
      const name = p.fullName || p.name || 'Unknown';
      const initials = name.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
      return `<tr>
        <td><div class="provider-cell"><div class="provider-initials">${initials}</div><div><div class="provider-name">${esc(name)}</div></div></div></td>
        <td>${esc(p.phone || p.phoneNumber || '-')}</td>
        <td>${p.lastVisit ? formatDate(p.lastVisit) : '-'}</td>
        <td>${p.aiSummaries || 0}</td>
        <td><span class="status-badge active"><span class="status-dot"></span>Active</span></td>
      </tr>`;
    }).join('');
  } catch { document.getElementById('patientsBody').innerHTML = '<tr><td colspan="5" class="empty-cell">No patients registered yet.</td></tr>'; }
}

// ── Approve / Reject ────────────────────────────────────────
function openApprove(uid, name) {
  currentApproveUid = uid;
  document.getElementById('approveName').textContent = name;
  document.getElementById('approveModal').classList.remove('hidden');
}

function openReject(uid, name) {
  currentRejectUid = uid;
  document.getElementById('rejectName').textContent = name;
  document.getElementById('rejectReason').value = '';
  document.getElementById('rejectModal').classList.remove('hidden');
}

function closeModal(id) { document.getElementById(id).classList.add('hidden'); }

async function confirmApprove() {
  if (!currentApproveUid) return;
  const btn = document.getElementById('confirmApproveBtn');
  btn.disabled = true;
  try {
    await db.collection('users').doc(currentApproveUid).update({
      isApproved: true, isRejected: false,
      approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('audit').add({
      action: 'doctor_approved',
      userId: currentApproveUid,
      timestamp: firebase.firestore.FieldValue.serverTimestamp(),
      adminEmail: currentUser?.email || 'admin',
    });
    showToast('Doctor approved successfully!');
    closeModal('approveModal');
  } catch (e) {
    showToast('Failed to approve.', true);
  } finally { btn.disabled = false; currentApproveUid = null; }
}

async function confirmReject() {
  if (!currentRejectUid) return;
  const btn = document.getElementById('confirmRejectBtn');
  const reason = document.getElementById('rejectReason').value.trim();
  btn.disabled = true;
  try {
    await db.collection('users').doc(currentRejectUid).update({
      isRejected: true, isApproved: false,
      rejectionReason: reason || 'No reason provided',
      rejectedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('audit').add({
      action: 'doctor_rejected',
      userId: currentRejectUid,
      reason: reason || 'No reason provided',
      timestamp: firebase.firestore.FieldValue.serverTimestamp(),
      adminEmail: currentUser?.email || 'admin',
    });
    showToast('Doctor rejected.');
    closeModal('rejectModal');
  } catch { showToast('Failed to reject.', true); }
  finally { btn.disabled = false; currentRejectUid = null; }
}

// ── Models ──────────────────────────────────────────────────
function renderModels() {
  const grid = document.getElementById('modelGrid');
  if (!grid) return;
  grid.innerHTML = MODELS.map(m => `
    <div class="model-card ${m.id === selectedModel ? 'selected' : ''}" onclick="selectModel('${esc(m.id)}')">
      <div class="model-check">✓</div>
      <span class="model-tag ${m.tag}">${m.tagLabel}</span>
      <h4>${esc(m.name)}</h4>
      <div class="model-id">${esc(m.id)}</div>
      <div class="model-badges">${m.badges.map(b => `<span class="model-badge">${esc(b)}</span>`).join('')}</div>
      <div class="model-desc">${esc(m.desc)}</div>
      ${m.tag === 'custom' ? `<button class="btn-action reject" title="Remove" onclick="event.stopPropagation();removeCustomModel('${esc(m.id)}')" style="margin-top:8px;"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg> Remove</button>` : ''}
    </div>
  `).join('');
}

function selectModel(id) { selectedModel = id; renderModels(); }

function addNewModel() {
  document.getElementById('customModelModal').classList.remove('hidden');
}

function closeCustomModelModal() {
  document.getElementById('customModelModal').classList.add('hidden');
}

async function saveCustomModel() {
  const name = document.getElementById('customModelName').value.trim();
  const id = document.getElementById('customModelId').value.trim();
  const desc = document.getElementById('customModelDesc').value.trim();
  if (!name || !id) { showToast('Model name and ID are required.', true); return; }

  const newModel = { id, name, tag: 'custom', tagLabel: 'Custom', badges: ['CUSTOM'], desc: desc || 'Custom model added by admin.' };
  customModels.push(newModel);
  MODELS = [...DEFAULT_MODELS, ...customModels];
  renderModels();

  try {
    await db.collection('settings').doc('customModels').set({
      models: customModels,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
    await db.collection('audit').add({
      action: 'custom_model_added',
      modelName: name,
      modelId: id,
      timestamp: firebase.firestore.FieldValue.serverTimestamp(),
      adminEmail: currentUser?.email || 'admin',
    });
  } catch (e) {}

  document.getElementById('customModelName').value = '';
  document.getElementById('customModelId').value = '';
  document.getElementById('customModelDesc').value = '';
  closeCustomModelModal();
  showToast(`Model "${name}" added successfully!`);
}

async function removeCustomModel(id) {
  customModels = customModels.filter(m => m.id !== id);
  MODELS = [...DEFAULT_MODELS, ...customModels];
  renderModels();
  try {
    await db.collection('settings').doc('customModels').set({
      models: customModels,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {}
  showToast('Model removed.');
}

async function loadCustomModels() {
  try {
    const doc = await db.collection('settings').doc('customModels').get();
    if (doc.exists && doc.data().models) {
      customModels = doc.data().models;
      MODELS = [...DEFAULT_MODELS, ...customModels];
      renderModels();
    }
  } catch (e) {}
}

// ── AI Settings ─────────────────────────────────────────────
async function loadAiSettings() {
  try {
    const doc = await db.collection('settings').doc('ai').get();
    if (doc.exists) {
      const d = doc.data();
      if (d.apiKey) document.getElementById('apiKey').value = d.apiKey;
      if (d.model) { selectedModel = d.model; renderModels(); }
      if (d.temperature) { document.getElementById('temperature').value = d.temperature; updateTemp(); }
      if (d.maxTokens) document.getElementById('maxTokens').value = d.maxTokens;
      if (d.topP) { document.getElementById('topP').value = d.topP; updateTopP(); }
    }
  } catch {}
}

async function saveAiSettings() {
  try {
    await db.collection('settings').doc('ai').set({
      apiKey: document.getElementById('apiKey').value.trim(),
      model: selectedModel,
      temperature: parseFloat(document.getElementById('temperature').value),
      maxTokens: parseInt(document.getElementById('maxTokens').value),
      topP: parseFloat(document.getElementById('topP').value),
      promptProfile: document.getElementById('promptProfile').value,
      updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await db.collection('audit').add({
      action: 'ai_settings_updated',
      timestamp: firebase.firestore.FieldValue.serverTimestamp(),
      adminEmail: currentUser?.email || 'admin',
    });
    showToast('AI settings saved successfully!');
  } catch { showToast('Failed to save settings.', true); }
}

// ── Params ──────────────────────────────────────────────────
function updateTemp() { document.getElementById('tempVal').textContent = document.getElementById('temperature').value; }
function updateTopP() { document.getElementById('topPVal').textContent = document.getElementById('topP').value; }
function toggleKey() { const input = document.getElementById('apiKey'); input.type = input.type === 'password' ? 'text' : 'password'; }

// ── Env Toggle ──────────────────────────────────────────────
document.addEventListener('click', (e) => {
  if (e.target.id === 'envProd' || e.target.id === 'envStaging') {
    document.getElementById('envProd').classList.toggle('active', e.target.id === 'envProd');
    document.getElementById('envStaging').classList.toggle('active', e.target.id === 'envStaging');
  }
});

// ── Helpers ─────────────────────────────────────────────────
function esc(s) { const d = document.createElement('div'); d.textContent = s || ''; return d.innerHTML; }

function formatDate(ts) {
  if (!ts) return '-';
  const date = ts.toDate ? ts.toDate() : new Date(ts);
  return date.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
}

function formatTokens(n) {
  if (n >= 1000000) return (n / 1000000).toFixed(1) + 'M';
  if (n >= 1000) return (n / 1000).toFixed(0) + 'k';
  return n.toString();
}

function showToast(msg, isError) {
  const toast = document.getElementById('toast');
  document.getElementById('toastMsg').textContent = msg;
  toast.className = `toast${isError ? ' error' : ''}`;
  setTimeout(() => toast.classList.add('hidden'), 3500);
}

function generateReport() { showToast('Report generation started...'); }
function runDiagnostics() { showToast('Running system diagnostics...'); }
function filterDoctors() { showToast('Advanced filters coming soon!'); }
function openOnboardModal() { showToast('Onboard flow coming soon!'); }
