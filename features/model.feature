Feature: Model selection

  Scenario: Default model from environment
    * > el neo "what model are you using?":
      | haiku |
    * > el neo exit

  Scenario: Explicit model flag
    * > el trinity -m sonnet "what model are you using?":
      | sonnet |
    * > el trinity exit
