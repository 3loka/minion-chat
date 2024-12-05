# Leaderboard UI 

```bash
http://<DNS>
```

where DNS is output from Terraform.

# Get Leaderboard

```bash
curl -X GET http://<DNS>/api 
```

# Update Leaderboard

```bash
curl -X POST http://<DNS>/api -H "Content-Type: application/json" \
-d '{"user": "username", "game": "vault"}
```

** Note above curl will not work. Update call only works with Go Client ;)

# Get Leaderboard for Game

```bash
curl -X GET http://<DNS>/api/:game 
```
