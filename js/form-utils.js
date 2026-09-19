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
