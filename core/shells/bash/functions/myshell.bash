#!/bin/bash
# shellcheck disable=SC2154
# shellcheck disable=SC1090
myshell() {
  source "$mod_colors"
  #
  #CORE
  # commands
  red
  echo ">""$(cyan)myshell"
  echo -e \
   "myshell - available commands\nchecks - compatibility software checks"
  echo ""
  # help
  red
  echo ">""$(white)Help"
  echo -e "help_arch\thelp_az\thelp_dig\thelp_docker\thelp_gcloud\thelp_git\thelp_kubectl\thelp_mysql\thelp_terraform"
  #
  #MODULES
  # docker
  echo ""
  red
  echo ">""$(blue)docker"
  ls "$project_path"/modules/docker/
  echo ""
  # k8s
  #
  red
  echo ">""$(magenta)k8s"
  ls "$project_path"/modules/k8s/menus
  echo ""
  # ssh
  red
  echo ">""$(red)ssh"
  ls "$project_path"/modules/ssh/
  echo ""
  # bw
  red
  echo ">""$(orange)bw - client"
  echo -e "bw_push\t\tbw_clone\tbw_create"
  echo ""
  # john
  red
  echo ">""$(green)John"
  echo -e "john_dictionary\tjohn_unshadow\tjohn_zip"
  # utils
  echo ""
  red
  echo ">""$(yellow)Utils"
  echo -e "cert_base64_for_sealed_secret\tcheck_domains"
}
export myshell