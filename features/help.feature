@el
Feature: Help

  Scenario: Usage
    * > el:
      | el v0.1.                       |
      | el -v                          |
      | el ls                          |
      | el <name> [-m <model>]         |
      | el <name> tell <message>       |
      | el <name> ask <message>        |
      | el <name> log                  |
      | el <name> kill                 |
      | el kill all                    |
