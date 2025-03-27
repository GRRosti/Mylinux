#!/bin/bash

#list files, sorted asc/desc by size

echo "enter path to any directory"
read directory
echo "Choose order A/D"
read order
if [ $order == A ]; then
ls -lSrh $directory
elif [ $order == D ]; then
ls -lSh $directory
else 
echo "wrong choise"
fi



