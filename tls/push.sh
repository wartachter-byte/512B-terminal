#!/bin/bash

if [ $(git auth status) == "1"]; then
	echo "Please log in."
else
git add .
git commit
git push
fi
