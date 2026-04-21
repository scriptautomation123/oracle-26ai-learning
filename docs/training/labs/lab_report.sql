-- lab_report.sql

PROMPT ===== Per-module PASS/FAIL/MANUAL counts =====
SELECT module_name,
       SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS pass_count,
       SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS fail_count,
       SUM(CASE WHEN status = 'MANUAL' THEN 1 ELSE 0 END) AS manual_count
FROM lab_results
GROUP BY module_name
ORDER BY module_name;

PROMPT ===== FAIL details =====
SELECT module_name, test_name, detail, created_at
FROM lab_results
WHERE status = 'FAIL'
ORDER BY created_at, module_name, test_name;

PROMPT ===== MANUAL items =====
SELECT module_name, test_name, detail, created_at
FROM lab_results
WHERE status = 'MANUAL'
ORDER BY created_at, module_name, test_name;

PROMPT ===== Overall pass rate =====
SELECT ROUND(
         100 * SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END)
         / NULLIF(SUM(CASE WHEN status IN ('PASS','FAIL') THEN 1 ELSE 0 END), 0),
         2
       ) AS pass_rate_pct
FROM lab_results;

PROMPT ===== Final summary =====
SELECT 'SUMMARY: PASS=' || SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END)
       || ', FAIL=' || SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END)
       || ', MANUAL=' || SUM(CASE WHEN status = 'MANUAL' THEN 1 ELSE 0 END) AS summary
FROM lab_results;
