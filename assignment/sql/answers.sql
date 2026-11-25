

-- QUERY TRUNCATED
-- Part 2: write your answers below each task.
-- Use a SQL database of your choice. Each task should be a single query (CTEs are welcome).

-- The first issue I found (before we start the test)
-- The way the data is inserted leaves a lot of room for errors
-- Firstly I rewrote the initial ingestion sql syntax so it reflects postgres db I use (not an error, but something to point out I know you use Snowflake and it works)
-- Secondly, due to cleaner approach I decided to use DROP TABLE IF EXISTS first then doing CREATE TABLE so we can start with a clean dataset
-- After that, there is one really important thing to keep in mind. submission_id should be treated as a primary key
-- 
-- submission_id INTEGER PRIMARY KEY
-- THat way each submission is unique, which is a way of validating an id as such...
-- This might not be the best approach but I did decide on that. Since by keeping this as primary key we do drop duplicate records that we'll not see in the model...
-- We will not be implementing 81 character constraint so we can test invalid inputs...


-- Task 1: Validate in SQL
-- Return submission_id, is_valid for every row in puzzle_submissions,
-- using the same three rules as Part 1 (plus: exactly 81 characters, digits 1-9 only).

WITH base AS (
    SELECT
        submission_id,
        puzzle,
        COALESCE(
  -- This is where we draw the logic. We check for lenght, then we do regular expression. First part checks for numbers from 1 to 9, second for a lenght.
  -- Technically, we can do with only LENGHT but this is safer to be honest.
  -- We use COALESCE to eliminate NULL values because the statement itself would return NULL not False if it checked lenght and got NULL...
            LENGTH(puzzle) = 81
            AND puzzle ~ '^[1-9]{81}$',
            FALSE
        ) AS format_ok
    FROM puzzle_submissions
),

cells AS (
    SELECT
        b.submission_id,
  -- This calculates the row number as in 0-8 is 0, 9-17 is 1, 18-26 is 2 etc.
  -- every sudoku row contains 9 positions, so dividing by 9 using integer division tells us which row it belongs to...
        gs.pos / 9 AS row_no,
  -- This is modulus operator (%) that returns the remainder of a division. We can use % rather than MOD() because Postrgres supports this syntax.
  -- This returns a column number as it takes position and divides it by 9. So 1 % 9 will return 1, 10 % 9 will return 1...
        gs.pos % 9 AS col_no,
  -- This is where we get to the most important part where the block sits.
  -- We are trying to enumerate it so it goes, 0, 1, 2 as a first row. 3, 4, 5 as a second. 6, 7, 8 as third...
  -- We divide both row position (first part of the equation) and the column postion (second part) by three so we break it into segments.
  -- We multiply row position by 3
  -- When we add these numbers together we get position of the block.
  -- This is quite a substantial part and the most difficult one to be honest...
        ((gs.pos / 9) / 3) * 3
            + ((gs.pos % 9) / 3) AS block_no,
  -- This extracts each position of a string (so, if the string is 974236158 pos is 1 it returns 9, then plus 1 it returns 7 etc...)
        SUBSTRING(b.puzzle, gs.pos + 1, 1) AS digit
    FROM base b
    CROSS JOIN generate_series(0, 80) AS gs(pos)
  -- This removes invalid formats. We built this CTE before.
    WHERE b.format_ok
),

unit_checks AS (
    -- Check rows
    SELECT
        submission_id,
  -- We check if number of unique digits is 9.
        COUNT(DISTINCT digit) = 9 AS unit_ok
    FROM cells
  -- This is just a simple group by, for submission_id and row number...
    GROUP BY submission_id, row_no
-- We perform union all to merge all of these tests together, without trying to remove duplicate rows.
    UNION ALL

    -- Check columns
    -- Same logic as the first, only for columns...
    SELECT
        submission_id,
        COUNT(DISTINCT digit) = 9 AS unit_ok
    FROM cells
    GROUP BY submission_id, col_no

    UNION ALL

    -- Check 3x3 blocks
    SELECT
        submission_id,
        COUNT(DISTINCT digit) = 9 AS unit_ok
    FROM cells
    GROUP BY submission_id, block_no
),

  -- This is where we validate everything
validation AS (
    SELECT
        submission_id,
  -- BOOL_AND() is a PostgreSQL aggregate function...
  -- It only returns True if all 27 rows checks pass...
        BOOL_AND(unit_ok) AS sudoku_ok
    FROM unit_checks
  -- Since we want one result per puzzle, we are grouping them by submission_id, otherwise we would have 27 rows per submission...
    GROUP BY submission_id
)
-- Here we join everything together...
SELECT
    b.submission_id,
    (
        b.format_ok
  -- This is here because we don't want NULL to be treated as a valid result...
        AND COALESCE(v.sudoku_ok, FALSE)
    ) AS is_valid
  -- We use left join because base table has all submission, including malformed puzzles...
