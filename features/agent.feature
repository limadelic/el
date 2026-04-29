Feature: Agent support

  Scenario: Explicit agent flag
    * > el kenny -a kent
    * > el kenny "who are you and what model are you?":
      | kent |
      | opus |
    * > el kenny exit

  @el_kent
  Scenario: Implicit agent detection from session name
    * > el kent "who are you and what model are you?":
      | kent |
      | haiku |
