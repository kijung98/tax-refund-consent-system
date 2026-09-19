// ============================================================
// 입력 자동완성 유틸
// - 주민등록번호: 6자리-7자리 하이픈 자동입력
// - 전화번호: 3-4-4 / 3-3-4 하이픈 자동입력
// - 주소검색: 다음(카카오) 우편번호 서비스 연동
//
// 사용 전 HTML에서 아래를 함께 로드해야 합니다:
//   <script src="//t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
//   <script src="../js/form-utils.js"></script>
// ============================================================

/**
 * 입력창에 주민등록번호 형식(6자리-7자리)을 입력하는 동안 자동으로 적용한다.
 */
function attachRRNFormatter(input) {
  input.addEventListener('input', () => {
    const digits = input.value.replace(/[^0-9]/g, '').slice(0, 13);
    input.value = digits.length > 6 ? `${digits.slice(0, 6)}-${digits.slice(6)}` : digits;
  });
}

/**
 * 입력창에 전화번호 형식(예: 010-1234-5678, 02-123-4567)을 입력하는 동안 자동으로 적용한다.
 */
function attachPhoneFormatter(input) {
  input.addEventListener('input', () => {
    const digits = input.value.replace(/[^0-9]/g, '').slice(0, 11);
    let formatted = digits;
    if (digits.length > 3 && digits.length <= 7) {
      formatted = `${digits.slice(0, 3)}-${digits.slice(3)}`;
    } else if (digits.length > 7) {
      formatted = `${digits.slice(0, 3)}-${digits.slice(3, digits.length - 4)}-${digits.slice(-4)}`;
    }
    input.value = formatted;
  });
}

/**
 * "주소검색" 버튼에 다음(카카오) 우편번호 검색 팝업을 연결한다.
 * 검색 완료시 도로명주소를 addressInput에 채우고, detailInput이 있으면 그쪽으로 포커스를 옮긴다.
 */
function attachAddressSearch(buttonEl, addressInput, detailInput) {
  buttonEl.addEventListener('click', () => {
    if (typeof daum === 'undefined' || !daum.Postcode) {
      alert('주소 검색 서비스를 불러오지 못했습니다. 인터넷 연결 상태를 확인해 주세요.');
      return;
    }
    new daum.Postcode({
      oncomplete: function (data) {
        const fullAddress = data.roadAddress || data.jibunAddress;
        addressInput.value = fullAddress;
        addressInput.closest('.field')?.classList.remove('has-error');
        if (detailInput) detailInput.focus();
      }
    }).open();
  });
}

// ============================================================
// 임시저장(초안) — sessionStorage 기반
// localStorage가 아니라 sessionStorage를 쓰는 이유: 브라우저 탭/앱을
// 완전히 닫으면 자동으로 사라진다. 주민등록번호처럼 민감한 값을
// 오래 남겨두지 않으면서도, 화면이 꺼지거나 실수로 뒤로가기를 누른
// 정도로는 데이터를 잃지 않도록 하기 위한 절충이다.
// 전자서명은 저장 대상에서 제외한다 (다시 서명하도록 유도).
// ============================================================

/**
 * 폼 안의 모든 input/select/textarea 값을 스냅샷으로 만든다.
 * (서명 캔버스는 input/select/textarea가 아니므로 자동으로 제외된다)
 */
function snapshotFormDraft(formEl, currentStep) {
  const values = {};
  formEl.querySelectorAll('input, select, textarea').forEach(el => {
    if (el.type === 'checkbox') {
      if (el.id) values[el.id] = el.checked;
    } else if (el.type === 'radio') {
      if (el.name && el.checked) values[el.name] = el.value;
    } else if (el.id) {
      values[el.id] = el.value;
    }
  });
  return { step: currentStep, values, savedAt: Date.now() };
}

/**
 * snapshotFormDraft()로 만든 draft를 폼에 되돌린다.
 */
function restoreFormDraft(formEl, draft) {
  formEl.querySelectorAll('input, select, textarea').forEach(el => {
    if (el.type === 'checkbox') {
      if (el.id && draft.values[el.id] !== undefined) el.checked = draft.values[el.id];
    } else if (el.type === 'radio') {
      if (el.name && draft.values[el.name] === el.value) el.checked = true;
    } else if (el.id && draft.values[el.id] !== undefined) {
      el.value = draft.values[el.id];
    }
  });
}

function saveDraftToSession(key, formEl, currentStep) {
  try { sessionStorage.setItem(key, JSON.stringify(snapshotFormDraft(formEl, currentStep))); }
  catch (e) { /* 저장 실패(용량 초과 등)는 조용히 무시 - 임시저장은 부가기능이라 제출 자체를 막지 않는다 */ }
}

function clearDraftFromSession(key) {
  try { sessionStorage.removeItem(key); } catch (e) { /* 무시 */ }
}

/**
 * 페이지 로드시 이어서 작성할 초안이 있으면 사용자에게 물어보고,
 * 이어서 작성하기로 하면 draft 객체를, 아니면 null을 반환한다(이 경우 초안은 삭제됨).
 */
function loadDraftIfConfirmed(key) {
  let raw;
  try { raw = sessionStorage.getItem(key); } catch (e) { return null; }
  if (!raw) return null;

  try {
    const draft = JSON.parse(raw);
    if (confirm('이전에 작성하시던 내용이 있습니다. 이어서 작성하시겠습니까?')) {
      return draft;
    }
    clearDraftFromSession(key);
    return null;
  } catch (e) {
    clearDraftFromSession(key);
    return null;
  }
}

// ============================================================
// 이탈방지 — 뒤로가기/닫기/새로고침 시 확인창 표시
// ============================================================

/**
 * markDirty()를 호출한 이후부터, markClean()을 호출하기 전까지
 * 페이지를 벗어나려 하면(뒤로가기, 닫기, 새로고침) 브라우저 확인창을 띄운다.
 * 제출 성공 등 "의도된" 이동 직전에는 반드시 markClean()을 호출해야 확인창이 안 뜬다.
 */
function setupUnloadGuard() {
  let dirty = false;
  window.addEventListener('beforeunload', function (e) {
    if (!dirty) return;
    e.preventDefault();
    e.returnValue = ''; // 최신 브라우저는 이 문구 대신 자체 기본 문구를 보여준다
  });
  return {
    markDirty() { dirty = true; },
    markClean() { dirty = false; }
  };
}
