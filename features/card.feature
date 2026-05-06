Feature: Agent card

  Scenario Outline: New
    * > el <el>:
      """
      ╭────────────────────────────────────────────────╮
      │ name:  <name>                            id: … │
      │ agent: <agent>                  cwd: …/self/el │
      │ model: opus                                    │
      │ msgs:  1                                       │
      │ ────────────────────────────────────────────── │
      │ > who are you?                                 │
      │ ────────────────────────────────────────────── │
      │ <agent>                                        │
      ╰────────────────────────────────────────────────╯
      """
    * > el <name> exit

    Examples:
      | el            | name    | agent |
      | kent          | kent    | kent  |
      | kento -a kent | kento   | kent  |
      | kent@el       | kent@el | kent  |

  @el_kent
  Scenario: Used
    * > el kent "What is the meaning of life? (Int)"
    * > el kent:
      """
      ╭────────────────────────────────────────────────╮
      │ name:  kent                              id: … │
      │ agent: kent                     cwd: …/self/el │
      │ model: opus                                    │
      │ msgs:  2                                       │
      │ ────────────────────────────────────────────── │
      │ > What is the meaning of life?                 │
      │ ────────────────────────────────────────────── │
      │ 42                                             │
      ╰────────────────────────────────────────────────╯
      """
    * > el kent exit

  Scenario: Anom
    * > el anom:
      """
      ╭────────────────────────────────────────────────╮
      │ name:  anom                              id: … │
      ╰────────────────────────────────────────────────╯
      """
    * > el anom "who are you?"
    * > el anom:
      """
      ╭────────────────────────────────────────────────╮
      │ name:  anom                              id: … │
      │ model: haiku                    cwd: …/self/el │
      │ msgs:  1                                       │
      │ ────────────────────────────────────────────── │
      │ > who are you?                                 │
      │ ────────────────────────────────────────────── │
      │ dude                                           │
      ╰────────────────────────────────────────────────╯
      """
    * > el anom exit
