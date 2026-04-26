Feature: Clear

  Scenario: Clear log
    * > el dude
    * > el dude log:
      | (dude) |
    * > el dude clear:
      | ok |
    * > el dude exit
