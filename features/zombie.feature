@el
Feature: Zombie
  Dude runs headless Claude sessions from the shell.

  @wip
  Scenario: Tell dude hey man
    * > el dude &
    * > el dude tell hey man
    * > el dude log
      | hey man |

  @wip
  Scenario: Ask dude 1 + 1
    * > el dude &
    * > el dude ask 1 + 1
      | 2 |

  @wip
  Scenario: Kill dude
    * > el dude &
    * > el ls
      | dude |
    * > el dude kill
    * > el ls
      | (dude) |