FROM base b
  -- Contains only submissions with valid formats that were checked for Sudoku rules...
  -- Why results have NULL? Some submissions neer entered table cells, so there are no matching recorts in validation table...
LEFT JOIN validation v
    ON b.submission_id = v.submission_id
ORDER BY b.submission_id;


-- Task 2: Deduplicate
-- Keep only the latest submission per (puzzle, source).
-- Return all columns.

-- This is simple enough. You just use ROW_NUMBER for deduplication. If you have more than 1 record by puzzle and source, it's a duplicate.
-- You filter out in the second query table. WHERE rn = 1
-- Why not RANK or DENSE RANK? Because they don't provide the same results and are not good for deduplication.
-- They tend to return multiple rows when ordering numbers are tie...
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY puzzle, source
            ORDER BY submitted_at DESC, submission_id DESC
        ) AS rn
    FROM puzzle_submissions
)

SELECT
    submission_id,
    source,
    puzzle,
    submitted_at
FROM ranked
WHERE rn = 1
ORDER BY submission_id;

-- Task 3: Report
-- Daily invalid rate by source (use the deduplicated data from Task 2),
-- plus a 7-day rolling average of the invalid rate per source.
-- Columns: day, source, submissions, invalid, invalid_rate, invalid_rate_7d



WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY puzzle, source
            ORDER BY submitted_at DESC, submission_id DESC
        ) AS rn
    FROM puzzle_submissions
),

deduplicated AS (
    SELECT *
    FROM ranked
    WHERE rn = 1
),

base AS (
    SELECT
        *,
        COALESCE(
            LENGTH(puzzle) = 81
            AND puzzle ~ '^[1-9]{81}$',
            FALSE
        ) AS format_ok
    FROM deduplicated
),

cells AS (
    SELECT
        b.submission_id,
        gs.pos / 9 AS row_no,
        gs.pos % 9 AS col_no,
        ((gs.pos / 9) / 3) * 3
            + ((gs.pos % 9) / 3) AS block_no,
        SUBSTRING(b.puzzle, gs.pos + 1, 1) AS digit
    FROM base b
    CROSS JOIN generate_series(0, 80) AS gs(pos)
    WHERE b.format_ok
),

unit_checks AS (
    SELECT submission_id,
           COUNT(DISTINCT digit) = 9 AS unit_ok
    FROM cells
    GROUP BY submission_id, row_no

    UNION ALL

    SELECT submission_id,
           COUNT(DISTINCT digit) = 9 AS unit_ok
    FROM cells
    GROUP BY submission_id, col_no

    UNION ALL

    SELECT submission_id,
           COUNT(DISTINCT digit) = 9 AS unit_ok
    FROM cells
    GROUP BY submission_id, block_no
),

validation AS (
    SELECT
        submission_id,
        BOOL_AND(unit_ok) AS sudoku_ok
    FROM unit_checks
    GROUP BY submission_id
),


  -- Here we start with the third task specifically...
  -- I will skip first two queries as we already covered them...
classified AS (
    SELECT
        b.submission_id,
        b.source,
  -- We simply format submitted_at as date and not datetime so we can use it to actually calculate the rolling average.
        b.submitted_at::date AS day,
        (
            b.format_ok
            AND COALESCE(v.sudoku_ok, FALSE)
        ) AS is_valid
    FROM base b
    LEFT JOIN validation v
        ON b.submission_id = v.submission_id
),

daily AS (
    SELECT
        day,
        source,
  -- We count number of submssions overall...
        COUNT(*) AS submissions,
  -- We count number of submissions that are invalid by using WHERE NOT is_valid...
  -- We use filter statement for well, filtering...
  -- I know FILTER is not really present in every db, and that in Snowflake this was added recently...
        COUNT(*) FILTER (
            WHERE NOT is_valid
        ) AS invalid
    FROM classified
  -- We convert timestamp to date so submissions are aggregated by a calendar day...
    GROUP BY day, source
),

  -- We use this CTE specifically to help us calculate moving average...
source_bounds AS (
    SELECT
        source,
  -- We want to know the first and last submission date...
        MIN(day) AS min_day,
        MAX(day) AS max_day
    FROM daily
    GROUP BY source
),

calendar AS (
    SELECT
        sb.source,
        gs.day::date AS day
    FROM source_bounds sb
  -- Here we generate (something we used already previously) each calendar date...
  -- We cross join so we have every day present in the table...
    CROSS JOIN LATERAL generate_series(
        sb.min_day::timestamp,
        sb.max_day::timestamp,
        INTERVAL '1 day'
    ) AS gs(day)
),

