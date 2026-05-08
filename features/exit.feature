Feature: Exit

  Scenario: Single
    * > el ls:
      | (donny) |
    * > el donny start
    * > el ls:
      | donny |
    * > el donny exit
    * > el ls:
      | (donny) |
