"""
CODING CHALLENGE

Validate a sudoku for the following rules:

- each row has every number between 1 and 9 exactly once
- each column has every number between 1 and 9 exactly once
- each 3x3 block has every number between 1 and 9 exactly once

Example input:
  "974236158638591742125487936316754289742918563589362417867125394253649871491873625"

Example return:
  True

Test cases can be found in test_challenge.py.

"""


def validate(puzzle: str) -> bool:
  # We check if the input has 81 characters. This is the first and critical step.
    if len(puzzle) != 81:
      return False

    # Check if every character is a digit from 1 to 9
    if not all(char in '123456789' for char in puzzle):
      return False

    # We convert the string to 9 by 9 grid
    grid = [[int(puzzle[row * 9 + col]) for col in range(9)]
      for row in range(9)]

    # This is straight forward enough. Range is from 1 to 9, but the range functions doesn't take the last number so it's 10.
    expected = set(range(1,10))

    # Check rows
    for row in grid:
        if set(row) != expected:
          return False

    # Check columns
    for col in range(9):
        column = {grid[row][col] for row in range(9)}
        if column != expected:
          return False

    # Check 3 by 3 blocks
    for block_row in range(0,9,3):
        for block_col in range(0,9,3):
          block = {grid[row][col]
          for row in range(block_row, block_row + 3)
          for col in range(block_col, block_col + 3)}

          if block != expected:
            return False
        
    return True
