#! /bin/sh
 # This file (tmux_cmd.sh) was created based on xt_cmd.sh by Ron Rechenmacher <ron@fnal.gov>
 # Uses tmux for terminal management instead of xterm.
 # Suitable for headless/remote environments that lack an X11 display.

# defaults
session_name=artdaq-demo
CMD_STR=

env_opts_var=`basename $0 | sed 's/\.sh$//' | tr 'a-z-' 'A-Z_'`_OPTS
USAGE="\
   usage: `basename $0` [-h?] [options] <root>
examples: `basename $0` tmux_tmp_home -c'ps aux|grep \$$' -c': hi' -c'ls -a'
          `basename $0` tmux_tmp_home -c'::echo xxx' -c'history|tail -n5'
          `basename $0` tmux_tmp_home -c'echo hi' -c':^sleep 5' -c'echo done'
          $env_opts_var=-smy-session `basename $0` tmux_tmp_home -c'echo x'

-h -?             help
-c<cmd>
-g<geom_option>   (ignored; accepted for xt_cmd.sh compatibility)
-t<term>          (ignored; accepted for xt_cmd.sh compatibility)
-s<name>          tmux session name (dflt:$session_name)
--exec            block until the tmux window closes (analogous to xt_cmd.sh --exec)
--rcfile          bash resource file
--bash-opts       additional bash options

special 2 character sequences (as in -c':^sleep 5' above):
:^   just eval command (no echo, no hist insert)
::   just insert into the history
:!   \"command\" is actually a file of command(s)
:,   echo and eval, no hist insert
"

# Process script arguments and options
eval env_opts=\${$env_opts_var-} # can be args too
eval "set -- $env_opts \"\$@\""
op1chr='rest=`expr "$op" : "[^-]\(.*\)"`   && set -- "-$rest" "$@"'
op1arg='rest=`expr "$op" : "[^-]\(.*\)"`   && set --  "$rest" "$@"'
reqarg="$op1arg;"'test -z "${1+1}" &&echo opt -$op requires arg. &&echo "$USAGE" &&exit'
args= do_help= opt_v=0
while [ -n "${1-}" ];do
    if expr "x${1-}" : 'x-' >/dev/null;then
        op=`expr "x$1" : 'x-\(.*\)'`; shift   # done with $1
        leq=`expr "x$op" : 'x-[^=]*\(=\)'` lev=`expr "x$op" : 'x-[^=]*=\(.*\)'`
        test -n "$leq"&&eval "set -- \"\$lev\" \"\$@\""&&op=`expr "x$op" : 'x\([^=]*\)'`
        case "$op" in
        \?*|h*)      eval $op1chr; do_help=1;;
        v*)          eval $op1chr; opt_v=`expr $opt_v + 1`;;
        x*)          eval $op1chr; set -x;;
        t*|-term)    eval $reqarg; shift;;  # ignored; accepted for xt_cmd.sh compatibility
        -bash-opts)  eval $reqarg; bash_opts=$1; shift;;
        -rcfile)     eval $reqarg; rcfile=$1;    shift;;
        g*|-geom)    eval $reqarg; shift;;  # ignored; accepted for xt_cmd.sh compatibility
        s*|-session) eval $reqarg; session_name=$1; shift;;
        -exec)       do_exec=1;;
        c*)          eval $op1arg; test -z "$CMD_STR" && CMD_STR=$1 || CMD_STR=`echo "$CMD_STR";echo "$1"`;shift;;
        *)           echo "Unknown option -$op"; do_help=1;;
        esac
    else
        aa=`echo "$1" | sed -e"s/'/'\"'\"'/g"` args="$args '$aa'"; shift
    fi
done
eval "set -- $args \"\$@\""; unset args aa
test $# -ne 1 && do_help=1  # 1 required arg
test -n "${do_help-}" && echo "$USAGE" && exit

set -u # helps development
pseudo_home=$1
if [ ! -d "$pseudo_home" ];then
    echo "creating $pseudo_home"
    mkdir -p "$pseudo_home"
fi
pseudo_home=`cd "$pseudo_home" >/dev/null;pwd` # convert from potentially relative to abs

