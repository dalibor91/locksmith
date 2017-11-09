#!/bin/bash

option_add=""
option_remove=""
option_list=0
option_update=0
option_remote_normal=""
option_remote=""
option_help=0
option_show_rmt=0
option_edit_rmt=0
option_clear_rmt=0
option_user_public_key="${HOME}/.ssh/id_rsa.pub"
option_home_dir="${HOME}/.sshlsm"
option_keys_aliases="${option_home_dir}/alias"
option_keys_keys="${option_home_dir}/keys"
option_global_log="${option_home_dir}/log"
option_authkeys_history="${option_home_dir}/history"
option_history_remote="${option_home_dir}/remotes.history"

function _log() {
   local msg=$(date +"[ %Y-%m-%d %H:%M:%S ] ")
   local msg="${msg}${1}"

   echo "${msg}" >> "${option_global_log}"
}

function _dieOnFail() {
    _log "_dieOnFail [ $1 ] [ $2 ]"

    if [ ! $1 -eq 0 ];
    then
        if [ ! "$2" = "" ]; then echo "$2"; fi
        exit 1;
    fi
}

function _checkDirectories() {
    if [ ! -d "$option_home_dir" ]; then mkdir "$option_home_dir"; _dieOnFail $? "Unable to create $option_home_dir"; chmod 700 "$option_home_dir"; fi;
    if [ ! -d "$option_keys_keys" ]; then mkdir "$option_keys_keys"; _dieOnFail $? "Unable to create $option_keys_keys"; fi;
    if [ ! -d "$option_keys_aliases" ]; then mkdir "$option_keys_aliases"; _dieOnFail $? " Unable to create $option_keys_aliases"; fi;
    if [ ! -d "$option_authkeys_history" ]; then mkdir "$option_authkeys_history"; _dieOnFail $? " Unable to create $option_authkeys_history"; fi;
}

function _parseParams() {
    while [[ $# -gt 0 ]];
    do
        local key=$1
        case $key in 
            -a|--add)
                option_add=$2
                shift
                shift
                ;;
            -r|--remove)
                option_remove=$2
                shift
                shift
                ;;
            -e|--edit)
                option_edit=$2
                shift
                shift
                ;; 
            -l|--list)
                option_list=1
                shift
                ;;
            -h|--help)
                option_help=1
                shift
                ;;
            --update)
                option_update=1
                shift
                ;;
            --addme)
                option_remote_normal=$2
                shift;
                shift
                ;;
             --addmelsm)
                option_remote=$2
                shift
                shift
                ;;
            --show-remotes)
                option_show_rmt=1
                shift
                ;;
            --edit-remotes)
                option_edit_rmt=1
                shift
                ;;
             --clear-remotes)
                option_clear_rmt=$2
                shift
                ;;
                
            *)
                #unknown 
                #options_args="${options_args}${key} "
                echo "Unknown -> ${key}"
                shift
            ;;
        esac
    done;
}

function _addKey() {
    _log "_addKey() $@"

    local file_alias="&"
    until [[ ! "$file_alias" =~ [^a-zA-Z0-9@_.-] ]];
    do
        echo "Enter key name:"
        read -r file_alias
        if [ -f "${option_keys_aliases}/${file_alias}" ];
        then 
                echo "Alias already exists"
                local file_alias="&"
        fi;
    done;

    _log "${file_alias} ->" "${1}"

    local new_key_name=$(date +"%Y-%m-%d_%H-%M-%S.key");

    cp $1 "${option_keys_keys}/${new_key_name}"
    ln -s "${option_keys_keys}/${new_key_name}" "${option_keys_aliases}/${file_alias}"
    _dieOnFail $? "Unable to add"
}

function _getKey() {
    _log "_getKey() $@"
    if [ -f "${option_keys_aliases}/$1" ]; then echo $(readlink "${option_keys_aliases}/$1"); fi;
}

function _printKey() {
    _log "_printKey() $@"
    local k=$(_getKey $1)

    if [ ! "$k" = "" ];
    then 
        cat "$k";
    fi
}

function _updateKey() {
    _log "_updateKey() $@"
    local k=$(_getKey $1)

    if [ ! "$k" = "" ];
    then 
        if [ "$DEFAULT_EDITOR" ];
        then 
           $DEFAULT_EDITOR "$k"
        else 
           nano $k
        fi
    fi
}

function _allowAll() {
    _log "_allowAll() $@"

    local ak="${HOME}/.ssh/authorized_keys"

    if [ -f "${HOME}/${ak}" ];
    then 
        cp "${HOME}/${ak}" "${option_authkeys_history}/authorized_keys-`date +"%Y-%m-%d_%H-%M-%S"`"
        _dieOnFail $? "Unable to make backup copy of authorized_keys"
    fi;

    local tempfile=$(mktemp /tmp/tmp_key.XXXXXX)
    for key in $(ls "${option_keys_keys}");
    do 
            cat "${option_keys_keys}/$key" >> "$tempfile"
    done
    cat "$tempfile" > "$ak"
    rm $tempfile
}

function _addMe() {
    _log "_addMe() "

    local userkey="${option_user_public_key}"

    echo "Enter publc key to use or leave empty to use ${userkey}"
    read newuserkey

    if [ ! "$newuserkey" = "" ]; then userkey="$newuserkey"; fi;
    if [ ! -f "$userkey" ]; then echo "Not found ${userkey}"; exit 6; fi;

    _log "Using ${userkey}"
    local ukey=$(cat $userkey)
    
    echo "Adding ..."

    ssh $1 "echo '${ukey}' >> ~/.ssh/authorized_keys"
    if [ $? -eq 0 ];
    then
      echo $1 >> "${option_history_remote}"
    fi
}

