Feature: Sessions

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

  Scenario: Glob
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
