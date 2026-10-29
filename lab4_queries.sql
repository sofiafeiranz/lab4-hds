-- Lab 4
-- Required queries and validation checks
--
-- Run this file from a regular terminal with:
-- cd /Users/sofia/Desktop/hds-practical/Lab4
-- sqlite3 -header -column cohort.db < lab4_queries.sql
--
-- This file does not modify cohort.db.
-- Task 1 schema exploration and documentation are in README.md.

-- ============================================================================
-- TASK 2: REQUIRED SQL QUERIES AND COMPACT CHECKS
-- ============================================================================

-- MISSING-DATA AUDIT BEFORE THE TASK 2 JOINS
--
-- CASE expressions count missing clinical values. These values remain NULL;
-- they are not dropped and are not replaced with zero. Zero is reserved for a
-- confirmed absence of a qualifying mutation.

SELECT COUNT(*) AS patients_before_task2,
       SUM(CASE WHEN sex IS NULL THEN 1 ELSE 0 END) AS missing_sex,
       SUM(CASE WHEN age_at_diagnosis IS NULL THEN 1 ELSE 0 END)
           AS missing_age,
       SUM(CASE WHEN stage IS NULL THEN 1 ELSE 0 END) AS missing_stage
FROM patients;

--From the 566 patients, 52 are missing sex, 71 are missing age, 54 are missing stage.
-- NULL means the clinical value was not recorded.
-- These NULL values are kept. They are not changed to zero.
-- Sex, age, and stage are not used to remove patients.


-- ============================================================================
-- TASK 2, QUERY 1: PROTEIN-ALTERING MUTATIONS PER PATIENT AND TARGET GENE
-- ============================================================================

-- Required grain: one row per patient per target gene.
-- Expected from Task 1: 566 patients x 5 genes = 2,830 rows.
-- Expected retained patients after every LEFT JOIN: 566.

WITH target_genes(gene_symbol) AS (
    VALUES ('TP53'),
           ('KRAS'),
           ('EGFR'),
           ('STK11'),
           ('KEAP1')
),
after_sample_join AS (
    SELECT p.patient_id,
           s.sample_id
    FROM patients AS p
    LEFT JOIN samples AS s
      ON s.patient_id = p.patient_id
),
after_mutation_join AS (
    SELECT ps.patient_id,
           tg.gene_symbol,
           m.mutation_id
    FROM after_sample_join AS ps
    CROSS JOIN target_genes AS tg
    LEFT JOIN mutations AS m
      ON m.sample_id = ps.sample_id
     AND m.gene_symbol = tg.gene_symbol
     AND m.variant_classification <> 'Silent'
),
patient_gene_counts AS (
    SELECT patient_id,
           gene_symbol,
           COUNT(mutation_id) AS protein_altering_mutation_count
    FROM after_mutation_join
    GROUP BY patient_id,
             gene_symbol
)
SELECT 566 AS expected_patients_from_task1,
       (SELECT COUNT(*) FROM patients) AS actual_patients_before_joins,
       (SELECT COUNT(DISTINCT patient_id) FROM after_sample_join)
           AS patients_after_sample_join,
       (SELECT COUNT(DISTINCT patient_id) FROM after_mutation_join)
           AS patients_after_mutation_join,
       2830 AS expected_patient_gene_rows,
       COUNT(*) AS actual_patient_gene_rows,
       SUM(CASE WHEN protein_altering_mutation_count = 0 THEN 1 ELSE 0 END)
           AS zero_count_patient_gene_rows,
       SUM(CASE WHEN protein_altering_mutation_count > 0 THEN 1 ELSE 0 END)
           AS nonzero_patient_gene_rows,
       SUM(protein_altering_mutation_count) AS total_counted_mutations
FROM patient_gene_counts;

--all 566 patients were preserved after joining the sample and mutation tables.
--There are expected 2,830 patient–gene combinations (566 patients times 5 genes).
--Among these, 2,130 combinations had zero qualifying mutations; 700 had at least one; 746 qualifying mutation records counted in total. 
-- A gene count of zero means no non-Silent mutation was found for that gene.
-- Zero is a real count. It is not a missing value.
-- Missing sex, age, and stage remain NULL because they were not recorded.


-- QUERY 1 LIMITED PREVIEW (10/2830 rows)

WITH target_genes(gene_symbol) AS (
    VALUES ('TP53'),
           ('KRAS'),
           ('EGFR'),
           ('STK11'),
           ('KEAP1')
),
patient_gene_counts AS (
    SELECT p.patient_id,
           tg.gene_symbol,
           COUNT(m.mutation_id) AS protein_altering_mutation_count
    FROM patients AS p
    CROSS JOIN target_genes AS tg
    LEFT JOIN samples AS s
      ON s.patient_id = p.patient_id
    LEFT JOIN mutations AS m
      ON m.sample_id = s.sample_id
     AND m.gene_symbol = tg.gene_symbol
     AND m.variant_classification <> 'Silent'
    GROUP BY p.patient_id,
             tg.gene_symbol
)
SELECT patient_id,
       gene_symbol,
       protein_altering_mutation_count
FROM patient_gene_counts
ORDER BY patient_id,
         gene_symbol
LIMIT 10;


-- QUERY 1 FIVE-ROW CHECK BY GENE
-- ADDITIONAL: This compact check confirms that Silent rows were excluded.

