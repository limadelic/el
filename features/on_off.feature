@el
Feature: On/Off

  Scenario: Single
    * > el ls:
      | (dude) |
    * > el dude:
      | el dude is up |
    * > el ls:
      | dude |
    * > el dude kill
    * > el ls:
      | (dude) |


  Scenario: Many
    * > el ls:
      | (dude) |
    * > el dude
    * > el duder
    * > el dudito
    * > el ls:
      | dude   |
      | duder  |
      | dudito |
    * > el kill all
    * > el ls:
      | (dude)   |
      | (duder)  |
      | (dudito) |