daily_filled AS (
    SELECT
        c.day,
        c.source,
        COALESCE(d.submissions, 0) AS submissions,
        COALESCE(d.invalid, 0) AS invalid,
        d.invalid::numeric
            / NULLIF(d.submissions, 0) AS invalid_rate
    FROM calendar c
    LEFT JOIN daily d
        ON d.day = c.day
        AND d.source = c.source
)

SELECT
    day,
    source,
    submissions,
    invalid,
  -- I rounded the numbers just for clarity.
    ROUND(invalid_rate,2) as invalid_rate,
  -- We calculate the rolling average using window function.
    ROUND(AVG(invalid_rate) OVER (
        PARTITION BY source
        ORDER BY day
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ),2) AS invalid_rate_7d
FROM daily_filled
ORDER BY day, source;


-- Task 4: Explain the failure
-- For each invalid submission, return the first rule it fails, checked in this order:
-- 'format', 'row', 'column', 'block'.
-- Columns: submission_id, failure_reason

WITH base AS (
    SELECT
        submission_id,
        puzzle,
        COALESCE(
            LENGTH(puzzle) = 81
            AND puzzle ~ '^[1-9]{81}$',
            FALSE
        ) AS format_ok
    FROM puzzle_submissions
),

cells AS (
    SELECT
        b.submission_id,
        gs.pos / 9 AS row_no,
        gs.pos % 9 AS col_no,
        ((gs.pos / 9) / 3) * 3
            + ((gs.pos % 9) / 3) AS block_no,
        SUBSTRING(b.puzzle, gs.pos + 1, 1) AS digit
    FROM base b
    CROSS JOIN generate_series(0, 80) AS gs(pos)
    WHERE b.format_ok
),

-- We put together CTEs for each type of failure.
-- That way we can join them together and use CASE statement to poin to a specific type of failure

row_failures AS (
    SELECT DISTINCT submission_id
    FROM (
        SELECT
            submission_id,
            row_no
        FROM cells
        GROUP BY submission_id, row_no
        HAVING COUNT(DISTINCT digit) <> 9
    ) r
),

column_failures AS (
    SELECT DISTINCT submission_id
    FROM (
        SELECT
            submission_id,
            col_no
        FROM cells
        GROUP BY submission_id, col_no
        HAVING COUNT(DISTINCT digit) <> 9
    ) c
),

block_failures AS (
    SELECT DISTINCT submission_id
    FROM (
        SELECT
            submission_id,
            block_no
        FROM cells
        GROUP BY submission_id, block_no
        HAVING COUNT(DISTINCT digit) <> 9
    ) b
)

SELECT
    b.submission_id,

    CASE
        WHEN NOT b.format_ok THEN 'format'
        WHEN r.submission_id IS NOT NULL THEN 'row'
        WHEN c.submission_id IS NOT NULL THEN 'column'
        WHEN bl.submission_id IS NOT NULL THEN 'block'
    END AS failure_reason

FROM base b

LEFT JOIN row_failures r
    ON b.submission_id = r.submission_id

LEFT JOIN column_failures c
    ON b.submission_id = c.submission_id

LEFT JOIN block_failures bl
    ON b.submission_id = bl.submission_id

WHERE
    NOT b.format_ok
    OR r.submission_id IS NOT NULL
    OR c.submission_id IS NOT NULL
    OR bl.submission_id IS NOT NULL

ORDER BY b.submission_id;


-- Task 5: Model it (written answer, no code required)
-- Sketch the tables you would build in a warehouse for this data
-- (e.g. raw -> staging -> mart), and list 3 data quality tests you would add.

-- First is the raw layer - r_puzzle_submission
-- I think that already on ingestion we would need to add primary key as such for a submission_id as I already mentioned.
-- This table always stays the same as it's the source.

-- Second is the staging layer - stg_puzzle_submission

-- Here clean and standardize the data.
-- We add validatin columns: is_duplicate, format_ok, sudoku_ok, is_valid and they should be boolean type.

-- Mart layer - mart_daily_submission_quality or prsn_daily_submission_quality (as it is for presentation purposes)

-- This is aggregated data used for reporting and analysis.

-- As we established in previous tasks the columns are as such
-- This table is now ready for analysis

-- I would use materialized view and some orchestration tool to handle the model since views tend to slow done queries...
-- Indexing is not necessary if we're working with a data warehouse and is not even possible, that is something to keep in mind.
-- When using something like postgres it's good to index on primary key, join columns, anything with unique values pretty much...
