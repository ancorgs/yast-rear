#! /bin/sh

# exit on error immediately
set -e

function start_module()
{
  # run "yast <module>" in a new tmux session (-d = detach, -s = session name)
  tmux new-session -d -s $1 "yast $2"
}

function dump_screen()
{
  echo "----------------------- Screen Dump Begin -----------------------------"
  # TODO: optionally use -e to include the escape characters,
  # i.e. dump the colors as well (optionally because it does not look nice at Travis)
  # reinitialize the terminal to possibly reset the colors after that:
  # tput init
  tmux capture-pane -p -t "$1"
  echo "----------------------- Screen Dump End -------------------------------"
}

function expect_text()
{
  if tmux capture-pane -p -t "$1" | grep -q "$2"; then
    echo "Matched expected text: '$2'"
  else
    echo "ERROR: No match for expected text '$2'"
    exit 1
  fi
}

function not_expect_text()
{
  if tmux capture-pane -p -t "$1" | grep -q "$2"; then
    echo "ERROR: Matched unexpected text: '$2'"
    exit 1
  fi
}

function send_keys() {
  echo "Sending keys: $2"
  tmux send-keys -t "$1" "$2"
}

# additionally install tmux
# TODO: install tmux in the shared base Docker image
zypper --non-interactive in --no-recommends tmux

# install the built package
# TODO: use zypper if the dependencies are really required:
# zypper --non-interactive in --no-recommends /usr/src/packages/RPMS/*/*.rpm
rpm -iv --force --nodeps /usr/src/packages/RPMS/*/*.rpm

# name of the tmux session
SESSION=yast2_rear

# run "yast rear" in a new session
start_module $SESSION rear

# wait a bit to ensure YaST is up
# TODO: wait until the screen contains the expected text (with a timeout),
# 3 seconds might not be enough on a slow or overloaded machine
sleep 3

dump_screen $SESSION
not_expect_text $SESSION "Internal error"
# Bootloader is not configured (does not make sense in Docker),
# so this is OK actually
# TODO: when running the script outside Docker the bootloader might be configured,
# make this step optional depending on the /etc/sysconfig/bootloader:LOADER_TYPE value
expect_text $SESSION "This system is not supported by rear"
expect_text $SESSION "Bootloader none is used"
# Press "Ignore" (Alt-i shortcut)
send_keys $SESSION "M-i"

sleep 3
dump_screen $SESSION
expect_text $SESSION "Your ReaR configuration needs to be modified"
# Press "OK" (F10 shortcut)
send_keys $SESSION "F10"

sleep 3
dump_screen $SESSION
expect_text $SESSION "Rear Configuration"
# the configuration is not trivial, just abort right now...
send_keys $SESSION "F9"

# TODO: check if YaST exited properly

# TODO: trap the signals and do a cleanup at the end
# (kill YaST if it is still running, tmux kill-session ?)
