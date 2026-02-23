CREATE TABLE users (
    id          SERIAL PRIMARY KEY,
    username    VARCHAR(64) NOT NULL UNIQUE,
    email       VARCHAR(255) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active   BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

CREATE TABLE posts (
    id          SERIAL PRIMARY KEY,
    author_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title       VARCHAR(256) NOT NULL,
    body        TEXT NOT NULL,
    published   BOOLEAN DEFAULT FALSE,
    view_count  INTEGER DEFAULT 0,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_posts_author ON posts(author_id);
CREATE INDEX idx_posts_published ON posts(published) WHERE published = TRUE;

-- Analytics view
CREATE VIEW post_analytics AS
SELECT
    u.username,
    COUNT(p.id) AS total_posts,
    SUM(CASE WHEN p.published THEN 1 ELSE 0 END) AS published_count,
    COALESCE(SUM(p.view_count), 0) AS total_views,
    MAX(p.created_at) AS last_post_date
FROM users u
LEFT JOIN posts p ON u.id = p.author_id
GROUP BY u.id, u.username
ORDER BY total_views DESC;

-- Insert sample data
INSERT INTO users (username, email, password_hash) VALUES
    ('alice', 'alice@example.com', 'hash_abc123'),
    ('bob', 'bob@example.com', 'hash_def456');

INSERT INTO posts (author_id, title, body, published, view_count) VALUES
    (1, 'Getting Started with SQL', 'This is a beginner guide...', TRUE, 150),
    (1, 'Advanced Queries', 'Let us explore CTEs...', TRUE, 89),
    (2, 'Draft Post', 'Work in progress...', FALSE, 0);
