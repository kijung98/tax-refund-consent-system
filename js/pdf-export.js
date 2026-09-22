// ============================================================
// PDF 다운로드 (html2canvas + jsPDF)
//
// 화면에 이미 정상적으로 그려진 내용을 이미지로 캡처해서 PDF에 붙이는 방식이다.
// jsPDF의 텍스트 방식으로 직접 PDF를 만들면 한글 폰트를 별도로 변환해서
// 심어야 해서 복잡하고 깨질 위험이 있는데, 이 방식은 브라우저가 이미 잘
// 그려놓은 한글을 그대로 이미지로 담기 때문에 폰트 문제가 없다.
//
// 사용 전 HTML에서 아래 순서로 로드해야 합니다:
//   <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
//   <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
//   <script src="../js/pdf-export.js"></script>
// ============================================================

/**
 * 지정한 요소를 A4 규격 PDF로 캡처해서 다운로드한다.
 *
 * ⚠️ 캡처 전에 아래 요소들은 잠깐 숨겨서 종이(PDF)에 포함되지 않도록 처리:
 *   - .print-system-footer : 접수번호·처리상태·시스템 출력일시 (화면 확인용)
 *   - .no-print            : 인쇄 툴바 등 화면 전용 UI
 * 이렇게 하지 않으면 화면에 보이는 참고용 문구가 세로 길이를 A4보다
 * 살짝 넘게 만들어서 PDF가 2페이지로 저장되는 문제가 생긴다.
 *
 * @param {HTMLElement} targetEl - 캡처할 요소 (보통 .print-page 컨테이너)
 * @param {string} filename - 저장할 파일명 (.pdf 확장자 포함)
 * @param {HTMLButtonElement} [buttonEl] - 클릭한 버튼(있으면 생성 중 비활성화 처리)
 */
async function downloadElementAsPdf(targetEl, filename, buttonEl) {
  if (typeof html2canvas === 'undefined' || typeof window.jspdf === 'undefined') {
    alert('PDF 생성 기능을 불러오지 못했습니다. 인터넷 연결을 확인하고 새로고침해 주세요.');
    return;
  }

  const originalText = buttonEl ? buttonEl.textContent : null;
  if (buttonEl) { buttonEl.disabled = true; buttonEl.textContent = 'PDF 생성 중...'; }

  // 캡처 전에 종이에 안 들어갈 요소들을 임시로 숨긴다.
  // (문서 전체에서 검색해야 targetEl 밖에 있는 툴바까지 잡을 수 있음)
  const toHide = document.querySelectorAll('.print-system-footer, .no-print');
  const hidden = [];
  toHide.forEach(el => {
    hidden.push({ el, prevDisplay: el.style.display });
    el.style.display = 'none';
  });

  try {
    // 숨김이 실제 레이아웃에 반영될 시간을 한 프레임 준다 (안전장치)
    await new Promise(resolve => requestAnimationFrame(resolve));

    const canvas = await html2canvas(targetEl, {
      scale: 2,              // 해상도를 2배로 캡처해서 인쇄해도 선명하게
      useCORS: true,
      backgroundColor: '#ffffff'
    });
    const imgData = canvas.toDataURL('image/png');

    const { jsPDF } = window.jspdf;
    const pdf = new jsPDF('p', 'mm', 'a4');
    const pageWidth = pdf.internal.pageSize.getWidth();   // 210
    const pageHeight = pdf.internal.pageSize.getHeight(); // 297
    const imgWidth = pageWidth;
    const imgHeight = (canvas.height * imgWidth) / canvas.width;

    // 내용이 A4 한 장에 거의 딱 맞는 경우 (약간 넘어도 몇 mm 이내면)
    // 자동으로 살짝 축소해서 한 장에 담는다.
    // 이렇게 하면 소수점 오차로 인한 "2페이지째가 완전 빈 페이지" 문제 방지.
    const TOLERANCE_MM = 15;

    if (imgHeight <= pageHeight + TOLERANCE_MM) {
      // 한 장에 담기 - 내용이 A4보다 살짝 크면 A4 높이에 맞춰 축소
      const finalHeight = Math.min(imgHeight, pageHeight);
      const finalWidth = (canvas.width * finalHeight) / canvas.height;
      const xOffset = (pageWidth - finalWidth) / 2;
      pdf.addImage(imgData, 'PNG', xOffset, 0, finalWidth, finalHeight);
    } else {
      // 진짜 A4를 훨씬 넘어가는 경우만 다중 페이지로 분할
      let heightLeft = imgHeight;
      let position = 0;

      pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
      heightLeft -= pageHeight;

      while (heightLeft > TOLERANCE_MM) {
        position -= pageHeight;
        pdf.addPage();
        pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
        heightLeft -= pageHeight;
      }
    }

    pdf.save(filename);
  } catch (err) {
    console.error(err);
    alert('PDF 생성 중 문제가 발생했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.');
  } finally {
    // 숨겼던 요소들 원래대로 복원 (성공/실패 상관없이 반드시 실행)
    hidden.forEach(({ el, prevDisplay }) => { el.style.display = prevDisplay; });
    if (buttonEl) { buttonEl.disabled = false; buttonEl.textContent = originalText; }
  }
}
