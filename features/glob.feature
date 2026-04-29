@el_donny @el_donner
Feature: Glob

  Scenario: All
    * > el ls:
      | donny  |
      | donner |
    * > el exit
    * > el ls:
      | (donny)  |
      | (donner) |

  @el_kenny
  Scenario: Pattern
    * > el donn* exit
    * > el ls:
      | kenny    |
      | (donny)  |
      | (donner) |

  Scenario: Clear
    * > el donny 1 + 1
    * > el donner 2 + 2
    * > el donn* clear
    * > el donny log:
      | (1 + 1) |
    * > el donner log:
      | (2 + 2) |

  Scenario: Log
    * > el donny 1 + 1
    * > el donner 2 + 2
    * > el donn* log:
      | 1 + 1 |
      | 2 + 2 |
