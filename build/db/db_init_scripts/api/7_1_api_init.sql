
CREATE SCHEMA api; 

create table api.todos (
  id serial primary key,
  done boolean not null default false,
  task text not null,
  due timestamptz
);

insert into api.todos (task) values
  ('finish tutorial 0'), ('pat self on back');

create role web_anon nologin;

grant usage on schema api to web_anon;
grant select on api.todos to web_anon;

create role authenticator noinherit login password 'mysecretpassword';
grant web_anon to authenticator;

CREATE view api.tasks AS SELECT * FROM  alerting.jobs_to_run;
CREATE view api.jobs AS SELECT * FROM  alerting.jobs;
CREATE view api.test AS SELECT * FROM  alerting.test;

