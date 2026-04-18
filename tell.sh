#!/bin/bash
cd /Users/maykel.suarez/dev/self/el
NAME=$1
shift
MSG="$*"
elixir --sname "client_$$" --cookie el -S mix run -e "
  Node.connect(:\"${NAME}@$(hostname -s)\")
  IO.puts(El.tell({:${NAME}, :\"${NAME}@$(hostname -s)\"}, \"${MSG}\"))
"
