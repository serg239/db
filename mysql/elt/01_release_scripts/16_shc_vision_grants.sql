/*
   Script:
     shc_vision_grants.sql
   Description:
     Add SELECT grants to shc_vision user
*/

GRANT SELECT ON *.*     TO 'shc_vision'@'%';
GRANT SELECT ON mysql.* TO 'shc_vision'@'%';

GRANT SELECT ON *.*     TO 'shc_vision'@'localhost';
GRANT SELECT ON mysql.* TO 'shc_vision'@'localhost';

FLUSH PRIVILEGES;
