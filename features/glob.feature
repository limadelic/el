Feature: Glob

  Scenario: All
    * > el dude
    * > el duder
    * > el dudito
    * > el ls:
      | dude   |
      | duder  |
      | dudito |
    * > el exit
    * > el ls:
      | (dude)   |
      | (duder)  |
      | (dudito) |

  Scenario: Pattern
    * > el dude
    * > el duder
    * > el dudito
    * > el kenny
    * > el dud* exit
    * > el ls:
      | kenny    |
      | (dude)   |
      | (duder)  |
      | (dudito) |
    * > el kenny exit