function _addMe1() {
    _log "_addMe1() "

    local userkey="${option_user_public_key}"

    echo "Enter publc key to use or leave empty to use ${userkey}"
    read newuserkey

    if [ ! "$newuserkey" = "" ]; then userkey="$newuserkey"; fi;
    if [ ! -f "$userkey" ]; then echo "Not found ${userkey}"; exit 6; fi;

    _log "Using ${userkey}"
    local ukey=$(cat $userkey)
    
    echo "Adding ..."

    ssh $1 "_t=\$(date +"%s"); echo '${ukey}' > /tmp/\$_t; sshlsm -a /tmp/\$_t; rm /tmp/\$_t;"
    if [ $? -eq 0 ];
    then
      echo $1 >> "${option_history_remote}"
    fi
}


function _update() {
    _log "_update() $@"
    local _curl=$(which curl)
    if [ "$_curl" = "" ];
    then 
        echo "Please install curl"
        exit 4
    fi

    local abspath=$(readlink $(which sshlsm))
    echo "Updating..."
    curl -o "$abspath" "https://raw.githubusercontent.com/dalibor91/locksmith/master/locksmith.sh?timestamp=$(date +"%s")" > "/tmp/sshlsm_`whoami`.log" 2>&1

    _dieOnFail $? "Unable to update check /tmp/sshlsm_`whoami`.log"
    echo "Updated!"
}

function process {

    _log "process() $@"

    function _action_help() {
        _log "_action_help() $@"
        echo "
Description:

SSHlsm is small script that makes SSH key management easy. 
You can easily add, remove, update keys for your user, 
without manually editing ~/.ssh/authorized_keys file. 
Or you can add your local key to some remote server. 
Whenever this script makes change to the authorized_keys, 
it saves backup of it in ~/.sshlsm/history so you can revert it if you need to
When adding to remote server you can chose 2 options,
--addme and --addmelsm. Difference between this 2 options is 
that --addme will add your key directly to authorized_keys,
--addmelsm uses SSHlsm on remote server to add your key there,
if it's installed, so you can better manage keys on remote server also.

Usage:

sshlsm 
    -a|--add    <key-file>    - adds key 
    -e|--edit   <key-name>    - opens editor to edit key 
    -r|--remove <key-name>    - removes key 
    -l|--list                 - list all keys 
    -h|--help                 - prints this message

    --addme     <user>@<host> - adds your key to remote authorized_keys
    --addmelsm  <user>@<host> - adds your key to remote server via sshlsm 
    --update                  - updates this program
    --show-remotes            - shows where you added your key remotely
    --edit-remotes            - opens file with remotes to edit it
    --clear-remotes           - clears file with history where you added your key 

Example:
    sshlsm -a mykey.pub
    sshlsm -r someuser@somedomain.com
    sshlsm --addmelsm test@example.org
"
    }

    function _action_add() {
        _log "_action_add $@"
        if [ ! -f "$1" ]; then echo "Key file does not exists"; exit 2; fi;
        _addKey $1
        _allowAll

        echo "Added."
    }

    function _action_remove() {
        _log "_action_remove $@"
        local key=$(_getKey $1)
        if [ "$key" = "" ]; then echo "Unable to find key"; exit 3; fi;

        rm "${key}"
        rm "${option_keys_aliases}/${1}"
        _allowAll
        echo "Removed"
    }

    function _action_edit() {
        _log "_action_edit $@"
        local key=$(_getKey $1)
        if [ "$key" = "" ]; then echo "Unable to find key"; exit 3; fi;

        _updateKey $1
        _allowAll
        echo "Updated."
    }

    function _action_list() {
        _log "_action_list()"
        echo "Keys found:"
        for k in $(ls "${option_keys_aliases}");
        do 
            echo "  ${k}"
        done;
    }

    function _action_remote_normal() {
        _log "_action_remote_normal()"
        _addMe $1
    }


    function _action_remote() {
        _log "_action_remote()"
        _addMe1 $1
    }
    
    function _action_showrmt() {
      _log "_action_showrmt()"
      cat "${option_history_remote}"
    }
    
    function _action_clearrmt() {
      _log "_action_clearrmt()"
      echo '' > "${option_history_remote}"
    }
    
    function _action_editrmt() {
      _log "_action_editrmt()"
      
      if [ "$DEFAULT_EDITOR" ];
      then 
          $DEFAULT_EDITOR "${option_history_remote}"
      else 
         nano "${option_history_remote}"
      fi
    }

    local _used=0;

    if [ $option_help -eq 1 ]; then _action_help; _used=1; fi;
    if [ $option_list -eq 1 ]; then _action_list; _used=1; fi;
    if [ $option_update -eq 1 ]; then _update; _used=1; fi; 
    if [ $option_show_rmt -eq 1 ]; then _action_showrmt; _used=1; fi;
    if [ $option_edit_rmt -eq 1 ]; then _action_editrmt; _used=1; fi;
    if [ $option_clear_rmt -eq 1 ]; then _action_clearrmt; _used=1; fi;

    if [ ! "$option_remove" = "" ]; then _action_remove "$option_remove"; _used=1; fi;
    if [ ! "$option_add" = "" ]; then _action_add "$option_add"; _used=1; fi;
    if [ ! "$option_edit" = "" ]; then _action_edit "$option_edit"; _used=1; fi;
    if [ ! "$option_remote_normal" = "" ]; then _action_remote_normal "$option_remote_normal"; _used=1; fi;
    if [ ! "$option_remote" = "" ]; then _action_remote "$option_remote"; _used=1; fi;

    if [ $_used -eq 0 ];
    then 
        _action_help
    fi;

}

_checkDirectories

_parseParams $@

process
