@el_donny
Feature: Msg

  Scenario: Msg
    * > el donny 1 + 1:
      | 2 |
    * > el donny log:
      | 1 + 1 |
      | 2     |

  Scenario: Convo
    * > el donny knock knock:
      | who |
    * > el donny the donny:
      | donny |
    * > el donny out of your element
    * > el donny log all:
      | knock   |
      | donny   |
      | element |
