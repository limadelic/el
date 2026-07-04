Feature: Help

  Scenario Outline: <scenario>
    * > el <args>:
      """
      el v0.1.*

      el -v                                 version
      el ls                                 list names
      el <name> [-json]                     info
      el <name> log [n|all] [-json]         view log (default: last 1)

      el <name> start [args]                start session
        args:
          -m <model>                        model
          -a <agent>                        agent

      el <name> <msg>                       send a msg

      el <name|glob> <cmd>                  apply command to one or many
      el <cmd>                              apply command to all
        cmds:
          clear                             start new session
          exit                              exit session
          restart                           restart session
      """

    Examples:
      | scenario           | args     |
      | Help               |          |
      | Usage not a flag   | --noflag |
      | Usage not an agent | nobody   |
