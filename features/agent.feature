Feature: Agent support

  Scenario: Explicit agent flag
    * > el kenny -a kent:
      | agent | kent |
      | model | opus |
    * > el kenny exit

  Scenario: Implicit agent detection from name
    * > el kent:
      | agent | kent |
      | model | opus |
    * > el kent exit

  Scenario: Model override agent detection from name
    * > el kent -m haiku:
      | agent | kent  |
      | model | haiku |
    * > el kent exit

  Scenario: Lisa agent with sonnet model
    * > el lisa:
      | agent | lisa   |
      | model | sonnet |
    * > el lisa exit
