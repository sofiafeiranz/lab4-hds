# Lab 4: Database Feature Table

This folder builds a patient-level feature table from the TCGA Lung Adenocarcinoma PanCancer Atlas SQLite database. The final table has one row for each of the 566 patients.

## Folder structure

```text
Lab4/
  README.md
  AI_USAGE.md
  lab4_queries.sql
  feature_table.ipynb
  outputs/
    feature_table.tsv
    data_dictionary.tsv
```

The input database is not included in this folder.

`lab4_queries.sql` contains the Task 2 SQL queries, compact previews, row-count checks, and the base query used for the feature table.

`feature_table.ipynb` uses SQL and Python to build the final wide feature
table and its data dictionary.

`outputs/feature_table.tsv` is the final patient-level feature table.

`outputs/data_dictionary.tsv` explains every column in the feature table.

`AI_USAGE.md` describes where AI was used, how its output was checked, and
which responses needed correction.

## Input database

The database is not included in this folder. Request the data from the author.
After receiving it, save the database in this `Lab4` folder and name it
`cohort.db`.

The database contains de-identified data from the Lung Adenocarcinoma TCGA
PanCancer Atlas study:

<https://www.cbioportal.org/study/summary?id=luad_tcga_pan_can_atlas_2018>

The database contains four tables: `patients`, `samples`, `mutations`, and
`genes`. The SQL file and notebook read this database but do not modify it.

## How to run the SQL

Open a regular terminal and run:

```bash
cd /Users/sofia/Desktop/hds-practical/Lab4
sqlite3 -header -column cohort.db < lab4_queries.sql
```

This prints the Task 2 results and validation checks. The mutation-count table is limited to a 10-row preview. The tissue-source-site and stage query prints the required grouped counts, followed by its row-count and patient-retention checks.

## How to build the feature table

From the same folder, run the notebook with this command:

```bash
cd /Users/sofia/Desktop/hds-practical/Lab4
jupyter nbconvert --to notebook --execute feature_table.ipynb --inplace
```

The notebook expects `cohort.db` to be in the same folder. It connects to the
database with the variable `con`, runs the SQL queries, reshapes the five gene counts with pandas, checks the patient count, and writes both output files.

The notebook can also be opened interactively:

```bash
cd /Users/sofia/Desktop/hds-practical/Lab4
jupyter notebook feature_table.ipynb
```

Then use Run All Cells.

## Expected outputs

Running the notebook creates or replaces these files:

- `outputs/feature_table.tsv`: 566 patient rows and 11 columns.
- `outputs/data_dictionary.tsv`: 11 metadata rows, one for each feature-table
  column.

The feature table contains patient ID, sex, age at diagnosis, stage, tissue
source site, nonsynonymous tumor mutation burden, and mutation-count columns
for TP53, KRAS, EGFR, STK11, and KEAP1.

## Task 1: schema exploration

The following Task 1 material was initially wrote in `lab4_queries.sql`.

```sql
-- ============================================================================
-- TASK 1: EXPLORE AND DOCUMENT THE SCHEMA
-- ============================================================================
.tables
.schema patients
.schema samples
.schema mutations
.schema genes


-- FROM WEEK 8 / ADAPTED TO LAB 4:
-- Read primary keys and foreign keys.

SELECT name AS table_name,
       sql AS create_statement
FROM sqlite_master
WHERE type = 'table'
  AND name NOT LIKE 'sqlite_%'
ORDER BY name;

-- The SQLite database contains four related tables: 
-- patients (patient demographics and clinical information), 
-- samples (sample characteristics), 
-- mutations (genetic mutation records), 
-- and genes (gene annotations).
--Each table has a primary key, while foreign keys establish relationships between tables: 
-- patients connects to samples through patient_id, 
-- samples connects to mutations through sample_id, and mutations connects to genes through gene_symbol.

SELECT COUNT(*) AS n_rows,
       COUNT(DISTINCT patient_id) AS n_distinct_patient_ids
FROM patients;
--566

SELECT COUNT(*) AS n_rows,
       COUNT(DISTINCT sample_id) AS n_distinct_sample_ids
FROM samples;
--566

SELECT COUNT(*) AS n_rows,
       COUNT(DISTINCT mutation_id) AS n_distinct_mutation_ids
FROM mutations;
--200789

SELECT COUNT(*) AS n_rows,
       COUNT(DISTINCT gene_symbol) AS n_distinct_gene_symbols
FROM genes;
--17756

-- For every table, n_rows equal the distinct primary-key count as the commented value.

SELECT * FROM patients LIMIT 3;
-- Contains patient-level demographic and clinical information, 
-- including sex(sex), age at diagnosis(age_at_diagnosis), cancer stage(stage), survival status(vital_status), and follow-up duration(followup_months.).
-- One row represents one unique patient, identified by patient_id.

SELECT * FROM samples LIMIT 3;
-- Contains sample-level information,
-- including tissue source(tissue_source_site), tumor mutational burden(tmb_nonsynonymous),
-- aneuploidy score(aneuploidy_score), and microsatellite instability score(msi_mantis_score).
-- One row represents one unique biological sample, identified by sample_id and linked to patient_id.

SELECT * FROM mutations LIMIT 3;
-- Contains individual genetic mutation records,
-- including affected gene(gene_symbol), mutation classification(variant_classification),
-- variant type(variant_type), protein change(protein_change),
-- genomic location(chromosome, start_pos, end_pos),
-- and sequencing read counts(t_ref_count, t_alt_count).
-- One row represents one recorded genetic mutation in a specific sample, identified by mutation_id.

SELECT * FROM genes LIMIT 3;
-- Contains gene-level annotation information,
-- including gene symbol(gene_symbol), Entrez Gene identifier(entrez_gene_id),
-- and chromosome location(chromosome).
-- One row represents one unique gene, identified by gene_symbol.


SELECT gene_symbol,
       COUNT(*) AS n_mutations
FROM mutations
GROUP BY gene_symbol
ORDER BY n_mutations DESC
LIMIT 10;
-- one gene can be linked to many mutation rows.
-- For example, TTN is linked to 862 mutations.


SELECT COUNT(*) AS samples_without_matching_patient
FROM samples AS s
LEFT JOIN patients AS p
  ON p.patient_id = s.patient_id
WHERE p.patient_id IS NULL;

SELECT COUNT(*) AS mutations_without_matching_sample
FROM mutations AS m
LEFT JOIN samples AS s
  ON s.sample_id = m.sample_id
WHERE s.sample_id IS NULL;

SELECT COUNT(*) AS mutations_without_matching_gene
FROM mutations AS m
LEFT JOIN genes AS g
  ON g.gene_symbol = m.gene_symbol
WHERE g.gene_symbol IS NULL;

-- Checked if foreign-key values have matching parent rows. Each result is zero.
```

## Task 2 checks

For the patient-gene mutation query, the expected grain is one row per patient per target gene. With 566 patients and 5 genes, the expected count is 2,830 rows. The query returns 2,830 rows and retains all 566 patients. It counts 746 non-Silent mutation records across the five genes.

For the tissue-source-site and stage query, the expected and actual grouped
row counts are both 142. The patient-retention check shows 566 patients before the sample join, 566 after the join, and 566 represented after grouping.

## Missing data

The patient table contains 52 missing sex values, 71 missing age values, and
54 missing stage values. These values stay as `NA` because the information was not recorded.

The five gene-count columns use zero when no qualifying non-Silent mutation
was found. Zero is a real count and does not mean the same thing as a missing clinical value.
