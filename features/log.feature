@el_donny
Feature: Log

  Scenario: Last
    * > el donny 1 + 1
    * > el donny 2 + 2
    * > el donny log:
      | (> 1 + 1) |
      | > 2 + 2   |

  Scenario: N
    * > el donny 1 + 1
    * > el donny 2 + 2
    * > el donny log 2:
      | > 1 + 1 |
      | > 2 + 2 |

  Scenario: All
    * > el donny 1 + 1
    * > el donny 2 + 2
    * > el donny log all:
      | > 1 + 1 |
      | > 2 + 2 |
