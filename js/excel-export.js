// ============================================================
// 엑셀 다운로드 (SheetJS)
// 사용 전 HTML에서 아래 로드 필요:
//   <script src="https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js"></script>
// ============================================================

/**
 * 세목별 항목 배열(jsonb)의 "계" 합계를 구한다.
 */
function sumRefundItems(items) {
  if (!items || !Array.isArray(items)) return 0;
  return items.reduce((sum, it) => sum + (Number(it.total) || 0), 0);
}

/**
 * 접수 목록(submissions + 서식별 상세)을 엑셀 파일로 다운로드
 * FORM A/B/C가 섞여 있어도 한 시트에서 고정된 컬럼셋으로 출력한다.
 * (SheetJS는 배열의 키 구성이 행마다 다르면 컬럼이 누락될 수 있어
 *  모든 행에 동일한 컬럼셋을 명시적으로 채워 넣는다.)
 *
 * @param {Array} rows - listSubmissions()가 반환한 배열
 * @param {string} filename
 */
function exportSubmissionsToExcel(rows, filename) {
  if (!rows || rows.length === 0) {
    alert('내려받을 데이터가 없습니다.');
    return;
  }

  const excelRows = rows.map(row => {
    const b = (row.form_b_joint_home && row.form_b_joint_home[0]) || null;
    const a = (row.form_a_transfer && row.form_a_transfer[0]) || null;
    const c = (row.form_c_offset && row.form_c_offset[0]) || null;
    const formType = b ? '공동명의 1주택자 특례신청서' : (a ? '국세환급금양도요구서' : (c ? '국세환급금 충당청구동의서' : '-'));

    return {
      '접수번호': row.reception_number,
      '서식종류': formType,
      '제출일시': new Date(row.created_at).toLocaleString('ko-KR'),
      '처리상태': row.status,
      '담당자': row.staff_name || '',

      // --- FORM B(공동명의 1주택자 특례신청서) ---
      'B_신청유형': b ? (b.request_type || '') : '',
      'B_신청인': b ? (b.applicant_name || '') : '',
      'B_신청인_주민등록번호': b ? (b.applicant_rrn || '') : '',
      'B_신청인_주소': b ? (b.applicant_address || '') : '',
      'B_신청인_전화번호': b ? (b.applicant_phone || '') : '',
      'B_납세의무자': b ? (b.taxpayer_name || '') : '',
      'B_납세의무자_주민등록번호': b ? (b.taxpayer_rrn || '') : '',
      'B_배우자': b ? (b.spouse_name || '') : '',
      'B_배우자_주민등록번호': b ? (b.spouse_rrn || '') : '',
      'B_점검1_지분율조건': b ? (b.check_ownership_ratio ? 'O' : 'X') : '',
      'B_점검2_배우자타주택없음': b ? (b.check_spouse_no_other_house ? 'O' : 'X') : '',
      'B_점검3_세대원타주택없음': b ? (b.check_household_no_other_house ? 'O' : 'X') : '',
      'B_국세청안내결과': b ? (b.nts_notice_result || '') : '',
      'B_배우자동의확인': b ? (b.consent_confirmed ? 'O' : 'X') : '',

      // --- FORM A(국세환급금양도요구서) ---
      'A_양도인': a ? (a.transferor_name || '') : '',
      'A_양도인_주민등록번호': a ? (a.transferor_rrn || '') : '',
      'A_양도인_사업자등록번호': a ? (a.transferor_biz_no || '') : '',
      'A_양도인_주소': a ? (a.transferor_address || '') : '',
      'A_양도인_전화번호': a ? (a.transferor_phone || '') : '',
      'A_양수인': a ? (a.transferee_name || '') : '',
      'A_양수인_주민등록번호': a ? (a.transferee_rrn || '') : '',
      'A_양수인_사업자등록번호': a ? (a.transferee_biz_no || '') : '',
      'A_양수인_주소': a ? (a.transferee_address || '') : '',
      'A_양수인_전화번호': a ? (a.transferee_phone || '') : '',
      'A_국세환급금_합계': a ? sumRefundItems(a.refund_items) : '',
      'A_양도금액_합계': a ? sumRefundItems(a.transfer_amount_items) : '',

      // --- FORM C(국세환급금 충당청구(동의)서) ---
      'C_청구인': c ? (c.claimant_name || '') : '',
      'C_청구인_주민등록번호': c ? (c.claimant_rrn || '') : '',
      'C_청구인_사업자등록번호': c ? (c.claimant_biz_no || '') : '',
      'C_청구인_주소': c ? (c.claimant_address || '') : '',
      'C_청구인_전화번호': c ? (c.claimant_phone || '') : '',
      'C_국세환급금_합계': c ? sumRefundItems(c.refund_items) : '',
      'C_충당청구_합계': c ? sumRefundItems(c.offset_items) : '',
      'C_잔액': c ? (c.balance ?? '') : '',
      'C_대리인': c ? (c.agent_name || '') : ''
    };
  });

  const worksheet = XLSX.utils.json_to_sheet(excelRows);
  worksheet['!cols'] = Object.keys(excelRows[0]).map(() => ({ wch: 16 }));

  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, '동의서목록');

  const finalName = filename || `국세환급금동의서_${new Date().toISOString().slice(0,10)}.xlsx`;
  XLSX.writeFile(workbook, finalName);
}
