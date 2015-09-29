#!/bin/bash
#set -x
declare -a PROJ_LIST=([0]='aide' [1]='eeasearch' [2]='elastic' [3]='pam')
declare -a FLAG_LIST=([0]='include_searchserver' [1]='include_es_river_rdf')
declare -a apps_to_build
declare -a flag_to_use

function build_apps() {
  
  declare -a tempArray=("${!1}")
  #for prj in "${apps_to_build[@]}"; do
  for prj in "${tempArray[@]}"; do
    echo "eeacms/${prj}:dev /eea.docker.${prj}/"
    #echo ${apps_to_build[@]}
  #docker build -t eeacms/eeasearch:dev /eea.docker.eeasearch/
  #sleep 1
  #docker build -t eeacms/pam:dev /eea.docker.pam/
  #sleep 1
  #docker build -t eeacms/aide:dev /eea.docker.aide/
  #sleep 1
  #docker build -t eeacms/elastic:dev /eea.docker.elastic/
  done
  unset apps_to_build
}

function build_apps_with_flags() {
  echo " "
}

function choose_builder() {
  declare -a apps=("${!1}")
  declare -a flags=("${!2}")
  
  if [ ${#apps[@]} -eq 0 ] && [ ${#flags[@]} -eq 0 ]; then
    build_apps PROJ_LIST[@]
  
  elif [ ${#apps[@]} -ge 1 ] && [ ${#flags[@]} -eq 0 ]; then
    build_apps apps[@]
    
  elif [ ${#apps[@]} -eq 0 ] && [ ${#flags[@]} -ge 1 ]; then
    build_apps_with_flags
    
  fi
}

function array_contains() {
  local array=("${!1}")
  local seeking=$2
  local in=false
  for element in "${array[@]}"; do
    if [[ $element == $seeking ]]; then
      in=true
      break
    fi
  done
  echo $in
}

function exist_in_array() {
  local args_or_flags=("${!1}")
  
  for item in "${args_or_flags[@]}"; do
    
    if [[ "argument" == "$2" ]]; then
      local is_in_array=$(array_contains PROJ_LIST[@] $arg)
      echo "args"
    else
      local is_in_array=$(array_contains FLAG_LIST[@] $arg)
      echo "flags"
    fi
  
    if [[ $is_in_array = false ]]; then
      echo "$item is not a correct $2 !"
      exit 100
    fi
  done
}

# Check if arguments are correctly inserted and added to local array variables
for arg in "$@"; do

  if [[ $arg != include* ]]; then
    apps_to_build+=($arg)
    #echo "$arg"
  else
    flag_to_use+=($arg)
  fi
  #echo "${apps_to_build[$var]}"
done

exist_in_array apps_to_build[@] "argument"
exist_in_array flag_to_use[@] "flag"

# ================ to remove
#for app in "${flag_to_use[@]}"; do
#  local is_in_array=$(array_contains FLAG_LIST[@] $arg)
  
#  if [[ $is_in_array = false ]]; then
#    echo "$arg is not a correct flag !"
#    exit 100
#  fi
#done
# ======

if [ ${#apps_to_build[@]} -eq 0 ]; then
  apps_to_build=("${PROJ_LIST[@]}")
  #for i in ${PROJ_LIST[@]}; do
  #  apps_to_build[${#apps_to_build[*]}]=$i
  #done
fi

choose_builder apps_to_build[@] flag_to_use[@]
# build_apps apps_to_build[@] flag_to_use[@]


# echo "$#"

# echo "Buidling eeacms/aide locally with local eea.searchserver.js"

# set -e

# if [ -z $1 ]; then
#     echo "Usage: ./build_dev.sh PATH_TO_SEACHSERVER_JS_REPO"
#     exit 100
# fi

# if [ ! -d $1 ]; then
#     echo "$1 is not a directory!"
#     exit 100
# fi

# SEARCHSERVER_DIR=$1

# function cleanup() {
#     echo "Cleanup"
#     rm -rf ./eea-searchserver
# }

# trap 'cleanup' INT

# rm -rf ./eea-searchserver && cp -r $SEARCHSERVER_DIR  ./eea-searchserver
# docker build -t "eeacms/aide:dev" -f Dockerfile.dev .

# cleanup

# echo "Done"
