@el_v
Feature: Restart

  Scenario: Restart preserves session and context
    * > el v "remember remember the fifth of november"
    * > el restart
    * > el ls:
      | v |
    * > el v "what did i ask u to remember?":
      | fifth of november |
