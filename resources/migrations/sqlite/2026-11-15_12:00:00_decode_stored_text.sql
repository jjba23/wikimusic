-- WikiMusic used to store a row's text the way it was rendered: every display
-- name, description, legend and comment was passed through `html-escape' before
-- it was written, and every page unescaped it again on the way out.  A row now
-- keeps what a reader typed, and the document template escapes the text once,
-- when the page is written.  This turns the rows written under the old rule
-- into the new one.
--
-- The five entities `html-escape' produced are decoded here, and `&amp;' is
-- decoded last: a row whose author typed the characters `&lt;' was stored as
-- `&amp;lt;', which comes back as what they typed only when the ampersand is
-- taken back after the entities that spell it.
--
-- Columns that were never escaped -- an identifier, a time, a percent-encoded
-- address -- are left alone, and a row that holds no `&' is unchanged by any
-- of these statements.

UPDATE "songs"
   SET "display_name" = replace(replace(replace(replace(replace("display_name", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "music_key" = replace(replace(replace(replace(replace("music_key", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "music_tuning" = replace(replace(replace(replace(replace("music_tuning", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "music_creation_date" = replace(replace(replace(replace(replace("music_creation_date", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "album_name" = replace(replace(replace(replace(replace("album_name", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "description" = replace(replace(replace(replace(replace("description", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "artists"
   SET "display_name" = replace(replace(replace(replace(replace("display_name", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "description" = replace(replace(replace(replace(replace("description", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "genres"
   SET "display_name" = replace(replace(replace(replace(replace("display_name", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "description" = replace(replace(replace(replace(replace("description", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "articles"
   SET "display_name" = replace(replace(replace(replace(replace("display_name", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "contents" = replace(replace(replace(replace(replace("contents", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "song_contents"
   SET "instrument_type" = replace(replace(replace(replace(replace("instrument_type", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "version_name" = replace(replace(replace(replace(replace("version_name", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "ascii_legend" = replace(replace(replace(replace(replace("ascii_legend", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "ascii_contents" = replace(replace(replace(replace(replace("ascii_contents", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "song_artworks"
   SET "content_caption" = replace(replace(replace(replace(replace("content_caption", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "artist_artworks"
   SET "content_caption" = replace(replace(replace(replace(replace("content_caption", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "genre_artworks"
   SET "content_caption" = replace(replace(replace(replace(replace("content_caption", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "song_comments"
   SET "contents" = replace(replace(replace(replace(replace("contents", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "artist_comments"
   SET "contents" = replace(replace(replace(replace(replace("contents", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "genre_comments"
   SET "contents" = replace(replace(replace(replace(replace("contents", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "article_comments"
   SET "contents" = replace(replace(replace(replace(replace("contents", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');

UPDATE "users"
   SET "username" = replace(replace(replace(replace(replace("username", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&'),
       "email" = replace(replace(replace(replace(replace("email", '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');
