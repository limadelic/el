Feature: Agent support

  Scenario: Explicit agent flag
    * > el session1 -a kent "calculate 2 + 2":
      | kent |
    * > el session1 exit

  Scenario: Implicit agent detection from session name
    * > el kent "do something":
      | kent |
    * > el kent exit

  Scenario: Agent not found uses default session
    * > el unknown "task":
      | unknown |
    * > el unknown exit
