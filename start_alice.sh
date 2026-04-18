#!/bin/bash
cd /Users/maykel.suarez/dev/self/el
elixir --sname alice --cookie el -S mix run -e 'El.start(:alice); IO.puts("el: alice is up"); Process.sleep(:infinity)'
