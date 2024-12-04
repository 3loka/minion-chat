# Get Leaderboard

curl -X GET http://<DNS>/api 

# Update Leaderboard

curl -X POST http://<DNS>/api -H "Content-Type: application/json" \
-d '{"user": "username", "game": "vault"}

** Note above curl will not work. Update call only works with Go Client ;)

# Get Leaderboard for Game

curl -X GET http://<DNS>/api/:game 
