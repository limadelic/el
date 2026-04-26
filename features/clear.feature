@el_dude
Feature: Clear

  Scenario: Clear
    * > el dude 1 + 1
    * > el dude log:
      | 1 + 1 |
    * > el dude clear
    * > el dude log:
      | (1 + 1) |
