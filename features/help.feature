@el
Feature: El CLI

  Scenario: Usage
    * > el:
      | el 0.1.                        |
      | el --version                   |
      | el ls                          |
      | el <name> [--model <model>]    |
      | el <name> tell <message>       |
      | el <name> ask <message>        |
      | el <name> log                  |
      | el <name> kill                 |
      | el kill all                    |
