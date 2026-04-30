@el_donny
Feature: Restart

  Scenario: Restart preserves session and context
    * > el donny "you are out of your element"
    * > el restart
    * > el ls:
      | donny |
    * > el donny "whare i said were u?":
      | element |
    * > el donny exit
