@el_dude
Feature: Msg

  Scenario: Msg
    * > el dude 1 + 1:
      | 2 |
    * > el dude log:
      | 1 + 1 |
      | 2     |

  Scenario: Convo
    * > el dude knock knock:
      | who |
    * > el dude the dude:
      | dude |
    * > el dude abides
    * > el dude log:
      | abides |
    * > el dude log all:
      | knock |
      | dude  |
      | abides |
