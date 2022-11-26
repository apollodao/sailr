#!/bin/bash

release_tag=master
sailr_repo="https://github.com/craicoverflow/sailr/tree/$release_tag"

# checks that jq is usable
function check_jq_exists_and_executable {
if ! [ -x "$(command -v jq)" ]; then
  echo -e "\`commit-msg\` hook failed. Please install jq."
  exit 1
fi
}

# check if the config file exists
# if it doesnt we dont need to run the hook
function check_sailr_config {
  if [[ ! -f "$CONFIG" ]]; then
    echo -e "Sailr config file is missing. To set one see $sailr_repo#usage"
    exit 0
  fi
}

function set_config {
  local_config="$PWD/sailr.json"

  if [ -f "$local_config" ]; then
    CONFIG=$local_config
  elif [ -n "$SAILR_CONFIG" ]; then
    CONFIG=$SAILR_CONFIG
  fi
}

# set values from config file to variables
function set_config_values() {
  enabled=$(jq -r .enabled "$CONFIG")

  if [[ ! $enabled ]]; then
    exit 0
  fi

  revert=$(jq -r .revert "$CONFIG")
  types=($(jq -r '.types[]' "$CONFIG"))
  min_length=$(jq -r .length.min "$CONFIG")
  max_length=$(jq -r .length.max "$CONFIG")
}

# build the regex pattern based on the config file
function build_regex() {
  set_config_values

  regexp="^[.0-9]+$|"

  if $revert; then
      regexp="${regexp}^([Rr]evert|[Mm]erge):? )?.*$|^("
  fi

  for type in "${types[@]}"
  do
    regexp="${regexp}$type|"
  done

  regexp="${regexp%|})(\(.+\))?: "

  regexp="${regexp}.{$min_length,$max_length}$"
}


# Print out a standard error message which explains
# how the commit message should be structured
function print_error() {
  commit_message=$1
  regular_expression=$2
  echo -e "[Invalid Commit Message]"
  echo -e "------------------------"
  echo -e "Valid types: ${types[@]}"
  echo -e "Max length (first line): $max_length"
  echo -e "Min length (first line): $min_length"
  echo -e "Regex: $regular_expression"
  echo -e "Actual commit message: $commit_message"
  echo -e "Actual length: $(echo $commit_message | wc -c)"
}

set_config

# check if the repo has a sailr config file
check_sailr_config

# make sure jq is installed
check_jq_exists_and_executable

# get the first line of the commit message
INPUT_FILE=$1
START_LINE=`head -n1 $INPUT_FILE`

build_regex

if [[ ! $START_LINE =~ $regexp ]]; then
  # commit message is invalid according to config - block commit
  print_error
  exit 1
fi
