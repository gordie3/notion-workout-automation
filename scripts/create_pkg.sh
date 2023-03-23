#!/bin/bash

echo "Executing create_pkg.sh..."

dir_name=lambda_dist_pkg/
mkdir $dir_name

# Create and activate virtual environment...
virtualenv env_notion_workouts
source ./env_notion_workouts/bin/activate

# Installing python dependencies...
FILE=./src/requirements.txt

if [ -f "$FILE" ]; then
  echo "Installing dependencies..."
  echo "From: requirement.txt file exists..."
  pip install -r "$FILE"

else
  echo "Error: requirement.txt does not exist!"
fi

# Deactivate virtual environment...
deactivate

# Create deployment package...
echo "Creating deployment package..."
cp -r env_notion_workouts/lib/python3.9/site-packages/. ./$dir_name
cp -r ./src/. ./$dir_name

# Removing virtual environment folder...
echo "Removing virtual environment folder..."
rm -rf ./env_notion_workouts

echo "Finished script execution!"
