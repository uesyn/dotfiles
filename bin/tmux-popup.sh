#!/bin/bash

## Based on https://zenn.dev/skanehira/articles/2020-10-25-tmux-toggle-popup

width=${1:-80%}
height=${2:-80%}
if [[ "$(tmux display-message -p -F "#{session_name}")" == "popup" ]];then
    tmux detach-client
else
    tmux popup -d '#{pane_current_path}' -xC -yC -w$width -h$height -E "tmux attach -t popup || tmux new -s popup"
fi
