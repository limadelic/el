#!/bin/bash
cd /Users/maykel.suarez/dev/self/el
elixir --sname bob --cookie el -S mix run -e 'El.start(:bob); IO.puts("el: bob is up"); Process.sleep(:infinity)'
