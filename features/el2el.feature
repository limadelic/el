#@el2el
#Feature: El2El Sessions talk to each other via @name> routing.
#
#  Scenario: Tell route to another session
#    * > el donny
#    * > el donnie
#    * > el donny tell @donnie you are out of your element
#    * > el donnie log
#      | you are out of your element |
#
#  Scenario: Ask route to another session
#    * > el donny
#    * > el donnie
#    * > el donny ask @donnie 1 + 1
#      | 2 |
