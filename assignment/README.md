# Data Engineer Coding Challenge

Expected time: about 3 hours in total. You don't need to finish everything.
We value clear, correct, readable work over completeness.

## Part 1: Python (about 1 hour)

Implement `validate()` in `challenge.py`. The rules are in the docstring.
All tests in `test_challenge.py` should pass. Don't change the tests.

## Part 2: SQL (about 2 hours)

Load the data into a SQL database of your choice.:
Write your answers in `sql/answers.sql`. There are five tasks:

1. **Validate:** check each submission in SQL using the same rules as Part 1.
2. **Deduplicate:** keep only the latest submission per puzzle and source.
3. **Report:** the daily invalid rate per source, with a 7-day rolling average.
4. **Explain:** the first rule each invalid submission fails.
5. **Model it:** a short written answer on the table design and data quality tests.

## Submitting

Send back the whole folder (zip or Git repo) with your `challenge.py` and `sql/answers.sql`.
Git history is welcome but not required.

## Follow-up interview

We'll discuss your solution and how you'd take it further, for example:

- Puzzles arrive as files in cloud storage every hour. How would you design the pipeline?
- How would you make it idempotent if the same batch arrives twice?
- How would you validate millions of puzzles a day?
- What would you monitor and alert on?
- How would you turn the validator into a service or API?
