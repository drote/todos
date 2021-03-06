CREATE TABLE lists (
	id SERIAL 		  PRIMARY KEY,
	name VARCHAR(128) NOT NULL UNIQUE
);

CREATE TABLE todos (
	id SERIAL 		  PRIMARY KEY,
	name VARCHAR(64)  NOT NULL,
	completed BOOLEAN NOT NULL DEFAULT false,
	list_id INT  	  NOT NULL REFERENCES lists (id) ON DELETE CASCADE
);