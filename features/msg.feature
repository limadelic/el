@el
Feature: Comms

  Scenario: Tell
    * > el dude
    * > el dude tell sup dude
    * > el dude log:
      | user > sup dude |

  Scenario: Ask
    * > el dude
    * > el dude ask 1 + 1
      | 2 |