# Normally, I handle rcfile and bash_opts automatically --
# but if an expert user has specified BOTH, then assume he knows what he is doing
if [ -z "${rcfile+1}" -o -z "${bash_opts+1}" ];then
    links_resolved_pseudo=`csh -fc "cd \"$pseudo_home\";pwd"`
    links_resolved_home=`  csh -fc "cd \"$HOME\";pwd"`
    if [ "$links_resolved_pseudo" = "$links_resolved_home" ];then
        rcfile=.bashrc_xt_cmd
        bash_opts="--rcfile $rcfile"
    else
        rcfile=.bash_profile
        bash_opts="-l"
    fi
fi

init_profile_file() # $1=profile_file
{
    cat >$1 <<-'EOF'
	test -n "${REALHOME-}" && HOME=$REALHOME
	cmd_str_sav=$CMD_STR; unset CMD_STR
	if   [ -r $HOME/.bash_profile ];then
	        . $HOME/.bash_profile
	elif [ -r $HOME/.bash_login ];then
	        . $HOME/.bash_login
	elif [ -r $HOME/.profile ];then
	        . $HOME/.profile
	elif [ -f /etc/bashrc ];then
	        . /etc/bashrc
	fi
	CMD_STR=$cmd_str_sav
	histchars='!^#' # fix the (2nd part of the) strangeness (next line)
	builtin history -n      # strange: shouldn't have to do this. also, timestamps show up.
	EOF
    #
}

append_cmd_str_support() # $1=profile_file
{
    cat >>$1 <<-'EOF'
	# CMD_STR support
	hcmd() { builtin history -s "$@"; echo "$@"; eval "$@"; }
	process_cmd_str()
	{   cpltcmd=
	    IFSsav=$IFS IFS='
	';  for cmd_ in $1;do IFS=$IFSsav
	        if cmd__=`expr "x${cmd_}x" : 'x\(.*\)\\\\x$'`;then
	            cpltcmd="$cpltcmd$cmd__"; continue
	        else
	            cpltcmd="$cpltcmd$cmd_"
	        fi
	        if   histonly=`expr "x$cpltcmd" : 'x::\(.*\)'`;then
	            builtin history -s "$histonly"
	        elif nohist=`expr   "x$cpltcmd" : 'x:,\(.*\)'`;then
	            echo "$nohist"; eval "$nohist"
	        elif file=`expr     "x$cpltcmd" : 'x:!\(.*\)'`;then
	            xx=`cat $file`
	            process_cmd_str "$xx"  # recursive call
	        elif just_exe=`expr "x$cpltcmd" : 'x:^\(.*\)'`;then
	            eval "$just_exe"
	        else
	            hcmd "$cpltcmd"
	        fi
	        cpltcmd=
	    done
	}
	if [ -n "${CMD_STR-}" ];then
	    process_cmd_str "$CMD_STR"
	    unset CMD_STR
	fi
	EOF
    #
}

# pseudo_home_profile
if [ ! -f "$pseudo_home/$rcfile" ];then
    # create new one
    init_profile_file      "$pseudo_home/$rcfile"
    append_cmd_str_support "$pseudo_home/$rcfile"
fi

expr "x$bash_opts" : '.*--rcfile' >/dev/null && home=$HOME || home=$pseudo_home

# Build the tmux session name; append partition number when set so that
# multiple concurrent demos on the same host land in separate sessions.
tmux_session="$session_name"
if [ -n "${ARTDAQ_PARTITION_NUMBER-}" ]; then
    tmux_session="${session_name}-${ARTDAQ_PARTITION_NUMBER}"
fi

# Derive a human-readable window name from the pseudo_home directory.
window_name=`basename "$pseudo_home"`

# Create the tmux session (detached) if it does not already exist.
if ! tmux has-session -t "$tmux_session" 2>/dev/null; then
    tmux new-session -d -s "$tmux_session"
fi

cd "$pseudo_home" >/dev/null

# Write CMD_STR to a temporary file so that the wrapper script can read it
# back without any shell-quoting concerns (CMD_STR may contain newlines,
# dollar signs, single quotes, etc.).
cmd_str_file="$pseudo_home/.tmux_cmd_str_$$"
printf '%s' "$CMD_STR" > "$cmd_str_file"

