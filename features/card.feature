Feature: Agent card

  Scenario Outline: New
    * > el <args>:
      """
      ╭────────────────────────────────────────────────╮
      │ name:  <name>                            id: … │
      │ agent: kent                     cwd: …/self/el │
      │ model: opus                                    │
      │ msgs:  1                                       │
      │ ────────────────────────────────────────────── │
      │ > who are you?                                 │
      │ ────────────────────────────────────────────── │
      │ kent                                           │
      ╰────────────────────────────────────────────────╯
      """
    * > el <name> exit

    Examples:
      | args                | name    |
      | kent start          | kent    |
      | kento start -a kent | kento   |
      | kent@el start       | kent@el |

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
    * > el anom start:
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
