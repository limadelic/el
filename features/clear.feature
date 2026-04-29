@el_donny
Feature: Clear

  Scenario: Clear
    * > el donny 1 + 1
    * > el donny log:
      | 1 + 1 |
    * > el donny clear
    * > el donny log:
      | (1 + 1) |
