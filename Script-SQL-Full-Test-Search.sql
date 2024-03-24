CREATE TABLE teste.public.author(
   id SERIAL PRIMARY KEY,
   name TEXT NOT null
);

CREATE TABLE teste.public.post(
   id SERIAL PRIMARY KEY,
   title TEXT NOT NULL,
   content TEXT NOT NULL,
   author_id INT NOT NULL references teste.public.author(id)
);

CREATE TABLE teste.public.tag(
   id SERIAL PRIMARY KEY,
   name TEXT NOT NULL
);

CREATE TABLE teste.public.posts_tags(
   post_id INT NOT NULL references teste.public.post(id),
   tag_id INT NOT NULL references teste.public.tag(id)
 );

INSERT INTO teste.public.author (id, name)
VALUES (1, 'Pete Graham'),
   	(2, 'Rachid Belaid'),
   	(3, 'Robert Berry');

INSERT INTO teste.public.tag (id, name)
VALUES (1, 'scifi'),
   	(2, 'politics'),
   	(3, 'science');

INSERT INTO teste.public.post (id, title, content, author_id)
VALUES (1, 'Endangered species',
    	'Pandas are an endangered species', 1 ),
   	(2, 'Freedom of Speech',
    	'Freedom of speech is a necessary right', 2),
   	(3, 'Star Wars vs Star Trek',
    	'Few words from a big fan', 3);

INSERT INTO teste.public.posts_tags (post_id, tag_id)
VALUES (1, 3),
   	(2, 2),
   	(3, 1);

/*Construindo o documento para busca*/
SELECT post.title || ' ' || post.content || ' ' ||
   	 author.name || ' ' ||
   	 coalesce((string_agg(tag.name, ' ')), '') as document
FROM post
   	 JOIN author ON author.id = post.author_id JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
   	 JOIN tag ON tag.id = posts_tags.tag_id GROUP BY post.id, author.id;
   	
SELECT to_tsvector(post.title) ||
    to_tsvector(post.content) ||
    to_tsvector(author.name) ||
    to_tsvector(coalesce((string_agg(tag.name, ' ')), '')) as document
FROM post
    JOIN author ON author.id = post.author_id JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
    JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;

SELECT to_tsvector('Try not to become a man of success, but rather try to become a man of value');

select to_tsvector('If you can dream it, you can do it') @@ to_tsquery('dream');
select to_tsvector('It''s kind of fun to do the impossible') @@ to_tsquery('impossible');
SELECT to_tsvector('It''s kind of fun to do the impossible') @@ to_tsquery('impossible');
SELECT to_tsvector('If the facts don''t fit the theory, change the facts') @@ to_tsquery('! fact');
SELECT to_tsvector('If the facts don''t fit the theory, change the facts') @@ to_tsquery('theory & !fact');
SELECT to_tsvector('If the facts don''t fit the theory, change the facts.') @@ to_tsquery('fiction | theory');
SELECT to_tsvector('If the facts don''t fit the theory, change the facts.') @@ to_tsquery('theo:*');
SELECT 'impossible'::tsquery, to_tsquery('impossible');
SELECT 'dream'::tsquery, to_tsquery('dream');


SELECT pid, p_title
FROM (SELECT post.id as pid,
         	post.title as p_title,
         	to_tsvector(post.title) ||
         	to_tsvector(post.content) ||
         	to_tsvector(author.name) ||
         	to_tsvector(coalesce(string_agg(tag.name, ' '))) as document
  	FROM post
  	JOIN author ON author.id = post.author_id
  	JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
  	JOIN tag ON tag.id = posts_tags.tag_id
  	GROUP BY post.id, author.id) p_search
WHERE p_search.document @@ to_tsquery('Endangered & Species');

/*Suporte a idiomas*/
SELECT to_tsvector('english', 'We are running');
SELECT to_tsvector('french', 'We are running');

ALTER TABLE post ADD language text NOT NULL DEFAULT('english');