# Generate a per-invocation wrapper script that the tmux window will execute.
# The wrapper reconstructs CMD_STR from the file, then execs bash inside a
# clean environment — mirroring exactly what xt_cmd.sh does via xterm.
wrapper="$pseudo_home/.tmux_start_$$.sh"
{
    printf '#!/bin/sh\n'
    printf '# Auto-generated by tmux_cmd.sh -- safe to delete\n'
    printf 'rm -f "%s"\n'  "$wrapper"        # self-cleanup on execution
    printf 'CMD_STR=$(cat "%s" 2>/dev/null)\n' "$cmd_str_file"
    printf 'rm -f "%s"\n'  "$cmd_str_file"
    printf 'export CMD_STR\n'
    printf 'exec env -i \\\n'
    printf '    SHELL="%s" \\\n'    "$SHELL"
    printf '    PATH="/usr/bin:/bin" \\\n'
    printf '    LOGNAME="%s" \\\n'  "$USER"
    printf '    USER="%s" \\\n'     "$USER"
    printf '    REALHOME="%s" \\\n' "$HOME"
    printf '    HISTFILE="%s/.bash_history" \\\n' "$HOME"
    # Write HISTTIMEFORMAT via a variable so that the % signs are passed
    # as literal characters (printf %s does not interpret them).
    _hfmt='%a %m/%d %H:%M:%S  '
    printf '    HISTTIMEFORMAT="%s" \\\n' "$_hfmt"
    printf '    HOME="%s" \\\n'     "$home"
    test -n "${KRB5CCNAME-}"           && printf '    KRB5CCNAME="%s" \\\n'           "$KRB5CCNAME"
    test -n "${TRACE_FILE-}"           && printf '    TRACE_FILE="%s" \\\n'           "$TRACE_FILE"
    test -n "${TRACE_LVLS-}"           && printf '    TRACE_LVLS="%s" \\\n'           "$TRACE_LVLS"
    test -n "${TRACE_LVLM-}"           && printf '    TRACE_LVLM="%s" \\\n'           "$TRACE_LVLM"
    test -n "${TRACE_MSGMAX-}"         && printf '    TRACE_MSGMAX="%s" \\\n'         "$TRACE_MSGMAX"
    test -n "${UPS_OVERRIDE-}"         && printf '    UPS_OVERRIDE="%s" \\\n'         "$UPS_OVERRIDE"
    test -n "${CET_PLATINFO-}"         && printf '    CET_PLATINFO="%s" \\\n'         "$CET_PLATINFO"
    test -n "${LIBRARY_PATH-}"         && printf '    LIBRARY_PATH="%s" \\\n'         "$LIBRARY_PATH"
    test -n "${SSH_AGENT_PID-}"        && printf '    SSH_AGENT_PID="%s" \\\n'        "$SSH_AGENT_PID"
    test -n "${SSH_AUTH_SOCK-}"        && printf '    SSH_AUTH_SOCK="%s" \\\n'        "$SSH_AUTH_SOCK"
    test -n "${PRODUCTS-}"             && printf '    PRODUCTS="%s" \\\n'             "$PRODUCTS"
    test -n "${ARTDAQDEMO_BASE_PORT-}" && printf '    ARTDAQDEMO_BASE_PORT="%s" \\\n' "$ARTDAQDEMO_BASE_PORT"
    test -n "${ARTDAQ_PARTITION_NUMBER-}" && printf '    ARTDAQ_PARTITION_NUMBER="%s" \\\n' "$ARTDAQ_PARTITION_NUMBER"
    printf '    CMD_STR="$CMD_STR" \\\n'
    printf '    bash %s\n' "$bash_opts"
} > "$wrapper"
chmod +x "$wrapper"

# Launch the wrapper in a new tmux window.
# -P -F "#{window_index}" prints the index of the newly created window so
# that the --exec poll loop can monitor exactly this window (not others that
# may share the same name).
new_window_idx=$(tmux new-window \
    -t "${tmux_session}:" \
    -n "$window_name" \
    -P -F "#{window_index}" \
    "$wrapper" 2>/dev/null)

if [ -n "${do_exec-}" ]; then
    # Block until the specific window we just opened is gone, mirroring the
    # blocking behaviour of xt_cmd.sh --exec when used with & in run_demo.sh.
    while tmux list-windows -t "$tmux_session" \
              -F "#{window_index}" 2>/dev/null \
          | grep -q "^${new_window_idx}$"; do
        sleep 1
    done
fi
