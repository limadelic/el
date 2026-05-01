@el_donny
Feature: Restart

  Scenario: Restart preserves session and context
    * > el donny "you are out of your element"
    * > el restart
    * > el ls:
      | donny |
    * > el donny "where did i say u were?":
      | element |
    * > el donny exit
