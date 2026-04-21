@el2el
Feature: El2El
  Sessions talk to each other via @name> routing.

  Scenario: Tell route to another session
    * > el dude
    * > el donnie
    * > el dude tell @donnie> you are out of your element
    * > el donnie log
      | you are out of your element |

  Scenario: Ask route to another session
    * > el dude
    * > el donnie
    * > el dude ask @donnie> 1 + 1?
      | 2 |

  Scenario: Tell ask cross route
    * > el dude
    * > el donnie
    * > el dude tell ask @donnie 1 + 1
    * > el donnie log
      | 2 |

  Scenario: Ask tell cross route
    * > el dude
    * > el donnie
    * > el dude ask tell @donnie you are out of your element
    * > el donnie log
      | you are out of your element |
