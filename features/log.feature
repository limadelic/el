@el_dude
Feature: Log

  Scenario: Last
    * > el dude 1 + 1
    * > el dude 2 + 2
    * > el dude log:
      | (1 + 1) |
      | 2 + 2   |

  Scenario: N
    * > el dude 1 + 1
    * > el dude 2 + 2
    * > el dude log 2:
      | 1 + 1 |
      | 2 + 2 |

  Scenario: All
    * > el dude 1 + 1
    * > el dude 2 + 2
    * > el dude log all:
      | 1 + 1 |
      | 2 + 2 |
