Feature: Agent support

  Scenario: Explicit agent flag
    * > el kenny -a kent
    * > el kenny "who are you and what model are you?":
      | kent |
      | opus |
    * > el kenny exit

  Scenario: Implicit agent detection from session name
    * > el kent "who are you and what model are you?":
      | kent |
      | opus |
    * > el kent exit

  Scenario: Lisa agent with sonnet model
    * > el lisa "who are you and what model are you?":
      | lisa |
      | sonnet |
    * > el lisa exit
