@el_dude @el_duder
Feature: Glob

  Scenario: All
    * > el ls:
      | dude  |
      | duder |
    * > el exit
    * > el ls:
      | (dude)  |
      | (duder) |

  @el_kenny
  Scenario: Pattern
    * > el dud* exit
    * > el ls:
      | kenny   |
      | (dude)  |
      | (duder) |

  Scenario: Clear
    * > el dude 1 + 1
    * > el duder 2 + 2
    * > el dud* clear
    * > el dude log:
      | (1 + 1) |
    * > el duder log:
      | (2 + 2) |

  Scenario: Log
    * > el dude 1 + 1
    * > el duder 2 + 2
    * > el dud* log:
      | 1 + 1 |
      | 2 + 2 |
