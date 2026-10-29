# AI Usage

## Scope of AI assistance

Task 1 was handwritten. I explored the schema in the SQLite terminal, checked
the output manually, and wrote the schema description myself.

Starting with Task 2, I used OpenAI Codex/ChatGPT to help draft and revise SQL and Python code. I ran the queries myself, compared the expected and actual row counts, reviewed limited previews, and asked for corrections when
the output did not meet the task requirements.

## Task 2, Query 1: mutations per patient and gene

My first prompt was a simple request to work on Task 2:

> Write SQL queries to:
>
> - For each patient and each of these five genes (TP53, KRAS, EGFR, STK11,
>   KEAP1), count the protein-altering mutations (exclude Silent).
> - Count patients per tissue source site per tumor stage.

ChatGPT originally produced this query for the first part:

```sql
WITH target_genes(gene_symbol) AS (
    VALUES ('TP53'),
           ('KRAS'),
           ('EGFR'),
           ('STK11'),
           ('KEAP1')
)
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
ORDER BY p.patient_id,
         tg.gene_symbol;
```

The query used the correct grain, but it printed the complete table of 566
patients multiplied by 5 genes, or 2,830 rows. This was too much terminal
output to review easily.

I then rewrote my prompt more carefully and combined the Task 2 and Task 4
requirements:

> Make sure only important summary numbers are printed. If a table is printed,
> limit it to several rows. Record the row count expected from Task 1 so I can
> compare it with the result when I run the code. Be careful with missing sex,
> age, and stage values, and with patients who have no mutation in a gene. Use
> a left join to keep patients, show the patient count before and after joins,
> and explain why a gene count of zero is different from a missing value.

The revised version kept the full result inside common table expressions and
printed a compact audit plus a 10-row preview. I manually checked these final
results:

- Expected and actual patients: 566.
- Expected and actual patient-gene rows: 2,830.
- Patient-gene rows with a zero count: 2,130.
- Patient-gene rows with one or more qualifying mutations: 700.
- Total non-Silent mutation records counted across the five genes: 746.

The code also printed a five-row gene-level check that compared counted
non-Silent mutations with excluded `Silent` mutations. This confirmed that the filter was applied.

For study purpose, I also asked ChatGPT to distinguish from its code and class materials. Here is the output:

The following parts were adapted from Week 8:

- The patient table stays on the left side of each `LEFT JOIN`.
- Filters on the optional `mutations` table are placed in the `ON` clause, not
  the `WHERE` clause.
- `COUNT(m.mutation_id)` counts matching mutation rows and returns zero when no
  qualifying mutation row exists.
- Expected and actual row counts are compared before interpreting the result.

The following parts were additional suggestions from ChatGPT and were not
shown directly in the Week 8 notes:

- The `target_genes` common table expression.
- `CROSS JOIN` to create exactly five gene rows for every patient before
  mutations are joined.
- Common table expressions and `CASE` expressions used for compact audit
  summaries.

## Task 2, Query 2: patients per tissue source site and stage

The first AI response for Query 2 ended with validation statistics only. It
did not print the required grouped counts. I identified this problem and sent
the following correction:

> I don't think the output counts patients per tissue source site per tumor
> stage. Fix it.

ChatGPT then separated the required grouped table from the validation query.
The final grouped query in `lab4_queries.sql` is:

```sql
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
SELECT tissue_source_site,
       stage,
       n_patients
FROM site_stage_counts
ORDER BY tissue_source_site,
         stage;
```

The audit-only query was retained as a separate check instead of being used as
a replacement for the required table. I manually checked the following final
results:

- Expected grouped rows: 142.
- Actual grouped rows: 142.
- Patients before the sample join: 566.
- Distinct patients after the sample join: 566.
- Patients represented after grouping: 566.
- Patients with missing stage retained in the grouped result: 54.

Missing stage values remain `NULL` and form `NULL`-stage groups. They are not
changed to zero. Missing sex and age do not affect this query because neither
column is used as a filter.

## Tasks 3 and 4: feature-table notebook

I used ChatGPT to help build the Jupyter notebook. The AI helped write the SQL
and Python code that:

1. Connects to `cohort.db` with the variable `con`.
2. Queries patient and sample features with SQL.
3. Queries the five-gene mutation counts in long format with SQL.
4. Uses pandas to reshape the gene counts into wide format.
5. Left-merges the wide counts into the patient feature table.
6. Keeps missing clinical values as `NA`.
7. Fills only the five gene-count columns with zero.
8. Saves the final table as `outputs/feature_table.tsv`.

The SQL join logic was adapted from Week 8. The pandas `pivot`, one-to-one
merge validation, assertions, and TSV export were additional Python steps
suggested by ChatGPT because the assignment required Python or R for the wide
reshape.

I checked the notebook output manually and kept explicit programmatic checks:

- The patient feature query returns 566 rows and 566 unique patients.
- The long mutation-count query returns 2,830 rows.
- The wide gene-count table returns 566 rows.
- The final table has 566 rows before and after the merge.
- `patient_id` is unique in the final table.
- Missing clinical values remain visible: 52 missing sex values, 71 missing
  ages, and 54 missing stages.
- Tissue source site and tumor mutation burden have no missing values in this
  database.

The notebook explains that a clinical `NA` means the value was not recorded.
A gene count of `0` means that no qualifying non-Silent mutation was found.
These meanings are different, so only gene-count columns are filled with zero.

## Task 5: study information and data dictionary

I asked ChatGPT to read the official cBioPortal study page:

<https://www.cbioportal.org/study/summary?id=luad_tcga_pan_can_atlas_2018>

ChatGPT used that study context to revise the short descriptions
in the data dictionary.

ChatGPT also helped create the data dictionary in Python, and I used agentic codex to check that the dictionary column names exactly match the feature-table columns and saves it as `outputs/data_dictionary.tsv`.

The cBioPortal page supplied the study context only. The decision to exclude
`Silent` variants and the distinction between gene-count zero and clinical
`NA` came from the assignment requirements and the SQL analysis, not from the
study-page description.


The original work did not preserve an SQLite error log. To document one
concrete and reproducible troubleshooting case, I checked what happens when a
SQLite terminal command is sent through the Python connection. Running
`.tables` through `con.execute()` produced this actual error:

```text
sqlite3.OperationalError: near ".": syntax error
```

The troubleshooting prompt is:

> I ran `.tables` through Python's sqlite3 connection and received
> `sqlite3.OperationalError: near ".": syntax error`. Why does this happen,
> and how should I list the tables in the notebook?

ChatGPT explained that `.tables` is a command understood by the interactive
`sqlite3` terminal. It is not SQL, so Python's `sqlite3` connection and
`pandas.read_sql()` cannot execute it. The terminal version remains appropriate
in `lab4_queries.sql`. In the notebook, the AI replaced it with a real SQL
query against SQLite's schema table:

```python
q("SELECT name FROM sqlite_master WHERE type='table'")
```


## Final review

AI was most useful for drafting the repeated join logic, adding compact audit
queries, reshaping the long mutation counts, and documenting missing data. It
also produced two outputs that required correction: Query 1 printed too many
rows, and the first version of Query 2 printed only an audit rather than the
required grouped table. I identified both issues, revised my prompts, reran the code, and kept the corrected versions only.
