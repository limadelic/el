Feature: Exit

  Scenario: Single
    * > el ls:
      | (dude) |
    * > el dude
    * > el ls:
      | dude |
    * > el dude exit
    * > el ls:
      | (dude) |
