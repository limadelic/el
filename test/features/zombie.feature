@el
Feature: Zombie
  Dude runs headless Claude sessions from the shell.

  Scenario: Kill dude
    When I run el dude in background
    Then el ls should show dude
    When I run el dude kill
    Then el ls should show (dude)
