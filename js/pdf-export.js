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
 * 내용이 A4 한 장을 넘으면 자동으로 여러 페이지로 나눠 담는다.
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

  try {
    const canvas = await html2canvas(targetEl, {
      scale: 2,              // 해상도를 2배로 캡처해서 인쇄해도 선명하게
      useCORS: true,
      backgroundColor: '#ffffff'
    });
    const imgData = canvas.toDataURL('image/png');

    const { jsPDF } = window.jspdf;
    const pdf = new jsPDF('p', 'mm', 'a4');
    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    const imgWidth = pageWidth;
    const imgHeight = (canvas.height * imgWidth) / canvas.width;

    let heightLeft = imgHeight;
    let position = 0;

    pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
    heightLeft -= pageHeight;

    // 내용이 A4 한 장보다 길면 다음 페이지로 이어서 담는다
    while (heightLeft > 0) {
      position -= pageHeight;
      pdf.addPage();
      pdf.addImage(imgData, 'PNG', 0, position, imgWidth, imgHeight);
      heightLeft -= pageHeight;
    }

    pdf.save(filename);
  } catch (err) {
    console.error(err);
    alert('PDF 생성 중 문제가 발생했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요.');
  } finally {
    if (buttonEl) { buttonEl.disabled = false; buttonEl.textContent = originalText; }
  }
}
