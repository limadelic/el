Feature: Model selection

  @el_haiko
  Scenario: Default model from environment
    * > el haiko "what model are you using?":
      | haiku |

  Scenario: Explicit model flag
    * > el sonet -m sonnet
    * > el sonet "what model are you using?":
      | sonnet |
    * > el sonet exit
