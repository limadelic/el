@el
Feature: El CLI

  Scenario: Usage
    * > el:
      | el v0.1.                 |                   |
      | el -v                    | version           |
      | el ls                    | list sessions     |
      | el <name> [-m <model>]   | start or status   |
      | el <name> tell <message> | fire-and-forget   |
      | el <name> ask <message>  | wait for response |
      | el <name> log            | view log          |
      | el <name> kill           | kill session      |
      | el kill all              | kill all sessions |
