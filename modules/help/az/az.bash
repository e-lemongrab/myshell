#!/bin/bash
source "$mod_colors"
clear
cyan
echo "Azure"
nocolor
yellow
echo "Packages"
nocolor
echo -e "\tbrew install az; sudo pacman -S azure-kubelogin"
yellow
echo "Extensions"
nocolor
echo -e "\tTo perform Pull Request from terminal"
echo -e "\taz extension add --name azure-devops"
echo -e "\taz devops login"
yellow
echo "Kubeconfig"
nocolor
echo -e "\taz login --use-device-code"
echo -e "\taz account set --subscription subcription_ID"
echo -e "\taz group list --output table"
echo -e "\taz aks list --resource-group <your-resource-group-name> --output table"
echo -e "\taz aks get-credentials --resource-group rg-name --name cluster-name --overwrite-existing"
echo -e "\tkubelogin convert-kubeconfig -l azurecli"
yellow
echo "Set the Default Organization and Project"
nocolor
echo -e "\taz devops configure --defaults organization=https://dev.azure.com/YourOrganization project=YourProjectName"
