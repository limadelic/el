@el
Feature: On/Off

  Scenario: Single
    * > el ls:
      | check   |
      | (dude)  |
    * > el dude:
      | check          |
      | el dude is up  |
    * > el ls:
      | check |
      | dude  |
    * > el dude kill
    * > el ls:
      | check  |
      | (dude) |


  Scenario: Many
    * > el ls:
      | check  |
      | (dude) |
    * > el dude
    * > el duder
    * > el dudito
    * > el ls:
      | check  |
      | dude   |
      | duder  |
      | dudito |
    * > el kill all
    * > el ls:
      | check    |
      | (dude)   |
      | (duder)  |
      | (dudito) |
