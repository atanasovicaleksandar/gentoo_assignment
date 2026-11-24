-- Part 2: write your answers below each task.
-- Use a SQL database of your choice. Each task should be a single query (CTEs are welcome).


-- Task 1: Validate in SQL
-- Return submission_id, is_valid for every row in puzzle_submissions,
-- using the same three rules as Part 1 (plus: exactly 81 characters, digits 1-9 only).


-- Task 2: Deduplicate
-- Keep only the latest submission per (puzzle, source).
-- Return all columns.


-- Task 3: Report
-- Daily invalid rate by source (use the deduplicated data from Task 2),
-- plus a 7-day rolling average of the invalid rate per source.
-- Columns: day, source, submissions, invalid, invalid_rate, invalid_rate_7d


-- Task 4: Explain the failure
-- For each invalid submission, return the first rule it fails, checked in this order:
-- 'format', 'row', 'column', 'block'.
-- Columns: submission_id, failure_reason


-- Task 5: Model it (written answer, no code required)
-- Sketch the tables you would build in a warehouse for this data
-- (e.g. raw -> staging -> mart), and list 3 data quality tests you would add.