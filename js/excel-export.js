// ============================================================
// 엑셀 다운로드 (SheetJS)
// 사용 전 HTML에서 아래 로드 필요:
//   <script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
// ============================================================

/**
 * 접수 목록(submissions + form_b_joint_home)을 엑셀 파일로 다운로드
 * @param {Array} rows - listSubmissions()가 반환한 배열
 * @param {string} filename
 */
function exportSubmissionsToExcel(rows, filename) {
  if (!rows || rows.length === 0) {
    alert('내려받을 데이터가 없습니다.');
    return;
  }

  const excelRows = rows.map(row => {
    const f = (row.form_b_joint_home && row.form_b_joint_home[0]) || {};
    return {
      '접수번호': row.reception_number,
      '제출일시': new Date(row.created_at).toLocaleString('ko-KR'),
      '처리상태': row.status,
      '신청유형': f.request_type || '',
      '신청인': f.applicant_name || '',
      '신청인_주민등록번호': f.applicant_rrn || '',
      '신청인_주소': f.applicant_address || '',
      '신청인_전화번호': f.applicant_phone || '',
      '납세의무자': f.taxpayer_name || '',
      '납세의무자_주민등록번호': f.taxpayer_rrn || '',
      '배우자': f.spouse_name || '',
      '배우자_주민등록번호': f.spouse_rrn || '',
      '점검1_지분율조건': f.check_ownership_ratio ? 'O' : 'X',
      '점검2_배우자타주택없음': f.check_spouse_no_other_house ? 'O' : 'X',
      '점검3_세대원타주택없음': f.check_household_no_other_house ? 'O' : 'X',
      '국세청안내결과': f.nts_notice_result || '',
      '배우자동의확인': f.consent_confirmed ? 'O' : 'X',
      '담당자': row.staff_name || ''
    };
  });

  const worksheet = XLSX.utils.json_to_sheet(excelRows);
  worksheet['!cols'] = Object.keys(excelRows[0]).map(() => ({ wch: 18 }));

  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, '동의서목록');

  const finalName = filename || `국세환급금동의서_${new Date().toISOString().slice(0,10)}.xlsx`;
  XLSX.writeFile(workbook, finalName);
}
