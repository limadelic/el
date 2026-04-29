Feature: Help

  Scenario Outline: <scenario>
    * > el <args>:
      | el v0.1.                     |                            |
      | el -v                        | version                    |
      | el ls                        | list sessions              |
      | el <name> [-m <model>] [-a <agent>] | start or status            |
      | el <name> <msg>              | send a msg                 |
      | el <name\|glob> log [n\|all] | view log (default: last 1) |
      | el <name\|glob> clear        | clear log                  |
      | el <name\|glob> exit         | exit session               |
      | el exit                      | exit all sessions          |

    Examples:
      | scenario | args       |
      | Help     |            |
      | Usage    | --nonsense |