SELECT to_tsvector(post.language::regconfig, post.title) ||
   	to_tsvector(post.language::regconfig, post.content) ||
   	to_tsvector('simple', author.name) ||
   	to_tsvector('simple', coalesce((string_agg(tag.name, ' ')), '')) as document
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;

SELECT to_tsvector('simple', 'We are running');

/*Trabalhando com caracteres acentuados*/
CREATE EXTENSION unaccent;
SELECT unaccent('èéêë');

INSERT INTO post (id, title, content, author_id, language)
VALUES (4, 'il était une fois', 'il était une fois un hôtel ...', 2,'french');

ALTER TEXT SEARCH CONFIGURATION fr ALTER MAPPING
FOR hword, hword_part, word WITH unaccent, french_stem;

SELECT to_tsvector('french', 'il était une fois');
SELECT to_tsvector('fr', 'il était une fois');
SELECT to_tsvector('french', unaccent('il était une fois'));
SELECT to_tsvector('fr', 'Hôtel') @@ to_tsquery('hotels') as result;

/*Classificação de documentos*/
SELECT pid, p_title
FROM (SELECT post.id as pid,
         	post.title as p_title,
         	setweight(to_tsvector(post.language::regconfig, post.title), 'A') ||
         	setweight(to_tsvector(post.language::regconfig, post.content), 'B') ||
         	setweight(to_tsvector('simple', author.name), 'C') ||
         	setweight(to_tsvector('simple', coalesce(string_agg(tag.name, ' '))), 'B') as document
  	FROM post
  	JOIN author ON author.id = post.author_id
  	JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
  	JOIN tag ON tag.id = posts_tags.tag_id
  	GROUP BY post.id, author.id) p_search
WHERE p_search.document @@ to_tsquery('english', 'Endangered & Species')
ORDER BY ts_rank(p_search.document, to_tsquery('english', 'Endangered & Species')) DESC;



SELECT ts_rank(to_tsvector('This is an example of document'),
           	to_tsquery('example | document')) as relevancy;
    

/*Otimização e indexação*/      
CREATE MATERIALIZED VIEW search_index AS
SELECT post.id,
   	post.title,
   	setweight(to_tsvector(post.language::regconfig, post.title), 'A') ||
   	setweight(to_tsvector(post.language::regconfig, post.content), 'B') ||
   	setweight(to_tsvector('simple', author.name), 'C') ||
   	setweight(to_tsvector('simple', coalesce(string_agg(tag.name, ' '))), 'A') as document
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id;


CREATE INDEX idx_fts_search ON search_index USING gin(document);

SELECT id as post_id, title
FROM search_index
WHERE document @@ to_tsquery('english', 'Freedom & Speech')
ORDER BY ts_rank(document, to_tsquery('english', 'Freedom & Speech')) DESC;

/*Erros de ortografia*/

CREATE EXTENSION pg_trgm;

SELECT similarity('Something', 'something');
SELECT similarity('Something', 'omething');

CREATE MATERIALIZED VIEW unique_lexeme AS
SELECT word FROM ts_stat(
$$SELECT to_tsvector('simple', post.title) ||
	to_tsvector('simple', post.content) ||
	to_tsvector('simple', author.name) ||
	to_tsvector('simple', coalesce(string_agg(tag.name, ' ')))
FROM post
JOIN author ON author.id = post.author_id
JOIN posts_tags ON posts_tags.post_id = posts_tags.tag_id
JOIN tag ON tag.id = posts_tags.tag_id
GROUP BY post.id, author.id$$);

CREATE INDEX words_idx ON search_words USING gin(word gin_trgm_ops);

REFRESH MATERIALIZED VIEW unique_lexeme;

SELECT word
FROM search_words
WHERE similarity(word, 'words') > 0.5
ORDER BY word <-> 'words'
LIMIT 1;

SELECT word, similarity(word, 'un') AS sml
  FROM search_words
  WHERE word % 'un'
  ORDER BY sml DESC, word;
 

