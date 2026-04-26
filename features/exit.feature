Feature: Exit

  Scenario: Single
    * > el ls:
      | (dude) |
    * > el dude:
      | el dude is up |
    * > el ls:
      | dude |
    * > el dude exit
    * > el ls:
      | (dude) |
