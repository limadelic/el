Feature: Model selection

  Scenario: Default model from environment
    * > el session1 "what model are you using?":
      | haiku |
    * > el session1 exit

  Scenario: Explicit model flag
    * > el session2 -m sonnet "what model are you using?":
      | sonnet |
    * > el session2 exit
