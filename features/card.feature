Feature: Agent card

  Scenario: New
    * > el kent:
      | name  | kent    |
      | agent | kent    |
      | model | opus    |
      | msgs  | 1       |
      | >     | who are |
      | lisa  | ...     |
    * > el kent exit

  @el_kent
  Scenario: Used
    * > el kent "What is the meaning of life?"
    * > el kent:
      | name  | kent                         |
      | agent | kent                         |
      | model | opus                         |
      | msgs  | 2                            |
      | >     | What is the meaning of life? |
      | 42    |                              |


