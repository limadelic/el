@el
Feature: Help

  Scenario Outline: <scenario>
    * > el <args>:
      | el v0.1.               |                            |
      | el -v                  | version                    |
      | el ls                  | list sessions              |
      | el <name> [-m <model>] | start or status            |
      | el <name> <msg>        | send a msg                 |
      | el <name> log [n\|all] | view log (default: last 1) |
      | el <name> clear        | clear log                  |
      | el <name> exit         | exit session               |
      | el exit all            | exit all sessions          |

    Examples:
      | scenario | args       |
      | Help     |            |
      | Usage    | --nonsense |
