@el_dude @el_duder @el_dudito
Feature: Glob


  Scenario: All
    * > el ls:
      | dude   |
      | duder  |
      | dudito |
    * > el exit
    * > el ls:
      | (dude)   |
      | (duder)  |
      | (dudito) |

  @el_kenny
  Scenario: Pattern
    * > el dud* exit
    * > el ls:
      | kenny    |
      | (dude)   |
      | (duder)  |
      | (dudito) |
