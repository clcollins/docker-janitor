#!/usr/bin/env bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -o errexit

# Docker Janitor removed non-running containers, 
# orphaned (dangling) images, and images that are 
# not in use by a running container.
#
# Useful for cleaing build systems or just picking up
# after oneself.

# This can be changed to use the docker command with extra options, eg:
# DOCKER=docker --tlsverify ...etc

DOCKER='docker'

# For future versions of docker:
# "container ls" == "ps"
# "container rm" == "rm"
# "image ls == "images"
# "image rm == "rmi"

# Remove Non-running containers
NONRUNNING_CONTAINERS=($($DOCKER ps --quiet --filter "status=created" --filter "status=exited" --filter "status=dead"))

if [[ ${#NONRUNNING_CONTAINERS[@]} > 0 ]]
then
  echo "Removing ${#NONRUNNING_CONTAINERS[@]} stopped containers"
  $DOCKER rm ${NONRUNNING_CONTAINERS[@]}
fi

# Remove Dangling Images
DANGLING_IMAGES=($($DOCKER images --quiet --filter "dangling=true"))

if [[ ${#DANGLING_IMAGES[@]} > 0 ]]
then
  echo "Removing ${#DANGLING_IMAGES[@]} orphaned images"
  $DOCKER rmi ${DANGLING_IMAGES[@]}
fi

# Get Images for Running containers
RUNNING_IMAGES=($($DOCKER inspect $($DOCKER ps --filter "status=running" --format '{{.ID}}' ) | jq --raw-output .[].Image))

# First set nonrunning image to ALL images
NONRUNNING_IMAGES=($($DOCKER images --quiet --no-trunc))

# Then remove running ones
for i in "${RUNNING_IMAGES[@]}"
do
  NONRUNNING_IMAGES=( ${NONRUNNING_IMAGES[@]/$i} )
done

# Remove Nonrunning Images
if [[ ${#NONRUNNING_IMAGES[@]} > 0 ]]
then
  echo "Removing ${#NONRUNNING_IMAGES[@]} non-running images"
  NONRUNNING_IMAGES_BY_TAGS=()
  for image in ${NONRUNNING_IMAGES[@]}
  do 
    # Convert to repo tags to avoid 
    # "image is referenced in multiple repositories" error
    NONRUNNING_IMAGES_BY_TAGS+=( $($DOCKER inspect $image | jq --raw-output  '.[].RepoTags | .[]') )
  done
  if [[ ${#NONRUNNING_IMAGES_BY_TAGS[@]} > 0 ]]
  then
    echo "Removing ${#NONRUNNING_IMAGES_BY_TAGS[@]} tagged images"
    $DOCKER rmi ${NONRUNNING_IMAGES_BY_TAGS[@]}
  fi
fi
