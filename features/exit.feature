Feature: Exit

  Scenario: Single
    * > el ls:
      | (donny) |
    * > el donny
    * > el ls:
      | donny |
    * > el donny exit
    * > el ls:
      | (donny) |
