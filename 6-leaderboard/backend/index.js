const express = require("express");
const bodyParser = require("body-parser");
const sqlite3 = require("sqlite3").verbose();
const cors = require("cors");

const app = express();
const db = new sqlite3.Database(":memory:");

// Middleware
app.use(bodyParser.json());
app.use(cors());

// Initialize database
db.serialize(() => {
    // Create scores table
    db.run(`CREATE TABLE scores (
    score_id INTEGER PRIMARY KEY AUTOINCREMENT,
    user TEXT NOT NULL,
    game TEXT NOT NULL,
    score INTEGER NOT NULL
  )`);
});

// API Endpoints

const validGames = ['vault', 'consul', 'nomad', 'terraform', 'hvs']

// Update leaderboard by adding a score
app.post("/", (req, res) => {
    const { user, game } = req.body;

    const userAgent = req.headers['user-agent'];

    if (!((req.headers['token'] === '5B9E24B5-19CE-46B0-8FEB-830ADBD74FF9') || (req.headers['token'] === 'ECD9823E-6E7E-42F0-BD72-1CA381098C0D'))) {
        return res.status(403).send("UnAuth!!");
    }

    if (!userAgent.startsWith("Go-http-client")) {
        return res.status(400).send("No cheating!!");
    }

    if (!validGames.includes(game)) {
        return res.status(400).send("Invalid Game!!");
    }

    if (!user || !game) {
        return res.status(400).send("Missing required fields: user, game");
    }

    score = parseFloat(new Date().getTime()) / 100

    db.run(
        "INSERT INTO scores (user, game, score) VALUES (?, ?, ?)",
        [user, game, score],
        function (err) {
            if (err) return res.status(500).send(err.message);
            res.status(201).send({ score_id: this.lastID });
        }
    );
});

// Get overall leaderboard
app.get("/", (req, res) => {
    const query = `
        SELECT 
            user,
            COUNT(DISTINCT game) AS unique_games,
            SUM(min_score) AS min_total_score
        FROM (
            SELECT 
                user, 
                game, 
                MIN(score) AS min_score
            FROM 
                scores
            GROUP BY 
                user, game
        ) AS user_game_min_scores
        GROUP BY 
            user
        ORDER BY 
            unique_games DESC, 
            min_total_score ASC;
  `;

    db.all(query, [], (err, rows) => {
        if (err) {
            res.status(500).send(err.message);
            return;
        }
        res.json(rows);
    });
});

app.get("/:game", (req, res) => {
    const { game } = req.params;

    if (!game) {
        return res.status(400).send("Game name is required.");
    }

    db.all(
        `SELECT user, score
     FROM scores
     WHERE game = ?
     ORDER BY score ASC`,
        [game],
        (err, rows) => {
            if (err) return res.status(500).send(err.message);
            res.send(rows);
        }
    );
});

// Start server
const PORT = 3000;
app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});
