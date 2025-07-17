CREATE SCHEMA application;

CREATE TABLE application.user(
  email TEXT NOT NULL,
  PRIMARY KEY(email)
);

CREATE TABLE application.user_with_birth_date(
  LIKE application.user INCLUDING ALL,
  birth_date DATE NOT NULL
);
