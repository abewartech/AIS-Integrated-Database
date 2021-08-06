INSERT INTO alerting.users 
(user_name, email_addr, enabled, org)
VALUES
('SysAdmin','sysadmin@csir.co.za',True,'CSIR');

INSERT INTO alerting.reports 
(report_name, report_type, source_type, report_source, creation_date, version)
VALUES
('Test Report','scheduled','View','alerting.test',now(),'0.1');

INSERT INTO alerting.user_reports
(user_id, report_id)
VALUES
((SELECT id FROM alerting.users WHERE user_name = 'SysAdmin'),
 (SELECT id FROM alerting.reports WHERE report_name = 'Test Report'));

INSERT INTO alerting.jobs
(application_name, schedule_interval, max_runtime, max_retries, retry_period, owner, scheduled, config, report_id, last_run)
VALUES
('Test Scheduled Report', 	-- Report name
 interval '24 hours', 	-- how often to send reports
 interval '20 minutes', 	-- how long to wait while getting data from view
 -1, 				-- How many times to try to build report before failing
 interval '5 minutes', 	--How long to wait between retry
 'rory', 			--the owner
 True, 				--active/not active
 NULL,				-- Some JSONb config params. I dunno
 (SELECT id FROM alerting.reports WHERE report_name = 'Test Report'),
 '2020-01-01'			-- Updated on successful run
); 


