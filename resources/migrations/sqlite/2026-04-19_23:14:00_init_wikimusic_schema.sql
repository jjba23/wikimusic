CREATE TABLE IF NOT EXISTS "artist_artworks" (
	"identifier"	TEXT NOT NULL,
	"artist_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"content_url"	TEXT NOT NULL,
	"content_caption"	TEXT,
	"order_value"	INTEGER NOT NULL,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("artist_identifier") REFERENCES "artists"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "artist_comments" (
	"identifier"	TEXT NOT NULL,
	"parent_identifier"	TEXT,
	"artist_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"contents"	TEXT NOT NULL,
	"approved_by"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("artist_identifier") REFERENCES "artists"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "artist_external_sources" (
	"identifier"	TEXT NOT NULL,
	"artist_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"spotify_url"	TEXT,
	"youtube_url"	TEXT,
	"soundcloud_url"	TEXT,
	"wikipedia_url"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("artist_identifier") REFERENCES "artists"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "artist_genres" (
	"identifier"	TEXT NOT NULL,
	"artist_identifier"	TEXT NOT NULL,
	"genre_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"created_at"	TEXT NOT NULL,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("artist_identifier") REFERENCES "artists"("identifier"),
	FOREIGN KEY("genre_identifier") REFERENCES "genres"("identifier")
);

CREATE TABLE IF NOT EXISTS "artist_opinions" (
	"identifier"	TEXT NOT NULL,
	"artist_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"is_like"	INTEGER NOT NULL,
	"is_dislike"	INTEGER NOT NULL,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("artist_identifier") REFERENCES "artists"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "artists" (
	"identifier"	TEXT NOT NULL,
	"display_name"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	"views"	INTEGER NOT NULL DEFAULT 0,
	"description"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "genre_artworks" (
	"identifier"	TEXT NOT NULL,
	"genre_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"content_url"	TEXT NOT NULL,
	"content_caption"	TEXT,
	"order_value"	INTEGER NOT NULL,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("genre_identifier") REFERENCES "genres"("identifier")
);

CREATE TABLE IF NOT EXISTS "genre_comments" (
	"identifier"	TEXT NOT NULL,
	"parent_identifier"	TEXT,
	"genre_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"contents"	TEXT NOT NULL,
	"approved_by"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("genre_identifier") REFERENCES "genres"("identifier")
);

CREATE TABLE IF NOT EXISTS "genre_external_sources" (
	"identifier"	TEXT NOT NULL,
	"genre_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"spotify_url"	TEXT,
	"youtube_url"	TEXT,
	"soundcloud_url"	TEXT,
	"wikipedia_url"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("genre_identifier") REFERENCES "genres"("identifier")
);

CREATE TABLE IF NOT EXISTS "genre_opinions" (
	"identifier"	TEXT NOT NULL,
	"genre_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"is_like"	INTEGER NOT NULL,
	"is_dislike"	INTEGER NOT NULL,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("genre_identifier") REFERENCES "genres"("identifier")
);

CREATE TABLE IF NOT EXISTS "genres" (
	"identifier"	TEXT NOT NULL,
	"parent_identifier"	TEXT,
	"display_name"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	"views"	INTEGER NOT NULL DEFAULT 0,
	"description"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "password_reset" (
	"user_id"	varchar(36) NOT NULL UNIQUE,
	"reset_token"	varchar(2048) NOT NULL,
	"created_at"	date NOT NULL
);

CREATE TABLE IF NOT EXISTS "song_artists" (
	"identifier"	TEXT NOT NULL,
	"song_identifier"	TEXT NOT NULL,
	"artist_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"created_at"	TEXT NOT NULL,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("artist_identifier") REFERENCES "artists"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("song_identifier") REFERENCES "songs"("identifier")
);

CREATE TABLE IF NOT EXISTS "song_artworks" (
	"identifier"	TEXT NOT NULL,
	"song_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"content_url"	TEXT NOT NULL,
	"content_caption"	TEXT,
	"order_value"	INTEGER NOT NULL,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("song_identifier") REFERENCES "songs"("identifier")
);

CREATE TABLE IF NOT EXISTS "song_comments" (
	"identifier"	TEXT NOT NULL,
	"parent_identifier"	TEXT,
	"song_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"contents"	TEXT NOT NULL,
	"approved_by"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("song_identifier") REFERENCES "songs"("identifier")
);

CREATE TABLE IF NOT EXISTS "song_contents" (
	"identifier"	TEXT NOT NULL,
	"song_identifier"	TEXT NOT NULL,
	"version_name"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"instrument_type"	TEXT NOT NULL,
	"ascii_legend"	text,
	"ascii_contents"	text,
	"pdf_contents"	text,
	"guitarpro_contents"	text,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("song_identifier") REFERENCES "songs"("identifier")
);

CREATE TABLE IF NOT EXISTS "song_external_sources" (
	"identifier"	TEXT NOT NULL,
	"song_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"spotify_url"	TEXT,
	"youtube_url"	TEXT,
	"soundcloud_url"	TEXT,
	"wikipedia_url"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("song_identifier") REFERENCES "songs"("identifier")
);

CREATE TABLE IF NOT EXISTS "song_genres" (
	"identifier"	TEXT NOT NULL,
	"song_identifier"	TEXT NOT NULL,
	"genre_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"created_at"	TEXT NOT NULL,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("genre_identifier") REFERENCES "genres"("identifier"),
	FOREIGN KEY("song_identifier") REFERENCES "songs"("identifier")
);

CREATE TABLE IF NOT EXISTS "song_opinions" (
	"identifier"	TEXT NOT NULL,
	"song_identifier"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"is_like"	INTEGER NOT NULL,
	"is_dislike"	INTEGER NOT NULL,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("song_identifier") REFERENCES "songs"("identifier")
);

CREATE TABLE IF NOT EXISTS "songs" (
	"identifier"	TEXT NOT NULL,
	"display_name"	TEXT NOT NULL,
	"music_key"	TEXT,
	"music_tuning"	TEXT,
	"music_creation_date"	TEXT,
	"album_name"	TEXT,
	"album_info_link"	TEXT,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	"views"	INTEGER NOT NULL DEFAULT 0,
	"description"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "users" (
	"identifier"	TEXT NOT NULL,
	"email"	TEXT NOT NULL,
	"password"	TEXT,
	"salt"	TEXT,
	"permissions"	TEXT,
	"username"	TEXT,
	PRIMARY KEY("identifier")
);
