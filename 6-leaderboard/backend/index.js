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

// Update leaderboard by adding a score
app.post("/update-leaderboard", (req, res) => {
    const { user, game, score } = req.body;

    if (!user || !game || score == null) {
        return res.status(400).send("Missing required fields: user, game, or score.");
    }

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
app.get("/leaderboard", (req, res) => {
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

// Get leaderboard for a specific game
app.get("/leaderboard/:game", (req, res) => {
    const { game } = req.params;

    if (!game) {
        return res.status(400).send("Game name is required.");
    }

    db.all(
        `SELECT user, score
     FROM scores
     WHERE game = ?
     ORDER BY score DESC LIMIT 10`,
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
