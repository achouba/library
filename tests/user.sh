#! /bin/bash

passwords=$(mktemp)
echo "password" >> ${passwords}
echo "password" >> ${passwords}

echo "Stopping daemon:"
./cosy.lua daemon:stop --force
echo "Stopping server:"
./cosy.lua server:stop  --force
echo "Starting server:"
./cosy.lua server:start --force --clean
echo "Printing available methods:"
./cosy.lua
echo "Server information:"
./cosy.lua server:information
echo "Terms of Service:"
./cosy.lua server:tos
echo "Creating user alinard:"
cat ${passwords} | ./cosy.lua user:create alban.linard@gmail.com alinard
echo "Failing at creating user alban:"
cat ${passwords} | ./cosy.lua user:create alban.linard@gmail.com alban
echo "Creating user alban:"
cat ${passwords} | ./cosy.lua user:create alban.linard@lsv.ens-cachan.fr alban
echo "Authenticating user alinard:"
cat ${passwords} | ./cosy.lua user:authenticate alinard
echo "Authenticating user alban:"
cat ${passwords} | ./cosy.lua user:information alban
echo "Updating user alban:"
./cosy.lua user:update --name="Alban Linard"
echo "Showing user alban:"
./cosy.lua user:information alban
echo "Showing the list of users:"
./cosy.lua user:list
echo "Deleting user alinard:"
./cosy.lua user:delete
echo "Failing at authenticating user alinard:"
cat ${passwords} | ./cosy.lua user:authenticate alinard
echo "Authenticating user alban:"
cat ${passwords} | ./cosy.lua user:authenticate alban