SELECT gene_symbol,
       SUM(CASE WHEN variant_classification <> 'Silent' THEN 1 ELSE 0 END)
           AS counted_protein_altering,
       SUM(CASE WHEN variant_classification = 'Silent' THEN 1 ELSE 0 END)
           AS excluded_silent
FROM mutations
WHERE gene_symbol IN ('TP53', 'KRAS', 'EGFR', 'STK11', 'KEAP1')
GROUP BY gene_symbol
ORDER BY gene_symbol;

-- The results show 746 non-silent mutation records across the five target genes.
-- For example, TP53 having the highest count, 305 mutations.
-- The total of 746 included mutations matches the previous patient–gene-level summary.


-- ============================================================================
-- TASK 2, QUERY 2: PATIENTS PER TISSUE SOURCE SITE AND TUMOR STAGE
-- ============================================================================

-- The patient table stays on the left. This keeps all 566 patients.
-- Missing stage remains NULL and forms a NULL-stage group.
-- Missing sex and age do not affect this query. They are not filtered.

WITH after_sample_join AS (
    SELECT p.patient_id,
           p.stage,
           s.tissue_source_site
    FROM patients AS p
    LEFT JOIN samples AS s
      ON s.patient_id = p.patient_id
),
site_stage_counts AS (
    SELECT tissue_source_site,
           stage,
           COUNT(DISTINCT patient_id) AS n_patients
    FROM after_sample_join
    GROUP BY tissue_source_site, stage
)
SELECT tissue_source_site,
       stage,
       n_patients
FROM site_stage_counts
ORDER BY tissue_source_site, stage;

-- This displayed the summary table.

SELECT COUNT(*) AS expected_group_rows
FROM (
    SELECT DISTINCT
           s.tissue_source_site,
           p.stage
    FROM patients AS p
    LEFT JOIN samples AS s
      ON s.patient_id = p.patient_id
);
-- This printed the number of expected rows would be 142.

WITH site_stage_counts AS (
    SELECT s.tissue_source_site,
           p.stage,
           COUNT(DISTINCT p.patient_id) AS n_patients
    FROM patients AS p
    LEFT JOIN samples AS s
      ON s.patient_id = p.patient_id
    GROUP BY s.tissue_source_site,
             p.stage
)
SELECT COUNT(*) AS total_final_rows
FROM site_stage_counts;
-- The output has 142 rows which matched the expectation.


-- QUERY 2 PATIENT-RETENTION AND MISSING-STAGE AUDIT
-- This compact check shows that no patient was lost.

WITH after_sample_join AS (
    SELECT p.patient_id,
           p.stage,
           s.tissue_source_site
    FROM patients AS p
    LEFT JOIN samples AS s
      ON s.patient_id = p.patient_id
),
site_stage_counts AS (
    SELECT tissue_source_site,
           stage,
           COUNT(DISTINCT patient_id) AS n_patients
    FROM after_sample_join
    GROUP BY tissue_source_site,
             stage
)
SELECT (SELECT COUNT(*) FROM patients) AS patients_before_join,
       (SELECT COUNT(DISTINCT patient_id) FROM after_sample_join)
           AS patients_after_join,
       SUM(n_patients) AS patients_after_grouping,
       SUM(CASE WHEN stage IS NULL THEN n_patients ELSE 0 END)
           AS patients_with_missing_stage
FROM site_stage_counts;

-- Expected results: 566 before, 566 after, and 566 after grouping.
-- The 54 missing stage values remain in the grouped result.


-- QUERY 2 MISSING-STAGE PREVIEW
-- Print only the NULL-stage groups to prove they were retained.

WITH site_stage_counts AS (
    SELECT s.tissue_source_site,
           p.stage,
           COUNT(DISTINCT p.patient_id) AS n_patients
    FROM patients AS p
    LEFT JOIN samples AS s
      ON s.patient_id = p.patient_id
    GROUP BY s.tissue_source_site,
             p.stage
)
SELECT tissue_source_site,
       stage,
       n_patients
FROM site_stage_counts
WHERE stage IS NULL
ORDER BY tissue_source_site
LIMIT 10;

-- These rows are not zeros. Their stage was not recorded.


-- ============================================================================
-- TASK 3: BASE QUERY FOR THE PYTHON FEATURE-TABLE SCRIPT
-- ============================================================================

-- Required grain: one row per patient.
-- Expected and verified rows in the current database: 566.
--
-- ADAPTED FROM WEEK 8:
-- The patient table stays on the left so no patient disappears. The Python
-- script will pivot Task 2 Query 1 to five count columns and left-merge it into
-- this base table. The reshape itself belongs in Python, as required by Lab 4.

-- MISSING-DATA POLICY FOR THE FINAL FEATURE TABLE:
-- Missing sex stays NA because sex was not recorded.
-- Missing age stays NA because age was not recorded.
-- Missing stage stays NA because stage was not recorded.
-- Missing site or TMB would also stay NA.
-- Python fills only the five gene-count columns with zero.
-- A gene zero means no qualifying non-Silent mutation was found.
-- Clinical NA and gene zero have different meanings.

SELECT p.patient_id,
       p.sex,
       p.age_at_diagnosis,
       p.stage,
       s.tissue_source_site,
       s.tmb_nonsynonymous
FROM patients AS p
LEFT JOIN samples AS s
  ON s.patient_id = p.patient_id
ORDER BY p.patient_id;
