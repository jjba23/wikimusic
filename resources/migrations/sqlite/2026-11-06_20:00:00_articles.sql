-- Articles: the pages readers write for other readers -- tutorials, videos,
-- chord guides, theory, discussions -- and the comments that hang off them.
--
-- `kind' is constrained here as well as in the form, because it is the column
-- every list and every badge is drawn from: a word nobody offers must never
-- reach a row, and the database is the last place that can say so.
--
-- `article_comments.created_by' is the one nullable author column in the
-- schema, and it is nullable on purpose: anyone may comment, signed in or not,
-- so a comment's author is either a user of this instance or a name the reader
-- typed, which `author_name' holds.  Nothing else may be anonymous.

CREATE TABLE IF NOT EXISTS "articles" (
	"identifier"	TEXT NOT NULL,
	"display_name"	TEXT NOT NULL,
	"kind"	TEXT NOT NULL CHECK ("kind" IN ('tutorial', 'video', 'chord-guide', 'theory', 'discussion')),
	"video_url"	TEXT,
	"contents"	TEXT NOT NULL,
	"created_by"	TEXT NOT NULL,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	"views"	INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier")
);

CREATE TABLE IF NOT EXISTS "article_comments" (
	"identifier"	TEXT NOT NULL,
	"parent_identifier"	TEXT,
	"article_identifier"	TEXT NOT NULL,
	"author_name"	TEXT,
	"created_by"	TEXT,
	"visibility_status"	INTEGER NOT NULL,
	"approved_by"	TEXT,
	"contents"	TEXT NOT NULL,
	"created_at"	TEXT NOT NULL,
	"last_edited_at"	TEXT,
	PRIMARY KEY("identifier"),
	FOREIGN KEY("approved_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("created_by") REFERENCES "users"("identifier"),
	FOREIGN KEY("article_identifier") REFERENCES "articles"("identifier")
);
